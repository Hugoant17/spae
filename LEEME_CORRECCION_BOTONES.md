# Corrección de aprobación y eliminación · 27/09/2026

## Instalar sobre la entrega del 26/09

1. Guarda una copia de tu proyecto y una copia de seguridad de tu base de datos.
2. Extrae este ZIP en una carpeta nueva. Conserva tu configuración de conexión.
3. En Supabase > SQL Editor, ejecuta las migraciones pendientes en orden. Si ya aplicaste todos los ajustes del 26/09, ejecuta solamente:
   `supabase/migrations/202609270001_botones_participantes.sql`
   Si todavía falta `202609260002_ultimos_ajustes.sql`, ejecútala antes. No vuelvas a crear las tablas ni ejecutes `schema.sql` sobre tu instalación existente.
4. Abre PowerShell dentro de `spae_flutter` y ejecuta:

```powershell
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
.\scripts\INICIAR.ps1
```

5. Si usas una web publicada, ejecuta `flutter build web --release` con la misma configuración de conexión de tu despliegue y publica el nuevo contenido de `build/web`. Reiniciar una pestaña con la versión antigua no instala el arreglo.
6. Para actualizar también la ruta de eliminación de la Edge Function (usada por clientes anteriores), desde esta carpeta ejecuta:

```powershell
npx supabase login
npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
```

Los botones Aprobar y Eliminar de esta versión llaman directamente a funciones SQL autenticadas. No necesitan la Edge Function para esas dos operaciones. Rechazar, comprobantes y otros servicios siguen utilizando `spae-api`.

## Cambios y alcance

- Aprobar actualiza inscripción y pago en una sola transacción. Repetir la misma aprobación no duplica la auditoría. Se muestra confirmación en pantalla.
- Eliminar permite borrar participantes con inscripciones aprobadas si no tienen certificados emitidos. El diálogo indica que también se borrarán sus inscripciones, pagos registrados en la base y asistencias. La operación es irreversible una vez confirmada.
- Una eliminación fallida revierte todos sus cambios. Se registra auditoría y se conservan las cuentas de miembro y sus membresías.
- Los participantes con certificados emitidos siguen protegidos y reciben un mensaje explícito; no se borran certificados.
- Los archivos de comprobantes en Storage se conservan. Se eliminan los registros de pago asociados en la base, no los archivos físicos.
- Solo asistentes y administradores habilitados pueden ejecutar las operaciones. Una cuenta desactivada queda bloqueada incluso con una sesión anterior.
- Si falta la función SQL, la interfaz indica qué migración ejecutar.

## Qué se encontró

La versión anterior bloqueaba explícitamente toda eliminación que tuviera una inscripción aprobada. Además, Aprobar dependía de que la Edge Function desplegada y la migración SQL estuvieran sincronizadas. No se tuvo acceso al error ni al despliegue real, por lo que no se atribuye la falla de aprobación a una causa de producción confirmada.

## Comprobar después de instalar

Utiliza registros de prueba, no participantes reales:

1. Inicia sesión como asistente. Aprueba una inscripción pendiente; debe mostrarse Aprobado después de actualizar. Verifica también el pago.
2. Elimina un participante de prueba aprobado sin certificado. Cancela primero para comprobar que no cambia nada; luego confirma y verifica que desaparezca.
3. Intenta eliminar un participante con certificado: debe mostrar el bloqueo y conservar los datos.
4. Comprueba que una cuenta de miembro o desactivada no pueda realizar estas operaciones.

Se agregó `tests/participant_actions.sql` para aprobación, reintento, cuenta desactivada, protección de certificados, eliminación y auditoría. Ejecutar exclusivamente en una base de pruebas, después de todas las migraciones. Se revierte al terminar. La prueba de widgets comprueba confirmación y cancelación.

Validación realizada aquí: sintaxis TypeScript mediante Node y revisión de los cambios y rutas de llamadas. Flutter, Dart, PostgreSQL y Deno no están instalados en este entorno: las pruebas de ejecución y la compilación quedan pendientes. No se modificó tu base de datos ni el sistema publicado.
