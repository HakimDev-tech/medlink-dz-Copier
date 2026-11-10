create or replace function public.claim_notification_delivery_jobs(p_batch_size integer default 25)
returns table(id uuid,notification_id uuid,user_id uuid,channel text,attempt integer,idempotency_key text)
language plpgsql security definer set search_path='' as $$
begin
 return query
 with due as (
  select j.id from public.notification_delivery_jobs j
  where ((j.status='pending' and j.next_attempt_at<=now())
     or (j.status='processing' and j.locked_at<now()-interval '5 minutes'))
    and j.attempts<j.max_attempts
  order by j.created_at
  for update skip locked
  limit greatest(1,least(coalesce(p_batch_size,25),100))
 )
 update public.notification_delivery_jobs j
 set status='processing',attempts=j.attempts+1,locked_at=now(),updated_at=now()
 from due where j.id=due.id
 returning j.id,j.notification_id,j.user_id,j.channel,j.attempts,j.idempotency_key;
end; $$;
revoke all on function public.claim_notification_delivery_jobs(integer) from public,anon,authenticated;
grant execute on function public.claim_notification_delivery_jobs(integer) to service_role;
create index if not exists notification_delivery_logs_job_id_idx on public.notification_delivery_logs(job_id);
