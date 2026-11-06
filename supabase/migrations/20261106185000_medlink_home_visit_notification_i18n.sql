-- Localize home-visit lifecycle notifications for patients and professionals.
create or replace function private.notify_medlink_home_visit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient uuid;
  language_code text;
  title_text text;
  body_text text;
begin
  if tg_op='INSERT' then
    if new.doctor_id is not null then
      select user_id into recipient from public.doctors where id=new.doctor_id;
    end if;
    if recipient is not null then
      select preferred_language into language_code from public.profiles where id=recipient;
      title_text:=case language_code when 'ar' then 'طلب زيارة منزلية جديد' when 'en' then 'New home visit request' else 'Nouvelle demande de visite à domicile' end;
      body_text:=case language_code when 'ar' then 'تم إرسال طلب زيارة منزلية إليك. يرجى مراجعته.' when 'en' then 'A patient has sent you a home visit request. Please review it.' else 'Une demande de visite à domicile vous a été adressée. Veuillez l’examiner.' end;
      insert into public.notifications(user_id,title,body,category) values(recipient,title_text,body_text,'home_visit');
    end if;
  elsif old.status is distinct from new.status then
    select preferred_language into language_code from public.profiles where id=new.patient_id;
    title_text:=case language_code when 'ar' then 'تحديث طلب الزيارة المنزلية' when 'en' then 'Home visit request update' else 'Mise à jour de votre visite à domicile' end;
    body_text:=case new.status::text
      when 'accepted' then case language_code when 'ar' then 'تم قبول طلب الزيارة المنزلية.' when 'en' then 'Your home visit request has been accepted.' else 'Votre demande de visite à domicile a été acceptée.' end
      when 'rejected' then case language_code when 'ar' then 'تعذّر قبول طلب الزيارة المنزلية.' when 'en' then 'Your home visit request was declined.' else 'Votre demande de visite à domicile a été refusée.' end
      when 'cancelled' then case language_code when 'ar' then 'تم إلغاء طلب الزيارة المنزلية.' when 'en' then 'Your home visit request was cancelled.' else 'Votre demande de visite à domicile a été annulée.' end
      when 'completed' then case language_code when 'ar' then 'تم إنهاء الزيارة المنزلية.' when 'en' then 'Your home visit has been completed.' else 'Votre visite à domicile est terminée.' end
      else case language_code when 'ar' then 'تم تحديث حالة طلب الزيارة المنزلية.' when 'en' then 'Your home visit request status has changed.' else 'Le statut de votre demande de visite à domicile a changé.' end
    end;
    insert into public.notifications(user_id,title,body,category) values(new.patient_id,title_text,body_text,'home_visit');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_medlink_home_visit() from public,anon,authenticated;
