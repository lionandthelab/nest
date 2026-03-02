# Nest Vanilla Frontend

## 기능

- Supabase Auth 로그인/로그아웃
- 홈스쿨/학기/반 컨텍스트 선택
- 빠른 초기 세팅(홈스쿨 + 학기 + 반 + 과목 + 기본 시간 슬롯)
- 시간표 스튜디오
  - 채팅 프롬프트 생성안
  - 수동 드래그앤드롭 편집
  - 과목 팔레트 드래그로 수업 생성
- Google Drive 연동 설정
- 교사 미디어 업로드 + 갤러리 조회

## 실행

```bash
cd frontend
python3 -m http.server 8080
```

브라우저: `http://localhost:8080`

Google OAuth redirect URI는 아래 페이지를 사용합니다.

- `http://localhost:8080/oauth/google/callback.html`

## 환경

- `config.js`에 Supabase URL/Anon Key가 설정되어 있어야 합니다.
- Drive 업로드는 아래 Edge Function 배포가 필요합니다.
  - `timetable-assistant-generate`
  - `google-drive-upload`
  - `google-drive-connect-start`
  - `google-drive-connect-complete`
