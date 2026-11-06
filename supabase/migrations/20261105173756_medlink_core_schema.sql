
-- MedLink DZ core schema. Synthetic/demo data only; never store real medical records in this prototype.
create extension if not exists pgcrypto;

create schema if not exists private;

do $$ begin
  create type public.medlink_user_role as enum ('patient','doctor','clinic_admin','platform_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.verification_status as enum ('pending','in_review','verified','rejected','suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.appointment_status as enum ('requested','confirmed','cancelled','completed','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.home_visit_status as enum ('requested','accepted','rejected','cancelled','completed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.refund_status as enum ('requested','under_review','approved','rejected','processing','refunded','failed');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.medlink_user_role not null default 'patient',
  full_name text not null default '',
  phone text,
  preferred_language text not null default 'fr' check (preferred_language in ('fr','ar','en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.doctors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  specialty text not null,
  wilaya text not null,
  commune text,
  practice_address text,
  bio text,
  registration_reference text,
  verification_status public.verification_status not null default 'pending',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  wilaya text not null,
  commune text,
  address text,
  verification_status public.verification_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists public.clinic_members (
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role text not null check (member_role in ('owner','manager','receptionist','doctor')),
  created_at timestamptz not null default now(),
  primary key (clinic_id,user_id)
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id),
  doctor_id uuid not null references public.doctors(id),
  clinic_id uuid references public.clinics(id),
  starts_at timestamptz not null,
  reason text,
  status public.appointment_status not null default 'requested',
  patient_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint appointment_future check (starts_at > created_at - interval '1 minute')
);

create table if not exists public.follow_up_plans (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.doctors(id),
  patient_id uuid not null references public.profiles(id),
  appointment_id uuid references public.appointments(id),
  title text not null,
  instructions text not null,
  starts_on date not null,
  ends_on date,
  status text not null default 'draft' check (status in ('draft','published','completed','cancelled')),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create table if not exists public.follow_up_events (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.follow_up_plans(id) on delete cascade,
  event_at timestamptz not null,
  label text not null,
  instruction text,
  created_at timestamptz not null default now()
);

create table if not exists public.home_visit_requests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id),
  doctor_id uuid references public.doctors(id),
  wilaya text not null,
  commune text not null,
  address text not null,
  requested_for timestamptz,
  reason text,
  status public.home_visit_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id),
  doctor_id uuid not null references public.doctors(id),
  created_at timestamptz not null default now(),
  unique(patient_id,doctor_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  category text not null default 'general',
  scheduled_for timestamptz,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.refund_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id),
  appointment_id uuid references public.appointments(id),
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'DZD',
  reason text not null,
  status public.refund_status not null default 'requested',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists doctors_search_idx on public.doctors (wilaya,specialty,verification_status);
create index if not exists appointments_patient_idx on public.appointments (patient_id,starts_at desc);
create index if not exists appointments_doctor_idx on public.appointments (doctor_id,starts_at desc);
create index if not exists follow_up_patient_idx on public.follow_up_plans (patient_id,starts_on desc);
create index if not exists messages_conversation_idx on public.messages (conversation_id,created_at);
create index if not exists notifications_user_idx on public.notifications (user_id,created_at desc);

-- The signup trigger never trusts user-supplied role metadata.
create or replace function private.handle_new_medlink_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, role, full_name)
  values (new.id, 'patient', coalesce(new.raw_user_meta_data ->> 'full_name',''));
  return new;
end;
$$;

revoke all on function private.handle_new_medlink_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_medlink on auth.users;
create trigger on_auth_user_created_medlink
after insert on auth.users
for each row execute function private.handle_new_medlink_user();

-- RLS is enabled on every exposed application table.
alter table public.profiles enable row level security;
alter table public.doctors enable row level security;
alter table public.clinics enable row level security;
alter table public.clinic_members enable row level security;
alter table public.appointments enable row level security;
alter table public.follow_up_plans enable row level security;
alter table public.follow_up_events enable row level security;
alter table public.home_visit_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.refund_requests enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: users can read/update only their own profile. Role is not client-updatable.
drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role') = 'platform_admin');
drop policy if exists "profile update own" on public.profiles;
create policy "profile update own" on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Public directory only exposes approved professional profiles.
drop policy if exists "public read verified doctors" on public.doctors;
create policy "public read verified doctors" on public.doctors for select to anon, authenticated
using (verification_status = 'verified');
drop policy if exists "doctor read own record" on public.doctors;
create policy "doctor read own record" on public.doctors for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists "doctor create pending record" on public.doctors;
create policy "doctor create pending record" on public.doctors for insert to authenticated
with check (user_id = (select auth.uid()) and verification_status = 'pending');

-- Clinics and memberships are private to their members; public directory is not enabled yet.
drop policy if exists "clinic members read clinic" on public.clinics;
create policy "clinic members read clinic" on public.clinics for select to authenticated
using (exists (select 1 from public.clinic_members m where m.clinic_id=id and m.user_id=(select auth.uid())));
drop policy if exists "members read own memberships" on public.clinic_members;
create policy "members read own memberships" on public.clinic_members for select to authenticated
using (user_id=(select auth.uid()));

-- Appointment participants may read. Patient may request; assigned doctor may update status/details.
drop policy if exists "appointment participants read" on public.appointments;
create policy "appointment participants read" on public.appointments for select to authenticated
using (patient_id=(select auth.uid()) or exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "patient create appointment" on public.appointments;
create policy "patient create appointment" on public.appointments for insert to authenticated
with check (patient_id=(select auth.uid()) and status='requested');
drop policy if exists "doctor update appointment" on public.appointments;
create policy "doctor update appointment" on public.appointments for update to authenticated
using (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));

-- Follow-up plans: doctor owns creation; patient can read only published plans.
drop policy if exists "followup doctor read" on public.follow_up_plans;
create policy "followup doctor read" on public.follow_up_plans for select to authenticated
using (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "followup patient read published" on public.follow_up_plans;
create policy "followup patient read published" on public.follow_up_plans for select to authenticated
using (patient_id=(select auth.uid()) and status='published');
drop policy if exists "doctor create followup draft" on public.follow_up_plans;
create policy "doctor create followup draft" on public.follow_up_plans for insert to authenticated
with check (status='draft' and exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "doctor update own followup" on public.follow_up_plans;
create policy "doctor update own followup" on public.follow_up_plans for update to authenticated
using (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));

drop policy if exists "followup events visible to participants" on public.follow_up_events;
create policy "followup events visible to participants" on public.follow_up_events for select to authenticated
using (exists (select 1 from public.follow_up_plans p where p.id=plan_id and ((p.patient_id=(select auth.uid()) and p.status='published') or exists (select 1 from public.doctors d where d.id=p.doctor_id and d.user_id=(select auth.uid())))));
drop policy if exists "doctor manage followup events" on public.follow_up_events;
create policy "doctor manage followup events" on public.follow_up_events for all to authenticated
using (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())))
with check (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));

-- Home visit requests: patient owns creation/read; assigned doctor can read/update.
drop policy if exists "home visit participants read" on public.home_visit_requests;
create policy "home visit participants read" on public.home_visit_requests for select to authenticated
using (patient_id=(select auth.uid()) or exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "patient create home visit" on public.home_visit_requests;
create policy "patient create home visit" on public.home_visit_requests for insert to authenticated
with check (patient_id=(select auth.uid()) and status='requested');
drop policy if exists "doctor update home visit" on public.home_visit_requests;
create policy "doctor update home visit" on public.home_visit_requests for update to authenticated
using (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check (exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));

-- Messages: only the patient and doctor assigned to a conversation can access it.
drop policy if exists "conversation participants read" on public.conversations;
create policy "conversation participants read" on public.conversations for select to authenticated
using (patient_id=(select auth.uid()) or exists (select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "patient create conversation" on public.conversations;
create policy "patient create conversation" on public.conversations for insert to authenticated
with check (patient_id=(select auth.uid()));
drop policy if exists "message participants read" on public.messages;
create policy "message participants read" on public.messages for select to authenticated
using (exists (select 1 from public.conversations c where c.id=conversation_id and (c.patient_id=(select auth.uid()) or exists (select 1 from public.doctors d where d.id=c.doctor_id and d.user_id=(select auth.uid())))));
drop policy if exists "participants send messages" on public.messages;
create policy "participants send messages" on public.messages for insert to authenticated
with check (sender_id=(select auth.uid()) and exists (select 1 from public.conversations c where c.id=conversation_id and (c.patient_id=(select auth.uid()) or exists (select 1 from public.doctors d where d.id=c.doctor_id and d.user_id=(select auth.uid())))));

-- Notifications and refunds are user-scoped. Refund review is reserved for platform-side administration.
drop policy if exists "users read own notifications" on public.notifications;
create policy "users read own notifications" on public.notifications for select to authenticated
using (user_id=(select auth.uid()));
drop policy if exists "users mark own notifications read" on public.notifications;
create policy "users mark own notifications read" on public.notifications for update to authenticated
using (user_id=(select auth.uid()))
with check (user_id=(select auth.uid()));
drop policy if exists "users read own refunds" on public.refund_requests;
create policy "users read own refunds" on public.refund_requests for select to authenticated
using (requester_id=(select auth.uid()));
drop policy if exists "users create own refunds" on public.refund_requests;
create policy "users create own refunds" on public.refund_requests for insert to authenticated
with check (requester_id=(select auth.uid()) and status='requested');

drop policy if exists "platform admin read audit logs" on public.audit_logs;
create policy "platform admin read audit logs" on public.audit_logs for select to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='platform_admin');

-- No direct client access to audit log writes or verification decisions.
revoke all on public.audit_logs from anon, authenticated;
grant select on public.audit_logs to authenticated;
grant select on public.doctors to anon, authenticated;
grant select on public.clinics to authenticated;
grant select on public.profiles, public.clinic_members, public.appointments, public.follow_up_plans,
  public.follow_up_events, public.home_visit_requests, public.conversations, public.messages,
  public.notifications, public.refund_requests to authenticated;

-- Remove unsafe access to an unrelated SECURITY DEFINER helper found by the security advisor.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

