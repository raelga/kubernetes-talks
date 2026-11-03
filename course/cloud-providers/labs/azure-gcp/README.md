# 03 · Azure y GCP: transferencia multicloud e IaC

**10/11/2026 · Rael Garcia · 18:00–21:00 Europe/Madrid · M2, con 60 min de M1 integrados.**

El alumnado **no necesita cuentas Azure/GCP ni despliega recursos**. Analiza dos demostraciones docentes preparadas y adapta Python sobre respuestas **sintéticas** locales. No se ha realizado un despliegue cloud para preparar estos archivos. Las cuentas, permisos, cuota, imágenes, región y precios reales deben comprobarse antes de clase: [guía docente](guia-docente.md).

## Objetivo y alcance obligatorio

Transferir el caso de AWS: red propia + VM pequeña que ofrece JSON HTTP con Python estándar en el puerto 8080 + almacenamiento de objetos **privado**, vacío y separado de la aplicación. No hay Docker, Kubernetes, acceso de la VM al bucket, claves en startup ni cambios de IAM. La misma intención no significa recursos intercambiables. Terraform comparte lenguaje y flujo, no estado ni APIs entre proveedores.

El almacenamiento global recibe por defecto un sufijo aleatorio persistido en estado: 8 hexadecimales para Azure (`upc3` + lab_id sin guiones + sufijo, máximo 24 caracteres) y 12 para GCP (proyecto + `-c03-` + lab_id + sufijo, máximo 60). El mismo estado conserva el nombre; estados independientes generan sufijos distintos. Red, grupo de recursos y VM siguen requiriendo un `lab_id` único. `storage_account_name` (Azure) y `bucket_name` (GCP), ambos `null` por defecto, aceptan un nombre exacto globalmente disponible y omiten la generación del sufijo; no adoptan recursos existentes. Cambiar estos valores puede reemplazar almacenamiento: revisar el plan y consultar siempre los nombres reales en outputs, nunca reconstruirlos.

Al finalizar se entrega una tabla razonada de equivalencias, una adaptación Python revisada con IA y evidencia local del filtrado de recursos encendidos. Las demostraciones cloud son del docente; no son dos laboratorios de alta de cuentas. No se añaden requisitos al Proyecto Final ni porcentajes de evaluación.

### Agenda exacta de 180 minutos

| Hora | Min | Actividad |
|---|---:|---|
| 18:00–18:10 | 10 | Recuperar AWS; identidad, red, VM, almacenamiento y alcance docente/alumno |
| 18:10–18:35 | 25 | Demostración Azure: plan preparado, recursos, salida HTTP, Blob privado |
| 18:35–18:53 | 18 | Azure Cost Management: filtros, presupuesto, alertas y limpieza |
| 18:53–19:18 | 25 | Demostración GCP: proyecto, VPC regional/zonal, VM y bucket privado |
| 19:18–19:36 | 18 | GCP Cloud Billing: filtros, presupuesto, alertas y limpieza |
| 19:36–20:36 | 60 | **M1: Python, configuración, comparación y revisión con IA**, sin credenciales |
| 20:36–20:51 | 15 | Variables, módulos, outputs, estado remoto y locking en ambos backends |
| 20:51–21:00 | 9 | Destroy preparado docente, verificación de residuos y conclusiones |

El docente puede tener las VMs levantadas antes del inicio y planes/evidencias preparados para evitar esperar al aprovisionamiento. El destroy se realiza y comprueba aunque la clase use evidencias preparadas; si no hubo despliegue, se explica explícitamente que no había recursos que destruir. No ejecutar despliegues para “probar el material”.

## Preparación local del alumnado

Python **3.11+** y editor; ninguna dependencia Python externa, Terraform ni CLI cloud necesarios para la actividad local. El docente necesita además Terraform **>=1.6,<2**, Azure CLI y Google Cloud CLI. Desde la raíz del repositorio:

```sh
cd course/cloud-providers/labs/azure-gcp
python3 --version
python3 scripts/normalize.py fixture --provider azure
python3 scripts/normalize.py fixture --provider gcp --running-only
python3 scripts/normalize.py fixture --provider aws --running-only
```

`fixture` jamás consulta APIs ni necesita credenciales. Imprime origen en stderr y JSON en stdout. La app se puede observar localmente, sin nube: `HTTP_HOST=127.0.0.1 python3 app.py`; en otro terminal, `curl --fail http://127.0.0.1:8080/health`; Ctrl-C la detiene. No abrir el puerto local a otras redes. Los templates de ambas VMs insertan este mismo `app.py`, no una implementación distinta.

## Mapa de transferencia

| Intención | AWS (sesión 2) | Azure | GCP |
|---|---|---|---|
| Identidad y ámbito | Cuenta, principal temporal Academy, IAM | Tenant Microsoft Entra, suscripción, grupo de recursos, RBAC | Organización/carpeta/proyecto, principal, IAM |
| Red | VPC regional, subnet zonal, SG de instancia | VNet regional, subnet, NSG asociado a NIC | VPC global, subnet regional, firewall dirigido por network tag |
| VM | EC2 + AMI + tipo + AZ | Linux VM + imagen + SKU + región | Compute Engine + imagen + machine type + zona |
| Objetos privados | S3 + bloqueo acceso público | Storage Account LRS + container privado, sin claves compartidas | Cloud Storage, acceso uniforme y prevención pública |
| Registro de imágenes (solo equivalencia) | ECR | ACR | Artifact Registry |
| Servicios gestionados (sin desplegar) | RDS / EKS | Azure Database / AKS | Cloud SQL / GKE |
| Frontera de gestión | Recursos etiquetados | Grupo dedicado y tags | Proyecto explícito y labels; no crear/eliminar el proyecto |

Una Azure VM no se considera encendida porque `provisioningState` sea `Succeeded`. El estado de alimentación viene de `powerState` (`VM running`, `VM deallocated`) o del código `PowerState/...` en `instanceView.statuses`. En GCP `status=RUNNING` es encendida y `TERMINATED` es apagada, no un recurso eliminado. Azure `location` es región, GCP `zone` es zona, AWS `AvailabilityZone` es zona: **location conserva el valor del proveedor, no inventa una equivalencia regional**.

## Práctica M1 · 60 minutos

1. **0–10 min: inspeccionar contratos.** Leer `fixtures/*.json` y `scripts/normalize.py`. Identificar rutas de nombre, ubicación y alimentación. Cada fixture es una envoltura `{source, provider, description, data}`: `source=synthetic` identifica datos inventados; `data` es un subconjunto de la respuesta CLI, no una captura real. Azure representa `az vm list --show-details`, GCP `gcloud compute instances list --format=json`, AWS `aws ec2 describe-instances` (contraste, sin nuevo despliegue AWS).
2. **10–25 min: adaptar.** Escribir una copia local fuera del repositorio o una función propia que reciba un proveedor y su respuesta y devuelva registros con **solo** `provider`, `name`, `location`, `state`. Conservar el origen separado de los cuatro campos; ordenar de forma determinista. Inspeccionar el adaptador resuelto después de intentar la adaptación. El esquema admite `running`, `stopped`, `pending`, `stopping`, `suspended`, `terminated`, `unknown`; un valor desconocido no se convierte en `running`.
3. **25–40 min: filtrar y contrastar.** Implementar `running-only` sobre el esquema común, no sobre campos diferentes para cada proveedor. Ejecutar los tres fixtures y contrastar con la tabla de resultados de abajo. Incluir el caso Azure `Succeeded` sin `powerState`: debe dar `unknown` y **no** pasar el filtro. Comprobar que una lista válida vacía produce `[]`, mientras JSON inválido falla con código distinto de cero.
4. **40–50 min: IA bajo revisión.** Pedir al asistente: «Propón una función Python estándar que adapte estos tres esquemas, sin ejecutar comandos cloud ni solicitar credenciales. No confundas estado de aprovisionamiento con alimentación; justifica cada campo y el tratamiento de desconocidos». Compartir únicamente fixtures sintéticos y código, nunca capturas privadas, tokens, estado Terraform ni identificadores de la cuenta docente. Revisar propuesta, citar un error/riesgo concreto y corregirlo; el modelo no es una fuente de verdad del API.
5. **50–60 min: transferir configuración y explicar.** Localizar variables equivalentes y no equivalentes en los dos roots Terraform; explicar por qué GCP exige proyecto/región/zona y Azure una clave **pública** aunque SSH no esté abierto. Entregar salidas normalizadas, resultado del filtro, tabla de equivalencias y breve decisión de revisión de IA. No copiar `description` ni respuestas originales como si fueran resultados esperados.

### Resultados semánticos esperados (no pruebas de copia del origen)

| provider | name | location | state | Pasa `running-only` |
|---|---|---|---|---|
| aws | aws-demo-running | eu-west-1a | running | sí |
| aws | aws-demo-stopped | eu-west-1b | stopped | no |
| azure | azure-demo-running | westeurope | running | sí |
| azure | azure-demo-stopped | westeurope | stopped | no |
| azure | azure-demo-unknown | westeurope | unknown | no |
| gcp | gcp-demo-running | europe-west1-b | running | sí |
| gcp | gcp-demo-stopped | europe-west1-b | stopped | no |

## Lo que observar durante las demostraciones

- Leer el plan antes de `apply`: exclusivamente recursos de este caso; no IAM, APIs habilitadas, cuentas/proyectos, Kubernetes ni backends nuevos. Nombres `upc-2026-cloud-03-<lab_id>`; tags/labels `course=upc-2026`, `lab=cloud-03`, `lab_id` elegido por el docente. Algunos recursos GCP no admiten labels y se identifican por nombre/prefijo exacto.
- CIDR HTTP explícito /24–/32, preferiblemente IP docente /32; jamás `0.0.0.0/0`. Solo TCP 8080. Azure deniega otra entrada, incluido SSH; GCP no crea regla SSH y usa una VPC nueva sin reglas por defecto. La clave Azure es pública, nunca la privada. No son aplicaciones públicas de producción ni tráfico cifrado.
- Leer `terraform output -json`: es una envoltura de outputs con `value`, `type`, `sensitive`, no el esquema de inventario. Ejemplo: `json.load(...)["http_url"]["value"]`. No normalizarla como si fuera una respuesta de VM.
- Las VMs usan Python del sistema, usuario `nobody` y systemd; descarga inicial de paquetes requiere salida a Internet. No usan SDK cloud ni acceden al almacenamiento. Una VM encendida puede no tener HTTP listo: comprobar `/health` separadamente, sin afirmar que estado implica salud.
- Los dos directorios `azure/terraform` y `gcp/terraform` son **root modules independientes**, con sus propios providers, inputs, outputs y estados. Dibujar una posible frontera de módulo hijo (red o aplicación), sus entradas/salidas y límites por proveedor. No hay un módulo universal que oculte diferencias; no es obligatorio crear un módulo hijo artificial. Localizar el uso de `templatefile` y distinguirlo de `module`.
- El estado remoto vive en **backends docentes existentes**, nunca en los buckets de la demo: Blob con lease para locking y GCS con locking de Terraform. La clave/prefijo incluye lab_id y proveedor. Revisar dos planes que compiten por **el mismo** estado solo mediante explicación/evidencia preparada; nunca quitar un lock activo ni simularlo en un estado compartido. Setup concreto: [guía docente](guia-docente.md#estado-remoto-y-autenticación-docente).

## Costes: dos actividades separadas

**Azure, 18 min.** El docente abre *Cost Management + Billing → Cost analysis* al ámbito de la suscripción docente, elige mes actual y coste real, filtra grupo dedicado y luego servicio/región/tag `lab_id` cuando estén disponibles. Comparar VM, disco del SO, IP pública Standard, almacenamiento LRS, operaciones y tráfico saliente. Cambiar agrupación por servicio y fecha; el desglose puede tardar en incorporar nuevos cargos y tags. En *Budgets*, revisar un presupuesto docente existente (o explicar el formulario sin guardarlo): importe y periodo, ámbito/filtros, umbrales de gasto real y previsto, canal y destinatario verificado. No enviar alertas ni crear presupuestos como efecto del script. Relacionar el umbral con cuánto gasto podría acumularse antes de recibir una alerta. Parar/desasignar VM no elimina disco/IP/storage; revisar destroy y residuos.

**GCP, 18 min.** Abrir cuenta de *Cloud Billing → Reports*, filtrar proyecto docente y periodo, agrupar por servicio/SKU; revisar Compute Engine, Persistent Disk, IPv4 externa, Cloud Storage y egress. Añadir filtros de labels cuando existan en el informe; no asumir que todo cargo o recurso tiene labels. En *Budgets & alerts*, revisar presupuesto docente existente o formulario sin guardarlo: proyecto, periodo, importe, umbrales real/previsto y destinatarios autorizados de la cuenta de facturación, verificando quién recibiría el correo y sin enviar notificaciones. Explicar crédito frente a coste bruto y que región/tipo/uso cambian el precio. Destruir VM no basta si quedan discos, IPs o buckets.

En ambos: **facturación con retraso; presupuesto/alerta NO detienen automáticamente el gasto**. No prometer free tier. Si el docente no tiene acceso a Billing o aún no aparecen cargos, usar las fichas sintéticas de la guía docente, indicando que no son una factura ni precios actuales. Academy es AWS: sus indicadores y límites no se extrapolan a Azure/GCP ni garantizan una parada universal.

## Capturas reales, claramente separadas

Solo el docente, con autorización y desde este directorio, puede ejecutar `scripts/capture.py live`. Las instrucciones completas de autenticación, variables y backend están en la guía. La captura ejecuta **solo lectura** con proyecto o suscripción/grupo explícitos y selección exacta de propiedad; no modifica recursos ni usa fallback sintético:

```sh
python3 scripts/capture.py live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION" --resource-group "upc-2026-cloud-03-$LAB_ID" \
  --output "$EVIDENCE_DIR/azure-live.json"
python3 scripts/capture.py live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --output "$EVIDENCE_DIR/gcp-live.json"
python3 scripts/normalize.py live --provider azure --input "$EVIDENCE_DIR/azure-live.json" --running-only
python3 scripts/normalize.py live --provider gcp --input "$EVIDENCE_DIR/gcp-live.json" --running-only
```

La envoltura capturada contiene `source=live`, `provider`, `scope`, `ownership`, `data`. `normalize.py live` procesa el fichero **no llama a la API**: el único paso que consulta es `capture.py live`. Ningún modo convierte errores de autenticación/API en `[]`; los errores son explícitos. Una captura de cero VMs no prueba que no queden otros recursos: para limpieza usar `scripts/cleanup.py live` y revisión de estado, explicados en la guía. Capturas/outputs pueden contener datos de cuenta: fuera de Git y sin compartir con servicios de IA.

## Evidencias y límites

Conservar únicamente entregables locales sin credenciales; no subir `.terraform`, `*.tfstate*`, planes, capturas reales, outputs, `.tfvars`, archivos backend ni claves. No hay despliegue real ni comprobación cloud afirmados en este material. El backend/imagen/SKU/cuota/precio dependen del entorno docente. Extensiones opcionales, fuera de los 180 min: debatir un módulo hijo o contrastar brevemente Pulumi/OpenTofu. No son requisitos ni sustituyen esta práctica.
