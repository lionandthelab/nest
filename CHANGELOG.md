# Changelog

## 2026-03-03

### Added

- 이메일 초대 기반 멤버 온보딩
  - Supabase `homeschool_invites` 마이그레이션 추가
  - 초대 수락 RPC `accept_homeschool_invite` 추가
  - 관리자 `Members` 탭에서 이메일 초대 생성/취소/목록 관리
  - 사용자 `Dashboard`에서 대기 초대 수락 UI 추가
- 역할 기반 사용자 뷰 전환
  - 상단 컨텍스트에 `뷰 역할` 선택 추가 (부모/교사/관리자)
  - 계정이 다중 역할을 가진 경우 즉시 전환 가능
- 역할별 허브 탭 추가
  - `Parent Hub` (`parent_hub_tab.dart`)
  - `Teacher Hub` (`teacher_hub_tab.dart`)
- 권한 관리 탭 추가
  - `Members` (`members_tab.dart`)
  - 홈스쿨 관리자가 사용자별 역할 부여/회수 가능
  - 마지막 `HOMESCHOOL_ADMIN` 보호 로직 추가
- 일반 사용자용 커뮤니티 피드 탭 추가
  - `Community` (`community_feed_tab.dart`)
  - 글/첨부/좋아요/댓글/신고 기능 제공
- 운영/행정 완성 탭 추가
  - `Families` (`family_admin_tab.dart`) 가정/아이/반 배정 + 교사 프로필 등록
  - `Ops` (`ops_tab.dart`) 공지 작성/감사로그 모니터링
- 교사 운영 기능 확장
  - `Teacher Hub`에서 수업계획(Teaching Plan) 등록
  - `Teacher Hub`에서 아동 활동기록(Activity Log) 등록
  - `Teacher Hub`에서 교사 공지 작성
- 시간표 교사 배정 UI 강화
  - 세션별 주강사/보조교사 배정 다이얼로그
  - 충돌 경고 배지 표시 + DB 충돌 메시지 가이드
- Supabase 마이그레이션 추가
  - `20260303143000_children_policy_fix.sql`
  - `20260303145000_child_admin_rpc.sql`
  - `20260303150000_invite_rpc_fix.sql`
  - `20260303162000_class_groups_delete_and_member_search.sql`
- 원격 E2E 자동화 워크플로 추가
  - `.github/workflows/remote_e2e.yml`
  - `scripts/e2e_remote.mjs`에 가족/아이/배정/계획/활동/공지/초대수락 검증 시나리오 확장
- 홈스쿨 어드민 반 운영 기능 강화
  - `Families` 탭에 반(Class) CRUD UI 추가 (생성/수정/삭제)
  - 반 삭제 시 경고 확인 다이얼로그 추가
  - 반 편집 선택 시 이름/정원 폼 자동 동기화
- 교사 등록 UX 개선
  - 기존 계정 연결 토글 + 이름/이메일/UUID 검색 기반 선택
  - 계정 미보유 교사는 연결 없이 초청교사 프로필 생성 가능
- 관리자 시간표 UX 고도화
  - `Schedule Concierge` 질문형 생성기(요일/일일 수업 수/대안 개수/기존 시간표 유지 옵션)
  - 다중 초안(안 1~N) 비교 카드 + 선택/적용 플로우
  - 초안 보정 에디터(과목/슬롯/주강사 변경, 세션 추가/삭제)
  - 초안 보정 시 하드충돌/경고 실시간 계산 및 표시
- Family Admin 질문형 일괄 생성
  - 반 접두어/개수/정원/교사 목록 질문 기반 초안 생성
  - 생성 전 미리보기 + 일괄 생성(중복 이름 자동 스킵)
- 수동 시간표 충돌 요약 패널 추가
  - `Manual Board` 상단에서 교사 충돌/주강사 미지정 경고를 즉시 확인

### Changed

- `NestRepository`/`NestController`에 초대 도메인 API/상태 추가
  - `fetchHomeschoolInvites`, `createHomeschoolInvite`, `cancelHomeschoolInvite`, `acceptHomeschoolInvite`
  - `pendingInvites`, `homeschoolInvites` 상태 및 로드 흐름 추가
- 탭 라우팅을 역할 기반 동적 구성으로 전환 (`home_page.dart`)
  - 공통: Dashboard, Timetable, Gallery
  - 부모: Parent Hub
  - 교사: Teacher Hub
  - 사용자: Community
  - 관리자/스태프: SNS Admin
  - 관리자/스태프: Families, Ops
  - 관리자 전용: Drive, Members
- 시간표 탭을 권한 기반 UX로 개선
  - 관리자: Prompt + Manual 편집
  - 부모/교사: 읽기 전용 시간표
- `NestRepository`/`NestController` 운영 도메인 확장
  - families/children/class_enrollments
  - teacher_profiles/session_teacher_assignments
  - teaching_plans/student_activity_logs
  - announcements/audit_logs
- 멤버십/권한 API 확장 (`nest_repository.dart`)
  - 홈스쿨 전체 멤버십 조회
  - 역할 부여/회수 API
- 멤버십 모델에 `userId` 추가 (`nest_models.dart`)
- 아키텍처 문서 최신화 (`docs/architecture.md`)
  - 역할 전환 구조, 동적 탭, 권한관리, 커뮤니티 이중 모드 반영
- 실행 추적 문서 추가 (`docs/execution_tracker.md`)
  - 다국어/결제 제외 기준 체크리스트와 반복 검증 로그 누적
- 원격 E2E 워크플로 조건식 수정 (`.github/workflows/remote_e2e.yml`)
  - `if`에서 `secrets.*` 직접 참조 제거
  - job `env` 주입 후 `env.*` 기반으로 실행/스킵 분기하도록 변경
- 원격 E2E 스크립트 경로 이식성 수정 (`scripts/e2e_remote.mjs`)
  - OAuth 콜백 페이지 존재 검증 경로를 로컬 절대경로에서 `process.cwd()` 기반 상대 해석으로 변경
- `NestController`/`NestRepository` 반 도메인 확장
  - `createClassGroup`, `updateClassGroup`, `deleteClassGroup`
  - 반 CRUD 후 시간표/공지/커뮤니티/갤러리 연동 데이터 동기화
- 스케줄 도메인 모델/로컬 플래너 확장
  - `ScheduleOptionDraft`, `ScheduleOptionSession`, `ScheduleDraftIssue`
  - `buildWizardScheduleOptions`, `evaluateScheduleOptionIssues`
  - `applyScheduleOptionDraft` 반영 시 생성/건너뜀/교사충돌 결과 요약
  - `createSessionAndReturn` 저장소 API 추가 (`source_type` 지원)
- 멤버 디렉토리 검색 도메인 추가
  - `search_homeschool_members` RPC 연동
  - `HomeschoolMemberDirectoryEntry` 모델 추가
  - `NestController.searchHomeschoolMemberDirectory(...)`로 로컬 검색 제공
- 관리자 설정 UX 간소화
  - `Drive` 탭 라벨을 `Media Setup`으로 변경
  - Drive 토큰 수동 입력 필드를 `개발자 고급 설정` 토글 하위로 숨김 처리

### Verification

- `cd frontend && flutter analyze` 통과
- `cd frontend && flutter test` 통과
- `cd frontend && flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과 (`20260303130000`, `20260303143000`, `20260303145000`, `20260303150000`)
- `node scripts/e2e_remote.mjs` 통과 (`summary.success: true`, invite_flow 포함)
- GitHub Actions `Remote Supabase E2E` 통과 (`run: 22607933835`)
- GitHub Actions `Remote Supabase E2E` 통과 (`run: 22609099078`)
- GitHub Actions `Deploy Flutter Web to GitHub Pages` 통과 (`run: 22609099069`)
- 신규 마이그레이션 `20260303162000_class_groups_delete_and_member_search.sql`는 파일 추가 완료
  - 현재 환경에서는 `supabase db push` 시 권한/DB 비밀번호 이슈로 직접 적용은 미실행

## 2026-03-02

### Added

- Flutter 기반 신규 프론트엔드(`frontend/`) 구축
  - 인증/컨텍스트: 회원가입/로그인, 홈스쿨/학기/반 선택
  - 대시보드: 빠른 초기 세팅(홈스쿨/학기/반/과목/슬롯)
  - 시간표 스튜디오: 프롬프트 생성안 + 드래그앤드롭 수동 편집
  - Drive 연동: OAuth 시작/동기화, 수동 설정/해제
  - 갤러리: 사진/영상 업로드, Drive 링크 기반 열람
- 웹 OAuth 콜백 페이지 추가: `frontend/web/oauth/google/callback.html`
- GitHub Pages 자동 배포 워크플로 추가: `.github/workflows/flutter_web_pages.yml`
- 아키텍처 문서 추가: `docs/architecture.md`
- 기본 admin 자동 생성 스크립트 추가: `scripts/create_default_admin.mjs`

### Changed

- 문서 업데이트
  - `docs/10_supabase_execution_guide.md` (Flutter + GitHub Pages 기준으로 갱신)
  - `docs/README.md` (architecture 문서 항목 추가)
  - `frontend/README.md` (Flutter 실행/배포/OAuth 경로 + 기본 admin 생성 가이드)
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
- 기본 admin 생성: `node scripts/create_default_admin.mjs` 실행 완료
