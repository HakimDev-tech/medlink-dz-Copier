revoke update on public.care_agent_escalations from authenticated;
grant update(status,resolved_at,patient_message,message_locale) on public.care_agent_escalations to authenticated;
drop policy if exists "patient attaches own care agent handoff" on public.care_agent_escalations;
create policy "patient attaches own care agent handoff"
on public.care_agent_escalations for update to authenticated
using(patient_id=(select auth.uid()) and status='open')
with check(patient_id=(select auth.uid()) and status='open');
drop function if exists public.attach_care_agent_handoff(uuid,text,text);