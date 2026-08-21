-- 결석 신고 (absence_reports)
--
-- 학생 본인 또는 보호자가 "다가오는 특정 날짜의 특정 수업"에 결석함을 미리 알린다.
-- 담당 교사에게는 nest-notify Edge Function 이 문자/알림톡으로 통지한다.
--
-- 날짜 모델: class_sessions 에는 날짜가 없다(주간 반복 템플릿). 그래서 신고는
--   (class_session_id, occurrence_date) 조합으로 특정 회차를 가리키고,
--   RPC 가 occurrence_date 의 요일이 그 수업의 time_slots.day_of_week 와 같은지,
--   학기 기간 안인지, 과거가 아닌지를 검증한다.
--   Postgres 의 extract(dow) 와 앱 규약이 둘 다 0=일요일이라 오프셋 보정은 없다.
--
-- 쓰기 경로: INSERT 정책을 두지 않고 report_absence() RPC 로만 만든다.
--   (수강 여부·날짜 정합성 검증을 우회할 수 없게 하기 위함)
--
-- 상태: SUBMITTED → ACKNOWLEDGED(교사 확인) 또는 CANCELED(신고 철회).

-- =====================================================
-- 1) 테이블
-- =====================================================

create table if not exists public.absence_reports (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references public.class_sessions(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  occurrence_date date not null,
  reason text not null default '',
  reported_by_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'SUBMITTED' check (
    status in ('SUBMITTED', 'ACKNOWLEDGED', 'CANCELED')
  ),
  acknowledged_by_user_id uuid references auth.users(id) on delete set null,
  acknowledged_at timestamptz,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 같은 회차에 대해 살아있는 신고는 1건만. (철회된 건은 이력으로 남는다)
create unique index if not exists uq_absence_active
  on public.absence_reports (class_session_id, child_id, occurrence_date)
  where status <> 'CANCELED';

create index if not exists idx_absence_reports_date
  on public.absence_reports (occurrence_date, class_session_id);

create index if not exists idx_absence_reports_child
  on public.absence_reports (child_id, occurrence_date desc);

-- =====================================================
-- 2) 트리거 (updated_at + ARCHIVED 학기 가드)
-- =====================================================

drop trigger if exists trg_absence_reports_updated_at on public.absence_reports;
create trigger trg_absence_reports_updated_at
before update on public.absence_reports
for each row execute function public.set_updated_at();

create or replace function public.guard_mutation_absence_reports()
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

drop trigger if exists trg_guard_mutation_absence_reports on public.absence_reports;
create trigger trg_guard_mutation_absence_reports
before insert or update or delete on public.absence_reports
for each row execute function public.guard_mutation_absence_reports();

-- =====================================================
-- 3) RLS
-- =====================================================

alter table public.absence_reports enable row level security;

drop policy if exists absence_reports_select_related on public.absence_reports;
create policy absence_reports_select_related on public.absence_reports
for select using (
  public.is_child_guardian(child_id)
  or public.is_child_self(child_id)
  or public.is_session_teacher(class_session_id)
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

-- INSERT 정책 없음: report_absence() RPC(security definer)로만 생성한다.

-- 수정: 담당 교사/관리자는 자유롭게, 신고자 본인은 "철회(CANCELED)"만 가능.
drop policy if exists absence_reports_update_teacher_admin_or_reporter on public.absence_reports;
create policy absence_reports_update_teacher_admin_or_reporter on public.absence_reports
for update using (
  public.is_session_teacher(class_session_id)
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
  or reported_by_user_id = auth.uid()
)
with check (
  public.is_session_teacher(class_session_id)
  or public.has_class_session_role(
    class_session_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
  -- 신고자 본인 분기: 철회만 허용하고, 철회 후에도 그 행이 여전히 "본인과 관계된
  -- 자녀"를 가리키게 강제한다. WITH CHECK 는 OLD 를 볼 수 없으므로 이 조건이 없으면
  -- 신고자가 자기 신고의 child_id 를 남의 자녀로 바꿔치기해(status 는 CANCELED 로
  -- 맞추고) 다른 가정에 유령 결석 이력을 심을 수 있다.
  or (
    reported_by_user_id = auth.uid()
    and status = 'CANCELED'
    and (public.is_child_guardian(child_id) or public.is_child_self(child_id))
  )
);

-- =====================================================
-- 4) 신고 RPC
-- =====================================================

create or replace function public.report_absence(
  p_class_session_id uuid,
  p_child_id uuid,
  p_occurrence_date date,
  p_reason text default ''
)
returns public.absence_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session record;
  v_existing_id uuid;
  v_row public.absence_reports%rowtype;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if not (public.is_child_guardian(p_child_id) or public.is_child_self(p_child_id)) then
    raise exception using
      errcode = '42501',
      message = 'FORBIDDEN',
      detail = '본인 또는 보호자만 결석을 신고할 수 있습니다.';
  end if;

  select
    cs.id as class_session_id,
    cs.class_group_id as class_group_id,
    ts.day_of_week as day_of_week,
    t.start_date as term_start,
    t.end_date as term_end
  into v_session
  from public.class_sessions cs
  join public.class_groups cg on cg.id = cs.class_group_id
  join public.terms t on t.id = cg.term_id
  join public.time_slots ts on ts.id = cs.time_slot_id
  where cs.id = p_class_session_id;

  if v_session is null then
    raise exception using
      errcode = 'P0002',
      message = 'SESSION_NOT_FOUND',
      detail = '수업을 찾을 수 없습니다.';
  end if;

  if not exists (
    select 1
    from public.class_enrollments e
    where e.class_group_id = v_session.class_group_id
      and e.child_id = p_child_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'NOT_ENROLLED',
      detail = '해당 수업을 듣는 학생이 아닙니다.';
  end if;

  if p_occurrence_date is null then
    raise exception using
      errcode = '22023',
      message = 'DATE_REQUIRED',
      detail = '결석 날짜를 선택해 주세요.';
  end if;

  if extract(dow from p_occurrence_date)::int <> v_session.day_of_week then
    raise exception using
      errcode = '22023',
      message = 'DATE_WEEKDAY_MISMATCH',
      detail = '선택한 날짜의 요일이 이 수업의 요일과 다릅니다.';
  end if;

  if p_occurrence_date < v_session.term_start or p_occurrence_date > v_session.term_end then
    raise exception using
      errcode = '22023',
      message = 'DATE_OUT_OF_TERM',
      detail = '학기 기간 밖의 날짜입니다.';
  end if;

  if p_occurrence_date < current_date then
    raise exception using
      errcode = '22023',
      message = 'PAST_DATE',
      detail = '지난 날짜는 결석 신고를 할 수 없습니다.';
  end if;

  -- 같은 회차에 대한 기존 신고가 있으면 되살린다(철회했다가 다시 신고하는 경우 포함).
  select r.id
    into v_existing_id
  from public.absence_reports r
  where r.class_session_id = p_class_session_id
    and r.child_id = p_child_id
    and r.occurrence_date = p_occurrence_date
  order by (r.status <> 'CANCELED') desc, r.created_at desc
  limit 1;

  if v_existing_id is not null then
    update public.absence_reports r
    set status = 'SUBMITTED',
        reason = coalesce(p_reason, ''),
        reported_by_user_id = v_uid,
        acknowledged_by_user_id = null,
        acknowledged_at = null,
        notified_at = null
    where r.id = v_existing_id
    returning * into v_row;
  else
    insert into public.absence_reports (
      class_session_id, child_id, occurrence_date, reason,
      reported_by_user_id, status
    )
    values (
      p_class_session_id, p_child_id, p_occurrence_date, coalesce(p_reason, ''),
      v_uid, 'SUBMITTED'
    )
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

grant execute on function public.report_absence(uuid, uuid, date, text) to authenticated;

-- =====================================================
-- 5) 철회 / 확인 RPC
-- =====================================================

create or replace function public.cancel_absence_report(p_report_id uuid)
returns public.absence_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_report record;
  v_row public.absence_reports%rowtype;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select r.id, r.child_id, r.reported_by_user_id
    into v_report
  from public.absence_reports r
  where r.id = p_report_id;

  if v_report is null then
    raise exception using
      errcode = 'P0002',
      message = 'REPORT_NOT_FOUND',
      detail = '결석 신고를 찾을 수 없습니다.';
  end if;

  if not (
    v_report.reported_by_user_id = v_uid
    or public.is_child_guardian(v_report.child_id)
    or public.is_child_self(v_report.child_id)
  ) then
    raise exception using
      errcode = '42501',
      message = 'FORBIDDEN',
      detail = '이 결석 신고를 철회할 권한이 없습니다.';
  end if;

  update public.absence_reports r
  set status = 'CANCELED'
  where r.id = p_report_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.cancel_absence_report(uuid) to authenticated;

create or replace function public.acknowledge_absence_report(p_report_id uuid)
returns public.absence_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_report record;
  v_row public.absence_reports%rowtype;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select r.id, r.class_session_id, r.status
    into v_report
  from public.absence_reports r
  where r.id = p_report_id;

  if v_report is null then
    raise exception using
      errcode = 'P0002',
      message = 'REPORT_NOT_FOUND',
      detail = '결석 신고를 찾을 수 없습니다.';
  end if;

  if not (
    public.is_session_teacher(v_report.class_session_id)
    or public.has_class_session_role(
      v_report.class_session_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  ) then
    raise exception using
      errcode = '42501',
      message = 'FORBIDDEN',
      detail = '담당 교사 또는 관리자만 확인 처리할 수 있습니다.';
  end if;

  if v_report.status = 'CANCELED' then
    raise exception using
      errcode = '22023',
      message = 'REPORT_CANCELED',
      detail = '이미 철회된 결석 신고입니다.';
  end if;

  update public.absence_reports r
  set status = 'ACKNOWLEDGED',
      acknowledged_by_user_id = v_uid,
      acknowledged_at = now()
  where r.id = p_report_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.acknowledge_absence_report(uuid) to authenticated;
