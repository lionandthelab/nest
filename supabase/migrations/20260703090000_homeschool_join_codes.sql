-- 간편 합류: 홈스쿨 참여 코드 + 역할 선택 + 승인 시 가정 연결
--
-- 새 사용자는 (가입 → 참여 코드 입력 → 역할[학부모/선생님] 선택 → 요청) 만 하고,
-- 관리자가 한 번의 승인으로 멤버십을 만든다. 학부모는 승인 시 관리자가 어느
-- 가정(family)의 보호자인지 연결해 주면, 그 가정의 자녀가 바로 보인다.
-- (가입자는 자녀를 직접 입력하지 않음 — 학교가 이미 가정·자녀를 세팅하는 구조.)

-- 1) 홈스쿨 참여 코드 --------------------------------------------------------
alter table public.homeschools add column if not exists join_code text;

create unique index if not exists uq_homeschools_join_code
  on public.homeschools (upper(join_code)) where join_code is not null;

-- 헷갈리는 문자(0/O/1/I/L) 제외한 6자리 코드.
create or replace function public.gen_join_code()
returns text
language plpgsql
as $$
declare
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_i int;
begin
  loop
    v_code := '';
    for v_i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.homeschools where upper(join_code) = v_code
    );
  end loop;
  return v_code;
end;
$$;

-- 기존 홈스쿨에 코드 백필.
update public.homeschools
set join_code = public.gen_join_code()
where join_code is null;

-- 2) 합류 요청에 희망 역할 컬럼 ---------------------------------------------
alter table public.homeschool_join_requests
  add column if not exists requested_role text
    check (requested_role in ('PARENT', 'TEACHER', 'GUEST_TEACHER'));

-- 3) 코드 → 홈스쿨 조회(비회원 확인용, 대소문자 무시) ------------------------
create or replace function public.resolve_join_code(p_code text)
returns table (homeschool_id uuid, name text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  return query
  select h.id, h.name
  from public.homeschools h
  where h.join_code is not null
    and upper(h.join_code) = upper(trim(p_code))
  limit 1;
end;
$$;
revoke all on function public.resolve_join_code(text) from public;
grant execute on function public.resolve_join_code(text) to authenticated;

-- 4) 코드로 합류 요청(역할 포함, 중복/이미회원 방지) ------------------------
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
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_name text;
  v_hs record;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_role is null or p_role not in ('PARENT', 'TEACHER', 'GUEST_TEACHER') then
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

  insert into public.homeschool_join_requests (
    homeschool_id, requester_user_id, requester_email, requester_name,
    request_note, requested_role, status
  )
  values (
    v_hs.id, v_uid, coalesce(lower(v_email), ''), coalesce(v_name, ''),
    coalesce(trim(p_note), ''), p_role, 'PENDING'
  )
  on conflict (homeschool_id, requester_user_id, status)
  do update set request_note = excluded.request_note,
                requested_role = excluded.requested_role,
                updated_at = now();

  return query select v_hs.id, v_hs.name;
end;
$$;
revoke all on function public.request_join_with_code(text, text, text) from public;
grant execute on function public.request_join_with_code(text, text, text) to authenticated;

-- 5) 한 번에 승인: 멤버십 생성 + (학부모면) 가정 연결 ------------------------
create or replace function public.approve_join_request(
  p_request_id uuid,
  p_role text,
  p_family_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_req record;
begin
  if v_admin is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_role is null or p_role not in
     ('PARENT', 'TEACHER', 'GUEST_TEACHER', 'STAFF', 'HOMESCHOOL_ADMIN') then
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
    'family_id', p_family_id
  );
end;
$$;
grant execute on function public.approve_join_request(uuid, text, uuid) to authenticated;

-- 6) 참여 코드 재발급(관리자) -----------------------------------------------
create or replace function public.rotate_join_code(p_homeschool_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_code text;
begin
  if v_admin is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = p_homeschool_id
      and m.user_id = v_admin
      and m.status = 'ACTIVE'
      and m.role = 'HOMESCHOOL_ADMIN'::public.membership_role
  ) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  v_code := public.gen_join_code();
  update public.homeschools set join_code = v_code where id = p_homeschool_id;
  return v_code;
end;
$$;
grant execute on function public.rotate_join_code(uuid) to authenticated;
