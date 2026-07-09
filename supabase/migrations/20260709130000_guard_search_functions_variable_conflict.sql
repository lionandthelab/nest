-- 예방 하드닝: search_homeschool_directory / search_homeschool_members 의 42702 잠재 위험 차단
--
-- 두 함수는 `returns table (...)` OUT 컬럼명이 실제 테이블 컬럼명과 동일한 위험 시그니처다
--   search_homeschool_directory: id, name, timezone  (= public.homeschools 컬럼)
--   search_homeschool_members:   user_id, email, full_name  (= memberships/profiles 컬럼)
-- 지금은 본문의 모든 참조가 h./hm./pr. 로 한정돼 있고 순수 SELECT 라서 안전하지만,
-- 나중에 누군가 미한정 참조(WHERE/ORDER BY/DML)를 하나만 추가하면 즉시 42702 로 터진다.
-- 이 부류는 2026-03 · 2026-07 두 번 재발했으므로, 방금 join 함수에 건 것과 동일하게
-- `#variable_conflict use_column` 지시자를 예방적으로 걸어 세 번째 재발을 막는다.
-- (본문 로직은 배포본 그대로. 실제 변수는 전부 v_ 접두사라 오작동 위험 없음.)

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
#variable_conflict use_column
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

create or replace function public.search_homeschool_members(
  p_homeschool_id uuid,
  p_query text default '',
  p_limit int default 30
)
returns table (
  user_id uuid,
  email text,
  full_name text,
  roles text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(trim(coalesce(p_query, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 200));
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if p_homeschool_id is null then
    raise exception using errcode = '22023', message = 'HOMESCHOOL_REQUIRED';
  end if;

  if not public.has_homeschool_role(
    p_homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  ) then
    raise exception using errcode = '42501', message = 'INSUFFICIENT_ROLE';
  end if;

  return query
  select
    hm.user_id,
    coalesce(pr.email, ''),
    coalesce(
      nullif(pr.full_name, ''),
      nullif(split_part(coalesce(pr.email, ''), '@', 1), ''),
      hm.user_id::text
    ) as full_name,
    array_agg(distinct hm.role::text order by hm.role::text) as roles
  from public.homeschool_memberships hm
  left join public.profiles pr on pr.id = hm.user_id
  where hm.homeschool_id = p_homeschool_id
    and hm.status = 'ACTIVE'::public.membership_status
    and (
      v_query = ''
      or lower(coalesce(pr.full_name, '')) like '%' || v_query || '%'
      or lower(coalesce(pr.email, '')) like '%' || v_query || '%'
      or lower(hm.user_id::text) like '%' || v_query || '%'
    )
  group by hm.user_id, pr.email, pr.full_name
  order by
    case
      when v_query <> '' and lower(coalesce(pr.full_name, '')) like v_query || '%' then 0
      when v_query <> '' and lower(coalesce(pr.email, '')) like v_query || '%' then 1
      else 2
    end,
    coalesce(nullif(pr.full_name, ''), pr.email, hm.user_id::text)
  limit v_limit;
end;
$$;
revoke all on function public.search_homeschool_members(uuid, text, int) from public;
grant execute on function public.search_homeschool_members(uuid, text, int) to authenticated;
