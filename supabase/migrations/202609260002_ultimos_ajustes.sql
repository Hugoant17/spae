-- Últimos ajustes SPAE 26/09/2026 (documento "ULTIMOS AJUSTES Y ERRORES SISTEMA SPAE 2609").
-- Aplicar después de 202609260001_observaciones_finales.sql.
begin;

-- Conservar la auditoría aunque se elimine una cuenta de miembro sin historial académico.
alter table public.audit_logs drop constraint if exists audit_logs_actor_id_fkey;
alter table public.audit_logs
  add constraint audit_logs_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

-- Lista de cuentas de miembro para gestión por asistente/administrador.
-- Se separa el id de la cuenta (member_id) del id de la membresía (id).
create or replace function public.spae_member_accounts() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
  if auth.uid() is null or public.current_app_role() not in ('assistant','administrator') then
    raise exception 'Solo personal autorizado';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
  into result
  from (
    select
      m.id,
      p.id as member_id,
      p.full_name,
      p.email,
      p.dni,
      p.phone,
      p.enabled,
      p.registration_status,
      p.registration_reason,
      p.created_at,
      m.starts_on,
      m.ends_on,
      m.status,
      case
        when p.enabled is false then 'inactive'
        when m.ends_on < current_date then 'expired'
        else coalesce(m.status::text,'pending')
      end as effective_status,
      (select coalesce(jsonb_agg(to_jsonb(mp) order by mp.created_at desc),'[]'::jsonb)
       from public.membership_payments mp where mp.membership_id=m.id) as payments
    from public.profiles p
    left join lateral (
      select * from public.memberships mm
      where mm.profile_id=p.id
      order by mm.created_at desc
      limit 1
    ) m on true
    where p.role='member'
  ) x;

  return result;
end $$;
revoke all on function public.spae_member_accounts() from public,anon,authenticated;
grant execute on function public.spae_member_accounts() to authenticated;

-- Revisión dedicada de inscripciones. Evita depender del despachador genérico
-- spae_action para Aprobar/Rechazar y elimina el error "Acción no admitida".
create or replace function public.spae_review_enrollment_v2(
  p_id uuid,
  p_status text,
  p_reason text default null
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  uid uuid:=auth.uid();
  e public.enrollments;
begin
  if uid is null or public.current_app_role() not in ('assistant','administrator') then
    raise exception 'Solo personal autorizado';
  end if;
  if p_status not in ('approved','rejected') then raise exception 'Estado no válido'; end if;
  if p_status='rejected' and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Indica el motivo'; end if;

  select * into e from public.enrollments where id=p_id for update;
  if e.id is null or e.status<>'pending' then
    raise exception 'Inscripción inexistente o ya revisada';
  end if;

  update public.enrollments
  set status=p_status::public.record_status,
      rejection_reason=case when p_status='rejected' then trim(p_reason) else null end,
      reviewed_by=uid,
      reviewed_at=clock_timestamp()
  where id=p_id;

  update public.training_payments
  set status=p_status::public.record_status,
      rejection_reason=case when p_status='rejected' then trim(p_reason) else null end,
      reviewed_by=uid,
      reviewed_at=clock_timestamp()
  where enrollment_id=p_id;

  insert into public.audit_logs(actor_id,action,entity,entity_id,details)
  values(uid,'review_enrollment','enrollments',p_id::text,jsonb_build_object('status',p_status,'reason',p_reason));

  return jsonb_build_object('ok',true,'id',p_id,'status',p_status);
end $$;
revoke all on function public.spae_review_enrollment_v2(uuid,text,text) from public,anon,authenticated;
grant execute on function public.spae_review_enrollment_v2(uuid,text,text) to authenticated;

-- Emisión dedicada del certificado. La fecha se guarda como día civil de Perú,
-- evitando que un timestamptz cambie 23/09 a 24/09 al generar el PDF.
create or replace function public.spae_issue_certificate_v2(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  uid uuid:=auth.uid();
  e public.enrollments;
  c public.certificates;
  t public.trainings;
  minimum numeric;
  local_start text;
begin
  if uid is null or public.current_app_role() not in ('assistant','administrator') then
    raise exception 'Solo personal autorizado';
  end if;

  select * into e from public.enrollments where id=p_id for update;
  if e.id is null then raise exception 'Inscripción inexistente'; end if;

  select * into c from public.certificates where enrollment_id=e.id;
  if c.id is not null then return to_jsonb(c); end if;

  minimum:=coalesce((select (value::text)::numeric from public.system_settings where key='minimum_attendance_percent'),80);
  if e.status<>'approved' or not e.wants_certificate or public.spae_attendance(e.id)<minimum then
    raise exception 'El participante no cumple los requisitos de certificación';
  end if;
  if not exists(select 1 from public.training_payments where enrollment_id=e.id and status='approved') then
    raise exception 'Pago no aprobado';
  end if;

  select * into t from public.trainings where id=e.training_id;
  local_start:=to_char(t.start_date at time zone 'America/Lima','YYYY-MM-DD');

  insert into public.certificates(
    enrollment_id,certificate_number,pdf_path,requirement_met_at,issued_by,snapshot
  ) values (
    e.id,
    'SPAE-'||to_char(clock_timestamp(),'YYYY')||'-'||upper(substr(encode(gen_random_bytes(8),'hex'),1,12)),
    'generated',
    coalesce(e.requirement_met_at,clock_timestamp()),
    uid,
    jsonb_build_object(
      'full_name',(select full_name from public.participants where id=e.participant_id),
      'training',t.title,
      'hours',t.total_hours,
      'training_date',local_start,
      'institution','Sociedad Peruana de Auditoría en Enfermería'
    )
  ) returning * into c;

  insert into public.audit_logs(actor_id,action,entity,entity_id,details)
  values(uid,'issue_certificate','certificates',c.id::text,jsonb_build_object('enrollment_id',e.id,'training_date',local_start));

  return to_jsonb(c);
end $$;
revoke all on function public.spae_issue_certificate_v2(uuid) from public,anon,authenticated;
grant execute on function public.spae_issue_certificate_v2(uuid) to authenticated;

-- Normaliza también certificados ya emitidos para que al regenerarse usen
-- exactamente la fecha de inicio de la capacitación en hora de Perú.
update public.certificates c
set snapshot=jsonb_set(
  coalesce(c.snapshot,'{}'::jsonb),
  '{training_date}',
  to_jsonb(to_char(t.start_date at time zone 'America/Lima','YYYY-MM-DD')),
  true
)
from public.enrollments e
join public.trainings t on t.id=e.training_id
where e.id=c.enrollment_id;

notify pgrst,'reload schema';
commit;
