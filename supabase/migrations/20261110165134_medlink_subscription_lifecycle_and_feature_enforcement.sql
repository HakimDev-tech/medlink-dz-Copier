-- Change pending requests into plan changes; expire unpaid requests; enforce paid feature entitlements.
create or replace function private.request_doctor_subscription(p_plan_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();d uuid;p public.subscription_plans%rowtype;s uuid;i uuid;st timestamptz:=now();en timestamptz;num text;
begin
if u is null then raise exception 'authentication_required';end if;
select id into d from public.doctors where user_id=u and verification_status not in('rejected','suspended') limit 1;
if d is null then raise exception 'professional_profile_required';end if;
select * into p from public.subscription_plans where code=p_plan_code and is_active;
if not found then raise exception 'plan_not_available';end if;
en:=st+make_interval(months=>p.interval_count);
select id into s from public.doctor_subscriptions where doctor_id=d and status='pending' for update;
if s is not null then
 update public.subscription_invoices set status='void' where subscription_id=s and status in('pending','overdue');
 update public.doctor_subscriptions set plan_id=p.id,current_period_start=st,current_period_end=en,updated_at=now() where id=s;
else
 insert into public.doctor_subscriptions(doctor_id,plan_id,status,current_period_start,current_period_end) values(d,p.id,'pending',st,en) returning id into s;
end if;
num:='MLD-'||to_char(st at time zone 'Africa/Algiers','YYYYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
insert into public.subscription_invoices(invoice_number,doctor_id,subscription_id,plan_code,plan_name,amount,currency,status,period_start,period_end,due_at) values(num,d,s,p.code,p.name,p.amount,p.currency,'pending',st,en,st+interval '7 days') returning id into i;
return jsonb_build_object('subscription_id',s,'invoice_id',i,'invoice_number',num,'status','pending','amount',p.amount,'currency',p.currency,'period_end',en);
end $$;
create or replace function private.expire_doctor_subscriptions() returns integer language plpgsql security definer set search_path='' as $$
declare n integer;begin
update public.doctor_subscriptions set status=case when cancel_at_period_end then 'cancelled' else 'past_due' end,ended_at=case when cancel_at_period_end then now() else ended_at end,updated_at=now() where status='active' and current_period_end<=now();
get diagnostics n=row_count;
update public.subscription_invoices set status='overdue' where status='pending' and due_at<=now();
update public.doctor_subscriptions s set status='past_due',updated_at=now() where s.status='pending' and exists(select 1 from public.subscription_invoices i where i.subscription_id=s.id and i.status='overdue');
return n;end $$;
create or replace function private.doctor_has_feature(p_doctor_id uuid,p_feature text) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.doctor_subscriptions s join public.subscription_plans p on p.id=s.plan_id where s.doctor_id=p_doctor_id and s.status='active' and s.current_period_end>now() and coalesce((p.features->>p_feature)::boolean,false)=true);
$$;
grant usage on schema private to authenticated;
grant execute on function private.doctor_has_feature(uuid,text) to authenticated;
drop policy if exists "doctor update appointment" on public.appointments;
create policy "doctor update appointment" on public.appointments for update to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'appointments')))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'appointments')));
drop policy if exists "doctor create consultation draft" on public.consultation_records;
create policy "doctor create consultation draft" on public.consultation_records for insert to authenticated
with check(status='draft' and exists(select 1 from public.appointments a join public.doctors d on d.id=a.doctor_id where a.id=consultation_records.appointment_id and a.doctor_id=consultation_records.doctor_id and a.patient_id=consultation_records.patient_id and a.status='completed' and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'consultations')));
drop policy if exists "doctor update consultation draft" on public.consultation_records;
create policy "doctor update consultation draft" on public.consultation_records for update to authenticated
using(status='draft' and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'consultations')))
with check(status in('draft','published') and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'consultations')));
drop policy if exists "doctor create followup draft" on public.follow_up_plans;
create policy "doctor create followup draft" on public.follow_up_plans for insert to authenticated
with check(status='draft' and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')));
drop policy if exists "doctor update own followup" on public.follow_up_plans;
create policy "doctor update own followup" on public.follow_up_plans for update to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')));
drop policy if exists "doctor insert followup events" on public.follow_up_events;
create policy "doctor insert followup events" on public.follow_up_events for insert to authenticated
with check(exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')));
drop policy if exists "doctor update followup events" on public.follow_up_events;
create policy "doctor update followup events" on public.follow_up_events for update to authenticated
using(exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')))
with check(exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')));
drop policy if exists "doctor delete followup events" on public.follow_up_events;
create policy "doctor delete followup events" on public.follow_up_events for delete to authenticated
using(exists(select 1 from public.follow_up_plans p join public.doctors d on d.id=p.doctor_id where p.id=plan_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'manual_follow_up')));
drop policy if exists "doctor update home visit" on public.home_visit_requests;
create policy "doctor update home visit" on public.home_visit_requests for update to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'appointments')))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'appointments')));
drop policy if exists "participants send messages" on public.messages;
create policy "participants send messages" on public.messages for insert to authenticated
with check(sender_id=(select auth.uid()) and exists(select 1 from public.conversations c where c.id=conversation_id and (c.patient_id=(select auth.uid()) or exists(select 1 from public.doctors d where d.id=c.doctor_id and d.user_id=(select auth.uid()) and private.doctor_has_feature(d.id,'messaging')))));