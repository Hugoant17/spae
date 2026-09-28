# Correcciones SPAE del 23 de septiembre de 2026

## Instalar en la base de datos existente

1. Guarda una copia de tu proyecto y de la base de datos. Sustituye la carpeta Flutter completa por esta versión.
2. En el SQL Editor de tu proyecto Supabase, ejecuta `supabase/migrations/202609230001_correcciones.sql` **una sola vez**. Requiere que ya estén aplicadas `202609090001_backend.sql`, `202609160001_observaciones.sql` y `202609160002_fichas_entrega.sql`, en ese orden.
3. En PowerShell, dentro de esta carpeta (donde está `pubspec.yaml`), inicia sesión y vuelve a desplegar la función:

   ```powershell
   npx supabase login
   npx supabase functions deploy spae-api --project-ref friocmtkfannujwkslge --no-verify-jwt
   flutter pub get
   flutter run -d chrome --web-port=3000 --dart-define=SUPABASE_URL="https://friocmtkfannujwkslge.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="sb_publishable_GiagZG0ZL3Ci4pDo8ptXLw_bDjKFfvl"
   ```

   Si arrancas desde una base nueva, ejecuta también `supabase/schema.sql` y las cuatro migraciones por orden de fecha antes del despliegue.

4. Abre Administrador → Configuración e ingresa los enlaces HTTPS oficiales de Facebook y WhatsApp cuando estén disponibles. El adicional del certificado inicia en S/ 50 y se puede ajustar ahí. No se inventó una cuenta ni un teléfono institucional.

## Cambios operativos

- El miembro con cuenta aprobada, correo confirmado y **membresía anual vigente** se inscribe sin comprobante cuando elige **No** en certificado. Con **Sí**, adjunta comprobante y número de operación por el adicional de S/ 50 (o el monto configurado). Los demás participantes pagan el precio del curso; el certificado agrega el adicional.
- El botón de acceso público permite elegir miembro, asistente y administrador. El menú interior muestra el rol. Las etiquetas de estados tienen un punto verde, amarillo o rojo.
- El código privado de los nuevos registros tiene 10 caracteres. Los códigos anteriores de 12 caracteres siguen siendo válidos. La consulta con DNI exige exactamente ocho dígitos y conserva el código privado por seguridad.
- El administrador puede subir un flyer JPG o PNG de hasta 3 MB. Se muestra a mayor tamaño en el detalle. El enlace HTTPS anterior sigue disponible como alternativa.
- Las inscripciones se revisan sin casillas manuales para los siete campos de TRC. La validación se calcula a partir de los datos recibidos. La asistente puede registrar varios participantes y sesiones.
- **Emitir PDF** registra la hora utilizada en TEC. Se quitó **Registrar entrega**. La emisión individual descarga el PDF; la emisión masiva genera los documentos de los participantes elegibles y presenta éxitos y errores. TEC y su exportación se muestran con dos decimales de hora. Los datos históricos de entrega manual permanecen en la base de datos por trazabilidad.
- El PDF usa el logo, composición, colores y firmas visibles en la muestra compartida. Sustituye nombre, evento, fecha, duración y registro por los datos reales. El registro de ejemplo de `Certificado_SPAE_vista_previa.pdf` es solo una muestra y no debe entregarse a un participante.

## Comprobación recomendada tras desplegar

1. Entra como miembro activo, inscríbete con **No** sin comprobante y comprueba que queda pendiente de aprobación.
2. Inscríbete a otro curso con **Sí** y adjunta el comprobante; revisa que el pago refleje el adicional configurado.
3. Aprueba dos participantes, registra asistencia en dos sesiones, emite un PDF y consulta TEC en Dashboard → Ficha TEC. Repite con emisión masiva.
4. Descarga el PDF desde la consulta pública autenticada con DNI/correo y código privado. Comprueba el flyer y los enlaces de Contacto.

La migración y el despliegue deben hacerse en la misma instalación; si se actualiza solo Flutter o solo la función, la aplicación puede seguir respondiendo «Acción no admitida».
