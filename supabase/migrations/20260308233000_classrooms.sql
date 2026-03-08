create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id) on delete cascade,
  name text not null,
  capacity integer not null default 20,
  note text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint classrooms_name_not_blank check (char_length(trim(name)) > 0),
  constraint classrooms_capacity_check check (capacity between 1 and 300),
  constraint classrooms_term_name_unique unique (term_id, name)
);

create index if not exists idx_classrooms_term on public.classrooms(term_id);

drop trigger if exists trg_classrooms_updated_at on public.classrooms;
create trigger trg_classrooms_updated_at
before update on public.classrooms
for each row execute function public.set_updated_at();

alter table public.classrooms enable row level security;

drop policy if exists classrooms_select_member on public.classrooms;
create policy classrooms_select_member on public.classrooms
for select using (public.is_term_member(term_id));

drop policy if exists classrooms_insert_admin_staff on public.classrooms;
create policy classrooms_insert_admin_staff on public.classrooms
for insert with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists classrooms_update_admin_staff on public.classrooms;
create policy classrooms_update_admin_staff on public.classrooms
for update using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists classrooms_delete_admin_staff on public.classrooms;
create policy classrooms_delete_admin_staff on public.classrooms
for delete using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);
