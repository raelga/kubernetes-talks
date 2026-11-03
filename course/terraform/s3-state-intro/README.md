# Terraform: de estado local a un backend S3

Práctica autónoma de **90 minutos** para aprender el ciclo `init → plan → apply`, cambios declarativos, drift, estado y bloqueo. Solo requiere Terraform, AWS CLI y S3; no necesita EC2, Kubernetes, Python ni crear o modificar IAM. La [guía docente](guia-docente.md) incluye tiempos, preparación y criterios de observación.

**Verificado en AWS Academy:** con `hashicorp/awscc` 1.108.0 se completó el recorrido real: bucket con nombre generado, bucket con nombre exacto, versionado, objeto privado y cambios, detección/reconciliación de drift, migración local → S3 con IDs estables y plan sin cambios, estado AES256 con VersionId, exclusión concurrente mediante `.tflock`, guard de destrucción y retirada completa. Se eliminaron ambos buckets y todas las versiones/marcadores del estado y lock; se comprobó que no quedaban buckets del ensayo. AWS 5.100.0 había fallado en su recurso de bucket por una lectura opcional de Object Lock denegada por SCP; el recurso oficial de Cloud Control funcionó con el mismo rol, sin modificar IAM ni las protecciones. Los permisos de otros laboratorios Academy deben verificarse igualmente.

## Dos raíces independientes, dos responsabilidades

| Ruta | Recursos | Estado inicial | Destino del estado |
| --- | --- | --- | --- |
| `bootstrap/` | Bucket privado del backend, cifrado SSE-S3, ACL deshabilitadas, bloqueo público y versionado configurable | Local | **Siempre local**, fuera de Git y con copia segura externa |
| `exercise/` | Otro bucket privado con las mismas protecciones y el objeto `hello.txt` | Local | S3, solo al completar la migración guiada |
| `files/hello.txt` | Contenido del objeto del ejercicio | No es estado | Archivo didáctico versionado |

Por defecto (`bucket_name = null`), los nombres son `tfstate-<cuenta>-<lab_id>-<12hex>` y `tfexercise-<cuenta>-<lab_id>-<12hex>`. Cada raíz genera su propio sufijo con `random_id`, 6 bytes persistidos en su estado: dos personas con estados independientes obtienen nombres distintos aunque compartan cuenta y `lab_id`. No se utilizan timestamps ni `uuid()` que cambien en cada plan. Con el máximo de 20 caracteres de `lab_id`, los nombres ocupan como máximo 54 y 57 caracteres, por debajo del límite S3 de 63. Elige un identificador pedagógico reconocible; ya no necesitas coordinar su unicidad.

Opcionalmente, `bucket_name = "nombre-exacto-propio-disponible"` omite el sufijo y usa **ese nombre exacto** en la raíz correspondiente. Debe estar globalmente disponible, respetar las reglas S3 (la validación de entrada comprueba longitud/sintaxis básica y AWS/proveedor las restricciones finales) y ser distinto del otro bucket. Esto no adopta ni importa un bucket existente. Cambiar el nombre, la cuenta o el identificador tras crear recursos puede requerir sustitución; `prevent_destroy` bloquea la del backend. No lo retires para resolver un cambio accidental.

Conserva siempre el estado: contiene también el sufijo aleatorio. Copiar un estado **no crea una ejecución independiente**; copia la identidad y hace que ambos directorios gestionen los mismos recursos. Cada nueva ejecución independiente parte de su propio estado, mientras que una reanudación usa el estado original. No borres estados para conseguir otro nombre. Obtén los nombres reales con los outputs para configurar el backend, consultar S3 y limpiar; nunca los reconstruyas a mano a partir de cuenta/identificador. En cada raíz, `aws_caller_identity` y la precondición del bucket comparan la cuenta activa con `account_id`; el proveedor AWS y el backend también comprueban la cuenta esperada. AWSCC no dispone de `allowed_account_ids`, por eso la precondición es necesaria.

El bucket del estado tiene `prevent_destroy = true`; el del ejercicio no, para permitir su retirada revisada. `awscc_s3_bucket` solo elimina buckets vacíos y no tiene atributo `force_destroy`: no vacía objetos ni versiones automáticamente. Ninguno tiene ACL públicas, políticas públicas ni credenciales en código. El versionado del backend empieza suspendido (`Suspended`) para ver el cambio declarativo y **se activa antes de utilizar el backend**. Suspenderlo después no borra las versiones anteriores y no forma parte de la práctica.

## Requisitos y preflight de AWS Academy

- Terraform **>= 1.10 y < 2.0**; proveedores `hashicorp/awscc` **>= 1.108 y < 2.0**, `hashicorp/aws` **>= 5.80 y < 6.0** y `hashicorp/random` **>= 3.6 y < 4.0**. AWSCC administra los buckets mediante AWS Cloud Control; AWS conserva identidad y objetos S3; Random conserva los sufijos. AWS CLI v2 configurada con las credenciales temporales del laboratorio, mediante su mecanismo autorizado, nunca en archivos HCL ni en Git.
- Terminal en `course/terraform/s3-state-intro` del repositorio `raelga/kubernetes-talks`. Todos los comandos siguientes parten de esa carpeta; `-chdir` identifica siempre la raíz afectada.
- Confirmar con el docente el tipo de laboratorio, región permitida, vencimiento/renovación de credenciales, persistencia entre sesiones, límites de tiempo/presupuesto y procedimiento de limpieza. No se presupone que todos los laboratorios Academy permitan lo mismo.
- El docente debe comprobar previamente permisos de creación y configuración S3: etiquetas, bloqueo de acceso público, ownership `BucketOwnerEnforced`, cifrado y versionado; además de consulta y eliminación revisada de los recursos del ejercicio. No se solicita ampliar permisos ni crear roles/policies.
- Comprobar también los permisos de AWS Cloud Control y el ciclo de creación/lectura/actualización/borrado de `awscc_s3_bucket` con el rol autorizado. El recurso agrupa las protecciones del bucket; no usa el recurso `aws_s3_bucket` cuya lectura opcional de Object Lock falló en el ensayo con AWS 5.100.0. El deny SCP sigue intacto: no ampliar IAM, desactivar protecciones ni ocultar errores de permisos. El resultado del rol probado no presupone permisos idénticos en todos los laboratorios Academy.
- Para el backend se necesitan `s3:ListBucket` sobre el bucket, `s3:GetObject` y `s3:PutObject` sobre **la clave exacta** `exercise/terraform.tfstate`; `s3:GetObject`, `s3:PutObject` y `s3:DeleteObject` sobre **la clave exacta** `exercise/terraform.tfstate.tflock`. La configuración/consulta de versionado usa `s3:PutBucketVersioning`/`s3:GetBucketVersioning`. La inspección de versiones requiere `s3:ListBucketVersions` y, para recuperar una versión, `s3:GetObjectVersion`. La retirada final requiere permisos específicos de eliminación de versiones, no necesarios para el trabajo cotidiano con el estado.
- No basta con `sts get-caller-identity`: verifica también listar, escribir y recuperar objetos y el ciclo de creación/lectura/borrado del lock. La guía docente explica la comprobación segura; si Academy deniega algo, **parar antes de migrar** y resolverlo con el responsable, sin desactivar el lock ni las protecciones.

```sh
terraform version
aws --version
aws sts get-caller-identity
```

Anota el ID real de cuenta y la región autorizada. Los `.example` contienen valores sintéticos, no recursos existentes. S3 cobra almacenamiento, versiones y peticiones; revisa los límites del laboratorio, Billing/Cost Explorer y alertas disponibles. Los datos de facturación pueden llegar con retraso y un presupuesto **no detiene el gasto automáticamente**.

## 1. Crear el backend como infraestructura, pero con estado local

```sh
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
```

Edita `bootstrap/terraform.tfvars`: cuenta real, región autorizada y `lab_id` reconocible. Mantén `bucket_name = null` para unicidad automática, `enable_versioning = false` y `stage = "basics"`.

```sh
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=private-bootstrap.tfplan
terraform -chdir=bootstrap apply private-bootstrap.tfplan
terraform -chdir=bootstrap output
```

Revisa en el plan el nombre, cuenta/región, etiquetas y protecciones de `awscc_s3_bucket.state`: acceso público bloqueado, ACL deshabilitadas, cifrado y versionado inicialmente `Suspended`; revisa también `prevent_destroy`. Cloud Control solo permite eliminar un bucket vacío. No se crea IAM ni cómputo. Guarda **el directorio y estado local de bootstrap** de forma segura y persistente fuera de Git y de este bucket; perderlos no elimina el bucket, pero sí su vínculo con Terraform. Ni `terraform init -migrate-state` ni un backend S3 se ejecutan nunca en esta raíz.

`fmt` normaliza el formato HCL; `validate` comprueba la configuración y sus tipos, no los permisos ni los costes. `init` descarga proveedores y genera `.terraform.lock.hcl`, mientras `plan` consulta AWS y propone cambios. Solo `apply` ejecuta el plan aprobado.

Ahora cambia en ese mismo `terraform.tfvars`:

```hcl
enable_versioning = true
stage             = "backend-ready"
```

```sh
terraform -chdir=bootstrap plan -out=private-bootstrap-versioning.tfplan
terraform -chdir=bootstrap apply private-bootstrap-versioning.tfplan
export AWS_REGION="us-east-1" # Sustituir por la región real de ambos tfvars.
export STATE_BUCKET="$(terraform -chdir=bootstrap output -raw state_bucket_name)"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

La consulta **de solo lectura** debe devolver `"Status": "Enabled"`; el output Terraform no sustituye esta comprobación. En el primer encendido del versionado AWS recomienda esperar **15 minutos antes de escribir objetos** para evitar problemas de propagación: realiza mientras los apartados 2–3 y respeta ese margen antes del preflight de escritura y la migración. No sigas si sigue suspendido o la consulta es denegada.

## 2. Aplicar el ejercicio con estado local

```sh
cp exercise/terraform.tfvars.example exercise/terraform.tfvars
```

Introduce la misma cuenta, región e identificador; `demo_tag = "initial"`. **No copies todavía los ejemplos del backend.**

```sh
terraform -chdir=exercise init
terraform -chdir=exercise validate
terraform -chdir=exercise plan -out=private-exercise.tfplan
terraform -chdir=exercise apply private-exercise.tfplan
export EXERCISE_BUCKET="$(terraform -chdir=exercise output -raw exercise_bucket_name)"
aws s3api list-objects-v2 --bucket "$EXERCISE_BUCKET" --region "$AWS_REGION"
aws s3api get-object --bucket "$EXERCISE_BUCKET" --key hello.txt --region "$AWS_REGION" exercise/private-hello.download.txt
```

Lee el archivo descargado: debe contener el saludo. El objeto no es público; una URL anónima no es la prueba adecuada. No subas contenido privado al bucket ni al archivo didáctico.

## 3. Cambios y drift, solo sobre el ejercicio

1. Edita `files/hello.txt` con otro saludo y cambia `demo_tag = "updated"` en `exercise/terraform.tfvars`.
2. Ejecuta `terraform -chdir=exercise plan -out=private-change.tfplan`, revisa que cambian el objeto y la etiqueta del **bucket del ejercicio**, y ejecuta `terraform -chdir=exercise apply private-change.tfplan`. Descarga otra vez el objeto con `get-object` para observar el contenido.
3. En la consola S3 selecciona exactamente el bucket `$EXERCISE_BUCKET` (nunca `$STATE_BUCKET`) y modifica únicamente la etiqueta `Demonstration` a `outside-terraform`. Conserva el resto. También puedes usar `get-bucket-tagging` y `put-bucket-tagging` con un archivo privado editado, recordando que `put-bucket-tagging` **sustituye todo el conjunto** de etiquetas.
4. Ejecuta `terraform -chdir=exercise plan -out=private-drift.tfplan`. Debe proponer restaurar `Demonstration = "updated"` sin recrear el bucket. Aplica ese plan para reconciliar el drift. No uses `ignore_changes` ni un refresco de estado para ocultarlo.

```sh
terraform -chdir=exercise output -json > exercise/private-ids.before.json
terraform -chdir=exercise state list
terraform -chdir=exercise state show awscc_s3_bucket.exercise
terraform -chdir=exercise state show aws_s3_object.hello
```

Los outputs registran el nombre/ID del bucket y el ID del objeto; en `state show awscc_s3_bucket.exercise`, `bucket_name` e `id` corresponden al mismo nombre real. Las etiquetas se representan como lista de objetos `key`/`value`; las protecciones están integradas en ese recurso, no son recursos independientes. `terraform -chdir=bootstrap state show awscc_s3_bucket.state` permite contrastar `versioning_configuration.status` con el output `versioning_status` y la consulta AWS de solo lectura. Todo estado, plan, captura de identidad y configuración real se conserva fuera de Git.

## 4. Migrar solamente el estado del ejercicio

Antes de continuar, el docente verifica la espera de propagación, el versionado `Enabled` y los permisos de objetos/lock indicados en el preflight. Confirma que nadie más está operando este backend. Guarda una copia segura del estado local del ejercicio; puede contener información sensible.

```sh
terraform -chdir=exercise state pull > exercise/private-before-migration.tfstate
cp exercise/backend.tf.example exercise/backend.tf
cp exercise/backend.hcl.example exercise/backend.hcl
```

Edita `exercise/backend.hcl` con el **nombre real** de `$STATE_BUCKET`, región y cuenta; conserva `key = "exercise/terraform.tfstate"`, `encrypt = true` y `use_lockfile = true`. No pegues credenciales: backend y proveedor usan la sesión AWS autorizada de forma independiente. Las variables de `terraform.tfvars` no configuran el backend.

```sh
terraform -chdir=exercise init -migrate-state -backend-config=backend.hcl
```

Lee la pregunta de copia de estado de local a S3 y acepta únicamente si origen y destino son los esperados. No uses `-reconfigure` en lugar de `-migrate-state`, `-force-copy`, workspaces adicionales ni migres ningún otro laboratorio. No se recrean recursos: cambia dónde se guarda el registro de los recursos existentes.

```sh
terraform -chdir=exercise output -json > exercise/private-ids.after.json
diff exercise/private-ids.before.json exercise/private-ids.after.json
terraform -chdir=exercise state list
terraform -chdir=exercise plan
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate --region "$AWS_REGION"
aws s3api list-object-versions --bucket "$STATE_BUCKET" --prefix exercise/terraform.tfstate --region "$AWS_REGION"
```

`diff` no debe mostrar diferencias; contrasta también los IDs con los `state show` anteriores. El plan debe indicar **sin cambios**. La consulta S3 debe mostrar el estado, cifrado `AES256` y un `VersionId`. El prefijo también puede listar versiones del lock; distingue las claves exactas. Son criterios que observar en la cuenta, no resultados ya verificados por este repositorio.

### Observar el lock sin provocar una escritura de recursos

1. Cambia temporalmente `demo_tag` a `lock-observation` en los tfvars del ejercicio.
2. Ejecuta `terraform -chdir=exercise apply` **sin** `-auto-approve` y deja abierta la pregunta de aprobación. Este proceso mantiene el lock mientras espera; no respondas todavía.
3. En otro terminal, con las mismas variables de entorno y credenciales autorizadas, observa el objeto:

   ```sh
   aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
   aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION" exercise/private-lock.json
   terraform -chdir=exercise plan -lock-timeout=5s
   ```

   El segundo proceso debe informar del bloqueo, no continuar simultáneamente. El JSON del lock contiene identidad del operador: no compartirlo ni subirlo a Git.
4. Responde **`no`** en el primer terminal, vuelve a poner `demo_tag = "updated"` y repite el `plan`: sin cambios. La ausencia del objeto actual `.tflock` después de liberar el lock es normal; sus versiones históricas pueden persistir. Si hay una interrupción, comprueba primero que ningún proceso siga activo; no borres el lock ni ejecutes `force-unlock` para saltarte una operación legítima.

**Dos locks distintos:** `exercise/terraform.tfstate.tflock` es un objeto temporal S3 para exclusión mutua al operar el **estado**; `.terraform.lock.hcl` registra versiones y checksums de **proveedores**. Este último no bloquea a otros operadores y se versiona una vez generado y revisado para cada raíz. No se necesita DynamoDB con `use_lockfile` y Terraform >= 1.10.

## 5. Fin normal: retirar solo el ejercicio

El bucket de estado **no es** el bucket del ejercicio. Ejecuta únicamente desde `exercise`:

```sh
terraform -chdir=exercise plan -destroy -out=private-destroy.tfplan
terraform -chdir=exercise show private-destroy.tfplan
```

Revisa que solo se eliminan el recurso `awscc_s3_bucket.exercise` del bucket exacto `$EXERCISE_BUCKET`, `aws_s3_object.hello` y el sufijo aleatorio cuando exista, **nunca** `$STATE_BUCKET`. Las protecciones son atributos del bucket, no recursos adicionales. Los prefijos `tfexercise-`/`tfstate-` solo identifican los nombres generados: si usaste `bucket_name`, manda el nombre real obtenido mediante outputs. Solo después de esa revisión:

```sh
terraform -chdir=exercise apply private-destroy.tfplan
terraform -chdir=exercise state list
terraform -chdir=exercise plan
```

Aplicar un plan guardado de destrucción equivale a un `destroy` revisado; no lanza otro plan implícito. Si usas `terraform -chdir=exercise destroy` en su lugar, revisa también su plan interactivo antes de confirmar. No ejecutes ambos. Terraform elimina primero su objeto `hello.txt`; si alguien añadió objetos manuales, Cloud Control rechazará eliminar el bucket no vacío: revisa los objetos exactos antes de eliminarlos. Conserva el backend y el estado local de bootstrap para la siguiente práctica. Aunque no queden recursos, el estado vacío remoto sigue siendo un consumidor del backend.

## Retirada completa y excepcional del backend

No forma parte del cierre normal de los 90 minutos. Solo un responsable puede realizarla, con ventana exclusiva y autorización, **después de inventariar todos los consumidores** y migrarlos a otro backend o destruir sus recursos y retirar también su dependencia de S3. No basta con que `exercise` esté vacío; no presupongas que es el único consumidor.

1. Conserva copias seguras de todos los estados y de la configuración. Para el ejercicio vacío, usa `terraform -chdir=exercise state pull > exercise/private-before-retirement.tfstate`. Sustituye el contenido de su `backend.tf` por:

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

   Ejecuta `terraform -chdir=exercise init -migrate-state` **sin** `-backend-config` y confirma que el backend quedó en `local`. Si hay estado no vacío, acepta y contrasta la copia S3 → local. Si el estado remoto ya está vacío, Terraform puede no solicitar confirmación ni crear un archivo local, y `state pull` puede no emitir JSON: conserva la copia privada previa y verifica que no había recursos gestionados y que ningún consumidor sigue usando S3. También puede migrarse a otro backend aprobado. No retires el bucket sin completar estas comprobaciones.
2. Confirma la cuenta con `aws sts get-caller-identity`, el nombre exacto con `terraform -chdir=bootstrap output -raw state_bucket_name`, y contrasta el inventario de consumidores. Detén toda operación concurrente; no elimines un lock activo.
3. Enumera y revisa **todas las páginas** y claves, versiones y marcadores de borrado del bucket exacto; no solo el prefijo del ejercicio:

   ```sh
   aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-object-versions --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   ```

4. Tras conservar los estados necesarios y autorizar cada eliminación, elimina **manualmente cada versión o marcador revisado** con su clave y `VersionId` exactos. Ejemplo de sintaxis, con marcadores que debes sustituir, **no un comando listo para ejecutar**:

   ```sh
   aws s3api delete-object --bucket NOMBRE_EXACTO_REVISADO --key CLAVE_EXACTA_REVISADA --version-id VERSION_ID_EXACTA_REVISADA --region REGION_REVISADA
   ```

   Una versión cuyo ID sea `null` también se selecciona explícitamente con `--version-id null`. Un borrado sin `VersionId` puede crear otro marcador y no vaciar el bucket. Repite el inventario hasta confirmar que no hay objetos, versiones ni marcadores. No uses `aws s3 rb --force`, borrados recursivos, scripts de vaciado ni reglas lifecycle de purga. AWSCC no ofrece vaciado forzado.
5. **Solo como último cambio de configuración**, retira intencionadamente únicamente `prevent_destroy = true` del bloque `lifecycle` de `bootstrap/main.tf`; conserva la precondición de identidad. Con las copias locales a salvo y el bucket vacío, revisa `terraform -chdir=bootstrap plan -destroy -out=private-retire.tfplan`, inspecciónalo con `terraform -chdir=bootstrap show private-retire.tfplan` y, únicamente si corresponde al bucket autorizado, aplica ese plan. Cloud Control rechazará el borrado si quedan objetos o versiones. Nunca elimines la raíz/configuración completa para sortear `prevent_destroy`: la protección depende de que esa configuración exista.
6. Conserva la evidencia y los estados locales finales de bootstrap y consumidores de acuerdo con la política del laboratorio. No los publiques en Git ni en el bucket recién retirado.

## Higiene del repositorio

Se incluyen ejemplos, código y contenido didáctico; se ignoran `.terraform/`, estados y copias, planes, `terraform.tfvars` privados, `backend.hcl`, el `backend.tf` generado y archivos `private-*`. Los `.example` sí se versionan, igual que los `.terraform.lock.hcl` de cada raíz una vez generados/revisados. El ignore no es un almacén seguro: credenciales, estados y planes requieren custodia fuera de Git y un directorio persistente, especialmente en entornos Academy efímeros. No migres ni modifiques los laboratorios Terraform ya existentes como consecuencia de esta práctica.
