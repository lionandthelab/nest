# Nest Flutter Architecture

## 1. 목표

- 웹/모바일 단일 코드베이스로 운영/학부모/교사 UX 일관성 유지
- Supabase(Postgres + Auth + Edge Functions) 중심의 단순한 BaaS 아키텍처
- 시간표 생성(프롬프트) + 수동 편집(드래그앤드롭) 동시 제공
- Google Drive 기반 미디어 업로드/갤러리 연동

## 2. 시스템 구성

- Frontend: Flutter (`frontend/`)
- Backend: Supabase
  - Auth: 이메일 로그인
  - DB: Postgres + RLS
  - Edge Functions:
    - `timetable-assistant-generate`
    - `google-drive-connect-start`
    - `google-drive-connect-complete`
    - `google-drive-upload`
- Deployment (Web): GitHub Pages (`gh-pages` branch)

## 3. 프론트엔드 프로젝트 구조

```text
frontend/
  lib/
    main.dart
    src/
      config/
        app_config.dart
      models/
        nest_models.dart
      services/
        nest_repository.dart
        local_planner.dart
        web_oauth_bridge.dart
        web_oauth_bridge_stub.dart
        web_oauth_bridge_web.dart
      state/
        nest_controller.dart
      ui/
        nest_app.dart
        nest_theme.dart
        login_page.dart
        home_page.dart
        tabs/
          dashboard_tab.dart
          timetable_tab.dart
          gallery_tab.dart
          drive_tab.dart
  web/
    index.html
    oauth/google/callback.html
  test/
    widget_test.dart
```

## 4. 상태관리/데이터 흐름

- `NestController`
  - 화면 상태 단일 소스
  - 인증 상태, 운영 컨텍스트, 시간표/갤러리/Drive 상태 관리
  - UI 이벤트를 비즈니스 액션으로 변환
- `NestRepository`
  - Supabase 테이블 CRUD와 Edge Function 호출 캡슐화
  - 컨트롤러는 SQL/HTTP 세부 구현을 몰라도 되도록 분리

## 5. 핵심 기능별 설계

### 5.1 인증/컨텍스트

1. `Supabase.auth` 회원가입/로그인
2. `homeschool_memberships` 로 사용자 소속 조회
3. 선택된 홈스쿨 기준으로 학기/반/권한 로딩

### 5.2 시간표 스튜디오

- Prompt 생성
  1. `timetable-assistant-generate` 호출
  2. 실패 시 `local_planner.dart` fallback 생성
  3. `timetable_proposals`, `timetable_proposal_sessions` 저장
  4. 적용 시 `class_sessions` 삽입
- Manual 편집
  - 과목 칩/수업 카드 Drag & Drop
  - `class_sessions.time_slot_id` 업데이트로 이동
  - 세션 취소는 `status = CANCELED`

### 5.3 Google Drive OAuth

- 시작: `google-drive-connect-start` → OAuth URL 반환
- 웹: 팝업으로 Google 인증 후 `web/oauth/google/callback.html` 진입
- 콜백 페이지가 `google-drive-connect-complete` 직접 호출
- 완료 결과는 `localStorage(nest.oauth.result)` 저장 후 앱 동기화

### 5.4 미디어 업로드/갤러리

1. `media_upload_sessions` 생성
2. `google-drive-upload` 호출 (base64 payload)
3. `media_assets` + `media_asset_children` 저장
4. 갤러리 조회 (`media_assets`, `media_asset_children`)

## 6. 환경 변수

Flutter `dart-define` 지원:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

예시:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## 7. 개발/검증 명령어

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /nest/
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

## 8. GitHub Pages 배포

- Workflow: `.github/workflows/flutter_web_pages.yml`
- 트리거: `main` 브랜치 푸시 (frontend 변경)
- 배포 대상: `frontend/build/web` → `gh-pages`

## 9. OAuth Redirect URI 기준

Google Console과 Supabase `GOOGLE_REDIRECT_URI`를 동일하게 맞춰야 함.

- 로컬 개발: `http://localhost:8080/oauth/google/callback.html`
- GitHub Pages: `https://lionandthelab.github.io/nest/oauth/google/callback.html`

## 10. 운영 시 주의사항

- `service_role` 키는 프론트에 절대 노출 금지
- OAuth 토큰 컬럼 접근은 관리자 권한과 RLS 정책 범위에서만 허용
- Edge Function JWT 검증 전략(`verify_jwt`) 변경 시 함수 내부 `requireUser` 체크를 유지
