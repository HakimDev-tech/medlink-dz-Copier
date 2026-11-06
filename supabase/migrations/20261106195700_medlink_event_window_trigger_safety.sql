-- Avoid relying on an unassigned OLD record in INSERT trigger branches.
create or replace function private.enforce_followup_event_window()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare plan_start date; plan_end date;
begin
  select p.starts_on,p.ends_on into plan_start,plan_end
  from public.follow_up_plans p where p.id=new.plan_id;
  if plan_start is null then
    raise exception 'Follow-up plan not found';
  end if;
  if timezone('Africa/Algiers',new.event_at)::date < plan_start
     or (plan_end is not null and timezone('Africa/Algiers',new.event_at)::date > plan_end) then
    raise exception 'Reminder date must be inside the follow-up plan period';
  end if;
  if tg_op='INSERT' then
    if new.event_at<=now() then
      raise exception 'New reminders must be in the future';
    end if;
  elsif new.event_at is distinct from old.event_at then
    if new.event_at<=now() then
      raise exception 'Rescheduled reminders must be in the future';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_followup_event_window() from public,anon,authenticated;
