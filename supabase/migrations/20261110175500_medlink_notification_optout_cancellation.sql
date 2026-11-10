create or replace function public.set_notification_preferences(p_email boolean,p_sms boolean,p_whatsapp boolean)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); account auth.users%rowtype; stored_phone text;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 select * into account from auth.users where id=uid;
 select regexp_replace(coalesce(phone,''),'[[:space:]().-]','','g') into stored_phone from public.profiles where id=uid;
 if p_email and (account.email is null or account.email_confirmed_at is null) then raise exception 'email_not_verified'; end if;
 if (p_sms or p_whatsapp) and (account.phone is null or account.phone_confirmed_at is null
   or stored_phone is distinct from regexp_replace(account.phone,'[[:space:]().-]','','g')
   or stored_phone !~ '^\+[1-9][0-9]{7,14}$') then raise exception 'phone_not_verified'; end if;
 insert into public.notification_preferences(user_id,email_enabled,sms_enabled,whatsapp_enabled,email_consent_at,sms_consent_at,whatsapp_consent_at,updated_at)
 values(uid,p_email,p_sms,p_whatsapp,case when p_email then now() end,case when p_sms then now() end,case when p_whatsapp then now() end,now())
 on conflict(user_id) do update set email_enabled=excluded.email_enabled,sms_enabled=excluded.sms_enabled,whatsapp_enabled=excluded.whatsapp_enabled,
 email_consent_at=case when excluded.email_enabled then coalesce(public.notification_preferences.email_consent_at,now()) else null end,
 sms_consent_at=case when excluded.sms_enabled then coalesce(public.notification_preferences.sms_consent_at,now()) else null end,
 whatsapp_consent_at=case when excluded.whatsapp_enabled then coalesce(public.notification_preferences.whatsapp_consent_at,now()) else null end,
 updated_at=now();
 update public.notification_delivery_jobs set status='cancelled',locked_at=null,updated_at=now()
 where user_id=uid and status='pending' and ((channel='email' and not p_email) or (channel='sms' and not p_sms) or (channel='whatsapp' and not p_whatsapp));
end; $$;