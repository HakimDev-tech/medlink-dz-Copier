-- Phase 6: clinician hand-off queue and cancellation synchronization.
create table if not exists public.care_agent_escalations (
 id uuid primary key default gen_random_uuid(),
 run_id uuid not null unique references public.care_agent_runs(id) on delete cascade,
 plan_id uuid not null references public.follow_up_plans(id) on delete cascade,
 patient_id uuid not null references public.profiles(id) on delete cascade,
 doctor_id uuid not null references public.doctors(id) on delete cascade,
 reason text not null check(reason in ('urgent_escalation','out_of_scope','unknown')),
 status text not null default 'open' check(status in ('open','in_review','resolved')),
 created_at timestamptz not null default now(),
 resolved_at timestamptz
);
create index if not exists care_agent_escalations_doctor_idx on public.care_agent_escalations(doctor_id,status,created_at desc);
alter table public.care_agent_escalations enable row level security;
grant select,update on public.care_agent_escalations to authenticated;
create policy "care escalation participants read" on public.care_agent_escalations for select to authenticated
using(patient_id=(select auth.uid()) or exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
create policy "doctor resolves own care escalations" on public.care_agent_escalations for update to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));

create or replace function private.create_care_agent_escalation()
returns trigger language plpgsql security definer set search_path='' as $$
declare p public.follow_up_plans; d public.doctors; lang text; title_text text; body_text text;
begin
 if new.outcome<>'human_handoff' then return new; end if;
 select * into p from public.follow_up_plans where id=new.plan_id;
 select * into d from public.doctors where id=p.doctor_id;
 if p.id is null or d.id is null then return new; end if;
 insert into public.care_agent_escalations(run_id,plan_id,patient_id,doctor_id,reason)
 values(new.id,p.id,p.patient_id,d.id,new.intent)
 on conflict(run_id) do nothing;
 select preferred_language into lang from public.profiles where id=d.user_id;
 title_text:=case lang when 'ar' then 'طلب يتطلب مراجعتك' when 'en' then 'Care assistant hand-off' else 'Demande à examiner' end;
 body_text:=case lang when 'ar' then 'أحال مساعد المتابعة طلباً يتطلب مراجعتك.' when 'en' then 'The care-plan assistant flagged a patient request for your review.' else 'L’assistant de suivi a signalé une demande nécessitant votre examen.' end;
 insert into public.notifications(user_id,title,body,category)
 values(d.user_id,title_text,body_text,'care_agent');
 return new;
end; $$;
revoke all on function private.create_care_agent_escalation() from public,anon,authenticated;
drop trigger if exists medlink_care_agent_escalation on public.care_agent_runs;
create trigger medlink_care_agent_escalation after insert on public.care_agent_runs
for each row execute function private.create_care_agent_escalation();

create or replace function private.sync_followup_plan_status()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='published' and new.status in ('cancelled','completed') then
  update public.notification_schedules set status='cancelled',updated_at=now()
  where plan_id=new.id and status in ('pending','failed');
 end if;
 return new;
end; $$;
revoke all on function private.sync_followup_plan_status() from public,anon,authenticated;
drop trigger if exists medlink_sync_followup_plan_status on public.follow_up_plans;
create trigger medlink_sync_followup_plan_status after update of status on public.follow_up_plans
for each row execute function private.sync_followup_plan_status();

