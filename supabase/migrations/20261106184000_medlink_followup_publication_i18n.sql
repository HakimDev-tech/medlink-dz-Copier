-- Localize the patient notification sent when a professional publishes a care plan.
create or replace function private.notify_medlink_followup_published()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  language_code text;
  title_text text;
  body_text text;
begin
  if old.status is distinct from new.status and new.status='published' then
    select preferred_language into language_code
    from public.profiles where id=new.patient_id;
    title_text:=case language_code
      when 'ar' then 'تم نشر برنامج متابعة جديد'
      when 'en' then 'New follow-up plan published'
      else 'Nouveau programme de suivi publié' end;
    body_text:=case language_code
      when 'ar' then 'نشر المهني برنامج المتابعة المعتمد والتعليمات والتذكيرات المرتبطة به.'
      when 'en' then 'Your healthcare professional published an approved follow-up plan with its instructions and reminders.'
      else 'Votre professionnel a publié un programme de suivi validé, avec ses consignes et ses rappels.' end;
    insert into public.notifications(user_id,title,body,category)
    values(new.patient_id,title_text,body_text,'follow_up');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_medlink_followup_published() from public,anon,authenticated;
