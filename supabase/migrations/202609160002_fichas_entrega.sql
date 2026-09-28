-- Aplicar después de las migraciones 202609090001 y 202609160001.
begin;
alter table public.certificates add column if not exists delivered_at timestamptz;
create or replace function public.spae_mark_certificate_sent(p_enrollment uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare c certificates;
begin
 if not public.is_staff() then raise exception 'Solo administrador o asistente'; end if;
 select * into c from certificates where enrollment_id=p_enrollment for update;
 if c.id is null or c.pdf_path='generated' then raise exception 'Primero genera el PDF del certificado'; end if;
 if c.delivered_at is not null then return jsonb_build_object('delivered_at',c.delivered_at); end if;
 update certificates set delivered_at=clock_timestamp() where id=c.id returning * into c;
 insert into audit_logs(actor_id,action,entity,entity_id,details) values(auth.uid(),'certificate_delivered','certificates',c.id::text,jsonb_build_object('delivered_at',c.delivered_at));
 return jsonb_build_object('delivered_at',c.delivered_at);
end $$;
revoke all on function public.spae_mark_certificate_sent(uuid) from public,anon;
grant execute on function public.spae_mark_certificate_sent(uuid) to authenticated;
create or replace function public.spae_individual_indicators() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.is_administrator() then raise exception 'Solo administrador'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.training,x.created_at,x.id),'[]') into result from (
 select e.id,e.training_id,e.created_at,t.title as training,t.start_date,e.code as participant_code,p.full_name,p.dni,
 e.status,e.wants_certificate,e.registration_snapshot,e.registration_checks,
 coalesce(c.requirement_met_at,e.requirement_met_at) as requirement_met_at,c.delivered_at as issued_at,c.certificate_number,
 public.spae_attendance(e.id) as naa,
 case when c.id is not null then round((extract(epoch from(c.delivered_at-c.requirement_met_at))/3600)::numeric) end as tec_hours,
 (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'starts_at',s.starts_at,'status',a.status) order by s.starts_at,s.id),'[]') from training_sessions s left join attendance a on a.session_id=s.id and a.enrollment_id=e.id where s.training_id=e.training_id) as sessions
 from enrollments e join participants p on p.id=e.participant_id join trainings t on t.id=e.training_id left join certificates c on c.enrollment_id=e.id
 ) x; return result;
end $$;
revoke all on function public.spae_individual_indicators() from public,anon;
grant execute on function public.spae_individual_indicators() to authenticated;

notify pgrst,'reload schema';
commit;
