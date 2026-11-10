-- MedLink DZ multichannel notification delivery
create table if not exists public.notification_preferences (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 email_enabled boolean not null default false,
 sms_enabled boolean not null default false,
 whatsapp_enabled boolean not null default false,
 email_consent_at timestamptz,
 sms_consent_at timestamptz,
 whatsapp_consent_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (email_enabled = (email_consent_at is not null)),
 check (sms_enabled = (sms_consent_at is not null)),
 check (whatsapp_enabled = (whatsapp_consent_at is not null))
);
alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from anon,authenticated;
grant select on public.notification_preferences to authenticated;
create policy "users read own notification preferences"
on public.notification_preferences for select to authenticated
using(user_id=(select auth.uid()));

create table if not exists public.notification_delivery_jobs (
 id uuid primary key default gen_random_uuid(),
 notification_id uuid not null references public.notifications(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 channel text not null check(channel in ('email','sms','whatsapp')),
 status text not null default 'pending' check(status in ('pending','processing','sent','failed','cancelled')),
 attempts integer not null default 0 check(attempts>=0),
 max_attempts integer not null default 5 check(max_attempts between 1 and 10),
 next_attempt_at timestamptz not null default now(),
 locked_at timestamptz,
 provider_message_id text,
 last_error text,
 idempotency_key text not null unique,
 sent_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(notification_id,channel)
);
create index if not exists notification_delivery_due_idx
on public.notification_delivery_jobs(status,next_attempt_at,created_at);
create index if not exists notification_delivery_user_idx
on public.notification_delivery_jobs(user_id,created_at desc);
alter table public.notification_delivery_jobs enable row level security;
revoke all on public.notification_delivery_jobs from anon,authenticated;
grant select on public.notification_delivery_jobs to authenticated;
create policy "users read own notification delivery status"
on public.notification_delivery_jobs for select to authenticated
using(user_id=(select auth.uid()));

create table if not exists public.notification_delivery_logs (
 id bigint generated always as identity primary key,
 job_id uuid not null references public.notification_delivery_jobs(id) on delete cascade,
 attempt integer not null,
 outcome text not null check(outcome in ('sent','retry','failed','skipped')),
 error_code text,
 provider_message_id text,
 processed_at timestamptz not null default now()
);
alter table public.notification_delivery_logs enable row level security;
revoke all on public.notification_delivery_logs from public,anon,authenticated;

create or replace function private.enqueue_notification_delivery()
returns trigger language plpgsql security definer set search_path='' as $$
declare prefs public.notification_preferences%rowtype;
begin
 select * into prefs from public.notification_preferences where user_id=new.user_id;
 if not found then return new; end if;
 if prefs.email_enabled and prefs.email_consent_at is not null then
  insert into public.notification_delivery_jobs(notification_id,user_id,channel,idempotency_key)
  values(new.id,new.user_id,'email',new.id::text||':email') on conflict(notification_id,channel) do nothing;
 end if;
 if prefs.sms_enabled and prefs.sms_consent_at is not null then
  insert into public.notification_delivery_jobs(notification_id,user_id,channel,idempotency_key)
  values(new.id,new.user_id,'sms',new.id::text||':sms') on conflict(notification_id,channel) do nothing;
 end if;
 if prefs.whatsapp_enabled and prefs.whatsapp_consent_at is not null then
  insert into public.notification_delivery_jobs(notification_id,user_id,channel,idempotency_key)
  values(new.id,new.user_id,'whatsapp',new.id::text||':whatsapp') on conflict(notification_id,channel) do nothing;
 end if;
 return new;
end; $$;
revoke all on function private.enqueue_notification_delivery() from public,anon,authenticated;
drop trigger if exists medlink_enqueue_notification_delivery on public.notifications;
create trigger medlink_enqueue_notification_delivery after insert on public.notifications
for each row execute function private.enqueue_notification_delivery();

create or replace function public.claim_notification_delivery_jobs(p_batch_size integer default 25)
returns table(id uuid,notification_id uuid,user_id uuid,channel text,attempt integer,idempotency_key text)
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then
  raise exception 'service_role_required';
 end if;
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
