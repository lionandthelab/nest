# Changelog

## 2026-03-02

### Added

- Flutter 기반 신규 프론트엔드(`frontend/`) 구축
  - 인증/컨텍스트: 로그인, 홈스쿨/학기/반 선택
  - 대시보드: 빠른 초기 세팅(홈스쿨/학기/반/과목/슬롯)
  - 시간표 스튜디오: 프롬프트 생성안 + 드래그앤드롭 수동 편집
  - Drive 연동: OAuth 시작/동기화, 수동 설정/해제
  - 갤러리: 사진/영상 업로드, Drive 링크 기반 열람
- 웹 OAuth 콜백 페이지 추가: `frontend/web/oauth/google/callback.html`
- GitHub Pages 자동 배포 워크플로 추가: `.github/workflows/flutter_web_pages.yml`
- 아키텍처 문서 추가: `docs/architecture.md`

### Changed

- 문서 업데이트
  - `docs/10_supabase_execution_guide.md` (Flutter + GitHub Pages 기준으로 갱신)
  - `docs/README.md` (architecture 문서 항목 추가)
  - `frontend/README.md` (Flutter 실행/배포/OAuth 경로 가이드)
- 원격 E2E 스크립트 콜백 경로 갱신
  - `scripts/e2e_remote.mjs` -> `frontend/web/oauth/google/callback.html` 검증

### Removed

- 기존 Vanilla 웹 프론트 파일 제거
  - `frontend/app.js`
  - `frontend/config.js`
  - `frontend/index.html`
  - `frontend/styles.css`
  - `frontend/oauth/google/callback.html`

### Verification

- `cd frontend && flutter analyze` 통과
- `cd frontend && flutter test` 통과
- `cd frontend && flutter build web --release --base-href /nest/` 통과
- `cd frontend && flutter build apk --debug` 통과
- `cd frontend && flutter build ios --simulator --no-codesign` 통과
- 원격 Supabase E2E: `node scripts/e2e_remote.mjs` 통과 (`summary.success: true`)
