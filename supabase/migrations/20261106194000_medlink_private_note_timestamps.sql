-- Keep private consultation note modification timestamps accurate.
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
  if tg_op='UPDATE' then
    if new.consultation_id is distinct from old.consultation_id
       or new.doctor_id is distinct from old.doctor_id then
      raise exception 'Private note ownership is immutable';
    end if;
    new.updated_at:=now();
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_consultation_private_note_owner() from public,anon,authenticated;
