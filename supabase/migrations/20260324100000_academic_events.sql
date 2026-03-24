-- Academic events (학사 일정) for homeschool-wide scheduling
create table if not exists public.academic_events (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  term_id uuid references public.terms(id) on delete set null,
  title text not null default '',
  description text not null default '',
  event_date date not null,
  end_date date, -- null = single-day event
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for efficient queries
create index idx_academic_events_homeschool_date
  on public.academic_events (homeschool_id, event_date desc);

create index idx_academic_events_term
  on public.academic_events (term_id, event_date);

-- Auto-update updated_at
create trigger set_academic_events_updated_at
  before update on public.academic_events
  for each row execute function public.set_updated_at();

-- RLS
alter table public.academic_events enable row level security;

-- All authenticated members of the homeschool can view
create policy "Members can view academic events"
  on public.academic_events for select
  using (
    homeschool_id in (
      select homeschool_id from public.homeschool_memberships
      where user_id = auth.uid() and status = 'ACTIVE'
    )
  );

-- Only admins can insert/update/delete
create policy "Admins can manage academic events"
  on public.academic_events for all
  using (
    homeschool_id in (
      select homeschool_id from public.homeschool_memberships
      where user_id = auth.uid() and role = 'HOMESCHOOL_ADMIN' and status = 'ACTIVE'
    )
  );
