-- Pruebas transaccionales. Ejecutar en base de pruebas, después de schema + migración.
-- Todo el contenido creado se revierte al terminar.
begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
('a1111111-1111-4111-8111-111111111111','spae-ci-admin@example.com',now(),'{"full_name":"Prueba Admin"}'),
('a2222222-2222-4222-8222-222222222222','spae-ci-assistant@example.com',now(),'{"full_name":"Prueba Asistente"}'),
('a3333333-3333-4333-8333-333333333333','spae-ci-member@example.com',now(),'{"full_name":"Prueba Miembro","dni":"99000001","phone":"999000001"}'),
('a4444444-4444-4444-8444-444444444444','spae-ci-other@example.com',now(),'{"full_name":"Prueba Otro"}');
update public.profiles set role='administrator' where id='a1111111-1111-4111-8111-111111111111';
update public.profiles set role='assistant' where id='a2222222-2222-4222-8222-222222222222';
set local role authenticated;
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.spae_action('save_settings','{"items":[{"key":"annual_membership_amount","value":250},{"key":"minimum_attendance_percent","value":80}]}');
select public.spae_action('save_training','{
 "id":"b1111111-1111-4111-8111-111111111111","title":"Prueba auditoría","description":"Prueba","modality":"virtual",
 "start_date":"2025-01-01T10:00:00Z","total_hours":4,"max_capacity":1,"price":100,"status":"active",
 "sessions":[{"id":"b2222222-2222-4222-8222-222222222222","title":"Sesión 1","starts_at":"2025-01-01T10:00:00Z"}]}');
do $$begin if jsonb_array_length(public.spae_data('trainings'))<1 then raise exception 'No listó capacitación creada';end if;end$$;
do $$begin if jsonb_array_length(public.spae_member_requests())<>2 then raise exception 'Solicitudes no disponibles'; end if;end$$;
-- Miembro no puede gestionar capacitación ni consultar indicadores globales.
select set_config('request.jwt.claim.sub','a3333333-3333-4333-8333-333333333333',true);
do $$begin
 begin perform public.spae_action('delete_training','{"id":"b1111111-1111-4111-8111-111111111111"}');raise exception 'Fallo: miembro pudo eliminar';exception when others then if sqlerrm<>'Solo administrador' then raise;end if;end;
 begin perform public.spae_individual_indicators();raise exception 'Fallo: indicador individual expuesto';exception when others then if sqlerrm<>'Solo administrador' then raise;end if;end;
 begin perform public.spae_data('indicators');raise exception 'Fallo: indicadores públicos';exception when others then if sqlerrm<>'Acceso denegado' then raise;end if;end;
end$$;
reset role;
-- Simula inscripción que ya pasó validación de archivo en Edge.
select set_config('spae.test.enrollment',(public.spae_public_enroll(jsonb_build_object(
 'training_id','b1111111-1111-4111-8111-111111111111','full_name','Prueba Miembro','dni','99000001','phone','999000001',
 'email','spae-ci-member@example.com','hospital','Hospital Prueba','region','Lima','nurse_auditor_registry',false,'wants_certificate',true,
 'lookup_hash',encode(digest('PRIVATE_TEST_CODE_1234567890123456','sha256'),'hex'),'receipt_path','public/test.pdf','operation_number','TEST-001')))->>'id',true);
do $$begin
 if jsonb_array_length(public.spae_public_history('99000001','WRONG'))<>0 then raise exception 'Código incorrecto reveló datos';end if;
 if jsonb_array_length(public.spae_public_history('99000001','PRIVATE_TEST_CODE_1234567890123456'))<>1 then raise exception 'Consulta privada falló';end if;
 if (select amount from public.training_payments where enrollment_id=current_setting('spae.test.enrollment')::uuid)<>150 then raise exception 'No se aplicó el adicional del certificado';end if;
end$$;
set local role anon;
do $$begin
 begin perform public.spae_public_history('99000001','PRIVATE_TEST_CODE_1234567890123456');raise exception 'Fallo: RPC privada anónima';exception when insufficient_privilege then null;end;
 begin perform public.spae_action('save_profile','{}');raise exception 'Fallo: acción anónima';exception when insufficient_privilege then null;end;
end$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
select public.spae_review_member('a3333333-3333-4333-8333-333333333333','approved');
select public.spae_action('review_enrollment',jsonb_build_object('id',current_setting('spae.test.enrollment'),'status','approved'));
do $$begin
 begin perform public.spae_action('issue_certificate',jsonb_build_object('id',current_setting('spae.test.enrollment')));raise exception 'Fallo: certificado sin asistencia';exception when others then if sqlerrm<>'El participante no cumple los requisitos de certificación' then raise;end if;end;
end$$;
select public.spae_action('save_attendance',jsonb_build_object('rows',jsonb_build_array(jsonb_build_object('enrollment_id',current_setting('spae.test.enrollment'),'session_id','b2222222-2222-4222-8222-222222222222','status','present'))));
select public.spae_action('issue_certificate',jsonb_build_object('id',current_setting('spae.test.enrollment')));
select public.spae_action('issue_certificate',jsonb_build_object('id',current_setting('spae.test.enrollment')));
-- Mismo certificado al reintentar, sin duplicados.
reset role;
do $$begin if (select count(*) from public.certificates where enrollment_id=current_setting('spae.test.enrollment')::uuid)<>1 then raise exception 'Emisión duplicada';end if;end$$;
insert into storage.objects(id,bucket_id,name) values('b3333333-3333-4333-8333-333333333333','payment-receipts','a3333333-3333-4333-8333-333333333333/test.pdf');
set local role authenticated;
select set_config('request.jwt.claim.sub','a3333333-3333-4333-8333-333333333333',true);
select public.spae_link_member();
do $$begin if jsonb_array_length(public.spae_data('certificates'))<>1 then raise exception 'Miembro no recuperó historial propio';end if;end$$;
select set_config('spae.test.payment',(public.spae_action('submit_membership','{"receipt_path":"a3333333-3333-4333-8333-333333333333/test.pdf","operation_number":"ANUAL-001"}')->>'id'),true);
select set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
select public.spae_action('review_membership',jsonb_build_object('id',current_setting('spae.test.payment'),'status','approved'));
-- Con membresía activa, sin certificado no se exige comprobante. Se admiten varias sesiones programadas.
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
select public.spae_action('save_training','{"id":"b4444444-4444-4444-8444-444444444444","title":"Curso de dos sesiones","description":"Prueba","modality":"virtual","start_date":"2030-01-01T10:00:00Z","total_hours":4,"max_capacity":10,"price":100,"status":"active","sessions":[{"id":"b5555555-5555-4555-8555-555555555555","title":"Bloque uno","starts_at":"2030-01-01T10:00:00Z"},{"id":"b6666666-6666-4666-8666-666666666666","title":"Bloque dos","starts_at":"2030-01-02T10:00:00Z"}]}');
reset role;
select set_config('spae.test.free',(public.spae_public_enroll(jsonb_build_object('training_id','b4444444-4444-4444-8444-444444444444','full_name','Prueba Miembro','dni','99000001','phone','999000001','email','spae-ci-member@example.com','hospital','Hospital Prueba','region','Lima','nurse_auditor_registry',false,'wants_certificate',false,'_member_id','a3333333-3333-4333-8333-333333333333','lookup_hash',encode(digest('OTHER_TEST_CODE','sha256'),'hex')))->>'id'),true);
do $$begin if exists(select 1 from public.training_payments where enrollment_id=current_setting('spae.test.free')::uuid) then raise exception 'El miembro sin certificado recibió cobro';end if;end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
select public.spae_action('review_enrollment',jsonb_build_object('id',current_setting('spae.test.free'),'status','approved'));
select public.spae_action('save_attendance',jsonb_build_object('rows',jsonb_build_array(jsonb_build_object('enrollment_id',current_setting('spae.test.free'),'session_id','b5555555-5555-4555-8555-555555555555','status','present'),jsonb_build_object('enrollment_id',current_setting('spae.test.free'),'session_id','b6666666-6666-4666-8666-666666666666','status','present'))));
select set_config('request.jwt.claim.sub','a4444444-4444-4444-8444-444444444444',true);
do $$begin if jsonb_array_length(public.spae_data('enrollments'))<>0 then raise exception 'Otro miembro pudo ver historial ajeno';end if;end$$;
reset role;
do $$begin
 if not exists(select 1 from public.memberships where profile_id='a3333333-3333-4333-8333-333333333333' and ends_on=(starts_on+interval '12 months')::date-1 and status='active') then raise exception 'Renovación incorrecta';end if;
end$$;
-- Los permisos efectivos se retiran inmediatamente al desactivar una asistente.
update public.profiles set enabled=false where id='a2222222-2222-4222-8222-222222222222';
set local role authenticated;
select set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
do $$begin
 begin perform public.spae_data('enrollments');raise exception 'Fallo: cuenta desactivada accede';exception when others then if sqlerrm<>'Sesión no válida o cuenta desactivada' then raise;end if;end;
end$$;
reset role;
rollback;
