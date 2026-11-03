# Laboratorios de proveedores cloud

Laboratorios reutilizables de infraestructura y análisis cloud. Las guías conservan la planificación docente de las sesiones 2 y 3 de la edición UPC 2026–2027; no añaden clases ni requisitos al Trabajo Final.

| Laboratorio | Recorrido | Ejecución |
|---|---|---|
| [AWS e IaC](labs/aws-iac/README.md) | Red, VM, almacenamiento privado, Terraform, consulta Python, diagnóstico y limpieza | Alumnado en el laboratorio AWS Academy asignado, con permisos comprobados por el docente |
| [Azure y GCP](labs/azure-gcp/README.md) | Transferir el mismo patrón, interpretar diferencias y adaptar consultas | Demostraciones cloud del docente; ejercicio Python con datos sintéticos identificados, sin cuentas Azure/GCP obligatorias |

Para introducir Terraform antes de desplegar redes y VMs, usar [S3 y estado remoto](../terraform/s3-state-intro/README.md): dos buckets pequeños para practicar el ciclo de cambios y migrar el estado a un backend propio. Es un ejercicio independiente; no migra automáticamente los estados de estos laboratorios.

## Antes de empezar

1. Completar el acceso a AWS Academy presentado en sesión 1. El docente ensaya el recorrido con los permisos reales del alumnado y confirma región, recursos permitidos, cuotas y límites de tiempo/presupuesto.
2. Consultar el `README.md` del laboratorio y su `guia-docente.md`: distinguen despliegue real, datos de ejemplo, comprobaciones y limpieza. Una ejecución con datos sintéticos no demuestra que un despliegue cloud funcione.
3. Instalar Terraform y Python según los requisitos de cada laboratorio; las consultas reales necesitan además la CLI del proveedor y una sesión autenticada. Nunca guardar credenciales en los ejemplos.
4. Elegir un identificador propio de laboratorio para no compartir nombres ni estado Terraform con otros equipos. Revisar siempre el plan antes de aplicar o destruir.

## Seguridad, costes y estado

- Los despliegues reales pueden generar cargos. No hay despliegues automáticos al ejecutar los ejercicios de análisis con datos de ejemplo.
- Limitar el acceso HTTP a la dirección de salida autorizada; no abrir SSH a Internet. El almacenamiento de objetos del caso es privado.
- Consultar costes, filtros, presupuestos/alertas y limpieza durante 15–20 minutos por proveedor. La facturación puede llegar con retraso; los presupuestos y sus alertas no detienen automáticamente el gasto. El indicador de Academy tampoco es una garantía universal de parada.
- Destruir únicamente los recursos del ejercicio con su configuración y estado originales. No resetear el laboratorio Academy ni eliminar infraestructura compartida; preservar el entorno docente para las prácticas de contenedores.
- No subir estados, planes, claves, variables privadas ni capturas reales. Guardar estas últimas en `capturas-reales/`, excluido de Git. Los estados pueden contener datos sensibles aunque un output esté marcado como sensible.
- Los ficheros `.terraform.lock.hcl` fijan versiones y comprobaciones de integridad de los proveedores; se pueden versionar. `.terraform/` es una caché local, no material docente.

Las guías documentan los backends y su bloqueo donde corresponde. No compartir un estado local entre alumnos ni inventar un backend remoto para el aula sin permisos y preparación previos.
