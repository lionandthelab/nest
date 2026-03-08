drop policy if exists teacher_profiles_delete_admin_staff on public.teacher_profiles;
create policy teacher_profiles_delete_admin_staff on public.teacher_profiles
for delete using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);
