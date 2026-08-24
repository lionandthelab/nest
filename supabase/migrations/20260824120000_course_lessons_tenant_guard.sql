-- 수업 회차 내용 후속 보정 (course_lessons)
--
-- 20260824090000_course_lessons.sql 의 두 가지를 고친다. 기존 마이그레이션 파일은
-- 수정하지 않는다는 규칙(CLAUDE.md §4)에 따라 새 파일로 올린다.

-- =====================================================
-- 1) is_course_teacher 의 테넌트 경계 고정
-- =====================================================
--
-- 문제: 두 EXISTS 분기가 모두 `is_homeschool_member(tp.homeschool_id)` 만 확인했다.
--   이건 "교사 프로필이 속한 홈스쿨"이지 "그 과목이 속한 홈스쿨"이 아니다.
--   반면 조회 정책은 `courses.homeschool_id` 를 기준으로 잡으므로, 읽기 경계와
--   쓰기 경계가 서로 다른 컬럼에 걸려 있었다.
--
--   class_sessions 에는 "course 와 class_group 이 같은 홈스쿨이어야 한다"는 제약이
--   없다. 그래서 B 홈스쿨 관리자가 A 홈스쿨의 course_id 를 알아내 자기 반에
--   class_session 을 하나 만들고(그 INSERT 는 class_group 쪽만 검사한다) 자기
--   교사 프로필을 배정하면, is_course_teacher(A의 과목) 이 true 가 되어 A 학교
--   진도표를 INSERT/UPDATE/DELETE 할 수 있었다. 읽기는 여전히 막히지만 남의 학교
--   진도표를 지우거나 바꿔 쓰는 것은 가능한 상태였다.
--
-- 수정: 두 분기 모두 과목의 홈스쿨을 조인해 `tp.homeschool_id = c.homeschool_id`
--   를 요구한다. 이제 쓰기 경계가 조회 정책과 같은 컬럼(courses.homeschool_id)에
--   고정된다.
--
-- 학기 범위에 대하여: 이 함수는 의도적으로 학기를 가리지 않는다. courses 는
--   `unique (homeschool_id, name)` 이라 학기마다 재사용되는 한 행이고, 진도표는
--   지난 학기 보정 입력이 필요하다(그래서 ARCHIVED 가드도 두지 않았다). 즉
--   **과거 학기에 배정된 적이 있는 교사도 계속 담당으로 인정된다.** 같은 홈스쿨
--   안의 협업 편집을 전제로 한 선택이며, 이 주석이 그 사실을 명시한다.

create or replace function public.is_course_teacher(p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_sessions cs
    join public.session_teacher_assignments sta
      on sta.class_session_id = cs.id
    join public.teacher_profiles tp on tp.id = sta.teacher_profile_id
    join public.courses c on c.id = cs.course_id
    where cs.course_id = p_course_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      -- 교사 프로필과 과목이 같은 홈스쿨이어야 한다(테넌트 경계).
      and tp.homeschool_id = c.homeschool_id
      and public.is_homeschool_member(c.homeschool_id)
  ) or exists (
    select 1
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.teacher_profiles tp on tp.id = cg.main_teacher_id
    join public.courses c on c.id = cs.course_id
    where cs.course_id = p_course_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      and tp.homeschool_id = c.homeschool_id
      and public.is_homeschool_member(c.homeschool_id)
  );
$$;

grant execute on function public.is_course_teacher(uuid) to authenticated;

-- =====================================================
-- 2) 중복 인덱스 제거
-- =====================================================
--
-- `unique (course_id, lesson_date)` 가 이미 같은 순서의 btree 인덱스를 만든다.
-- 20260824090000 이 추가한 idx_course_lessons_course_date 는 완전히 같은 컬럼·같은
-- 순서라 플래너가 절대 고르지 않고, 쓰기마다 인덱스 두 개를 유지하는 비용만 남는다.
-- (선행 사례인 class_session_changes 는 unique 제약이 없어서 인덱스가 필요했다.)

drop index if exists public.idx_course_lessons_course_date;
