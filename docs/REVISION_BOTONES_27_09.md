# Revisión de botones del 27 de septiembre

Se revisaron las 33 vistas y sus componentes compartidos. Esta matriz es revisión de conexiones y pruebas de reglas, no un recorrido interactivo completo en producción.

| Perfil | Botones y flujos | Evidencia |
|---|---|---|
| Administrador | Crear/editar/cancelar capacitación, sesiones, configuración y activar asistente | Rutas revisadas; reglas SQL ejecutadas en pruebas locales. |
| Administrador | Crear/editar/eliminar asistente, subir flyer | Acciones presentes en spae-api; requieren desplegar y probar Auth/Storage reales. |
| Administrador | Dashboard, filtros y exportaciones Excel | TEC ajustado a tres decimales; código y fórmulas revisados; ejecución Flutter pendiente. |
| Asistente | Aprobar/rechazar inscripción, eliminar participante y restablecer código | RPC revisadas y pruebas SQL locales satisfactorias. Rechazo conserva motivo e historial. |
| Asistente | Aprobar/rechazar cuenta, eliminar/inactivar miembro | Estado y protección del borrado probados en SQL. Auth admin requiere Edge desplegada. |
| Asistente | Validar pago anual, activar membresía, guardar asistencia | Suite SQL local verifica renovación y elegibilidad. |
| Asistente | Emitir/descargar certificado, emisión por lote | Render PDF local probado; Storage, enlaces y lote real pendientes. |
| Miembro | Registro/login/salida/recuperación de contraseña | Formularios y rutas revisados; correo y Auth reales pendientes. |
| Miembro | Inscribirse, adjuntar pago, renovar, guardar perfil | Inscripción y aislamiento SQL probados. DNI y correo registrados se presentan en gris. |
| Miembro | Consultar membresía/historial y descargar PDF | Aislamiento SQL probado; descarga web real pendiente. |

## Acciones enlazadas en el código

RPC spae_action: assistant_state, review_membership, save_attendance, save_profile, save_settings, save_training.

Edge Function: assistant_delete, assistant_save, bulk_certificates, certificate, issue_certificate, lookup, member_delete, membership_payment, public_certificate, receipt, recover_code, resubmit, review_member, upload_flyer.

## Pruebas ejecutadas

PASS tests/postgres_fixture.sql
PASS supabase/schema.sql
PASS supabase/migrations/202609090001_backend.sql
PASS supabase/migrations/202609160001_observaciones.sql
PASS supabase/migrations/202609160002_fichas_entrega.sql
PASS supabase/migrations/202609230001_correcciones.sql
PASS supabase/migrations/202609260001_observaciones_finales.sql
PASS supabase/migrations/202609260002_ultimos_ajustes.sql
PASS supabase/migrations/202609270001_botones_participantes.sql
PASS supabase/migrations/202609270002_revision_tres_perfiles.sql
PASS tests/backend_smoke.sql
PASS tests/participant_actions.sql
PASS tests/three_roles.sql

Sintaxis TypeScript: correcta. Estructura/importaciones Dart: 0 errores. Render PDF: tres casos (nombre normal, prefijo existente y nombre largo).

Flutter/Dart y Deno no están instalados. No se ejecutaron flutter analyze, flutter test, flutter build ni la interfaz de producción. Las pruebas de widgets se entregan para ejecutarlas con VERIFICAR.ps1.