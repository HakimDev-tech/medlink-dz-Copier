alter function public.request_doctor_subscription(text) set schema private;
alter function public.request_cancel_doctor_subscription() set schema private;
grant usage on schema private to authenticated;
grant execute on function private.request_doctor_subscription(text) to authenticated;
grant execute on function private.request_cancel_doctor_subscription() to authenticated;
create or replace function public.request_doctor_subscription(p_plan_code text) returns jsonb language sql security invoker set search_path='' as $$ select private.request_doctor_subscription(p_plan_code); $$;
revoke all on function public.request_doctor_subscription(text) from public,anon; grant execute on function public.request_doctor_subscription(text) to authenticated;
create or replace function public.request_cancel_doctor_subscription() returns jsonb language sql security invoker set search_path='' as $$ select private.request_cancel_doctor_subscription(); $$;
revoke all on function public.request_cancel_doctor_subscription() from public,anon; grant execute on function public.request_cancel_doctor_subscription() to authenticated;
create or replace function private.confirm_doctor_subscription_payment(p_subscription_id uuid,p_provider text,p_provider_reference text,p_amount integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.doctor_subscriptions%rowtype; i public.subscription_invoices%rowtype; pay uuid;
begin
 if p_provider is null or length(trim(p_provider))<2 or p_provider_reference is null or length(trim(p_provider_reference))<3 or p_amount is null or p_amount<=0 then raise exception 'invalid_payment_confirmation'; end if;
 select * into s from public.doctor_subscriptions where id=p_subscription_id for update;
 if not found then raise exception 'subscription_not_found'; end if;
 if s.status<>'pending' then raise exception 'subscription_not_payable'; end if;
 select * into i from public.subscription_invoices where subscription_id=p_subscription_id and status='pending' order by issued_at desc limit 1 for update;
 if not found then raise exception 'pending_invoice_not_found'; end if;
 if i.amount<>p_amount then raise exception 'payment_amount_mismatch'; end if;
 insert into public.subscription_payments(invoice_id,doctor_id,provider,provider_reference,amount,currency,status,paid_at) values(i.id,s.doctor_id,p_provider,p_provider_reference,p_amount,i.currency,'paid',now()) on conflict(provider,provider_reference) do nothing returning id into pay;
 if pay is null then select id into pay from public.subscription_payments where provider=p_provider and provider_reference=p_provider_reference; if exists(select 1 from public.subscription_payments where id=pay and invoice_id<>i.id) then raise exception 'payment_reference_already_used'; end if; end if;
 update public.subscription_invoices set status='paid',paid_at=now() where id=i.id;
 update public.doctor_subscriptions set status='cancelled',ended_at=now(),updated_at=now() where doctor_id=s.doctor_id and status='active';
 update public.doctor_subscriptions set status='active',activated_at=coalesce(activated_at,now()),current_period_start=now(),current_period_end=now()+(s.current_period_end-s.current_period_start),cancel_at_period_end=false,cancelled_at=null,ended_at=null,updated_at=now() where id=p_subscription_id;
 return jsonb_build_object('subscription_id',p_subscription_id,'invoice_id',i.id,'payment_id',pay,'status','active');
end $$;
revoke all on function private.confirm_doctor_subscription_payment(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function private.confirm_doctor_subscription_payment(uuid,text,text,integer) to service_role;