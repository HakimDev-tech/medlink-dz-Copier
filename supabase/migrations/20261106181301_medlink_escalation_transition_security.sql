revoke update on public.care_agent_escalations from authenticated;
grant update(status,resolved_at) on public.care_agent_escalations to authenticated;

create or replace function private.enforce_care_escalation_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.run_id is distinct from old.run_id
     or new.plan_id is distinct from old.plan_id
     or new.patient_id is distinct from old.patient_id
     or new.doctor_id is distinct from old.doctor_id
     or new.reason is distinct from old.reason then
    raise exception 'Escalation identity and reason are immutable';
  end if;

  if not exists (
    select 1 from public.doctors d
    where d.id=old.doctor_id and d.user_id=(select auth.uid())
  ) and not private.is_platform_admin() then
    raise exception 'Only the assigned professional may update this escalation';
  end if;

  if old.status='resolved' then
    raise exception 'Resolved escalations are immutable';
  end if;
  if old.status='open' and new.status not in ('in_review','resolved') then
    raise exception 'Invalid escalation status transition';
  end if;
  if old.status='in_review' and new.status not in ('open','resolved') then
    raise exception 'Invalid escalation status transition';
  end if;

  if new.status='resolved' then
    new.resolved_at:=coalesce(new.resolved_at,now());
  else
    new.resolved_at:=null;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_care_escalation_transition() from public,anon,authenticated;
drop trigger if exists medlink_enforce_care_escalation_transition on public.care_agent_escalations;
create trigger medlink_enforce_care_escalation_transition
before update on public.care_agent_escalations
for each row execute function private.enforce_care_escalation_transition();
