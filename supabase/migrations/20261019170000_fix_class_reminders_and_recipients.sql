-- 수업 시간 알림(nest-remind) 누락 원인 해결:
-- 1) 학기 생성 기본값을 ACTIVE 로 전환하고, 현재 진행 중인 DRAFT 학기를 ACTIVE 로 승격
-- 2) 단일 반(1인/가정 홈스쿨 등) 학기에서 미배정 자녀를 자동으로 해당 반에 편성
-- 3) recipients_for_class_session 에서 반 편성(class_enrollments)이 아직 없는
--    1인/가정 홈스쿨의 보호자·관리자·학생 계정도 알림 수신자로 해석되도록 보강

-- =====================================================
-- 1) terms.status 기본값 ACTIVE 전환 및 진행 학기 승격
-- =====================================================

alter table public.terms
  alter column status set default 'ACTIVE';

update public.terms
set status = 'ACTIVE'
where status = 'DRAFT'
  and end_date >= current_date;

-- =====================================================
-- 2) 단일 반 학기의 미편성 자녀 자동 반 배정
-- =====================================================

insert into public.class_enrollments (class_group_id, child_id)
select single_group.class_group_id, c.id
from (
  select cg.term_id, t.homeschool_id, (array_agg(cg.id))[1] as class_group_id
  from public.class_groups cg
  join public.terms t on t.id = cg.term_id
  where t.status <> 'ARCHIVED'
  group by cg.term_id, t.homeschool_id
  having count(*) = 1
) single_group
join public.families f on f.homeschool_id = single_group.homeschool_id
join public.children c on c.family_id = f.id and c.status = 'ACTIVE'
on conflict (class_group_id, child_id) do nothing;

-- =====================================================
-- 3) recipients_for_class_session 보강 (1인/가정 홈스쿨 폴백 포함)
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

    -- 보호자 폴백(반 편성이 아직 없는 1인/가정 홈스쿨): 홈스쿨 내 보호자 계정
    select fg.user_id as user_id, 'GUARDIAN'::text as recipient_kind
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.terms t on t.id = cg.term_id
    join public.families f on f.homeschool_id = t.homeschool_id
    join public.family_guardians fg on fg.family_id = f.id
    where cs.id = p_class_session_id
      and v_guardians
      and not exists (
        select 1
        from public.class_enrollments ce0
        where ce0.class_group_id = cs.class_group_id
      )

    union all

    -- 보호자/운영자 폴백(반 편성이 아직 없는 1인/가정 홈스쿨): ACTIVE 관리자·학부모 멤버십
    select hm.user_id as user_id, 'GUARDIAN'::text as recipient_kind
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.terms t on t.id = cg.term_id
    join public.homeschool_memberships hm
      on hm.homeschool_id = t.homeschool_id
     and hm.status = 'ACTIVE'
     and hm.role in ('HOMESCHOOL_ADMIN', 'PARENT')
    where cs.id = p_class_session_id
      and v_guardians
      and not exists (
        select 1
        from public.class_enrollments ce0
        where ce0.class_group_id = cs.class_group_id
      )

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

    -- 학생 폴백(반 편성이 아직 없는 1인/가정 홈스쿨): 홈스쿨 내 계정 연결된 학생
    select c.user_id as user_id, 'STUDENT'::text as recipient_kind
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.terms t on t.id = cg.term_id
    join public.families f on f.homeschool_id = t.homeschool_id
    join public.children c on c.family_id = f.id and c.status = 'ACTIVE'
    where cs.id = p_class_session_id
      and c.user_id is not null
      and v_students
      and not exists (
        select 1
        from public.class_enrollments ce0
        where ce0.class_group_id = cs.class_group_id
      )

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

revoke all on function public.recipients_for_class_session(uuid, boolean, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.recipients_for_class_session(uuid, boolean, boolean, boolean)
  to service_role;
