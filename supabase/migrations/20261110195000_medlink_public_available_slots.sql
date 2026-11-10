create or replace function private.validate_medlink_appointment_slot()
returns trigger language plpgsql security definer set search_path='' as $$
declare local_start timestamp; local_day date; local_clock time; local_end time; rule public.doctor_availability_rules%rowtype; exception_row public.doctor_availability_exceptions%rowtype; slot_start_time time; slot_end_time time; step_seconds integer;
begin
 if new.status not in ('requested','confirmed') then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text,0));
 local_start:=new.starts_at at time zone 'Africa/Algiers';local_day:=local_start::date;local_clock:=local_start::time;
 select * into exception_row from public.doctor_availability_exceptions e where e.doctor_id=new.doctor_id and e.exception_date=local_day;
 if found then
  if not exception_row.is_available then raise exception 'doctor_unavailable_on_date';end if;
  slot_start_time:=exception_row.start_time;slot_end_time:=exception_row.end_time;
  select * into rule from public.doctor_availability_rules r where r.doctor_id=new.doctor_id and r.is_active order by r.weekday,r.start_time limit 1;
  if not found then rule.slot_minutes:=30;end if;
 else
  select * into rule from public.doctor_availability_rules r where r.doctor_id=new.doctor_id and r.weekday=extract(dow from local_day)::int and r.is_active and local_day>=r.valid_from and (r.valid_until is null or local_day<=r.valid_until) and local_clock>=r.start_time and local_clock<r.end_time order by r.start_time limit 1;
  if not found then raise exception 'outside_doctor_availability';end if;
  slot_start_time:=rule.start_time;slot_end_time:=rule.end_time;
 end if;
 local_end:=local_clock+(new.duration_minutes||' minutes')::interval;
 if local_clock<slot_start_time or local_end>slot_end_time then raise exception 'appointment_outside_availability';end if;
 step_seconds:=extract(epoch from (local_clock-slot_start_time))::int;
 if mod(step_seconds,rule.slot_minutes*60)<>0 then raise exception 'appointment_not_aligned_to_slot';end if;
 if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id and a.id is distinct from new.id and a.status in ('requested','confirmed') and tstzrange(a.starts_at,a.starts_at+(a.duration_minutes||' minutes')::interval,'[)') && tstzrange(new.starts_at,new.starts_at+(new.duration_minutes||' minutes')::interval,'[)')) then
  raise exception 'doctor_slot_already_taken';
 end if;
 return new;
end;$$;
create or replace function public.get_medlink_available_slots(p_doctor_id uuid,p_date date)
returns table(slot_start timestamptz,duration_minutes smallint)
language plpgsql stable security definer set search_path='' as $$
declare ex public.doctor_availability_exceptions%rowtype;r record;v_from time;v_until time;v_step integer;v_time time;v_start timestamptz;v_duration smallint;
begin
 if p_date<(now() at time zone 'Africa/Algiers')::date or p_date>(now() at time zone 'Africa/Algiers')::date+90 then return;end if;
 if not exists(select 1 from public.doctors d where d.id=p_doctor_id and d.verification_status='verified') then return;end if;
 select * into ex from public.doctor_availability_exceptions e where e.doctor_id=p_doctor_id and e.exception_date=p_date;
 if found then
  if not ex.is_available then return;end if;
  select coalesce((select a.slot_minutes from public.doctor_availability_rules a where a.doctor_id=p_doctor_id and a.is_active order by a.weekday,a.start_time limit 1),30) into v_step;
  v_from:=ex.start_time;v_until:=ex.end_time;
  v_time:=v_from;
  while v_time+make_interval(mins=>v_step)<=v_until loop
   v_start:=(p_date+v_time) at time zone 'Africa/Algiers';v_duration:=v_step::smallint;
   if v_start>now() and not exists(select 1 from public.appointments a where a.doctor_id=p_doctor_id and a.status in('requested','confirmed') and tstzrange(a.starts_at,a.starts_at+(a.duration_minutes||' minutes')::interval,'[)') && tstzrange(v_start,v_start+make_interval(mins=>v_step),'[)')) then
    slot_start:=v_start;duration_minutes:=v_duration;return next;
   end if;
   v_time:=v_time+make_interval(mins=>v_step);
  end loop;
 else
  for r in select a.start_time,a.end_time,a.slot_minutes from public.doctor_availability_rules a where a.doctor_id=p_doctor_id and a.weekday=extract(dow from p_date)::int and a.is_active and p_date>=a.valid_from and (a.valid_until is null or p_date<=a.valid_until) order by a.start_time loop
   v_from:=r.start_time;v_until:=r.end_time;v_step:=r.slot_minutes;v_time:=v_from;
   while v_time+make_interval(mins=>v_step)<=v_until loop
    v_start:=(p_date+v_time) at time zone 'Africa/Algiers';v_duration:=v_step::smallint;
    if v_start>now() and not exists(select 1 from public.appointments a where a.doctor_id=p_doctor_id and a.status in('requested','confirmed') and tstzrange(a.starts_at,a.starts_at+(a.duration_minutes||' minutes')::interval,'[)') && tstzrange(v_start,v_start+make_interval(mins=>v_step),'[)')) then
     slot_start:=v_start;duration_minutes:=v_duration;return next;
    end if;
    v_time:=v_time+make_interval(mins=>v_step);
   end loop;
  end loop;
 end if;
end;$$;
revoke all on function public.get_medlink_available_slots(uuid,date) from public;
grant execute on function public.get_medlink_available_slots(uuid,date) to anon,authenticated;
