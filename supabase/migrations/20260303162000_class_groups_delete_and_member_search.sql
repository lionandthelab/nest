-- Enable class group delete for admin/staff and add member directory search RPC.

drop policy if exists class_groups_delete_admin_staff on public.class_groups;
create policy class_groups_delete_admin_staff on public.class_groups
for delete
using (
  public.has_term_role(
    term_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

create or replace function public.search_homeschool_members(
  p_homeschool_id uuid,
  p_query text default '',
  p_limit int default 30
)
returns table (
  user_id uuid,
  email text,
  full_name text,
  roles text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(trim(coalesce(p_query, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 200));
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if p_homeschool_id is null then
    raise exception using errcode = '22023', message = 'HOMESCHOOL_REQUIRED';
  end if;

  if not public.has_homeschool_role(
    p_homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  ) then
    raise exception using errcode = '42501', message = 'INSUFFICIENT_ROLE';
  end if;

  return query
  select
    hm.user_id,
    coalesce(pr.email, ''),
    coalesce(
      nullif(pr.full_name, ''),
      nullif(split_part(coalesce(pr.email, ''), '@', 1), ''),
      hm.user_id::text
    ) as full_name,
    array_agg(distinct hm.role::text order by hm.role::text) as roles
  from public.homeschool_memberships hm
  left join public.profiles pr on pr.id = hm.user_id
  where hm.homeschool_id = p_homeschool_id
    and hm.status = 'ACTIVE'::public.membership_status
    and (
      v_query = ''
      or lower(coalesce(pr.full_name, '')) like '%' || v_query || '%'
      or lower(coalesce(pr.email, '')) like '%' || v_query || '%'
      or lower(hm.user_id::text) like '%' || v_query || '%'
    )
  group by hm.user_id, pr.email, pr.full_name
  order by
    case
      when v_query <> '' and lower(coalesce(pr.full_name, '')) like v_query || '%' then 0
      when v_query <> '' and lower(coalesce(pr.email, '')) like v_query || '%' then 1
      else 2
    end,
    coalesce(nullif(pr.full_name, ''), pr.email, hm.user_id::text)
  limit v_limit;
end;
$$;

revoke all on function public.search_homeschool_members(uuid, text, int) from public;
grant execute on function public.search_homeschool_members(uuid, text, int) to authenticated;
