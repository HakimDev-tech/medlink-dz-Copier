create or replace function private.confirm_doctor_subscription_payment(p_subscription_id uuid,p_provider text,p_provider_reference text,p_amount integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.doctor_subscriptions%rowtype;i public.subscription_invoices%rowtype;pay uuid;prior public.subscription_payments%rowtype;
begin
 if p_provider is null or length(trim(p_provider))<2 or p_provider_reference is null or length(trim(p_provider_reference))<3 or p_amount is null or p_amount<=0 then raise exception 'invalid_payment_confirmation';end if;
 select * into s from public.doctor_subscriptions where id=p_subscription_id for update;
 if not found then raise exception 'subscription_not_found';end if;
 select * into prior from public.subscription_payments where provider=p_provider and provider_reference=p_provider_reference;
 if found then
  if prior.doctor_id<>s.doctor_id or prior.amount<>p_amount or not exists(select 1 from public.subscription_invoices x where x.id=prior.invoice_id and x.subscription_id=p_subscription_id) then raise exception 'payment_reference_already_used';end if;
  if s.status='active' and prior.status='paid' then return jsonb_build_object('subscription_id',p_subscription_id,'status','active','idempotent',true);end if;
  raise exception 'payment_reference_already_used';
 end if;
 if s.status<>'pending' then raise exception 'subscription_not_payable';end if;
 select * into i from public.subscription_invoices where subscription_id=p_subscription_id and status='pending' order by issued_at desc limit 1 for update;
 if not found then raise exception 'pending_invoice_not_found';end if;
 if i.amount<>p_amount or i.currency<>'DZD' then raise exception 'payment_amount_mismatch';end if;
 insert into public.subscription_payments(invoice_id,doctor_id,provider,provider_reference,amount,currency,status,paid_at)
 values(i.id,s.doctor_id,p_provider,p_provider_reference,p_amount,i.currency,'paid',now()) returning id into pay;
 update public.subscription_invoices set status='paid',paid_at=now() where id=i.id;
 update public.doctor_subscriptions set status='cancelled',ended_at=now(),updated_at=now() where doctor_id=s.doctor_id and status='active';
 update public.doctor_subscriptions set status='active',activated_at=coalesce(activated_at,now()),current_period_start=now(),current_period_end=now()+(s.current_period_end-s.current_period_start),cancel_at_period_end=false,cancelled_at=null,ended_at=null,updated_at=now() where id=p_subscription_id;
 return jsonb_build_object('subscription_id',p_subscription_id,'invoice_id',i.id,'payment_id',pay,'status','active','idempotent',false);
end $$;
revoke all on function private.confirm_doctor_subscription_payment(uuid,text,text,integer) from public,anon,authenticated;
grant usage on schema private to service_role;
grant execute on function private.confirm_doctor_subscription_payment(uuid,text,text,integer) to service_role;