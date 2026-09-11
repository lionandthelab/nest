-- 개인 일정 + 학사일정 공지 연동 + 사용자별 Google Calendar 토큰
--
-- 학기 시간표(class_sessions)는 요일×교시 템플릿이다. 날짜가 있는 일정은
-- personal_events(가정)와 academic_events(전교) 두 계층으로 쌓는다.
-- 토큰 컬럼은 클라이언트 GRANT에서 빼 프론트가 select * 로도 못 읽게 한다.

-- =====================================================
-- 1) academic_events 확장
-- =====================================================

alter table public.academic_events
  add column if not exists kind text not null default 'EVENT',
  add column if not exists start_time time,
  add column if not exists end_time time,
  add column if not exists publish_announcement boolean not null default true,
  add column if not exists announcement_id uuid references public.announcements(id) on delete set null,
  add column if not exists show_on_timetable boolean not null default true;

alter table public.academic_events
  drop constraint if exists academic_events_kind_check;

alter table public.academic_events
  add constraint academic_events_kind_check
  check (kind in ('EVENT', 'HOLIDAY', 'FIELD_TRIP', 'CEREMONY', 'BREAK'));

comment on column public.academic_events.kind is
  'EVENT/HOLIDAY/FIELD_TRIP/CEREMONY/BREAK';
comment on column public.academic_events.start_time is
  'null 이면 종일 일정. 있으면 그 시각에 시간표 칸과 겹침을 계산한다.';
comment on column public.academic_events.publish_announcement is
  'true 이면 트리거가 공지(announcements)를 만들거나 내용을 맞춘다.';
comment on column public.academic_events.show_on_timetable is
  '주간 시간표 요일 헤더/달력에 학사일정을 올릴지.';

-- 관리 권한을 스태프까지. 기존 정책 이름은 공백이 있어 그대로 drop 한다.
drop policy if exists "Admins can manage academic events" on public.academic_events;

create policy academic_events_write_admin_staff
  on public.academic_events
  for all
  using (
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

-- 학사일정 ↔ 공지 동기화. SECURITY DEFINER 라 공지 RLS를 우회한다.
create or replace function public.sync_academic_event_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_title text;
  v_body text;
  v_dates text;
  v_times text;
  v_id uuid;
begin
  if TG_OP = 'DELETE' then
    if OLD.announcement_id is not null then
      delete from public.announcements where id = OLD.announcement_id;
    end if;
    return OLD;
  end if;

  if not NEW.publish_announcement then
    if NEW.announcement_id is not null then
      delete from public.announcements where id = NEW.announcement_id;
      NEW.announcement_id := null;
    end if;
    return NEW;
  end if;

  v_author := coalesce(NEW.created_by_user_id, auth.uid());
  if v_author is null then
    return NEW;
  end if;

  v_title := format('[학사일정] %s', NEW.title);

  v_dates := to_char(NEW.event_date, 'YYYY년 MM월 DD일');
  if NEW.end_date is not null and NEW.end_date is distinct from NEW.event_date then
    v_dates := v_dates || ' ~ ' || to_char(NEW.end_date, 'YYYY년 MM월 DD일');
  end if;

  v_times := '';
  if NEW.start_time is not null then
    v_times := E'\n시간: ' || to_char(NEW.start_time, 'HH24:MI');
    if NEW.end_time is not null then
      v_times := v_times || ' - ' || to_char(NEW.end_time, 'HH24:MI');
    end if;
  end if;

  v_body := '날짜: ' || v_dates || v_times;
  if coalesce(NEW.description, '') <> '' then
    v_body := v_body || E'\n\n' || NEW.description;
  end if;

  if NEW.announcement_id is null then
    insert into public.announcements (
      homeschool_id,
      class_group_id,
      author_user_id,
      title,
      body,
      pinned
    ) values (
      NEW.homeschool_id,
      null,
      v_author,
      v_title,
      v_body,
      false
    )
    returning id into v_id;
    NEW.announcement_id := v_id;
  else
    update public.announcements
    set title = v_title,
        body = v_body
    where id = NEW.announcement_id;
  end if;

  return NEW;
end;
$$;

drop trigger if exists academic_events_sync_announcement_write
  on public.academic_events;
drop trigger if exists academic_events_sync_announcement_delete
  on public.academic_events;

create trigger academic_events_sync_announcement_write
  before insert or update on public.academic_events
  for each row
  execute function public.sync_academic_event_announcement();

create trigger academic_events_sync_announcement_delete
  after delete on public.academic_events
  for each row
  execute function public.sync_academic_event_announcement();

-- =====================================================
-- 2) personal_events
-- =====================================================

create table if not exists public.personal_events (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  title text not null,
  notes text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  conflict_policy text not null default 'KEEP_BOTH',
  source text not null default 'NEST',
  google_event_id text,
  google_calendar_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint personal_events_time_ok check (ends_at > starts_at),
  constraint personal_events_policy_ok
    check (conflict_policy in ('KEEP_BOTH', 'PRIORITIZE_PERSONAL')),
  constraint personal_events_source_ok
    check (source in ('NEST', 'GOOGLE'))
);

create index if not exists idx_personal_events_child_time
  on public.personal_events (child_id, starts_at);

create index if not exists idx_personal_events_school_time
  on public.personal_events (homeschool_id, starts_at);

create unique index if not exists uq_personal_events_google
  on public.personal_events (owner_user_id, google_event_id)
  where google_event_id is not null;

create trigger set_personal_events_updated_at
  before update on public.personal_events
  for each row execute function public.set_updated_at();

alter table public.personal_events enable row level security;

-- 보호자·학생 본인만. 관리자/교사는 남의 개인 일정을 보지 않는다.
create policy personal_events_select_family
  on public.personal_events for select
  using (
    public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
  );

create policy personal_events_insert_family
  on public.personal_events for insert
  with check (
    owner_user_id = auth.uid()
    and (public.is_child_guardian(child_id) or public.is_child_self(child_id))
    and exists (
      select 1
      from public.children c
      join public.families f on f.id = c.family_id
      where c.id = child_id
        and f.homeschool_id = homeschool_id
    )
  );

create policy personal_events_update_family
  on public.personal_events for update
  using (
    public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
  )
  with check (
    public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
  );

create policy personal_events_delete_family
  on public.personal_events for delete
  using (
    public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
  );

-- =====================================================
-- 3) calendar_integrations (사용자별 Google Calendar)
-- =====================================================

create table if not exists public.calendar_integrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  homeschool_id uuid references public.homeschools(id) on delete set null,
  provider text not null default 'GOOGLE',
  status text not null default 'DISCONNECTED',
  google_email text,
  google_access_token text,
  google_refresh_token text,
  google_token_expires_at timestamptz,
  oauth_scope text,
  calendar_id text not null default 'primary',
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calendar_integrations_status_ok
    check (status in ('CONNECTED', 'DISCONNECTED', 'ERROR'))
);

create trigger set_calendar_integrations_updated_at
  before update on public.calendar_integrations
  for each row execute function public.set_updated_at();

alter table public.calendar_integrations enable row level security;

create policy calendar_integrations_select_own
  on public.calendar_integrations for select
  using (user_id = auth.uid());

create policy calendar_integrations_update_own
  on public.calendar_integrations for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy calendar_integrations_delete_own
  on public.calendar_integrations for delete
  using (user_id = auth.uid());

-- 토큰은 서비스 롤(Edge Function)만. authenticated 는 상태 컬럼만.
revoke all on public.calendar_integrations from anon, authenticated;
grant select (
  id,
  user_id,
  homeschool_id,
  provider,
  status,
  google_email,
  calendar_id,
  last_synced_at,
  updated_at
) on public.calendar_integrations to authenticated;
grant update (status, homeschool_id) on public.calendar_integrations to authenticated;
grant delete on public.calendar_integrations to authenticated;
