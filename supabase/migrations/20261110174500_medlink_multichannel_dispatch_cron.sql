-- Invoke the application delivery worker from Supabase Cron.
create extension if not exists pg_net;
create or replace function private.invoke_medlink_multichannel_worker()
returns void language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text;
begin
 select decrypted_secret into endpoint from vault.decrypted_secrets where name='medlink_dispatch_url' limit 1;
 select decrypted_secret into secret from vault.decrypted_secrets where name='medlink_dispatch_secret' limit 1;
 if endpoint is null or secret is null or length(secret)<24 then return; end if;
 perform net.http_post(
  url:=endpoint,
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||secret),
  body:=jsonb_build_object('source','supabase-cron'),
  timeout_milliseconds:=5000
 );
end; $$;
revoke all on function private.invoke_medlink_multichannel_worker() from public,anon,authenticated;
do $$ begin
 if not exists(select 1 from cron.job where jobname='medlink-multichannel-delivery') then
  perform cron.schedule('medlink-multichannel-delivery','* * * * *','select private.invoke_medlink_multichannel_worker();');
 end if;
end $$;
