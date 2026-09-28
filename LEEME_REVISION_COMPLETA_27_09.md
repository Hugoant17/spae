# Instalar la revisión completa del 27 de septiembre

Esta entrega corrige los errores del Word de observaciones y conserva el proyecto completo. El código, la base de datos y la Edge Function deben actualizarse juntos.

1. Conserva una copia del proyecto y de la base. Extrae este ZIP en una carpeta nueva.
2. Comprueba que el proyecto seleccionado es `tgwihgzgzccjohvddawi`. Abre Supabase > SQL Editor. Sobre la instalación del 26/09 ejecuta, en orden, `202609270001_botones_participantes.sql` y `202609270002_revision_tres_perfiles.sql`, dentro de `supabase/migrations`. Si ya ejecutaste 270001, aplica solo 270002. Si faltan migraciones del 26/09 o anteriores, aplícalas primero en orden de nombre. No recrees tablas con schema.sql en una base existente.
3. Abre PowerShell dentro de spae_flutter y ejecuta:

```powershell
.\scripts\ACTUALIZAR_BACKEND_2709.ps1
.\scripts\VERIFICAR.ps1
.\scripts\INICIAR.ps1
```

El primer script despliega spae-api. Es indispensable para eliminar cuentas de miembro, gestionar cuentas de asistentes, restablecer códigos y regenerar certificados con la versión nueva. El segundo analiza, prueba y compila Flutter y se detiene ante fallos. Si tienes una web publicada, publica el nuevo contenido de build/web; abrir la web anterior no instala esta entrega.

## Cambios

- Aprobar y Rechazar inscripciones usan una RPC autenticada. Rechazar conserva el motivo y el registro para que el participante pueda corregir su comprobante; no elimina automáticamente el historial.
- Eliminar participante funciona con registros aprobados sin certificados, después de confirmar el alcance. Elimina inscripciones, pagos de capacitación y asistencias de ese participante. Con certificados emitidos se bloquea.
- Activar/Inactivar miembros usa una RPC con comprobación del rol y de la cuenta habilitada. Eliminar miembro utiliza Auth en el servidor; el guardado de seguridad impide borrar cuentas con historial académico y revierte cambios parciales. En ese caso se utiliza Inactivar.
- Los archivos de comprobantes permanecen en Storage; eliminar registros no borra automáticamente los archivos físicos.
- El certificado muestra Lic. una sola vez. Se cambió la versión de caché del PDF para regenerar también los anteriores al descargarlos. No se modifica el nombre del perfil.
- TEC se calcula y muestra con tres decimales en el dashboard, con precisión coherente en SQL y exportaciones.
- DNI y correo ya registrados se ven en gris y son de solo lectura. Las cuentas antiguas sin DNI pueden completarlo una vez; después queda bloqueado.
- Restablecer código ahora genera 16 caracteres: antes generaba 10 y la RPC exigía al menos 12.
- Las confirmaciones evitan múltiples operaciones por doble clic. Un servidor anterior muestra instrucciones de actualización en lugar de un error genérico.

## Validación

Se ejecutaron ocho migraciones y tres suites SQL en una base aislada con PGlite (motor PostgreSQL WASM): todas pasaron. Se validó sintaxis TypeScript, estructura de las 33 vistas Dart y tres renders de certificado. Se corrigieron también pruebas anteriores con un paréntesis faltante y expectativas desactualizadas de TEC/TRC.

No se tuvo acceso a tu Supabase ni hay SDK Flutter/Deno instalado aquí. No se afirma que todos los botones hayan pasado una prueba integral en navegador. Completa VERIFICAR.ps1 y el recorrido por los tres perfiles de `docs/REVISION_BOTONES_27_09.md`.

Para reproducir las pruebas SQL locales con Node:

```powershell
cd tests
npm install
npm test
```

## SCRUM

El documento revisado se entrega por separado. Se reordena el índice, se conservan los tres sprints del documento original, se mejoran los esquemas físicos y se separan las actas de planificación/revisión. La firma y el sello proporcionados se conservan en la autorización original anexa; las actas dejan espacios de conformidad para cada reunión. Los diagramas se exportaron de la base local migrada y se incluyen en SVG ampliable; no son una captura del Supabase remoto.
