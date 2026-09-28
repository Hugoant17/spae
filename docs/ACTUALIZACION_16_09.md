# Actualización según Requerimientos y Observaciones

## Instalación sobre tu sistema actual

1. Conserva una copia de la carpeta anterior. Extrae el ZIP completo en una carpeta nueva y abre la carpeta que contiene `pubspec.yaml`.
2. En tu proyecto **friocmtkfannujwkslge**, SQL Editor, ejecuta `supabase/migrations/202609160001_observaciones.sql`. Requiere la migración del 09/09 ya aplicada. No borres tablas ni ejecutes de nuevo `schema.sql`.
3. En PowerShell, desde la raíz del proyecto:

```powershell
npx supabase login
npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
flutter pub get
flutter analyze
flutter test
.\scripts\INICIAR.ps1
```

La función ahora importa `certificate.ts`; conserva ambos archivos al desplegar. El despliegue publica la función; la migración SQL debe ejecutarse aparte. Los scripts ya usan la última URL y clave publicable proporcionadas. No crean cuentas de prueba ni cambian contraseñas.

## Cambios relacionados con tus observaciones

| Requisito | Cambio en esta entrega |
|---|---|
| RF-01, RF-02 | Se conserva el sitio público y el catálogo. Registro de miembro visible también en el menú móvil. |
| RF-03, RF-05, RF-06 | Ayuda sobre código privado, etiqueta opcional para primera inscripción, código nuevo aleatorio de 12 caracteres, botón para copiarlo. DNI y teléfono solo admiten números y tienen límite; errores por campo y selección de región. Los códigos anteriores siguen funcionando. |
| RF-04 | Se conserva carga de PDF/JPG/PNG con validación en servidor. |
| RF-07, RF-08 | Formulario de consulta centrado y de ancho limitado. Resultados con acciones debajo de los datos. |
| RF-09 | Se conserva acceso por rol. |
| RF-10 | Se conservan alta, edición y desactivación de asistentes; acciones visibles. Se corrige la función compartida de recarga que producía una excepción después del guardado en listas. |
| RF-11 | Calendarios y selector de hora en inicio, fin y sesiones; interfaz localizada al español. |
| RF-12, RF-13, RF-14 | Tarjetas adaptables con botones separados: detalle, aprobación, rechazo, comprobante y validación TRC. |
| RF-15, RF-16, RF-17 | Corrección de recarga tras asistencia; se conserva el cálculo y la elegibilidad en servidor. |
| RF-18 | Emisión masiva de la selección filtrada, en lotes de 20, con resultados por participante. Pago, asistencia y solicitud se comprueban en servidor. PDF como la referencia, incluyendo nombre, curso, horas, fecha, número y código. |
| RF-19 | Se conserva consulta por capacitación. |
| RF-20, RF-21 | Dashboard y fichas NAA/TRC/TEC por participante, exportación Excel con cabeceras verificadas contra las fichas Pretest originales. |
| RF-22 | Costo-hora retirado del formulario; guardado y recarga corregidos. El valor histórico se conserva sin mostrarse. |
| RF-23, RF-24 | Registro visible desde landing/login. Las nuevas cuentas quedan pendientes de aprobación. Nueva pantalla Solicitudes de miembros para aprobar/rechazar con motivo. Pueden entrar al portal para ver su estado; pago anual e inscripción desde cuenta requieren aprobación. |
| RF-25, RF-26 | Catálogo dentro del portal del miembro e inscripción con datos precargados. Identidad validada en servidor y vínculo con su historial. |
| RF-27, RF-28 | Rechazo con motivo visible en pagos, estado rechazado para membresías nuevas sin vigencia y posibilidad de adjuntar un nuevo pago. Renovación no elimina la vigencia que ya estaba pagada. Corrección de recarga al guardar configuración. |

Los colores del documento aportado representan tu evaluación de la versión anterior. No se han cambiado a verde como si las pruebas de aceptación en tu instalación ya se hubieran ejecutado.

## Interpretación de los indicadores

Se selecciona una capacitación; cada registro corresponde a una persona inscrita en ese curso. El código se mantiene igual en NAA, TRC y TEC para cruzar las fichas. El desplegable Identificación de participantes relaciona código, nombre y DNI.

- **NAAi:** presentes / total de sesiones o bloques × 100, un decimal. Incluye todas las personas inscritas, tal como dice la ficha original. Una asistencia sin registrar no cuenta como presente. Si no hay sesiones, se muestra sin datos. Con cinco sesiones las cabeceras son B1 a B5; con otra cantidad, se adaptan. Bajo la tabla se muestra la leyenda de cada bloque.
- **TRCi:** número de campos válidos / 7 × 100, un decimal. Una respuesta «No» a registro de auditora o deseo de certificado es una respuesta válida y aparece como «Sí» en el control de completitud. El formato se valida automáticamente; la coherencia de nombre e institución necesita revisión humana. La asistente dispone de «Revisar campos TRC» para marcar cada criterio y guardar la evaluación con auditoría. Los porcentajes se calculan sobre esos criterios, no se fijan siempre en 100.
- **TECi:** emisión menos cumplimiento, en horas redondeadas al entero. Los certificados pendientes aparecen como Pendiente y no cuentan en el promedio. El cumplimiento se registra al validar asistencia suficiente, con pago aprobado y deseo de certificado. La emisión corresponde al registro de emisión en el sistema, **no a un envío por correo**: esta aplicación no tiene servicio de envío de certificados por email.
- El promedio del dashboard usa todos los participantes del curso que tienen valor para ese indicador. El promedio al pie de Excel usa solo las filas exportadas. Si filtras la tabla, ambos promedios pueden diferir.
- Las fechas de TEC en Excel usan UTC para que su diferencia sea independiente del equipo. Los calendarios de programación utilizan la hora local del navegador y guardan UTC.
- Las cabeceras coinciden con las fichas originales. Se incluyen fórmulas editables; Excel las calcula al abrir. El archivo se identifica como Postest, sin reutilizar los resultados Pretest de ejemplo.

Se congela una copia de los datos de inscripción para que un cambio posterior de perfil no altere el TRC. Para registros anteriores se usa la información disponible al aplicar la migración; no es posible reconstruir datos iniciales que nunca se guardaron.

## Cuentas y códigos

Las cuentas existentes conservan su acceso; la nueva aprobación se aplica a cuentas creadas después de esta migración. La aprobación de cuenta y la aprobación del pago anual son operaciones distintas. La asistente puede revisar ambas desde su menú.

Los nuevos códigos privados tienen 12 caracteres aleatorios. No contienen el DNI. Los códigos anteriores siguen siendo válidos hasta que la asistente los restablezca. El código se almacena como hash, por lo que no se puede recuperar el texto anterior; se genera uno nuevo tras verificar identidad.

## Prueba de aceptación en tu equipo

1. Administrador: guardar un parámetro, volver a entrar y comprobar el valor sin recargar manualmente Chrome.
2. Crear/editar capacitación y sesiones seleccionando fecha y hora en los calendarios.
3. Público: comprobar errores de DNI/celular; inscribir con un comprobante, copiar el código y consultar historial.
4. Asistente: aprobar/rechazar inscripción y comprobar cambio inmediato de estado; descargar comprobante desde la tarjeta.
5. Registrar asistencia en sesiones ya iniciadas. Verificar que vuelve a cargar sin error.
6. Emitir certificados de un grupo con y sin requisitos; revisar resumen. Descargar un PDF y contrastar con la imagen.
7. Registrar una nueva cuenta; confirmar correo si corresponde; comprobar que aparece pendiente en Solicitudes de miembros. Aprobarla.
8. Miembro: completar perfil, entrar a Capacitaciones y comprobar precarga. Enviar inscripción y verla en Mi historial.
9. Registrar pago anual, rechazarlo con motivo y comprobarlo en Mis pagos. Volver a adjuntar y aprobar; comprobar vigencia.
10. Seleccionar un curso en el dashboard. Comparar manualmente un participante en cada indicador y exportar las tres fichas.

## Verificaciones realizadas y pendientes

Realizadas: importaciones locales y delimitadores, coincidencia exacta de cabeceras con los tres Excel originales, nombres de RPC, sintaxis TypeScript mediante Node, generación real del PDF con pdf-lib y revisión visual. Se generó `preview/certificado_referencia.pdf` con los datos de tu imagen para comprobar el diseño.

Incluidas, pero **no ejecutadas aquí**: pruebas Flutter de recarga, calendario y fórmulas; análisis y compilación Flutter; pruebas PostgreSQL de roles, aprobación y operaciones; ejecución Deno y recorrido integrado contra tu proyecto Supabase. No hay Flutter ni PostgreSQL instalados en este entorno. Ejecuta `scripts/VERIFICAR.ps1` para analizar, probar y compilar en tu equipo. No se ha desplegado esta actualización ni ejecutado SQL en tu cuenta desde aquí.

Referencias técnicas: [setState en Flutter](https://api.flutter.dev/flutter/widgets/State/setState.html), [formatos de celda Excel](https://pub.dev/documentation/excel/latest/excel/CellStyle/CellStyle.html).
