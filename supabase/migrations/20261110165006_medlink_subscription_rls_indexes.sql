create index if not exists doctor_subscriptions_plan_id_idx on public.doctor_subscriptions(plan_id);
create index if not exists subscription_invoices_subscription_id_idx on public.subscription_invoices(subscription_id);
create index if not exists subscription_payments_doctor_id_idx on public.subscription_payments(doctor_id);
drop policy if exists "doctors read own subscriptions" on public.doctor_subscriptions;
create policy "doctors read own subscriptions" on public.doctor_subscriptions for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or ((select auth.jwt())->'app_metadata'->>'role')='platform_admin');
drop policy if exists "doctors read own invoices" on public.subscription_invoices;
create policy "doctors read own invoices" on public.subscription_invoices for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or ((select auth.jwt())->'app_metadata'->>'role')='platform_admin');
drop policy if exists "doctors read own payments" on public.subscription_payments;
create policy "doctors read own payments" on public.subscription_payments for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) or ((select auth.jwt())->'app_metadata'->>'role')='platform_admin');