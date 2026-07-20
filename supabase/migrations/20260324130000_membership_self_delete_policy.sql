-- Allow members to delete their own membership rows (self-withdrawal).
-- The existing memberships_delete_admin policy only allows HOMESCHOOL_ADMIN,
-- so non-admin members (PARENT, TEACHER, etc.) could not leave a homeschool.

drop policy if exists memberships_delete_self on public.homeschool_memberships;
create policy memberships_delete_self on public.homeschool_memberships
for delete using (
  user_id = auth.uid()
);
