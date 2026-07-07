-- =====================================================
-- Term deletion + ARCHIVED immutability hardening
-- =====================================================
-- 1) Adds a DELETE RLS policy so admins/staff can delete a term. Terms are
--    referenced by class_groups / class_sessions / time_slots / classrooms /
--    self_study_plans with ON DELETE CASCADE, so deleting a term removes all of
--    its scheduling data. academic_events keep their rows (term_id SET NULL).
--
-- 2) ARCHIVED terms are permanent, immutable records. This migration makes that
--    invariant authoritative at the DB layer:
--      - guard_delete_terms  : BEFORE DELETE on terms — blocks deleting ARCHIVED.
--      - guard_update_archived_terms : BEFORE UPDATE on terms — blocks changing
--        name/start_date/end_date while status stays ARCHIVED (un-archiving,
--        i.e. moving status away from ARCHIVED, is still allowed).
--    NOTE: guard_delete_terms is the authoritative ARCHIVED-delete block. The
--    older child-table guard triggers (20260302173000) exist ONLY on time_slots,
--    class_groups, class_enrollments, class_sessions, session_teacher_assignments
--    — classrooms and the self_study_* tables have NO such trigger, so for an
--    archived term whose only children are those, guard_delete_terms is the sole
--    protection (which is sufficient). (3) below adds the missing self_study
--    guards for symmetric defense-in-depth with the rest of the schema.
--
-- 3) Adds ARCHIVED-mutation guards on self_study_plans / self_study_slots /
--    self_study_slot_exclusions (parity with class_* tables) so an archived
--    term's self-study data cannot be mutated directly, matching the app-layer
--    read-only lock (NestController.isSelectedTermReadOnly).

-- ── (1) DELETE policy ────────────────────────────────────────────────────────
drop policy if exists terms_delete_admin_staff on public.terms;
create policy terms_delete_admin_staff on public.terms
for delete using (
  public.has_homeschool_role(homeschool_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- ── (2) Terms: block deleting / editing ARCHIVED ─────────────────────────────
create or replace function public.guard_delete_terms()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'ARCHIVED' then
    raise exception using
      errcode = '23514',
      message = 'ARCHIVED_TERM_READ_ONLY',
      detail = 'Archived term cannot be deleted.';
  end if;
  return old;
end;
$$;

drop trigger if exists trg_guard_delete_terms on public.terms;
create trigger trg_guard_delete_terms
before delete on public.terms
for each row execute function public.guard_delete_terms();

create or replace function public.guard_update_archived_terms()
returns trigger
language plpgsql
as $$
begin
  -- Allow un-archiving (status moving away from ARCHIVED). Block name/date edits
  -- while the term remains ARCHIVED.
  if old.status = 'ARCHIVED' and new.status = 'ARCHIVED' then
    if new.name is distinct from old.name
       or new.start_date is distinct from old.start_date
       or new.end_date is distinct from old.end_date then
      raise exception using
        errcode = '23514',
        message = 'ARCHIVED_TERM_READ_ONLY',
        detail = 'Archived term name/dates cannot be modified.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_update_archived_terms on public.terms;
create trigger trg_guard_update_archived_terms
before update on public.terms
for each row execute function public.guard_update_archived_terms();

-- ── (3) self_study_*: ARCHIVED-mutation guards (parity with class_* tables) ──
create or replace function public.guard_mutation_self_study_plans()
returns trigger
language plpgsql
as $$
begin
  perform public.raise_if_archived_term_by_term_id(coalesce(new.term_id, old.term_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_self_study_slots()
returns trigger
language plpgsql
as $$
declare
  v_term_id uuid;
begin
  select p.term_id
    into v_term_id
  from public.self_study_plans p
  where p.id = coalesce(new.plan_id, old.plan_id);

  perform public.raise_if_archived_term_by_term_id(v_term_id);
  return coalesce(new, old);
end;
$$;

create or replace function public.guard_mutation_self_study_slot_exclusions()
returns trigger
language plpgsql
as $$
declare
  v_term_id uuid;
begin
  select p.term_id
    into v_term_id
  from public.self_study_slots s
  join public.self_study_plans p on p.id = s.plan_id
  where s.id = coalesce(new.slot_id, old.slot_id);

  perform public.raise_if_archived_term_by_term_id(v_term_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_guard_mutation_self_study_plans on public.self_study_plans;
create trigger trg_guard_mutation_self_study_plans
before insert or update or delete on public.self_study_plans
for each row execute function public.guard_mutation_self_study_plans();

drop trigger if exists trg_guard_mutation_self_study_slots on public.self_study_slots;
create trigger trg_guard_mutation_self_study_slots
before insert or update or delete on public.self_study_slots
for each row execute function public.guard_mutation_self_study_slots();

drop trigger if exists trg_guard_mutation_self_study_slot_exclusions on public.self_study_slot_exclusions;
create trigger trg_guard_mutation_self_study_slot_exclusions
before insert or update or delete on public.self_study_slot_exclusions
for each row execute function public.guard_mutation_self_study_slot_exclusions();
