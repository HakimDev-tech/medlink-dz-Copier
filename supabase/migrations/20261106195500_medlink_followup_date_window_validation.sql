-- Validate follow-up date windows consistently in the database (Algeria local calendar).
create or replace function private.enforce_followup_plan_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare appointment_is_valid boolean; invalid_event_exists boolean;
begin
  if new.ends_on is not null and new.ends_on < new.starts_on then
    raise exception 'Follow-up end date must not precede its start date';
  end if;
  if tg_op='INSERT' then
    if new.status <> 'draft' then raise exception 'Follow-up plans must be created as drafts'; end if;
    select exists(select 1 from public.appointments a where a.id=new.appointment_id and a.doctor_id=new.doctor_id and a.patient_id=new.patient_id and a.status='completed') into appointment_is_valid;
    if not appointment_is_valid then raise exception 'A follow-up plan must reference the matching completed appointment'; end if;
    return new;
  end if;
  if new.doctor_id is distinct from old.doctor_id or new.patient_id is distinct from old.patient_id or new.appointment_id is distinct from old.appointment_id then
    raise exception 'Follow-up participants and appointment are immutable';
  end if;
  if old.status='published' then
    if new.title is distinct from old.title or new.instructions is distinct from old.instructions or new.starts_on is distinct from old.starts_on or new.ends_on is distinct from old.ends_on or new.approved_at is distinct from old.approved_at then
      raise exception 'Published follow-up content is immutable; create a revised plan instead';
    end if;
    if new.status is distinct from old.status then
      if not private.is_platform_admin() or new.status not in ('completed','cancelled') then raise exception 'Only an administrator may close a published follow-up plan'; end if;
    elsif new.schedule_version <> old.schedule_version + 1 then
      raise exception 'Only the internal schedule synchronizer may version a published plan';
    end if;
    return new;
  end if;
  select exists(select 1 from public.follow_up_events e where e.plan_id=old.id and ((timezone('Africa/Algiers',e.event_at)::date < new.starts_on) or (new.ends_on is not null and timezone('Africa/Algiers',e.event_at)::date > new.ends_on))) into invalid_event_exists;
  if invalid_event_exists then raise exception 'Existing reminders must remain within the follow-up plan date range'; end if;
  return new;
end;
$$;
revoke all on function private.enforce_followup_plan_integrity() from public,anon,authenticated;

create or replace function private.enforce_followup_event_window()
returns trigger language plpgsql security definer set search_path = '' as $$
declare plan_start date; plan_end date;
begin
  select p.starts_on,p.ends_on into plan_start,plan_end from public.follow_up_plans p where p.id=new.plan_id;
  if plan_start is null then raise exception 'Follow-up plan not found'; end if;
  if timezone('Africa/Algiers',new.event_at)::date < plan_start or (plan_end is not null and timezone('Africa/Algiers',new.event_at)::date > plan_end) then
    raise exception 'Reminder date must be inside the follow-up plan period';
  end if;
  if tg_op='INSERT' or new.event_at is distinct from old.event_at then
    if new.event_at <= now() then raise exception 'New or rescheduled reminders must be in the future'; end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_followup_event_window() from public,anon,authenticated;
drop trigger if exists medlink_00_enforce_followup_event_window on public.follow_up_events;
create trigger medlink_00_enforce_followup_event_window before insert or update on public.follow_up_events
for each row execute function private.enforce_followup_event_window();

create or replace function private.validate_followup_publish()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status is distinct from new.status and new.status='published' then
    if new.approved_at is null then raise exception 'Professional approval timestamp is required'; end if;
    if not exists(select 1 from public.follow_up_events e where e.plan_id=new.id and e.event_at>now() and timezone('Africa/Algiers',e.event_at)::date>=new.starts_on and (new.ends_on is null or timezone('Africa/Algiers',e.event_at)::date<=new.ends_on)) then
      raise exception 'At least one future reminder inside the plan period is required before publishing';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.validate_followup_publish() from public,anon,authenticated;
