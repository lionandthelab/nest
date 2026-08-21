-- 학생 계정: 아이 본인이 가입한 계정을 children 레코드에 연결한다.
--
-- 설계
--   * children.user_id (nullable, on delete set null) + partial unique index
--     → teacher_profiles.user_id 와 완전히 동일한 패턴. 자녀 1명 ↔ 계정 1개.
--   * 합류 흐름은 기존 참여 코드(request_join_with_code)를 그대로 재사용한다.
--     학생은 역할 'STUDENT' 로 요청하고, 관리자가 승인할 때 어느 자녀인지 고른다.
--   * 가시성(D2): 학생은 "본인 + 본인 가정" 밖의 children / families /
--     family_guardians 를 볼 수 없다. 기존 5개 역할
--     (HOMESCHOOL_ADMIN / STAFF / TEACHER / GUEST_TEACHER / PARENT)의 가시성은
--     100% 그대로 유지한다.
--     → 기존 SELECT 정책을 같은 이름으로 다시 만들되, 술어를
--       "본인 or 보호자 or has_*_role(5개 역할)" 로 바꾼다. is_homeschool_member 는
--       STUDENT 도 통과시키므로 역할 화이트리스트로 치환하는 것이다.
--     → RESTRICTIVE 정책은 쓰지 않는다(다른 permissive 정책과 AND 로 묶여 관리자
--       조회가 깨진다). 반드시 permissive OR 술어여야 한다.
--   * 시간표(class_sessions / time_slots / class_groups / class_enrollments)는
--     기존대로 전교 공개를 유지한다. 학생도 시간표는 그대로 본다.
--   * children 의 INSERT/UPDATE/DELETE 정책은 손대지 않는다.

-- =====================================================
-- 1) children.user_id
-- =====================================================

alter table public.children
  add column if not exists user_id uuid references auth.users(id) on delete set null;

comment on column public.children.user_id is
  '학생 본인 계정(auth.users). null = 아직 계정 미연결.';

-- 계정 1개는 자녀 1명에만 연결된다. 이 부분 인덱스는 predicate 가 함의되므로
-- `where user_id = $1` 조회 인덱스로도 그대로 사용된다(별도 인덱스 불필요).
create unique index if not exists uq_children_user_id
  on public.children (user_id)
  where user_id is not null;

-- =====================================================
-- 2) 신규 RLS 헬퍼
-- =====================================================

create or replace function public.is_child_self(p_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children c
    where c.id = p_child_id
      and c.user_id is not null
      and c.user_id = auth.uid()
  );
$$;

create or replace function public.is_child_guardian(p_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children c
    join public.family_guardians g on g.family_id = c.family_id
    where c.id = p_child_id
      and g.user_id = auth.uid()
  );
$$;

create or replace function public.current_user_child_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.children c
  where c.user_id is not null
    and c.user_id = auth.uid();
$$;

create or replace function public.is_family_of_current_user(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_guardians g
    where g.family_id = p_family_id
      and g.user_id = auth.uid()
  ) or exists (
    select 1
    from public.children c
    where c.family_id = p_family_id
      and c.user_id is not null
      and c.user_id = auth.uid()
  );
$$;

grant execute on function public.is_child_self(uuid) to authenticated;
grant execute on function public.is_child_guardian(uuid) to authenticated;
grant execute on function public.current_user_child_ids() to authenticated;
grant execute on function public.is_family_of_current_user(uuid) to authenticated;

-- =====================================================
-- 3) 가시성 좁히기 (STUDENT 만 좁아지고 기존 5개 역할은 동일)
-- =====================================================

-- children: 기존 술어 = public.is_child_member(id)
drop policy if exists children_select_member on public.children;
create policy children_select_member on public.children
for select using (
  public.is_child_self(id)
  or public.is_child_guardian(id)
  or public.has_child_role(
    id,
    array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER', 'GUEST_TEACHER', 'PARENT']::public.membership_role[]
  )
);

-- families: 기존 술어 = public.is_homeschool_member(homeschool_id)
drop policy if exists families_select_member on public.families;
create policy families_select_member on public.families
for select using (
  public.is_family_of_current_user(id)
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER', 'GUEST_TEACHER', 'PARENT']::public.membership_role[]
  )
);

-- family_guardians: 기존 술어 = public.is_family_member(family_id)
drop policy if exists family_guardians_select_member on public.family_guardians;
create policy family_guardians_select_member on public.family_guardians
for select using (
  user_id = auth.uid()
  or public.is_family_of_current_user(family_id)
  or public.has_family_role(
    family_id,
    array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER', 'GUEST_TEACHER', 'PARENT']::public.membership_role[]
  )
);

-- =====================================================
-- 4) 합류 요청에 STUDENT 역할 허용
-- =====================================================

-- requested_role CHECK 제약 교체. 제약 이름이 환경마다 다를 수 있어 정의문으로 찾는다.
do $$
declare
  v_names text[];
  v_name text;
begin
  -- 카탈로그를 순회하면서 DDL 을 실행하지 않도록 이름을 먼저 모은다.
  select coalesce(array_agg(con.conname::text), '{}'::text[])
    into v_names
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'homeschool_join_requests'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%requested_role%';

  foreach v_name in array v_names loop
    execute format(
      'alter table public.homeschool_join_requests drop constraint %I',
      v_name
    );
  end loop;
end
$$;

alter table public.homeschool_join_requests
  add constraint homeschool_join_requests_requested_role_check
  check (
    requested_role is null
    or requested_role in ('PARENT', 'TEACHER', 'GUEST_TEACHER', 'STUDENT')
  );

-- 참여 코드 합류 RPC: 화이트리스트에 STUDENT 추가.
-- (20260709120000 의 정의를 그대로 옮기고 역할 목록만 확장. #variable_conflict
--  use_column 지시자는 42702 재발 방지를 위해 반드시 유지한다.)
create or replace function public.request_join_with_code(
  p_code text,
  p_role text,
  p_note text default ''
)
returns table (homeschool_id uuid, name text)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_name text;
  v_real text;
  v_hs record;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_role is null or p_role not in ('PARENT', 'TEACHER', 'GUEST_TEACHER', 'STUDENT') then
    raise exception using errcode = '22023', message = 'INVALID_ROLE';
  end if;

  select h.id, h.name into v_hs
  from public.homeschools h
  where h.join_code is not null
    and upper(h.join_code) = upper(trim(p_code))
  limit 1;
  if v_hs is null then
    raise exception using errcode = 'P0002', message = 'CODE_NOT_FOUND';
  end if;

  if exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_hs.id
      and m.user_id = v_uid
      and m.status = 'ACTIVE'
  ) then
    raise exception using errcode = 'P0001', message = 'ALREADY_MEMBER';
  end if;

  select email into v_email from auth.users where id = v_uid;
  select coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', '')
    into v_name
  from auth.users where id = v_uid;
  -- 실명: metadata 우선, 없으면 profiles.real_name.
  select coalesce(
           nullif(u.raw_user_meta_data->>'real_name', ''),
           nullif(pr.real_name, ''),
           ''
         )
    into v_real
  from auth.users u
  left join public.profiles pr on pr.id = u.id
  where u.id = v_uid;

  insert into public.homeschool_join_requests (
    homeschool_id, requester_user_id, requester_email, requester_name,
    requester_real_name, request_note, requested_role, status
  )
  values (
    v_hs.id, v_uid, coalesce(lower(v_email), ''), coalesce(v_name, ''),
    coalesce(v_real, ''), coalesce(trim(p_note), ''), p_role, 'PENDING'
  )
  on conflict (homeschool_id, requester_user_id, status)
  do update set request_note = excluded.request_note,
                requested_role = excluded.requested_role,
                requester_real_name = excluded.requester_real_name,
                updated_at = now();

  return query select v_hs.id, v_hs.name;
end;
$$;
revoke all on function public.request_join_with_code(text, text, text) from public;
grant execute on function public.request_join_with_code(text, text, text) to authenticated;

-- =====================================================
-- 5) 승인 RPC: 4번째 인자(p_child_id) 추가
-- =====================================================
--
-- 기존 3-arg 시그니처는 제거한다. default 인자만 늘리면 두 시그니처가 공존해
-- "function is not unique" 모호성이 생기기 때문이다(프론트는 4-arg 로 호출한다).

drop function if exists public.approve_join_request(uuid, text, uuid);

create or replace function public.approve_join_request(
  p_request_id uuid,
  p_role text,
  p_family_id uuid default null,
  p_child_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_req record;
  v_child_homeschool_id uuid;
  v_linked int := 0;
begin
  if v_admin is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_role is null or p_role not in
     ('PARENT', 'TEACHER', 'GUEST_TEACHER', 'STAFF', 'HOMESCHOOL_ADMIN', 'STUDENT') then
    raise exception using errcode = '22023', message = 'INVALID_ROLE';
  end if;

  select * into v_req
  from public.homeschool_join_requests
  where id = p_request_id and status = 'PENDING';
  if v_req is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;

  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_req.homeschool_id
      and m.user_id = v_admin
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  ) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;

  -- 학생 승인: 멤버십을 만들기 전에 자녀 연결 가능 여부를 먼저 검증한다.
  if p_role = 'STUDENT' then
    if p_child_id is null then
      raise exception using
        errcode = '22023',
        message = 'CHILD_REQUIRED',
        detail = '학생 계정을 연결할 자녀를 선택해 주세요.';
    end if;

    select f.homeschool_id into v_child_homeschool_id
    from public.children c
    join public.families f on f.id = c.family_id
    where c.id = p_child_id;

    if v_child_homeschool_id is null or v_child_homeschool_id <> v_req.homeschool_id then
      raise exception using
        errcode = '22023',
        message = 'CHILD_HOMESCHOOL_MISMATCH',
        detail = '선택한 자녀가 이 홈스쿨 소속이 아닙니다.';
    end if;
  end if;

  insert into public.homeschool_memberships (homeschool_id, user_id, role, status)
  values (
    v_req.homeschool_id, v_req.requester_user_id,
    p_role::public.membership_role, 'ACTIVE'::public.membership_status
  )
  on conflict (homeschool_id, user_id, role)
  do update set status = 'ACTIVE'::public.membership_status;

  if p_role = 'PARENT' and p_family_id is not null then
    if not exists (
      select 1 from public.families f
      where f.id = p_family_id and f.homeschool_id = v_req.homeschool_id
    ) then
      raise exception using errcode = '22023', message = 'FAMILY_NOT_IN_HOMESCHOOL';
    end if;
    insert into public.family_guardians (family_id, user_id, guardian_type)
    select p_family_id, v_req.requester_user_id, 'GUARDIAN'
    where not exists (
      select 1 from public.family_guardians g
      where g.family_id = p_family_id and g.user_id = v_req.requester_user_id
    );
  end if;

  if p_role = 'STUDENT' then
    update public.children
    set user_id = v_req.requester_user_id
    where id = p_child_id
      and user_id is null;
    get diagnostics v_linked = row_count;

    if v_linked = 0 then
      raise exception using
        errcode = '22023',
        message = 'CHILD_ALREADY_LINKED',
        detail = '이미 다른 계정이 연결된 자녀입니다.';
    end if;
  end if;

  update public.homeschool_join_requests
  set status = 'APPROVED',
      reviewed_by_user_id = v_admin,
      reviewed_at = now(),
      updated_at = now()
  where id = p_request_id;

  return jsonb_build_object(
    'homeschool_id', v_req.homeschool_id,
    'user_id', v_req.requester_user_id,
    'role', p_role,
    'family_id', p_family_id,
    'child_id', case when p_role = 'STUDENT' then p_child_id else null end
  );
end;
$$;

grant execute on function public.approve_join_request(uuid, text, uuid, uuid) to authenticated;

-- =====================================================
-- 6) 관리자용 자녀 계정 연결/해제 RPC
-- =====================================================
--
-- 합류 승인 밖에서도(이미 멤버인 학생, 잘못 연결한 경우 등) 관리자가 직접
-- 자녀 ↔ 계정을 붙이고 뗄 수 있어야 한다.

create or replace function public.link_child_account(
  p_child_id uuid,
  p_user_id uuid
)
returns public.children
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_homeschool_id uuid;
  v_row public.children%rowtype;
begin
  if v_admin is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select f.homeschool_id into v_homeschool_id
  from public.children c
  join public.families f on f.id = c.family_id
  where c.id = p_child_id;

  if v_homeschool_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'CHILD_NOT_FOUND',
      detail = '자녀를 찾을 수 없습니다.';
  end if;

  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_homeschool_id
      and m.user_id = v_admin
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  ) then
    raise exception using
      errcode = '42501',
      message = 'FORBIDDEN',
      detail = '관리자 또는 운영진만 계정을 연결할 수 있습니다.';
  end if;

  if p_user_id is null then
    raise exception using
      errcode = '22023',
      message = 'USER_REQUIRED',
      detail = '연결할 계정을 선택해 주세요.';
  end if;

  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_homeschool_id
      and m.user_id = p_user_id
      and m.status = 'ACTIVE'
  ) then
    raise exception using
      errcode = '22023',
      message = 'USER_NOT_MEMBER',
      detail = '이 홈스쿨의 활성 구성원이 아닌 계정입니다.';
  end if;

  if exists (
    select 1 from public.children c
    where c.user_id = p_user_id
      and c.id <> p_child_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'USER_ALREADY_LINKED',
      detail = '이 계정은 이미 다른 자녀에 연결되어 있습니다.';
  end if;

  -- 학생 멤버십이 없으면 함께 부여한다(기존 역할은 건드리지 않음).
  insert into public.homeschool_memberships (homeschool_id, user_id, role, status)
  values (v_homeschool_id, p_user_id, 'STUDENT'::public.membership_role, 'ACTIVE'::public.membership_status)
  on conflict (homeschool_id, user_id, role) do nothing;

  update public.children
  set user_id = p_user_id
  where id = p_child_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.link_child_account(uuid, uuid) to authenticated;

create or replace function public.unlink_child_account(p_child_id uuid)
returns public.children
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_homeschool_id uuid;
  v_row public.children%rowtype;
begin
  if v_admin is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select f.homeschool_id into v_homeschool_id
  from public.children c
  join public.families f on f.id = c.family_id
  where c.id = p_child_id;

  if v_homeschool_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'CHILD_NOT_FOUND',
      detail = '자녀를 찾을 수 없습니다.';
  end if;

  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_homeschool_id
      and m.user_id = v_admin
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  ) then
    raise exception using
      errcode = '42501',
      message = 'FORBIDDEN',
      detail = '관리자 또는 운영진만 계정 연결을 해제할 수 있습니다.';
  end if;

  update public.children
  set user_id = null
  where id = p_child_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.unlink_child_account(uuid) to authenticated;
