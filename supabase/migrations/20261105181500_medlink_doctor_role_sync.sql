create or replace function private.set_medlink_doctor_role()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set role='doctor', updated_at=now() where id=new.user_id;
  return new;
end;
$$;
revoke all on function private.set_medlink_doctor_role() from public,anon,authenticated;
drop trigger if exists on_medlink_doctor_created on public.doctors;
create trigger on_medlink_doctor_created after insert on public.doctors
for each row execute function private.set_medlink_doctor_role();
