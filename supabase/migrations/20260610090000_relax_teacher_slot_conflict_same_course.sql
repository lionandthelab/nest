-- Relax teacher time-slot conflict guard to allow combined classes.
--
-- 배경: 홈스쿨은 한 교사가 같은 시간대에 여러 학년(분리된 class_group)을
-- "같은 수업(course)"으로 동시에 지도하는 합반 수업을 운영한다.
-- 기존 enforce_teacher_timeslot_conflict 는 동일 교사가 같은 time_slot 의
-- 서로 다른 세션에 배정되는 것을 무조건 차단하여 합반 표현이 불가능했다.
--
-- 변경: 충돌 대상 세션의 course_id 가 "다를 때만" 차단한다.
--  - 같은 course  → 합반으로 간주하여 허용
--  - 다른 course  → 진짜 이중배정으로 간주하여 기존처럼 차단(TEACHER_SLOT_CONFLICT)

create or replace function public.enforce_teacher_timeslot_conflict()
returns trigger
language plpgsql
as $$
declare
  v_time_slot_id uuid;
  v_course_id uuid;
begin
  select cs.time_slot_id, cs.course_id
    into v_time_slot_id, v_course_id
  from public.class_sessions cs
  where cs.id = new.class_session_id;

  if v_time_slot_id is null then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if exists (
    select 1
    from public.session_teacher_assignments sta
    join public.class_sessions cs on cs.id = sta.class_session_id
    where sta.teacher_profile_id = new.teacher_profile_id
      and cs.time_slot_id = v_time_slot_id
      and cs.status <> 'CANCELED'
      and sta.class_session_id <> new.class_session_id
      and cs.course_id is distinct from v_course_id   -- 같은 수업(합반)은 허용, 다른 수업만 차단
  ) then
    raise exception using
      errcode = '23514',
      message = 'TEACHER_SLOT_CONFLICT',
      detail = 'Teacher is already assigned to a different course in the same time slot.';
  end if;

  return new;
end;
$$;
