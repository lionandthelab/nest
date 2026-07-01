-- 공과(수업외 자습) 시간표 기능
--
-- 배경: 수업 시간표(class_sessions/time_slots)를 기준으로, 각 반(class_group)이
-- 지정된 창(예: 오전 9-12시) 안에서 "수업이 없는 빈 시간(공강)"에 자습을 하도록
-- 방/감독을 배정한 시간표를 만든다. 자습 명단은 반의 재원생 전체를 기본 포함하고,
-- 개별 아동을 슬롯 단위로 제외(exclusion)할 수 있다.
--
-- 저장 모델(3테이블):
--   self_study_plans          : 학기별 자습 계획 1개(창/요일/기간/최소 공강 설정)
--   self_study_slots          : 자동 생성/수정되는 (반, 요일, 공강 구간, 방, 감독) 슬롯
--   self_study_slot_exclusions: 슬롯별 제외 아동(기본은 반 전체 포함)
--
-- 격리/권한: 모든 접근은 계획이 속한 학기(term)의 homeschool 역할로 강제한다.
--   조회는 학기 멤버(is_term_member), 쓰기는 HOMESCHOOL_ADMIN/STAFF(has_term_role).

-- =====================================================
-- self_study_plans
-- =====================================================
create table if not exists public.self_study_plans (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id) on delete cascade,
  name text not null,
  -- 채울 요일(ISO 요일: 1=월 .. 7=일, 앱은 0=일..6=토를 쓰나 여기선 정수 배열로 보존).
  days smallint[] not null default array[1, 2, 3, 4, 5]::smallint[],
  window_start time not null default '09:00',
  window_end time not null default '12:00',
  -- 출석부 날짜 열 범위(비어 있으면 앱이 학기 범위로 대체).
  period_start date,
  period_end date,
  -- 이 값보다 짧은 공강은 자습 슬롯으로 만들지 않는다(분).
  min_gap_minutes smallint not null default 60,
  note text not null default '',
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint self_study_plans_name_not_blank check (char_length(trim(name)) > 0),
  constraint self_study_plans_window_order check (window_start < window_end),
  constraint self_study_plans_min_gap_check check (min_gap_minutes between 5 and 600),
  constraint self_study_plans_term_name_unique unique (term_id, name)
);

create index if not exists idx_self_study_plans_term
  on public.self_study_plans(term_id);

drop trigger if exists trg_self_study_plans_updated_at on public.self_study_plans;
create trigger trg_self_study_plans_updated_at
before update on public.self_study_plans
for each row execute function public.set_updated_at();

-- =====================================================
-- self_study_slots
-- =====================================================
create table if not exists public.self_study_slots (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.self_study_plans(id) on delete cascade,
  class_group_id uuid not null references public.class_groups(id) on delete cascade,
  day_of_week smallint not null,
  start_time time not null,
  end_time time not null,
  -- 자습 장소(자유 텍스트; 강의실 이름과 동일 규칙). 미배정이면 빈 문자열.
  room text not null default '',
  supervisor_teacher_id uuid references public.teacher_profiles(id) on delete set null,
  label text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint self_study_slots_day_check check (day_of_week between 0 and 6),
  constraint self_study_slots_time_order check (start_time < end_time)
);

create index if not exists idx_self_study_slots_plan
  on public.self_study_slots(plan_id);
create index if not exists idx_self_study_slots_group
  on public.self_study_slots(class_group_id);

drop trigger if exists trg_self_study_slots_updated_at on public.self_study_slots;
create trigger trg_self_study_slots_updated_at
before update on public.self_study_slots
for each row execute function public.set_updated_at();

-- =====================================================
-- self_study_slot_exclusions
-- =====================================================
create table if not exists public.self_study_slot_exclusions (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references public.self_study_slots(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint self_study_slot_exclusions_unique unique (slot_id, child_id)
);

create index if not exists idx_self_study_slot_exclusions_slot
  on public.self_study_slot_exclusions(slot_id);

-- =====================================================
-- RLS
-- =====================================================
alter table public.self_study_plans enable row level security;
alter table public.self_study_slots enable row level security;
alter table public.self_study_slot_exclusions enable row level security;

-- ── self_study_plans ──
drop policy if exists self_study_plans_select_member on public.self_study_plans;
create policy self_study_plans_select_member on public.self_study_plans
for select using (public.is_term_member(term_id));

drop policy if exists self_study_plans_insert_admin_staff on public.self_study_plans;
create policy self_study_plans_insert_admin_staff on public.self_study_plans
for insert with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists self_study_plans_update_admin_staff on public.self_study_plans;
create policy self_study_plans_update_admin_staff on public.self_study_plans
for update using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
)
with check (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

drop policy if exists self_study_plans_delete_admin_staff on public.self_study_plans;
create policy self_study_plans_delete_admin_staff on public.self_study_plans
for delete using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);

-- ── self_study_slots (권한은 소속 plan 의 term 으로 판단) ──
drop policy if exists self_study_slots_select_member on public.self_study_slots;
create policy self_study_slots_select_member on public.self_study_slots
for select using (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id and public.is_term_member(p.term_id)
  )
);

drop policy if exists self_study_slots_insert_admin_staff on public.self_study_slots;
create policy self_study_slots_insert_admin_staff on public.self_study_slots
for insert with check (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists self_study_slots_update_admin_staff on public.self_study_slots;
create policy self_study_slots_update_admin_staff on public.self_study_slots
for update using (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
)
with check (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists self_study_slots_delete_admin_staff on public.self_study_slots;
create policy self_study_slots_delete_admin_staff on public.self_study_slots
for delete using (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

-- ── self_study_slot_exclusions (권한은 slot→plan→term 으로 판단) ──
drop policy if exists self_study_slot_exclusions_select_member on public.self_study_slot_exclusions;
create policy self_study_slot_exclusions_select_member on public.self_study_slot_exclusions
for select using (
  exists (
    select 1
    from public.self_study_slots s
    join public.self_study_plans p on p.id = s.plan_id
    where s.id = slot_id and public.is_term_member(p.term_id)
  )
);

drop policy if exists self_study_slot_exclusions_insert_admin_staff on public.self_study_slot_exclusions;
create policy self_study_slot_exclusions_insert_admin_staff on public.self_study_slot_exclusions
for insert with check (
  exists (
    select 1
    from public.self_study_slots s
    join public.self_study_plans p on p.id = s.plan_id
    where s.id = slot_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists self_study_slot_exclusions_delete_admin_staff on public.self_study_slot_exclusions;
create policy self_study_slot_exclusions_delete_admin_staff on public.self_study_slot_exclusions
for delete using (
  exists (
    select 1
    from public.self_study_slots s
    join public.self_study_plans p on p.id = s.plan_id
    where s.id = slot_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);
