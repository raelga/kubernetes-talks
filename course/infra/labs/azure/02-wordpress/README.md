# Azure 02 — WordPress con MySQL privado

**Demostración del profesorado:** se despliega únicamente en una cuenta del instructor. Para el alumnado, el despliegue es opcional y solo debe hacerse con autorización, presupuesto y permisos adecuados. Esta práctica es un ejemplo didáctico, no una instalación de producción.

Un único estado Terraform crea un grupo de recursos, VNet con subredes web y delegada para MySQL Flexible Server, DNS privado, servidor MySQL sin acceso público, Key Vault, identidad administrada y una VM Ubuntu con Apache/PHP y WordPress. La VM obtiene los secretos desde Key Vault con su identidad, crea la base `wordpress` y un usuario de aplicación con permisos **solo sobre esa base**, y configura WordPress. La conexión a MySQL exige TLS; la inicialización del usuario verifica el certificado del servidor. La VM tiene IP pública, pero el NSG limita tanto HTTP como SSH al CIDR indicado. La instalación web inicial usa HTTP sin cifrar: no introducir datos reales ni reutilizar contraseñas y no exponerla a redes no confiables.

## Antes de empezar

- Terraform 1.10+ y autenticación Azure del onboarding del curso, en el tenant y la suscripción autorizados. El proveedor necesita la suscripción explícita; no se guarda ninguna credencial en el repositorio. El operador necesita permisos para crear los recursos y gestionar políticas y secretos del Key Vault.
- Un grupo de recursos, cuenta de almacenamiento y contenedor **existentes** para el backend `azurerm` (véase `../00-terraform-state`). Acceso al blob mediante Microsoft Entra ID y permisos de datos adecuados, como Storage Blob Data Contributor. El backend usa la clave independiente `azure/wordpress/terraform.tfstate`. No colocar el backend dentro del grupo de recursos que crea este laboratorio.
- Una clave SSH pública, tu IP pública IPv4 en formato CIDR (preferiblemente `/32`) y una región con disponibilidad de `Standard_B2s` y MySQL `B_Standard_B1ms`. La red debe permitir acceder al backend y al endpoint de datos de Key Vault. La VM necesita salida HTTPS para paquetes, WordPress y Key Vault.
- Confirmar el coste y los límites de la cuenta antes de aplicar. Esta práctica crea recursos facturables aunque no se visite la web.

## Uso

Desde la carpeta de este laboratorio, tras autenticarse según el onboarding, proporciona los nombres existentes del backend y la suscripción mediante el entorno de tu sesión. Estos valores son de ejemplo como **nombres de variables**, no son identificadores reales:

```sh
export TF_VAR_subscription_id="<suscripción-autorizada>"
export TF_VAR_admin_cidr="<tu-ip-pública>/32"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
export STATE_RG="<grupo-del-estado>"
export STATE_ACCOUNT="<cuenta-del-estado>"
export STATE_CONTAINER="<contenedor-del-estado>"

terraform init \
  -backend-config="resource_group_name=$STATE_RG" \
  -backend-config="storage_account_name=$STATE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER"
terraform plan
terraform apply
```

Sustituye los valores entre `<...>` y usa otra ruta de clave pública si corresponde. No introduzcas una clave privada. `location` por defecto es `westeurope`; se puede cambiar con `TF_VAR_location`. El CIDR debe incluir la IP pública desde la que abrirás el navegador y SSH; si cambia, actualízalo y aplica de nuevo. No uses `0.0.0.0/0`. Evita guardar planes con secretos en archivos o compartir su salida.

Tras `apply`, consulta `terraform output wordpress_url` y espera varios minutos a que termine cloud-init. Abre la URL desde el CIDR autorizado y completa inmediatamente el asistente de WordPress con credenciales desechables. El asistente no está preconfigurado: hasta completarlo, cualquier persona dentro del CIDR permitido podría apropiarse del sitio. Para diagnóstico, `terraform output ssh_command` muestra el comando de acceso; en la VM consulta `/var/log/cloud-init-output.log` con privilegios de administrador. No publiques los registros sin revisarlos. La URL es HTTP, no HTTPS; no usarla con información privada.

## Secretos y estado

Terraform genera contraseñas independientes para el administrador de MySQL y la aplicación, además de las claves y sales de WordPress. Se guardan en Key Vault; la VM usa una identidad administrada asignada por el usuario con permiso `Get` sobre los secretos del almacén para el bootstrap. El administrador de MySQL se usa solo para inicializar la base y el usuario limitado; WordPress usa este último con TLS. La VM necesita temporalmente el secreto administrador: esta es una concesión didáctica, no mínimo privilegio de producción. No hay contraseñas en `custom_data`, argumentos de Terraform ni salidas; `wp-config.php` contiene el secreto de aplicación en disco y es legible por root y el proceso web. Protege la VM y no compartas capturas ni archivos de configuración.

**El estado Terraform contiene todos los secretos en texto legible para quien pueda acceder a él**, incluso cuando Terraform los marca como sensibles. La cuenta de almacenamiento debe estar cifrada en reposo y tener acceso privado/restringido a identidades autorizadas; HTTPS cifra el transporte. Protege también backups, planes, logs y copias locales; nunca los subas a Git. El borrado del laboratorio no elimina automáticamente las versiones o copias retenidas del estado. La política de acceso del operador permite gestionar secretos; Key Vault usa soft delete, por lo que los secretos eliminados pueden permanecer recuperables durante la retención configurada.

## Costes y limpieza

La VM, disco, IP pública, MySQL Flexible Server (cómputo, almacenamiento y copias), Key Vault, DNS, tráfico y almacenamiento del estado pueden generar costes. Revisa precios y disponibilidad regionales, aplica filtros por grupo de recursos en Azure Cost Management y configura presupuesto y alertas; la facturación puede retrasarse y los presupuestos **no detienen el gasto**. Una VM detenida sin liberar recursos o una base activa pueden seguir generando cargos.

Al terminar, desde el mismo directorio y con el mismo backend y variables:

```sh
terraform destroy
```

Comprueba en la suscripción autorizada que ya no quedan recursos ni cargos inesperados, incluidas copias y secretos recuperables. La cuenta/contenedor de estado y cualquier infraestructura compartida se gestionan aparte: no los borres si otros laboratorios los usan. Conserva o elimina el estado y sus versiones según la política del curso. Desplegar y destruir recursos son operaciones reales y requieren autorización.
