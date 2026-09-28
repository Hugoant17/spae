# SPAE · Últimos ajustes 26/09/2026

Esta entrega responde al documento **ULTIMOS AJUSTES Y ERRORES SISTEMA SPAE 2609.docx**.

## Observaciones del sistema levantadas

1. **Registro de miembro / `email rate limit`**
   - La interfaz identifica el error y explica que proviene del envío de correos de Supabase Auth, no de la tabla de miembros.
   - No se deshabilita la confirmación de correo ni se autoconfirman cuentas, porque eso permitiría registrar correos sin demostrar su propiedad.
   - Para producción se debe configurar **Custom SMTP** en Supabase y ajustar el límite de envío desde Authentication > Rate Limits. Esta parte es configuración del proyecto y no puede eliminarse únicamente desde Flutter.

2. **Fecha de inicio de la capacitación**
   - El formulario guarda las fechas seleccionadas como hora civil de Perú y las convierte a UTC solo al enviarlas al servidor.
   - El certificado toma exclusivamente `trainings.start_date`.
   - Los certificados nuevos guardan `training_date` como día civil de Perú (`YYYY-MM-DD`).
   - El render del PDF trata esa fecha como fecha civil para evitar el error 23/09 -> 22/09.
   - Los certificados ya emitidos se normalizan mediante la migración nueva y se regeneran en la ruta `v6/` al descargarse nuevamente.

3. **Eliminar capacitación cancelada**
   - `spae_delete_training` elimina si no existe historial.
   - Si la capacitación tiene inscripciones y ya está cancelada, la archiva para conservar historial, pagos y certificados y la retira de la lista administrativa.

4. **Aprobar/Rechazar inscripciones**
   - La Edge Function ya no usa el despachador genérico para esta operación.
   - Se agregó `spae_review_enrollment_v2`, evitando el error `Acción no admitida`.
   - Al rechazar se mantiene la limpieza prevista para permitir una nueva inscripción cuando el participante no tiene otro historial.

5. **Eliminar participantes**
   - `participant_delete` está implementado como acción explícita de `spae-api`.
   - Puede eliminar registros sin historial aprobado/certificados. Si existe historial que debe conservarse, se bloquea con un mensaje claro.

6. **Certificados**
   - Se antepone `Lic.` a todos los nombres al renderizar.
   - Se usa la fecha de inicio registrada de la capacitación.
   - El botón de emisión ahora dice **Emitir Certificado** y los documentos existentes muestran **Descargar Certificado**.

7. **Eliminar / Inactivar miembros**
   - Se agregó una lista dedicada `spae_member_accounts` para asistente y administrador.
   - Se agregaron botones **Inactivar cuenta / Activar cuenta** y **Eliminar miembro**.
   - La eliminación física se bloquea cuando el miembro ya tiene historial de inscripciones; en ese caso se debe inactivar para conservar trazabilidad.
   - Los registros de auditoría se conservan aunque se elimine una cuenta sin historial.

8. **DNI del miembro vacío**
   - El formulario sigue permitiendo editar el DNI si el perfil aún no lo tiene.
   - `member_enroll` ahora toma ese DNI, valida los 8 dígitos, comprueba que no pertenezca a otra cuenta, lo guarda en el perfil y continúa la inscripción. Antes el backend volvía a reemplazarlo por el DNI vacío del perfil.

## Instalación sobre la versión anterior

Ejecutar **solo** esta migración nueva si `202609260001_observaciones_finales.sql` ya fue aplicada:

```text
supabase/migrations/202609260002_ultimos_ajustes.sql
```

Después volver a desplegar obligatoriamente la Edge Function:

```powershell
npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
```

Finalmente recompilar Flutter. Si no se vuelve a desplegar `spae-api`, los botones Aprobar/Rechazar/Eliminar pueden seguir respondiendo con la versión anterior del backend.

## Email rate limit

El límite del servidor de correo por defecto de Supabase es externo al código Flutter. La corrección segura es configurar un SMTP propio; no se recomienda quitar la confirmación de correo ni autoconfirmar usuarios para evitar el límite.

## SCRUM

El Word también solicita mejorar índice, gráfico físico de base de datos, agregar el gráfico exportado de la base de datos y actas de planificación/revisión. El proyecto contiene el modelo extraído y una guía en `docs/SCRUM_PENDIENTES_26_09.md`, pero para modificar el **SCRUM entregable** se necesita el archivo editable actual del SCRUM; no está dentro del ZIP de código.
