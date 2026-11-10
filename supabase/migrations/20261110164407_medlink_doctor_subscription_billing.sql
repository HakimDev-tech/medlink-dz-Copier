-- Subscription catalog, lifecycle, invoices and payment ledger.
create table if not exists public.subscription_plans(id uuid primary key default gen_random_uuid(),code text not null unique check(code in('manual','ai','premium')),name text not null,description text not null default '',amount integer not null check(amount>0),currency text not null default 'DZD' check(currency='DZD'),interval_unit text not null default 'month' check(interval_unit='month'),interval_count integer not null default 1 check(interval_count>0),features jsonb not null default '{}'::jsonb,is_active boolean not null default true,sort_order integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
insert into public.subscription_plans(code,name,description,amount,features,sort_order) values
('manual','Pack Manuel','Gestion manuelle des rendez-vous, consultations et suivis.',2500,'{"appointments":true,"consultations":true,"manual_follow_up":true,"reminders":true,"messaging":true,"ai_assistant":false,"ai_plan_drafting":false,"advanced_follow_up":false}',1),
('ai','Pack AI','Assistant patient encadré par les consignes publiées.',5000,'{"appointments":true,"consultations":true,"manual_follow_up":true,"reminders":true,"messaging":true,"ai_assistant":true,"ai_plan_drafting":false,"advanced_follow_up":false}',2),
('premium','Pack AI Premium','Préparation assistée des programmes avec validation médicale.',8000,'{"appointments":true,"consultations":true,"manual_follow_up":true,"reminders":true,"messaging":true,"ai_assistant":true,"ai_plan_drafting":true,"advanced_follow_up":true}',3)
on conflict(code) do update set name=excluded.name,description=excluded.description,amount=excluded.amount,features=excluded.features,is_active=true,sort_order=excluded.sort_order,updated_at=now();
create table if not exists public.doctor_subscriptions(id uuid primary key default gen_random_uuid(),doctor_id uuid not null references public.doctors(id) on delete restrict,plan_id uuid not null references public.subscription_plans(id) on delete restrict,status text not null default 'pending' check(status in('pending','active','past_due','cancelled')),current_period_start timestamptz not null,current_period_end timestamptz not null,cancel_at_period_end boolean not null default false,cancelled_at timestamptz,activated_at timestamptz,ended_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(current_period_end>current_period_start));
create index if not exists doctor_subscriptions_doctor_status_idx on public.doctor_subscriptions(doctor_id,status,current_period_end desc);
create unique index if not exists doctor_subscriptions_one_pending_per_doctor_idx on public.doctor_subscriptions(doctor_id) where status='pending';
create table if not exists public.subscription_invoices(id uuid primary key default gen_random_uuid(),invoice_number text not null unique,doctor_id uuid not null references public.doctors(id) on delete restrict,subscription_id uuid references public.doctor_subscriptions(id) on delete set null,plan_code text not null check(plan_code in('manual','ai','premium')),plan_name text not null,amount integer not null check(amount>0),currency text not null default 'DZD' check(currency='DZD'),status text not null default 'pending' check(status in('pending','paid','void','overdue')),period_start timestamptz not null,period_end timestamptz not null,issued_at timestamptz not null default now(),due_at timestamptz,paid_at timestamptz,created_at timestamptz not null default now(),check(period_end>period_start));
create index if not exists subscription_invoices_doctor_date_idx on public.subscription_invoices(doctor_id,issued_at desc);
create table if not exists public.subscription_payments(id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.subscription_invoices(id) on delete restrict,doctor_id uuid not null references public.doctors(id) on delete restrict,provider text not null,provider_reference text,amount integer not null check(amount>0),currency text not null default 'DZD' check(currency='DZD'),status text not null default 'pending' check(status in('pending','paid','failed','refunded')),provider_payload jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),paid_at timestamptz,unique(provider,provider_reference));
create index if not exists subscription_payments_invoice_idx on public.subscription_payments(invoice_id,created_at desc);
alter table public.subscription_plans enable row level security;alter table public.doctor_subscriptions enable row level security;alter table public.subscription_invoices enable row level security;alter table public.subscription_payments enable row level security;
create policy "active subscription plans are readable" on public.subscription_plans for select to anon,authenticated using(is_active=true);
create policy "doctors read own subscriptions" on public.doctor_subscriptions for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or (select auth.jwt()->'app_metadata'->>'role')='platform_admin');
create policy "doctors read own invoices" on public.subscription_invoices for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or (select auth.jwt()->'app_metadata'->>'role')='platform_admin');
create policy "doctors read own payments" on public.subscription_payments for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or (select auth.jwt()->'app_metadata'->>'role')='platform_admin');
revoke all on public.subscription_plans from anon,authenticated;grant select on public.subscription_plans to anon,authenticated;
revoke all on public.doctor_subscriptions from anon,authenticated;grant select on public.doctor_subscriptions to authenticated;
revoke all on public.subscription_invoices from anon,authenticated;grant select on public.subscription_invoices to authenticated;
revoke all on public.subscription_payments from anon,authenticated;grant select on public.subscription_payments to authenticated;
create or replace function public.request_doctor_subscription(p_plan_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();d uuid;p public.subscription_plans%rowtype;s uuid;i uuid;st timestamptz:=now();en timestamptz;num text;
begin
if u is null then raise exception 'authentication_required';end if;
select id into d from public.doctors where user_id=u and verification_status not in('rejected','suspended') limit 1;
if d is null then raise exception 'professional_profile_required';end if;
select * into p from public.subscription_plans where code=p_plan_code and is_active;
if not found then raise exception 'plan_not_available';end if;
if exists(select 1 from public.doctor_subscriptions where doctor_id=d and status='pending') then raise exception 'pending_subscription_exists';end if;
en:=st+make_interval(months=>p.interval_count);
insert into public.doctor_subscriptions(doctor_id,plan_id,status,current_period_start,current_period_end) values(d,p.id,'pending',st,en) returning id into s;
num:='MLD-'||to_char(st at time zone 'Africa/Algiers','YYYYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
insert into public.subscription_invoices(invoice_number,doctor_id,subscription_id,plan_code,plan_name,amount,currency,status,period_start,period_end,due_at) values(num,d,s,p.code,p.name,p.amount,p.currency,'pending',st,en,st+interval '7 days') returning id into i;
return jsonb_build_object('subscription_id',s,'invoice_id',i,'invoice_number',num,'status','pending','amount',p.amount,'currency',p.currency,'period_end',en);
end $$;
revoke all on function public.request_doctor_subscription(text) from public,anon;grant execute on function public.request_doctor_subscription(text) to authenticated;
create or replace function public.request_cancel_doctor_subscription() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();d uuid;s uuid;
begin if u is null then raise exception 'authentication_required';end if;
select id into d from public.doctors where user_id=u limit 1;if d is null then raise exception 'professional_profile_required';end if;
update public.doctor_subscriptions set cancel_at_period_end=true,cancelled_at=now(),updated_at=now() where doctor_id=d and status='active' and not cancel_at_period_end returning id into s;
if s is null then raise exception 'active_subscription_not_found';end if;return jsonb_build_object('subscription_id',s,'cancel_at_period_end',true);end $$;
revoke all on function public.request_cancel_doctor_subscription() from public,anon;grant execute on function public.request_cancel_doctor_subscription() to authenticated;
create or replace function private.expire_doctor_subscriptions() returns integer language plpgsql security definer set search_path='' as $$
declare n integer;begin
update public.doctor_subscriptions set status=case when cancel_at_period_end then 'cancelled' else 'past_due' end,ended_at=case when cancel_at_period_end then now() else ended_at end,updated_at=now() where status='active' and current_period_end<=now();
get diagnostics n=row_count;update public.subscription_invoices set status='overdue' where status='pending' and due_at<=now();return n;end $$;
revoke all on function private.expire_doctor_subscriptions() from public,anon,authenticated;
do $$ begin if exists(select 1 from cron.job where jobname='medlink-expire-doctor-subscriptions') then perform cron.unschedule('medlink-expire-doctor-subscriptions');end if;perform cron.schedule('medlink-expire-doctor-subscriptions','15 * * * *','select private.expire_doctor_subscriptions();');end $$;