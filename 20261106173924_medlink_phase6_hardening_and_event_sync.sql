-- Phase 6 hardening: bind consultation rows to the exact completed appointment and keep reminder jobs synchronized.
drop policy if exists "doctor create consultation draft" on public.consultation_records;
create policy "doctor create consultation draft" on public.consultation_records for insert to authenticated
with check (
 status='draft' and exists(
  select 1 from public.appointments a
  join public.doctors d on d.id=a.doctor_id
  where a.id=consultation_records.appointment_id
    and a.doctor_id=consultation_records.doctor_id
    and a.patient_id=consultation_records.patient_id
    and a.status='completed'
    and d.user_id=(select auth.uid())
 )
);
create or replace function public.claim_medlink_notification_jobs(batch_size integer default 50)
returns setof public.notification_schedules
language plpgsql security definer set search_path='' as $$
begin
 if current_setting('request.jwt.claim.role',true) is distinct from 'service_role' then
  raise exception 'service role required';
 end if;
 return query
 with due as (
  select id from public.notification_schedules
  where status in ('pending','failed') and due_at<=now() and next_attempt_at<=now() and attempts<max_attempts
  order by due_at asc for update skip locked limit greatest(1,least(batch_size,100))
 )
 update public.notification_schedules s
 set status='processing',attempts=s.attempts+1,updated_at=now()
 from due where s.id=due.id returning s.*;
end; $$;
revoke all on function public.claim_medlink_notification_jobs(integer) from public,anon,authenticated;
grant execute on function public.claim_medlink_notification_jobs(integer) to service_role;

create or replace function private.sync_followup_event_schedule()
returns trigger language plpgsql security definer set search_path='' as $$
declare p public.follow_up_plans;
begin
 if tg_op='DELETE' then
  update public.notification_schedules set status='cancelled',updated_at=now()
  where event_id=old.id and status in ('pending','failed');
  return old;
 end if;
 select * into p from public.follow_up_plans where id=new.plan_id;
 if p.status='published' then
  insert into public.notification_schedules(plan_id,event_id,user_id,due_at,idempotency_key,schedule_version)
  values(p.id,new.id,p.patient_id,new.event_at,p.id::text||':'||new.id::text,p.schedule_version)
  on conflict(event_id) do update set
   user_id=excluded.user_id,due_at=excluded.due_at,schedule_version=excluded.schedule_version,
   status=case when public.notification_schedules.status in ('sent','processing') then public.notification_schedules.status else 'pending' end,
   next_attempt_at=now(),updated_at=now();
 end if;
 return new;
end; $$;
revoke all on function private.sync_followup_event_schedule() from public,anon,authenticated;
drop trigger if exists medlink_sync_followup_event_schedule on public.follow_up_events;
create trigger medlink_sync_followup_event_schedule
after insert or update of event_at,plan_id or delete on public.follow_up_events
for each row execute function private.sync_followup_event_schedule();

create or replace function private.validate_followup_publish()
returns trigger language plpgsql set search_path='' as $$
begin
 if old.status is distinct from new.status and new.status='published' then
  if new.approved_at is null then raise exception 'Professional approval timestamp is required'; end if;
  if not exists(select 1 from public.follow_up_events e where e.plan_id=new.id and e.event_at>now()) then
   raise exception 'At least one future follow-up event is required before publishing';
  end if;
 end if;
 return new;
end; $$;
revoke all on function private.validate_followup_publish() from public,anon,authenticated;
drop trigger if exists medlink_validate_followup_publish on public.follow_up_plans;
create trigger medlink_validate_followup_publish before update of status on public.follow_up_plans
for each row execute function private.validate_followup_publish();

