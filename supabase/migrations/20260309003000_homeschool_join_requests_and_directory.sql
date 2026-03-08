-- Onboarding support:
-- 1) Public homeschool search directory for authenticated users
-- 2) Join request table for users without membership

create table if not exists public.homeschool_join_requests (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  requester_email text not null,
  requester_name text,
  request_note text,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED', 'CANCELED')),
  reviewed_by_user_id uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (homeschool_id, requester_user_id, status)
);

create index if not exists idx_homeschool_join_requests_school_status
  on public.homeschool_join_requests (homeschool_id, status, created_at desc);

create index if not exists idx_homeschool_join_requests_requester
  on public.homeschool_join_requests (requester_user_id, status, created_at desc);

drop trigger if exists trg_homeschool_join_requests_updated_at on public.homeschool_join_requests;
create trigger trg_homeschool_join_requests_updated_at
before update on public.homeschool_join_requests
for each row execute function public.set_updated_at();

alter table public.homeschool_join_requests enable row level security;

drop policy if exists homeschool_join_requests_select_self_or_admin on public.homeschool_join_requests;
create policy homeschool_join_requests_select_self_or_admin on public.homeschool_join_requests
for select using (
  requester_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists homeschool_join_requests_insert_self on public.homeschool_join_requests;
create policy homeschool_join_requests_insert_self on public.homeschool_join_requests
for insert with check (
  requester_user_id = auth.uid()
  and status = 'PENDING'
  and not public.is_homeschool_member(homeschool_id)
);

drop policy if exists homeschool_join_requests_update_admin on public.homeschool_join_requests;
create policy homeschool_join_requests_update_admin on public.homeschool_join_requests
for update using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
)
with check (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists homeschool_join_requests_delete_self_or_admin on public.homeschool_join_requests;
create policy homeschool_join_requests_delete_self_or_admin on public.homeschool_join_requests
for delete using (
  requester_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

create or replace function public.search_homeschool_directory(
  p_query text default '',
  p_limit int default 24
)
returns table (
  id uuid,
  name text,
  timezone text,
  active_member_count int,
  has_pending_request boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(trim(coalesce(p_query, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 24), 80));
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  return query
  select
    h.id,
    h.name,
    h.timezone,
    coalesce(members.active_member_count, 0)::int as active_member_count,
    exists (
      select 1
      from public.homeschool_join_requests req
      where req.homeschool_id = h.id
        and req.requester_user_id = v_user_id
        and req.status = 'PENDING'
    ) as has_pending_request
  from public.homeschools h
  left join lateral (
    select count(*) as active_member_count
    from public.homeschool_memberships hm
    where hm.homeschool_id = h.id
      and hm.status = 'ACTIVE'::public.membership_status
  ) members on true
  where not exists (
      select 1
      from public.homeschool_memberships mine
      where mine.homeschool_id = h.id
        and mine.user_id = v_user_id
        and mine.status = 'ACTIVE'::public.membership_status
    )
    and (
      v_query = ''
      or lower(h.name) like '%' || v_query || '%'
    )
  order by
    case
      when v_query <> '' and lower(h.name) like v_query || '%' then 0
      else 1
    end,
    h.name
  limit v_limit;
end;
$$;

revoke all on function public.search_homeschool_directory(text, int) from public;
grant execute on function public.search_homeschool_directory(text, int) to authenticated;
