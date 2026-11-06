
create or replace function private.is_platform_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'platform_admin'
  );
$$;
revoke all on function private.is_platform_admin() from public,anon;
grant execute on function private.is_platform_admin() to authenticated;

drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated
using (id=(select auth.uid()) or private.is_platform_admin());
drop policy if exists "platform admin read audit logs" on public.audit_logs;
create policy "platform admin read audit logs" on public.audit_logs for select to authenticated
using (private.is_platform_admin());

drop policy if exists "public read verified doctors" on public.doctors;
create policy "public read verified doctors" on public.doctors for select to anon
using (verification_status='verified');
drop policy if exists "doctor read own record" on public.doctors;
create policy "authenticated read verified or own doctor" on public.doctors for select to authenticated
using (verification_status='verified' or user_id=(select auth.uid()));

drop policy if exists "followup doctor read" on public.follow_up_plans;
drop policy if exists "followup patient read published" on public.follow_up_plans;
create policy "followup participants read" on public.follow_up_plans for select to authenticated
using ((patient_id=(select auth.uid()) and status='published') or exists (
  select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())
));

drop policy if exists "followup events visible to participants" on public.follow_up_events;
drop policy if exists "doctor manage followup events" on public.follow_up_events;
create policy "followup events visible to participants" on public.follow_up_events for select to authenticated
using (exists (
  select 1 from public.follow_up_plans p where p.id=plan_id and (
    (p.patient_id=(select auth.uid()) and p.status='published') or
    exists (select 1 from public.doctors d where d.id=p.doctor_id and d.user_id=(select auth.uid()))
  )
));
create policy "doctor insert followup events" on public.follow_up_events for insert to authenticated
with check (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));
create policy "doctor update followup events" on public.follow_up_events for update to authenticated
using (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())))
with check (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));
create policy "doctor delete followup events" on public.follow_up_events for delete to authenticated
using (exists (select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid())));

create index if not exists appointments_clinic_idx on public.appointments(clinic_id);
create index if not exists audit_logs_actor_idx on public.audit_logs(actor_id);
create index if not exists clinic_members_user_idx on public.clinic_members(user_id);
create index if not exists conversations_doctor_idx on public.conversations(doctor_id);
create index if not exists follow_up_events_plan_idx on public.follow_up_events(plan_id);
create index if not exists follow_up_plans_appointment_idx on public.follow_up_plans(appointment_id);
create index if not exists follow_up_plans_doctor_idx on public.follow_up_plans(doctor_id);
create index if not exists home_visit_requests_doctor_idx on public.home_visit_requests(doctor_id);
create index if not exists home_visit_requests_patient_idx on public.home_visit_requests(patient_id);
create index if not exists messages_sender_idx on public.messages(sender_id);
create index if not exists refund_requests_appointment_idx on public.refund_requests(appointment_id);
create index if not exists refund_requests_requester_idx on public.refund_requests(requester_id);
create index if not exists refund_requests_reviewed_by_idx on public.refund_requests(reviewed_by);

