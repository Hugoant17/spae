# Matriz de levantamiento de observaciones SPAE · 26/09/2026

| Área | Observación | Estado | Implementación |
|---|---|---|---|
| Página principal | Separar acceso de miembros y administrativo | Levantada | `page_frame.dart` |
| Consulta / certificados | Ayuda de código privado y “Olvidé mi código” a WhatsApp | Levantada | `public_pages.dart` |
| Capacitaciones | Fecha aparece con un día adicional | Levantada | `api.dart`, `components.dart`, `admin_pages.dart` |
| Registro miembro | Avisar que debe activar su cuenta desde el correo | Levantada | `member_registration_form.dart` |
| Registro miembro | `email rate limit` | Mitigada / configuración externa | Mensaje claro en Flutter; SMTP se configura en Supabase Auth |
| Administrador | Error al exportar TEC a Excel | Levantada | `download.dart` |
| Administrador | Fechas inconsistentes en capacitación/certificado | Levantada | manejo horario Perú + render del certificado |
| Administrador | Eliminar capacitación cancelada | Levantada | `spae_delete_training` + archivo de capacitación con historial |
| Asistente | Barra horizontal en tabla y fechas ordenadas | Levantada | `components.dart`, `api.dart` |
| Certificado | Agregar `Lic.` al participante | Levantada | `certificate.ts`; PDF `v5` |
| Solicitudes | Rechazo debe liberar DNI | Levantada para nuevos rechazos | `spae-api/index.ts`, `member_requests.dart`, `business_pages.dart` |
| Participantes | Agregar Eliminar | Levantada con protección de historial | `business_pages.dart`, `spae-api/index.ts` |
| Miembro | DNI bloqueado cuando estaba vacío | Levantada | `public_pages.dart`, `business_pages.dart` |
| Miembro | Curso exonerado y certificado S/ 50/configurado | Levantada | `public_pages.dart` |
| Miembro | “Mi historial” → “Mis inscripciones” | Levantada | `nav_items.dart`, `member_training_history_page.dart` |
| Miembro | “PDF” → “Descargar Certificado” | Levantada | `business_pages.dart` |
| Miembro | Ocultar TEC horas | Levantada | columnas específicas de miembro |
| SCRUM | Índice, gráfico físico, gráfico exportado, actas | Avance preparado; falta documento editable | Se extrajo el modelo incrustado del Word y se agregó `SCRUM_PENDIENTES_26_09.md`; falta el SCRUM actual para insertar/paginar |

## Validación estática realizada

Se ejecutaron `scripts/check_structure.py` y `scripts/check_revision.py`. Ambos terminaron sin errores. El entorno de esta corrección no tiene Flutter/Dart instalado, por lo que la compilación real debe ejecutarse en el equipo de desarrollo con `flutter analyze`, `flutter test` y `flutter build web`.
