create or replace function private.is_medlink_clinic_manager(p_clinic_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.clinics c where c.id=p_clinic_id and c.owner_id=(select auth.uid()))
 or exists(select 1 from public.clinic_members m where m.clinic_id=p_clinic_id and m.user_id=(select auth.uid()) and m.member_role in('owner','manager') and coalesce(m.member_status,'active')='active');
$$;
revoke all on function private.is_medlink_clinic_manager(uuid) from public,anon,authenticated;
drop policy if exists "clinic managers read invitations" on public.clinic_invitations;
create policy "clinic managers read invitations" on public.clinic_invitations for select to authenticated using(private.is_medlink_clinic_manager(clinic_id));
drop policy if exists "clinic members read memberships" on public.clinic_members;
create policy "clinic members read memberships" on public.clinic_members for select to authenticated using(user_id=(select auth.uid()) or private.is_medlink_clinic_manager(clinic_id));
drop policy if exists "clinic admins manage members" on public.clinic_members;
revoke insert,update,delete on public.clinic_members from authenticated;
revoke update on public.clinics from authenticated;
grant update(name,wilaya,commune,address) on public.clinics to authenticated;
drop policy if exists "clinic owner manages clinic" on public.clinics;
create policy "clinic owner manages clinic" on public.clinics for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy "platform admins read all refunds" on public.refund_requests for select to authenticated using(private.is_platform_admin());
