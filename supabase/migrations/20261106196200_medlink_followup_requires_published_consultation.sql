-- Require a published consultation record before creating or editing a follow-up plan.
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
    select exists(
      select 1 from public.appointments a
      where a.id=new.appointment_id and a.doctor_id=new.doctor_id
        and a.patient_id=new.patient_id and a.status='completed'
        and exists(
          select 1 from public.consultation_records c
          where c.appointment_id=a.id and c.doctor_id=a.doctor_id
            and c.patient_id=a.patient_id and c.status='published'
        )
    ) into appointment_is_valid;
    if not appointment_is_valid then
      raise exception 'A follow-up plan requires the matching completed appointment and published consultation record';
    end if;
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
  if not exists(
    select 1 from public.appointments a
    join public.consultation_records c on c.appointment_id=a.id
    where a.id=new.appointment_id and a.doctor_id=new.doctor_id and a.patient_id=new.patient_id
      and a.status='completed' and c.doctor_id=new.doctor_id and c.patient_id=new.patient_id and c.status='published'
  ) then
    raise exception 'A follow-up plan requires the matching completed appointment and published consultation record';
  end if;
  select exists(
    select 1 from public.follow_up_events e
    where e.plan_id=old.id
      and ((timezone('Africa/Algiers',e.event_at)::date < new.starts_on)
        or (new.ends_on is not null and timezone('Africa/Algiers',e.event_at)::date > new.ends_on))
  ) into invalid_event_exists;
  if invalid_event_exists then raise exception 'Existing reminders must remain within the follow-up plan date range'; end if;
  return new;
end;
$$;
revoke all on function private.enforce_followup_plan_integrity() from public,anon,authenticated;
