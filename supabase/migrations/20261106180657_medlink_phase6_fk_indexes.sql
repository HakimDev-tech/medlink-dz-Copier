create index if not exists care_agent_escalations_patient_idx on public.care_agent_escalations(patient_id);
create index if not exists care_agent_escalations_plan_idx on public.care_agent_escalations(plan_id);
create index if not exists care_agent_runs_actor_idx on public.care_agent_runs(actor_id);
create index if not exists consultation_private_notes_doctor_idx on public.consultation_private_notes(doctor_id);
create index if not exists notification_logs_job_idx on public.notification_logs(job_id);
create index if not exists notification_schedules_plan_idx on public.notification_schedules(plan_id);
create index if not exists notification_schedules_user_idx on public.notification_schedules(user_id);
