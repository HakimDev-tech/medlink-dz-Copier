-- Keep the plan version and patient notification stream in sync with post-publication schedule edits.
create or replace function private.bump_followup_schedule_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_plan_id uuid;
  target_patient_id uuid;
  target_status text;
  language_code text;
  title_text text;
  body_text text;
begin
  target_plan_id := case when tg_op='DELETE' then old.plan_id else new.plan_id end;
  select p.patient_id,p.status into target_patient_id,target_status
  from public.follow_up_plans p where p.id=target_plan_id;

  if target_status='published' then
    update public.follow_up_plans
      set schedule_version=schedule_version+1
      where id=target_plan_id;

    select preferred_language into language_code
    from public.profiles where id=target_patient_id;

    title_text:=case language_code
      when 'ar' then 'تم تحديث برنامج المتابعة'
      when 'en' then 'Follow-up schedule updated'
      else 'Programme de suivi mis à jour' end;
    body_text:=case language_code
      when 'ar' then 'قام المهني بتحديث أحد التذكيرات في برنامج المتابعة المعتمد.'
      when 'en' then 'Your healthcare professional updated a reminder in your approved follow-up plan.'
      else 'Votre professionnel a modifié un rappel dans votre programme de suivi validé.' end;
    insert into public.notifications(user_id,title,body,category)
    values(target_patient_id,title_text,body_text,'follow_up');
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.bump_followup_schedule_version() from public,anon,authenticated;
drop trigger if exists medlink_00_bump_followup_schedule_version on public.follow_up_events;
create trigger medlink_00_bump_followup_schedule_version
after insert or update of event_at,label,instruction,plan_id or delete on public.follow_up_events
for each row execute function private.bump_followup_schedule_version();

create or replace function private.prevent_followup_event_reassignment()
returns trigger language plpgsql set search_path='' as $$
begin
  if new.plan_id is distinct from old.plan_id then
    raise exception 'A reminder cannot be moved to another care plan';
  end if;
  return new;
end;
$$;
revoke all on function private.prevent_followup_event_reassignment() from public,anon,authenticated;
drop trigger if exists medlink_prevent_followup_event_reassignment on public.follow_up_events;
create trigger medlink_prevent_followup_event_reassignment
before update of plan_id on public.follow_up_events
for each row execute function private.prevent_followup_event_reassignment();

