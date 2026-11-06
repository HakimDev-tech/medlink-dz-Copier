create index if not exists doctor_verification_documents_doctor_idx
  on public.doctor_verification_documents(doctor_id);
create index if not exists doctor_verification_documents_reviewed_by_idx
  on public.doctor_verification_documents(reviewed_by);
create index if not exists doctor_verification_documents_uploaded_by_idx
  on public.doctor_verification_documents(uploaded_by);
