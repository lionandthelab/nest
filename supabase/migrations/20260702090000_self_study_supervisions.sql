-- 공과 자습 감독 오버라이드 (self_study_supervisions)
--
-- 배경: self_study_slots 는 슬롯(반·요일·공강)당 감독 1명만 담는다. 그러나
-- 수기 출석부(엑셀)의 월 중예배실·금요일처럼 "한 방을 여러 학년이 종일 함께
-- 쓰고, 감독이 시간대(9-10/10-11/11-12)·날짜(주차)별로 회전"하는 경우는
-- 슬롯 1개의 감독 필드로 표현할 수 없다.
--
-- 이 테이블은 (요일·방·시간밴드·날짜)별 감독을 별도로 저장하는 오버라이드
-- 계층이다. 출석부 감독 행은 다음 우선순위로 감독을 결정한다:
--   1) occurrence_date = 해당 날짜 인 행
--   2) occurrence_date = null(매주 기본) 인 행
--   3) 그 밴드를 포함하는 슬롯의 supervisor_teacher_id
--   4) 미지정
--
-- 권한: 소속 plan 의 term 역할로 강제(자습 슬롯과 동일).

create table if not exists public.self_study_supervisions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.self_study_plans(id) on delete cascade,
  day_of_week smallint not null,
  room text not null default '',
  band_start time not null,
  band_end time not null,
  -- null = 매주 기본, 값 = 특정 날짜 오버라이드.
  occurrence_date date,
  supervisor_teacher_id uuid references public.teacher_profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ss_superv_day_check check (day_of_week between 0 and 6),
  constraint ss_superv_band_order check (band_start < band_end)
);

create index if not exists idx_ss_superv_plan
  on public.self_study_supervisions(plan_id);

-- 매주 기본 감독은 (plan,요일,방,밴드시작)당 1개.
create unique index if not exists uq_ss_superv_default
  on public.self_study_supervisions(plan_id, day_of_week, room, band_start)
  where occurrence_date is null;

-- 날짜 오버라이드는 (plan,요일,방,밴드시작,날짜)당 1개.
create unique index if not exists uq_ss_superv_dated
  on public.self_study_supervisions(plan_id, day_of_week, room, band_start, occurrence_date)
  where occurrence_date is not null;

drop trigger if exists trg_ss_superv_updated_at on public.self_study_supervisions;
create trigger trg_ss_superv_updated_at
before update on public.self_study_supervisions
for each row execute function public.set_updated_at();

alter table public.self_study_supervisions enable row level security;

drop policy if exists ss_superv_select_member on public.self_study_supervisions;
create policy ss_superv_select_member on public.self_study_supervisions
for select using (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id and public.is_term_member(p.term_id)
  )
);

drop policy if exists ss_superv_insert_admin_staff on public.self_study_supervisions;
create policy ss_superv_insert_admin_staff on public.self_study_supervisions
for insert with check (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);

drop policy if exists ss_superv_update_admin_staff on public.self_study_supervisions;
create policy ss_superv_update_admin_staff on public.self_study_supervisions
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

drop policy if exists ss_superv_delete_admin_staff on public.self_study_supervisions;
create policy ss_superv_delete_admin_staff on public.self_study_supervisions
for delete using (
  exists (
    select 1 from public.self_study_plans p
    where p.id = plan_id
      and public.has_term_role(p.term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
  )
);
