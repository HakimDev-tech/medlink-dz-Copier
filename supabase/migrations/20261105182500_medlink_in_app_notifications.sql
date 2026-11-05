create or replace function private.notify_medlink_appointment_created()
returns trigger language plpgsql security definer set search_path = '' as $$
declare doctor_user_id uuid;
begin
 select user_id into doctor_user_id from public.doctors where id=new.doctor_id;
 if doctor_user_id is not null then
  insert into public.notifications(user_id,title,body,category) values(doctor_user_id,'Nouvelle demande de rendez-vous','Une nouvelle demande de rendez-vous attend votre réponse.','appointment');
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_appointment_created() from public,anon,authenticated;
drop trigger if exists medlink_notify_appointment_created on public.appointments;
create trigger medlink_notify_appointment_created after insert on public.appointments for each row execute function private.notify_medlink_appointment_created();

create or replace function private.notify_medlink_appointment_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.status is distinct from new.status then
  insert into public.notifications(user_id,title,body,category) values(new.patient_id,'Mise à jour de votre rendez-vous','Le statut de votre demande de rendez-vous a été mis à jour : '||new.status::text||'.','appointment');
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_appointment_status() from public,anon,authenticated;
drop trigger if exists medlink_notify_appointment_status on public.appointments;
create trigger medlink_notify_appointment_status after update of status on public.appointments for each row execute function private.notify_medlink_appointment_status();

create or replace function private.notify_medlink_followup_published()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.status is distinct from new.status and new.status='published' then
  insert into public.notifications(user_id,title,body,category) values(new.patient_id,'Nouveau suivi publié','Votre professionnel a publié de nouvelles consignes de suivi.','follow_up');
 end if;
 return new;
end; $$;
revoke all on function private.notify_medlink_followup_published() from public,anon,authenticated;
drop trigger if exists medlink_notify_followup_published on public.follow_up_plans;
create trigger medlink_notify_followup_published after update of status on public.follow_up_plans for each row execute function private.notify_medlink_followup_published();
