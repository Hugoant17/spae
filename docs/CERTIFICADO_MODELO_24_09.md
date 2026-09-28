# Certificado SPAE: actualización del diseño

El PDF ahora usa la imagen oficial compartida como base. Conserva el logo, la tipografía de «Certificado», las formas, firmas y cargos. Sustituye el nombre del participante, capacitación, fecha, duración y registro por datos del sistema. Incluye texto buscable.

## Aplicar sobre el sistema que ya ejecutas

1. Descomprime el proyecto actualizado y utiliza su carpeta `spae_flutter`. Si conservas tu carpeta anterior, copia a `supabase/functions/spae-api/` estos archivos: `index.ts`, `certificate.ts`, `certificate_template.ts` y `certificate_glyphs.ts`.
2. Abre PowerShell en la carpeta `spae_flutter` que contiene `pubspec.yaml`.
3. Ejecuta:

   ```powershell
   npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
   ```

4. En la aplicación, entra como asistente a **Certificados**. Si ya aparece el botón **PDF**, descárgalo de nuevo: el servidor reconstruye el documento con la versión `v4` del diseño. Para una inscripción nueva aprobada, con certificado solicitado, pago aprobado y asistencia suficiente, pulsa **Emitir PDF**.

**No repitas las migraciones SQL** por esta actualización. No es necesario volver a ejecutar `flutter pub get` para modificar el certificado: la plantilla se genera en Supabase.

Revisa `docs/preview/Certificado_SPAE_vista_previa.pdf` antes de entregar un certificado real. La vista previa contiene «Nombre de muestra» y no es un certificado válido de participante.
