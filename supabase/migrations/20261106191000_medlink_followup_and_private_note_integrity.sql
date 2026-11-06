-- Prevent client-side reassignment or silent edits to published clinical instructions.
create or replace function private.enforce_followup_plan_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  appointment_is_valid boolean;
begin
  if tg_op='INSERT' then
    if new.status <> 'draft' then
      raise exception 'Follow-up plans must be created as drafts';
    end if;
    select exists(
      select 1 from public.appointments a
      where a.id=new.appointment_id
        and a.doctor_id=new.doctor_id
        and a.patient_id=new.patient_id
        and a.status='completed'
    ) into appointment_is_valid;
    if not appointment_is_valid then
      raise exception 'A follow-up plan must reference the matching completed appointment';
    end if;
    return new;
  end if;

  if new.doctor_id is distinct from old.doctor_id
     or new.patient_id is distinct from old.patient_id
     or new.appointment_id is distinct from old.appointment_id then
    raise exception 'Follow-up participants and appointment are immutable';
  end if;

  if old.status='published' then
    if new.title is distinct from old.title
       or new.instructions is distinct from old.instructions
       or new.starts_on is distinct from old.starts_on
       or new.ends_on is distinct from old.ends_on
       or new.approved_at is distinct from old.approved_at then
      raise exception 'Published follow-up content is immutable; create a revised plan instead';
    end if;
    if new.status is distinct from old.status then
      if not private.is_platform_admin() or new.status not in ('completed','cancelled') then
        raise exception 'Only an administrator may close a published follow-up plan';
      end if;
    elsif new.schedule_version <> old.schedule_version + 1 then
      raise exception 'Only the internal schedule synchronizer may version a published plan';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_followup_plan_integrity() from public,anon,authenticated;
drop trigger if exists medlink_00_followup_plan_integrity on public.follow_up_plans;
create trigger medlink_00_followup_plan_integrity
before insert or update on public.follow_up_plans
for each row execute function private.enforce_followup_plan_integrity();

create or replace function private.enforce_consultation_private_note_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists(
    select 1 from public.consultation_records c
    where c.id=new.consultation_id and c.doctor_id=new.doctor_id
  ) then
    raise exception 'Private notes must belong to the consultation owner';
  end if;
  if tg_op='UPDATE' and (new.consultation_id is distinct from old.consultation_id or new.doctor_id is distinct from old.doctor_id) then
    raise exception 'Private note ownership is immutable';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_consultation_private_note_owner() from public,anon,authenticated;
drop trigger if exists medlink_enforce_consultation_private_note_owner on public.consultation_private_notes;
create trigger medlink_enforce_consultation_private_note_owner
before insert or update on public.consultation_private_notes
for each row execute function private.enforce_consultation_private_note_owner();
