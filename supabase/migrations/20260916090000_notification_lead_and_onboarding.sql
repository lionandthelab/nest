-- 알림 설정 강화: 수업 전 리드타임 사용자 선택 + 알림 온보딩 1회 표시 기록
--
-- 배경: 지금까지 알림 시각은 서버에 박혀 있었다. 아침 일정은 07:30, 수업 알림은
--   "30분 전" 고정이다. 학교마다 등원 준비 시간이 달라서 30분 전이 누구에겐
--   너무 늦고(이미 출발했어야) 누구에겐 너무 이르다. 그래서 알림을 아예 꺼 버리는데,
--   한 번 끄면 다시 켜지 않는다.
--
-- 이번 변경은 수업 전 리드타임만 사용자 선택으로 연다. 아침 시각까지 열려면
--   아침 cron(하루 1회)을 30분마다 돌게 바꿔야 해서 운영 일정에 손을 대야 한다.
--   리드타임은 리마인더 cron 이 이미 5분마다 돌고 있어 cron 변경 없이 된다.

-- =====================================================
-- 1) 수업 전 리드타임
-- =====================================================
--
-- 10/20/30/60 만 허용한다. 자유 입력을 받으면 발송 창(cron 주기)과 어긋나는 값이
-- 들어와 조용히 알림이 빠질 수 있다. 기본값 30 은 지금 동작과 같아서, 이미 쓰고
-- 있는 사용자는 아무것도 바뀌지 않는다.

alter table public.notification_prefs
  add column if not exists class_reminder_lead_min smallint not null default 30;

do $$
begin
  alter table public.notification_prefs
    add constraint notification_prefs_lead_min_check
    check (class_reminder_lead_min in (10, 20, 30, 60));
exception
  when duplicate_object then null;
end;
$$;

-- =====================================================
-- 2) 알림 온보딩 표시 기록
-- =====================================================
--
-- 최초 1회 전체화면 안내를 띄웠는지. 기기가 아니라 계정에 붙여야 폰을 바꾸거나
-- 웹·앱을 오갈 때 같은 안내가 다시 뜨지 않는다.
--
-- "건너뛰기" 도 표시로 친다. 안내는 한 번이면 충분하고, 그 뒤로는 알림이 꺼져
-- 있을 때만 홈 배너로 가볍게 다시 권한다.

alter table public.notification_prefs
  add column if not exists notif_onboarded_at timestamptz;

comment on column public.notification_prefs.class_reminder_lead_min is
  '수업 시작 몇 분 전에 알릴지. 10/20/30/60 만 허용.';
comment on column public.notification_prefs.notif_onboarded_at is
  '알림 온보딩(전체화면)을 보여준 시각. null 이면 아직 안 봤다.';
