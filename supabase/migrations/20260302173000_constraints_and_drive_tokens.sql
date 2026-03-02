-- Nest constraint hardening + Google Drive credential columns

-- =====================================================
-- Drive integration token columns (MVP)
-- =====================================================

alter table public.drive_integrations
  add column if not exists google_access_token text,
  add column if not exists google_refresh_token text,
  add column if not exists google_token_expires_at timestamptz,
  add column if not exists oauth_scope text;

-- =====================================================
-- Teacher timeslot conflict guard
-- =====================================================

create or replace function public.enforce_teacher_timeslot_conflict()
returns trigger
language plpgsql
as $$
declare
  v_time_slot_id uuid;
begin
  select cs.time_slot_id
    into v_time_slot_id
  from public.class_sessions cs
  where cs.id = new.class_session_id;

  if v_time_slot_id is null then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if exists (
    select 1
    from public.session_teacher_assignments sta
    join public.class_sessions cs on cs.id = sta.class_session_id
    where sta.teacher_profile_id = new.teacher_profile_id
      and cs.time_slot_id = v_time_slot_id
      and cs.status <> 'CANCELED'
      and sta.class_session_id <> new.class_session_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'TEACHER_SLOT_CONFLICT',
      detail = 'Teacher is already assigned in the same time slot.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_teacher_timeslot_conflict on public.session_teacher_assignments;
create trigger trg_enforce_teacher_timeslot_conflict
before insert or update on public.session_teacher_assignments
for each row execute function public.enforce_teacher_timeslot_conflict();

-- =====================================================
-- Archived term mutation guard
-- =====================================================

create or replace function public.raise_if_archived_term_by_term_id(p_term_id uuid)
returns void
language plpgsql
as $$
declare
  v_status public.term_status;
begin
  select t.status
    into v_status
  from public.terms t
  where t.id = p_term_id;

  if v_status = 'ARCHIVED' then
    raise exception using
      errcode = '23514',
      message = 'ARCHIVED_TERM_READ_ONLY',
      detail = 'Archived term cannot be modified.';
  end if;
end;
$$;

create or replace function public.guard_mutation_time_slots()
returns trigger
language plpgsql
as $$
begin
  perform public.raise_if_archived_term_by_term_id(coalesce(new.term_id, old.term_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_class_groups()
returns trigger
language plpgsql
as $$
begin
  perform public.raise_if_archived_term_by_term_id(coalesce(new.term_id, old.term_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_class_enrollments()
returns trigger
language plpgsql
as $$
declare
  v_term_id uuid;
begin
  select cg.term_id
    into v_term_id
  from public.class_groups cg
  where cg.id = coalesce(new.class_group_id, old.class_group_id);

  perform public.raise_if_archived_term_by_term_id(v_term_id);
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_class_sessions()
returns trigger
language plpgsql
as $$
declare
  v_term_id uuid;
begin
  select cg.term_id
    into v_term_id
  from public.class_groups cg
  where cg.id = coalesce(new.class_group_id, old.class_group_id);

  perform public.raise_if_archived_term_by_term_id(v_term_id);
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_session_teacher_assignments()
returns trigger
language plpgsql
as $$
declare
  v_term_id uuid;
begin
  select cg.term_id
    into v_term_id
  from public.class_sessions cs
  join public.class_groups cg on cg.id = cs.class_group_id
  where cs.id = coalesce(new.class_session_id, old.class_session_id);

  perform public.raise_if_archived_term_by_term_id(v_term_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_guard_mutation_time_slots on public.time_slots;
create trigger trg_guard_mutation_time_slots
before insert or update or delete on public.time_slots
for each row execute function public.guard_mutation_time_slots();

drop trigger if exists trg_guard_mutation_class_groups on public.class_groups;
create trigger trg_guard_mutation_class_groups
before insert or update or delete on public.class_groups
for each row execute function public.guard_mutation_class_groups();

drop trigger if exists trg_guard_mutation_class_enrollments on public.class_enrollments;
create trigger trg_guard_mutation_class_enrollments
before insert or update or delete on public.class_enrollments
for each row execute function public.guard_mutation_class_enrollments();

drop trigger if exists trg_guard_mutation_class_sessions on public.class_sessions;
create trigger trg_guard_mutation_class_sessions
before insert or update or delete on public.class_sessions
for each row execute function public.guard_mutation_class_sessions();

drop trigger if exists trg_guard_mutation_session_teacher_assignments on public.session_teacher_assignments;
create trigger trg_guard_mutation_session_teacher_assignments
before insert or update or delete on public.session_teacher_assignments
for each row execute function public.guard_mutation_session_teacher_assignments();
