-- 수업 변경 공지 (class_session_changes)
--
-- 배경: class_sessions 는 "요일×교시" 주간 반복 템플릿이라 날짜 컬럼이 없다.
-- 그래서 "이번 주 목요일 3교시만 휴강", "다음 주부터 학기 끝까지 교실 이동" 같은
-- 실제 운영 공지를 표현할 방법이 없었다.
--
-- 설계: 단일 테이블 + 유효기간(effective_from ~ effective_to).
--   * effective_to is null  → 학기 끝까지 계속 적용
--   * effective_from = effective_to → 그 날짜 하루만("이번 주만")
--   self_study_supervisions 의 날짜 오버라이드 패턴과 같은 계층 구조다.
--
-- 권한(D5): 그 수업의 담당 교사(MAIN/ASSISTANT) 또는 반 담임 또는 ADMIN/STAFF.
--   교사는 기존 시간표 테이블에 쓰기 권한이 없으므로(전부 ADMIN/STAFF 전용),
--   이 "변경 공지" 계층을 통해서만 학생·학부모에게 변경을 알린다.
--   교사 자신이 만든 행만 수정/삭제할 수 있고, ADMIN/STAFF 는 전부 가능하다.
--
-- notified_at: nest-notify Edge Function 이 발송을 마치면 채우는 타임스탬프.
--   (중복 발송 방지 / 발송 여부 표시용)

-- =====================================================
-- 1) 테이블
-- =====================================================

create table if not exists public.class_session_changes (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references public.class_sessions(id) on delete cascade,
  change_type text not null check (
    change_type in ('CANCELED', 'TIME_MOVED', 'ROOM_MOVED', 'TEACHER_SUBSTITUTE', 'NOTE')
  ),
  -- 적용 시작일(포함). "이번 주만" 은 from = to = 그 날짜.
  effective_from date not null,
  -- null = 학기 끝까지.
  effective_to date,
  new_time_slot_id uuid references public.time_slots(id) on delete set null,
  new_location text,
  substitute_teacher_id uuid references public.teacher_profiles(id) on delete set null,
  reason text not null default '',
  created_by_user_id uuid references auth.users(id) on delete set null,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_session_changes_effective_range
    check (effective_to is null or effective_to >= effective_from)
);

create index if not exists idx_class_session_changes_session
  on public.class_session_changes (class_session_id, effective_from);

-- =====================================================
-- 2) 담당 교사 판별 헬퍼
-- =====================================================
--
-- 담당 교사 = 세션에 배정된 교사(MAIN/ASSISTANT) ∪ 그 반의 담임.
--
-- ⚠️ ACTIVE 멤버십을 반드시 함께 요구한다.
--   teacher_profiles.user_id 는 멤버십을 지워도 그대로 남는다(정리 트리거가 없다).
--   그래서 이 조건이 없으면 홈스쿨을 떠난(멤버십 삭제/EXPIRED) 교사가 여전히
--   "담당 교사"로 판정되어 수업 변경 공지를 등록하고 그 반 전체 학부모에게
--   문자를 발송할 수 있다. 이 레포의 다른 헬퍼(is_*_member / has_*_role)는 전부
--   status='ACTIVE' 를 요구하므로 그 규약에 맞춘다.

create or replace function public.is_session_teacher(p_class_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.session_teacher_assignments sta
    join public.teacher_profiles tp on tp.id = sta.teacher_profile_id
    where sta.class_session_id = p_class_session_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      and public.is_homeschool_member(tp.homeschool_id)
  ) or exists (
    select 1
    from public.class_sessions cs
    join public.class_groups cg on cg.id = cs.class_group_id
    join public.teacher_profiles tp on tp.id = cg.main_teacher_id
    where cs.id = p_class_session_id
      and tp.user_id is not null
      and tp.user_id = auth.uid()
      and public.is_homeschool_member(tp.homeschool_id)
  );
$$;

grant execute on function public.is_session_teacher(uuid) to authenticated;

-- =====================================================
-- 3) 트리거 (updated_at + ARCHIVED 학기 가드)
-- =====================================================

drop trigger if exists trg_class_session_changes_updated_at on public.class_session_changes;
create trigger trg_class_session_changes_updated_at
before update on public.class_session_changes
for each row execute function public.set_updated_at();

create or replace function public.guard_mutation_class_session_changes()
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

drop trigger if exists trg_guard_mutation_class_session_changes on public.class_session_changes;
create trigger trg_guard_mutation_class_session_changes
before insert or update or delete on public.class_session_changes
for each row execute function public.guard_mutation_class_session_changes();

-- =====================================================
-- 4) RLS
-- =====================================================

alter table public.class_session_changes enable row level security;

-- 조회: 그 수업이 속한 홈스쿨의 구성원 전체(학생 포함). 시간표와 동일한 가시성.
drop policy if exists class_session_changes_select_member on public.class_session_changes;
create policy class_session_changes_select_member on public.class_session_changes
for select using (
  public.is_class_session_member(class_session_id)
);

drop policy if exists class_session_changes_insert_teacher_admin on public.class_session_changes;
create policy class_session_changes_insert_teacher_admin on public.class_session_changes
for insert with check (
  public.is_session_teacher(class_session_id)
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

-- 수정/삭제: 교사는 "자기가 등록한 공지"만. ADMIN/STAFF 는 전부.
drop policy if exists class_session_changes_update_teacher_admin on public.class_session_changes;
create policy class_session_changes_update_teacher_admin on public.class_session_changes
for update using (
  (public.is_session_teacher(class_session_id) and created_by_user_id = auth.uid())
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
)
with check (
  (public.is_session_teacher(class_session_id) and created_by_user_id = auth.uid())
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists class_session_changes_delete_teacher_admin on public.class_session_changes;
create policy class_session_changes_delete_teacher_admin on public.class_session_changes
for delete using (
  (public.is_session_teacher(class_session_id) and created_by_user_id = auth.uid())
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);
