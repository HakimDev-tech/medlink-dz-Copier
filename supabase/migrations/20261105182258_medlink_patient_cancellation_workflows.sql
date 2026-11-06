
drop policy if exists "patient cancel own appointment" on public.appointments;
create policy "patient cancel own appointment" on public.appointments for update to authenticated
using(patient_id=(select auth.uid())) with check(patient_id=(select auth.uid()));

create or replace function private.enforce_medlink_appointment_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_is_doctor boolean; actor_is_patient boolean;
begin
 if old.status is not distinct from new.status then return new; end if;
 select exists(select 1 from public.doctors d where d.id=old.doctor_id and d.user_id=(select auth.uid())) into actor_is_doctor;
 actor_is_patient := old.patient_id=(select auth.uid());
 if not actor_is_doctor and not actor_is_patient and not private.is_platform_admin() then
  raise exception 'Only appointment participants may change appointment status';
 end if;
 if actor_is_doctor and not private.is_platform_admin() then
  if not ((old.status='requested' and new.status in ('confirmed','rejected')) or (old.status='confirmed' and new.status='completed')) then
   raise exception 'Invalid appointment status transition';
  end if;
 elsif actor_is_patient and not private.is_platform_admin() then
  if not (old.status in ('requested','confirmed') and new.status='cancelled') then
   raise exception 'Patients may only cancel requested or confirmed appointments';
  end if;
 end if;
 return new;
end; $$;

drop policy if exists "patient cancel own home visit" on public.home_visit_requests;
create policy "patient cancel own home visit" on public.home_visit_requests for update to authenticated
using(patient_id=(select auth.uid())) with check(patient_id=(select auth.uid()));

create or replace function private.enforce_medlink_home_visit_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_is_doctor boolean; actor_is_patient boolean;
begin
 if old.status is not distinct from new.status then return new; end if;
 select exists(select 1 from public.doctors d where d.id=old.doctor_id and d.user_id=(select auth.uid())) into actor_is_doctor;
 actor_is_patient := old.patient_id=(select auth.uid());
 if not actor_is_doctor and not actor_is_patient and not private.is_platform_admin() then raise exception 'Only home-visit participants may change status'; end if;
 if actor_is_doctor and not private.is_platform_admin() then
  if not ((old.status='requested' and new.status in ('accepted','rejected')) or (old.status='accepted' and new.status='completed')) then raise exception 'Invalid home-visit status transition'; end if;
 elsif actor_is_patient and not private.is_platform_admin() then
  if not (old.status='requested' and new.status='cancelled') then raise exception 'Patients may only cancel requested home visits'; end if;
 end if;
 return new;
end; $$;

