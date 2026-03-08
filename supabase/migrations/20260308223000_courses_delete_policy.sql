-- Allow homeschool admin/staff to delete courses.
-- Deletion still respects FK restrictions (in-use courses are blocked).

drop policy if exists courses_delete_admin_staff on public.courses;
create policy courses_delete_admin_staff on public.courses
for delete using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);
