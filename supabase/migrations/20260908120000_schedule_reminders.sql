-- 푸시 리마인더: 알림 설정 컬럼 + 중복 발송 방지 + 인박스 필드 + (가능하면) cron

alter table public.notification_prefs
  add column if not exists morning_digest_enabled boolean not null default true;

alter table public.notification_prefs
  add column if not exists class_reminder_enabled boolean not null default true;

alter table public.notification_log
  add column if not exists event_type text;

alter table public.notification_log
  add column if not exists title text;

alter table public.notification_log
  add column if not exists body text;

alter table public.notification_log
  add column if not exists payload jsonb;

create table if not exists public.schedule_reminder_sends (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('MORNING_DIGEST', 'CLASS_REMINDER')),
  occurrence_date date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  class_session_id uuid references public.class_sessions(id) on delete cascade,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_schedule_reminder_digest
  on public.schedule_reminder_sends (event_type, occurrence_date, user_id)
  where event_type = 'MORNING_DIGEST';

create unique index if not exists uq_schedule_reminder_class
  on public.schedule_reminder_sends (event_type, occurrence_date, user_id, class_session_id)
  where event_type = 'CLASS_REMINDER';

create index if not exists idx_schedule_reminder_sends_date
  on public.schedule_reminder_sends (occurrence_date, event_type);

alter table public.schedule_reminder_sends enable row level security;

-- 클라이언트는 읽기/쓰기 불가. Edge Function(service_role)만 사용.
revoke all on table public.schedule_reminder_sends from anon, authenticated;

-- pg_cron 이 켜져 있으면 5분/아침 07:30 KST 스케줄을 건다.
-- 프로젝트에 확장이 없으면 이 블록은 조용히 건너뛴다.
do $$
begin
  create extension if not exists pg_cron;
  create extension if not exists pg_net;
exception
  when others then
    raise notice 'pg_cron/pg_net 을 켤 수 없습니다. GitHub Actions nest_remind 워크플로를 쓰세요.';
end;
$$;

do $$
declare
  v_url text := current_setting('app.settings.supabase_url', true);
begin
  if v_url is null or v_url = '' then
    v_url := 'https://avursvhmilcsssabqtkx.supabase.co';
  end if;

  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname in ('nest-class-reminder', 'nest-morning-digest');

    perform cron.schedule(
      'nest-class-reminder',
      '*/5 * * * *',
      format(
        $cron$
        select net.http_post(
          url := %L,
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', coalesce(current_setting('app.settings.nest_cron_secret', true), '')
          ),
          body := '{"job":"CLASS_REMINDER"}'::jsonb
        );
        $cron$,
        v_url || '/functions/v1/nest-remind'
      )
    );

    -- 22:30 UTC = 07:30 Asia/Seoul (KST, DST 없음)
    perform cron.schedule(
      'nest-morning-digest',
      '30 22 * * *',
      format(
        $cron$
        select net.http_post(
          url := %L,
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', coalesce(current_setting('app.settings.nest_cron_secret', true), '')
          ),
          body := '{"job":"MORNING_DIGEST"}'::jsonb
        );
        $cron$,
        v_url || '/functions/v1/nest-remind'
      )
    );
  end if;
exception
  when others then
    raise notice '리마인더 cron 등록을 건너뜁니다: %', sqlerrm;
end;
$$;
