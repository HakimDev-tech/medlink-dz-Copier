create table if not exists public.refund_admin_notes(
 refund_id uuid primary key references public.refund_requests(id) on delete cascade,
 note text not null default '',
 updated_by uuid not null references auth.users(id) on delete restrict,
 updated_at timestamptz not null default now()
);
alter table public.refund_admin_notes enable row level security;
create policy "platform admins manage refund notes" on public.refund_admin_notes for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
revoke all on public.refund_admin_notes from anon,authenticated;
grant select,insert,update on public.refund_admin_notes to authenticated;
alter table public.refund_requests drop column if exists admin_note;
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
