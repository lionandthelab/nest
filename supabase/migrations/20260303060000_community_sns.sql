-- Community SNS module + parent media upload permissions

-- =====================================================
-- Tables
-- =====================================================

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  class_group_id uuid references public.class_groups(id) on delete set null,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  author_display_name text not null,
  content text not null,
  is_hidden boolean not null default false,
  is_pinned boolean not null default false,
  hidden_by_user_id uuid references auth.users(id) on delete set null,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(trim(content)) > 0)
);

alter table public.community_posts
  add column if not exists is_hidden boolean not null default false;
alter table public.community_posts
  add column if not exists is_pinned boolean not null default false;
alter table public.community_posts
  add column if not exists hidden_by_user_id uuid references auth.users(id) on delete set null;
alter table public.community_posts
  add column if not exists hidden_at timestamptz;

create table if not exists public.community_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, media_asset_id)
);

create table if not exists public.community_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  author_display_name text not null,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(trim(content)) > 0)
);

create table if not exists public.community_post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction_type text not null default 'LIKE' check (reaction_type in ('LIKE')),
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reporter_display_name text not null,
  reason_category text not null default 'OTHER'
    check (reason_category in ('SPAM', 'ABUSE', 'SAFETY', 'INAPPROPRIATE', 'OTHER')),
  reason_detail text not null default '',
  status text not null default 'OPEN'
    check (status in ('OPEN', 'RESOLVED', 'DISMISSED')),
  handled_by_user_id uuid references auth.users(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =====================================================
-- Indexes
-- =====================================================

create index if not exists idx_community_posts_school_created
  on public.community_posts(homeschool_id, created_at desc);

create index if not exists idx_community_posts_class_created
  on public.community_posts(class_group_id, created_at desc);

create index if not exists idx_community_posts_school_pinned_created
  on public.community_posts(homeschool_id, is_pinned desc, created_at desc);

create index if not exists idx_community_post_media_post
  on public.community_post_media(post_id);

create index if not exists idx_community_post_comments_post_created
  on public.community_post_comments(post_id, created_at asc);

create index if not exists idx_community_post_reactions_post
  on public.community_post_reactions(post_id);

create index if not exists idx_community_reports_school_status_created
  on public.community_reports(homeschool_id, status, created_at desc);

create index if not exists idx_community_reports_post_created
  on public.community_reports(post_id, created_at desc);

-- =====================================================
-- Triggers
-- =====================================================

drop trigger if exists trg_community_posts_updated_at on public.community_posts;
create trigger trg_community_posts_updated_at
before update on public.community_posts
for each row execute function public.set_updated_at();

drop trigger if exists trg_community_post_comments_updated_at on public.community_post_comments;
create trigger trg_community_post_comments_updated_at
before update on public.community_post_comments
for each row execute function public.set_updated_at();

drop trigger if exists trg_community_reports_updated_at on public.community_reports;
create trigger trg_community_reports_updated_at
before update on public.community_reports
for each row execute function public.set_updated_at();

-- =====================================================
-- RLS
-- =====================================================

alter table public.community_posts enable row level security;
alter table public.community_post_media enable row level security;
alter table public.community_post_comments enable row level security;
alter table public.community_post_reactions enable row level security;
alter table public.community_reports enable row level security;

-- community_posts

drop policy if exists community_posts_select_member on public.community_posts;
create policy community_posts_select_member on public.community_posts
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists community_posts_insert_member on public.community_posts;
create policy community_posts_insert_member on public.community_posts
for insert with check (
  author_user_id = auth.uid()
  and public.is_homeschool_member(homeschool_id)
);

drop policy if exists community_posts_update_author_or_admin on public.community_posts;
create policy community_posts_update_author_or_admin on public.community_posts
for update using (
  author_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  author_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists community_posts_delete_author_or_admin on public.community_posts;
create policy community_posts_delete_author_or_admin on public.community_posts
for delete using (
  author_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- community_post_media

drop policy if exists community_post_media_select_member on public.community_post_media;
create policy community_post_media_select_member on public.community_post_media
for select using (
  exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_post_media_insert_author_or_admin on public.community_post_media;
create policy community_post_media_insert_author_or_admin on public.community_post_media
for insert with check (
  exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and (
        cp.author_user_id = auth.uid()
        or public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
      )
  )
);

drop policy if exists community_post_media_delete_author_or_admin on public.community_post_media;
create policy community_post_media_delete_author_or_admin on public.community_post_media
for delete using (
  exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and (
        cp.author_user_id = auth.uid()
        or public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
      )
  )
);

-- community_post_comments

drop policy if exists community_post_comments_select_member on public.community_post_comments;
create policy community_post_comments_select_member on public.community_post_comments
for select using (
  exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_post_comments_insert_member on public.community_post_comments;
create policy community_post_comments_insert_member on public.community_post_comments
for insert with check (
  author_user_id = auth.uid()
  and exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_post_comments_update_author_or_admin on public.community_post_comments;
create policy community_post_comments_update_author_or_admin on public.community_post_comments
for update using (
  author_user_id = auth.uid()
  or exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
)
with check (
  author_user_id = auth.uid()
  or exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists community_post_comments_delete_author_or_admin on public.community_post_comments;
create policy community_post_comments_delete_author_or_admin on public.community_post_comments
for delete using (
  author_user_id = auth.uid()
  or exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

-- community_post_reactions

drop policy if exists community_post_reactions_select_member on public.community_post_reactions;
create policy community_post_reactions_select_member on public.community_post_reactions
for select using (
  exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_post_reactions_insert_member on public.community_post_reactions;
create policy community_post_reactions_insert_member on public.community_post_reactions
for insert with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_post_reactions_delete_owner_or_admin on public.community_post_reactions;
create policy community_post_reactions_delete_owner_or_admin on public.community_post_reactions
for delete using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and public.has_homeschool_role(cp.homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

-- community_reports

drop policy if exists community_reports_select_reporter_or_admin on public.community_reports;
create policy community_reports_select_reporter_or_admin on public.community_reports
for select using (
  reporter_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists community_reports_insert_member on public.community_reports;
create policy community_reports_insert_member on public.community_reports
for insert with check (
  reporter_user_id = auth.uid()
  and exists (
    select 1
    from public.community_posts cp
    where cp.id = post_id
      and cp.homeschool_id = homeschool_id
      and public.is_homeschool_member(cp.homeschool_id)
  )
);

drop policy if exists community_reports_update_admin on public.community_reports;
create policy community_reports_update_admin on public.community_reports
for update using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
)
with check (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists community_reports_delete_admin on public.community_reports;
create policy community_reports_delete_admin on public.community_reports
for delete using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

-- =====================================================
-- Existing media policy update: allow parent uploads too
-- =====================================================

drop policy if exists media_upload_sessions_insert_teacher_admin on public.media_upload_sessions;
create policy media_upload_sessions_insert_teacher_admin on public.media_upload_sessions
for insert with check (
  uploader_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF', 'PARENT']::public.membership_role[]
  )
);

drop policy if exists media_assets_insert_teacher_admin on public.media_assets;
create policy media_assets_insert_teacher_admin on public.media_assets
for insert with check (
  uploader_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF', 'PARENT']::public.membership_role[]
  )
);
