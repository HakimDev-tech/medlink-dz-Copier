-- Phase 6: consultation records, event-driven follow-up reminders, and constrained care-plan agent audit.
create table if not exists public.consultation_records (
 id uuid primary key default gen_random_uuid(),
 appointment_id uuid not null unique references public.appointments(id) on delete cascade,
 doctor_id uuid not null references public.doctors(id),
 patient_id uuid not null references public.profiles(id),
 summary text not null default '' check (char_length(summary) <= 5000),
 patient_instructions text not null default '' check (char_length(patient_instructions) <= 5000),
 status text not null default 'draft' check (status in ('draft','published')),
 published_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (status <> 'published' or published_at is not null)
);
create index if not exists consultation_records_patient_idx on public.consultation_records(patient_id,created_at desc);
create index if not exists consultation_records_doctor_idx on public.consultation_records(doctor_id,created_at desc);
alter table public.consultation_records enable row level security;
grant select,insert,update on public.consultation_records to authenticated;
create policy "consultation participants read" on public.consultation_records for select to authenticated
using ((patient_id=(select auth.uid()) and status='published') or exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
create policy "doctor create consultation draft" on public.consultation_records for insert to authenticated
with check (status='draft' and exists(select 1 from public.doctors d join public.appointments a on a.doctor_id=d.id where d.id=doctor_id and d.user_id=(select auth.uid()) and a.id=appointment_id and a.patient_id=patient_id and a.status='completed'));
create policy "doctor update consultation draft" on public.consultation_records for update to authenticated
using(status='draft' and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check(status in ('draft','published') and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
create or replace function private.sync_consultation_record()
returns trigger language plpgsql set search_path='' as $$
begin
 new.updated_at := now();
 if new.status='published' and old.status is distinct from 'published' then
  if length(trim(new.summary))=0 and length(trim(new.patient_instructions))=0 then
   raise exception 'A consultation record needs a patient-facing summary or instructions';
  end if;
  new.published_at := now();
 end if;
 return new;
end; $$;
revoke all on function private.sync_consultation_record() from public,anon,authenticated;
drop trigger if exists medlink_sync_consultation_record on public.consultation_records;
create trigger medlink_sync_consultation_record before update on public.consultation_records for each row execute function private.sync_consultation_record();

-- A separate doctor-only table prevents private clinical notes from leaking through patient-readable consultation rows.
create table if not exists public.consultation_private_notes (
 consultation_id uuid primary key references public.consultation_records(id) on delete cascade,
 doctor_id uuid not null references public.doctors(id),
 notes text not null default '' check (char_length(notes) <= 10000),
 updated_at timestamptz not null default now()
);
alter table public.consultation_private_notes enable row level security;
grant select,insert,update,delete on public.consultation_private_notes to authenticated;
create policy "doctor manages own private consultation notes" on public.consultation_private_notes for all to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));

-- Follow-up events are the approved, structured source for reminders and agent retrieval.
alter table public.follow_up_plans add column if not exists schedule_version integer not null default 1;
create index if not exists follow_up_events_event_at_idx on public.follow_up_events(event_at);
create table if not exists public.notification_schedules (
 id uuid primary key default gen_random_uuid(),
 plan_id uuid not null references public.follow_up_plans(id) on delete cascade,
 event_id uuid not null unique references public.follow_up_events(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 due_at timestamptz not null,
 status text not null default 'pending' check(status in ('pending','processing','sent','failed','cancelled')),
 attempts integer not null default 0 check(attempts >= 0),
 max_attempts integer not null default 5 check(max_attempts between 1 and 10),
 next_attempt_at timestamptz not null default now(),
 last_error text,
 idempotency_key text not null unique,
 schedule_version integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists notification_schedules_due_idx on public.notification_schedules(status,next_attempt_at,due_at);
create table if not exists public.notification_logs (
 id bigint generated always as identity primary key,
 job_id uuid not null references public.notification_schedules(id) on delete cascade,
 attempt integer not null,
 outcome text not null check(outcome in ('sent','retry','failed','skipped')),
 detail text,
 processed_at timestamptz not null default now()
);
alter table public.notification_schedules enable row level security;
alter table public.notification_logs enable row level security;
revoke all on public.notification_schedules,public.notification_logs from anon,authenticated;
grant select on public.notification_schedules to authenticated;
create policy "participants read their reminder schedules" on public.notification_schedules for select to authenticated
using(user_id=(select auth.uid()) or exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));
-- Logs are intentionally service-role only; never expose dispatcher internals to clients.

alter table public.notifications add column if not exists source_job_id uuid unique references public.notification_schedules(id) on delete set null;
create or replace function private.enqueue_published_followup_events()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status is distinct from new.status and new.status='published' then
  insert into public.notification_schedules(plan_id,event_id,user_id,due_at,idempotency_key,schedule_version)
  select new.id,e.id,new.patient_id,e.event_at,new.id::text||':'||e.id::text,new.schedule_version
  from public.follow_up_events e where e.plan_id=new.id and e.event_at>now()
  on conflict (event_id) do update set
   user_id=excluded.user_id,due_at=excluded.due_at,schedule_version=excluded.schedule_version,
   status=case when public.notification_schedules.status in ('sent','processing') then public.notification_schedules.status else 'pending' end,
   next_attempt_at=now(),updated_at=now();
 end if;
 return new;
end; $$;
revoke all on function private.enqueue_published_followup_events() from public,anon,authenticated;
drop trigger if exists medlink_enqueue_followup_reminders on public.follow_up_plans;
create trigger medlink_enqueue_followup_reminders after update of status on public.follow_up_plans for each row execute function private.enqueue_published_followup_events();

-- Safe claim function: only the service role can claim jobs; SKIP LOCKED prevents concurrent workers duplicating work.
create or replace function public.claim_medlink_notification_jobs(batch_size integer default 50)
returns setof public.notification_schedules
language plpgsql security definer set search_path='' as $$
begin
 if current_setting('request.jwt.claim.role',true) <> 'service_role' then
  raise exception 'service role required';
 end if;
 return query
 with due as (
  select id from public.notification_schedules
  where status in ('pending','failed') and due_at<=now() and next_attempt_at<=now() and attempts<max_attempts
  order by due_at asc
  for update skip locked
  limit greatest(1,least(batch_size,100))
 )
 update public.notification_schedules s
 set status='processing',attempts=s.attempts+1,updated_at=now()
 from due where s.id=due.id
 returning s.*;
end; $$;
revoke all on function public.claim_medlink_notification_jobs(integer) from public,anon,authenticated;
grant execute on function public.claim_medlink_notification_jobs(integer) to service_role;

-- Agent audit stores intent and outcome only; no raw prompt or copied medical context.
create table if not exists public.care_agent_runs (
 id uuid primary key default gen_random_uuid(),
 plan_id uuid not null references public.follow_up_plans(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 intent text not null check(intent in ('plan_lookup','schedule_lookup','out_of_scope','urgent_escalation','unknown')),
 outcome text not null check(outcome in ('answered_from_plan','human_handoff','refused','error')),
 safety_flags text[] not null default '{}',
 created_at timestamptz not null default now()
);
create index if not exists care_agent_runs_plan_idx on public.care_agent_runs(plan_id,created_at desc);
alter table public.care_agent_runs enable row level security;
grant select,insert on public.care_agent_runs to authenticated;
create policy "care agent runs visible to plan participants" on public.care_agent_runs for select to authenticated
using(actor_id=(select auth.uid()) or exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));
create policy "participants record own care agent runs" on public.care_agent_runs for insert to authenticated
with check(actor_id=(select auth.uid()) and exists(select 1 from public.follow_up_plans p where p.id=plan_id and (p.patient_id=(select auth.uid()) or exists(select 1 from public.doctors d where d.id=p.doctor_id and d.user_id=(select auth.uid())))));

-- Live in-app notification delivery is row-level protected by the existing owner-read policy.
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
  alter publication supabase_realtime add table public.notifications;
 end if;
end $$;

