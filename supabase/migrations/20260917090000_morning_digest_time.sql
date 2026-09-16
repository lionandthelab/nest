-- 아침 알림 시각을 사용자가 고를 수 있게 한다.
--
-- 배경: 아침 "오늘 일정"은 07:30 에 고정이었다. 등원 준비 시간이 집마다 달라서
--   누구에겐 이미 나갈 채비가 끝난 뒤고 누구에겐 아직 자는 시간이다. 그러면
--   알림을 꺼 버리고, 한 번 끈 알림은 다시 켜지 않는다.
--
-- 리드타임(20260916)과 같은 방식이다. 다만 이쪽은 cron 주기까지 바꿔야 한다.
--   아침 잡이 하루 한 번(22:30 UTC = 07:30 KST)만 돌고 있었기 때문이다.

-- =====================================================
-- 1) 컬럼
-- =====================================================
--
-- 자정부터의 분으로 둔다. 06:30=390, 07:00=420, 07:30=450, 08:00=480.
-- time 보다 비교가 단순하고, 발송 잡이 쓰는 단위와 같다.
--
-- 격자에 없는 값을 막는 이유: 발송 잡이 30분 간격으로 돌면서 훑기 때문에,
-- 그 사이의 시각은 제 때 걸리지 않고 한 회차 늦게 가거나 빠진다.

alter table public.notification_prefs
  add column if not exists morning_digest_min smallint not null default 450;

do $$
begin
  alter table public.notification_prefs
    add constraint notification_prefs_morning_min_check
    check (morning_digest_min in (390, 420, 450, 480));
exception
  when duplicate_object then null;
end;
$$;

comment on column public.notification_prefs.morning_digest_min is
  '아침 오늘 일정을 보낼 시각(자정부터 분, KST). 390/420/450/480 만 허용.';

-- =====================================================
-- 2) cron: 하루 1회 → 아침 구간 30분마다
-- =====================================================
--
-- 사용자마다 시각이 다르니 잡이 그 시각마다 깨어 있어야 한다. 실제 발송 여부는
-- Edge Function 이 사람별로 판단하고, 이미 보낸 건 schedule_reminder_sends 의
-- 유니크 인덱스가 막는다. 그래서 여러 번 깨워도 중복 발송은 없다.
--
-- UTC 21:00~23:30 = KST 06:00~08:30. 가장 이른 선택(06:30)과 가장 늦은
-- 선택(08:00)을 창(35분)까지 포함해 덮는다.

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
    where jobname = 'nest-morning-digest';

    perform cron.schedule(
      'nest-morning-digest',
      '0,30 21-23 * * *',
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
    raise notice 'pg_cron 재스케줄에 실패했습니다. GitHub Actions nest_remind 워크플로를 쓰세요.';
end;
$$;
