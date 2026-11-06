
-- Tighten column-level privileges: RLS filters rows, grants restrict mutable fields.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, preferred_language) on public.profiles to authenticated;

revoke update on public.appointments from authenticated;
grant update (status, starts_at, reason, patient_note) on public.appointments to authenticated;

revoke update on public.follow_up_plans from authenticated;
grant update (title, instructions, starts_on, ends_on, status, approved_at) on public.follow_up_plans to authenticated;

revoke update on public.home_visit_requests from authenticated;
grant update (status, requested_for, reason) on public.home_visit_requests to authenticated;

revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- No authenticated client may edit the message sender or content after sending.
revoke update, delete on public.messages from authenticated;

