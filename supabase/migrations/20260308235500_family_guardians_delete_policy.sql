-- Allow admin/staff to unlink guardian accounts from families.

drop policy if exists family_guardians_delete_admin_staff on public.family_guardians;
create policy family_guardians_delete_admin_staff on public.family_guardians
for delete using (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);
