# Guía docente — Terraform y estado S3 en 90 minutos

## Alcance y resultados observables

Práctica introductoria independiente y reutilizable, sin fecha ni número de sesión. Todo el trabajo obligatorio usa Terraform y S3: no se despliegan EC2 ni otros laboratorios, no se requiere Python y no se crea o modifica IAM. No sustituye los laboratorios cloud ni migra sus estados.

Al terminar, el alumnado debe explicar y mostrar:

- Dos raíces independientes: bootstrap con estado local persistente y ejercicio inicialmente local, después remoto.
- Un cambio de etiquetas y la activación del versionado del backend antes de usarlo; una consulta AWS de solo lectura que devuelva `Enabled`.
- Una actualización declarativa de `hello.txt`, drift en una etiqueta del **ejercicio** y reconciliación sin recrear el bucket.
- IDs de recursos iguales antes y después de `init -migrate-state`, estado remoto versionado y un plan sin cambios.
- Un `.tflock` mientras una operación espera aprobación y la negativa de un segundo proceso a operar simultáneamente.
- La diferencia entre lock de estado y `.terraform.lock.hcl`, y un plan de destrucción limitado al ejercicio, sin comprometer el backend.

**Verificación real completada en Academy:** recorrido de buckets, nombre generado y override exacto, versionado, objeto y actualización, drift/reconciliación, migración con IDs estables, estado remoto cifrado/versionado, locking concurrente, cancelación sin aplicar cambios y limpieza completa. También se comprobó que `prevent_destroy` impide retirar accidentalmente el backend. El proveedor oficial `hashicorp/awscc` 1.108.0 resolvió la incompatibilidad de la lectura opcional de Object Lock del recurso AWS 5.100.0 con la SCP, sin cambiar IAM ni protecciones. No quedan buckets del ensayo. El resultado acredita el rol probado, no permisos universales de todos los entornos Academy.

## Preparación antes de los 90 minutos

1. Confirmar el laboratorio Academy concreto: acceso, entrega y caducidad de credenciales temporales, región autorizada, persistencia del workspace y recursos, límites de tiempo/coste y política de limpieza. No asumir un tipo universal de laboratorio ni persistencia de su disco. Preparar custodia privada y externa para el estado local de bootstrap.
2. Disponer de Terraform >= 1.10 y < 2, AWS CLI v2 y acceso a descarga de AWSCC >= 1.108 y < 2, AWS >= 5.80 y < 6 y Random >= 3.6 y < 4. AWSCC administra buckets mediante Cloud Control; AWS administra identidad y objetos; Random conserva los sufijos. No cambiar proveedores de otros ejemplos. Las dos raíces usan bloqueos de proveedores separados; los lockfiles generados y revisados pueden incorporarse al repositorio, nunca el estado.
3. Comprobar identidad y cuenta/región del laboratorio. `allowed_account_ids` protege frente a una cuenta distinta, no frente a una región no autorizada. Por defecto `bucket_name = null` genera cuenta + `lab_id` + 12 hex aleatorios persistidos por raíz; dos estados independientes con los mismos parámetros generan nombres distintos. Los nombres máximos son 54/57 caracteres. No compartir/copiar estados entre alumnos: copiar el estado conserva la misma identidad, no crea otro laboratorio. Custodiar el estado conserva el sufijo al reanudar. Un `bucket_name` no nulo usa el nombre exacto sin aleatoriedad: comprobar disponibilidad global y reglas S3, no interpretarlo como adopción/importación. Cambiar el nombre puede sustituir el recurso; `prevent_destroy` debe bloquear la sustitución del backend, no retirarse para resolverla. Para backend, APIs y retirada, usar siempre outputs reales, nunca reconstruir nombres.
4. Ensayar con un identificador docente propio el ciclo completo y el procedimiento de conservación/retirada. Las etiquetas esperadas son `Project`, `LabId`, `ManagedBy`, `Purpose` y `Stage` o `Demonstration`; los cambios/demos no deben tocar las protecciones privadas.
5. Verificar de antemano permisos de AWS Cloud Control y APIs S3 para crear, leer, actualizar y eliminar buckets vacíos, etiquetas, cifrado AES256, ownership `BucketOwnerEnforced`, bloqueo público y versionado. Las protecciones están integradas en `awscc_s3_bucket`; no se usa la lectura opcional de Object Lock del antiguo recurso AWS. Si Academy restringe estas operaciones, resolver con el responsable del laboratorio: **no** rebajar protecciones, añadir IAM ni hacer un despliegue obligatorio alternativo.
6. Comprobar los permisos de objetos y lock con las credenciales reales y **los prefijos autorizados**. Para el backend: listar bucket, leer/escribir la clave de estado; leer/escribir/borrar la clave `.tflock`; consultar versionado. La consulta de versiones necesita además `ListBucketVersions`. Un `get-object` exitoso en el bucket del ejercicio no demuestra permisos en el backend.
7. Reservar un margen de **15 minutos desde la primera activación de versionado hasta escribir objetos** en ese bucket. El cronograma utiliza ese tiempo para ejercicio y drift. Si la configuración tarda o hay incidencias, terminar después sin omitir el preflight ni prometer que el trabajo ya quedó verificado.

### Preflight de APIs con alcance controlado

Antes de permitir migraciones, comprobar `aws sts get-caller-identity`, `get-bucket-versioning` y `list-objects-v2` sobre el backend real. La consulta de versión debe mostrar `Enabled`; hacerlo después del `apply`, no fiarse solo de la variable o del estado Terraform.

Para ensayar `PutObject`/`GetObject`/`ListBucket` sin introducir un falso archivo de estado, usar un **objeto de prueba no sensible** en un prefijo temporal autorizado, por ejemplo `exercise/preflight.txt`. Este prefijo requiere permisos explícitamente disponibles; no ampliar policies para realizar el ensayo. Los permisos sobre esa clave no acreditan por sí solos los de `exercise/terraform.tfstate`: contrastar también el alcance exacto autorizado y completar el ensayo docente de migración/lectura real con esa misma clave en su backend de prueba. No escribir un archivo de prueba en la clave `.tfstate`.

Ejemplo de APIs para el ensayo docente, tras la espera de propagación y con `STATE_BUCKET`/`AWS_REGION` revisados:

```sh
aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --prefix exercise/ --region "$AWS_REGION"
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --region "$AWS_REGION" exercise/private-preflight.download.txt
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

Registrar el `VersionId` del objeto de prueba. Su eliminación final se hace manualmente por la versión exacta revisada, no con vaciado recursivo; puede conservarse hasta la retirada autorizada del backend.

Para comprobar **la clave exacta del lock**, antes de cualquier consumidor/migración y en ventana exclusiva, confirmar que no existe lock actual con `head-object` y que no hay procesos Terraform activos. Solo entonces el docente puede probar el ciclo API con contenido no sensible sobre `exercise/terraform.tfstate.tflock`: no es un lock Terraform real y nunca debe coexistir con un consumidor. No ejecutar esta prueba sobre un backend ya en uso.

```sh
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
# Continuar SOLO si el responsable confirma ausencia de consumidores y la respuesta es 404.
# Un 403 no demuestra que la clave no exista: detener el ensayo.
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION" exercise/private-preflight-lock.download.txt
aws s3api delete-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
```

El último `head-object` debe devolver 404. Esta prueba de `DeleteObject` crea un marcador en un bucket versionado; la versión de prueba y el marcador seguirán visibles en `list-object-versions` y se revisarán para su retirada manual. El ciclo normal del backend también deja versiones históricas de locks. El objetivo no es borrar sus versiones automáticamente ni desactivar versionado. No confundir la prueba controlada previa con la observación posterior del lock **real**, que solo se lee y que libera el proceso Terraform propietario.

La aceptación del preflight requiere: listar y consultar versionado del bucket exacto, escribir/recuperar el objeto, alcance de get/put confirmado para la clave de estado, ciclo get/put/delete de `.tflock`, y ensayo de migración docente sin cambiar permisos IAM. Si falta un permiso, detenerse antes de migrar al alumnado. Nunca usar `-lock=false`, borrar locks activos ni exponer credenciales para completar una demo.

## Secuencia de 90 minutos

| Minutos | Actividad | Evidencia / intervención docente |
| --- | --- | --- |
| 0–10 | Modelo declarativo, identidad, región, credenciales y costes; copiar/editar tfvars | Cuenta esperada y `lab_id` propio; localizar dos raíces y distinguir estado frente a recursos. Recordar retraso de billing y que presupuestos no cortan gasto. |
| 10–25 | `bootstrap init`, `plan`, revisión y `apply`; cambiar `stage` y habilitar versionado con segundo plan/apply | Privacidad, ACL deshabilitadas, SSE-S3, `prevent_destroy` y borrado limitado a bucket vacío; consulta `get-bucket-versioning = Enabled`. Anotar hora de activación y no escribir aún. |
| 25–40 | Ejercicio con estado local, lectura privada del objeto, cambio de saludo y etiqueta | Segundo bucket distinto; `source_hash` detecta contenido; IDs registrados. Esta actividad cubre el margen de propagación del backend. |
| 40–50 | Drift exclusivamente en `Demonstration` del ejercicio y reconciliación | Plan restaura la etiqueta declarada sin recrear bucket ni modificar backend. Completar preflight del backend tras la espera si no estaba completado. |
| 50–65 | Copia segura, ejemplos → backend activo, configuración real e `init -migrate-state` | Confirmación de copia local → S3; IDs idénticos; estado cifrado con VersionId; `plan` sin cambios. Bootstrap continúa local. |
| 65–80 | `apply` interactivo esperando aprobación, lectura del `.tflock`, segundo plan bloqueado; cancelar y revertir tfvars | Lock real observado y liberado por su dueño; distinguirlo del lockfile de proveedores. Repetir plan sin cambios. |
| 80–90 | Revisar y aplicar plan de destrucción **solo del ejercicio**, repaso y custodia | No aparece `tfstate-…` en la destrucción; estado remoto vacío, backend preservado y bootstrap local guardado. La retirada completa queda fuera del cierre normal. |

Usar el [README del alumno](README.md) como secuencia de comandos. Si una espera, credenciales caducadas o restricción impide completar la práctica, registrar el punto real alcanzado y no marcar como verificados los pasos restantes. No convertir pasos de seguridad en extensiones opcionales para cumplir el reloj.

## Puntos de explicación

- **Estado no equivale a configuración:** mapea direcciones a recursos reales. Una migración de backend mueve ese registro, no hace `import`, no renombra buckets ni cambia IDs. No borrar estados para “empezar de nuevo”.
- **Bootstrap no se administra desde su propio bucket:** evita la dependencia circular de custodia. Su backend es local explícito y requiere conservación fuera de Git y del propio bucket. No ejecutar `init -migrate-state` en `bootstrap`.
- **Plan guardado:** contiene decisiones y puede contener datos sensibles. Revisar `terraform show` y aplicar únicamente el plan de la raíz correcta. No subir planes, estados, tfvars ni backend real.
- **Drift:** usar solo `Demonstration` del ejercicio. No cambiar cifrado, permisos o versionado como demo de drift. `put-bucket-tagging` reemplaza todas las etiquetas; preferir consola para cambiar una sola o revisar el conjunto completo en un archivo privado.
- **Versionado y bloqueo resuelven problemas distintos:** versiones para recuperación; `.tflock` para exclusión mutua. El lock no sustituye a las copias, y el versionado no evita escrituras simultáneas.
- **Lock de proveedor:** `.terraform.lock.hcl` fija selección/checksums y se versiona tras revisarlo. No contiene ni sustituye el lock remoto. `use_lockfile = true` requiere Terraform >= 1.10 y permisos S3, no DynamoDB.
- **Credenciales:** el backend se inicializa antes que el proveedor y tiene su propia configuración; no puede usar `var.region`, `var.account_id` ni referencias a recursos en su bloque. Usar la cadena de credenciales temporal autorizada, no secretos en `backend.hcl` o comandos compartidos.
- **Coste y limpieza:** almacenamiento de versiones y peticiones sigue existiendo aunque el ejercicio esté destruido. AWSCC no tiene `force_destroy`: la eliminación requiere un bucket vacío; nunca proponer vaciado automático como solución rápida.

## Incidencias habituales y respuesta segura

| Señal | Acción |
| --- | --- |
| Cuenta inesperada / precondición de identidad o `allowed_account_ids` rechaza | Revisar sesión temporal y cuenta real; no eliminar el guard. AWSCC no admite `allowed_account_ids`: cada bucket compara `aws_caller_identity.current.account_id` con la cuenta esperada mediante una precondición. |
| Nombre S3 ocupado antes de crear | Si hay un nombre exacto opcional, elegir uno propio disponible antes de crear; no importar un bucket desconocido. Con nombre generado, investigar cuenta/nombre/estado antes de actuar, sin borrar estado ni quitar `prevent_destroy`. |
| Credenciales caducadas | Renovar con el mecanismo Academy, recuperar la misma cuenta y repetir la operación pendiente; no reconstruir recursos ni estado. |
| 403 en objetos/lock/configuración | Revisar alcance con el responsable; distinguir 403 de clave ausente. No alterar IAM ni desactivar bloqueo/protecciones. |
| Versionado no `Enabled` | Revisión de plan/apply y lectura real; no migrar. No escribir durante el margen inicial de propagación. |
| Plan propone crear todo después de migrar | Parar: revisar raíz, bucket, clave, cuenta y copia de estado. No aplicar para “arreglarlo”. |
| Lock sin proceso aparente | Investigar al propietario y otros terminales antes de cualquier recuperación. No borrar `.tflock` ni hacer `force-unlock` en una demo. |
| Destrucción del ejercicio falla por bucket no vacío | Inventariar objetos ajenos y revisarlos con el dueño; nunca vaciar forzadamente. |
| Se pierde el workspace efímero | Recuperar copia custodiada del bootstrap; no suponer que los recursos desaparecieron con el disco. |

## Evidencias mínimas y cierre

Sin publicar estado ni identidad sensible, contrastar en la sesión: versión de herramientas, cuenta/región correctas, versionado real `Enabled`, ID del bucket y objeto antes/después sin cambios, `head-object` del estado con cifrado y versión, lock real temporal, plan final sin cambios y plan-destroy limitado al ejercicio. Las capturas privadas no se incorporan a Git.

La **retirada excepcional completa** está detallada en el README: primero todos los consumidores migrados o destruidos y desvinculados del backend (incluido el estado vacío), después copias seguras, revisión de nombres y de cada clave/versión/marcador, eliminaciones manuales exactas y, solo al final, retirada intencionada de `prevent_destroy` conservando la precondición de identidad y plan-destroy revisado de bootstrap. Cloud Control solo elimina el bucket vacío. No automatizar el vaciado, no borrar configuración para sortear la protección y no retirar el backend durante el cierre normal de clase.

Extensiones opcionales, no requisitos: recuperar una versión de estado únicamente en un entorno docente aislado y planificado, o comparar otros backends. No añadir EC2, IAM, despliegues de otros labs ni migraciones masivas a esta introducción.
