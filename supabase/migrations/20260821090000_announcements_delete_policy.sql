-- 공지사항 삭제 정책
--
-- init_nest.sql은 announcements에 select/insert/update 정책만 만들었다. RLS가
-- 켜진 테이블에서 정책이 없는 명령은 "0건 매칭"으로 조용히 성공하므로, 관리자가
-- 신학기에 지난 공지를 정리하려 해도 아무 일도 일어나지 않는 것처럼 보였다.
-- update 정책과 같은 조건(작성자 본인 또는 관리자/스태프)으로 delete를 연다.

drop policy if exists announcements_delete_teacher_admin on public.announcements;
create policy announcements_delete_teacher_admin on public.announcements
for delete using (
  author_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);
