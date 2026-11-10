-- Professional operations: recurring availability, clinic ownership/invitations, refund review.
create table if not exists public.doctor_availability_rules(
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.doctors(id) on delete cascade,
 weekday smallint not null check(weekday between 0 and 6),
 start_time time not null,end_time time not null,
 slot_minutes smallint not null default 30 check(slot_minutes between 10 and 180),
 valid_from date not null default (now() at time zone 'Africa/Algiers')::date,
 valid_until date,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(end_time>start_time),check(valid_until is null or valid_until>=valid_from),
 unique(doctor_id,weekday,start_time)
);
create index if not exists doctor_availability_lookup_idx on public.doctor_availability_rules(doctor_id,weekday,is_active);
create table if not exists public.doctor_availability_exceptions(
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.doctors(id) on delete cascade,
 exception_date date not null,
 is_available boolean not null default false,
 start_time time,end_time time,
 reason text,
 created_at timestamptz not null default now(),
 unique(doctor_id,exception_date),
 check((is_available=false and start_time is null and end_time is null) or (is_available=true and start_time is not null and end_time is not null and end_time>start_time))
);
create index if not exists doctor_availability_exception_date_idx on public.doctor_availability_exceptions(doctor_id,exception_date);
alter table public.appointments add column if not exists duration_minutes smallint not null default 30 check(duration_minutes between 10 and 240);
alter table public.doctor_availability_rules enable row level security;
alter table public.doctor_availability_exceptions enable row level security;
create policy "public reads active doctor availability" on public.doctor_availability_rules for select to anon,authenticated using(is_active=true);
create policy "doctor manages own availability rules" on public.doctor_availability_rules for all to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
create policy "public reads availability exceptions" on public.doctor_availability_exceptions for select to anon,authenticated using(is_available=true);
create policy "doctor manages own availability exceptions" on public.doctor_availability_exceptions for all to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())))
with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
revoke all on public.doctor_availability_rules,public.doctor_availability_exceptions from anon,authenticated;
grant select on public.doctor_availability_rules,public.doctor_availability_exceptions to anon,authenticated;
grant insert,update,delete on public.doctor_availability_rules,public.doctor_availability_exceptions to authenticated;
create or replace function private.validate_medlink_appointment_slot()
returns trigger language plpgsql security definer set search_path='' as $$
declare local_start timestamp; local_day date; local_clock time; local_end time; rule public.doctor_availability_rules%rowtype; exception_row public.doctor_availability_exceptions%rowtype; configured boolean:=false; slot_start time; slot_end time; step_seconds integer;
begin
 if new.status not in ('requested','confirmed') then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text,0));
 local_start:=new.starts_at at time zone 'Africa/Algiers';local_day:=local_start::date;local_clock:=local_start::time;
 if exists(select 1 from public.doctor_availability_rules r where r.doctor_id=new.doctor_id and r.is_active) then
  configured:=true;
  select * into exception_row from public.doctor_availability_exceptions e where e.doctor_id=new.doctor_id and e.exception_date=local_day;
  if found then
   if not exception_row.is_available then raise exception 'doctor_unavailable_on_date';end if;
   slot_start:=exception_row.start_time;slot_end:=exception_row.end_time;
   select * into rule from public.doctor_availability_rules r where r.doctor_id=new.doctor_id and r.weekday=extract(dow from local_day)::int and r.is_active order by r.start_time limit 1;
   if not found then rule.slot_minutes:=30;end if;
  else
   select * into rule from public.doctor_availability_rules r where r.doctor_id=new.doctor_id and r.weekday=extract(dow from local_day)::int and r.is_active and local_day>=r.valid_from and (r.valid_until is null or local_day<=r.valid_until) and local_clock>=r.start_time and local_clock<r.end_time order by r.start_time limit 1;
   if not found then raise exception 'outside_doctor_availability';end if;
   slot_start:=rule.start_time;slot_end:=rule.end_time;
  end if;
  local_end:=local_clock+(new.duration_minutes||' minutes')::interval;
  if local_clock<slot_start or local_end>slot_end then raise exception 'appointment_outside_availability';end if;
  step_seconds:=extract(epoch from (local_clock-slot_start))::int;
  if mod(step_seconds,rule.slot_minutes*60)<>0 then raise exception 'appointment_not_aligned_to_slot';end if;
 end if;
 if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id and a.id is distinct from new.id and a.status in ('requested','confirmed') and tstzrange(a.starts_at,a.starts_at+(a.duration_minutes||' minutes')::interval,'[)') && tstzrange(new.starts_at,new.starts_at+(new.duration_minutes||' minutes')::interval,'[)')) then
  raise exception 'doctor_slot_already_taken';
 end if;
 return new;
end;$$;
revoke all on function private.validate_medlink_appointment_slot() from public,anon,authenticated;
drop trigger if exists medlink_validate_appointment_slot on public.appointments;
create trigger medlink_validate_appointment_slot before insert or update of starts_at,duration_minutes,status,doctor_id on public.appointments for each row execute function private.validate_medlink_appointment_slot();

alter table public.clinics add column if not exists owner_id uuid references auth.users(id) on delete restrict;
alter table public.clinics add column if not exists updated_at timestamptz not null default now();
alter table public.clinic_members add column if not exists member_status text not null default 'active' check(member_status in('active','invited','suspended'));
create table if not exists public.clinic_invitations(
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null references public.clinics(id) on delete cascade,
 email text not null,member_role text not null default 'staff' check(member_role in('clinic_admin','staff')),
 invited_by uuid not null references auth.users(id) on delete restrict,
 token_hash text not null unique,status text not null default 'pending' check(status in('pending','accepted','revoked','expired')),
 expires_at timestamptz not null default now()+interval '7 days',accepted_at timestamptz,created_at timestamptz not null default now()
);
create unique index if not exists clinic_invitation_pending_email_idx on public.clinic_invitations(clinic_id,lower(email)) where status='pending';
alter table public.clinic_invitations enable row level security;
create policy "clinic managers read invitations" on public.clinic_invitations for select to authenticated using(exists(select 1 from public.clinic_members m where m.clinic_id=clinic_id and m.user_id=(select auth.uid()) and m.member_role in('owner','clinic_admin')));
revoke all on public.clinic_invitations from anon,authenticated;grant select on public.clinic_invitations to authenticated;
create or replace function public.create_medlink_clinic(p_name text,p_wilaya text,p_commune text,p_address text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); cid uuid;
begin if u is null then raise exception 'authentication_required';end if;
 if length(trim(coalesce(p_name,'')))<2 or length(trim(coalesce(p_wilaya,'')))<2 then raise exception 'invalid_clinic_details';end if;
 insert into public.clinics(name,wilaya,commune,address,owner_id,verification_status) values(trim(p_name),trim(p_wilaya),nullif(trim(p_commune),''),nullif(trim(p_address),''),u,'pending') returning id into cid;
 insert into public.clinic_members(clinic_id,user_id,member_role) values(cid,u,'owner');
 return cid;
end;$$;
revoke all on function public.create_medlink_clinic(text,text,text,text) from public,anon;grant execute on function public.create_medlink_clinic(text,text,text,text) to authenticated;
create or replace function public.invite_medlink_clinic_member(p_clinic_id uuid,p_email text,p_role text default 'staff')
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();inv uuid;tok text:=encode(gen_random_bytes(32),'hex');target uuid;
begin if u is null then raise exception 'authentication_required';end if;
 if p_role not in('clinic_admin','staff') or position('@' in p_email)=0 then raise exception 'invalid_invitation';end if;
 if not exists(select 1 from public.clinics c where c.id=p_clinic_id and (c.owner_id=u or exists(select 1 from public.clinic_members m where m.clinic_id=c.id and m.user_id=u and m.member_role in('owner','clinic_admin')))) then raise exception 'clinic_admin_required';end if;
 select id into target from auth.users where lower(email)=lower(trim(p_email));
 if target is not null and exists(select 1 from public.clinic_members m where m.clinic_id=p_clinic_id and m.user_id=target and coalesce(m.member_status,'active')='active') then raise exception 'already_a_member';end if;
 insert into public.clinic_invitations(clinic_id,email,member_role,invited_by,token_hash) values(p_clinic_id,lower(trim(p_email)),p_role,u,encode(digest(tok,'sha256'),'hex')) returning id into inv;
 return jsonb_build_object('invitation_id',inv,'invitation_token',tok);
end;$$;
revoke all on function public.invite_medlink_clinic_member(uuid,text,text) from public,anon;grant execute on function public.invite_medlink_clinic_member(uuid,text,text) to authenticated;
create or replace function public.accept_medlink_clinic_invitation(p_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();inv public.clinic_invitations%rowtype;user_email text;
begin if u is null then raise exception 'authentication_required';end if;
 select lower(email) into user_email from auth.users where id=u;
 select * into inv from public.clinic_invitations where token_hash=encode(digest(p_token,'sha256'),'hex') and status='pending' and expires_at>now() for update;
 if not found or inv.email<>user_email then raise exception 'invalid_or_expired_invitation';end if;
 insert into public.clinic_members(clinic_id,user_id,member_role,member_status) values(inv.clinic_id,u,inv.member_role,'active')
 on conflict(clinic_id,user_id) do update set member_role=excluded.member_role,member_status='active';
 update public.clinic_invitations set status='accepted',accepted_at=now() where id=inv.id;
 return inv.clinic_id;
end;$$;
revoke all on function public.accept_medlink_clinic_invitation(text) from public,anon;grant execute on function public.accept_medlink_clinic_invitation(text) to authenticated;
drop policy if exists "clinic members read clinic" on public.clinics;
create policy "clinic members read clinic" on public.clinics for select to authenticated using(owner_id=(select auth.uid()) or exists(select 1 from public.clinic_members m where m.clinic_id=clinics.id and m.user_id=(select auth.uid()) and coalesce(m.member_status,'active')='active'));
create policy "clinic owner manages clinic" on public.clinics for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
drop policy if exists "members read own memberships" on public.clinic_members;
create policy "clinic members read memberships" on public.clinic_members for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.clinic_members m where m.clinic_id=clinic_members.clinic_id and m.user_id=(select auth.uid()) and m.member_role in('owner','clinic_admin')));
create policy "clinic admins manage members" on public.clinic_members for all to authenticated using(exists(select 1 from public.clinics c where c.id=clinic_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.clinic_members m where m.clinic_id=c.id and m.user_id=(select auth.uid()) and m.member_role in('owner','clinic_admin'))))) with check(exists(select 1 from public.clinics c where c.id=clinic_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.clinic_members m where m.clinic_id=c.id and m.user_id=(select auth.uid()) and m.member_role in('owner','clinic_admin')))));

alter table public.refund_requests add column if not exists admin_note text;
alter table public.refund_requests add column if not exists resolved_at timestamptz;
create policy "doctors read refunds for own appointments" on public.refund_requests for select to authenticated using(exists(select 1 from public.appointments a join public.doctors d on d.id=a.doctor_id where a.id=refund_requests.appointment_id and d.user_id=(select auth.uid())));
create policy "platform admins review refunds" on public.refund_requests for update to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
revoke update on public.refund_requests from authenticated;
grant update(status,admin_note,resolved_at,reviewed_by,reviewed_at) on public.refund_requests to authenticated;
create or replace function private.enforce_medlink_refund_review()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.is_platform_admin() then raise exception 'platform_admin_required';end if;
 if old.status is distinct from new.status and not (
  (old.status='requested' and new.status in('under_review','rejected')) or
  (old.status='under_review' and new.status in('approved','rejected')) or
  (old.status='approved' and new.status in('processing','failed')) or
  (old.status='processing' and new.status in('refunded','failed'))
 ) then raise exception 'invalid_refund_transition';end if;
 if new.status in('rejected','refunded','failed') then new.resolved_at=now();end if;
 new.reviewed_at=now();new.reviewed_by=auth.uid();
 return new;
end;$$;
revoke all on function private.enforce_medlink_refund_review() from public,anon,authenticated;
drop trigger if exists medlink_enforce_refund_review on public.refund_requests;
create trigger medlink_enforce_refund_review before update on public.refund_requests for each row execute function private.enforce_medlink_refund_review();
