-- Aplicar después de 202609270001_botones_participantes.sql.
begin;
create or replace function public.spae_member_state(p_id uuid,p_enabled boolean) returns jsonb
language plpgsql security definer set search_path=public as $$
declare target public.profiles;
begin
 if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Solo personal autorizado'; end if;
 if p_enabled is null then raise exception 'Estado de cuenta obligatorio'; end if;
 select * into target from public.profiles where id=p_id and role='member' for update;
 if target.id is null then raise exception 'Miembro inexistente'; end if;
 update public.profiles set enabled=p_enabled,updated_at=clock_timestamp() where id=p_id;
 insert into public.audit_logs(actor_id,action,entity,entity_id,details)
 values(auth.uid(),'member_state','profiles',p_id::text,jsonb_build_object('enabled',p_enabled));
 return jsonb_build_object('ok',true,'enabled',p_enabled);
end $$;
revoke all on function public.spae_member_state(uuid,boolean) from public,anon,authenticated;
grant execute on function public.spae_member_state(uuid,boolean) to authenticated;

-- Eliminar cuenta de miembro desde Auth y su participante sin historial
-- se ejecuta dentro de la misma transacción, nunca en peticiones separadas.
create or replace function public.spae_before_member_delete() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if old.role='member' then
  perform id from public.participants where profile_id=old.id for update;
  if exists(select 1 from public.enrollments e join public.participants p on p.id=e.participant_id where p.profile_id=old.id) then
   raise exception 'Este miembro tiene historial de inscripciones. Usa Inactivar cuenta para conservar sus registros.';
  end if;
  delete from public.participants where profile_id=old.id;
 end if;
 return old;
end $$;
revoke all on function public.spae_before_member_delete() from public,anon,authenticated;
drop trigger if exists spae_member_delete_guard on public.profiles;
create trigger spae_member_delete_guard before delete on public.profiles
for each row execute function public.spae_before_member_delete();

-- Rechazo conserva el registro y el motivo para corregir el comprobante.
-- La operación dedicada es idempotente y también admite cuentas habilitadas.
-- La migración 270001 ya reemplaza spae_review_enrollment_v2.
create or replace function public.spae_individual_indicators() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.is_administrator() then raise exception 'Solo administrador'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.training,x.created_at,x.id),'[]') into result from (
 select e.id,e.training_id,e.created_at,t.title as training,t.start_date,e.code as participant_code,p.full_name,p.dni,
 e.status,e.wants_certificate,e.registration_snapshot,e.registration_checks,
 coalesce(c.requirement_met_at,e.requirement_met_at) as requirement_met_at,c.issued_at as issued_at,c.certificate_number,
 public.spae_attendance(e.id) as naa,
 case when c.id is not null then round(greatest(0,(extract(epoch from(c.issued_at-c.requirement_met_at))/3600))::numeric,3) end as tec_hours,
 (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'starts_at',s.starts_at,'status',a.status) order by s.starts_at,s.id),'[]') from training_sessions s left join attendance a on a.session_id=s.id and a.enrollment_id=e.id where s.training_id=e.training_id) as sessions
 from enrollments e join participants p on p.id=e.participant_id join trainings t on t.id=e.training_id left join certificates c on c.enrollment_id=e.id
 ) x; return result;
end $$;
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
   case when c.id is not null then round(greatest(0,(extract(epoch from(c.issued_at-c.requirement_met_at))/3600))::numeric,3) end as tec_hours,
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
    round(avg(greatest(0,(extract(epoch from(c.issued_at-c.requirement_met_at))/3600))::numeric),3) as tec_hours,
    round(avg(e.completion_rate),1) as trc,count(c.id) as certificates
   from trainings t left join enrollments e on e.training_id=t.id left join certificates c on c.enrollment_id=e.id group by t.id
  ) x;
 else raise exception 'Consulta no admitida'; end if;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
