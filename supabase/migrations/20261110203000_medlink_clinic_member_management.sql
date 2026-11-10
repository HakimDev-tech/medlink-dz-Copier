create or replace function private.manage_medlink_clinic_member_impl(p_clinic_id uuid,p_user_id uuid,p_action text,p_role text default null)
returns void language plpgsql security definer set search_path='' as $$
declare owner_user uuid;target_role text;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.is_medlink_clinic_manager(p_clinic_id) then raise exception 'clinic_admin_required';end if;
 select owner_id into owner_user from public.clinics where id=p_clinic_id;
 if p_user_id=owner_user then raise exception 'cannot_change_clinic_owner';end if;
 select member_role into target_role from public.clinic_members where clinic_id=p_clinic_id and user_id=p_user_id;
 if not found then raise exception 'clinic_member_not_found';end if;
 if target_role='owner' then raise exception 'cannot_change_clinic_owner';end if;
 if p_action='remove' then
  delete from public.clinic_members where clinic_id=p_clinic_id and user_id=p_user_id;
 elsif p_action='change_role' then
  if p_role not in('manager','receptionist','doctor') then raise exception 'invalid_member_role';end if;
  if p_role='doctor' and not exists(select 1 from public.profiles where id=p_user_id and role='doctor') then raise exception 'account_role_not_eligible';end if;
  if p_role<>'doctor' and not exists(select 1 from public.profiles where id=p_user_id and role in('clinic_admin','doctor')) then raise exception 'account_role_not_eligible';end if;
  update public.clinic_members set member_role=p_role where clinic_id=p_clinic_id and user_id=p_user_id;
 else raise exception 'invalid_member_action';end if;
end;$$;
revoke all on function private.manage_medlink_clinic_member_impl(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function private.manage_medlink_clinic_member_impl(uuid,uuid,text,text) to authenticated;
create or replace function public.manage_medlink_clinic_member(p_clinic_id uuid,p_user_id uuid,p_action text,p_role text default null)
returns void language sql security invoker set search_path='' as $$ select private.manage_medlink_clinic_member_impl(p_clinic_id,p_user_id,p_action,p_role); $$;
revoke all on function public.manage_medlink_clinic_member(uuid,uuid,text,text) from public,anon;
grant execute on function public.manage_medlink_clinic_member(uuid,uuid,text,text) to authenticated;
