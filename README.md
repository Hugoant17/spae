# Revisión completa 27/09/2026

Empieza por **LEEME_REVISION_COMPLETA_27_09.md**. Incluye cambios de aplicación, migraciones y despliegue de la función.

# Corrección actual · 27/09/2026

Lee primero **LEEME_CORRECCION_BOTONES.md**. Instala la migración `202609270001_botones_participantes.sql` y ejecuta esta versión de Flutter.

# SPAE · Últimos ajustes 26/09/2026

La versión más reciente incorpora `supabase/migrations/202609260002_ultimos_ajustes.sql`. Lee `docs/ULTIMOS_AJUSTES_26_09.md`, ejecuta esa migración después de `202609260001_observaciones_finales.sql`, vuelve a desplegar `spae-api` y recompila Flutter.

# SPAE · Levantamiento final 26/09/2026

La versión más reciente corresponde a `docs/ACTUALIZACION_26_09.md`. Para instalarla sobre la entrega del 24/09, ejecuta `supabase/migrations/202609260001_observaciones_finales.sql`, vuelve a desplegar `spae-api` y recompila Flutter. La matriz de observaciones está en `docs/LEVANTAMIENTO_OBSERVACIONES_26_09.md`.

# SPAE · Certificado con el modelo institucional

Si el sistema ya funciona y solo necesitas el certificado fiel a la imagen, lee `docs/CERTIFICADO_MODELO_24_09.md`. Esta corrección actualiza únicamente la función `spae-api`: no requiere ejecutar SQL ni reinstalar Flutter. Los certificados anteriores se regeneran con el diseño nuevo al volver a descargarlos.

# SPAE · Correcciones del 23/09/2026

Para aplicar esta entrega sobre la instalación anterior, lee `docs/ACTUALIZACION_23_09.md`. Ejecuta `supabase/migrations/202609230001_correcciones.sql` después de las tres migraciones previas, vuelve a desplegar `spae-api` y compila la carpeta Flutter completa. El modelo nuevo del PDF se genera desde `supabase/functions/spae-api/certificate.ts` y sus imágenes incorporadas.

# Fichas y membresías: actualización adicional

`docs/FICHAS_Y_ACTIVACION.md` describe la versión anterior. La actualización del 23/09 sustituye el registro manual de entrega por la fecha de emisión del PDF y muestra TEC con dos decimales.

# SPAE Flutter · Actualización del 16/09/2026

Consulta `docs/ACTUALIZACION_16_09.md` para la relación de cambios según el Excel, pruebas y pasos de actualización.

Esta actualización sustituye los datos y botones de demostración por consultas y operaciones reales. Conserva 33 archivos de vista independientes, con componentes compartidos y navegación según rol. La carpeta debe reemplazar la versión anterior: mezclar archivos viejos puede conservar simulaciones.

## Instalar sobre la base de datos que ya creaste

1. Conserva una copia de tu carpeta anterior. Extrae esta versión en otra carpeta.
2. Si ya instalaste la versión funcional anterior, ejecuta **solo** `supabase/migrations/202609160001_observaciones.sql` completo en SQL Editor. Si todavía no aplicaste `202609090001_backend.sql`, ejecútalo primero. No repitas `schema.sql` si las tablas ya existen.
3. Instala Node.js si aún no tienes `npx`. Abre PowerShell en la carpeta donde está `pubspec.yaml`.
4. Despliega el backend:

```powershell
npx supabase login
npx supabase functions deploy spae-api --project-ref tgwihgzgzccjohvddawi --no-verify-jwt
```

El primer comando abre el inicio de sesión de Supabase. El segundo sube `supabase/functions/spae-api/index.ts`. No necesitas introducir una service_role en Flutter: la función recibe las variables reservadas de Supabase en el servidor.

`--no-verify-jwt` permite las operaciones públicas de inscripción y consulta. Las operaciones privadas verifican el token con `auth.getUser`, el perfil habilitado y el rol dentro de la función. No elimines esas comprobaciones.

5. Abre Authentication > URL Configuration y conserva `http://localhost:3000` como Site URL y `http://localhost:3000/**` entre las redirecciones locales. Configura las URL de producción al publicar.
6. Ejecuta en PowerShell:

```powershell
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=SUPABASE_URL="https://tgwihgzgzccjohvddawi.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="sb_publishable_JUfxFcQfm-xu_Ffr2mYAPw_YiIDnBk5"
```

También puedes abrir `scripts/INICIAR.ps1`. La clave incluida es la clave publicable proporcionada para este proyecto. No se incluyen contraseñas ni claves privadas.

## Si partes de una base vacía

Ejecuta `supabase/schema.sql`, después las dos migraciones en orden (`202609090001_backend.sql`, `202609160001_observaciones.sql`) y opcionalmente `supabase/seed.sql`. Los datos seed solo crean capacitaciones: debes programar sus sesiones desde el administrador. Las cuentas de Authentication existentes y sus roles se conservan al aplicar la migración.

## Accesos

- Público: `http://localhost:3000/#/`
- Miembro: `http://localhost:3000/#/miembro/login`
- Asistente: `http://localhost:3000/#/interno/login`
- Administrador: `http://localhost:3000/#/admin/login`

Usa las cuentas que ya creaste. No hay acceso de demostración ni credenciales automáticas. La ausencia de configuración muestra un error; no simula un ingreso.

## Qué cambia

- **Capacitaciones**: crear, editar, publicar, cancelar y eliminar sin historial asociado; sesiones con fecha/hora, costo, duración y cupo.
- **Inscripción pública**: guarda participante, inscripción y pago en una transacción. El comprobante se sube a Storage mediante la función. El cupo se comprueba con bloqueo de la capacitación.
- **Consulta pública**: DNI o correo más código privado aleatorio. Ese código se muestra al confirmar la primera inscripción; debe conservarse. No basta conocer el DNI para ver documentos ajenos.
- **Corrección de pago rechazado**: desde la consulta pública se puede adjuntar otro comprobante y volver a revisión.
- **Miembros**: registro, login, perfil editable, vinculación del historial mediante correo verificado y DNI, pago anual y descarga de certificados propios.
- **Membresía**: el monto se toma del servidor; un pago pendiente por miembro. Al aprobar se renueva por doce meses desde el vencimiento siguiente o desde hoy si ya venció. Rechazar no activa la membresía.
- **Asistentes**: aprobación/rechazo de pagos, control de asistencia por sesión, consulta de participantes y miembros, emisión de certificados.
- **Certificación**: el servidor comprueba pago, aprobación, solicitud de certificado y asistencia mínima. Guarda una copia de los datos de emisión; genera PDF real en Storage y entrega enlaces temporales. Reintentar no duplica el certificado.
- **Cuentas de asistentes**: se crean y editan en Supabase Auth desde el administrador. Se pueden activar/desactivar. La eliminación se bloquea cuando relaciones históricas requieren conservar la cuenta; en ese caso desactívala.
- **Reportes**: seis reportes Excel independientes. Búsqueda, filtros y fechas aplican a las filas exportadas. La asistencia se exporta por sesión.
- **Indicadores**: una fila por participante y capacitación. NAA incluye todas las inscripciones; TRC evalúa los siete campos de la ficha original; TEC usa cumplimiento y emisión en horas enteras. Cada ficha conserva las cabeceras originales y exporta las filas filtradas con fórmulas Excel.
- **Seguridad**: sesión y rol comprobados en rutas y servidor; cuenta desactivada pierde acceso aunque tenga un token anterior; escrituras de negocio reservadas a RPC; acceso a archivos mediante enlaces temporales.

## Preparación del primer recorrido

1. Administrador: configura un monto de membresía mayor que cero y asistencia mínima en Configuración.
2. Crea una capacitación publicada con al menos una sesión. Para probar asistencia usa una fecha de sesión pasada, porque el servidor rechaza asistencia de sesiones futuras.
3. Público: inscribe un participante, adjunta un PDF/JPG/PNG válido y conserva el código privado mostrado.
4. Asistente: revisa la inscripción, descarga el comprobante y aprueba o rechaza.
5. Asistente: marca asistencia de la sesión y guarda. Luego emite el PDF si cumple la asistencia mínima.
6. Público: consulta con DNI/correo y código privado; descarga el PDF.
7. Miembro: crea una cuenta con mismo DNI/correo, verifica el correo si está habilitado, inicia sesión y completa Mi perfil si falta el DNI. El historial propio se vincula con esos datos.
8. La asistente aprueba la solicitud de cuenta desde Solicitudes de miembros. Después registra pago anual; la asistente lo aprueba. Comprueba vigencia y fecha de vencimiento.
9. Administrador: consulta indicadores y exporta los seis reportes.

Los registros anteriores a la actualización no tienen código privado. La asistente puede restablecerlo desde Participantes después de comprobar la identidad. No debe entregarlo a una persona únicamente por conocer su DNI.

## Verificación y límites comprobados

En el entorno de elaboración se ejecutó el control de importaciones, delimitadores, rutas, llamadas frontend/backend y ausencia de botones vacíos. También se verificó la sintaxis TypeScript de la función mediante el parser de Node.js; esto no sustituye pruebas en Deno/Supabase. **No se pudo ejecutar Flutter, Deno ni PostgreSQL**: no están instalados y no se pudo descargar el SDK. Por tanto, no se afirma compilación ni validación end-to-end al 100%.

En tu equipo, `scripts/VERIFICAR.ps1` ejecuta dependencias, análisis Dart, pruebas de widgets y compilación web. Detiene el proceso si falla un paso.

Se incluyen pruebas SQL transaccionales `tests/backend_smoke.sql` y un flujo CI `.github/workflows/verify.yml`. Comprueban aislamiento de roles, inscripción, emisión sin asistencia bloqueada, emisión idempotente, renovación, historial propio y desactivación. **Son pruebas incluidas para ejecutar, no pruebas ya aprobadas.** `tests/postgres_fixture.sql` es exclusivamente para PostgreSQL aislado del CI; no debe ejecutarse en tu Supabase.

Después de desplegar la función, revisa Edge Functions > spae-api > Logs si falla una operación. Nunca borres tablas para resolver un error: copia el mensaje exacto. La función y la migración se necesitan juntas.

## Referencias de implementación

[Invocación de funciones desde Flutter](https://supabase.com/docs/reference/dart/functions-invoke)

[Permisos y Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
