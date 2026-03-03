-- Fix children insert/update RLS evaluation for homeschool admin/staff

drop policy if exists children_insert_admin_staff on public.children;
create policy children_insert_admin_staff on public.children
for insert with check (
  exists (
    select 1
    from public.families f
    join public.homeschool_memberships m
      on m.homeschool_id = f.homeschool_id
    where f.id = family_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists children_update_admin_staff on public.children;
create policy children_update_admin_staff on public.children
for update using (
  exists (
    select 1
    from public.families f
    join public.homeschool_memberships m
      on m.homeschool_id = f.homeschool_id
    where f.id = family_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
)
with check (
  exists (
    select 1
    from public.families f
    join public.homeschool_memberships m
      on m.homeschool_id = f.homeschool_id
    where f.id = family_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);
