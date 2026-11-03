# Guía docente · 02 AWS: fundamentos y aprovisionamiento como código

**05/11/2026 · 18:00–21:00 · Rael Garcia · 3 h.** M2 con **1 h transversal M1** de Python y revisión asistida por IA, incluida en estas tres horas, no adicional. Entrada: perfil junior con Linux, redes y scripting básicos. AWS es el laboratorio práctico principal del alumnado; la sesión 3 traslada este patrón a demos Azure/GCP, no a dos cuentas/despliegues nuevos obligatorios.

El material contiene implementación ejecutable y respuestas **sintéticas** para practicar sin credenciales. **El laboratorio completo de red/EC2/HTTP no se ha probado contra AWS.** La evidencia real disponible es un ensayo S3 aislado con el mismo rol Academy: `hashicorp/awscc` 1.108.0 creó un bucket privado/cifrado con ownership enforced, lo refrescó con un plan sin cambios y lo destruyó. No extender esa evidencia a una ejecución completa del laboratorio introductorio ni de este laboratorio de VM. Tampoco una ejecución offline correcta acredita disponibilidad real de Academy, apt, EC2 o Billing.

## Resultado y alcance docente

Al finalizar, el alumno puede interpretar dependencias HCL y un plan, desplegar una VM HTTP pequeña y un bucket privado, consultar recursos de su propiedad con Python/CLI, justificar un cambio/reconciliación, identificar costes y verificar una destrucción controlada. No se evalúa diseñar una landing zone ni aprender boto3 desde cero.

Caso: red dedicada VPC/subred/IGW/tabla/ruta/asociación, SG HTTP solo desde `/32`, EC2 Ubuntu 24.04 x86_64 y S3 privado vacío con cifrado AES256 y ownership enforced. La aplicación Python usa biblioteca estándar, sin Docker. Su proceso corre como usuario de sistema sin privilegios, con capacidad limitada de bind al puerto 80. La VM no tiene credenciales, rol IAM, key pair ni acceso asignado a S3. Desde el cliente se usan los permisos Academy existentes; no crear usuarios, roles, políticas ni perfiles de instancia.

Presentar además el mapa de identidad, registro de imágenes (ECR), bases de datos y servicios gestionados a nivel de equivalencias/necesidad. No añadir ECR/EKS/RDS, un balanceador, NAT Gateway ni despliegues extra a este ejercicio. No convertir las extensiones en requisito del proyecto.

## Preflight obligatorio antes de la clase

### Confirmar el Academy concreto (no inferir por la marca)

Registrar para el grupo, sin secretos:

- Nombre/tipo real del laboratorio y las instrucciones oficiales asignadas. Invitación/acceso desde sesión 1; forma de inicio, duración, renovación de sesión y credenciales, persistencia entre sesiones y significado exacto de Start/End/Stop/Reset.
- Cuenta y región autorizadas, tipos x86_64 admitidos y cuotas EC2/VPC/EBS/S3. El ejemplo ofrece `t2.micro`, `t3.micro`, `t3.small`, `t3a.micro`, `t3a.small`: escoger **uno realmente permitido**, no asumir que t3.micro existe o es gratis. Si solo hay otro tipo, adaptar la lista de validación de manera acordada y conservando tamaño pequeño antes de clase, sin evadir restricciones.
- Búsqueda `DescribeImages` de Ubuntu 24.04 amd64 oficial de Canonical (`099720109477`) y permiso de lanzamiento. Si la búsqueda no está permitida, facilitar un `ami_id` Ubuntu 24.04 x86_64 autorizado y de la región. Un ID válido sintácticamente puede pertenecer a otra región, ser arm64 o requerir permiso de marketplace: la validación HCL no resuelve eso.
- Permisos existentes para crear/etiquetar/describir/borrar VPC, subnet, IGW, route table/route/association, SG, EC2 y EBS cifrado; configuración de metadatos IMDSv2; S3 create/tag/BPA/encryption/ownership y destrucción del bucket vacío. Confirmar uso de cifrado EBS permitido con la clave de servicio, sin añadir cambios IAM/KMS. Las acciones read-only del verificador incluyen STS identity, EC2 Describe y S3 GetBucketTagging/GetPublicAccessBlock/GetBucketEncryption/GetBucketOwnershipControls. `GetBucketTagging` tiene que devolver NoSuchBucket en un bucket propio eliminado; si devuelve AccessDenied no hay evidencia de ausencia.
- `awscc_s3_bucket.private` usa AWS Cloud Control API: comprobar permisos de crear/consultar/actualizar/eliminar recursos y consultar el estado de las operaciones, además de las acciones S3 subyacentes y de las consultas directas del inventario. El proveedor oficial `hashicorp/awscc` 1.108.0 completó el ensayo S3 aislado con el mismo rol Academy, sin añadir IAM ni modificar SCP. La alternativa anterior `hashicorp/aws` 5.100.0, al gestionar `aws_s3_bucket`, intentaba leer `s3:GetBucketObjectLockConfiguration` aunque no se habilitara Object Lock y encontró un deny explícito de SCP tras crear el bucket; se limpió ese recurso parcial. La ruta soportada Cloud Control conserva bloqueo público completo, AES256, ownership enforced y etiquetas sin relajar la política. Verificar el entorno concreto y el ciclo autorizado antes de clase: la prueba aislada no demuestra permisos EC2/red ni el funcionamiento del laboratorio completo.
- Autenticación temporal compatible con CLI/proveedor y margen de vigencia suficiente hasta el destroy. La identidad usada en `apply` y consulta posterior debe coincidir. No asumir que el navegador proporciona automáticamente credenciales al terminal.
- Ubuntu puede salir por DNS/HTTP/HTTPS a sus repositorios y dispone de cloud-init/systemd. La AMI no instala Docker; apt puede fallar por conectividad o indisponibilidad. `running` no implica bootstrap correcto.
- El alumno puede llegar a la IP pública de EC2 por el puerto 80 desde su IPv4 de salida. VPN, NAT y políticas corporativas pueden cambiar/bloquear esa IP. No abrir `/0` ni 22 para facilitar la práctica.
- Billing, Cost Explorer y Budgets: qué vistas permite el rol; cuenta docente autorizada o muestra sintética preparada si no están disponibles. No prometer que las etiquetas estén activadas como cost allocation tags ni que el gasto aparezca al momento.

No se prescribe una política IAM «universal Academy»: verificar restricciones reales y adaptar la actividad de manera explícita. Una denegación no se resuelve con credenciales de administrador prestadas ni con llamadas privilegiadas en Python.

### Herramientas y estado

Terraform `>=1.6,<2`, proveedor `hashicorp/aws` `>=5.80,<6` para identidad/EC2/red, `hashicorp/awscc` `>=1.108,<2` para S3, `hashicorp/random` `>=3.6,<4` para el sufijo, Python `>=3.11`, AWS CLI v2. Ambos proveedores AWS usan `var.aws_region` y las credenciales temporales existentes. Verificar resolución del ejecutable Python (el Python del sistema de algunos macOS es 3.9), descarga de proveedores y acceso a la red. No dependemos de boto3, pip ni SDK pesado. La app puede iniciarse localmente con `python3 app.py --host 127.0.0.1 --port 8080`; no requiere root ni AWS.

Cada alumno usa copia de trabajo y estado local privados y `lab_id` distinto. No reutilizar el directorio/estado del docente ni un backend compartido. El bucket generado usa cuenta+lab_id+sufijo aleatorio de 12 hexadecimales persistido en estado; un estado nuevo genera otro sufijo, pero no cambia el requisito de lab_id propio para red/VM. `bucket_name` permite un nombre exacto globalmente disponible sin sufijo (null por defecto), no adoptar almacenamiento existente; cambiarlo puede provocar reemplazo. Consumir el nombre real desde outputs. Explicar que separar carpetas no basta si se copia por error un estado de otra persona. Confirmar la carpeta/workspace antes de plan/apply/destroy y revisar la lista exacta de cambios.

Conservar el lockfile de proveedor resuelto para reproducibilidad. No distribuir estado real, planes guardados, credenciales ni outputs con infraestructura personal; las únicas capturas incluidas son JSON sintético marcado como tal. Acordar un lugar local para evidencias saneadas.

### Preservar el entorno para contenedores (sesiones 4–5)

Este ejercicio **no es** la preparación del runtime Academy de las sesiones 4 y 5. La VM cloud-02 debe destruirse; no instalarle Docker como atajo ni convertirla en dependencia posterior. Antes de sesión 4 dejar comprobados por separado runtime permitido compatible con OCI, CLI/Compose, registro, conectividad, puertos, cuotas y persistencia en el entorno que realmente se ha asignado. Si ese entorno comparte cuenta con cloud-02, identificar explícitamente sus recursos y no incluirlos en este estado ni en el plan de destrucción.

Mostrar la diferencia entre eliminar los recursos Terraform de esta carpeta y las acciones del portal Academy. No pedir Reset, End Lab general ni destrucción de recursos compartidos. Explicar cómo termina cada alumno su sesión según las instrucciones del laboratorio sin perder el runtime preparado.

## Guion de 180 minutos

| Hora Europe/Madrid | Min | Actividad y evidencia |
|---|---:|---|
| 18:00–18:15 | 15 | Acceso/identidad/región, alcance, credenciales temporales y presupuesto Academy. Mapa de AWS: cómputo, red, almacenamiento, IAM, ECR y servicios gestionados; sin desplegar extras. |
| 18:15–18:40 | 25 | Leer HCL y dependencias, default tags AWS y etiquetas explícitas AWSCC, AMI/tipo, `/32`, S3 mediante Cloud Control y user-data. Configurar variables propias, init/validate, leer plan y estado local. |
| 18:40–19:05 | 25 | Aplicar plan revisado, guardar outputs JSON, explicar que EC2 running y bootstrap son distintos. Diagnóstico guiado sin SSH. |
| 19:05–19:20 | 15 | **M1**: ejecutar parser offline, recorrer JSON anidado y argumentos subprocess sin shell. |
| 19:20–19:45 | 25 | **M1**: copiar fixtures, inyectar stopped/instancia ausente/S3 público, revisar una propuesta pequeña de IA conservando fallos y filtros. |
| 19:45–20:05 | 20 | **M1**: separar consulta real de offline; inventario por etiquetas/outputs y sonda HTTP opcional. Contrastar IDs, mensaje y errores. **Total M1 60 min.** |
| 20:05–20:25 | 20 | Cambiar mensaje, interpretar reemplazo por user-data y guardar outputs nuevos. Fallo `/32` documental, diagnóstico y restauración en grupo. Si el bootstrap consume tiempo, docente demuestra la inyección, sin omitir explicar causa/recuperación. |
| 20:25–20:45 | 20 | **Costes AWS**: Bills, Cost Explorer, filtros, Budgets/alertas y límites; muestra explícita si permisos/retraso impiden consulta real. |
| 20:45–21:00 | 15 | Guardar outputs actuales, plan destroy/revisión/aplicación, consulta read-only `--expect absent` y estado vacío. Registrar pendientes sin declarar limpieza falsa. |

Mantener los 60 minutos M1 y los 20 minutos de costes. Se parte de una implementación preparada para no dedicar la clase a escribir HCL desde cero. No consumir el cierre haciendo instalaciones o extensiones no previstas. Si un problema de permisos impide el despliegue del alumno, separar el análisis offline de la demostración autorizada del docente y registrar honestamente que falta su evidencia real, sin fingir éxito.

## Recorrido de seguridad y Python

Antes de `apply`, preguntar: «¿Qué entra por el SG? ¿Por qué una ruta 0/0 no equivale a un SG 0/0? ¿Quién lee S3? ¿Dónde están las credenciales?». Después, mostrar que base64 en user-data solo evita problemas de escape y no protege secretos. El servidor sirve únicamente dos rutas JSON y no expone un directorio de archivos.

El inventario exige modo `--live` o `--fixture-dir`; no prueba AWS implícitamente ni cae a fixtures tras fallo. En vivo exige outputs guardados, `--lab-id` y `--region`, compara la cuenta de STS, consulta siete familias EC2 por tres etiquetas y un bucket exacto. No llama a create/update/delete/stop/start ni ejecuta shell. Los errores de permisos, JSON, timeout o recursos esperados muertos/ausentes son código no cero; solo `NoSuchBucket` acredita ausencia del bucket. En modo present, los IDs deben coincidir exactamente, incluida la ausencia de recursos extra con las mismas etiquetas.

La sonda HTTP debe pedirse explícitamente y solo existe para modo real/present. No sigue redirecciones ni usa proxies y comprueba el JSON del caso. Offline rechaza `--probe-http`: las direcciones de documentación nunca se usan para fingir una respuesta live. Sin la opción de sonda, una consulta API correcta no prueba la salud de la aplicación. La comprobación de propiedad se apoya en etiquetas y outputs; no es un auditor de toda la cuenta ni una frontera de autorización IAM.

Ejercicio de IA: proporcionar solo la fixture, pedir explicación/adaptación pequeña de salida y revisar casos de fallo, no generar un controlador cloud. Rechazar propuestas que añadan `shell=True`, ignoren retornos CLI, capturen todo para imprimir «OK», eliminen filtros, sigan URLs arbitrarias o pidan secretos. La evidencia es el razonamiento y el contraste, no la longitud del prompt.

## Demostración de costes (20 minutos, no un aviso genérico)

1. Abrir **Billing and Cost Management → Bills**, seleccionar mes/cuenta y distinguir EC2 cómputo de EBS/EC2-Other, IPv4 pública, S3 y tráfico. Anotar unidad de cada concepto; «micro» no significa gratis y detener EC2 no limpia EBS.
2. Abrir **Cost Explorer → Cost and usage**. Mostrar fecha, granularidad diaria, agrupar por servicio y filtrar región; después las etiquetas de asignación de costes disponibles. Explicar por qué una etiqueta no activada o un cargo no etiquetado puede no aparecer en el filtro. No habilitar etiquetas globales de facturación como efecto lateral del ejercicio.
3. En **Budgets → Create budget → Cost budget**, mostrar presupuesto mensual didáctico (p. ej. 5 USD), alcance y umbrales real 50/80/100 %, previsto 100 %. Revisar destinatario con su propietario y confirmación si la notificación elegida la requiere. Usar una cuenta docente autorizada o recorrer el formulario sin guardar si no se deben crear avisos. No ejecutar acciones de presupuesto ni enviar correos de prueba a personas no autorizadas.
4. Explicar retraso de facturación y alertas, y que un presupuesto no frena automáticamente el gasto. Diferenciar ese mecanismo del indicador propio del Academy real y sus reglas específicas, sin garantizar una parada universal.
5. Si no hay permiso o datos recientes, usar la tabla **sintética** del README. Está inventada, no es una captura ni tarifa: agrupar los 0,06 USD y hacer visible el efecto de la fila sin etiquetas. Nombrar qué se ha podido observar realmente y qué no. La actividad sigue siendo interpretar consultas, filtros y alertas; no producir una factura ficticia del alumno.

Al volver al cierre, conectar costes con `root_volume_id`, IP pública y `delete_on_termination`. En futuras sesiones de clúster gestionado se retomarán control-plane, nodos, balanceadores, discos y tráfico; no añadirlos aquí.

## Cierre, incidencias y aceptación

Usar el bloque exacto de limpieza del README: outputs **actuales** antes de destroy, plan de destrucción revisado, aplicación y consulta con `--expect absent`. Esperar que las instancias puedan seguir listadas como terminated; comprobar que el disco etiquetado y la red desaparezcan. Si AccessDenied impide consultar S3 tras borrado, registrar «sin evidencia por permisos», no «eliminado». Gestionar persistencia/credenciales según el Academy concreto para terminar la comprobación.

El bucket nace vacío y [`awscc_s3_bucket`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/s3_bucket) solo permite eliminarlo vacío; su esquema no incluye `force_destroy` ni vaciado automático. Ante BucketNotEmpty, revisar el bucket exacto y acordar la eliminación explícita solo de sus datos; no introducir un script recursivo. Ante fallo de apply parcial, conservar estado, planificar desde el mismo estado y limpiar lo creado; nunca borrar el fichero para ocultar el fallo. Un token caducado se renueva con el procedimiento oficial y la misma cuenta. Un error de apt se diagnostica sin añadir SSH ni permisos IAM y sin confundir el parser offline con una reparación.

Aceptar evidencias saneadas de plan/cambio, separación offline-real, fallo intencionado y revisión de IA, diseño de coste/alerta y verificación de limpieza. No solicitar estado ni planes reales en entregas. Registrar cualquier recurso pendiente con responsable y causa concreta, sin dar por finalizada la limpieza. La sesión no cambia las ponderaciones del curso ni crea requisitos avanzados para el proyecto final.
