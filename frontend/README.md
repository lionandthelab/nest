# Nest Flutter Frontend

Nest 홈스쿨링 플랫폼의 모바일/웹 공통 프론트엔드입니다.

## 핵심 기능

- Supabase 이메일 로그인/로그아웃
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

예시:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

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
