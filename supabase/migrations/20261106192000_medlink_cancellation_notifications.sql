-- Notify the assigned professional when a patient cancels an appointment or home visit.
create or replace function private.notify_appointment_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
declare doctor_user_id uuid; patient_lang text; doctor_lang text; title_text text; body_text text;
begin
 select d.user_id into doctor_user_id from public.doctors d where d.id=new.doctor_id;
 select preferred_language into patient_lang from public.profiles where id=new.patient_id;
 select preferred_language into doctor_lang from public.profiles where id=doctor_user_id;
 if tg_op='INSERT' then
  if doctor_user_id is not null then
   title_text:=case doctor_lang when 'ar' then 'طلب موعد جديد' when 'en' then 'New appointment request' else 'Nouvelle demande de rendez-vous' end;
   body_text:=case doctor_lang when 'ar' then 'لديك طلب موعد جديد لمراجعته.' when 'en' then 'A patient has requested an appointment. Please review it.' else 'Un patient a demandé un rendez-vous. Veuillez examiner la demande.' end;
   insert into public.notifications(user_id,title,body,category) values(doctor_user_id,title_text,body_text,'appointment');
  end if;
  return new;
 end if;
 if old.status is distinct from new.status then
  title_text:=case patient_lang when 'ar' then 'تحديث طلب الموعد' when 'en' then 'Appointment update' else 'Mise à jour du rendez-vous' end;
  body_text:=case new.status::text
   when 'confirmed' then case patient_lang when 'ar' then 'تم تأكيد موعدك.' when 'en' then 'Your appointment has been confirmed.' else 'Votre rendez-vous a été confirmé.' end
   when 'rejected' then case patient_lang when 'ar' then 'تعذّر قبول طلب موعدك.' when 'en' then 'Your appointment request was declined.' else 'Votre demande de rendez-vous a été refusée.' end
   when 'cancelled' then case patient_lang when 'ar' then 'تم إلغاء الموعد.' when 'en' then 'The appointment was cancelled.' else 'Le rendez-vous a été annulé.' end
   when 'completed' then case patient_lang when 'ar' then 'تم إنهاء الموعد. يمكنك الاطلاع على تقرير الاستشارة عند نشره.' when 'en' then 'The appointment is complete. Your consultation record will appear when published.' else 'Le rendez-vous est terminé. Le compte rendu sera disponible après publication.' end
   else case patient_lang when 'ar' then 'تم تحديث حالة موعدك.' when 'en' then 'Your appointment status has changed.' else 'Le statut de votre rendez-vous a changé.' end end;
  insert into public.notifications(user_id,title,body,category) values(new.patient_id,title_text,body_text,'appointment');
  if new.status='cancelled' and doctor_user_id is not null then
   title_text:=case doctor_lang when 'ar' then 'تم إلغاء موعد' when 'en' then 'Appointment cancelled' else 'Rendez-vous annulé' end;
   body_text:=case doctor_lang when 'ar' then 'ألغى المريض موعداً كان مسجلاً لديك.' when 'en' then 'A patient cancelled an appointment on your schedule.' else 'Un patient a annulé un rendez-vous de votre agenda.' end;
   insert into public.notifications(user_id,title,body,category) values(doctor_user_id,title_text,body_text,'appointment');
  end if;
 end if;
 return new;
end; $$;
revoke all on function private.notify_appointment_lifecycle() from public,anon,authenticated;

create or replace function private.notify_medlink_home_visit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; doctor_user_id uuid; language_code text; doctor_language text; title_text text; body_text text;
begin
 if tg_op='INSERT' then
  if new.doctor_id is not null then select user_id into recipient from public.doctors where id=new.doctor_id; end if;
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
   else case language_code when 'ar' then 'تم تحديث حالة طلب الزيارة المنزلية.' when 'en' then 'Your home visit request status has changed.' else 'Le statut de votre demande de visite à domicile a changé.' end end;
  insert into public.notifications(user_id,title,body,category) values(new.patient_id,title_text,body_text,'home_visit');
  if new.status='cancelled' and new.doctor_id is not null then
   select user_id into doctor_user_id from public.doctors where id=new.doctor_id;
   select preferred_language into doctor_language from public.profiles where id=doctor_user_id;
   title_text:=case doctor_language when 'ar' then 'تم إلغاء زيارة منزلية' when 'en' then 'Home visit cancelled' else 'Visite à domicile annulée' end;
   body_text:=case doctor_language when 'ar' then 'ألغى المريض طلب الزيارة المنزلية.' when 'en' then 'The patient cancelled the home visit request.' else 'Le patient a annulé la demande de visite à domicile.' end;
   insert into public.notifications(user_id,title,body,category) values(doctor_user_id,title_text,body_text,'home_visit');
  end if;
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_home_visit() from public,anon,authenticated;
