drop trigger if exists medlink_prevent_followup_event_reassignment on public.follow_up_events;
create trigger medlink_prevent_followup_event_reassignment
before update of plan_id,event_at on public.follow_up_events
for each row execute function private.prevent_followup_event_reassignment();
