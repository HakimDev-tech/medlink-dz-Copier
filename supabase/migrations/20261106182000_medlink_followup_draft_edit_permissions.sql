-- Allow the assigned professional to edit only the content and date fields of an unpublished follow-up draft.
grant update(title,instructions,starts_on,ends_on) on public.follow_up_plans to authenticated;
