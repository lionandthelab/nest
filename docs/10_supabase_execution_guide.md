# Supabase 실행 가이드 (Nest)

## 1) 마이그레이션 적용

Supabase CLI 링크 상태에서:

```bash
supabase db push
```

수동 SQL Editor 적용 시 순서:

1. `supabase/migrations/20260302160000_init_nest.sql`
2. `supabase/migrations/20260302173000_constraints_and_drive_tokens.sql`
3. `supabase/migrations/20260303060000_community_sns.sql`
4. `supabase/migrations/20260303130000_homeschool_invites.sql`
5. `supabase/migrations/20260303143000_children_policy_fix.sql`
6. `supabase/migrations/20260303145000_child_admin_rpc.sql`
7. `supabase/migrations/20260303150000_invite_rpc_fix.sql`
8. `supabase/migrations/20260303162000_class_groups_delete_and_member_search.sql`

## 2) Edge Functions 배포

필수 secrets 설정:

```bash
supabase secrets set \
  SUPABASE_URL="https://avursvhmilcsssabqtkx.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>" \
  GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>" \
  GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>" \
  GOOGLE_REDIRECT_URI="<REGISTERED_REDIRECT_URI>"
```

예시 redirect URI:

- 로컬: `http://localhost:8080/oauth/google/callback.html`
- GitHub Pages: `https://lionandthelab.github.io/nest/oauth/google/callback.html`

배포:

```bash
./scripts/deploy_supabase.sh
```

## 3) Flutter 프론트 실행

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

필요 시 `dart-define`으로 환경값 덮어쓰기:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=AUTH_EMAIL_REDIRECT_URL=https://lionandthelab.github.io/nest/
```

Authentication > URL Configuration도 함께 설정합니다.

- Site URL: `https://lionandthelab.github.io/nest/`
- Redirect URLs:
  - `https://lionandthelab.github.io/nest/`
  - `http://localhost:3000/`
  - `http://localhost:8080/`

## 4) GitHub Pages 빌드/배포

로컬 빌드 검증:

```bash
cd frontend
flutter build web --release --base-href /nest/
```

원격 배포는 `.github/workflows/flutter_web_pages.yml`가 `main` 푸시 시 자동 처리.

원격 Supabase 통합 검증은 `.github/workflows/remote_e2e.yml`로 실행합니다.

리포지토리 Secrets(`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`)가 비어 있으면
워크플로우는 자동으로 E2E를 스킵하고 성공적으로 종료됩니다.

### Drive 실제 업로드 E2E (선택)

`scripts/e2e_remote.mjs`의 `drive_real_upload_when_connected` 스텝은 Google OAuth 동의를
자동화할 수 없으므로(사람이 한 번 직접 동의해야 함), 미리 발급받은 `refresh_token`을
GitHub Secrets에 저장해두고 재사용하는 방식으로 실제 Drive 업로드를 검증합니다.

1. `refresh_token` 1회 발급 (사람이 직접 OAuth 동의):
   - 아래 파라미터로 Google OAuth 동의 화면 URL을 구성해 브라우저에서 접속합니다.
     - `scope=https://www.googleapis.com/auth/drive.file`
     - `access_type=offline`
     - `prompt=consent` (매번 refresh_token을 재발급받기 위해 필수)
     - `redirect_uri`는 배포된 `GOOGLE_REDIRECT_URI`와 동일해야 함
   - 동의 후 리다이렉트된 `code`를 `https://oauth2.googleapis.com/token`에
     `grant_type=authorization_code`로 교환하여 응답의 `refresh_token`을 확보합니다.
2. 리포지토리 Secrets에 등록:
   - `E2E_DRIVE_REFRESH_TOKEN`: 위에서 발급받은 refresh_token
   - `E2E_DRIVE_ROOT_FOLDER_ID`: 업로드 대상 Drive 폴더 ID (선택, 없으면 루트에 업로드)
3. 동작 방식: 테스트는 임시로 생성한 `homeschool`에 `drive_integrations` 행을
   `status='CONNECTED'` + 만료된 `google_token_expires_at`으로 upsert하여
   `google-drive-upload` 함수의 `maybeRefreshToken()`이 실제 refresh_token 교환을
   수행하도록 강제한 뒤, 1x1 PNG를 실제로 업로드하고 `drive_file_id`를 검증합니다.
4. `E2E_DRIVE_REFRESH_TOKEN`이 설정되지 않은 환경(예: 시크릿 미등록 상태의 CI)에서는
   해당 스텝이 `{ skipped: true }`를 반환하고 통과 처리되어 전체 E2E는 계속 초록색으로 유지됩니다.

## 5) 권장 운영 순서

1. 기본 관리자 계정 자동 생성(선택)

```bash
SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY> \
node scripts/create_default_admin.mjs
```

기본 admin 계정:
- Email: `admin@nest.local`
- Password: `NestAdmin!2026`

2. 관리자 계정 회원가입/로그인
3. Dashboard에서 `빠른 초기 세팅` 실행
4. Drive 탭에서 OAuth 시작 후 Google 인증
5. Timetable 탭에서 프롬프트 생성안 + 드래그앤드롭 편집
6. Gallery 탭에서 업로드/열람 검증
