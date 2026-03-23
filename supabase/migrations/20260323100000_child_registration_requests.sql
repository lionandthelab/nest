-- Child registration request system: parents request, admins approve

create table if not exists public.child_registration_requests (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  family_name text not null,
  child_name text not null,
  birth_date date,
  guardian_type text not null default 'GUARDIAN',
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  reviewed_by_user_id uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_family_id uuid references public.families(id) on delete set null,
  created_child_id uuid references public.children(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_child_reg_requests_school_status
  on public.child_registration_requests (homeschool_id, status, created_at desc);

alter table public.child_registration_requests enable row level security;

-- Parents can see their own requests; admins/staff see all for their school
create policy child_reg_requests_select on public.child_registration_requests
for select using (
  requester_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- Any active member can create a request
create policy child_reg_requests_insert on public.child_registration_requests
for insert with check (
  requester_user_id = auth.uid()
  and status = 'PENDING'
  and exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = child_registration_requests.homeschool_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
  )
);

-- Only admins/staff can update (approve/reject)
create policy child_reg_requests_update on public.child_registration_requests
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- Approve: creates family (if needed), child, and guardian link
create or replace function public.approve_child_registration(
  p_request_id uuid,
  p_role text default 'PARENT'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_req record;
  v_family_id uuid;
  v_child public.children%rowtype;
begin
  if v_admin_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select * into v_req
  from public.child_registration_requests
  where id = p_request_id and status = 'PENDING';

  if v_req is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;

  -- Verify caller is admin/staff of this homeschool
  if not exists (
    select 1 from public.homeschool_memberships m
    where m.homeschool_id = v_req.homeschool_id
      and m.user_id = v_admin_id
      and m.status = 'ACTIVE'
      and m.role = any(array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  ) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;

  -- Find existing family for requester, or create one
  select f.id into v_family_id
  from public.families f
  join public.family_guardians fg on fg.family_id = f.id
  where f.homeschool_id = v_req.homeschool_id
    and fg.user_id = v_req.requester_user_id
  limit 1;

  if v_family_id is null then
    insert into public.families (homeschool_id, family_name, note)
    values (v_req.homeschool_id, v_req.family_name, '')
    returning id into v_family_id;

    insert into public.family_guardians (family_id, user_id, guardian_type)
    values (v_family_id, v_req.requester_user_id, coalesce(v_req.guardian_type, 'GUARDIAN'));
  end if;

  -- Create child
  insert into public.children (family_id, name, birth_date, profile_note, status)
  values (v_family_id, v_req.child_name, v_req.birth_date, '', 'ACTIVE')
  returning * into v_child;

  -- Mark request as approved
  update public.child_registration_requests
  set status = 'APPROVED',
      reviewed_by_user_id = v_admin_id,
      reviewed_at = now(),
      created_family_id = v_family_id,
      created_child_id = v_child.id,
      updated_at = now()
  where id = p_request_id;

  return jsonb_build_object(
    'family_id', v_family_id,
    'child_id', v_child.id,
    'child_name', v_child.name
  );
end;
$$;

grant execute on function public.approve_child_registration(uuid, text) to authenticated;
