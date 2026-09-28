begin;
insert into auth.users(id,email,raw_user_meta_data) values
('e1111111-1111-4111-8111-111111111111','review-admin@example.com','{"full_name":"Prueba Admin"}'),
('e2222222-2222-4222-8222-222222222222','review-assistant@example.com','{"full_name":"Prueba Asistente"}'),
('e3333333-3333-4333-8333-333333333333','review-member@example.com','{"full_name":"Prueba Miembro"}');
update public.profiles set role='administrator' where id='e1111111-1111-4111-8111-111111111111';
update public.profiles set role='assistant' where id='e2222222-2222-4222-8222-222222222222';
select set_config('request.jwt.claim.sub','e2222222-2222-4222-8222-222222222222',true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select public.spae_member_state('e3333333-3333-4333-8333-333333333333',false);
select public.spae_member_state('e3333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claim.sub','e3333333-3333-4333-8333-333333333333',true);
do $$begin
 begin perform public.spae_member_state('e3333333-3333-4333-8333-333333333333',false);raise exception 'Miembro cambió estado';
 exception when others then if sqlerrm<>'Solo personal autorizado' then raise;end if;end;
end$$;
reset role;
insert into public.trainings(id,title,slug,modality,start_date,max_capacity) values
('e4444444-4444-4444-8444-444444444444','Rechazo prueba','rejection-test','virtual',now(),20);
insert into public.participants(id,profile_id,full_name,dni,email,phone,nurse_auditor_registry,hospital,region) values
('e5555555-5555-4555-8555-555555555555','e3333333-3333-4333-8333-333333333333','Prueba Miembro','97979797','review-member@example.com','997979797',false,'Hospital Prueba','Lima');
insert into public.enrollments(id,training_id,participant_id) values
('e6666666-6666-4666-8666-666666666666','e4444444-4444-4444-8444-444444444444','e5555555-5555-4555-8555-555555555555');
select set_config('request.jwt.claim.sub','e2222222-2222-4222-8222-222222222222',true);
set local role authenticated;
do $$begin
 begin perform public.spae_review_enrollment_v2('e6666666-6666-4666-8666-666666666666','rejected','');raise exception 'Aceptó motivo vacío';
 exception when others then if sqlerrm<>'Indica el motivo' then raise;end if;end;
end$$;
select public.spae_review_enrollment_v2('e6666666-6666-4666-8666-666666666666','rejected','Comprobante ilegible');
select public.spae_action('recover_code','{"id":"e5555555-5555-4555-8555-555555555555","code":"ABCDEFGHJKLMNPQR"}');
reset role;
do $$begin
 if (select status from public.enrollments where id='e6666666-6666-4666-8666-666666666666')<>'rejected' then raise exception 'No rechazó';end if;
 begin delete from auth.users where id='e3333333-3333-4333-8333-333333333333';raise exception 'Borró cuenta con historial';
 exception when others then if sqlerrm<>'Este miembro tiene historial de inscripciones. Usa Inactivar cuenta para conservar sus registros.' then raise;end if;end;
 if not exists(select 1 from public.profiles where id='e3333333-3333-4333-8333-333333333333') then raise exception 'El borrado fallido alteró el perfil';end if;
end$$;
delete from public.enrollments where id='e6666666-6666-4666-8666-666666666666';
delete from auth.users where id='e3333333-3333-4333-8333-333333333333';
do $$begin
 if exists(select 1 from public.participants where id='e5555555-5555-4555-8555-555555555555') then raise exception 'Quedó participante huérfano';end if;
end$$;
rollback;
