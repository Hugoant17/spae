-- Solo base de pruebas, después de TODAS las migraciones. Revierte los datos.
begin;
insert into auth.users(id,email,raw_user_meta_data)
values ('d1111111-1111-4111-8111-111111111111','buttons-test@example.com','{"full_name":"Prueba Botones"}');
update public.profiles set role='assistant' where id='d1111111-1111-4111-8111-111111111111';
select set_config('request.jwt.claim.sub','d1111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.trainings(id,title,slug,modality,start_date,max_capacity)
values ('d2222222-2222-4222-8222-222222222222','Prueba botones','test-buttons-2709','virtual',now(),10);
insert into public.participants(id,full_name,dni,email,phone,nurse_auditor_registry,hospital,region)
values ('d3333333-3333-4333-8333-333333333333','Prueba Participante','98989898','participant@example.com','998989898',false,'Hospital Prueba','Lima');
insert into public.enrollments(id,training_id,participant_id)
values ('d4444444-4444-4444-8444-444444444444','d2222222-2222-4222-8222-222222222222','d3333333-3333-4333-8333-333333333333');
insert into public.training_payments(enrollment_id,amount,operation_number,receipt_path)
values ('d4444444-4444-4444-8444-444444444444',50,'TEST-BUTTONS','public/test-buttons.pdf');
-- Cuenta desactivada: ni aprobar ni eliminar, incluso con sesión existente.
update public.profiles set enabled=false where id=auth.uid();
set local role authenticated;
do $$ begin
 begin
  perform public.spae_review_enrollment_v2('d4444444-4444-4444-8444-444444444444','approved');
  raise exception 'Fallo: aprobó cuenta desactivada';
 exception when others then if sqlerrm<>'Solo personal autorizado' then raise; end if; end;
 begin
  perform public.spae_delete_participant('d3333333-3333-4333-8333-333333333333');
  raise exception 'Fallo: eliminó cuenta desactivada';
 exception when others then if sqlerrm<>'Solo personal autorizado' then raise; end if; end;
end $$;
reset role;
update public.profiles set enabled=true where id=auth.uid();
set local role authenticated;
select public.spae_review_enrollment_v2('d4444444-4444-4444-8444-444444444444','approved');
select public.spae_review_enrollment_v2('d4444444-4444-4444-8444-444444444444','approved');
reset role;
do $$ begin
 if (select status from public.enrollments where id='d4444444-4444-4444-8444-444444444444')<>'approved'
 or (select status from public.training_payments where enrollment_id='d4444444-4444-4444-8444-444444444444')<>'approved'
 then raise exception 'No aprobó inscripción y pago'; end if;
 if (select count(*) from public.audit_logs where entity_id='d4444444-4444-4444-8444-444444444444' and action='review_enrollment')<>1
 then raise exception 'Reintento duplicó auditoría'; end if;
end $$;
insert into public.certificates(enrollment_id,certificate_number,pdf_path,requirement_met_at,issued_by)
values ('d4444444-4444-4444-8444-444444444444','TEST-BUTTONS','test.pdf',now(),auth.uid());
set local role authenticated;
do $$ begin
 begin
  perform public.spae_delete_participant('d3333333-3333-4333-8333-333333333333');
  raise exception 'Fallo: eliminó certificado';
 exception when others then if sqlerrm<>'No se puede eliminar: el participante tiene certificados emitidos. Se conserva su historial.' then raise; end if; end;
end $$;
reset role;
do $$ begin
 if not exists(select 1 from public.training_payments where enrollment_id='d4444444-4444-4444-8444-444444444444') then
 raise exception 'El bloqueo dejó cambios parciales'; end if;
end $$;
delete from public.certificates where enrollment_id='d4444444-4444-4444-8444-444444444444';
set local role authenticated;
select public.spae_delete_participant('d3333333-3333-4333-8333-333333333333');
reset role;
do $$ begin
 if exists(select 1 from public.participants where id='d3333333-3333-4333-8333-333333333333')
 or exists(select 1 from public.enrollments where id='d4444444-4444-4444-8444-444444444444')
 or exists(select 1 from public.training_payments where enrollment_id='d4444444-4444-4444-8444-444444444444')
 then raise exception 'Eliminación incompleta'; end if;
 if not exists(select 1 from public.audit_logs where entity_id='d3333333-3333-4333-8333-333333333333' and action='participant_delete')
 then raise exception 'Falta auditoría'; end if;
end $$;
rollback;
