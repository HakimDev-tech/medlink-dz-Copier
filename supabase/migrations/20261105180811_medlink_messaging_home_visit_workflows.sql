
-- Patient-initiated conversations must target an approved professional.
drop policy if exists "patient create conversation" on public.conversations;
create policy "patient create conversation" on public.conversations
for insert to authenticated with check (
 patient_id=(select auth.uid()) and exists(
  select 1 from public.doctors d where d.id=doctor_id and d.verification_status='verified'
 )
);

-- Restrict home-visit state changes to the assigned professional and valid transitions.
revoke update on public.home_visit_requests from authenticated;
grant update(status) on public.home_visit_requests to authenticated;
create or replace function private.enforce_medlink_home_visit_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_is_doctor boolean;
begin
 if old.status is not distinct from new.status then return new; end if;
 select exists(select 1 from public.doctors d where d.id=old.doctor_id and d.user_id=(select auth.uid())) into actor_is_doctor;
 if not actor_is_doctor and not private.is_platform_admin() then
  raise exception 'Only the assigned professional may change home-visit status';
 end if;
 if actor_is_doctor and not private.is_platform_admin() and not (
  (old.status='requested' and new.status in ('accepted','rejected')) or
  (old.status='accepted' and new.status='completed')
 ) then raise exception 'Invalid home-visit status transition'; end if;
 return new;
end; $$;
revoke all on function private.enforce_medlink_home_visit_transition() from public,anon,authenticated;
drop trigger if exists medlink_enforce_home_visit_transition on public.home_visit_requests;
create trigger medlink_enforce_home_visit_transition before update of status on public.home_visit_requests
for each row execute function private.enforce_medlink_home_visit_transition();

-- Notify the recipient when a participant sends a message.
create or replace function private.notify_medlink_new_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
 select case when c.patient_id=new.sender_id then d.user_id else c.patient_id end
 into recipient
 from public.conversations c join public.doctors d on d.id=c.doctor_id
 where c.id=new.conversation_id;
 if recipient is not null then
  insert into public.notifications(user_id,title,body,category)
  values(recipient,'Nouveau message','Vous avez reçu un nouveau message dans MedLink DZ.','message');
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_new_message() from public,anon,authenticated;
drop trigger if exists medlink_notify_new_message on public.messages;
create trigger medlink_notify_new_message after insert on public.messages
for each row execute function private.notify_medlink_new_message();

-- Notify the patient when a home-visit request is assigned or updated.
create or replace function private.notify_medlink_home_visit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
 if tg_op='INSERT' then
  if new.doctor_id is not null then select user_id into recipient from public.doctors where id=new.doctor_id; end if;
  if recipient is not null then
   insert into public.notifications(user_id,title,body,category)
   values(recipient,'Nouvelle demande de visite à domicile','Une demande de visite à domicile vous a été adressée.','home_visit');
  end if;
 elsif old.status is distinct from new.status then
  insert into public.notifications(user_id,title,body,category)
  values(new.patient_id,'Mise à jour de votre visite à domicile','Le statut de votre demande a changé : '||new.status::text||'.','home_visit');
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_home_visit() from public,anon,authenticated;
drop trigger if exists medlink_notify_home_visit on public.home_visit_requests;
create trigger medlink_notify_home_visit after insert or update of status on public.home_visit_requests
for each row execute function private.notify_medlink_home_visit();

-- Keep the database-level request valid even when a client bypasses form validation.
create or replace function private.validate_medlink_home_visit()
returns trigger language plpgsql set search_path = '' as $$
begin
 if new.requested_for is not null and new.requested_for <= now() then
  raise exception 'Requested home-visit time must be in the future';
 end if;
 if new.doctor_id is not null and not exists(select 1 from public.doctors d where d.id=new.doctor_id and d.verification_status='verified') then
  raise exception 'Home visits can only be requested from verified professionals';
 end if;
 return new;
end; $$;
revoke all on function private.validate_medlink_home_visit() from public,anon,authenticated;
drop trigger if exists medlink_validate_home_visit on public.home_visit_requests;
create trigger medlink_validate_home_visit before insert or update of requested_for,doctor_id on public.home_visit_requests
for each row execute function private.validate_medlink_home_visit();

