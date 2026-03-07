# Changelog

## 1.0.2+3 (2026-03-06)

### Changed

- `class_sessions.location` 스키마 호환성 강화
  - location 컬럼이 없는 DB에서도 수업 조회/생성/이동이 동작하도록 fallback 처리
  - location NOT NULL 제약이 있는 환경에서 기본값(`미정`)으로 자동 보정
  - 리모트 DB에 `20260306100000_session_location.sql` 마이그레이션 적용 (`supabase db push`)
- 상단 컨텍스트 UX 개편 (전 탭 공통)
  - 드롭다운 4개를 `카드형 선택 UI`로 교체 (`홈스쿨/학기/반/뷰 역할`)
  - 카드 클릭 시 검색 가능한 바텀시트 선택창 제공 (웹/모바일 공통)
  - `설정 도움말` 추가로 추천 선택 순서 안내
- 학부모 뷰 UX 재설계: 모놀리식 Parent Hub을 3개 전용 탭으로 분리
  - **시간표** 탭: 아이 선택 → 반별 시간표 즉시 확인 + 불가시간 설정
  - **학습 현황** 탭: 활동 기록/유형별 메트릭 대시보드
  - **소식** 탭: 공지사항 + 커뮤니티 + 갤러리를 서브섹션 칩으로 통합
  - 아이 선택 상태를 탭 간 공유 (`ChildSelectorHeader` 위젯 추출)
  - `ChildClassBundle` 공유 모델 추출
- 신규 사용자 온보딩 UI 추가
  - 홈스쿨 미소속 사용자에게 초대 수락 또는 홈스쿨 개설 안내 제공
  - 미소속 시 Dashboard만 표시하여 UX 혼란 방지
- 로그인 화면 테스트 계정 자동 채움 (`lionandthelab@gmail.com`)

### Removed

- `parent_hub_tab.dart` 삭제 (로직 전량 신규 탭으로 이전)

### Verification

- `flutter analyze` 통과
- `flutter build web --release` 통과

## 1.0.1+2 (2026-03-05)

### Added

- 로컬 캐시 & Stale-While-Revalidate 패턴 도입
  - `NestCache` 서비스 (`SharedPreferences` 기반, 스키마 버전 관리)
  - 앱 시작 시 캐시 데이터 즉시 표시 → 백그라운드 최신 데이터 동기화
  - 18개 모델에 `toMap()` 직렬화 메서드 추가
  - 네트워크 실패 시 캐시 데이터 유지 (graceful degradation)
- PWA 지원
  - `manifest.json` 업데이트 (name, scope, start_url, orientation, categories)
  - `index.html`에 `theme-color`, `apple-mobile-web-app-capable` 메타 태그 추가
  - 데스크톱에서 앱 설치 가능
- 시간표 이미지 내보내기
  - `RepaintBoundary` + `toImage()` 기반 PNG 캡처
  - 웹 전용 다운로드 헬퍼 (조건부 import 패턴: `download_helper.dart` / `_web` / `_stub`)
- 부모/교사 허브 공통 스캐폴드
  - `HubScaffold` 위젯으로 Parent Hub / Teacher Hub 레이아웃 일관화
  - 상단 KPI 카드 + 섹션 칩 전환 + 카드형 본문 구성
- 전역 모션/로딩 컴포넌트
  - `NestLoadingScreen`, `NestBusyOverlay`, 공통 fade+slide 전환

### Changed

- 시간표 탭 레이아웃 재구성
  - 시간표 그리드를 최상단 메인으로 배치
  - 초안 위자드 + 비교 패널을 `showModalBottomSheet` 모달로 이동
  - 보드 패널 헤더에 "위자드 열기" / "내보내기" 버튼 추가
- 헤더 영역 접기/펼치기
  - `_MainPanel`을 `StatefulWidget`으로 변환
  - 접힌 상태: 앱 이름 + 역할 칩 한 줄 표시
  - `AnimatedSize`로 부드러운 전환
- Parent Hub 아이 중심 뷰 강화
  - 아이 selector 기반 child-specific 화면
  - 반별 시간표/교사배정/공지 데이터 on-demand 로드
- Teacher Hub 담당 반 중심 뷰 강화
  - 교사 프로필 배정 기준 담당 반 자동 식별
  - 반 컨텍스트에서 공지/수업계획/활동 기록 일관 흐름
- 시간표 위자드 단계형 재구성 (기본 설정 / 리소스 조건 / 생성·검토)
- 시간표 보드에 반/교사 상태 사이드바 상시 표시 (모바일: 모달 시트)

### Verification

- `flutter analyze` 통과
- `flutter build web --release --base-href /nest/` 통과

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
  - 과목 빈도 가중치(낮음/보통/높음) 입력 UI 추가
  - 교사 배정 전략(균형/선호교사 우선/부모교사 우선) 및 선호교사 선택 UI 추가
  - 다중 초안(안 1~N) 비교 카드 + 선택/적용 플로우
  - 초안 보정 에디터(과목/슬롯/주강사 변경, 세션 추가/삭제)
  - 초안 보정 시 하드충돌/경고 실시간 계산 및 표시
- Family Admin 질문형 일괄 생성
  - 반 접두어/개수/정원/교사 목록 질문 기반 초안 생성
  - 생성 전 미리보기 + 일괄 생성(중복 이름 자동 스킵)
- 수동 시간표 충돌 요약 패널 추가
  - `Manual Board` 상단에서 교사 충돌/주강사 미지정 경고를 즉시 확인
- 교사/부모 불가 시간 관리 기능 추가
  - `member_unavailability_blocks` 마이그레이션 추가 (`20260303190000_member_unavailability_blocks.sql`)
  - `Families` 탭에서 관리자 기준 교사/부모 불가 시간 등록/삭제 UI 추가
  - `Parent Hub`/`Teacher Hub`에 본인 불가 시간 self-service 등록/삭제 UI 추가
- 관리자 대시보드 단계형 온보딩 UI 추가
  - 큰 카드 기반 `학기 설정 가이드`(1~4 순번 + 완료 체크 + 다음 단계 이동)
  - 단계별 빠른 이동: `Term Setup`, `Schedule` 탭 점프
- 관리자 시스템 통합 탭 추가
  - `System` 탭에서 `SNS 관리`, `Google Drive`, `권한`, `운영` 섹션을 한 화면에서 전환
- 학기 설정 단위형 UI 추가
  - `Term Setup` 탭에서 `가정`, `선생님`, `반`, `과목` 단위를 분리해 설정
  - 단위별 완료 상태/진행도를 직관적으로 표시
  - 과목 CRUD(추가/삭제) UI 및 API 추가
- 시간표 작성 UI 재설계
  - `Schedule Studio` 그리드형 시간표(day x period) 도입
  - 과목 팔레트에서 셀로 드래그해 수업 생성
  - 세션 카드 드래그로 셀 간 이동
  - 교사 배정/충돌 상태를 카드 내부에서 바로 확인 가능
- 부모/교사 허브 공통 UX 프레임 도입
  - `HubScaffold` 기반으로 `Parent Hub`/`Teacher Hub` 레이아웃 일관화
  - 상단 KPI 카드 + 섹션 칩 전환 + 카드형 본문 구성
  - 부모: `개요`/`내 불가 시간`/`활동 타임라인`
  - 교사: `수업 운영`/`계획 작성`/`활동 기록`
- Parent Hub 아이 중심 뷰 강화
  - 내 아이 selector 기반으로 child-specific 화면 제공
  - 아이 소속 반 목록 + 반별 시간표 + 아이 상태 로그를 한 흐름으로 제공
  - 반별 세션/교사배정/공지 데이터를 on-demand 로드해 정확한 아이 단위 정보 제공
- Teacher Hub 담당 반 중심 뷰 강화
  - 내 교사 프로필 배정 기준으로 담당 반 자동 식별
  - 반 운영보드에서 반별 시간표를 직접 확인
  - 반 컨텍스트에서 공지 작성/수업계획/아동 상태 기록을 일관 흐름으로 제공
- 시간표 작성 UX 강화
  - `초안 위자드`를 단계형(기본 설정/리소스 조건/생성·검토)으로 재구성
  - 메인 시간표 보드 상단에 `프롬프트 수정 액션바` 추가
  - 웹: 반/교사 상태를 사이드바 `상황 패널`로 상시 확인
  - 모바일: 같은 상황 패널을 모달 시트로 열어 동일 정보 접근
  - 교사별 배정량/충돌/불가시간 배정 위험을 요약해 빠른 보정 지원
- 전역 모션/로딩 컴포넌트 추가
  - `nest_motion.dart` (`NestLoadingScreen`, `NestBusyOverlay`, 공통 fade+slide 전환)
  - 루트 부트스트랩/로그인/홈 전환 애니메이션
  - 메인 탭 콘텐츠 전환 애니메이션 및 busy 오버레이
  - 로그인 모드 전환(로그인/회원가입) 애니메이션 개선

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
  - 과목 가중치 기반 편성 풀 생성 로직 추가
  - 선호교사/부모교사 우선 배정 전략 및 선택교사 전용 모드 추가
  - `applyScheduleOptionDraft` 반영 시 생성/건너뜀/교사충돌 결과 요약
  - `createSessionAndReturn` 저장소 API 추가 (`source_type` 지원)
- 멤버 디렉토리 검색 도메인 추가
  - `search_homeschool_members` RPC 연동
  - `HomeschoolMemberDirectoryEntry` 모델 추가
  - `NestController.searchHomeschoolMemberDirectory(...)`로 로컬 검색 제공
- 관리자 설정 UX 간소화
  - `Drive` 탭 라벨을 `Media Setup`으로 변경
  - Drive 토큰 수동 입력 필드를 `개발자 고급 설정` 토글 하위로 숨김 처리
- 스케줄 생성/검증 로직 확장
  - 부모 불가 시간 충돌 코드 추가: `PARENT_SLOT_UNAVAILABLE`
  - 교사 불가 시간 충돌 코드 추가: `TEACHER_SLOT_UNAVAILABLE`
  - 초안 생성 시 부모/교사 불가 슬롯 자동 회피 반영
- 불가 시간 권한 모델 확장
  - 관리자/스태프는 전체 대상 관리
  - 부모는 본인(`MEMBER_USER`) 항목만 직접 관리
  - 교사는 본인 `teacher_profile` 항목만 직접 관리
- 시간표 초안 적용 시 세션 source_type 정합성 수정
  - `ASSISTED` 값을 `AI_PROMPT`로 교체하여
  - DB 체크 제약(`class_sessions_source_type_check`) 위반 문제 해결
- 관리자 상위 탭 구조 간소화
  - 기존 다중 운영 탭(`SNS Admin`, `Media Setup`, `Members`, `Families`, `Ops`)을
  - `Dashboard` / `Term Setup` / `Schedule` / `System` 중심으로 재구성
- 대시보드 온보딩 가이드 이동 대상 갱신
  - `Families`/`Timetable` 기준에서 `Term Setup`/`Schedule` 기준으로 변경
- 수동 보드 UX를 시각화 중심으로 전환
  - 슬롯 나열 방식에서 그리드 편집 방식으로 변경
  - 충돌 배너 가시성 강화 및 읽기/수정 모드 구분 강화
- 디자인 시스템 확장
  - `NestTheme`에 페이지 전환/Progress 스타일을 추가해 애니메이션 톤 통일
- `NestController` 확장
  - parent/teacher 허브를 위한 `myChildren`, `classGroupsForChild`, `childrenForClassGroup` 헬퍼 추가
  - class/session/plan/announcement on-demand 조회용 controller API 추가

### Verification

- `cd frontend && flutter analyze` 통과
- `cd frontend && flutter test` 통과
- `cd frontend && flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과 (`20260303130000`, `20260303143000`, `20260303145000`, `20260303150000`, `20260303162000`, `20260303190000`)
- `node scripts/e2e_remote.mjs` 통과 (`summary.success: true`, invite_flow 포함)
- `SUPABASE_* node scripts/e2e_remote.mjs` 재통과 (UI 재구성 이후 회귀 없음, `source_type=AI_PROMPT` 확인)
- GitHub Actions `Remote Supabase E2E` 통과 (`run: 22607933835`)
- GitHub Actions `Remote Supabase E2E` 통과 (`run: 22609099078`)
- GitHub Actions `Remote Supabase E2E` 통과 (`run: 22610640069`)
- GitHub Actions `Deploy Flutter Web to GitHub Pages` 통과 (`run: 22609099069`)
- GitHub Actions `Deploy Flutter Web to GitHub Pages` 통과 (`run: 22610637304`)
- GitHub Actions `pages-build-deployment` 통과 (`run: 22610687288`)

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
