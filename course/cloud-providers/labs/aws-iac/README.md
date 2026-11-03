# 02 · AWS: infraestructura pequeña, verificable y eliminable

**5 de noviembre de 2026 · 18:00–21:00 · Rael Garcia · M2, con 60 min de M1 integrados.**

Laboratorio principal del alumnado en **el entorno AWS Academy asignado**, no en una cuenta personal. El objetivo es leer y cambiar IaC preparada, consultar recursos con Python y destruir únicamente lo creado por este ejercicio. **Este laboratorio completo de red/EC2/HTTP no se ha probado contra AWS.** En un ensayo S3 aislado con el mismo rol Academy se comprobó crear un bucket privado/cifrado con ownership enforced, refrescar con un plan sin cambios y destruirlo mediante `hashicorp/awscc` 1.108.0; esa prueba no acredita EC2, bootstrap, HTTP ni Billing. Las fixtures son **sintéticas**, no evidencias de una ejecución cloud.

## Caso y límites

```text
Tu IPv4 /32 ── HTTP:80 ── Internet Gateway ── subred ── EC2 Ubuntu/Python
                                                        sin SSH ni rol IAM
Credenciales temporales del cliente ── API AWS ── S3 privado y cifrado
```

Terraform crea una VPC y subred propias, Internet Gateway, tabla/ruta/asociación, grupo de seguridad, EC2 con disco cifrado y un bucket S3 vacío con bloqueo público completo, AES256 y ACL deshabilitadas. El servidor usa la biblioteca estándar de Python y systemd, **sin Docker**. S3 no aloja la web y EC2 no accede a S3: son dos recursos distintos consultados desde tu cliente autorizado. No se crea ni modifica IAM, una key pair ni un instance profile.

HTTP es texto claro: no introducir datos personales, tokens ni contraseñas. Solo se admite el puerto 80 desde tu IPv4 pública `/32`; no se abre SSH. La salida TCP 80/443 permite instalar Python desde Ubuntu y la salida DNS está declarada. No hay NAT Gateway, balanceador, Elastic IP ni Kubernetes. La IP pública efímera, el disco, la instancia y el tráfico pueden generar costes; detener EC2 **no** elimina sus discos ni equivale a limpiar el ejercicio.

Cada recurso lleva `course=upc-2026`, `lab=cloud-02`, `lab_id=<tu-identificador>`. Usa un `lab_id` único en la cuenta, también entre regiones. Por defecto el bucket incluye cuenta, identificador y un sufijo aleatorio de 12 hexadecimales, guardado en estado: los planes del mismo estado mantienen el nombre y un estado independiente genera otro sufijo. Solo el almacenamiento global recibe este sufijo; no sustituye el aislamiento de redes/VM por `lab_id`. `bucket_name = "nombre-global-disponible"` permite indicar un nombre exacto sin generar sufijo; `null` es el valor predeterminado. El nombre personalizado debe estar disponible globalmente: no adopta un bucket existente. Cambiar esta variable puede reemplazar el bucket; revisar el plan y usar siempre `bucket_name` de los outputs para inventario/limpieza. La coincidencia de etiquetas no autoriza a borrar recursos de otra persona.

## Antes de clase

- Acceso Academy verificado desde sesión 1. El docente confirma el tipo real de laboratorio, región, AMI Ubuntu 24.04 x86_64, tipos EC2 y cuotas permitidos; **no hay una lista universal válida para todos los Academy**.
- El docente verifica permisos para AWS Cloud Control API y las operaciones S3 subyacentes de `awscc_s3_bucket`, además de EC2/red y del inventario. El proveedor oficial `hashicorp/awscc` gestiona el bucket por esa API soportada. `hashicorp/aws` 5.100.0 intentó leer `s3:GetBucketObjectLockConfiguration` para `aws_s3_bucket` sin habilitar Object Lock y encontró un deny de SCP; el ensayo aislado de Cloud Control sí completó el ciclo con el mismo rol, sin cambios IAM ni de SCP. No se necesita relajar esa protección, pero el resultado no garantiza permisos en todos los Academy ni sustituye el preflight completo.
- Terraform `>=1.6,<2`, Python `>=3.11`, AWS CLI v2, editor y conexión con salida a AWS y a repositorios Ubuntu. Python no necesita paquetes externos.
- Copia de trabajo y estado locales exclusivamente tuyos. No ejecutes desde una carpeta de estado compartida ni desde el entorno de contenedores que se conservará para sesiones 4–5.
- Credenciales temporales suministradas por el laboratorio: configura el mecanismo indicado en Academy, incluido `AWS_SESSION_TOKEN` cuando corresponda. No las pongas en HCL, user-data, Git, capturas, prompts de IA ni ficheros del ejercicio. No es necesario un perfil AWS nombrado. No uses `aws configure` para persistir secretos si el entorno indica variables temporales.

Todos los comandos siguientes parten de `course/cloud-providers/labs/aws-iac`, desde la raíz de este repositorio. Antes de usar `python3`, comprueba que apunta a Python 3.11 o posterior (en algunos macOS el Python del sistema es anterior).

```sh
terraform version
python3 --version
aws --version
aws sts get-caller-identity --region us-east-1
```

La última llamada es **real y de solo lectura**. Sustituye la región por la autorizada. Contrasta la cuenta/identidad con el laboratorio. Ante credenciales caducadas o `AccessDenied`, detente y consulta las instrucciones reales: no pruebes cuentas ajenas ni relajes políticas. El modo offline de abajo es una actividad distinta, no un reemplazo silencioso del resultado cloud.

## 0–65 min · Leer, planificar, desplegar

### 1. Leer y configurar

Identifica en `main.tf` y `versions.tf`: referencias entre recursos, `default_tags` para los recursos del proveedor AWS y etiquetas explícitas equivalentes en `awscc_s3_bucket.private`, AMI oficial de Canonical, ausencia de IAM, `/32`, disco cifrado y protecciones S3. El bucket y sus tres configuraciones de seguridad se declaran juntos mediante AWS Cloud Control API; EC2/red e identidad siguen usando `hashicorp/aws`. `user-data.sh.tftpl` instala `python3` con apt y ejecuta `app.py` con un usuario sin privilegios y capacidad limitada para abrir el puerto 80. La configuración pública se entrega como JSON codificado en base64, **no cifrado ni secreto**.

Copia `terraform.tfvars.example` como `terraform.tfvars` con el editor y cambia:

- `aws_region`: exactamente la región permitida.
- `lab_id`: 3–20 caracteres en minúsculas, empezando por letra; p. ej. `ana-red-01`. No uses el ejemplo de otra persona.
- `client_cidr`: tu IPv4 pública de salida seguida de `/32`, obtenida desde el método autorizado por el docente. `203.0.113.10/32` es **documental**, no una dirección para desplegar. Si usas VPN/NAT o cambias de red, esa dirección puede variar. Una IP privada de tu portátil no sirve.
- `instance_type`: tipo pequeño permitido, de la lista validada en `variables.tf`. `t3.micro` es un valor de partida, **no una promesa de disponibilidad ni gratuidad**.
- `ami_id`: déjalo sin definir para buscar Ubuntu 24.04 x86_64 de Canonical. Si Academy restringe la búsqueda, el docente suministra una AMI Ubuntu compatible, de la región y autorizada. Otra distribución no sirve para este bootstrap apt/systemd. No sustituyas una AMI para esquivar restricciones.

### 2. Inicializar y revisar sin crear todavía

```sh
terraform init
terraform workspace show
terraform validate
terraform plan -out=apply.tfplan
terraform show apply.tfplan
```

`init` descarga `hashicorp/aws` `>=5.80,<6` para identidad/EC2/red, `hashicorp/awscc` `>=1.108,<2` para S3 y `hashicorp/random` `>=3.6,<4` para el sufijo, y actualiza `.terraform.lock.hcl`; conserva el lockfile de tu trabajo para reproducibilidad. Ambos proveedores AWS usan `var.aws_region` y las credenciales temporales autorizadas. Este ejemplo usa **estado local**, sin backend remoto. Confirma que es tu carpeta/estado y el workspace `default` previsto para este ejercicio. No selecciones otro workspace porque contenga recursos compartidos.

`validate` comprueba configuración, **no permisos ni presupuesto**. `plan` sí consulta APIs; revisa región, etiquetas, tipo, origen `/32` y que no importa/destruye infraestructura ajena. Es normal ver la ruta de salida `0.0.0.0/0`: no es una entrada abierta del SG. Explica esa diferencia antes de continuar. El plan guardado contiene datos de configuración: no lo subas.

### 3. Aplicar únicamente el plan revisado

```sh
terraform apply apply.tfplan
terraform output
terraform output -json > outputs.local.json
```

`apply` crea recursos facturables y no debe ejecutarse en una cuenta sin autorización. Si cambia una variable, el plan anterior **no** recoge ese cambio: genera y revisa uno nuevo. Terraform termina antes de que apt/systemd estén necesariamente listos. Espera unos minutos y comprueba el HTTP durante el bloque Python; no añadas reintentos que oculten un servicio roto. No se necesita SSH.

El estado contiene identidades y metadatos necesarios para gestionar recursos: guárdalo hasta completar la limpieza. No publiques `terraform.tfvars`, `outputs.local.json`, `.terraform/`, estados, logs con credenciales ni planes. Los outputs `http_url`, `instance_id`, `bucket_name`, IDs de red, cuenta y disco permiten verificar exactamente este despliegue.

## 65–125 min · M1: Python y revisión con IA (60 minutos)

### A. Leer datos sin credenciales (15 min)

```sh
python3 inventory.py --fixture-dir fixtures --lab-id demo-aws --region us-east-1
```

No usa AWS CLI ni hace peticiones HTTP. `fixtures/ec2.json` agrupa las respuestas EC2 por operación y `fixtures/s3.json` agrupa tagging, bloqueo, cifrado y ownership. Ambos declaran `synthetic=true`; `fixtures/outputs.json` conserva el formato `{nombre: {value, type, sensitive}}` de Terraform con IDs inventados y direcciones reservadas para documentación. La salida dice `offline-synthetic-NO-CLOUD-VERIFICATION`, **nunca éxito en una cuenta AWS**.

Lee en `inventory.py` la llamada `subprocess.run` sin shell, la lista de filtros de etiquetas, el desempaquetado de `Reservations → Instances` y la diferencia entre error de API y ausencia de bucket. Identifica por qué `AccessDenied` no puede significar «no queda nada».

### B. Fallo de datos y revisión asistida (25 min)

Haz una copia local de la carpeta `fixtures` llamada `fixtures-local` y edita **esa copia**, no los originales:

1. Cambia `instances.Reservations[0].Instances[0].State.Name` de `running` a `stopped` en `ec2.json`.
2. Ejecuta el comando anterior con `--fixture-dir fixtures-local`; debe terminar distinto de cero. En un shell puedes consultar el código con `echo $?` inmediatamente después.
3. Restaura `running`; vacía `instances.Reservations`. Repite: faltar la instancia también debe fallar.
4. Restaura los datos y cambia `BlockPublicPolicy` a `false` en `s3.json`. Repite: seguridad incorrecta no puede ser éxito.
5. Restaura todo; explica qué cambia si el JSON no es válido.

Pide a la IA, **solo con fixtures sintéticas**, que explique o proponga una mejora pequeña de presentación (por ejemplo, mostrar el número de recursos por tipo). Revisa el diff: conserva filtros, modo offline explícito, fallo no cero, ausencia de mutaciones y validación del JSON/HTTP. Contrasta manualmente con las tres entradas defectuosas antes de aceptar su propuesta. No pidas credenciales ni un `except: pass`; no conviertas «API inaccesible» en lista vacía. Entrega el fragmento revisado y el razonamiento, no una conversación con secretos. La modificación es del alumno; el script base ya es funcional.

### C. Contrastar con AWS real y la aplicación (20 min)

Con credenciales vigentes y los outputs de **tu** `apply`:

```sh
python3 inventory.py --live --outputs outputs.local.json --lab-id TU-LAB-ID --region TU-REGION
python3 inventory.py --live --outputs outputs.local.json --lab-id TU-LAB-ID --region TU-REGION --probe-http
```

Sustituye los dos valores en mayúsculas, sin copiarlos literalmente. El script comprueba cuenta de STS, región, `lab_id`, filtros `course/lab/lab_id`, IDs exactos de instancia/red/disco, estado `running`, asociación/ruta, IMDSv2, SG `/32`, disco cifrado y protecciones S3. Una instancia detenida, recurso esperado ausente, recurso extra con tus etiquetas, API denegada o JSON malformado produce código no cero. `--probe-http` añade una petición explícita de 5 s a la IP de EC2 sin proxy ni redirecciones y compara proveedor, mensaje, lab_id y estado. Sin esa opción, el inventario **no demuestra que la aplicación responda**. No comprueba todos los recursos de la cuenta: revisa las etiquetas del ejercicio y el bucket exacto guardado en outputs.

EC2 `running` no demuestra que apt haya terminado. Si falla HTTP, distingue bootstrap pendiente, IP pública del cliente cambiada, ruta/SG y servicio muerto. El docente puede consultar el registro de sistema de **esa EC2** en consola (Actions → Monitor and troubleshoot → Get system log); su disponibilidad depende del laboratorio. No abras SSH ni otorgues un rol para «arreglarlo». Si el bootstrap falla, corrige la causa permitida y revisa el reemplazo antes de aplicar.

También puedes leer y lanzar la misma app **localmente**, sin cloud ni credenciales:

```sh
python3 app.py --host 127.0.0.1 --port 8080
```

Visita `http://127.0.0.1:8080/` y `/health`; termina con Ctrl-C. El modo local usa `lab_id=local`; no es evidencia de EC2.

## 125–145 min · Cambio, reconciliación y fallo de red controlado

1. Cambia `message` por otro texto público en `terraform.tfvars`.
2. Ejecuta `terraform plan -out=change.tfplan` y `terraform show change.tfplan`. La configuración de arranque cambia y `user_data_replace_on_change=true` solicita **reemplazar EC2**: no es un despliegue en caliente. Predice cambio de IP e impacto en el disco.
3. Aplica solo el plan revisado: `terraform apply change.tfplan`. Regenera `outputs.local.json` con `terraform output -json > outputs.local.json`, espera el bootstrap y repite el inventario real con HTTP. Verifica el nuevo mensaje. Un plan posterior sin cambios debe mostrar convergencia, no «reaplicar por si acaso».
4. Inyecta un fallo **solo de tu SG**: cambia temporalmente `client_cidr` al documental `192.0.2.10/32`, revisa un plan `network.tfplan` y aplícalo. Guarda de nuevo los outputs. El inventario sin HTTP puede ser correcto respecto a la nueva configuración; `--probe-http` desde tu cliente debe fallar. Es un fallo de conectividad intencionado, no un servicio arreglado.
5. Restaura tu `/32` real, genera/revisa/aplica un plan nuevo y vuelve a guardar los outputs. Repite la sonda. Nunca uses `0.0.0.0/0` para resolver el fallo.

Si quedan pocos minutos, el docente prioriza el cambio de mensaje y realiza el fallo `/32` como demostración; la lectura de su causa y recuperación forma parte del cierre, no una exigencia de ampliar el caso.

## 145–165 min · AWS Billing, Cost Explorer y Budgets (20 min)

No esperes que una sesión recién creada aparezca al instante en facturación. Sigue la consola habilitada por el docente:

1. **Billing and Cost Management → Bills**: selecciona mes y cuenta; localiza EC2, EC2-Other/EBS, S3, dirección IPv4 pública y transferencia según la clasificación disponible. Distingue uso horario de instancia, GiB-mes de disco, horas de IPv4, peticiones/almacenamiento S3 y tráfico. El bucket vacío no implica coste total cero del caso.
2. **Cost Explorer → Cost and usage**: intervalo de esta semana/mes, granularidad diaria, coste no amortizado si está disponible; agrupa por servicio y filtra región. Añade etiquetas `course`, `lab`, `lab_id` cuando estén habilitadas como etiquetas de asignación de costes. Su activación y aparición pueden requerir permisos/tiempo: no son retroactivas universalmente ni un inventario de recursos en tiempo real.
3. **Budgets → Create budget → Cost budget**: el docente muestra la configuración de un presupuesto mensual de ejemplo (p. ej. 5 USD, importe didáctico, **no garantía**), alcance cuenta/etiquetas admitidas y alertas de gasto real al 50/80/100 % y previsto al 100 %. Revisa el correo destinatario con el propietario y, si se crea una suscripción que requiere confirmación, su confirmación. No introduzcas direcciones ajenas. El alumnado no crea presupuestos ni envía avisos sin permiso; si el rol lo impide, sigue la demostración docente. No se configura ninguna acción automática de presupuesto.
4. Relaciona un filtro de coste con el inventario, explica qué seguiría cobrando una EC2 detenida y localiza el `destroy` posterior. Una alerta **no detiene automáticamente el gasto**. Tampoco el indicador de Academy garantiza una política universal de parada: aplica las reglas reales del laboratorio.

Si Academy deniega Billing/Cost Explorer/Budgets, usa la pantalla autorizada del docente o esta **muestra completamente sintética** (no tarifa vigente ni factura):

| Día ficticio | Servicio/concepto | Región | Etiquetas | Coste ficticio USD |
|---|---|---|---|---:|
| 05/11 | EC2, tiempo de cómputo | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0,04 |
| 05/11 | EBS, almacenamiento | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0,01 |
| 05/11 | IPv4 pública, horas | us-east-1 | sin asignar en esta muestra | 0,01 |
| 05/11 | S3, peticiones | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0,00 |

Agrupa los 0,06 USD por concepto, prueba el filtro de región y explica por qué el filtro por etiquetas podría ocultar la fila sin asignar. Para estimar costes reales se consultan precios de región/tipo y duración previstos; esta tabla no permite afirmar gratuidad ni medir el gasto propio.

## 165–180 min · Destruir y comprobar lo que queda

No pulses **Reset**, no cierres un laboratorio compartido ni borres el entorno preparado para contenedores. Destruye solo el estado local de este ejercicio, desde la misma carpeta y workspace:

```sh
terraform workspace show
terraform state list
terraform output -json > outputs.before-destroy.local.json
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
python3 inventory.py --live --outputs outputs.before-destroy.local.json --lab-id TU-LAB-ID --region TU-REGION --expect absent
terraform state list
```

El plan de destrucción debe contener **solo tus recursos cloud-02**. El fichero de outputs se guarda **antes**, porque después desaparecen los outputs del estado. No uses el de antes de un reemplazo de EC2: contiene IDs e IP antiguos. Conserva estado y outputs hasta que el borrado y su comprobación terminen correctamente.

La comprobación consulta las siete familias EC2 por las tres etiquetas y el bucket exacto. Tolera que EC2 siga mostrando instancias `terminated`, no `stopped` ni `shutting-down`; exige ausencia de disco, VPC, subred, gateway, tabla y SG propios. `NoSuchBucket` significa ausencia S3; `AccessDenied`, token caducado o error de red **son fallo, no limpieza**. Si la consistencia de API demora el resultado, espera y vuelve a consultar explícitamente; no alteres el script para devolver éxito. El estado debe quedar sin recursos; una lista vacía local por sí sola no acredita limpieza cloud.

El bucket nace vacío. [`awscc_s3_bucket`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/s3_bucket) solo puede eliminar un bucket vacío: no tiene un atributo `force_destroy` ni vacía objetos automáticamente. Si alguien añadió objetos, la eliminación falla; el docente debe revisar exclusivamente ese bucket y acordar la retirada explícita de esos objetos. No hay borrado masivo automático. No borres estado para ocultar recursos ni ejecutes `destroy` en otro directorio.

### Evidencias mínimas

- Breve mapa de red/cómputo/almacenamiento e identidad; explicación de `/32`, S3 privado y ausencia de IAM en EC2.
- Extracto saneado del plan inicial y del reemplazo por cambio de mensaje; justificación de la reconciliación.
- Resultado offline marcado sintético, fallo inyectado y revisión de la propuesta de IA; resultado real separado, sin secretos.
- Filtros de costes y diseño de alerta con sus limitaciones, distinguiendo muestra de consulta real.
- Destrucción y consulta posterior con expectativa `absent`; incidencias de permisos o recursos pendientes documentadas honestamente. No publiques planes/estado/credenciales para aportar evidencias.
