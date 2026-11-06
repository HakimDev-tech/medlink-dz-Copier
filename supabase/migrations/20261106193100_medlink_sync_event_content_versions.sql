-- Keep reminder rows aligned with schedule versions even when reminder wording changes.
drop trigger if exists medlink_sync_followup_event_schedule on public.follow_up_events;
create trigger medlink_sync_followup_event_schedule
after insert or update of event_at,label,instruction,plan_id or delete on public.follow_up_events
for each row execute function private.sync_followup_event_schedule();
