-- Datos mínimos de demostración. Ejecutar después de schema.sql.
insert into public.trainings(title, slug, description, modality, start_date, total_hours, max_capacity, price, status)
values
  ('Auditoría de la calidad del registro clínico', 'auditoria-registro-clinico', 'Actualización profesional para evaluar la integridad y trazabilidad del registro de enfermería.', 'virtual', '2026-10-15 19:00:00-05', 24, 80, 180, 'active'),
  ('Gestión de riesgos y seguridad del paciente', 'seguridad-del-paciente', 'Herramientas para identificar riesgos y mejorar la seguridad asistencial.', 'hybrid', '2026-10-28 18:00:00-05', 18, 60, 150, 'active')
on conflict (slug) do nothing;

