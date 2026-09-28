# Fichas por participante y activación de membresías

Proyecto configurado: SPAE Capacitaciones, friocmtkfannujwkslge.

## Actualizar

Reemplaza el proyecto con esta carpeta completa. Si ya aplicaste las migraciones del 09/09 y `202609160001_observaciones.sql`, ejecuta solo `supabase/migrations/202609160002_fichas_entrega.sql` en SQL Editor. Para una instalación nueva: schema.sql y las tres migraciones por orden de nombre.

Luego ejecuta, uno por uno:

```powershell
flutter pub get
flutter analyze
flutter test
npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
.\scripts\INICIAR.ps1
```

## Administrador y asistente

Ambos tienen Miembros y Membresías en su menú. En Miembros, «Activar membresía» abre el pago pendiente y su comprobante; «Confirmar activación» aprueba ese pago y activa/renueva doce meses. En Membresías el botón también aparece junto al pago pendiente. Si no hay un pago pendiente, el sistema explica que el miembro debe adjuntar su comprobante. La operación usa los permisos y la transacción de aprobación existentes; no inventa un pago ni duplica periodos ya aprobados.

Administrador: /#/admin/miembros y /#/admin/membresias.
Asistente: /#/asistente/miembros y /#/asistente/membresias.

## Fichas Excel

Dashboard del administrador o Reportes → Fichas NAA / TRC / TEC → seleccionar capacitación → seleccionar ficha → Exportar.

La tabla tiene una fila por participante de la capacitación. Se mantienen el mismo código en las tres fichas, las cabeceras, los títulos superiores, los objetivos, las leyendas, las fórmulas y el promedio. La capacitación, fecha y bloques provienen de registros reales. Los nombres de investigador y responsable quedan vacíos para completar; no se atribuyen a una persona desconocida. La prueba se marca como Postest porque son datos del sistema, no se reutiliza la población de muestra de los Excel Pretest.

- NAA: N.°, Código de participante, B1...Bn, NAAi (%). Presente/Ausente y Sin registrar cuando no hay una marca todavía. NAAi = presentes / total de bloques × 100. Si el curso tiene cinco bloques, las columnas coinciden con B1...B5 del original.
- TRC: N.°, Código de participante, Apellido y nombres, N.° DNI, N.° de teléfono, ¿Registro de enfermera auditora?, Hospital donde labora, Región, ¿Desea certificado?, % de completitud del registro. Las siete columnas de criterios contienen Sí/No sobre su validez, como tus ejemplos; no contienen los datos personales literales. TRCi = campos válidos / 7 × 100. La revisión manual de la asistente prevalece sobre la validación automática de formato.
- TEC: N.°, Código de participante, Hora de cumplimiento, Hora de emisión, TECi (horas). Fechas reales y diferencia redondeada a horas enteras; pendientes excluidos del promedio. Las fechas se exportan en UTC.

Tu leyenda de TEC define la emisión como el envío. Por ello ahora la asistente tiene «Registrar entrega» en Certificados. Debe pulsarlo después de enviar o entregar efectivamente el documento. El botón registra la hora del servidor y quién confirmó la entrega; NO manda correos. Generar o descargar el PDF no registra una entrega. Repetir la confirmación conserva la primera fecha. Los certificados anteriores sin entrega documentada aparecen como Pendiente en TEC: no se inventa una fecha histórica.

## Verificación

Las 10 pruebas de la versión anterior pasaron en tu equipo, según tu registro. Esta modificación tiene controles estáticos de importaciones, delimitadores y cabeceras originales aprobados aquí. Sus pruebas Flutter y SQL todavía deben ejecutarse en tu equipo: el entorno de edición no cuenta con Flutter ni PostgreSQL.
