begin;
-- Actualización para el schema.sql original. Conserva usuarios y registros.
alter table public.participants add column if not exists lookup_hash text;
alter table public.enrollments add column if not exists requirement_met_at timestamptz;
alter table public.certificates add column if not exists snapshot jsonb not null default '{}'::jsonb;
create table if not exists public.api_rate_limits(key text primary key, hits integer not null, reset_at timestamptz not null);
alter table public.api_rate_limits enable row level security;

-- Cierre de accesos directos: las escrituras de negocio pasan por funciones transaccionales.
do $$ declare r record; begin
 for r in select tablename, policyname from pg_policies where schemaname='public'
 and tablename in ('profiles','trainings','training_sessions','participants','enrollments','training_payments','attendance','memberships','membership_payments','certificates','system_settings','audit_logs') loop
 execute format('drop policy %I on public.%I',r.policyname,r.tablename);
 end loop;
end $$;
create or replace function public.current_app_role() returns public.app_role
language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() and enabled $$;
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path=public
as $$ select coalesce(public.current_app_role() in ('assistant','administrator'),false) $$;
create or replace function public.is_administrator() returns boolean
language sql stable security definer set search_path=public
as $$ select coalesce(public.current_app_role()='administrator',false) $$;
create policy profile_self on public.profiles for select to authenticated using(id=auth.uid());
create policy catalogue on public.trainings for select using(status='active' or public.is_staff());
create policy sessions_catalogue on public.training_sessions for select using(exists(select 1 from public.trainings t where t.id=training_id and t.status='active') or public.is_staff());
-- Datos personales solo a través de RPC con rol e identidad comprobados.
revoke all on public.participants,public.enrollments,public.training_payments,public.attendance,
public.memberships,public.membership_payments,public.certificates,public.system_settings,public.audit_logs,public.api_rate_limits from anon,authenticated;
revoke insert,update,delete on public.profiles,public.trainings,public.training_sessions from anon,authenticated;
grant select on public.profiles to authenticated;
grant select on public.trainings,public.training_sessions to anon,authenticated;
alter view public.enrollment_attendance_summary set(security_invoker=true);
alter view public.management_indicators set(security_invoker=true);
revoke all on public.enrollment_attendance_summary,public.management_indicators from anon,authenticated;
revoke all on function public.public_participant_lookup(text) from public,anon,authenticated;

create or replace function public.spae_rate_limit(p_key text) returns boolean
language plpgsql security definer set search_path=public as $$
declare n integer; begin
 insert into api_rate_limits(key,hits,reset_at) values(p_key,1,now()+interval '10 minutes')
 on conflict(key) do update set hits=case when api_rate_limits.reset_at<now() then 1 else api_rate_limits.hits+1 end,
 reset_at=case when api_rate_limits.reset_at<now() then now()+interval '10 minutes' else api_rate_limits.reset_at end returning hits into n;
 return n<=30;
end $$;
revoke all on function public.spae_rate_limit(text) from public,anon,authenticated;
grant execute on function public.spae_rate_limit(text) to service_role;

-- Proporción calculada contra todas las sesiones programadas; ausencias/no registradas cuentan cero.
create or replace function public.spae_attendance(p_id uuid) returns numeric
language sql stable security definer set search_path=public as $$
 select coalesce(round(100.0 * count(a.id) filter(where a.status='present') / nullif(count(s.id),0),1),0)
 from enrollments e left join training_sessions s on s.training_id=e.training_id
 left join attendance a on a.enrollment_id=e.id and a.session_id=s.id where e.id=p_id
$$;
revoke all on function public.spae_attendance(uuid) from public,anon,authenticated;

create or replace function public.spae_data(p_scope text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb; r public.app_role; uid uuid:=auth.uid(); begin
 r:=public.current_app_role();
 if uid is null or r is null then raise exception 'Sesión no válida o cuenta desactivada'; end if;
 if p_scope='profile' then
  select to_jsonb(p) into result from profiles p where id=uid; return result;
 elsif p_scope='settings' then
  if not public.is_administrator() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(s) order by key),'[]') into result from system_settings s;
 elsif p_scope='assistants' then
  if not public.is_administrator() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(p) order by created_at desc),'[]') into result from profiles p where role='assistant';
 elsif p_scope='trainings' then
  if not public.is_staff() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.start_date desc),'[]') into result from
  (select t.*, (select count(*) from enrollments e where e.training_id=t.id and e.status in('pending','approved')) as registered,
    (select coalesce(jsonb_agg(to_jsonb(s) order by s.starts_at),'[]') from training_sessions s where s.training_id=t.id) as sessions
    from trainings t) x;
 elsif p_scope in ('enrollments','certificates','payments','attendance') then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') into result from (
   select e.*,p.full_name,p.dni,p.email,p.phone,p.hospital,p.region,p.nurse_auditor_registry,t.title as training,t.total_hours,
   public.spae_attendance(e.id) as attendance_percent,
   tp.amount,tp.operation_number,tp.receipt_path,tp.status as payment_status,
   c.certificate_number,c.snapshot,c.issued_at,c.verification_code,
   case when c.id is not null then round((extract(epoch from(c.issued_at-c.requirement_met_at))/3600)::numeric,2) end as tec_hours,
   (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'starts_at',s.starts_at,'status',a.status) order by s.starts_at),'[]')
     from training_sessions s left join attendance a on a.session_id=s.id and a.enrollment_id=e.id where s.training_id=e.training_id) as sessions
   from enrollments e join participants p on p.id=e.participant_id join trainings t on t.id=e.training_id
   left join training_payments tp on tp.enrollment_id=e.id left join certificates c on c.enrollment_id=e.id
   where public.is_staff() or p.profile_id=uid
  ) x;
 elsif p_scope='participants' then
  if not public.is_staff() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(p) order by full_name),'[]') into result from participants p;
 elsif p_scope in ('memberships','membership_payments','members') then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') into result from (
   select m.*,p.full_name,p.email,p.dni,
   case when m.ends_on<current_date then 'expired' else coalesce(m.status::text,'pending') end as effective_status,
   (select coalesce(jsonb_agg(to_jsonb(mp) order by mp.created_at desc),'[]') from membership_payments mp where mp.membership_id=m.id) as payments
   from profiles p left join lateral (select * from memberships where profile_id=p.id order by created_at desc limit 1) m on true where p.role='member' and (public.is_staff() or p.id=uid)
  ) x;
 elsif p_scope='audit' then
  if not public.is_administrator() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]') into result from (select * from audit_logs order by created_at desc limit 200) x;
 elsif p_scope='indicators' then
  if not public.is_administrator() then raise exception 'Acceso denegado'; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]') into result from (
   select t.id,t.title,t.start_date,count(e.id) as enrolled,
    count(e.id) filter(where e.status='approved') as approved,
    round(avg(public.spae_attendance(e.id)) filter(where e.status='approved'),1) as naa,
    round(avg((extract(epoch from(c.issued_at-c.requirement_met_at))/3600)::numeric),2) as tec_hours,
    round(avg(e.completion_rate),1) as trc,count(c.id) as certificates
   from trainings t left join enrollments e on e.training_id=t.id left join certificates c on c.enrollment_id=e.id group by t.id
  ) x;
 else raise exception 'Consulta no admitida'; end if;
 return result;
end $$;
revoke all on function public.spae_data(text) from public,anon;
grant execute on function public.spae_data(text) to authenticated;

-- Vincular un historial requiere correo verificado del mismo titular y DNI coincidente.
create or replace function public.spae_link_member() returns void
language plpgsql security definer set search_path=public as $$
declare p profiles; begin
 select * into p from profiles where id=auth.uid() and enabled;
 if p.id is null then raise exception 'Sesión no válida'; end if;
 if exists(select 1 from auth.users where id=p.id and email_confirmed_at is not null) then
  update participants set profile_id=p.id where lower(email)=lower(p.email) and dni=p.dni and (profile_id is null or profile_id=p.id);
 end if;
end $$;
revoke all on function public.spae_link_member() from public,anon;
grant execute on function public.spae_link_member() to authenticated;

create or replace function public.spae_public_enroll(p jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare t trainings; who participants; eid uuid; cnt integer; begin
 -- Solo Edge Function con service_role.
 select * into t from trainings where id=(p->>'training_id')::uuid for update;
 if t.id is null or t.status<>'active' or (t.end_date is not null and t.end_date<now()) then raise exception 'Capacitación no disponible'; end if;
 if trim(coalesce(p->>'full_name','')) !~ '^\S+\s+\S+' or coalesce(p->>'dni','') !~ '^[0-9]{8}$'
 or coalesce(p->>'phone','') !~ '^9[0-9]{8}$' or coalesce(p->>'email','') !~ '^[^ @]+@[^ @]+\.[^ @]+$'
 or length(trim(coalesce(p->>'hospital','')))<2 or length(trim(coalesce(p->>'region','')))<2
 or not (p ? 'nurse_auditor_registry') or not (p ? 'wants_certificate') then raise exception 'Completa correctamente los siete campos requeridos y el correo'; end if;
 select count(*) into cnt from enrollments where training_id=t.id and status in('pending','approved');
 if cnt>=t.max_capacity then raise exception 'Cupos agotados'; end if;
 select * into who from participants where dni=p->>'dni' for update;
 if who.id is not null then
   -- Impide sobrescribir identidad por conocer solo DNI/correo.
   if lower(who.email)<>lower(trim(p->>'email')) or who.lookup_hash is null or who.lookup_hash<>encode(digest(coalesce(p->>'previous_code',''),'sha256'),'hex') then
     raise exception 'El DNI ya tiene historial. Usa el correo y código privado de tu primera inscripción';
   end if;
 else
  insert into participants(full_name,dni,email,phone,hospital,region,nurse_auditor_registry,lookup_hash)
  values(trim(p->>'full_name'),p->>'dni',lower(trim(p->>'email')),p->>'phone',trim(p->>'hospital'),trim(p->>'region'),(p->>'nurse_auditor_registry')::boolean,p->>'lookup_hash') returning * into who;
 end if;
 insert into enrollments(training_id,participant_id,wants_certificate,completion_rate)
 values(t.id,who.id,(p->>'wants_certificate')::boolean,100) returning id into eid;
 if length(trim(coalesce(p->>'operation_number','')))=0 or length(coalesce(p->>'receipt_path',''))=0 then raise exception 'Adjunta el comprobante y número de operación'; end if;
 insert into training_payments(enrollment_id,amount,payment_method,operation_number,receipt_path)
 values(eid,t.price,p->>'payment_method',trim(p->>'operation_number'),p->>'receipt_path');
 return jsonb_build_object('id',eid,'code',(select code from enrollments where id=eid),'status','pending');
end $$;
revoke all on function public.spae_public_enroll(jsonb) from public,anon,authenticated;
grant execute on function public.spae_public_enroll(jsonb) to service_role;

create or replace function public.spae_public_history(p_term text,p_code text) returns jsonb
language sql stable security definer set search_path=public,extensions as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'code',e.code,'training',t.title,'created_at',e.created_at,'status',e.status,
 'rejection_reason',e.rejection_reason,'payment_status',pay.status,'attendance_percent',public.spae_attendance(e.id),
 'certificate_number',c.certificate_number,'snapshot',c.snapshot,'issued_at',c.issued_at,'verification_code',c.verification_code) order by e.created_at desc),'[]')
 from participants p join enrollments e on e.participant_id=p.id join trainings t on t.id=e.training_id
 left join training_payments pay on pay.enrollment_id=e.id left join certificates c on c.enrollment_id=e.id
 where (p.dni=trim(p_term) or lower(p.email)=lower(trim(p_term))) and p.lookup_hash=encode(digest(p_code,'sha256'),'hex')
$$;
revoke all on function public.spae_public_history(text,text) from public,anon,authenticated;
grant execute on function public.spae_public_history(text,text) to service_role;

-- Acciones de negocio autenticadas. Todas se registran en auditoría dentro de la transacción.
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
   update enrollments set requirement_met_at=case when percent>=minimum then coalesce(requirement_met_at,now()) else null end where id=e.id;
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
  if length(coalesce(p->>'code',''))<24 then raise exception 'Código insuficiente'; end if;
  update participants set lookup_hash=encode(digest(p->>'code','sha256'),'hex') where id=(p->>'id')::uuid;
  if not found then raise exception 'Participante inexistente'; end if;
 else raise exception 'Acción no admitida'; end if;
 insert into audit_logs(actor_id,action,entity,entity_id,details) values(uid,p_action,'spae',coalesce(p->>'id',result->>'id'),p - 'code' - 'password');
 return result;
end $$;
revoke all on function public.spae_action(text,jsonb) from public,anon;
grant execute on function public.spae_action(text,jsonb) to authenticated;

create or replace function public.spae_public_settings() returns jsonb
language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_object_agg(key,value),'{}') from system_settings where key in('annual_membership_amount','receipt_max_mb','contact_email','contact_phone','contact_address','minimum_attendance_percent')
$$;
revoke all on function public.spae_public_settings() from public;
grant execute on function public.spae_public_settings() to anon,authenticated;

-- Reemplazo de las políticas Storage previas; el servidor revisa titularidad antes de firmar enlaces.
do $$ declare r record; begin
 for r in select policyname from pg_policies where schemaname='storage' and tablename='objects' and policyname in
 ('authenticated uploads own receipts','staff reads receipts','owners read own receipts','staff manages certificates files','spae_receipt_upload','spae_receipt_read','spae_receipt_delete') loop
 execute format('drop policy %I on storage.objects',r.policyname); end loop;
end $$;
create policy spae_receipt_upload on storage.objects for insert to authenticated with check(bucket_id='payment-receipts' and (storage.foldername(name))[1]=auth.uid()::text and public.current_app_role() is not null);
create policy spae_receipt_read on storage.objects for select to authenticated using(bucket_id='payment-receipts' and public.current_app_role() is not null and ((storage.foldername(name))[1]=auth.uid()::text or public.is_staff()));
create policy spae_receipt_delete on storage.objects for delete to authenticated using(bucket_id='payment-receipts' and (storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.membership_payments where receipt_path=name));
-- La limpieza de archivos huérfanos se hace por el servidor, no por cliente.
drop policy spae_receipt_delete on storage.objects;
insert into public.system_settings(key,value,description) values
 ('contact_email','""','Correo institucional'),('contact_phone','""','Teléfono'),('contact_address','""','Dirección') on conflict(key) do nothing;


-- Reemplazo de comprobante rechazado, autorizado mediante código privado en la Edge Function.
create or replace function public.spae_resubmit(p jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare e enrollments; t trainings; begin
 select training_id into t.id from enrollments where id=(p->>'id')::uuid;
 select * into t from trainings where id=t.id for update;
 select * into e from enrollments where id=(p->>'id')::uuid for update;
 if e.id is null or e.status<>'rejected' then raise exception 'Solo se corrigen inscripciones rechazadas'; end if;
 if t.status<>'active' or (select count(*) from enrollments where training_id=t.id and status in('pending','approved'))>=t.max_capacity then raise exception 'Capacitación cerrada o sin cupos'; end if;
 if length(trim(coalesce(p->>'operation_number','')))<1 then raise exception 'Número de operación obligatorio'; end if;
 update training_payments set receipt_path=p->>'receipt_path',operation_number=p->>'operation_number',status='pending',rejection_reason=null,reviewed_at=null,reviewed_by=null where enrollment_id=e.id;
 update enrollments set status='pending',rejection_reason=null,reviewed_at=null,reviewed_by=null where id=e.id;
 return jsonb_build_object('id',e.id,'status','pending');
end $$;
revoke all on function public.spae_resubmit(jsonb) from public,anon,authenticated;
grant execute on function public.spae_resubmit(jsonb) to service_role;

create or replace function public.spae_catalogue() returns jsonb
language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(to_jsonb(x) order by x.start_date),'[]') from (
 select t.*,greatest(0,t.max_capacity-(select count(*) from enrollments e where e.training_id=t.id and e.status in('pending','approved'))) as available_capacity
 from trainings t where t.status='active' and (t.end_date is null or t.end_date>=now())
 ) x
$$;
revoke all on function public.spae_catalogue() from public;
grant execute on function public.spae_catalogue() to anon,authenticated;

notify pgrst,'reload schema';
commit;
