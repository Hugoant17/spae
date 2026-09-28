-- Levantamiento final de observaciones SPAE 26/09/2026.
-- Aplicar después de 202609230001_correcciones.sql.
begin;

-- Una capacitación cancelada con historial no se destruye: se archiva para
-- retirarla de la gestión cotidiana sin perder inscripciones/certificados.
alter table public.trainings add column if not exists archived_at timestamptz;
create index if not exists trainings_archived_at_idx on public.trainings(archived_at);

create or replace function public.spae_delete_training(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  t public.trainings;
  action_name text;
begin
  if auth.uid() is null or public.current_app_role()<>'administrator' then
    raise exception 'Solo administrador';
  end if;
  select * into t from public.trainings where id=p_id for update;
  if t.id is null then raise exception 'Capacitación inexistente'; end if;

  if exists(select 1 from public.enrollments where training_id=p_id) then
    if t.status<>'cancelled' then
      raise exception 'Primero cancela la capacitación. Con inscripciones registradas se archivará para conservar el historial';
    end if;
    update public.trainings set archived_at=clock_timestamp(),updated_at=clock_timestamp() where id=p_id;
    action_name:='archive_training';
  else
    delete from public.trainings where id=p_id;
    action_name:='delete_training';
  end if;

  insert into public.audit_logs(actor_id,action,entity,entity_id,details)
  values(auth.uid(),action_name,'trainings',p_id::text,jsonb_build_object('title',t.title,'status',t.status));
  return jsonb_build_object('ok',true,'archived',action_name='archive_training');
end $$;
revoke all on function public.spae_delete_training(uuid) from public,anon,authenticated;
grant execute on function public.spae_delete_training(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
