-- Actualización incremental 16/09/2026. Aplicar DESPUÉS de 202609090001_backend.sql.
begin;
alter table public.profiles add column if not exists registration_status text not null default 'approved' check (registration_status in ('pending','approved','rejected'));
alter table public.profiles alter column registration_status set default 'pending';
alter table public.profiles add column if not exists registration_reason text;
alter table public.enrollments add column if not exists registration_snapshot jsonb;
alter table public.enrollments add column if not exists registration_checks jsonb not null default '{}';
-- Congela los datos disponibles en la actualización; no inventa el historial previo.
update public.enrollments e set registration_snapshot=jsonb_build_object('full_name',p.full_name,'dni',p.dni,'phone',p.phone,'hospital',p.hospital,'region',p.region,'nurse_auditor_registry',p.nurse_auditor_registry,'wants_certificate',e.wants_certificate)
from public.participants p where p.id=e.participant_id and e.registration_snapshot is null;
create or replace function public.spae_capture_registration() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.registration_snapshot is null then
 select jsonb_build_object('full_name',p.full_name,'dni',p.dni,'phone',p.phone,'hospital',p.hospital,'region',p.region,'nurse_auditor_registry',p.nurse_auditor_registry,'wants_certificate',new.wants_certificate) into new.registration_snapshot from participants p where p.id=new.participant_id;
 end if; return new;
end $$;
drop trigger if exists spae_registration_snapshot on public.enrollments;
create trigger spae_registration_snapshot before insert on public.enrollments for each row execute function public.spae_capture_registration();
revoke all on function public.spae_capture_registration() from public;

create or replace function public.spae_member_requests() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
 if not public.is_staff() then raise exception 'Solo personal autorizado'; end if;
 return (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc),'[]') from profiles p where role='member');
end $$;
revoke all on function public.spae_member_requests() from public,anon;
grant execute on function public.spae_member_requests() to authenticated;

create or replace function public.spae_review_member(p_id uuid,p_status text,p_reason text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
 if not public.is_staff() then raise exception 'Solo personal autorizado'; end if;
 if p_status not in ('approved','rejected') then raise exception 'Estado inválido'; end if;
 if p_status='rejected' and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Indica el motivo'; end if;
 update profiles set registration_status=p_status,registration_reason=p_reason,updated_at=now() where id=p_id and role='member' and registration_status='pending';
 if not found then raise exception 'Solicitud inexistente o ya revisada'; end if;
 insert into audit_logs(actor_id,action,entity,entity_id,details) values(auth.uid(),'review_member','profiles',p_id::text,jsonb_build_object('status',p_status,'reason',p_reason));
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.spae_review_member(uuid,text,text) from public,anon;
grant execute on function public.spae_review_member(uuid,text,text) to authenticated;
create or replace function public.spae_action(p_action text,p jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare uid uuid:=auth.uid(); r app_role:=public.current_app_role(); result jsonb:='{}';
 tid uuid; eid uuid; mid uuid; item jsonb; e enrollments; m memberships; mp membership_payments; c certificates; pr profiles; t trainings;
 percent numeric; minimum numeric; start_day date; n integer; new_id uuid; amount numeric; sid uuid;
begin
 if uid is null or r is null then raise exception 'Sesión no válida o cuenta desactivada'; end if;
 if p_action in('save_training','delete_training','save_settings','assistant_state') and r<>'administrator' then raise exception 'Solo administrador'; end if;
 if p_action in('review_enrollment','review_membership','save_attendance','issue_certificate','recover_code') and r not in('assistant','administrator') then raise exception 'Solo personal autorizado'; end if;
 if p_action='save_training' then
  tid:=coalesce(nullif(p->>'id','')::uuid,gen_random_uuid());
  select * into t from trainings where id=tid for update;
  if length(trim(coalesce(p->>'title','')))<3 then raise exception 'Ingresa un nombre de capacitación'; end if;
  if (p->>'max_capacity')::integer<(select count(*) from enrollments where training_id=tid and status in('pending','approved')) then raise exception 'El cupo no puede ser menor a los registros existentes'; end if;
  if jsonb_array_length(coalesce(p->'sessions','[]'))<1 then raise exception 'Programa al menos una sesión'; end if;
  if exists(select 1 from enrollments where training_id=tid) and
     exists(select 1 from training_sessions s where s.training_id=tid and not exists(select 1 from jsonb_array_elements(p->'sessions') z where z->>'id'=s.id::text)) then
    raise exception 'No se pueden eliminar sesiones de una capacitación con inscritos'; end if;
  insert into trainings(id,title,slug,description,objectives,syllabus,speaker,modality,start_date,end_date,total_hours,max_capacity,price,image_url,status,created_by)
  values(tid,trim(p->>'title'),coalesce(nullif(p->>'slug',''),tid::text),coalesce(p->>'description',''),p->>'objectives',p->>'syllabus',p->>'speaker',p->>'modality',
    (p->>'start_date')::timestamptz,nullif(p->>'end_date','')::timestamptz,(p->>'total_hours')::numeric,(p->>'max_capacity')::integer,(p->>'price')::numeric,p->>'image_url',(p->>'status')::record_status,uid)
  on conflict(id) do update set title=excluded.title,description=excluded.description,objectives=excluded.objectives,syllabus=excluded.syllabus,
    speaker=excluded.speaker,modality=excluded.modality,start_date=excluded.start_date,end_date=excluded.end_date,total_hours=excluded.total_hours,
    max_capacity=excluded.max_capacity,price=excluded.price,image_url=excluded.image_url,status=excluded.status,updated_at=now();
  delete from training_sessions s where training_id=tid and not exists(select 1 from jsonb_array_elements(p->'sessions') z where z->>'id'=s.id::text);
  for item in select * from jsonb_array_elements(p->'sessions') loop
    sid:=coalesce(nullif(item->>'id','')::uuid,gen_random_uuid());
    if exists(select 1 from training_sessions where id=sid and training_id<>tid) then raise exception 'Sesión de otra capacitación'; end if;
    insert into training_sessions(id,training_id,title,starts_at) values(sid,tid,item->>'title',(item->>'starts_at')::timestamptz)
    on conflict(id) do update set title=excluded.title,starts_at=excluded.starts_at;
  end loop;
  result:=jsonb_build_object('id',tid);
 elsif p_action='delete_training' then
  tid:=(p->>'id')::uuid;
  if exists(select 1 from enrollments where training_id=tid) then raise exception 'Conserva el historial: cancela la capacitación en lugar de eliminarla'; end if;
  delete from trainings where id=tid;
  if not found then raise exception 'Capacitación inexistente'; end if;
 elsif p_action='save_profile' then
  if coalesce(p->>'phone','')!~'^9[0-9]{8}$' or length(trim(coalesce(p->>'full_name','')))<3 then raise exception 'Nombre y celular no válidos'; end if;
  select * into pr from profiles where id=uid;
  if pr.dni is null and coalesce(p->>'dni','')!~'^[0-9]{8}$' then raise exception 'Completa el DNI de 8 dígitos'; end if;
  update profiles set full_name=trim(p->>'full_name'),phone=p->>'phone',dni=coalesce(dni,p->>'dni'),hospital=p->>'hospital',region=p->>'region',nurse_auditor_registry=(p->>'nurse_auditor_registry')::boolean,updated_at=now() where id=uid;
  update participants set full_name=trim(p->>'full_name'),phone=p->>'phone',hospital=p->>'hospital',region=p->>'region' where profile_id=uid;
  perform spae_link_member();
 elsif p_action='submit_membership' then
  if r<>'member' or not exists(select 1 from profiles where id=uid and registration_status='approved') then raise exception 'Tu solicitud de miembro debe ser aprobada antes de registrar el pago anual'; end if;
  perform pg_advisory_xact_lock(hashtext(uid::text));
  select * into m from memberships where profile_id=uid order by created_at desc limit 1 for update;
  if m.id is null then insert into memberships(profile_id) values(uid) returning * into m; end if;
  if exists(select 1 from membership_payments where membership_id=m.id and status='pending') then raise exception 'Ya tienes un pago pendiente de revisión'; end if;
  start_day:=greatest(current_date,coalesce(m.ends_on+1,current_date));
  if exists(select 1 from membership_payments where membership_id=m.id and period=start_day::text and status='approved') then raise exception 'Periodo ya pagado'; end if;
  select (value::text)::numeric into amount from system_settings where key='annual_membership_amount';
  if amount is null or amount<=0 then raise exception 'El administrador debe configurar el monto anual'; end if;
  if (p->>'receipt_path') not like uid::text||'/%' or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=p->>'receipt_path') then raise exception 'Comprobante no válido'; end if;
  if length(trim(coalesce(p->>'operation_number','')))<1 then raise exception 'Número de operación obligatorio'; end if;
  insert into membership_payments(membership_id,period,amount,payment_method,operation_number,receipt_path)
  values(m.id,start_day::text,amount,p->>'payment_method',p->>'operation_number',p->>'receipt_path') returning id into mid;
  if m.ends_on is null then update memberships set status='pending' where id=m.id; end if;
  result:=jsonb_build_object('id',mid,'amount',amount);
 elsif p_action='review_membership' then
  select * into mp from membership_payments where id=(p->>'id')::uuid for update;
  if mp.id is null or mp.status<>'pending' then raise exception 'Pago inexistente o ya revisado'; end if;
  select * into m from memberships where id=mp.membership_id for update;
  if p->>'status' not in('approved','rejected') then raise exception 'Estado no válido'; end if;
  if p->>'status'='rejected' and length(trim(coalesce(p->>'reason','')))<3 then raise exception 'Indica el motivo'; end if;
  if p->>'status'='approved' then
   start_day:=greatest(current_date,coalesce(m.ends_on+1,current_date));
   update memberships set starts_on=start_day,ends_on=(start_day+interval '12 months')::date-1,status='active' where id=m.id;
  elsif m.ends_on is null then
   update memberships set status='rejected' where id=m.id;
  end if;
  update membership_payments set status=(p->>'status')::record_status,rejection_reason=p->>'reason',reviewed_by=uid,reviewed_at=now() where id=mp.id;
 elsif p_action='review_enrollment' then
  select * into e from enrollments where id=(p->>'id')::uuid for update;
  if e.id is null or e.status<>'pending' then raise exception 'Inscripción inexistente o ya revisada'; end if;
  if p->>'status' not in('approved','rejected') then raise exception 'Estado no válido'; end if;
  if p->>'status'='rejected' and length(trim(coalesce(p->>'reason','')))<3 then raise exception 'Indica el motivo'; end if;
  update enrollments set status=(p->>'status')::record_status,rejection_reason=p->>'reason',reviewed_by=uid,reviewed_at=now() where id=e.id;
  update training_payments set status=(p->>'status')::record_status,rejection_reason=p->>'reason',reviewed_by=uid,reviewed_at=now() where enrollment_id=e.id;
 elsif p_action='save_attendance' then
  minimum:=coalesce((select (value::text)::numeric from system_settings where key='minimum_attendance_percent'),80);
  for item in select * from jsonb_array_elements(p->'rows') loop
   select * into e from enrollments where id=(item->>'enrollment_id')::uuid for update;
   if e.id is null or e.status<>'approved' then raise exception 'Solo participantes aprobados'; end if;
   if not exists(select 1 from training_sessions where id=(item->>'session_id')::uuid and training_id=e.training_id and starts_at<=now()) then raise exception 'Sesión inválida, futura o de otra capacitación'; end if;
   if exists(select 1 from certificates where enrollment_id=e.id) then raise exception 'No se modifica asistencia con certificado emitido'; end if;
   insert into attendance(session_id,enrollment_id,status,recorded_by) values((item->>'session_id')::uuid,e.id,item->>'status',uid)
   on conflict(session_id,enrollment_id) do update set status=excluded.status,recorded_by=uid,recorded_at=now();
   percent:=spae_attendance(e.id);
   update enrollments set requirement_met_at=case when percent>=minimum and e.wants_certificate and exists(select 1 from training_payments where enrollment_id=e.id and status='approved') then coalesce(requirement_met_at,now()) else null end where id=e.id;
  end loop;
 elsif p_action='issue_certificate' then
  select * into e from enrollments where id=(p->>'id')::uuid for update;
  select * into c from certificates where enrollment_id=e.id;
  if c.id is not null then return to_jsonb(c); end if;
  minimum:=coalesce((select (value::text)::numeric from system_settings where key='minimum_attendance_percent'),80);
  if e.id is null or e.status<>'approved' or not e.wants_certificate or spae_attendance(e.id)<minimum then raise exception 'El participante no cumple los requisitos de certificación'; end if;
  if not exists(select 1 from training_payments where enrollment_id=e.id and status='approved') then raise exception 'Pago no aprobado'; end if;
  select * into t from trainings where id=e.training_id;
  insert into certificates(enrollment_id,certificate_number,pdf_path,requirement_met_at,issued_by,snapshot)
  values(e.id,'SPAE-'||to_char(now(),'YYYY')||'-'||upper(substr(encode(gen_random_bytes(8),'hex'),1,12)), 'generated',coalesce(e.requirement_met_at,now()),uid,
   jsonb_build_object('full_name',(select full_name from participants where id=e.participant_id),'training',t.title,'hours',t.total_hours,'training_date',t.start_date,'institution','Sociedad Peruana de Auditoría en Enfermería')) returning * into c;
  result:=to_jsonb(c);
 elsif p_action='save_settings' then
  for item in select * from jsonb_array_elements(p->'items') loop
   if item->>'key' not in('minimum_attendance_percent','team_hourly_cost','annual_membership_amount','receipt_max_mb','contact_email','contact_phone','contact_address') then raise exception 'Parámetro no permitido'; end if;
   if item->>'key' in('minimum_attendance_percent','team_hourly_cost','annual_membership_amount','receipt_max_mb') then
    amount:=(item->>'value')::numeric;
    if amount<0 then raise exception 'Valor negativo'; end if;
    if item->>'key'='minimum_attendance_percent' and (amount<=0 or amount>100) then raise exception 'Asistencia entre 1 y 100'; end if;
    if item->>'key'='receipt_max_mb' and (amount<1 or amount>5) then raise exception 'Comprobantes de 1 a 5 MB'; end if;
   end if;
   insert into system_settings(key,value,updated_by) values(item->>'key',item->'value',uid)
   on conflict(key) do update set value=excluded.value,updated_by=uid,updated_at=now();
  end loop;
 elsif p_action='assistant_state' then
  update profiles set enabled=(p->>'enabled')::boolean,updated_at=now() where id=(p->>'id')::uuid and role='assistant';
  if not found then raise exception 'Asistente inexistente'; end if;
 elsif p_action='recover_code' then
  -- Solo personal, después de validar la identidad fuera del sistema.
  if length(coalesce(p->>'code',''))<12 then raise exception 'Código insuficiente'; end if;
  update participants set lookup_hash=encode(digest(p->>'code','sha256'),'hex') where id=(p->>'id')::uuid;
  if not found then raise exception 'Participante inexistente'; end if;
 else raise exception 'Acción no admitida'; end if;
 insert into audit_logs(actor_id,action,entity,entity_id,details) values(uid,p_action,'spae',coalesce(p->>'id',result->>'id'),p - 'code' - 'password');
 return result;
end $$;
revoke all on function public.spae_action(text,jsonb) from public,anon;
grant execute on function public.spae_action(text,jsonb) to authenticated;

create or replace function public.spae_public_enroll(p jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare t trainings; who participants; eid uuid; cnt integer; member_profile profiles; trusted boolean:=false; begin
 if p ? '_member_id' then
 select * into member_profile from profiles where id=(p->>'_member_id')::uuid and enabled and role='member' and registration_status='approved';
 if member_profile.id is null or not exists(select 1 from auth.users where id=member_profile.id and email_confirmed_at is not null) then raise exception 'Cuenta pendiente de aprobación o correo sin verificar'; end if;
 if member_profile.dni is distinct from p->>'dni' or lower(member_profile.email) is distinct from lower(p->>'email') then raise exception 'Identidad no válida'; end if;
 trusted:=true;
 end if;
 -- Solo Edge Function con service_role.
 select * into t from trainings where id=(p->>'training_id')::uuid for update;
 if t.id is null or t.status<>'active' or (t.end_date is not null and t.end_date<now()) then raise exception 'Capacitación no disponible'; end if;
 if trim(coalesce(p->>'full_name','')) !~ '^\S+\s+\S+' then raise exception 'Ingresa nombres y apellidos completos'; end if;
 if coalesce(p->>'dni','') !~ '^[0-9]{8}$' then raise exception 'El DNI debe tener exactamente 8 dígitos'; end if;
 if coalesce(p->>'phone','') !~ '^9[0-9]{8}$' then raise exception 'El celular debe tener 9 dígitos y comenzar con 9'; end if;
 if coalesce(p->>'email','') !~ '^[^ @]+@[^ @]+\.[^ @]+$' then raise exception 'Ingresa un correo válido'; end if;
 if length(trim(coalesce(p->>'hospital','')))<3 then raise exception 'Ingresa el nombre de la institución'; end if;
 if length(trim(coalesce(p->>'region','')))<3 then raise exception 'Selecciona la región'; end if;
 if coalesce(jsonb_typeof(p->'nurse_auditor_registry'),'null')<>'boolean' then raise exception 'Responde si cuentas con registro de enfermera auditora'; end if;
 if coalesce(jsonb_typeof(p->'wants_certificate'),'null')<>'boolean' then raise exception 'Responde si deseas certificado'; end if;
 select count(*) into cnt from enrollments where training_id=t.id and status in('pending','approved');
 if cnt>=t.max_capacity then raise exception 'Cupos agotados'; end if;
 select * into who from participants where dni=p->>'dni' for update;
 if who.id is not null then
   -- Impide sobrescribir identidad por conocer solo DNI/correo.
   if not (trusted and lower(who.email)=lower(member_profile.email) and (who.profile_id is null or who.profile_id=member_profile.id)) and (lower(who.email)<>lower(trim(p->>'email')) or who.lookup_hash is null or who.lookup_hash<>encode(digest(coalesce(p->>'previous_code',''),'sha256'),'hex')) then
     raise exception 'El DNI ya tiene historial. Usa el correo y código privado de tu primera inscripción';
   end if;
 else
  insert into participants(full_name,dni,email,phone,hospital,region,nurse_auditor_registry,lookup_hash)
  values(trim(p->>'full_name'),p->>'dni',lower(trim(p->>'email')),p->>'phone',trim(p->>'hospital'),trim(p->>'region'),(p->>'nurse_auditor_registry')::boolean,p->>'lookup_hash') returning * into who;
 end if;
 if trusted then update participants set profile_id=member_profile.id where id=who.id; end if;
 if exists(select 1 from enrollments where training_id=t.id and participant_id=who.id) then raise exception 'Ya estás inscrito en esta capacitación. Consulta el estado de tu inscripción'; end if;
 insert into enrollments(training_id,participant_id,wants_certificate,completion_rate,registration_snapshot)
 values(t.id,who.id,(p->>'wants_certificate')::boolean,100,p - 'file_base64' - 'previous_code' - 'lookup_hash' - '_member_id') returning id into eid;
 if length(trim(coalesce(p->>'operation_number','')))=0 or length(coalesce(p->>'receipt_path',''))=0 then raise exception 'Adjunta el comprobante y número de operación'; end if;
 insert into training_payments(enrollment_id,amount,payment_method,operation_number,receipt_path)
 values(eid,t.price,p->>'payment_method',trim(p->>'operation_number'),p->>'receipt_path');
 return jsonb_build_object('id',eid,'code',(select code from enrollments where id=eid),'status','pending');
end $$;
revoke all on function public.spae_public_enroll(jsonb) from public,anon,authenticated;
grant execute on function public.spae_public_enroll(jsonb) to service_role;


create or replace function public.spae_individual_indicators() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.is_administrator() then raise exception 'Solo administrador'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.training,x.created_at,x.id),'[]') into result from (
 select e.id,e.training_id,e.created_at,t.title as training,t.start_date,e.code as participant_code,p.full_name,p.dni,
 e.status,e.wants_certificate,e.registration_snapshot,e.registration_checks,
 coalesce(c.requirement_met_at,e.requirement_met_at) as requirement_met_at,c.issued_at,c.certificate_number,
 public.spae_attendance(e.id) as naa,
 case when c.id is not null then round((extract(epoch from(c.issued_at-c.requirement_met_at))/3600)::numeric) end as tec_hours,
 (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'starts_at',s.starts_at,'status',a.status) order by s.starts_at,s.id),'[]') from training_sessions s left join attendance a on a.session_id=s.id and a.enrollment_id=e.id where s.training_id=e.training_id) as sessions
 from enrollments e join participants p on p.id=e.participant_id join trainings t on t.id=e.training_id left join certificates c on c.enrollment_id=e.id
 ) x; return result;
end $$;
revoke all on function public.spae_individual_indicators() from public,anon;
grant execute on function public.spae_individual_indicators() to authenticated;

create or replace function public.spae_review_fields(p_id uuid,p_checks jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare k text; v jsonb;
begin
 if not public.is_staff() then raise exception 'Solo personal autorizado'; end if;
 for k,v in select * from jsonb_each(p_checks) loop
 if k not in ('full_name','dni','phone','nurse_auditor_registry','hospital','region','wants_certificate') or jsonb_typeof(v)<>'boolean' then raise exception 'Criterio no válido'; end if;
 end loop;
 update enrollments set registration_checks=p_checks where id=p_id;
 if not found then raise exception 'Inscripción inexistente'; end if;
 insert into audit_logs(actor_id,action,entity,entity_id,details) values(auth.uid(),'review_fields','enrollments',p_id::text,p_checks);
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.spae_review_fields(uuid,jsonb) from public,anon;
grant execute on function public.spae_review_fields(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
