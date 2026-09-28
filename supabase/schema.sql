-- SPAE Capacitaciones - Esquema inicial para Supabase PostgreSQL
-- Ejecutar una sola vez desde Supabase SQL Editor en un proyecto nuevo.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('member', 'assistant', 'administrator');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.record_status as enum ('draft', 'pending', 'approved', 'rejected', 'active', 'expired', 'cancelled', 'completed');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  dni varchar(8) unique check (dni is null or dni ~ '^[0-9]{8}$'),
  phone varchar(9) check (phone is null or phone ~ '^9[0-9]{8}$'),
  hospital text,
  region text,
  nurse_auditor_registry boolean,
  role public.app_role not null default 'member',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trainings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  description text not null default '',
  objectives text,
  syllabus text,
  speaker text,
  modality text not null check (modality in ('virtual', 'hybrid', 'in_person')),
  start_date timestamptz not null,
  end_date timestamptz,
  total_hours numeric(6,2) not null default 0 check (total_hours >= 0),
  max_capacity integer not null check (max_capacity > 0),
  price numeric(10,2) not null default 0 check (price >= 0),
  image_url text,
  status public.record_status not null default 'draft',
  archived_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.trainings(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  unique(training_id, starts_at)
);

create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  full_name text not null,
  dni varchar(8) not null unique check (dni ~ '^[0-9]{8}$'),
  email text not null,
  phone varchar(9) not null check (phone ~ '^9[0-9]{8}$'),
  nurse_auditor_registry boolean not null,
  hospital text not null,
  region text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default ('INS-' || to_char(now(), 'YYYY') || '-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8))),
  training_id uuid not null references public.trainings(id) on delete restrict,
  participant_id uuid not null references public.participants(id) on delete restrict,
  wants_certificate boolean not null default true,
  status public.record_status not null default 'pending',
  rejection_reason text,
  completion_rate numeric(5,2) not null default 100 check (completion_rate between 0 and 100),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(training_id, participant_id)
);

create table if not exists public.training_payments (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null unique references public.enrollments(id) on delete cascade,
  amount numeric(10,2) not null check (amount >= 0),
  payment_method text,
  operation_number text not null,
  receipt_path text not null,
  status public.record_status not null default 'pending',
  rejection_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.training_sessions(id) on delete cascade,
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  status text not null check (status in ('present', 'absent')),
  recorded_by uuid references public.profiles(id),
  recorded_at timestamptz not null default now(),
  unique(session_id, enrollment_id)
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  starts_on date,
  ends_on date,
  status public.record_status not null default 'pending',
  created_at timestamptz not null default now(),
  constraint membership_dates check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create table if not exists public.membership_payments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.memberships(id) on delete cascade,
  period text not null,
  amount numeric(10,2) not null check (amount >= 0),
  payment_method text,
  operation_number text not null,
  receipt_path text not null,
  status public.record_status not null default 'pending',
  rejection_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists one_approved_membership_payment_per_period
  on public.membership_payments(membership_id, period) where status = 'approved';

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null unique references public.enrollments(id) on delete restrict,
  certificate_number text not null unique,
  pdf_path text not null,
  requirement_met_at timestamptz not null,
  issued_at timestamptz not null default now(),
  issued_by uuid not null references public.profiles(id),
  verification_code text not null unique default encode(gen_random_bytes(12), 'hex'),
  created_at timestamptz not null default now()
);

create table if not exists public.system_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

insert into public.system_settings(key, value, description) values
  ('minimum_attendance_percent', '80', 'Porcentaje mínimo requerido para certificar'),
  ('team_hourly_cost', '0', 'Costo hora del equipo administrativo'),
  ('annual_membership_amount', '0', 'Monto de la cuota anual'),
  ('receipt_max_mb', '5', 'Tamaño máximo del comprobante')
on conflict (key) do nothing;

create or replace function public.current_app_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.profiles where id = auth.uid()), 'member'::public.app_role); $$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select public.current_app_role() in ('assistant', 'administrator'); $$;

create or replace function public.is_administrator()
returns boolean language sql stable security definer set search_path = public
as $$ select public.current_app_role() = 'administrator'; $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, full_name, email, dni, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    nullif(new.raw_user_meta_data->>'dni', ''),
    nullif(new.raw_user_meta_data->>'phone', ''),
    case when new.raw_user_meta_data->>'role' = 'member' then 'member'::public.app_role else 'member'::public.app_role end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace view public.enrollment_attendance_summary as
select
  e.id as enrollment_id,
  count(ts.id) as total_sessions,
  count(a.id) filter (where a.status = 'present') as attended_sessions,
  case when count(ts.id) = 0 then 0
       else round(100.0 * count(a.id) filter (where a.status = 'present') / count(ts.id), 1) end as attendance_percent
from public.enrollments e
join public.training_sessions ts on ts.training_id = e.training_id
left join public.attendance a on a.session_id = ts.id and a.enrollment_id = e.id
group by e.id;

create or replace view public.management_indicators as
select
  t.id as training_id,
  t.title,
  coalesce(round(avg(a.attendance_percent), 1), 0) as naa,
  coalesce(round(avg(extract(epoch from (c.issued_at - c.requirement_met_at)) / 3600)::numeric, 1), 0) as tec_hours,
  coalesce(round(avg(e.completion_rate), 1), 0) as trc
from public.trainings t
left join public.enrollments e on e.training_id = t.id
left join public.enrollment_attendance_summary a on a.enrollment_id = e.id
left join public.certificates c on c.enrollment_id = e.id
group by t.id, t.title;

create or replace function public.public_participant_lookup(lookup_value text)
returns jsonb language sql stable security definer set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'enrollment_code', e.code,
    'training', t.title,
    'enrollment_status', e.status,
    'registered_at', e.created_at,
    'certificate_available', c.id is not null,
    'verification_code', c.verification_code
  )), '[]'::jsonb)
  from public.participants p
  join public.enrollments e on e.participant_id = p.id
  join public.trainings t on t.id = e.training_id
  left join public.certificates c on c.enrollment_id = e.id
  where lower(p.email) = lower(trim(lookup_value)) or p.dni = trim(lookup_value);
$$;
grant execute on function public.public_participant_lookup(text) to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.trainings enable row level security;
alter table public.training_sessions enable row level security;
alter table public.participants enable row level security;
alter table public.enrollments enable row level security;
alter table public.training_payments enable row level security;
alter table public.attendance enable row level security;
alter table public.memberships enable row level security;
alter table public.membership_payments enable row level security;
alter table public.certificates enable row level security;
alter table public.system_settings enable row level security;
alter table public.audit_logs enable row level security;

create policy "published trainings are public" on public.trainings for select using (status = 'active' or public.is_staff());
create policy "administrator manages trainings" on public.trainings for all using (public.is_administrator()) with check (public.is_administrator());
create policy "published sessions are public" on public.training_sessions for select using (exists(select 1 from public.trainings t where t.id = training_id and (t.status = 'active' or public.is_staff())));
create policy "administrator manages sessions" on public.training_sessions for all using (public.is_administrator()) with check (public.is_administrator());

create policy "profile owner reads" on public.profiles for select using (id = auth.uid() or public.is_staff());
create policy "profile owner updates" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = public.current_app_role());
create policy "administrator manages profiles" on public.profiles for all using (public.is_administrator()) with check (public.is_administrator());

create policy "public creates participants" on public.participants for insert to anon, authenticated with check (true);
create policy "member reads participant" on public.participants for select using (profile_id = auth.uid() or public.is_staff());
create policy "staff manages participants" on public.participants for all using (public.is_staff()) with check (public.is_staff());

create policy "public creates enrollments" on public.enrollments for insert to anon, authenticated with check (status = 'pending');
create policy "member reads enrollments" on public.enrollments for select using (exists(select 1 from public.participants p where p.id = participant_id and p.profile_id = auth.uid()) or public.is_staff());
create policy "staff manages enrollments" on public.enrollments for all using (public.is_staff()) with check (public.is_staff());

create policy "public creates training payments" on public.training_payments for insert to anon, authenticated with check (status = 'pending');
create policy "owner reads training payments" on public.training_payments for select using (exists(select 1 from public.enrollments e join public.participants p on p.id=e.participant_id where e.id=enrollment_id and p.profile_id=auth.uid()) or public.is_staff());
create policy "staff manages training payments" on public.training_payments for all using (public.is_staff()) with check (public.is_staff());

create policy "staff manages attendance" on public.attendance for all using (public.is_staff()) with check (public.is_staff());
create policy "owner reads attendance" on public.attendance for select using (exists(select 1 from public.enrollments e join public.participants p on p.id=e.participant_id where e.id=enrollment_id and p.profile_id=auth.uid()) or public.is_staff());

create policy "member reads memberships" on public.memberships for select using (profile_id = auth.uid() or public.is_staff());
create policy "member creates membership" on public.memberships for insert with check (profile_id = auth.uid() and status = 'pending');
create policy "staff manages memberships" on public.memberships for all using (public.is_staff()) with check (public.is_staff());
create policy "member reads membership payments" on public.membership_payments for select using (exists(select 1 from public.memberships m where m.id=membership_id and m.profile_id=auth.uid()) or public.is_staff());
create policy "member creates membership payments" on public.membership_payments for insert with check (exists(select 1 from public.memberships m where m.id=membership_id and m.profile_id=auth.uid()) and status='pending');
create policy "staff manages membership payments" on public.membership_payments for all using (public.is_staff()) with check (public.is_staff());

create policy "owner reads certificates" on public.certificates for select using (exists(select 1 from public.enrollments e join public.participants p on p.id=e.participant_id where e.id=enrollment_id and p.profile_id=auth.uid()) or public.is_staff());
create policy "staff manages certificates" on public.certificates for all using (public.is_staff()) with check (public.is_staff());
create policy "staff reads settings" on public.system_settings for select using (public.is_staff());
create policy "administrator manages settings" on public.system_settings for all using (public.is_administrator()) with check (public.is_administrator());
create policy "administrator reads audit" on public.audit_logs for select using (public.is_administrator());
create policy "staff creates audit" on public.audit_logs for insert with check (actor_id = auth.uid() and public.is_staff());

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values
  ('payment-receipts', 'payment-receipts', false, 5242880, array['application/pdf','image/jpeg','image/png']),
  ('certificates', 'certificates', false, 10485760, array['application/pdf'])
on conflict (id) do nothing;

create policy "authenticated uploads own receipts" on storage.objects for insert to authenticated
with check (bucket_id = 'payment-receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "staff reads receipts" on storage.objects for select to authenticated
using (bucket_id = 'payment-receipts' and public.is_staff());
create policy "owners read own receipts" on storage.objects for select to authenticated
using (bucket_id = 'payment-receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "staff manages certificates files" on storage.objects for all to authenticated
using (bucket_id = 'certificates' and public.is_staff()) with check (bucket_id = 'certificates' and public.is_staff());

-- IMPORTANTE: la inscripción pública con archivo debe pasar por una Edge Function
-- protegida con CAPTCHA/rate limiting. No se permite carga anónima directa al bucket.

