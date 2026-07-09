-- 참여 코드 합류 RPC 의 변수/컬럼 이름 충돌(42702) 수정
--
-- 증상: 학부모가 "합류 요청 보내기"를 누르면
--   PostgrestException(message: column reference "homeschool_id" is ambiguous, code: 42702)
--
-- 원인: request_join_with_code 는 `returns table (homeschool_id uuid, name text)` 로
--   선언돼 homeschool_id / name 이 함수의 OUT 파라미터(=PL/pgSQL 변수)가 된다.
--   본문의 INSERT ... ON CONFLICT (homeschool_id, ...) 에서 같은 이름을 컬럼으로
--   참조하는데, 기본 설정(variable_conflict = error)에서 변수인지 컬럼인지 판별할 수
--   없어 42702 를 던진다. (resolve_join_code 는 순수 SELECT + 전부 `h.` 한정이라
--   지금은 안전하지만, 같은 위험 시그니처라 예방 차원에서 함께 가드를 건다.)
--
--   이 부류는 2026-03 accept_homeschool_invite 에서 이미 한 번 고쳤던 재발 케이스다
--   (20260303150000_invite_rpc_fix.sql).
--
-- 해결: 본문 첫 줄에 `#variable_conflict use_column` 지시자를 추가해, 이름이 겹칠 때
--   항상 "테이블 컬럼"으로 해석하도록 한다. 실제 변수는 전부 v_ 접두사라 오작동
--   가능성이 없고, 반환 컬럼명(homeschool_id, name)이 그대로 유지돼 프론트 변경 불필요.
--   기존 마이그레이션은 수정하지 않고 create or replace 로 새로 덮어쓴다.

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

-- 예방 가드: resolve_join_code 도 같은 위험 시그니처라 지시자를 함께 건다.
create or replace function public.resolve_join_code(p_code text)
returns table (homeschool_id uuid, name text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
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
