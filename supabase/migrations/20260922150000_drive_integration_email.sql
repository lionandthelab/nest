-- Drive 연결 화면에 "어느 계정에 저장되는지"를 보여 주기 위한 이메일
--
-- 앨범 원본이 관리자 Drive로 가게 되면서, 관리자는 "내 어느 계정의 용량을
-- 쓰는지"를 반드시 확인할 수 있어야 한다. 지금까지는 연결 여부만 알 수 있어
-- 계정이 여러 개인 관리자가 엉뚱한 곳에 붙여 놓고도 알아채지 못했다.
-- 모델(DriveIntegration.googleEmail)은 이미 이 컬럼을 방어적으로 읽고 있다.

alter table public.drive_integrations
  add column if not exists google_email text;
