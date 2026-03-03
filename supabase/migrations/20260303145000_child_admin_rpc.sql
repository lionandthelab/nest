-- Admin/staff child creation RPC (bypasses brittle RLS edge cases)

create or replace function public.create_child_admin(
  p_family_id uuid,
  p_name text,
  p_birth_date date,
  p_profile_note text default ''
)
returns public.children
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.children%rowtype;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.families f
    join public.homeschool_memberships m
      on m.homeschool_id = f.homeschool_id
    where f.id = p_family_id
      and m.user_id = v_user_id
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  ) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;

  insert into public.children (family_id, name, birth_date, profile_note, status)
  values (
    p_family_id,
    trim(coalesce(p_name, '')),
    p_birth_date,
    coalesce(p_profile_note, ''),
    'ACTIVE'
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_child_admin(uuid, text, date, text) to authenticated;
