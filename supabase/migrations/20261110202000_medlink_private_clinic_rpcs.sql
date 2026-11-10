create or replace function private.create_medlink_clinic_impl(p_name text,p_wilaya text,p_commune text,p_address text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();cid uuid;account_role text;
begin
 if u is null then raise exception 'authentication_required';end if;
 select role::text into account_role from public.profiles where id=u;
 if account_role not in('doctor','clinic_admin','platform_admin') then raise exception 'clinic_account_required';end if;
 if length(trim(coalesce(p_name,'')))<2 or length(trim(coalesce(p_wilaya,'')))<2 then raise exception 'invalid_clinic_details';end if;
 insert into public.clinics(name,wilaya,commune,address,owner_id,verification_status) values(trim(p_name),trim(p_wilaya),nullif(trim(p_commune),''),nullif(trim(p_address),''),u,'pending') returning id into cid;
 insert into public.clinic_members(clinic_id,user_id,member_role) values(cid,u,'owner');
 return cid;
end;$$;
create or replace function private.invite_medlink_clinic_member_impl(p_clinic_id uuid,p_email text,p_role text default 'receptionist')
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();inv uuid;tok text:=encode(extensions.gen_random_bytes(32),'hex');target uuid;target_role text;
begin
 if u is null then raise exception 'authentication_required';end if;
 if p_role not in('manager','receptionist','doctor') or position('@' in p_email)=0 then raise exception 'invalid_invitation';end if;
 if not private.is_medlink_clinic_manager(p_clinic_id) then raise exception 'clinic_admin_required';end if;
 select id into target from auth.users where lower(email)=lower(trim(p_email));
 if target is not null then
  select role::text into target_role from public.profiles where id=target;
  if (p_role='doctor' and target_role<>'doctor') or (p_role<>'doctor' and target_role not in('clinic_admin','doctor')) then raise exception 'account_role_not_eligible';end if;
  if exists(select 1 from public.clinic_members m where m.clinic_id=p_clinic_id and m.user_id=target and coalesce(m.member_status,'active')='active') then raise exception 'already_a_member';end if;
 end if;
 insert into public.clinic_invitations(clinic_id,email,member_role,invited_by,token_hash) values(p_clinic_id,lower(trim(p_email)),p_role,u,encode(extensions.digest(convert_to(tok,'UTF8'),'sha256'),'hex')) returning id into inv;
 return jsonb_build_object('invitation_id',inv,'invitation_token',tok);
end;$$;
create or replace function private.accept_medlink_clinic_invitation_impl(p_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();inv public.clinic_invitations%rowtype;user_email text;account_role text;
begin
 if u is null then raise exception 'authentication_required';end if;
 select lower(email) into user_email from auth.users where id=u;
 select role::text into account_role from public.profiles where id=u;
 select * into inv from public.clinic_invitations where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex') and status='pending' and expires_at>now() for update;
 if not found or inv.email<>user_email then raise exception 'invalid_or_expired_invitation';end if;
 if (inv.member_role='doctor' and account_role<>'doctor') or (inv.member_role<>'doctor' and account_role not in('clinic_admin','doctor')) then raise exception 'account_role_not_eligible';end if;
 insert into public.clinic_members(clinic_id,user_id,member_role,member_status) values(inv.clinic_id,u,inv.member_role,'active')
 on conflict(clinic_id,user_id) do update set member_role=excluded.member_role,member_status='active';
 update public.clinic_invitations set status='accepted',accepted_at=now() where id=inv.id;
 return inv.clinic_id;
end;$$;
revoke all on function private.create_medlink_clinic_impl(text,text,text,text) from public,anon,authenticated;
revoke all on function private.invite_medlink_clinic_member_impl(uuid,text,text) from public,anon,authenticated;
revoke all on function private.accept_medlink_clinic_invitation_impl(text) from public,anon,authenticated;
grant execute on function private.create_medlink_clinic_impl(text,text,text,text) to authenticated;
grant execute on function private.invite_medlink_clinic_member_impl(uuid,text,text) to authenticated;
grant execute on function private.accept_medlink_clinic_invitation_impl(text) to authenticated;
create or replace function public.create_medlink_clinic(p_name text,p_wilaya text,p_commune text,p_address text)
returns uuid language sql security invoker set search_path='' as $$ select private.create_medlink_clinic_impl(p_name,p_wilaya,p_commune,p_address); $$;
create or replace function public.invite_medlink_clinic_member(p_clinic_id uuid,p_email text,p_role text default 'receptionist')
returns jsonb language sql security invoker set search_path='' as $$ select private.invite_medlink_clinic_member_impl(p_clinic_id,p_email,p_role); $$;
create or replace function public.accept_medlink_clinic_invitation(p_token text)
returns uuid language sql security invoker set search_path='' as $$ select private.accept_medlink_clinic_invitation_impl(p_token); $$;
revoke all on function public.create_medlink_clinic(text,text,text,text) from public,anon;
revoke all on function public.invite_medlink_clinic_member(uuid,text,text) from public,anon;
revoke all on function public.accept_medlink_clinic_invitation(text) from public,anon;
grant execute on function public.create_medlink_clinic(text,text,text,text) to authenticated;
grant execute on function public.invite_medlink_clinic_member(uuid,text,text) to authenticated;
grant execute on function public.accept_medlink_clinic_invitation(text) to authenticated;
