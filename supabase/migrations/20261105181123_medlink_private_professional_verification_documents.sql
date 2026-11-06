
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('doctor-verification','doctor-verification',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['application/pdf','image/jpeg','image/png'];

create table if not exists public.doctor_verification_documents(
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.doctors(id) on delete cascade,
 uploaded_by uuid not null references public.profiles(id),
 document_type text not null check(document_type in ('professional_card','license','diploma')),
 object_path text not null unique,
 original_filename text not null,
 mime_type text not null,
 size_bytes bigint not null check(size_bytes between 1 and 10485760),
 status text not null default 'pending' check(status in ('pending','accepted','rejected')),
 review_note text,
 reviewed_by uuid references public.profiles(id),
 reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.doctor_verification_documents enable row level security;
drop policy if exists "doctor read own verification documents" on public.doctor_verification_documents;
create policy "doctor read own verification documents" on public.doctor_verification_documents for select to authenticated
using(exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())));
drop policy if exists "doctor upload own verification documents" on public.doctor_verification_documents;
create policy "doctor upload own verification documents" on public.doctor_verification_documents for insert to authenticated
with check(uploaded_by=(select auth.uid()) and exists(select 1 from public.doctors d where d.id=doctor_id and d.user_id=(select auth.uid())) and status='pending');
drop policy if exists "admin read verification documents" on public.doctor_verification_documents;
create policy "admin read verification documents" on public.doctor_verification_documents for select to authenticated using(private.is_platform_admin());
drop policy if exists "admin review verification documents" on public.doctor_verification_documents;
create policy "admin review verification documents" on public.doctor_verification_documents for update to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());

drop policy if exists "doctors upload private verification files" on storage.objects;
create policy "doctors upload private verification files" on storage.objects for insert to authenticated
with check(bucket_id='doctor-verification' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "owners and admins read private verification files" on storage.objects;
create policy "owners and admins read private verification files" on storage.objects for select to authenticated
using(bucket_id='doctor-verification' and ((storage.foldername(name))[1]=(select auth.uid())::text or private.is_platform_admin()));
drop policy if exists "owners delete own pending verification files" on storage.objects;
create policy "owners delete own pending verification files" on storage.objects for delete to authenticated
using(bucket_id='doctor-verification' and (storage.foldername(name))[1]=(select auth.uid())::text);

