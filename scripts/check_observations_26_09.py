"""Comprobaciones estáticas del levantamiento 26/09. No sustituyen flutter analyze ni pruebas en Supabase."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def read(path): return (root/path).read_text()
checks={
 'Acceso administrativo separado': ('lib/core/widgets/page_frame.dart', "tooltip:'Administrativo'"),
 'Acceso de miembro directo': ('lib/core/widgets/page_frame.dart', "context.go('/miembro/login')"),
 'Ayuda código privado': ('lib/core/live/public_pages.dart', 'Este código se genera al crear la inscripción'),
 'Olvidé mi código': ('lib/core/live/public_pages.dart', 'Olvidé mi código'),
 'Hora Perú al guardar': ('lib/core/live/admin_pages.dart', 'peruWallClockToUtcIso'),
 'Mensaje activación correo': ('lib/core/widgets/member_registration_form.dart', 'Revisa el buzón de tu correo registrado para activar tu cuenta'),
 'Manejo email rate limit': ('lib/core/widgets/member_registration_form.dart', "contains('rate limit')"),
 'TEC sin formato DateTime incompatible': ('lib/core/live/download.dart', "TextCellValue(display(v))"),
 'Eliminar/archivar capacitación': ('supabase/migrations/202609260001_observaciones_finales.sql', 'spae_delete_training'),
 'Scrollbar visible': ('lib/core/live/components.dart', 'thumbVisibility:true'),
 'Prefijo Lic.': ('supabase/functions/spae-api/certificate.ts', '`Lic. ${rawPerson}`'),
 'Certificado v6': ('supabase/functions/spae-api/index.ts', 'v6/${c.id}.pdf'),
 'Rechazo miembro libera cuenta': ('supabase/functions/spae-api/index.ts', 'admin.auth.admin.deleteUser(p.id)'),
 'Rechazo inscripción libera DNI': ('supabase/functions/spae-api/index.ts', "if(participant&&!participant.profile_id&&(countResponse.count??0)===0)"),
 'Eliminar participante': ('lib/core/live/business_pages.dart', "label:'Eliminar',icon:Icons.delete_outline"),
 'DNI vacío editable': ('lib/core/live/business_pages.dart', "readOnly:(data['dni']??'').toString().trim().isNotEmpty"),
 'Miembro exonerado': ('lib/core/live/public_pages.dart', 'Curso: Exonerado'),
 'Mis inscripciones': ('lib/core/navigation/nav_items.dart', "NavItem('Mis inscripciones'"),
 'Descargar Certificado': ('lib/core/live/business_pages.dart', "'Descargar Certificado'"),
 'TEC oculto para miembro': ('lib/core/live/business_pages.dart', 'memberCertificateColumns'),
}
errors=[]
for name,(path,needle) in checks.items():
 if needle not in read(path): errors.append(f'{name}: falta {needle!r} en {path}')
# El export TEC ya no debe aplicar CustomDateTimeNumFormat a DoubleCellValue.
if 'CustomDateTimeNumFormat' in read('lib/core/live/download.dart'):
 errors.append('TEC: todavía existe CustomDateTimeNumFormat en download.dart')
print(f'Observaciones verificadas: {len(checks)-len(errors)}/{len(checks)}')
for e in errors: print('ERROR:',e)
raise SystemExit(bool(errors))
