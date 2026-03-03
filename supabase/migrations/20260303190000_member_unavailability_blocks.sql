-- Parent/Teacher unavailability blocks for scheduling constraints.

create table if not exists public.member_unavailability_blocks (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  owner_kind text not null check (owner_kind in ('TEACHER_PROFILE', 'MEMBER_USER')),
  owner_id uuid not null,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  note text not null default '',
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time > start_time),
  unique (homeschool_id, owner_kind, owner_id, day_of_week, start_time, end_time)
);

create index if not exists idx_member_unavailability_homeschool
  on public.member_unavailability_blocks(homeschool_id);

create index if not exists idx_member_unavailability_owner
  on public.member_unavailability_blocks(owner_kind, owner_id, day_of_week);

alter table public.member_unavailability_blocks enable row level security;

drop policy if exists member_unavailability_select_member on public.member_unavailability_blocks;
create policy member_unavailability_select_member on public.member_unavailability_blocks
for select using (
  public.is_homeschool_member(homeschool_id)
);

drop policy if exists member_unavailability_insert_admin_or_owner on public.member_unavailability_blocks;
create policy member_unavailability_insert_admin_or_owner on public.member_unavailability_blocks
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or (
    owner_kind = 'MEMBER_USER'
    and owner_id = auth.uid()
    and public.is_homeschool_member(homeschool_id)
  )
  or (
    owner_kind = 'TEACHER_PROFILE'
    and exists (
      select 1
      from public.teacher_profiles tp
      where tp.id = owner_id
        and tp.user_id = auth.uid()
        and tp.homeschool_id = homeschool_id
    )
  )
);

drop policy if exists member_unavailability_update_admin_or_owner on public.member_unavailability_blocks;
create policy member_unavailability_update_admin_or_owner on public.member_unavailability_blocks
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or (
    owner_kind = 'MEMBER_USER'
    and owner_id = auth.uid()
    and public.is_homeschool_member(homeschool_id)
  )
  or (
    owner_kind = 'TEACHER_PROFILE'
    and exists (
      select 1
      from public.teacher_profiles tp
      where tp.id = owner_id
        and tp.user_id = auth.uid()
        and tp.homeschool_id = homeschool_id
    )
  )
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or (
    owner_kind = 'MEMBER_USER'
    and owner_id = auth.uid()
    and public.is_homeschool_member(homeschool_id)
  )
  or (
    owner_kind = 'TEACHER_PROFILE'
    and exists (
      select 1
      from public.teacher_profiles tp
      where tp.id = owner_id
        and tp.user_id = auth.uid()
        and tp.homeschool_id = homeschool_id
    )
  )
);

drop policy if exists member_unavailability_delete_admin_or_owner on public.member_unavailability_blocks;
create policy member_unavailability_delete_admin_or_owner on public.member_unavailability_blocks
for delete using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or (
    owner_kind = 'MEMBER_USER'
    and owner_id = auth.uid()
    and public.is_homeschool_member(homeschool_id)
  )
  or (
    owner_kind = 'TEACHER_PROFILE'
    and exists (
      select 1
      from public.teacher_profiles tp
      where tp.id = owner_id
        and tp.user_id = auth.uid()
        and tp.homeschool_id = homeschool_id
    )
  )
);

drop trigger if exists trg_member_unavailability_blocks_updated_at on public.member_unavailability_blocks;
create trigger trg_member_unavailability_blocks_updated_at
before update on public.member_unavailability_blocks
for each row execute function public.set_updated_at();
