alter function private.doctor_has_feature(uuid,text) security invoker;
drop policy if exists "doctor create consultation draft" on public.consultation_records;
create policy "doctor create consultation draft" on public.consultation_records for insert to authenticated
with check(status='draft' and exists(select 1 from public.appointments a join public.doctors d on d.id=a.doctor_id
where a.id=consultation_records.appointment_id and a.doctor_id=consultation_records.doctor_id
and a.patient_id=consultation_records.patient_id and a.status='completed'
and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'consultations')));