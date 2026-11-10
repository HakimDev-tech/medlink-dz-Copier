alter function public.request_doctor_subscription(text) set schema private;
alter function public.request_cancel_doctor_subscription() set schema private;
grant usage on schema private to authenticated;
grant execute on function private.request_doctor_subscription(text) to authenticated;
grant execute on function private.request_cancel_doctor_subscription() to authenticated;
create or replace function public.request_doctor_subscription(p_plan_code text) returns jsonb language sql security invoker set search_path='' as $$select private.request_doctor_subscription(p_plan_code);$$;
revoke all on function public.request_doctor_subscription(text) from public,anon;grant execute on function public.request_doctor_subscription(text) to authenticated;
create or replace function public.request_cancel_doctor_subscription() returns jsonb language sql security invoker set search_path='' as $$select private.request_cancel_doctor_subscription();$$;
revoke all on function public.request_cancel_doctor_subscription() from public,anon;grant execute on function public.request_cancel_doctor_subscription() to authenticated;