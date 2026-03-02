# Nest Flutter Frontend

Nest 홈스쿨링 플랫폼의 모바일/웹 공통 프론트엔드입니다.

## 핵심 기능

- Supabase 이메일 로그인/로그아웃
- Supabase 이메일 회원가입/로그인/로그아웃
- 홈스쿨/학기/반 컨텍스트 전환
- 빠른 초기 세팅(홈스쿨 + 학기 + 반 + 과목 + 시간 슬롯)
- 시간표 스튜디오
  - 프롬프트 기반 생성안 생성
  - 생성안 적용/폐기
  - 드래그앤드롭 수동 편집
- Google Drive 연동
  - OAuth 시작(웹 팝업)
  - 연동 상태 조회/수동 저장/해제
- 미디어 업로드/갤러리
  - 사진/영상 선택
  - Edge Function 기반 Drive 업로드
  - 갤러리 조회 및 Drive 링크 이동

## 환경

기본값은 코드에 이미 포함되어 있으며, 필요시 `dart-define`으로 덮어쓸 수 있습니다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AUTH_EMAIL_REDIRECT_URL`

예시:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=AUTH_EMAIL_REDIRECT_URL=https://lionandthelab.github.io/nest/
```

## Supabase Auth URL 설정(필수)

Supabase Dashboard > Authentication > URL Configuration에서 아래를 확인하세요.

- Site URL: `https://lionandthelab.github.io/nest/`
- Redirect URLs 포함:
  - `https://lionandthelab.github.io/nest/`
  - `http://localhost:3000/` (로컬 개발 시)
  - `http://localhost:8080/` (로컬 개발 시)

## 로컬 실행

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

모바일 예시:

```bash
flutter run -d ios
flutter run -d android
```

## 기본 Admin 계정 생성

아래 스크립트로 기본 관리자 계정과 기본 홈스쿨을 생성할 수 있습니다.

```bash
SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
node scripts/create_default_admin.mjs
```

기본값:

- Email: `admin@nest.local`
- Password: `NestAdmin!2026`
- Homeschool: `Nest Default Homeschool`

운영 환경에서는 생성 직후 비밀번호를 변경하세요.

## 웹 OAuth 콜백

Flutter 웹 빌드 산출물에 아래 파일이 포함됩니다.

- `web/oauth/google/callback.html`

Supabase Edge Function 시크릿 `GOOGLE_REDIRECT_URI`는 이 경로와 일치해야 합니다.

로컬 개발 예시:
- `http://localhost:8080/oauth/google/callback.html`

GitHub Pages 예시:
- `https://lionandthelab.github.io/nest/oauth/google/callback.html`

## GitHub Pages 배포

GitHub Actions 워크플로우가 `frontend`를 빌드해 `gh-pages` 브랜치로 배포합니다.

수동 빌드 확인:

```bash
cd frontend
flutter build web --release --base-href /nest/
```
