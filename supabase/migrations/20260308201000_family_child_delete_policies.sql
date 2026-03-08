begin;

drop policy if exists families_delete_admin_staff on public.families;
create policy families_delete_admin_staff on public.families
for delete using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists children_delete_admin_staff on public.children;
create policy children_delete_admin_staff on public.children
for delete using (
  public.has_family_role(
    family_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

commit;
