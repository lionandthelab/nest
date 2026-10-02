-- 학기별 아동 학습 포트폴리오 및 종합의견 (student_semester_reviews)
--
-- 한 학기를 돌아보며 교사 종합의견, 학부모 관찰 총평, 학생 성찰 소감문,
-- 출결 특기사항을 저장하고, 포트폴리오 PDF 생성 시 이를 불러와 생활기록부 및
-- 포트폴리오의 "행동특성 및 종합의견" 섹션에 수록한다.

create table if not exists public.student_semester_reviews (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  term_id uuid not null references public.terms(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  teacher_evaluation text not null default '',
  parent_evaluation text not null default '',
  student_reflection text not null default '',
  attendance_note text not null default '',
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint uq_student_semester_reviews_term_child unique (term_id, child_id)
);

create index if not exists idx_student_semester_reviews_hs
  on public.student_semester_reviews (homeschool_id);

create index if not exists idx_student_semester_reviews_child
  on public.student_semester_reviews (child_id, term_id);

-- updated_at 자동 갱신 트리거
drop trigger if exists trg_student_semester_reviews_updated_at on public.student_semester_reviews;
create trigger trg_student_semester_reviews_updated_at
  before update on public.student_semester_reviews
  for each row execute function public.set_updated_at();

-- RLS 활성화
alter table public.student_semester_reviews enable row level security;

-- 조회: 홈스쿨 회원 전체(교사, 부모, 관리자 등)
drop policy if exists student_semester_reviews_select_member on public.student_semester_reviews;
create policy student_semester_reviews_select_member
  on public.student_semester_reviews for select
  using (is_homeschool_member(homeschool_id));

-- 생성: 관리자, 스태프, 교사 또는 해당 아동의 보호자
drop policy if exists student_semester_reviews_insert_authorized on public.student_semester_reviews;
create policy student_semester_reviews_insert_authorized
  on public.student_semester_reviews for insert
  with check (
    has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER']::public.membership_role[])
    or exists (
      select 1 from public.family_guardians fg
      join public.children c on c.family_id = fg.family_id
      where c.id = student_semester_reviews.child_id
        and fg.user_id = auth.uid()
    )
  );

-- 수정: 관리자, 스태프, 교사 또는 해당 아동의 보호자
drop policy if exists student_semester_reviews_update_authorized on public.student_semester_reviews;
create policy student_semester_reviews_update_authorized
  on public.student_semester_reviews for update
  using (
    has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER']::public.membership_role[])
    or exists (
      select 1 from public.family_guardians fg
      join public.children c on c.family_id = fg.family_id
      where c.id = student_semester_reviews.child_id
        and fg.user_id = auth.uid()
    )
  );

-- 삭제: 관리자 및 스태프
drop policy if exists student_semester_reviews_delete_admin_staff on public.student_semester_reviews;
create policy student_semester_reviews_delete_admin_staff
  on public.student_semester_reviews for delete
  using (
    has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  );
