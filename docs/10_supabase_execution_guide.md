# Supabase 실행 가이드 (Nest)

## 1) 마이그레이션 적용

Supabase Dashboard SQL Editor에서 아래 파일을 순서대로 실행합니다.

1. `supabase/migrations/20260302160000_init_nest.sql`
2. `supabase/migrations/20260302173000_constraints_and_drive_tokens.sql`

## 2) Edge Functions 배포

필수 secrets를 설정합니다.

```bash
supabase secrets set \
  SUPABASE_URL="https://avursvhmilcsssabqtkx.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>" \
  GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>" \
  GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>" \
  GOOGLE_REDIRECT_URI="http://localhost:8080/oauth/google/callback.html"
```

그리고 `SUPABASE_ACCESS_TOKEN`을 환경변수로 설정합니다.

```bash
export SUPABASE_ACCESS_TOKEN="<YOUR_SUPABASE_PAT>"
```

배포:

```bash
./scripts/deploy_supabase.sh
```

## 3) 프론트 실행

```bash
cd frontend
python3 -m http.server 8080
```

브라우저에서 `http://localhost:8080` 접속.

Google Cloud Console OAuth Client의 `Authorized redirect URI`에도 아래 값을 반드시 등록합니다.

`http://localhost:8080/oauth/google/callback.html`

## 4) 권장 운영 순서

1. 관리자 계정 회원가입/로그인
2. 대시보드에서 `빠른 초기 세팅` 실행
3. Drive 페이지에서 `OAuth 시작 URL 발급` 클릭 후 Google 인증
4. 시간표 스튜디오에서 프롬프트 생성안 + 수동 편집
5. 갤러리에서 업로드/열람 검증
