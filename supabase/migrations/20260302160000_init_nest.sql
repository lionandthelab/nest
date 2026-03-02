-- Nest initial schema for Supabase
-- Includes: domain tables, indexes, helper functions, triggers, and RLS policies

create extension if not exists pgcrypto;

-- =====================================================
-- Enum types
-- =====================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'membership_role') then
    create type public.membership_role as enum (
      'HOMESCHOOL_ADMIN',
      'PARENT',
      'TEACHER',
      'GUEST_TEACHER',
      'STAFF'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'membership_status') then
    create type public.membership_status as enum ('ACTIVE', 'PENDING', 'EXPIRED');
  end if;

  if not exists (select 1 from pg_type where typname = 'guardian_type') then
    create type public.guardian_type as enum ('FATHER', 'MOTHER', 'GUARDIAN');
  end if;

  if not exists (select 1 from pg_type where typname = 'teacher_type') then
    create type public.teacher_type as enum ('PARENT_TEACHER', 'GUEST_TEACHER');
  end if;

  if not exists (select 1 from pg_type where typname = 'term_status') then
    create type public.term_status as enum ('DRAFT', 'ACTIVE', 'ARCHIVED');
  end if;

  if not exists (select 1 from pg_type where typname = 'session_status') then
    create type public.session_status as enum ('PLANNED', 'CONFIRMED', 'CANCELED');
  end if;

  if not exists (select 1 from pg_type where typname = 'assignment_role') then
    create type public.assignment_role as enum ('MAIN', 'ASSISTANT');
  end if;

  if not exists (select 1 from pg_type where typname = 'proposal_status') then
    create type public.proposal_status as enum ('GENERATED', 'APPLIED', 'DISCARDED');
  end if;

  if not exists (select 1 from pg_type where typname = 'drive_provider') then
    create type public.drive_provider as enum ('GOOGLE_DRIVE');
  end if;

  if not exists (select 1 from pg_type where typname = 'drive_status') then
    create type public.drive_status as enum ('CONNECTED', 'DISCONNECTED', 'ERROR');
  end if;

  if not exists (select 1 from pg_type where typname = 'folder_mapping_type') then
    create type public.folder_mapping_type as enum ('TERM', 'CLASS_GROUP', 'CHILD');
  end if;

  if not exists (select 1 from pg_type where typname = 'upload_status') then
    create type public.upload_status as enum ('PENDING', 'UPLOADING', 'COMPLETED', 'FAILED');
  end if;

  if not exists (select 1 from pg_type where typname = 'media_type') then
    create type public.media_type as enum ('PHOTO', 'VIDEO');
  end if;

  if not exists (select 1 from pg_type where typname = 'activity_type') then
    create type public.activity_type as enum ('ATTENDANCE', 'OBSERVATION', 'ASSIGNMENT');
  end if;

  if not exists (select 1 from pg_type where typname = 'folder_policy') then
    create type public.folder_policy as enum ('TERM_CLASS_DATE', 'CLASS_CHILD_DATE');
  end if;
end
$$;

-- =====================================================
-- Utility trigger functions
-- =====================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do update
  set email = excluded.email;

  return new;
end;
$$;

-- =====================================================
-- Tables
-- =====================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.homeschools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  invite_code text not null unique default substring(replace(gen_random_uuid()::text, '-', '') from 1 for 12),
  timezone text not null default 'Asia/Seoul',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.homeschool_memberships (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.membership_role not null,
  status public.membership_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (homeschool_id, user_id, role)
);

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  family_name text not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.family_guardians (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  guardian_type public.guardian_type not null,
  created_at timestamptz not null default now(),
  unique (family_id, user_id)
);

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  birth_date date not null,
  profile_note text,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teacher_profiles (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  display_name text not null,
  teacher_type public.teacher_type not null,
  specialties text[] not null default '{}',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teacher_availabilities (
  id uuid primary key default gen_random_uuid(),
  teacher_profile_id uuid not null references public.teacher_profiles(id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time > start_time),
  unique (teacher_profile_id, day_of_week, start_time, end_time)
);

create table if not exists public.terms (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  status public.term_status not null default 'DRAFT',
  timetable_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date),
  unique (homeschool_id, name)
);

create table if not exists public.class_groups (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id) on delete cascade,
  name text not null,
  capacity int not null default 12 check (capacity > 0),
  main_teacher_id uuid references public.teacher_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (term_id, name)
);

create table if not exists public.class_enrollments (
  id uuid primary key default gen_random_uuid(),
  class_group_id uuid not null references public.class_groups(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (class_group_id, child_id)
);

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  name text not null,
  description text,
  default_duration_min int not null default 50 check (default_duration_min >= 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (homeschool_id, name)
);

create table if not exists public.time_slots (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time > start_time),
  unique (term_id, day_of_week, start_time, end_time)
);

create table if not exists public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  class_group_id uuid not null references public.class_groups(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete restrict,
  time_slot_id uuid not null references public.time_slots(id) on delete restrict,
  title text,
  source_type text not null default 'MANUAL' check (source_type in ('MANUAL', 'AI_PROMPT')),
  status public.session_status not null default 'PLANNED',
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_group_id, time_slot_id)
);

create table if not exists public.session_teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references public.class_sessions(id) on delete cascade,
  teacher_profile_id uuid not null references public.teacher_profiles(id) on delete restrict,
  assignment_role public.assignment_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_session_id, teacher_profile_id)
);

create unique index if not exists uq_session_main_teacher
  on public.session_teacher_assignments (class_session_id)
  where assignment_role = 'MAIN';

create table if not exists public.timetable_proposals (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id) on delete cascade,
  prompt text not null,
  status public.proposal_status not null default 'GENERATED',
  generated_by_user_id uuid not null references auth.users(id) on delete restrict,
  summary_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.timetable_proposal_sessions (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.timetable_proposals(id) on delete cascade,
  class_group_id uuid not null references public.class_groups(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete restrict,
  time_slot_id uuid not null references public.time_slots(id) on delete restrict,
  teacher_main_id uuid references public.teacher_profiles(id) on delete set null,
  teacher_assistant_ids_json jsonb not null default '[]'::jsonb,
  hard_conflicts_json jsonb not null default '[]'::jsonb,
  soft_warnings_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.drive_integrations (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null unique references public.homeschools(id) on delete cascade,
  provider public.drive_provider not null default 'GOOGLE_DRIVE',
  status public.drive_status not null default 'DISCONNECTED',
  root_folder_id text,
  folder_policy public.folder_policy,
  connected_by_user_id uuid references auth.users(id) on delete set null,
  connected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.drive_folder_mappings (
  id uuid primary key default gen_random_uuid(),
  drive_integration_id uuid not null references public.drive_integrations(id) on delete cascade,
  mapping_type public.folder_mapping_type not null,
  mapping_key text not null,
  folder_id text not null,
  created_at timestamptz not null default now(),
  unique (drive_integration_id, mapping_type, mapping_key)
);

create table if not exists public.media_upload_sessions (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  uploader_user_id uuid not null references auth.users(id) on delete restrict,
  status public.upload_status not null default 'PENDING',
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  target_folder_id text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 day')
);

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  upload_session_id uuid not null unique references public.media_upload_sessions(id) on delete restrict,
  drive_file_id text not null unique,
  drive_web_view_link text,
  uploader_user_id uuid not null references auth.users(id) on delete restrict,
  class_group_id uuid references public.class_groups(id) on delete set null,
  class_session_id uuid references public.class_sessions(id) on delete set null,
  title text,
  description text,
  media_type public.media_type not null,
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.media_asset_children (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (media_asset_id, child_id)
);

create table if not exists public.teaching_plans (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references public.class_sessions(id) on delete cascade,
  teacher_profile_id uuid not null references public.teacher_profiles(id) on delete restrict,
  objectives text not null,
  materials text,
  activities text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_activity_logs (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  class_session_id uuid references public.class_sessions(id) on delete set null,
  recorded_by_teacher_id uuid not null references public.teacher_profiles(id) on delete restrict,
  activity_type public.activity_type not null,
  content text not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  class_group_id uuid references public.class_groups(id) on delete set null,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  title text not null,
  body text not null,
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action_type text not null,
  resource_type text not null,
  resource_id text not null,
  before_json jsonb,
  after_json jsonb,
  created_at timestamptz not null default now()
);

-- =====================================================
-- Indexes
-- =====================================================

create index if not exists idx_memberships_user on public.homeschool_memberships(user_id);
create index if not exists idx_memberships_school on public.homeschool_memberships(homeschool_id);
create index if not exists idx_families_school on public.families(homeschool_id);
create index if not exists idx_children_family on public.children(family_id);
create index if not exists idx_teacher_profiles_school on public.teacher_profiles(homeschool_id);
create index if not exists idx_terms_school on public.terms(homeschool_id);
create index if not exists idx_class_groups_term on public.class_groups(term_id);
create index if not exists idx_enrollments_child on public.class_enrollments(child_id);
create index if not exists idx_courses_school on public.courses(homeschool_id);
create index if not exists idx_time_slots_term on public.time_slots(term_id);
create index if not exists idx_class_sessions_class on public.class_sessions(class_group_id);
create index if not exists idx_class_sessions_slot on public.class_sessions(time_slot_id);
create index if not exists idx_session_assign_teacher on public.session_teacher_assignments(teacher_profile_id);
create index if not exists idx_proposals_term on public.timetable_proposals(term_id, created_at desc);
create index if not exists idx_media_assets_school on public.media_assets(homeschool_id, created_at desc);
create index if not exists idx_media_asset_children_child on public.media_asset_children(child_id);
create index if not exists idx_activity_logs_child on public.student_activity_logs(child_id, recorded_at desc);
create index if not exists idx_audit_logs_school on public.audit_logs(homeschool_id, created_at desc);

-- =====================================================
-- Triggers
-- =====================================================

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.handle_homeschool_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.homeschool_memberships (homeschool_id, user_id, role, status)
  values (new.id, new.owner_user_id, 'HOMESCHOOL_ADMIN', 'ACTIVE')
  on conflict (homeschool_id, user_id, role) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_homeschool_owner_membership on public.homeschools;
create trigger trg_homeschool_owner_membership
after insert on public.homeschools
for each row execute function public.handle_homeschool_owner_membership();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_homeschools_updated_at on public.homeschools;
create trigger trg_homeschools_updated_at
before update on public.homeschools
for each row execute function public.set_updated_at();

drop trigger if exists trg_memberships_updated_at on public.homeschool_memberships;
create trigger trg_memberships_updated_at
before update on public.homeschool_memberships
for each row execute function public.set_updated_at();

drop trigger if exists trg_families_updated_at on public.families;
create trigger trg_families_updated_at
before update on public.families
for each row execute function public.set_updated_at();

drop trigger if exists trg_children_updated_at on public.children;
create trigger trg_children_updated_at
before update on public.children
for each row execute function public.set_updated_at();

drop trigger if exists trg_teacher_profiles_updated_at on public.teacher_profiles;
create trigger trg_teacher_profiles_updated_at
before update on public.teacher_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_teacher_availabilities_updated_at on public.teacher_availabilities;
create trigger trg_teacher_availabilities_updated_at
before update on public.teacher_availabilities
for each row execute function public.set_updated_at();

drop trigger if exists trg_terms_updated_at on public.terms;
create trigger trg_terms_updated_at
before update on public.terms
for each row execute function public.set_updated_at();

drop trigger if exists trg_class_groups_updated_at on public.class_groups;
create trigger trg_class_groups_updated_at
before update on public.class_groups
for each row execute function public.set_updated_at();

drop trigger if exists trg_courses_updated_at on public.courses;
create trigger trg_courses_updated_at
before update on public.courses
for each row execute function public.set_updated_at();

drop trigger if exists trg_time_slots_updated_at on public.time_slots;
create trigger trg_time_slots_updated_at
before update on public.time_slots
for each row execute function public.set_updated_at();

drop trigger if exists trg_class_sessions_updated_at on public.class_sessions;
create trigger trg_class_sessions_updated_at
before update on public.class_sessions
for each row execute function public.set_updated_at();

drop trigger if exists trg_session_teacher_assignments_updated_at on public.session_teacher_assignments;
create trigger trg_session_teacher_assignments_updated_at
before update on public.session_teacher_assignments
for each row execute function public.set_updated_at();

drop trigger if exists trg_timetable_proposals_updated_at on public.timetable_proposals;
create trigger trg_timetable_proposals_updated_at
before update on public.timetable_proposals
for each row execute function public.set_updated_at();

drop trigger if exists trg_drive_integrations_updated_at on public.drive_integrations;
create trigger trg_drive_integrations_updated_at
before update on public.drive_integrations
for each row execute function public.set_updated_at();

drop trigger if exists trg_media_assets_updated_at on public.media_assets;
create trigger trg_media_assets_updated_at
before update on public.media_assets
for each row execute function public.set_updated_at();

drop trigger if exists trg_teaching_plans_updated_at on public.teaching_plans;
create trigger trg_teaching_plans_updated_at
before update on public.teaching_plans
for each row execute function public.set_updated_at();

drop trigger if exists trg_student_activity_logs_updated_at on public.student_activity_logs;
create trigger trg_student_activity_logs_updated_at
before update on public.student_activity_logs
for each row execute function public.set_updated_at();

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

-- =====================================================
-- Membership helper functions for RLS
-- =====================================================

create or replace function public.is_homeschool_member(p_homeschool_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.homeschool_memberships m
    where m.homeschool_id = p_homeschool_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
  );
$$;

create or replace function public.has_homeschool_role(
  p_homeschool_id uuid,
  p_roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.homeschool_memberships m
    where m.homeschool_id = p_homeschool_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
      and m.role = any(p_roles)
  );
$$;

create or replace function public.is_term_member(p_term_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.terms t
    where t.id = p_term_id
      and public.is_homeschool_member(t.homeschool_id)
  );
$$;

create or replace function public.has_term_role(p_term_id uuid, p_roles public.membership_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.terms t
    where t.id = p_term_id
      and public.has_homeschool_role(t.homeschool_id, p_roles)
  );
$$;

create or replace function public.is_class_group_member(p_class_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_groups cg
    join public.terms t on t.id = cg.term_id
    where cg.id = p_class_group_id
      and public.is_homeschool_member(t.homeschool_id)
  );
$$;

create or replace function public.has_class_group_role(p_class_group_id uuid, p_roles public.membership_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_groups cg
    join public.terms t on t.id = cg.term_id
    where cg.id = p_class_group_id
      and public.has_homeschool_role(t.homeschool_id, p_roles)
  );
$$;

create or replace function public.is_family_member(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.families f
    where f.id = p_family_id
      and public.is_homeschool_member(f.homeschool_id)
  );
$$;

create or replace function public.has_family_role(p_family_id uuid, p_roles public.membership_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.families f
    where f.id = p_family_id
      and public.has_homeschool_role(f.homeschool_id, p_roles)
  );
$$;

create or replace function public.is_teacher_profile_member(p_teacher_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teacher_profiles tp
    where tp.id = p_teacher_profile_id
      and public.is_homeschool_member(tp.homeschool_id)
  );
$$;

create or replace function public.has_teacher_profile_role(
  p_teacher_profile_id uuid,
  p_roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teacher_profiles tp
    where tp.id = p_teacher_profile_id
      and public.has_homeschool_role(tp.homeschool_id, p_roles)
  );
$$;

create or replace function public.is_class_session_member(p_class_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.terms t on t.id = cg.term_id
    where cs.id = p_class_session_id
      and public.is_homeschool_member(t.homeschool_id)
  );
$$;

create or replace function public.has_class_session_role(
  p_class_session_id uuid,
  p_roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.terms t on t.id = cg.term_id
    where cs.id = p_class_session_id
      and public.has_homeschool_role(t.homeschool_id, p_roles)
  );
$$;

create or replace function public.is_child_member(p_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children c
    join public.families f on f.id = c.family_id
    where c.id = p_child_id
      and public.is_homeschool_member(f.homeschool_id)
  );
$$;

create or replace function public.has_child_role(p_child_id uuid, p_roles public.membership_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children c
    join public.families f on f.id = c.family_id
    where c.id = p_child_id
      and public.has_homeschool_role(f.homeschool_id, p_roles)
  );
$$;

-- =====================================================
-- Enable RLS
-- =====================================================

alter table public.profiles enable row level security;
alter table public.homeschools enable row level security;
alter table public.homeschool_memberships enable row level security;
alter table public.families enable row level security;
alter table public.family_guardians enable row level security;
alter table public.children enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.teacher_availabilities enable row level security;
alter table public.terms enable row level security;
alter table public.class_groups enable row level security;
alter table public.class_enrollments enable row level security;
alter table public.courses enable row level security;
alter table public.time_slots enable row level security;
alter table public.class_sessions enable row level security;
alter table public.session_teacher_assignments enable row level security;
alter table public.timetable_proposals enable row level security;
alter table public.timetable_proposal_sessions enable row level security;
alter table public.drive_integrations enable row level security;
alter table public.drive_folder_mappings enable row level security;
alter table public.media_upload_sessions enable row level security;
alter table public.media_assets enable row level security;
alter table public.media_asset_children enable row level security;
alter table public.teaching_plans enable row level security;
alter table public.student_activity_logs enable row level security;
alter table public.announcements enable row level security;
alter table public.audit_logs enable row level security;

-- =====================================================
-- Policies
-- =====================================================

-- profiles
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select using (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

-- homeschools
drop policy if exists homeschools_select_member on public.homeschools;
create policy homeschools_select_member on public.homeschools
for select using (
  owner_user_id = auth.uid() or public.is_homeschool_member(id)
);

drop policy if exists homeschools_insert_owner on public.homeschools;
create policy homeschools_insert_owner on public.homeschools
for insert with check (owner_user_id = auth.uid());

drop policy if exists homeschools_update_admin on public.homeschools;
create policy homeschools_update_admin on public.homeschools
for update using (
  owner_user_id = auth.uid() or public.has_homeschool_role(id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
)
with check (
  owner_user_id = auth.uid() or public.has_homeschool_role(id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
);

-- homeschool_memberships
drop policy if exists memberships_select_self_or_admin on public.homeschool_memberships;
create policy memberships_select_self_or_admin on public.homeschool_memberships
for select using (
  user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists memberships_insert_admin on public.homeschool_memberships;
create policy memberships_insert_admin on public.homeschool_memberships
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
);

drop policy if exists memberships_update_admin on public.homeschool_memberships;
create policy memberships_update_admin on public.homeschool_memberships
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
);

drop policy if exists memberships_delete_admin on public.homeschool_memberships;
create policy memberships_delete_admin on public.homeschool_memberships
for delete using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
);

-- families
drop policy if exists families_select_member on public.families;
create policy families_select_member on public.families
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists families_insert_admin_staff on public.families;
create policy families_insert_admin_staff on public.families
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists families_update_admin_staff on public.families;
create policy families_update_admin_staff on public.families
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- family_guardians
drop policy if exists family_guardians_select_member on public.family_guardians;
create policy family_guardians_select_member on public.family_guardians
for select using (public.is_family_member(family_id));

drop policy if exists family_guardians_insert_admin_staff on public.family_guardians;
create policy family_guardians_insert_admin_staff on public.family_guardians
for insert with check (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists family_guardians_update_admin_staff on public.family_guardians;
create policy family_guardians_update_admin_staff on public.family_guardians
for update using (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- children
drop policy if exists children_select_member on public.children;
create policy children_select_member on public.children
for select using (public.is_child_member(id));

drop policy if exists children_insert_admin_staff on public.children;
create policy children_insert_admin_staff on public.children
for insert with check (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists children_update_admin_staff on public.children;
create policy children_update_admin_staff on public.children
for update using (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_family_role(family_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- teacher_profiles
drop policy if exists teacher_profiles_select_member on public.teacher_profiles;
create policy teacher_profiles_select_member on public.teacher_profiles
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists teacher_profiles_insert_admin_staff on public.teacher_profiles;
create policy teacher_profiles_insert_admin_staff on public.teacher_profiles
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists teacher_profiles_update_admin_staff on public.teacher_profiles;
create policy teacher_profiles_update_admin_staff on public.teacher_profiles
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- teacher_availabilities
drop policy if exists teacher_availabilities_select_member on public.teacher_availabilities;
create policy teacher_availabilities_select_member on public.teacher_availabilities
for select using (public.is_teacher_profile_member(teacher_profile_id));

drop policy if exists teacher_availabilities_insert_admin_or_owner on public.teacher_availabilities;
create policy teacher_availabilities_insert_admin_or_owner on public.teacher_availabilities
for insert with check (
  public.has_teacher_profile_role(teacher_profile_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or exists (
    select 1 from public.teacher_profiles tp
    where tp.id = teacher_profile_id and tp.user_id = auth.uid()
  )
);

drop policy if exists teacher_availabilities_update_admin_or_owner on public.teacher_availabilities;
create policy teacher_availabilities_update_admin_or_owner on public.teacher_availabilities
for update using (
  public.has_teacher_profile_role(teacher_profile_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or exists (
    select 1 from public.teacher_profiles tp
    where tp.id = teacher_profile_id and tp.user_id = auth.uid()
  )
)
with check (
  public.has_teacher_profile_role(teacher_profile_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  or exists (
    select 1 from public.teacher_profiles tp
    where tp.id = teacher_profile_id and tp.user_id = auth.uid()
  )
);

-- terms
drop policy if exists terms_select_member on public.terms;
create policy terms_select_member on public.terms
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists terms_insert_admin_staff on public.terms;
create policy terms_insert_admin_staff on public.terms
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists terms_update_admin_staff on public.terms;
create policy terms_update_admin_staff on public.terms
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- class_groups
drop policy if exists class_groups_select_member on public.class_groups;
create policy class_groups_select_member on public.class_groups
for select using (public.is_term_member(term_id));

drop policy if exists class_groups_insert_admin_staff on public.class_groups;
create policy class_groups_insert_admin_staff on public.class_groups
for insert with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists class_groups_update_admin_staff on public.class_groups;
create policy class_groups_update_admin_staff on public.class_groups
for update using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- class_enrollments
drop policy if exists class_enrollments_select_member on public.class_enrollments;
create policy class_enrollments_select_member on public.class_enrollments
for select using (public.is_class_group_member(class_group_id));

drop policy if exists class_enrollments_insert_admin_staff on public.class_enrollments;
create policy class_enrollments_insert_admin_staff on public.class_enrollments
for insert with check (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists class_enrollments_delete_admin_staff on public.class_enrollments;
create policy class_enrollments_delete_admin_staff on public.class_enrollments
for delete using (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- courses
drop policy if exists courses_select_member on public.courses;
create policy courses_select_member on public.courses
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists courses_insert_admin_staff on public.courses;
create policy courses_insert_admin_staff on public.courses
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists courses_update_admin_staff on public.courses;
create policy courses_update_admin_staff on public.courses
for update using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- time_slots
drop policy if exists time_slots_select_member on public.time_slots;
create policy time_slots_select_member on public.time_slots
for select using (public.is_term_member(term_id));

drop policy if exists time_slots_insert_admin_staff on public.time_slots;
create policy time_slots_insert_admin_staff on public.time_slots
for insert with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists time_slots_update_admin_staff on public.time_slots;
create policy time_slots_update_admin_staff on public.time_slots
for update using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- class_sessions
drop policy if exists class_sessions_select_member on public.class_sessions;
create policy class_sessions_select_member on public.class_sessions
for select using (public.is_class_group_member(class_group_id));

drop policy if exists class_sessions_insert_admin_staff on public.class_sessions;
create policy class_sessions_insert_admin_staff on public.class_sessions
for insert with check (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists class_sessions_update_admin_staff on public.class_sessions;
create policy class_sessions_update_admin_staff on public.class_sessions
for update using (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists class_sessions_delete_admin_staff on public.class_sessions;
create policy class_sessions_delete_admin_staff on public.class_sessions
for delete using (
  public.has_class_group_role(class_group_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- session_teacher_assignments
drop policy if exists session_teacher_assignments_select_member on public.session_teacher_assignments;
create policy session_teacher_assignments_select_member on public.session_teacher_assignments
for select using (public.is_class_session_member(class_session_id));

drop policy if exists session_teacher_assignments_insert_admin_staff on public.session_teacher_assignments;
create policy session_teacher_assignments_insert_admin_staff on public.session_teacher_assignments
for insert with check (
  public.has_class_session_role(class_session_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists session_teacher_assignments_update_admin_staff on public.session_teacher_assignments;
create policy session_teacher_assignments_update_admin_staff on public.session_teacher_assignments
for update using (
  public.has_class_session_role(class_session_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_class_session_role(class_session_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists session_teacher_assignments_delete_admin_staff on public.session_teacher_assignments;
create policy session_teacher_assignments_delete_admin_staff on public.session_teacher_assignments
for delete using (
  public.has_class_session_role(class_session_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- timetable_proposals
drop policy if exists timetable_proposals_select_member on public.timetable_proposals;
create policy timetable_proposals_select_member on public.timetable_proposals
for select using (public.is_term_member(term_id));

drop policy if exists timetable_proposals_insert_admin_staff on public.timetable_proposals;
create policy timetable_proposals_insert_admin_staff on public.timetable_proposals
for insert with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists timetable_proposals_update_admin_staff on public.timetable_proposals;
create policy timetable_proposals_update_admin_staff on public.timetable_proposals
for update using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- timetable_proposal_sessions
drop policy if exists timetable_proposal_sessions_select_member on public.timetable_proposal_sessions;
create policy timetable_proposal_sessions_select_member on public.timetable_proposal_sessions
for select using (
  exists (
    select 1
    from public.timetable_proposals tp
    where tp.id = proposal_id
      and public.is_term_member(tp.term_id)
  )
);

drop policy if exists timetable_proposal_sessions_insert_admin_staff on public.timetable_proposal_sessions;
create policy timetable_proposal_sessions_insert_admin_staff on public.timetable_proposal_sessions
for insert with check (
  exists (
    select 1
    from public.timetable_proposals tp
    where tp.id = proposal_id
      and public.has_term_role(tp.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists timetable_proposal_sessions_update_admin_staff on public.timetable_proposal_sessions;
create policy timetable_proposal_sessions_update_admin_staff on public.timetable_proposal_sessions
for update using (
  exists (
    select 1
    from public.timetable_proposals tp
    where tp.id = proposal_id
      and public.has_term_role(tp.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
)
with check (
  exists (
    select 1
    from public.timetable_proposals tp
    where tp.id = proposal_id
      and public.has_term_role(tp.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

-- drive_integrations
drop policy if exists drive_integrations_select_member on public.drive_integrations;
create policy drive_integrations_select_member on public.drive_integrations
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists drive_integrations_mutate_admin on public.drive_integrations;
create policy drive_integrations_mutate_admin on public.drive_integrations
for all using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
)
with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
);

-- drive_folder_mappings
drop policy if exists drive_folder_mappings_select_member on public.drive_folder_mappings;
create policy drive_folder_mappings_select_member on public.drive_folder_mappings
for select using (
  exists (
    select 1
    from public.drive_integrations di
    where di.id = drive_integration_id
      and public.is_homeschool_member(di.homeschool_id)
  )
);

drop policy if exists drive_folder_mappings_mutate_admin on public.drive_folder_mappings;
create policy drive_folder_mappings_mutate_admin on public.drive_folder_mappings
for all using (
  exists (
    select 1
    from public.drive_integrations di
    where di.id = drive_integration_id
      and public.has_homeschool_role(di.homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
  )
)
with check (
  exists (
    select 1
    from public.drive_integrations di
    where di.id = drive_integration_id
      and public.has_homeschool_role(di.homeschool_id, array['HOMESCHOOL_ADMIN']::public.membership_role[])
  )
);

-- media_upload_sessions
drop policy if exists media_upload_sessions_select_member on public.media_upload_sessions;
create policy media_upload_sessions_select_member on public.media_upload_sessions
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists media_upload_sessions_insert_teacher_admin on public.media_upload_sessions;
create policy media_upload_sessions_insert_teacher_admin on public.media_upload_sessions
for insert with check (
  uploader_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists media_upload_sessions_update_uploader_or_admin on public.media_upload_sessions;
create policy media_upload_sessions_update_uploader_or_admin on public.media_upload_sessions
for update using (
  uploader_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  uploader_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- media_assets
drop policy if exists media_assets_select_member on public.media_assets;
create policy media_assets_select_member on public.media_assets
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists media_assets_insert_teacher_admin on public.media_assets;
create policy media_assets_insert_teacher_admin on public.media_assets
for insert with check (
  uploader_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists media_assets_update_uploader_or_admin on public.media_assets;
create policy media_assets_update_uploader_or_admin on public.media_assets
for update using (
  uploader_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  uploader_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- media_asset_children
drop policy if exists media_asset_children_select_member on public.media_asset_children;
create policy media_asset_children_select_member on public.media_asset_children
for select using (
  exists (
    select 1
    from public.media_assets ma
    where ma.id = media_asset_id
      and public.is_homeschool_member(ma.homeschool_id)
  )
);

drop policy if exists media_asset_children_insert_teacher_admin on public.media_asset_children;
create policy media_asset_children_insert_teacher_admin on public.media_asset_children
for insert with check (
  exists (
    select 1
    from public.media_assets ma
    where ma.id = media_asset_id
      and (
        ma.uploader_user_id = auth.uid()
        or public.has_homeschool_role(
          ma.homeschool_id,
          array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
        )
      )
  )
);

-- teaching_plans
drop policy if exists teaching_plans_select_member on public.teaching_plans;
create policy teaching_plans_select_member on public.teaching_plans
for select using (public.is_class_session_member(class_session_id));

drop policy if exists teaching_plans_insert_teacher_admin on public.teaching_plans;
create policy teaching_plans_insert_teacher_admin on public.teaching_plans
for insert with check (
  public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists teaching_plans_update_teacher_admin on public.teaching_plans;
create policy teaching_plans_update_teacher_admin on public.teaching_plans
for update using (
  public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
)
with check (
  public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

-- student_activity_logs
drop policy if exists student_activity_logs_select_member on public.student_activity_logs;
create policy student_activity_logs_select_member on public.student_activity_logs
for select using (public.is_child_member(child_id));

drop policy if exists student_activity_logs_insert_teacher_admin on public.student_activity_logs;
create policy student_activity_logs_insert_teacher_admin on public.student_activity_logs
for insert with check (
  public.has_child_role(
    child_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists student_activity_logs_update_teacher_admin on public.student_activity_logs;
create policy student_activity_logs_update_teacher_admin on public.student_activity_logs
for update using (
  public.has_child_role(
    child_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
)
with check (
  public.has_child_role(
    child_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

-- announcements
drop policy if exists announcements_select_member on public.announcements;
create policy announcements_select_member on public.announcements
for select using (public.is_homeschool_member(homeschool_id));

drop policy if exists announcements_insert_teacher_admin on public.announcements;
create policy announcements_insert_teacher_admin on public.announcements
for insert with check (
  author_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'TEACHER', 'GUEST_TEACHER', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists announcements_update_teacher_admin on public.announcements;
create policy announcements_update_teacher_admin on public.announcements
for update using (
  author_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  author_user_id = auth.uid()
  or public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- audit_logs
drop policy if exists audit_logs_select_admin_staff on public.audit_logs;
create policy audit_logs_select_admin_staff on public.audit_logs
for select using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists audit_logs_insert_admin_staff on public.audit_logs;
create policy audit_logs_insert_admin_staff on public.audit_logs
for insert with check (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- =====================================================
-- Grants for authenticated role
-- =====================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
