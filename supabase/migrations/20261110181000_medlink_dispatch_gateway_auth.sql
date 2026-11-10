create or replace function private.invoke_medlink_multichannel_worker()
returns void language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text; api_key text;
begin
 select decrypted_secret into endpoint from vault.decrypted_secrets where name='medlink_dispatch_url' limit 1;
 select decrypted_secret into secret from vault.decrypted_secrets where name='medlink_dispatch_secret' limit 1;
 select decrypted_secret into api_key from vault.decrypted_secrets where name='medlink_dispatch_apikey' limit 1;
 if endpoint is null or secret is null or api_key is null or length(secret)<24 then return; end if;
 perform net.http_post(url:=endpoint,headers:=jsonb_build_object('Content-Type','application/json','apikey',api_key,'x-medlink-dispatch-secret',secret),body:=jsonb_build_object('source','supabase-cron'),timeout_milliseconds:=5000);
end; $$;
revoke all on function private.invoke_medlink_multichannel_worker() from public,anon,authenticated;