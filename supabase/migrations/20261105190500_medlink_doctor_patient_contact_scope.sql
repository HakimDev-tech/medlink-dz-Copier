drop policy if exists "doctor read connected patient profile" on public.profiles;
create policy "doctor read connected patient profile" on public.profiles for select to authenticated
using (
 exists(select 1 from public.appointments a join public.doctors d on d.id=a.doctor_id where a.patient_id=profiles.id and d.user_id=(select auth.uid()))
 or exists(select 1 from public.conversations c join public.doctors d on d.id=c.doctor_id where c.patient_id=profiles.id and d.user_id=(select auth.uid()))
);