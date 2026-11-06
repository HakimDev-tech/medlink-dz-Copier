-- MedLink DZ Phase 6 runtime: immutable consultation records, lifecycle notifications and in-database reminder dispatch.
create extension if not exists pg_cron with schema pg_catalog;

create or replace function private.enforce_consultation_record_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if old.status = 'published' then
      raise exception 'Published consultation records are immutable';
    end if;
    if new.appointment_id is distinct from old.appointment_id
       or new.doctor_id is distinct from old.doctor_id
       or new.patient_id is distinct from old.patient_id then
      raise exception 'Consultation participants and appointment cannot be changed';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_consultation_record_lifecycle() from public, anon, authenticated;
drop trigger if exists medlink_enforce_consultation_record_lifecycle on public.consultation_records;
create trigger medlink_enforce_consultation_record_lifecycle
before update on public.consultation_records
for each row execute function private.enforce_consultation_record_lifecycle();

create or replace function private.notify_appointment_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  doctor_user_id uuid;
  patient_lang text;
  doctor_lang text;
  title_text text;
  body_text text;
begin
  select d.user_id into doctor_user_id from public.doctors d where d.id = new.doctor_id;
  select preferred_language into patient_lang from public.profiles where id = new.patient_id;
  select preferred_language into doctor_lang from public.profiles where id = doctor_user_id;

  if tg_op = 'INSERT' then
    if doctor_user_id is not null then
      title_text := case doctor_lang when 'ar' then 'طلب موعد جديد' when 'en' then 'New appointment request' else 'Nouvelle demande de rendez-vous' end;
      body_text := case doctor_lang when 'ar' then 'لديك طلب موعد جديد لمراجعته.' when 'en' then 'A patient has requested an appointment. Please review it.' else 'Un patient a demandé un rendez-vous. Veuillez examiner la demande.' end;
      insert into public.notifications(user_id,title,body,category)
      values(doctor_user_id,title_text,body_text,'appointment');
    end if;
    return new;
  end if;

  if old.status is distinct from new.status then
    title_text := case patient_lang
      when 'ar' then 'تحديث طلب الموعد'
      when 'en' then 'Appointment update'
      else 'Mise à jour du rendez-vous' end;
    body_text := case new.status::text
      when 'confirmed' then case patient_lang when 'ar' then 'تم تأكيد موعدك.' when 'en' then 'Your appointment has been confirmed.' else 'Votre rendez-vous a été confirmé.' end
      when 'rejected' then case patient_lang when 'ar' then 'تعذّر قبول طلب موعدك.' when 'en' then 'Your appointment request was declined.' else 'Votre demande de rendez-vous a été refusée.' end
      when 'cancelled' then case patient_lang when 'ar' then 'تم إلغاء الموعد.' when 'en' then 'The appointment was cancelled.' else 'Le rendez-vous a été annulé.' end
      when 'completed' then case patient_lang when 'ar' then 'تم إنهاء الموعد. يمكنك الاطلاع على تقرير الاستشارة عند نشره.' when 'en' then 'The appointment is complete. Your consultation record will appear when published.' else 'Le rendez-vous est terminé. Le compte rendu sera disponible après publication.' end
      else case patient_lang when 'ar' then 'تم تحديث حالة موعدك.' when 'en' then 'Your appointment status has changed.' else 'Le statut de votre rendez-vous a changé.' end
    end;
    insert into public.notifications(user_id,title,body,category)
    values(new.patient_id,title_text,body_text,'appointment');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_appointment_lifecycle() from public, anon, authenticated;
drop trigger if exists medlink_notify_appointment_lifecycle on public.appointments;
create trigger medlink_notify_appointment_lifecycle
after insert or update of status on public.appointments
for each row execute function private.notify_appointment_lifecycle();

create or replace function private.notify_consultation_published()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare lang text; title_text text; body_text text;
begin
  if old.status is distinct from new.status and new.status = 'published' then
    select preferred_language into lang from public.profiles where id = new.patient_id;
    title_text := case lang when 'ar' then 'تقرير الاستشارة متاح' when 'en' then 'Consultation record available' else 'Compte rendu disponible' end;
    body_text := case lang when 'ar' then 'نشر المهني تقرير الاستشارة والتعليمات الموجهة إليك.' when 'en' then 'Your healthcare professional published the consultation record and patient instructions.' else 'Votre professionnel a publié le compte rendu et les consignes qui vous sont destinées.' end;
    insert into public.notifications(user_id,title,body,category)
    values(new.patient_id,title_text,body_text,'consultation');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_consultation_published() from public, anon, authenticated;
drop trigger if exists medlink_notify_consultation_published on public.consultation_records;
create trigger medlink_notify_consultation_published
after update of status on public.consultation_records
for each row execute function private.notify_consultation_published();

-- In-app notification dispatcher. No external secret or third-party transport is needed.
create or replace function private.dispatch_medlink_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  job record;
  event_label text;
  language_code text;
  notification_title text;
  notification_body text;
  processed integer := 0;
begin
  for job in
    select s.id, s.event_id, s.user_id, s.due_at, s.attempts + 1 as attempt, s.max_attempts,
           p.status as plan_status
    from public.notification_schedules s
    join public.follow_up_plans p on p.id = s.plan_id
    where s.status in ('pending','failed')
      and s.due_at <= now()
      and s.next_attempt_at <= now()
      and s.attempts < s.max_attempts
    order by s.due_at asc
    for update of s skip locked
    limit 50
  loop
    update public.notification_schedules
      set status = 'processing', attempts = job.attempt, updated_at = now()
      where id = job.id;

    begin
      if job.plan_status <> 'published' then
        update public.notification_schedules set status='cancelled',updated_at=now() where id=job.id;
        insert into public.notification_logs(job_id,attempt,outcome,detail)
        values(job.id,job.attempt,'skipped','plan_not_published');
      else
        select e.label, coalesce(pr.preferred_language,'fr')
          into event_label, language_code
        from public.follow_up_events e
        join public.profiles pr on pr.id=job.user_id
        where e.id=job.event_id;

        if event_label is null then
          raise exception 'reminder_context_unavailable';
        end if;

        notification_title := case language_code
          when 'ar' then 'تذكير بالمتابعة'
          when 'en' then 'Follow-up reminder'
          else 'Rappel de suivi' end;
        notification_body := case language_code
          when 'ar' then 'تذكير من برنامج المتابعة: ' || event_label
          when 'en' then 'Reminder from your follow-up plan: ' || event_label
          else 'Rappel prévu dans votre programme de suivi : ' || event_label end;

        insert into public.notifications(user_id,title,body,category,scheduled_for,sent_at,source_job_id)
        values(job.user_id,notification_title,notification_body,'follow_up',job.due_at,now(),job.id)
        on conflict (source_job_id) do nothing;

        update public.notification_schedules
          set status='sent',last_error=null,updated_at=now()
          where id=job.id;
        insert into public.notification_logs(job_id,attempt,outcome)
        values(job.id,job.attempt,'sent');
      end if;
    exception when others then
      update public.notification_schedules
        set status='failed',
            last_error='dispatch_failed',
            next_attempt_at=now() + make_interval(secs => least(3600,30 * power(2,greatest(0,job.attempt - 1))::integer)),
            updated_at=now()
        where id=job.id;
      insert into public.notification_logs(job_id,attempt,outcome,detail)
      values(job.id,job.attempt,case when job.attempt >= job.max_attempts then 'failed' else 'retry' end,'dispatch_failed');
    end;
    processed := processed + 1;
  end loop;
  return processed;
end;
$$;
revoke all on function private.dispatch_medlink_notifications() from public, anon, authenticated;

do $$
begin
  if not exists(select 1 from cron.job where jobname='medlink-notification-dispatch') then
    perform cron.schedule('medlink-notification-dispatch','* * * * *',
      'select private.dispatch_medlink_notifications();');
  end if;
end;
$$;
