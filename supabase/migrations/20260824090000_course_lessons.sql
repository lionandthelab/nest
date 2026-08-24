-- 수업 회차 내용 (course_lessons)
--
-- 배경: 시간표(class_sessions)는 "요일×교시" 주간 반복 템플릿이라 회차 개념이 없다.
--   그래서 "통합QT 9월 15일 = 창세기 36장(에서의 자손), 담당 리아" 같은 진도표를
--   앱 안에 담을 곳이 없어서 카톡/엑셀로 따로 돌고 있었다.
--
-- 설계: 회차의 주인을 class_sessions 가 아니라 courses(과목)로 잡는다.
--   전교생이 함께 모이는 통합QT/주중예배는 반 14개 × 교시 4개 = class_sessions 56행이다.
--   회차를 세션에 매달면 한 날짜의 진도를 56번 입력해야 한다. 반대로 과목에 매달면
--   날짜당 1행이고, 그 과목이 걸린 모든 반/교시의 시간표 셀에서 같은 내용을 읽는다.
--   반별로 진도가 갈리는 과목은 이 학교에서 이미 과목 자체를 쪼개서 쓴다
--   (수학A/수학B, 영어(민준)/영어(시온), 소리영어(배우리)/소리영어(채리아)).
--
-- 날짜 범위: 학기(term)에 묶지 않는다. course_id + lesson_date 만으로 유일하다.
--   학기는 날짜로 결정되고, 실제 운영에서는 학기 종료일을 넘겨서까지 진도표를
--   먼저 짜두는 일이 흔하다(예: 학기 종료 11/30, 진도표는 12/15까지). term_id 를
--   두면 그런 회차가 제약에 걸리거나 학기 경계에서 사라진다.
--
-- 권한: 조회는 그 홈스쿨 구성원 전체(학생·학부모 포함 — 진도표는 공개 정보다).
--   쓰기는 그 과목을 맡은 교사(세션 배정 또는 반 담임) 또는 ADMIN/STAFF.
--   class_session_changes 와 달리 "자기가 만든 행만" 제약을 두지 않는다. 통합QT처럼
--   여러 교사가 돌아가며 담당하는 과목의 진도표는 공동 편집물이고, 이 테이블에는
--   문자 발송처럼 되돌릴 수 없는 부작용이 없다.

-- =====================================================
-- 1) 테이블
-- =====================================================

create table if not exists public.course_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  -- 그 회차를 진행하는 날짜. 과목 안에서 유일하다.
  lesson_date date not null,
  -- 본문 제목. 예: '창세기 36장'
  title text not null default '',
  -- 부제/괄호 내용. 예: '에서의 자손'
  subtitle text not null default '',
  -- 담당(발표자). 교사 계정이 없는 학부모·학생도 담당이 되므로 자유 텍스트다.
  presenter text not null default '',
  -- 준비물·상세 안내 등 여러 줄 본문.
  content text not null default '',
  -- 원본 진도표의 ✔️ 표시. 담당/내용이 확정됐다는 뜻.
  is_confirmed boolean not null default false,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, lesson_date)
);

create index if not exists idx_course_lessons_course_date
  on public.course_lessons (course_id, lesson_date);

-- =====================================================
-- 2) 헬퍼 (과목 기준 멤버/역할/담당교사)
-- =====================================================
--
-- course_lessons 는 homeschool_id 를 직접 들고 있지 않으므로(과목이 이미 들고 있다)
-- RLS 는 이 세 함수를 통해 과목 → 홈스쿨로 올라가서 판정한다.

create or replace function public.is_course_member(p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.courses c
    where c.id = p_course_id
      and public.is_homeschool_member(c.homeschool_id)
  );
$$;

grant execute on function public.is_course_member(uuid) to authenticated;

create or replace function public.has_course_role(
  p_course_id uuid,
  p_roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.courses c
    where c.id = p_course_id
      and public.has_homeschool_role(c.homeschool_id, p_roles)
  );
$$;

grant execute on function public.has_course_role(uuid, public.membership_role[])
  to authenticated;

-- 담당 교사 = 그 과목의 어떤 세션에든 배정된 교사(MAIN/ASSISTANT) ∪ 그 세션이 걸린 반의 담임.
--
-- ⚠️ is_session_teacher 와 같은 이유로 ACTIVE 멤버십을 반드시 함께 요구한다.
--   teacher_profiles.user_id 는 멤버십을 지워도 남기 때문에, 이 조건이 없으면
--   홈스쿨을 떠난 교사가 계속 진도표를 고칠 수 있다.
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
    where cs.course_id = p_course_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      and public.is_homeschool_member(tp.homeschool_id)
  ) or exists (
    select 1
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.teacher_profiles tp on tp.id = cg.main_teacher_id
    where cs.course_id = p_course_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      and public.is_homeschool_member(tp.homeschool_id)
  );
$$;

grant execute on function public.is_course_teacher(uuid) to authenticated;

-- =====================================================
-- 3) 트리거
-- =====================================================

drop trigger if exists trg_course_lessons_updated_at on public.course_lessons;
create trigger trg_course_lessons_updated_at
before update on public.course_lessons
for each row execute function public.set_updated_at();

-- ARCHIVED 학기 가드는 두지 않는다. 회차는 학기가 아니라 과목+날짜에 매달려 있고,
-- 날짜로 학기를 되짚어 잠그면 학기 경계를 넘긴 회차(종료일 이후 진도)를 저장할 수
-- 없게 된다. 진도표는 학기 구성(반/교시/배정)과 달리 지난 학기에도 보정 입력이 필요하다.

-- =====================================================
-- 4) RLS
-- =====================================================

alter table public.course_lessons enable row level security;

-- 조회: 그 과목이 속한 홈스쿨의 구성원 전체(학생·학부모 포함).
drop policy if exists course_lessons_select_member on public.course_lessons;
create policy course_lessons_select_member on public.course_lessons
for select using (
  public.is_course_member(course_id)
);

drop policy if exists course_lessons_insert_teacher_admin on public.course_lessons;
create policy course_lessons_insert_teacher_admin on public.course_lessons
for insert with check (
  public.is_course_teacher(course_id)
  or public.has_course_role(
    course_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists course_lessons_update_teacher_admin on public.course_lessons;
create policy course_lessons_update_teacher_admin on public.course_lessons
for update using (
  public.is_course_teacher(course_id)
  or public.has_course_role(
    course_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
)
with check (
  public.is_course_teacher(course_id)
  or public.has_course_role(
    course_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists course_lessons_delete_teacher_admin on public.course_lessons;
create policy course_lessons_delete_teacher_admin on public.course_lessons
for delete using (
  public.is_course_teacher(course_id)
  or public.has_course_role(
    course_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);
