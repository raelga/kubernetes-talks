# Guía docente · Azure/GCP · sesión 3

**Rael Garcia · 10/11/2026 · 3h.** El alumnado realiza transferencia y Python sin cuentas. **Solo el docente despliega**, en cuentas autorizadas y con control presupuestario. No ejecutar estos comandos como verificación editorial del repositorio: crean recursos facturables. No se ha desplegado ni capturado nube real para elaborar este material. Los JSON de `fixtures/` son sintéticos y no se deben presentar como ejecuciones verificadas.

La agenda completa del [README](README.md) reserva 60 min reales de M1 y 18 min de costes **por proveedor**. Preparar infra/evidencias antes de clase; durante la sesión explicar cambios, plan, HTTP, costes y destrucción, no esperar dos instalaciones desde cero.

## Preflight de entorno y permisos

- Terraform >=1.6,<2; Python >=3.11; Azure CLI y gcloud recientes. Providers acotados en HCL (AzureRM 4.x, Google >=6,<8). Los lockfiles que genere `init` fijan una resolución concreta: conservar los revisados según política del curso, nunca credenciales ni caché. No actualizar versiones durante la demo sin preparar de nuevo el entorno.
- Azure: tenant/suscripción docente confirmados, cuota regional para uno de los SKU permitidos y Ubuntu 24.04 Canonical `ubuntu-24_04-lts/server` disponible. Comprobar `az vm list-skus --location "$AZ_LOCATION" --size "$TF_VAR_vm_size" --subscription "$AZ_SUBSCRIPTION" --output table` y `az vm image show --location "$AZ_LOCATION" --urn Canonical:ubuntu-24_04-lts:server:latest --subscription "$AZ_SUBSCRIPTION"` en preparación. Resource providers Microsoft.Compute, Network y Storage **ya registrados** por administración; el provider tiene registro automático desactivado. No resolver un error ampliando IAM o registrando servicios durante clase.
- Azure: permisos existentes para crear/borrar recursos solo en el ámbito autorizado y acceso de datos Blob mediante Entra (p. ej. rol de datos heredado aprobado) para backend y container. Shared keys desactivadas en almacenamiento del ejercicio. Esta configuración no crea roles, identidades ni excepciones. Denegación de permisos es un fallo real a resolver con administración, no motivo para habilitar claves compartidas.
- GCP: proyecto docente con facturación y APIs Compute Engine/Cloud Storage ya habilitadas, cuota en zona e2-micro/e2-small, imagen `debian-cloud/debian-12`, acceso a red y bucket con permisos existentes. `gcloud services list --enabled --project "$GCP_PROJECT"` y `gcloud compute zones describe "$GCP_ZONE" --project "$GCP_PROJECT"` son lecturas de preparación. No crear proyecto, habilitar API ni cambiar roles mediante este laboratorio. La VM no lleva bloque `service_account`, no tiene claves cloud y no necesita acceso a objetos; organización que exija otra identidad requiere revisión previa, no improvisación de IAM.
- Comprobar que no hay políticas heredadas que publiquen HTTP o SSH fuera de la regla mostrada. GCP VPC propia sin reglas default, Azure NSG deniega toda entrada restante. HTTP docente /32 preferido; si VPN/proxy cambia IP, corregir variable y revisar plan, no abrir Internet.
- Confirmar acceso a ambas vistas de facturación y presupuesto existente. Tener capturas autorizadas anonimizadas, o fichas sintéticas inferiores, si los permisos/retrasos impiden la vista live. No exigir acceso Billing estudiantil.
- Backends **ya existentes**, versionado/recuperación habilitados y acceso mínimo aprobado. No crearlos dentro de este estado ni apuntar al almacenamiento de la demo. Nunca compartir clave de estado ni workspace con otra persona o proveedor.
- La sesión 3 no sustituye el preflight Academy de las sesiones 1–2 ni el runtime de contenedores de sesión 4: preservar ese entorno por separado; limpiar aquí no es resetear Academy ni destruir una máquina compartida.

## Estado remoto y autenticación docente

Usar una terminal **Bash**; los `read` siguientes piden valores reales del entorno docente existente, no hay IDs ni backends ficticios. Desde la raíz del repositorio:

```bash
cd course/cloud-providers/labs/azure-gcp
export LAB_ROOT="$PWD"
export EVIDENCE_DIR="$(mktemp -d)"
printf 'Directorio local de evidencias (no Git): %s\n' "$EVIDENCE_DIR"
read -r -p 'lab_id propio y único, 3–12 minúsculas/dígitos/guiones: ' LAB_ID
read -r -p 'CIDR IPv4 de salida docente (/32 preferido, /24–/32): ' CLIENT_CIDR
export LAB_ID CLIENT_CIDR
export TF_VAR_lab_id="$LAB_ID" TF_VAR_http_client_cidr="$CLIENT_CIDR"
```

### Azure: identidad interactiva y Blob con locking

```bash
az login
read -r -p 'UUID de la suscripción docente: ' AZ_SUBSCRIPTION
read -r -p 'Región Azure autorizada: ' AZ_LOCATION
read -r -p 'SKU pequeño autorizado (Standard_B1s, Standard_B1ms o Standard_B2s): ' AZ_VM_SIZE
read -r -p 'Ruta a clave SSH PÚBLICA existente (.pub, nunca privada): ' AZ_PUBLIC_KEY
export AZ_SUBSCRIPTION AZ_LOCATION
export TF_VAR_subscription_id="$AZ_SUBSCRIPTION" TF_VAR_location="$AZ_LOCATION"
export TF_VAR_vm_size="$AZ_VM_SIZE" TF_VAR_ssh_public_key_path="$AZ_PUBLIC_KEY"
az account show --subscription "$AZ_SUBSCRIPTION" --output json

read -r -p 'Grupo del backend EXISTENTE (misma suscripción): ' AZ_STATE_RG
read -r -p 'Storage account del backend EXISTENTE: ' AZ_STATE_ACCOUNT
read -r -p 'Container privado del backend EXISTENTE: ' AZ_STATE_CONTAINER
az storage account show --subscription "$AZ_SUBSCRIPTION" --resource-group "$AZ_STATE_RG" \
  --name "$AZ_STATE_ACCOUNT" --output json
az storage container show --account-name "$AZ_STATE_ACCOUNT" --name "$AZ_STATE_CONTAINER" \
  --auth-mode login --output json
terraform -chdir="$LAB_ROOT/azure/terraform" init \
  -backend-config="subscription_id=$AZ_SUBSCRIPTION" \
  -backend-config="resource_group_name=$AZ_STATE_RG" \
  -backend-config="storage_account_name=$AZ_STATE_ACCOUNT" \
  -backend-config="container_name=$AZ_STATE_CONTAINER" \
  -backend-config="key=upc-2026/cloud-03/$LAB_ID/azure.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform -chdir="$LAB_ROOT/azure/terraform" workspace show
```

La cuenta CLI activa debe pertenecer al tenant de la suscripción; `az account show` permite comprobarlo sin depender de la suscripción por defecto. El backend usa el login CLI/Entra, no un access key. Blob proporciona locking mediante **lease** del objeto de estado. `init` debe terminar correctamente y `workspace show` debe indicar `default`; la separación viene de la clave única, no de varios workspaces del mismo lab_id. Si hay estado previo inesperado, **parar e investigar propiedad**, no importar ni borrar automáticamente. No usar `-migrate-state`, `-reconfigure`, `force-unlock` ni borrar leases para ignorar una discrepancia. Clave pública presente en configuración/estado no es un secreto; la privada nunca entra en Terraform. No se abre SSH, ni se necesita para ver HTTP.

### GCP: credenciales de usuario, GCS con locking

```bash
gcloud auth login
gcloud auth application-default login
read -r -p 'ID del proyecto docente existente: ' GCP_PROJECT
read -r -p 'Región GCP autorizada: ' GCP_REGION
read -r -p 'Zona de esa región con cuota: ' GCP_ZONE
read -r -p 'Bucket EXISTENTE del backend GCS (solo nombre, sin gs://): ' GCP_STATE_BUCKET
export GCP_PROJECT GCP_REGION GCP_ZONE
export TF_VAR_project_id="$GCP_PROJECT" TF_VAR_region="$GCP_REGION" TF_VAR_zone="$GCP_ZONE"
gcloud projects describe "$GCP_PROJECT" --format=json
gcloud storage buckets describe "gs://$GCP_STATE_BUCKET" --project "$GCP_PROJECT" --format=json
terraform -chdir="$LAB_ROOT/gcp/terraform" init \
  -backend-config="bucket=$GCP_STATE_BUCKET" \
  -backend-config="prefix=upc-2026/cloud-03/$LAB_ID/gcp"
terraform -chdir="$LAB_ROOT/gcp/terraform" workspace show
```

CLI login y Application Default Credentials (ADC) son almacenes distintos; verificar que ambos corresponden al principal autorizado. ADC es local, nunca se exporta una clave de service account ni se guarda en Git. GCS implementa locking de Terraform y el bucket debe tener versionado/recuperación ya preparados; comprobar su descripción y permisos con administración. El backend usa bucket/prefijo explícitos y no depende de `gcloud config set project`. El proyecto de cuota ADC depende de la cuenta docente; resolverlo antes si lo exige la organización, sin cambios automáticos en el script. Si falta acceso, detener la demo live y enseñar evidencias **identificadas**; no hacer pasar fixtures por un resultado real.

## Demostración Azure: plan, apply y evidencia

Una vez completado preflight/backend, comprobar que `terraform state list` no contiene recursos ajenos. No usar estados de otro docente. Todos los comandos siguientes son **docentes** y `apply` factura:

```bash
terraform -chdir="$LAB_ROOT/azure/terraform" state list
terraform -chdir="$LAB_ROOT/azure/terraform" plan -lock-timeout=60s -out="$EVIDENCE_DIR/azure.tfplan"
terraform -chdir="$LAB_ROOT/azure/terraform" show "$EVIDENCE_DIR/azure.tfplan"
# Solo tras leer y aprobar el plan exacto:
terraform -chdir="$LAB_ROOT/azure/terraform" apply -lock-timeout=60s "$EVIDENCE_DIR/azure.tfplan"
terraform -chdir="$LAB_ROOT/azure/terraform" output -json > "$EVIDENCE_DIR/azure-outputs.json"
AZ_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["http_url"]["value"])' "$EVIDENCE_DIR/azure-outputs.json")"
curl --fail --show-error "$AZ_URL/health"
python3 "$LAB_ROOT/scripts/capture.py" live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION" --resource-group "upc-2026-cloud-03-$LAB_ID" \
  --output "$EVIDENCE_DIR/azure-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider azure --input "$EVIDENCE_DIR/azure-live.json"
```

Leer recursos: grupo dedicado, VNet/subnet, NSG/NIC y asociación, IP Standard estática, Linux VM/disco y almacenamiento privado LRS. Comprobar CIDR docente y ausencia de secretos. `cloud-init` instala Python y systemd desde el template; un `apply` correcto no certifica que apt haya terminado ni que el servicio esté sano. Si HTTP falla, revisar estado de cloud-init/serial console desde acceso docente autorizado, conectividad de salida, CIDR de salida real y unidad systemd; no abrir SSH/HTTP global ni ocultar el fallo. No dejar una demo fallida consumiendo indefinidamente.

El endpoint Blob es autenticado y no sirve contenido anónimo: container privado, `allow_nested_items_to_be_public=false`, shared keys desactivadas. Privado aquí significa **datos no públicos**, no Private Endpoint/red privada. El provider utiliza la identidad docente para gestionarlo; la VM no tiene identidad cloud. No cargar objetos: se desea un contenedor vacío de demostración, no un servicio de publicación.

## Demostración GCP: plan, apply y evidencia

```bash
terraform -chdir="$LAB_ROOT/gcp/terraform" state list
terraform -chdir="$LAB_ROOT/gcp/terraform" plan -lock-timeout=60s -out="$EVIDENCE_DIR/gcp.tfplan"
terraform -chdir="$LAB_ROOT/gcp/terraform" show "$EVIDENCE_DIR/gcp.tfplan"
# Solo tras leer y aprobar el plan exacto:
terraform -chdir="$LAB_ROOT/gcp/terraform" apply -lock-timeout=60s "$EVIDENCE_DIR/gcp.tfplan"
terraform -chdir="$LAB_ROOT/gcp/terraform" output -json > "$EVIDENCE_DIR/gcp-outputs.json"
GCP_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["http_url"]["value"])' "$EVIDENCE_DIR/gcp-outputs.json")"
curl --fail --show-error "$GCP_URL/health"
python3 "$LAB_ROOT/scripts/capture.py" live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --output "$EVIDENCE_DIR/gcp-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider gcp --input "$EVIDENCE_DIR/gcp-live.json"
```

Mostrar VPC global propia, subnet regional, firewall exclusivo TCP8080 al network tag de la VM desde CIDR docente, VM zonal con disco standard y dirección IPv4 externa efímera. No hay regla SSH ni claves SSH obligatorias: OS Login está indicado, pero no se otorgan roles ni se configura acceso de administración. VM sin service account; metadatos solo contienen configuración/app sin secretos. Bucket con prevención pública `enforced`, acceso uniforme, sin miembros `allUsers` ni `allAuthenticatedUsers`, `force_destroy=false`. No subir objetos ni habilitar acceso público. HTTP depende de apt y del script de arranque: conservar el fallo como fallo, no convertirlo en un fixture live.

## Variables, módulos, estado y locking (15 min)

Abrir los dos `variables.tf` y mostrar validación de lab_id y CIDR, distinción región/zona, rutas públicas Azure y tamaños pequeños permitidos. Abrir `outputs.tf`, explicar consumo vía `terraform output -json` y su envoltura `value`. La misma variable `lab_id` conecta propiedad, inventario, bucket y aislamiento, no permite compartir estado entre providers.

Los dos directorios son módulos raíz; provider y backend son decisiones del root, `templatefile` no es un módulo. Dibujar una interfaz de hipotético módulo hijo `network` (entrada CIDR, salidas identificador subnet/red), y explicar por qué las salidas no convierten NSG en firewall GCP. No invertir la sesión en extraer módulos triviales ni usar librerías públicas no revisadas.

Mostrar configuración de backends existentes sin exponer estado. Locking protege escritores concurrentes al **mismo** estado, no coordina estados diferentes que accidentalmente apunten a los mismos recursos: lab_id único sigue siendo necesario. Planes/estado contienen datos sensibles aunque un output no esté marcado `sensitive`. No mostrar a IA ni añadir a Git. No provocar conflictos de lock en un estado docente compartido: explicar el mensaje de bloqueo o usar captura autorizada previa. Un lock no se fuerza fuera sin comprobar propietario y ejecución activa.

## Costes · fichas sintéticas y conducción (18 + 18 min)

Usar los pasos de consola del README, con el docente compartiendo la vista. Separar coste acumulado real, estimación, créditos e impuestos; no llamar “gratis” a una VM pequeña. Azure: ámbito suscripción/grupo, servicio, región, tags cuando disponibles; presupuesto/periodo/umbrales real y previsto, verificar destinatario y canal existentes. GCP: cuenta Billing/proyecto, servicio/SKU, etiquetas cuando disponibles; presupuesto/periodo/umbrales y destinatarios autorizados. Revisar formularios sin guardar ni enviar alertas. Revisar con la clase que ningún presupuesto apaga automáticamente el gasto y que hay latencia entre consumo, informe y notificación.

Si faltan permisos o cargos recientes, las siguientes cifras son **inventadas, NO precios ni facturas verificadas**. Se usan exclusivamente para practicar agrupación, filtros y decisión de alerta. No inferir equivalencia de precio entre clouds.

| Proveedor | Ámbito sintético | Servicio/concepto | Coste ficticio EUR | Etiqueta de docencia |
|---|---|---|---:|---|
| Azure | rg-demo, westeurope | VM, intervalo de muestra | 0,40 | lab_id=demo01 |
| Azure | rg-demo, westeurope | Disco del SO | 0,12 | lab_id=demo01 |
| Azure | rg-demo, westeurope | IPv4 pública | 0,10 | lab_id=demo01 |
| Azure | rg-demo, westeurope | Blob/operaciones/egress | 0,03 | puede no estar en toda línea |
| GCP | proyecto-demo, europe-west1 | Compute Engine | 0,35 | lab_id=demo01 |
| GCP | proyecto-demo, europe-west1 | Persistent Disk | 0,08 | según disponibilidad |
| GCP | proyecto-demo, europe-west1 | IPv4 externa | 0,10 | según disponibilidad |
| GCP | proyecto-demo, europe-west1 | Cloud Storage/egress | 0,04 | según disponibilidad |

Ejercicio guiado: sumar cada proveedor, filtrar solo computación y explicar qué costes quedan si se apaga VM. Proponer un presupuesto ficticio de 5 EUR con umbrales reales 50/80/100 % y previsto 100 %, identificar destinatario institucional autorizado **sin escribir correos reales en entregables**. Preguntar qué pasa si el informe aún refleja 0 EUR: no prueba gratuidad ni limpieza. Volver a costes de control-plane, nodos, load balancers, discos y tráfico en sesiones AKS/GKE; no desplegar clústeres aquí.

## Destrucción segura y comprobación de solo lectura

Conservar outputs antes de destroy para identificar almacenamiento. **Nunca ejecutar `az group delete`, eliminar proyecto/bucket backend, resetear Academy ni limpiar recursos compartidos.** Solo `terraform destroy` del root, backend, lab_id y workspace exactos. Revisar plan de destrucción antes de confirmar y no usar `-auto-approve`. Azure puede eliminar datos al borrar la cuenta: no existe en este root un `force_destroy` protector; por eso se mantiene vacía y se inspecciona antes. Si aparece contenido inesperado, **parar**, confirmar propietario y conservarlo; no vaciarlo automáticamente para que destroy pase.

```bash
AZ_STORAGE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["storage_account"]["value"])' "$EVIDENCE_DIR/azure-outputs.json")"
# Debe responder correctamente y mostrar []: incluye blobs borrados, snapshots y versiones.
az storage blob list --account-name "$AZ_STORAGE" --container-name private \
  --auth-mode login --include d s v --output json
terraform -chdir="$LAB_ROOT/azure/terraform" workspace show
terraform -chdir="$LAB_ROOT/azure/terraform" state list
terraform -chdir="$LAB_ROOT/azure/terraform" plan -destroy -lock-timeout=60s
terraform -chdir="$LAB_ROOT/azure/terraform" destroy -lock-timeout=60s
terraform -chdir="$LAB_ROOT/azure/terraform" state list
python3 "$LAB_ROOT/scripts/cleanup.py" live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION"

GCP_BUCKET="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bucket_name"]["value"])' "$EVIDENCE_DIR/gcp-outputs.json")"
gcloud storage buckets describe "gs://$GCP_BUCKET" --project "$GCP_PROJECT" --format=json
# Inspeccionar objetos/versiones en consola o con ls; si hay error, no asumir que está vacío.
gcloud storage ls --all-versions "gs://$GCP_BUCKET/**" --project "$GCP_PROJECT"
terraform -chdir="$LAB_ROOT/gcp/terraform" workspace show
terraform -chdir="$LAB_ROOT/gcp/terraform" state list
terraform -chdir="$LAB_ROOT/gcp/terraform" plan -destroy -lock-timeout=60s
terraform -chdir="$LAB_ROOT/gcp/terraform" destroy -lock-timeout=60s
terraform -chdir="$LAB_ROOT/gcp/terraform" state list
python3 "$LAB_ROOT/scripts/cleanup.py" live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --bucket "$GCP_BUCKET"
```

En GCP, `ls` sin coincidencias puede devolver error de “no matched objects”: distinguirlo de permisos/API y confirmar bucket accesible con `describe`; `force_destroy=false` evita borrar automáticamente contenido no vacío. No cambiarlo a `true` para resolver un fallo. Si el proveedor conserva datos por soft delete/retención, revisar política/costes y tiempo de conservación aunque ya no exista el recurso activo; no certificar una factura cerrada por tener inventario vacío.

`cleanup.py` consulta solo lectura. Azure verifica ausencia del **grupo dedicado** y, si existe, enumera todos sus recursos, no solo VMs etiquetadas. GCP consulta VMs, discos, direcciones, VPC, subnets, firewalls por nombre/prefijo exacto del lab y bucket exacto; no audita todos los recursos de la organización ni servicios nunca creados por este root. Una API fallida provoca salida no cero y **VERIFICACIÓN INCOMPLETA**, no “cero recursos”. Recursos restantes provocan salida no cero y deben investigarse con el estado exacto, no eliminarse a ciegas. Volver a consultar tras consistencia eventual sin ocultar fallos.

Destroy no elimina backend, versiones anteriores del estado ni credenciales locales. Conservar evidencia de limpieza autorizada fuera del repositorio; tratar planes/capturas/outputs como privados y retirarlos conforme a política institucional tras la clase. No cometer credenciales, claves, `.terraform`, estado/planes/backend config ni capturas reales.

## Cierre y contingencias

- Evidencia estudiantil: adaptación, filtro y razonamiento semántico del README; distinguir qué observó live, qué fue evidencia docente preparada y qué era sintético.
- Sin red/credenciales/API: actividad estudiantil completa con fixtures. Declarar demostración no ejecutada o incompleta; ningún código hace fallback silencioso. Terminar recursos que sí se hayan creado mediante el estado autorizado cuando el acceso esté recuperado y mantener incidencia visible mientras no se pueda verificar.
- El almacenamiento global usa por defecto un sufijo aleatorio persistido en estado (Azure: `upc3` + lab_id sin guiones + 8 hexadecimales, máximo 24; GCP: proyecto + `-c03-` + lab_id + 12 hexadecimales, máximo 60). El mismo estado mantiene nombres estables; estados independientes generan otros sufijos. Red/grupo/VM siguen requiriendo lab_id único. `storage_account_name` (Azure) y `bucket_name` (GCP) son null por defecto; un valor explícito omite el sufijo y debe estar globalmente disponible, no adopta storage existente. Cambiarlo puede reemplazar recursos: revisar el plan. Usar los nombres de outputs conservados para inspección/limpieza; GCP exige `--bucket "$GCP_BUCKET"` y compara ese nombre exacto dentro del proyecto indicado, sin reconstruirlo ni borrar nada.
- La clave pública Azure no habilita conectividad SSH; no desactivar NSG para diagnosticar. En GCP no generar service-account keys para “facilitar” permisos. No introducir Pulumi, Kubernetes ni nuevos despliegues como requisitos; son conversación opcional fuera del tiempo obligatorio.
