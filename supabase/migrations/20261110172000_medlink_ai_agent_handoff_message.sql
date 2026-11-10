alter table public.care_agent_escalations add column if not exists patient_message text;
alter table public.care_agent_escalations add column if not exists message_locale text not null default 'fr';
comment on column public.care_agent_escalations.patient_message is 'Patient message explicitly handed off to the responsible physician; visible only to escalation participants under RLS.';
create or replace function public.attach_care_agent_handoff(p_run_id uuid,p_message text,p_locale text default 'fr')
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_message is null or length(trim(p_message))<2 or length(p_message)>2000 then raise exception 'invalid_handoff';end if;
 update public.care_agent_escalations e set patient_message=trim(p_message),message_locale=case when p_locale in('fr','en','ar') then p_locale else 'fr' end
 where e.run_id=p_run_id and e.patient_id=auth.uid() and e.status='open';
 if not found then raise exception 'handoff_not_found';end if;
end $$;
revoke all on function public.attach_care_agent_handoff(uuid,text,text) from public,anon;
grant execute on function public.attach_care_agent_handoff(uuid,text,text) to authenticated;
