# SPAE · Levantamiento final de observaciones 26/09/2026

Esta entrega aplica las observaciones del documento **ULTIMOS AJUSTES Y ERRORES SISTEMA SPAE** sobre el código Flutter + Supabase incluido en el ZIP.

## Pasos para actualizar

1. Haz copia de la versión que está funcionando.
2. En Supabase SQL Editor ejecuta, después de `202609230001_correcciones.sql`, el archivo:

   `supabase/migrations/202609260001_observaciones_finales.sql`

3. Vuelve a desplegar la función Edge porque se modificó la lógica de rechazos, participantes y certificados:

```powershell
npx supabase functions deploy spae-api --project-ref TU_PROJECT_REF --no-verify-jwt
```

4. En Flutter ejecuta:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web
```

5. Publica la carpeta `build/web` en tu hosting.

## Correcciones incluidas

- Página pública: `Acceder` queda para miembros y `Administrativo` abre únicamente Asistente / Administrador.
- Consulta y certificados: ayuda en el código privado y botón **Olvidé mi código** conectado al WhatsApp configurado en el sistema.
- Fechas: los formularios tratan la fecha/hora seleccionada como hora de Perú (UTC-5) antes de guardarla. La visualización vuelve a convertirla a hora de Perú, evitando el salto de día.
- Registro de miembro: mensaje explícito para revisar el correo y activar la cuenta.
- Error `email rate limit`: se muestra un mensaje entendible. El límite de envío pertenece al proveedor de correo de Supabase; para producción se recomienda configurar un SMTP propio en Auth si se alcanza con frecuencia.
- Exportación TEC: ya no intenta escribir fechas como `DoubleCellValue` con un formato incompatible; las fechas se exportan como texto local y TEC conserva el valor numérico calculado por el backend.
- Capacitaciones canceladas: el botón Eliminar borra las que no tienen historial y archiva las canceladas que sí tienen inscripciones, sin destruir trazabilidad.
- Tablas del asistente: barra horizontal visible en las tablas anchas y fechas uniformes `dd/MM/yyyy HH:mm`.
- Certificados: el nombre se genera con prefijo `Lic.` y la versión `v5` fuerza la regeneración del PDF al descargarlo.
- Rechazos: una inscripción rechazada se elimina y, si era el único historial del participante, también se libera su DNI. Una solicitud de miembro rechazada elimina la cuenta Auth, liberando el correo/DNI para un nuevo registro.
- Participantes: se agregó opción **Eliminar**, con protección para no destruir historial aprobado ni certificados emitidos.
- Miembro: si el DNI aún está vacío puede completarlo al inscribirse y se guarda primero en su perfil.
- Precios de miembro: se muestra **Curso: Exonerado** y únicamente el costo del certificado.
- Portal de miembro: `Mi historial` pasa a **Mis inscripciones**, `PDF` pasa a **Descargar Certificado** y se oculta `TEC horas`.

## Punto externo al código

La observación de `email rate limit` no puede eliminarse solo modificando Flutter: es una cuota de envío de correos de Supabase/Auth. El sistema ahora evita mensajes crípticos, pero si el proyecto seguirá usando confirmación por correo, configura un proveedor SMTP con capacidad suficiente.

## Observaciones de SCRUM

El ZIP del sistema no contiene el documento SCRUM editable. El PDF `Modelo SCRUM.pdf` sí estaba incrustado dentro del Word de observaciones y se extrajo a `docs/referencias/Modelo_SCRUM_extraido_desde_Word.pdf`; además se dejó `docs/SCRUM_PENDIENTES_26_09.md` con la estructura del índice, las entidades reales del sistema y plantillas de actas. Para insertar y paginar estas correcciones en el trabajo final todavía se necesita el SCRUM editable del proyecto.
