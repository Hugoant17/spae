-- Aplicar después de todas las migraciones anteriores.
begin;
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
  if uid is null or not coalesce(public.is_staff(),false) then
    raise exception 'Solo personal autorizado';
  end if;
  if p_status is null or p_status not in ('approved','rejected') then raise exception 'Estado no válido'; end if;
  if p_status='rejected' and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Indica el motivo'; end if;

  select * into e from public.enrollments where id=p_id for update;
  if e.id is not null and e.status::text=p_status then
    return jsonb_build_object('ok',true,'id',p_id,'status',p_status);
  end if;
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

-- Eliminar un participante y sus dependencias en una sola transacción.
-- Los comprobantes de Storage se conservan; no se borran archivos desde SQL.
create or replace function public.spae_delete_participant(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  target public.participants;
  enrollment_ids uuid[];
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Solo personal autorizado';
  end if;
  select * into target from public.participants where id=p_id for update;
  if target.id is null then raise exception 'Participante inexistente o ya eliminado'; end if;
  -- Bloquea las inscripciones antes de comprobar certificados (también su emisión).
  perform id from public.enrollments where participant_id=p_id order by id for update;
  select array_agg(id) into enrollment_ids from public.enrollments where participant_id=p_id;
  if exists(select 1 from public.certificates where enrollment_id=any(enrollment_ids)) then
    raise exception 'No se puede eliminar: el participante tiene certificados emitidos. Se conserva su historial.';
  end if;
  insert into public.audit_logs(actor_id,action,entity,entity_id,details)
  values(auth.uid(),'participant_delete','participants',p_id::text,
    jsonb_build_object('full_name',target.full_name,'enrollment_ids',enrollment_ids));
  delete from public.enrollments where participant_id=p_id;
  delete from public.participants where id=p_id;
  return jsonb_build_object('ok',true,'id',p_id);
end $$;
revoke all on function public.spae_delete_participant(uuid) from public,anon,authenticated;
grant execute on function public.spae_delete_participant(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
