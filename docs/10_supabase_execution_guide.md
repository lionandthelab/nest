# Supabase 실행 가이드 (Nest)

## 1) 마이그레이션 적용

Supabase CLI 링크 상태에서:

```bash
supabase db push
```

수동 SQL Editor 적용 시 순서:

1. `supabase/migrations/20260302160000_init_nest.sql`
2. `supabase/migrations/20260302173000_constraints_and_drive_tokens.sql`

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
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## 4) GitHub Pages 빌드/배포

로컬 빌드 검증:

```bash
cd frontend
flutter build web --release --base-href /nest/
```

원격 배포는 `.github/workflows/flutter_web_pages.yml`가 `main` 푸시 시 자동 처리.

## 5) 권장 운영 순서

1. 관리자 계정 회원가입/로그인
2. Dashboard에서 `빠른 초기 세팅` 실행
3. Drive 탭에서 OAuth 시작 후 Google 인증
4. Timetable 탭에서 프롬프트 생성안 + 드래그앤드롭 편집
5. Gallery 탭에서 업로드/열람 검증
