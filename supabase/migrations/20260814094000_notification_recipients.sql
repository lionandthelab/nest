-- 알림 수신자 해석 함수 (nest-notify Edge Function 전용)
--
-- 원칙(D3): 클라이언트는 수신자를 절대 지정하지 않는다. 도메인 이벤트
--   {event, id} 만 서버로 보내고, 서버가 이 함수들로 수신자를 해석·인가한다.
--   그래야 "임의의 전화번호로 문자를 쏘는" 오남용 경로가 원천적으로 없다.
--
-- 반환은 user_id 목록이며, 전화번호는 호출 측(Edge Function)이 profiles.phone
--   (20260814089000 에서 채움)에서 조회한다.
--
-- 함정 주의: `returns table (user_id uuid, ...)` 는 user_id 를 OUT 파라미터(=변수)로
--   만들기 때문에, 본문에서 같은 이름을 미한정으로 참조하면 42702(ambiguous)가 난다.
--   이 레포에서 이미 두 번 재발한 부류라 본문 첫 줄에 `#variable_conflict use_column`
--   을 넣고 지역변수는 전부 v_ 접두사를 쓴다.
--
-- 인가: 이 두 함수는 **service_role 전용**이다(파일 하단 revoke/grant 참고).
--   Edge Function 은 이 레포의 관례상 service_role 클라이언트로 DB에 접근하므로
--   (auth.uid() = null) service_role JWT 로 호출된 경우를 통과시킨다.
--   함수 본문의 "홈스쿨 구성원" 검사는 실행 권한이 실수로 넓어졌을 때를 대비한
--   2차 방어선이며, 1차 방어선은 EXECUTE 권한 자체다.

-- =====================================================
-- 0) service_role 호출 판별
-- =====================================================

create or replace function public.is_service_role_call()
returns boolean
language plpgsql
stable
as $$
declare
  v_claims text;
begin
  v_claims := coalesce(current_setting('request.jwt.claims', true), '');
  if v_claims = '' then
    return false;
  end if;
  return coalesce((v_claims::jsonb ->> 'role') = 'service_role', false);
exception
  when others then
    return false;
end;
$$;

-- =====================================================
-- 1) 수업 회차 기준 수신자
-- =====================================================

create or replace function public.recipients_for_class_session(
  p_class_session_id uuid,
  p_include_guardians boolean default true,
  p_include_students boolean default true,
  p_include_teachers boolean default false
)
returns table (user_id uuid, recipient_kind text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_guardians boolean := coalesce(p_include_guardians, true);
  v_students boolean := coalesce(p_include_students, true);
  v_teachers boolean := coalesce(p_include_teachers, false);
begin
  if not public.is_service_role_call() then
    if v_uid is null then
      raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if not public.is_class_session_member(p_class_session_id) then
      raise exception using
        errcode = '42501',
        message = 'FORBIDDEN',
        detail = '이 수업의 알림 수신자를 조회할 권한이 없습니다.';
    end if;
  end if;

  return query
  select distinct v.user_id, v.recipient_kind
  from (
    -- 보호자: 수업 → 반 편성 → 자녀(ACTIVE) → 가정 → 보호자 계정
    select fg.user_id as user_id, 'GUARDIAN'::text as recipient_kind
    from public.class_sessions cs
    join public.class_enrollments ce on ce.class_group_id = cs.class_group_id
    join public.children c on c.id = ce.child_id and c.status = 'ACTIVE'
    join public.family_guardians fg on fg.family_id = c.family_id
    where cs.id = p_class_session_id
      and v_guardians

    union all

    -- 학생 본인: 같은 경로의 children.user_id (계정 연결된 학생만)
    select c.user_id as user_id, 'STUDENT'::text as recipient_kind
    from public.class_sessions cs
    join public.class_enrollments ce on ce.class_group_id = cs.class_group_id
    join public.children c on c.id = ce.child_id and c.status = 'ACTIVE'
    where cs.id = p_class_session_id
      and c.user_id is not null
      and v_students

    union all

    -- 담당 교사: 세션 배정(MAIN/ASSISTANT)
    select tp.user_id as user_id, 'TEACHER'::text as recipient_kind
    from public.session_teacher_assignments sta
    join public.teacher_profiles tp on tp.id = sta.teacher_profile_id
    where sta.class_session_id = p_class_session_id
      and tp.user_id is not null
      and v_teachers

    union all

    -- 담당 교사: 반 담임
    select tp.user_id as user_id, 'TEACHER'::text as recipient_kind
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.teacher_profiles tp on tp.id = cg.main_teacher_id
    where cs.id = p_class_session_id
      and tp.user_id is not null
      and v_teachers
  ) v;
end;
$$;

-- ⚠️ 클라이언트에는 절대 열어주지 않는다(D3: 수신자 해석은 서버 전용).
--   이 함수는 security definer 라 RLS 를 우회해 "그 반 학생·보호자 계정 uuid 전체"를
--   돌려준다. authenticated 에 열어두면 STUDENT 멤버십만 가진 계정이 직접 호출해
--   같은 반 다른 가정의 보호자·학생 계정 uuid 를 수집할 수 있고, 이는 D2(학생 격리)를
--   무력화한다. 프론트엔드는 이 RPC 를 호출하지 않으며(도메인 이벤트만 보낸다),
--   실제 호출자는 nest-notify Edge Function 의 service_role 클라이언트뿐이다.
--   Supabase 기본 권한(default privileges)이 anon/authenticated 에도 EXECUTE 를 주므로
--   PUBLIC 뿐 아니라 두 역할에서 명시적으로 회수해야 한다.
revoke all on function public.recipients_for_class_session(uuid, boolean, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.recipients_for_class_session(uuid, boolean, boolean, boolean)
  to service_role;

-- =====================================================
-- 2) 결석 신고 기준 수신자 (그 수업의 담당 교사들)
-- =====================================================

create or replace function public.recipients_for_absence_report(p_report_id uuid)
returns table (user_id uuid, recipient_kind text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_class_session_id uuid;
begin
  select r.class_session_id
    into v_class_session_id
  from public.absence_reports r
  where r.id = p_report_id;

  if v_class_session_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'REPORT_NOT_FOUND',
      detail = '결석 신고를 찾을 수 없습니다.';
  end if;

  if not public.is_service_role_call() then
    if v_uid is null then
      raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if not public.is_class_session_member(v_class_session_id) then
      raise exception using
        errcode = '42501',
        message = 'FORBIDDEN',
        detail = '이 결석 신고의 알림 수신자를 조회할 권한이 없습니다.';
    end if;
  end if;

  return query
  select distinct v.user_id, v.recipient_kind
  from (
    select tp.user_id as user_id, 'TEACHER'::text as recipient_kind
    from public.session_teacher_assignments sta
    join public.teacher_profiles tp on tp.id = sta.teacher_profile_id
    where sta.class_session_id = v_class_session_id
      and tp.user_id is not null

    union all

    select tp.user_id as user_id, 'TEACHER'::text as recipient_kind
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.teacher_profiles tp on tp.id = cg.main_teacher_id
    where cs.id = v_class_session_id
      and tp.user_id is not null
  ) v;
end;
$$;

-- 위와 동일한 이유로 service_role 전용.
revoke all on function public.recipients_for_absence_report(uuid)
  from public, anon, authenticated;
grant execute on function public.recipients_for_absence_report(uuid)
  to service_role;
