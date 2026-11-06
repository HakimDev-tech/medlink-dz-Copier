grant select,insert on public.doctor_verification_documents to authenticated; grant update(status,review_note,reviewed_by,reviewed_at) on public.doctor_verification_documents to authenticated;
