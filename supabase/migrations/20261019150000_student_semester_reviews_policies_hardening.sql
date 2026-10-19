-- student_semester_reviews RLS 정책 보강
-- 1) 학생 본인(is_child_self)도 자신의 성찰 소감문(student_reflection)을 조회·작성·수정할 수 있도록 허용
-- 2) 조회(SELECT) 정책을 학생 가시성 규칙(D2)에 맞춰 본인·보호자·교직원 역할로 정밀화
-- 3) authenticated 롤에 테이블 권한(GRANT) 명시

-- 1) SELECT 정책 재작성
drop policy if exists student_semester_reviews_select_member on public.student_semester_reviews;

create policy student_semester_reviews_select_member
  on public.student_semester_reviews for select
  using (
    public.is_child_self(child_id)
    or public.is_child_guardian(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER', 'GUEST_TEACHER', 'PARENT']::public.membership_role[]
    )
  );

-- 2) INSERT 정책 재작성
drop policy if exists student_semester_reviews_insert_authorized on public.student_semester_reviews;

create policy student_semester_reviews_insert_authorized
  on public.student_semester_reviews for insert
  with check (
    public.is_child_self(child_id)
    or public.is_child_guardian(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER']::public.membership_role[]
    )
  );

-- 3) UPDATE 정책 재작성
drop policy if exists student_semester_reviews_update_authorized on public.student_semester_reviews;

create policy student_semester_reviews_update_authorized
  on public.student_semester_reviews for update
  using (
    public.is_child_self(child_id)
    or public.is_child_guardian(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER']::public.membership_role[]
    )
  )
  with check (
    public.is_child_self(child_id)
    or public.is_child_guardian(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER']::public.membership_role[]
    )
  );

-- 4) authenticated 권한 보장
grant select, insert, update, delete on public.student_semester_reviews to authenticated;
