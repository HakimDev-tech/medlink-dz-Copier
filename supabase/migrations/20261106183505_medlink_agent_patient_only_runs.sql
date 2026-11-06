drop policy if exists "participants record own care agent runs" on public.care_agent_runs;
create policy "patient records own care agent runs"
on public.care_agent_runs
for insert
to authenticated
with check (
  actor_id=(select auth.uid())
  and exists(
    select 1 from public.follow_up_plans p
    where p.id=care_agent_runs.plan_id
      and p.patient_id=(select auth.uid())
      and p.status='published'
  )
);
