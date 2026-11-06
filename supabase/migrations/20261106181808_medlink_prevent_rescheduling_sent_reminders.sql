create or replace function private.prevent_followup_event_reassignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.plan_id is distinct from old.plan_id then
    raise exception 'A reminder cannot be moved to another care plan';
  end if;
  if new.event_at is distinct from old.event_at and exists(
    select 1 from public.notification_schedules s
    where s.event_id=old.id and s.status in ('sent','processing')
  ) then
    raise exception 'A reminder already sent or being processed cannot be rescheduled';
  end if;
  return new;
end;
$$;
revoke all on function private.prevent_followup_event_reassignment() from public,anon,authenticated;
