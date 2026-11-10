-- Secure consent updates and validation for the multichannel delivery worker.
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
end; $$;
revoke all on function public.set_notification_preferences(boolean,boolean,boolean) from public,anon;
grant execute on function public.set_notification_preferences(boolean,boolean,boolean) to authenticated;

create or replace function public.validate_medlink_notification_dispatch_secret(p_secret text)
returns boolean language sql stable security definer set search_path='' as $$
 select p_secret is not null and exists(select 1 from vault.decrypted_secrets where name='medlink_dispatch_secret' and decrypted_secret=p_secret);
$$;
revoke all on function public.validate_medlink_notification_dispatch_secret(text) from public,anon,authenticated;
grant execute on function public.validate_medlink_notification_dispatch_secret(text) to service_role;
