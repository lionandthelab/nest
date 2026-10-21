-- 세부 이벤트별 푸시 알림 수신 설정 확장 (2026-10)
--
-- 배경: 기존 notification_prefs 는 전체 푸시(push_enabled), 아침 일정 브리핑(morning_digest_enabled),
-- 수업 전 알림(class_reminder_enabled), 방해금지 시간(quiet_hours_start/end)만 제어할 수 있었다.
-- 홈스쿨 내 주요 도메인 이벤트(수업 변경, 결석 신고/확인, 공지사항, 학사 일정, 아이 활동 기록/수업 계획,
-- 실시간 채팅, 커뮤니티 새 글/댓글, 추억 앨범 사진/영상 업로드)마다 즉시 푸시 알림이 발송되도록
-- 확장하면서, 사용자가 원하는 알림 종류만 세밀하게 켜고 끌 수 있도록 컬럼을 추가한다.

alter table public.notification_prefs
  add column if not exists class_change_enabled boolean not null default true,
  add column if not exists absence_enabled boolean not null default true,
  add column if not exists announcement_enabled boolean not null default true,
  add column if not exists academic_event_enabled boolean not null default true,
  add column if not exists student_log_enabled boolean not null default true,
  add column if not exists chat_enabled boolean not null default true,
  add column if not exists community_enabled boolean not null default true,
  add column if not exists gallery_enabled boolean not null default true;

comment on column public.notification_prefs.class_change_enabled is
  '휴강·보강·시간/교실 변경 알림 수신 여부';
comment on column public.notification_prefs.absence_enabled is
  '결석 신고 접수 및 교사 확인 알림 수신 여부';
comment on column public.notification_prefs.announcement_enabled is
  '전체 공지 및 반 공지사항 등록 알림 수신 여부';
comment on column public.notification_prefs.academic_event_enabled is
  '학사 일정 및 학교 행사 등록 알림 수신 여부';
comment on column public.notification_prefs.student_log_enabled is
  '우리 아이 활동·관찰 기록 및 수업 계획 등록 알림 수신 여부';
comment on column public.notification_prefs.chat_enabled is
  '홈스쿨 실시간 채팅(전체·반별·1:1) 메시지 알림 수신 여부';
comment on column public.notification_prefs.community_enabled is
  '커뮤니티 새 게시글 및 댓글 알림 수신 여부';
comment on column public.notification_prefs.gallery_enabled is
  '추억 앨범 새 사진·동영상 업로드 알림 수신 여부';
