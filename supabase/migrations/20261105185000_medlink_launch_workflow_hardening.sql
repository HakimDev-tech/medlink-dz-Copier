-- Restrict client updates to workflow columns and enforce server-side state transitions.
revoke update on public.appointments from authenticated;
grant update(status) on public.appointments to authenticated;
revoke update on public.follow_up_plans from authenticated;
grant update(status, approved_at) on public.follow_up_plans to authenticated;
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;

drop policy if exists "platform admin read all doctor applications" on public.doctors;
create policy "platform admin read all doctor applications" on public.doctors for select to authenticated using(private.is_platform_admin());
drop policy if exists "platform admin update doctor verification" on public.doctors;
create policy "platform admin update doctor verification" on public.doctors for update to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());

create or replace function private.enforce_medlink_appointment_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_is_doctor boolean;
begin
 if old.status is not distinct from new.status then return new; end if;
 select exists(select 1 from public.doctors d where d.id=old.doctor_id and d.user_id=(select auth.uid())) into actor_is_doctor;
 if not actor_is_doctor and not private.is_platform_admin() then raise exception 'Only the assigned professional or platform administrator may change appointment status'; end if;
 if actor_is_doctor and not private.is_platform_admin() then
  if not ((old.status='requested' and new.status in ('confirmed','rejected')) or (old.status='confirmed' and new.status='completed')) then raise exception 'Invalid appointment status transition'; end if;
 end if;
 return new;
end; $$;
revoke all on function private.enforce_medlink_appointment_transition() from public,anon,authenticated;
drop trigger if exists medlink_enforce_appointment_transition on public.appointments;
create trigger medlink_enforce_appointment_transition before update of status on public.appointments for each row execute function private.enforce_medlink_appointment_transition();

create or replace function private.enforce_medlink_followup_publication()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_is_doctor boolean;
begin
 if old.status is distinct from new.status then
  select exists(select 1 from public.doctors d where d.id=old.doctor_id and d.user_id=(select auth.uid())) into actor_is_doctor;
  if not actor_is_doctor and not private.is_platform_admin() then raise exception 'Only the assigned professional may publish this follow-up'; end if;
  if actor_is_doctor and not private.is_platform_admin() and not (old.status='draft' and new.status='published') then raise exception 'Invalid follow-up status transition'; end if;
  if new.status='published' then new.approved_at=now(); end if;
 end if;
 return new;
end; $$;
revoke all on function private.enforce_medlink_followup_publication() from public,anon,authenticated;
drop trigger if exists medlink_enforce_followup_publication on public.follow_up_plans;
create trigger medlink_enforce_followup_publication before update of status on public.follow_up_plans for each row execute function private.enforce_medlink_followup_publication();

create or replace function private.audit_medlink_doctor_verification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.verification_status is distinct from new.verification_status then
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values((select auth.uid()),'doctor_verification_changed','doctor',new.id::text,jsonb_build_object('from',old.verification_status,'to',new.verification_status));
  new.verified_at=case when new.verification_status='verified' then now() else null end;
 end if;
 return new;
end; $$;
revoke all on function private.audit_medlink_doctor_verification() from public,anon,authenticated;
drop trigger if exists medlink_audit_doctor_verification on public.doctors;
create trigger medlink_audit_doctor_verification before update of verification_status on public.doctors for each row execute function private.audit_medlink_doctor_verification();
