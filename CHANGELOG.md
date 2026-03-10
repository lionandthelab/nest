# Changelog

## 1.0.24+25 (2026-03-10)

### Changed

- 모바일 출시 준비 보강
  - Android `applicationId/namespace`를 `io.lionandthelab.nest`로 통일
  - iOS `PRODUCT_BUNDLE_IDENTIFIER`를 `io.lionandthelab.nest`로 통일
  - Android/iOS Supabase 인증 복귀용 딥링크 스킴 설정
    - `io.lionandthelab.nest://login-callback/`
  - Android 릴리즈 네트워크 접근을 위한 `INTERNET` 권한을 `main` 매니페스트에 추가
  - Android 릴리즈 서명 설정을 `key.properties` 기반으로 지원 (없으면 로컬 검증용 debug 서명 fallback)
- 인증 UX 보강
  - 로그인 화면의 하드코딩된 기본 이메일/비밀번호 제거
  - 로그인 화면에 `비밀번호를 잊으셨나요?` 흐름 추가
  - 비밀번호 재설정 메일 발송 API/컨트롤러 연동
- 문서 업데이트
  - `docs/architecture.md` 모바일 배포/리다이렉트 설정 반영
  - `docs/mobile_release.md` 신설 (스토어 업로드 전 체크리스트 및 빌드 가이드)

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build appbundle --release` 통과
- `flutter build ios --release --no-codesign` 통과

## 1.0.23+24 (2026-03-08)

### Changed

- 홈 헤더 UX 재구성 (`home_page.dart`)
  - 기존 접힘(콜랍스) 기반 설정 영역 제거, 컨텍스트 선택(`홈스쿨/학기/반/뷰 역할`)을 항상 full-width 노출
  - 계정 식별 강화를 위해 사용자 표시 이름 + 이메일을 헤더에 항상 표시
- 한국어 IA 라벨 통일
  - 탭 라벨을 한국어로 정리: `대시보드`, `학기 설정`, `시간표`, `시스템`, `교사 허브`, `갤러리`, `커뮤니티`
  - 관리자 헤더 타이틀을 `관리` 중심으로 단순화
  - 대시보드 단계 이동 타깃 라벨도 한국어 탭명으로 동기화 (`dashboard_tab.dart`)
- 네비게이션/브랜딩 강화
  - 좌측 사이드바 상단에 로고(`assets/logo.png`)를 배치하고 클릭 시 홈 탭(인덱스 0)으로 이동
  - Nest 아이콘 사용 비중 확대(헤더/대시보드 아이콘 톤 통일)
- 현재 화면 컨텍스트 표시 추가
  - 메인 패널 하단에 `현재 탭: ...` 마이크로 캡션 추가

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.22+23 (2026-03-08)

### Fixed

- 시간표 탭 dirty 상태 동기화 버그 수정 (`timetable_tab.dart`)
  - `수정 확정` 성공 후 dirty 상태를 상위 탭 경고 가드(`HomePage`)로 강제 false 동기화
  - 반 선택 해제/무효 상태에서도 draft 정리 시 dirty false를 보장
  - 확정 후 탭 이동 시 `수정사항 경고`가 반복적으로 뜨던 문제 해결

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.21+22 (2026-03-08)

### Changed

- 시간표/교실 상황표 이미지 내보내기 여백 보정 (`timetable_tab.dart`)
  - export 보드 폭 계산을 `콘텐츠 폭 + 좌우 패딩`으로 수정
  - 우측이 붙어 보이던 문제를 제거하고 좌우 패딩을 대칭으로 맞춤
- 스케줄 탭 좌측 팔레트 즉시 관리 기능 추가
  - 과목 팔레트: `+`로 생성, 칩 `×`로 삭제
  - 선생님 팔레트: `+`로 생성, 칩 `×`로 삭제
  - 교실 팔레트: `+`로 생성, 칩 `×`로 삭제(연결 리소스 없는 항목은 팔레트 정리)
  - 삭제 시 현재 draft에 연결된 항목 정리(과목/교사/교실)로 일관성 유지
- 교사 삭제 API/권한 추가
  - `nest_repository.dart`: `deleteTeacherProfile`
  - `nest_controller.dart`: `deleteTeacherProfile` + 감사 로그(`TEACHER_PROFILE_DELETE`)
  - `supabase/migrations/20260309020000_teacher_profiles_delete_policy.sql` 추가

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.20+21 (2026-03-08)

### Changed

- 관리자 학기 설정 KPI 대시보드 추가 (`family_admin_tab.dart`)
  - `Term Setup` 헤더에 큰 숫자+단위 기반 요약 카드 도입
  - 지표: 가정(`가정`), 아이(`명`), 학부모(`명`), 선생님(`명`), 반(`반`), 과목(`개`), 교실(`개`)
  - 카드 개수를 세지 않고도 운영 규모를 한눈에 파악 가능하도록 개선
- 관리 섹션 헤더 스캔성 개선
  - 가정/아이/선생님/반/과목/교실 관리 카드 제목 옆에 총량 배지 추가
  - 섹션 이동 시 현재 등록 규모를 즉시 확인 가능

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.19+20 (2026-03-08)

### Changed

- 부모 헤더바 공지 프리뷰 추가 (`home_page.dart`)
  - 홈 상단에 최신 공지 3건을 카드로 노출
  - 공지 항목 탭 시 상세 다이얼로그 확인
  - `모두 보기`로 부모 `소식` 탭 이동 지원
- 부모 아이 선택 UX 통합
  - 아이 선택을 각 탭 카드에서 제거
  - 홈 헤더바 전역 아이 선택기로 일원화(시간표/학습현황 탭 공통 적용)
  - 부모는 guardian 연동된 아이만 선택 가능
- 부모 탭 레이아웃 정리
  - `parent_timetable_tab.dart`, `parent_progress_tab.dart`에서 탭 내부 ChildSelector 제거
  - 로딩 시 상단 progress 표시로 상태 전달

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.18+19 (2026-03-08)

### Changed

- 부모 아이 선택 범위 제한 강화
  - `nest_controller.dart`: `myChildren` fallback 제거
  - 부모 뷰에서는 guardian으로 연동된 아이만 선택 가능
  - guardian 연동이 없는 경우 아이 선택 목록이 비어 있으며 안내 메시지 노출
- 부모 시간표 UI 개선 (`parent_timetable_tab.dart`)
  - `요일 x 교시` 형태의 주간 스케줄표를 메인 보드로 추가
  - 과목/반/교사/장소를 셀 카드로 한눈에 확인 가능
  - 기존 반별 상세 카드는 보조 섹션으로 유지

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.17+18 (2026-03-08)

### Changed

- 대기 중 초대 UX 개선 (`dashboard_tab.dart`)
  - 초대 아이템을 풀너비 `초대장` 스타일 카드로 리디자인
  - 초대장 메타 정보(역할/만료/발송일) 칩화 및 수락 CTA 강조
  - `Unknown Homeschool` 문구는 UI에서 `홈스쿨 이름 확인 중`으로 보조 처리
- 초대 홈스쿨 이름 안정화
  - `nest_repository.dart`: 초대 조회/생성 select 필드에 `homeschool_name` 추가
  - `nest_models.dart`: `HomeschoolInvite.fromMap` 이름 해석 로직 강화(빈 문자열/조인 실패 fallback 처리)
- Supabase 스키마 보강
  - `supabase/migrations/20260309011500_homeschool_invites_name_snapshot.sql`
  - `homeschool_invites.homeschool_name` 스냅샷 컬럼 추가 + 기존 데이터 백필
  - 초대 생성/홈스쿨 이름 변경 시 스냅샷 동기화 트리거 추가
- 테스트 보강
  - `frontend/test/models_test.dart`: flat `homeschool_name` 파싱 검증 추가

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.16+17 (2026-03-08)

### Changed

- 초기 온보딩 UX 개편 (`dashboard_tab.dart`)
  - `초대를 받았나요?` 섹션 유지
  - 비소속 사용자를 위한 `홈스쿨 검색 및 가입 요청` 카드 추가
  - 검색 결과 카드에서 가입 요청 메시지 입력 후 즉시 요청 전송 지원
  - `새 홈스쿨을 직접 개설`의 하단 인라인 폼 제거, `홈스쿨 개설 열기` 모달로 전환
- 홈스쿨 검색/가입요청 API 추가
  - `nest_models.dart`: `HomeschoolDirectoryEntry`
  - `nest_repository.dart`: `searchHomeschoolDirectory`, `createHomeschoolJoinRequest`
  - `nest_controller.dart`: `searchHomeschoolDirectory`, `requestJoinHomeschool`
- Supabase 스키마 확장
  - `supabase/migrations/20260309003000_homeschool_join_requests_and_directory.sql`
  - `homeschool_join_requests` 테이블 + RLS 정책 추가
  - `search_homeschool_directory` security-definer RPC 추가
- 테스트 보강
  - `frontend/test/models_test.dart`: `HomeschoolDirectoryEntry.fromMap` 파싱 테스트 추가

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.15+16 (2026-03-08)

### Changed

- 가정-학부모 연동 UX 강화 (`family_admin_tab.dart`)
  - `가정 수정` 모달에 학부모 계정 검색/선택/연결 UI 추가
  - 연결된 학부모 목록에 `연결 해제` 버튼 추가
  - 보호자 유형(`FATHER`/`MOTHER`/`GUARDIAN`) 지정 지원
- 가정-학부모 연동 API 추가
  - `nest_repository.dart`: `upsertFamilyGuardian`, `deleteFamilyGuardian`
  - `nest_controller.dart`: `upsertFamilyGuardian`, `deleteFamilyGuardian`
  - 감사 로그 이벤트 추가: `FAMILY_GUARDIAN_UPSERT`, `FAMILY_GUARDIAN_DELETE`
- 시간표/교실 상황표 이미지 내보내기 레이아웃 보정 (`timetable_tab.dart`)
  - 내보내기 미리보기 다이얼로그를 가로+세로 스크롤 구조로 변경
  - export 전용 보드 너비 계산 보정으로 우측 마지막 카드 잘림/삐져나옴 완화
  - 우측 패딩 확보를 위해 export 캔버스 너비 여유 추가
- Supabase RLS 보강
  - `supabase/migrations/20260308235500_family_guardians_delete_policy.sql`
  - 정책 추가: `family_guardians_delete_admin_staff`

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.14+15 (2026-03-08)

### Changed

- 시간표 관리 UI 단순화 (`timetable_tab.dart`)
  - `AI 배정` 입력/도움말/실행 UI 제거
  - 시간표 상단 내보내기 버튼 라벨을 `시간표 내보내기`로 변경
  - 시간표 편집 내 장소 용어를 `교실` 기준으로 통일
- 이미지 내보내기 품질 개선 (`timetable_tab.dart`)
  - 시간표/교실 상황표 모두 내보내기 전용 다이얼로그에서 fit-to-width 레이아웃으로 렌더링
  - 캡처 보드 상하좌우 패딩 확보로 이미지 가장자리 잘림 완화
  - 내보내기 이미지에서 미배정 슬롯은 안내 문구 대신 빈칸으로 렌더링
- 교실 리소스 도메인 추가
  - `family_admin_tab.dart`: 학기 설정 `교실` 단계 추가 + 교실 카드형 CRUD(생성/수정/삭제) 통합 모달 구현
  - `nest_repository.dart`: `fetchClassrooms`, `createClassroom`, `updateClassroom`, `deleteClassroom`
  - `nest_controller.dart`: `classrooms` 상태/캐시 연동 + `create/update/deleteClassroom` + 감사 로그(`CLASSROOM_*`)
  - `timetable_tab.dart`: 교실 팔레트를 학기 설정 교실 리소스와 연동
- Supabase 마이그레이션 추가
  - `supabase/migrations/20260308233000_classrooms.sql`
  - `classrooms` 테이블 + RLS 정책(`classrooms_select/insert/update/delete_admin_staff`) 추가

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.13+14 (2026-03-08)

### Changed

- 과목 관리 UX 일관화 (`family_admin_tab.dart`)
  - 인라인 입력형 UI를 제거하고 카드형 과목 목록으로 전환
  - `과목 추가`/카드 클릭 편집을 동일한 생성·수정 통합 모달로 일원화
  - 과목 수정 모달에서 이름/기본 수업시간 편집 및 삭제 지원
  - 현재 반 시간표 사용 과목은 삭제 비활성화 가이드 제공
- 과목 수정 API 추가
  - `nest_repository.dart`: `updateCourse`
  - `nest_controller.dart`: `updateCourse`
  - 감사 로그 이벤트 추가: `COURSE_UPDATE`
- Supabase RLS 보강
  - `supabase/migrations/20260308223000_courses_delete_policy.sql`
  - 정책 추가: `courses_delete_admin_staff`

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.12+13 (2026-03-08)

### Changed

- 반 관리 UX 재구성 (`family_admin_tab.dart`)
  - 학기 설정 헤더 카드에서 `현재 반 목록` 제거
  - `반 관리`를 카드형 목록 기반으로 일원화
  - 반 카드 클릭 시 생성/수정 공용 모달로 진입
  - 반 생성/수정 모달에서 아이 배정을 같은 화면에서 처리
  - 아이 배정은 다중 선택(복수 체크) 기반으로 저장
- 반 배정 동기화 API 추가 (`nest_controller.dart`)
  - `syncClassEnrollments(classGroupId, childIds)` 추가
  - 모달 저장 시 선택된 아이 집합 기준으로 `추가/해제` diff 반영
  - 감사 로그 이벤트 추가: `CLASS_ENROLLMENT_SYNC`

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.11+12 (2026-03-08)

### Changed

- 가정/아이 삭제 기능 추가 (`family_admin_tab.dart`)
  - `가정 수정` 모달에 삭제 버튼 + 확인 다이얼로그 추가
  - `아이 수정` 모달에 삭제 버튼 + 확인 다이얼로그 추가
  - 삭제 시 연관 데이터(배정/활동/태깅) 정리 가능성을 명시한 가드 문구 제공
- 삭제 API 추가
  - `nest_repository.dart`: `deleteFamily`, `deleteChild`
  - `nest_controller.dart`: `deleteFamily`, `deleteChild`
  - 감사 로그 이벤트 추가: `FAMILY_DELETE`, `CHILD_DELETE`
- Supabase RLS 삭제 정책 추가
  - `supabase/migrations/20260308201000_family_child_delete_policies.sql`
  - 원격 반영 완료: `supabase db push`

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과
- `supabase db push` 통과

## 1.0.10+11 (2026-03-08)

### Changed

- 다중 역할 전환 UX 강화
  - `members_tab.dart`: `내 계정 역할 전환` 카드 추가
  - 관리자 본인 계정에 `부모`/`교사`/`외부교사` 역할을 토글로 바로 부여/회수
  - 역할 토글 후 `currentRole`/멤버십 재로드가 자동 반영되어 즉시 뷰 전환 가능
- 홈 헤더 즉시 뷰 스위처 추가 (`home_page.dart`)
  - 현재 역할 칩 옆 `뷰 전환` 팝업 버튼 추가
  - 2개 이상 역할이 있는 계정은 헤더에서 관리자/부모/교사 모드를 바로 전환
  - 기존 확장 컨텍스트(`뷰 역할` 카드)와 병행 동작

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.9+10 (2026-03-08)

### Changed

- 학기 설정 `가정` 탭 UI 일관화 (`family_admin_tab.dart`)
  - 기존 분리 폼(`가정 등록`, `아이 등록`, `가정 현황`)을 카드 중심 흐름으로 재구성
  - `가정 관리`: 가정 카드 클릭으로 즉시 수정, `가정 추가`는 동일 모달 재사용
  - `아이 관리`: 가정 선택 카드 + 아이 카드 클릭 수정, `아이 추가`는 동일 모달 재사용
  - 아이 편집 모달에서 소속 가정 재배정, 생년월일, 프로필 메모를 한 화면에서 수정
- 가정/아이 수정 API 추가
  - `nest_repository.dart`: `updateFamily`, `updateChild`
  - `nest_controller.dart`: `updateFamily`, `updateChild`
  - 감사 로그 이벤트 추가: `FAMILY_UPDATE`, `CHILD_UPDATE`

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.8+9 (2026-03-08)

### Changed

- 학기 설정 `반` 탭 정리 (`family_admin_tab.dart`)
  - `운영 초안 생성기` 제거
  - 반 관리/반 배정에서 반 선택을 카드 클릭 전환으로 통일
- 학기 설정 `선생님` 탭 통합 편집 UX 적용 (`family_admin_tab.dart`)
  - 선생님 카드 클릭 시 생성/수정 공용 모달 오픈
  - 모달에서 교사 정보 수정 + 기존 계정 연결/해제 + 불가 시간 등록/삭제를 한 번에 처리
- 교사 프로필 수정 API/상태 흐름 추가
  - `nest_repository.dart`: `updateTeacherProfile`
  - `nest_controller.dart`: `updateTeacherProfile` + 감사 로그(`TEACHER_PROFILE_UPDATE`)

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.7+8 (2026-03-08)

### Changed

- 전 탭 레이아웃 full-width 정책 적용
  - `home_page.dart`: 메인 패널 콘텐츠 max-width 제한 제거
  - `hub_scaffold.dart`: 허브 공통 레이아웃 max-width 제한 제거
- 공통 비주얼 컴포넌트 추가
  - `entity_visuals.dart`: `EntityAvatar`, `LabeledEntityTile`
- Parent/Teacher/Admin 주요 UX 시각 개편
  - `child_selector_header.dart`: 아이 선택 후 아바타 중심 프로필 카드 + 소속 반 시각 타일
  - `parent_timetable_tab.dart`: 반/수업 카드 레이아웃 개선, 수업 카드에 교사/시간/장소 아이콘 메타
  - `parent_progress_tab.dart`: 학습 지표 카드화 + 활동 로그 타임라인 시각화
  - `parent_news_tab.dart`: 소식 헤더 카드화 + 공지 카드 아바타 시각 강화
  - `teacher_hub_tab.dart`: 반 운영보드/수업카드/아이 상태 기록을 아바타/아이콘 중심으로 개편
  - `family_admin_tab.dart`: 반 목록/반 배정/가정 현황/교사 검색결과를 엔티티 타일 기반으로 개선
  - `hub_scaffold.dart`: 허브 헤더에 시각 배너 스타일 적용

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.6+7 (2026-03-08)

### Changed

- 시간표 관리 마감 UX 보강 (`timetable_tab.dart`)
  - 메인보드 카드 우측 상단에 `수정 확정` 단일 저장 동선으로 정리
  - 별도 수정상황 섹션 제거
  - `AI 배정`을 채팅형 단일 입력창으로 단순화하고 도움말 툴팁/다이얼로그 추가
- 장소 배정 가시화/내보내기 추가 (`timetable_tab.dart`)
  - 전체 반 기준 `요일 x 교시` 장소 배정 상황표 다이얼로그 제공
  - `장소 상황표 내보내기` 버튼으로 PNG 다운로드 지원

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.5+6 (2026-03-08)

### Changed

- 시간표 관리 탭 대규모 UX 단순화 (`timetable_tab.dart`)
  - 메인보드 중심 레이아웃으로 재구성 (상황 패널 제거)
  - 가용 폭을 최대 활용하도록 그리드 컬럼 폭을 동적 계산해 가로 스크롤 부담 완화
  - 탭 내부 반 스위처 카드 추가 (반별 시간표 즉시 전환)
  - `AI 배정` 단일 입력 UI 도입 (복잡한 위자드/프롬프트 패널/생성안 저장 UI 제거)
  - 과목 카드 탭 시 설정 모달에서 교사(주/보조)와 장소(교실) 지정 지원
  - 과목 팔레트 아래 `선생님 팔레트`, `교실 팔레트` 추가 및 DnD 배정 지원
  - 장소(교실) 팔레트 관리 UI 추가(추가/삭제)
  - 로컬 초안 편집 흐름 추가: `수정 확정` / `롤백`
- 탭 이탈 경고 추가 (`home_page.dart`)
  - 시간표 탭에 미확정 변경사항이 있을 때 다른 탭 이동 시 경고 다이얼로그 표시
- DnD payload 타입 확장 (`nest_models.dart`)
  - `DragPayloadType.teacher`, `DragPayloadType.room` 추가
- 메인 패널 폭 정책 조정 (`home_page.dart`)
  - Schedule/Timetable 탭은 최대폭 제한을 풀어 보드 가용폭 확보

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.4+5 (2026-03-07)

### Added

- UI 반복 점검 로그 문서 추가
  - `docs/ui_iteration_100.md`
  - 분석 → 개선제안 → 개선피드백 100회 루프 기록
  - 원칙: 핵심기능/집중 신규피처 추가 없이 UI 품질 개선만 수행

### Changed

- 전역 UI 폴리시 정돈 (`nest_theme.dart`)
  - 버튼/세그먼트/네비게이션/스낵바/바텀시트 시각 스타일 통일
  - 구분선/상태 피드백 대비 보강
- 메인 헤더 반응형 개선 (`home_page.dart`)
  - 소형 폭에서 타이틀/역할/행동 버튼 재배치로 오버플로 방지
  - 본문 콘텐츠 최대 폭 제한으로 데스크톱 가독성 개선
- 허브 공통 레이아웃 개선 (`hub_scaffold.dart`)
  - 좁은 화면에서 섹션 선택을 가로 스크롤 칩으로 전환
  - 허브 카드 영역 최대 폭 최적화
- 시스템 어드민 섹션 전환 개선 (`system_admin_tab.dart`)
  - 화면 폭에 따라 `SegmentedButton` ↔ `ChoiceChip` 전환

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

## 1.0.3+4 (2026-03-07)

### Added

- 공용 선택 UX 위젯 추가
  - `search_select_field.dart`
  - `SelectFieldCard`: 클릭형 카드 선택 필드
  - `showSelectSheet`: 검색 가능한 바텀시트 선택창

### Changed

- `Term Setup` UX 개선 (`family_admin_tab.dart`)
  - 가정 선택, 반 선택, 불가시간 대상 선택을 드롭다운에서 검색형 카드 선택으로 전환
  - 불가시간 요일 선택을 드롭다운에서 `ChoiceChip` 기반 빠른 선택으로 전환
  - 교사 유형 선택을 드롭다운에서 `SegmentedButton`으로 전환
- `Teacher Hub` UX 개선 (`teacher_hub_tab.dart`)
  - 담당 반/수업세션/작성교사/아이/활동유형/불가시간 프로필 선택을 검색형 카드 선택으로 전환
  - 수업운영 입력의 문맥 설명(help text) 강화
- `Parent` 아이 선택 UX 개선 (`child_selector_header.dart`)
  - 아이 전환을 검색형 카드 선택으로 통일

### Verification

- `flutter analyze` 통과
- `flutter test` 통과
- `flutter build web --release --base-href /nest/` 통과

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
