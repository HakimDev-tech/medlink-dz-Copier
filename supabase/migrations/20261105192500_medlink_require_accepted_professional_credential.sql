create or replace function private.require_medlink_credential_before_verification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.verification_status='verified' and old.verification_status is distinct from new.verification_status then
  if not exists(select 1 from public.doctor_verification_documents doc
   where doc.doctor_id=new.id and doc.status='accepted' and doc.document_type in ('professional_card','license')) then
   raise exception 'At least one accepted professional card or practice license is required before verification';
  end if;
 end if;
 return new;
end; $$;
revoke all on function private.require_medlink_credential_before_verification() from public,anon,authenticated;
drop trigger if exists medlink_require_credential_before_verification on public.doctors;
create trigger medlink_require_credential_before_verification before update of verification_status on public.doctors
for each row execute function private.require_medlink_credential_before_verification();