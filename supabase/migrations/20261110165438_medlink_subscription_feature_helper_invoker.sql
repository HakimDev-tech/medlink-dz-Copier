create or replace function private.doctor_has_feature(p_doctor_id uuid,p_feature text)
returns boolean language sql stable security invoker set search_path=''
as $$
 select exists(
  select 1 from public.doctor_subscriptions s
  join public.subscription_plans p on p.id=s.plan_id
  where s.doctor_id=p_doctor_id and s.status='active'
    and s.current_period_end>now()
    and coalesce((p.features->>p_feature)::boolean,false)=true
 );
$$;
revoke all on function private.doctor_has_feature(uuid,text) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.doctor_has_feature(uuid,text) to authenticated;