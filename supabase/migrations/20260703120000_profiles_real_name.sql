-- 실명(real_name) 수집
--
-- 배경: 지금까지 회원가입은 '닉네임' 하나만 받아 profiles.full_name 에 저장했다.
-- 사용자가 닉네임(에덴맘·혜경 등)을 넣는 바람에, 엑셀로 만든 교사/감독 프로필을
-- 이름으로 매칭할 수 없었다. 실명을 별도 필드로 받아 매칭을 안정화한다.
-- (소셜 로그인 도입 시에도 동일하게 이 필드에 실명을 채운다.)
--   full_name  = 앱 표시용 닉네임 (기존 유지)
--   real_name  = 실명 (관리자 확인·교사 매칭용, 신규)

alter table public.profiles add column if not exists real_name text;

-- 신규 가입 시 metadata 의 real_name 도 프로필에 복사. 닉네임(full_name)은 기존대로.
-- 이미 실명이 있는 경우(재로그인 등)엔 덮어쓰지 않는다.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, real_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data ->> 'real_name', '')
  )
  on conflict (id) do update
  set email = excluded.email,
      real_name = coalesce(profiles.real_name, excluded.real_name);
  return new;
end;
$$;

-- 가입 요청에 실명 스냅샷을 담아, 관리자 승인 시 교사 프로필과 실명으로 매칭한다.
alter table public.homeschool_join_requests
  add column if not exists requester_real_name text;

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
  v_real text;
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
