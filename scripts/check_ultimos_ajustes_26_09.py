"""Comprobaciones estáticas para ULTIMOS AJUSTES Y ERRORES SISTEMA SPAE 2609."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def text(path): return (root/path).read_text(encoding='utf-8')
checks={
 'Rate limit explicado con SMTP': ('lib/core/widgets/member_registration_form.dart','configura SMTP propio'),
 'Revisión de inscripción v2': ('supabase/functions/spae-api/index.ts','spae_review_enrollment_v2'),
 'RPC revisión de inscripción': ('supabase/migrations/202609260002_ultimos_ajustes.sql','spae_review_enrollment_v2'),
 'Eliminar participante explícito': ('supabase/functions/spae-api/index.ts',"action==='participant_delete'"),
 'Prefijo Lic.': ('supabase/functions/spae-api/certificate.ts','`Lic. ${rawPerson}`'),
 'Fecha civil de certificado': ('supabase/functions/spae-api/certificate.ts','const civil=rawTrainingDate.match'),
 'Certificado usa inicio': ('supabase/migrations/202609260002_ultimos_ajustes.sql',"'training_date',local_start"),
 'Regeneración certificado v6': ('supabase/functions/spae-api/index.ts','v6/${c.id}.pdf'),
 'Eliminar capacitación cancelada': ('supabase/migrations/202609260001_observaciones_finales.sql','spae_delete_training'),
 'Lista de cuentas de miembro': ('supabase/migrations/202609260002_ultimos_ajustes.sql','spae_member_accounts'),
 'Inactivar miembro': ('lib/core/live/business_pages.dart',"'Inactivar cuenta'"),
 'Eliminar miembro': ('lib/core/live/business_pages.dart',"'Eliminar miembro'"),
 'Emitir Certificado': ('lib/core/live/business_pages.dart',"label:'Emitir Certificado'"),
 'DNI vacío guardado en backend': ('supabase/functions/spae-api/index.ts','let memberDni='),
}
errors=[]
for name,(path,needle) in checks.items():
    if needle not in text(path): errors.append(f'{name}: falta {needle!r} en {path}')
print(f'Últimos ajustes verificados: {len(checks)-len(errors)}/{len(checks)}')
for e in errors: print('ERROR:',e)
raise SystemExit(bool(errors))
