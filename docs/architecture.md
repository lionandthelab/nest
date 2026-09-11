# Nest Flutter Architecture

Last updated: 2026-09-08

## 1. Goals

- Single Flutter codebase for web/mobile with consistent UX.
- Supabase-centered backend with strict RLS-based access control.
- Role-switching product model:
  - Parent view
  - Teacher view
  - Admin view
- Community dual mode:
  - User feed (post/comment/like/report)
  - Admin moderation (report queue/hide/pin/delete)
- Membership onboarding (2 paths):
  - admin invite create/cancel + invited user self-accept
  - non-member search homeschool directory + send join request
- Prompt timetable generation plus manual drag-and-drop editing.
- Questionnaire-based schedule concierge with multiple draft options and live conflict checks.
- Google Drive based media upload and gallery sharing.

## 2. System Overview

- Frontend: Flutter (`frontend/`)
- Backend: Supabase
  - Auth: email/password + Google/Kakao/Naver (`lion_auth`). Apple은 노출하지 않음
  - DB: Postgres + RLS
  - Edge Functions:
    - `timetable-assistant-generate`
    - `google-drive-connect-start`
    - `google-drive-connect-complete`
    - `google-drive-upload`
- Web deployment: GitHub Pages (`gh-pages`)

## 3. Project Structure

```text
frontend/
  lib/
    main.dart
    src/
      config/
        app_config.dart
      models/
        nest_models.dart
      services/
        nest_repository.dart
        local_planner.dart
        web_oauth_bridge.dart
        web_oauth_bridge_stub.dart
        web_oauth_bridge_web.dart
      state/
        nest_controller.dart
      ui/
        nest_app.dart
        nest_theme.dart
        login_page.dart
        home_page.dart
        widgets/
          child_selector_header.dart
          hub_scaffold.dart
          nest_motion.dart
          search_select_field.dart
          homeschool_tips_card.dart
          homeschool_create_dialog.dart
        models/
          new_term_checklist.dart
          homeschool_start_tips.dart
          tab_section_request.dart
        tabs/
          dashboard_tab.dart
          admin_home_tab.dart
          admin_news_tab.dart
          timetable_workspace_tab.dart
          parent_timetable_tab.dart
          parent_progress_tab.dart
          parent_news_tab.dart
          teacher_hub_tab.dart
          timetable_tab.dart
          gallery_tab.dart
          community_feed_tab.dart
          community_tab.dart
          members_tab.dart
          family_admin_tab.dart
          ops_tab.dart
          drive_tab.dart
  web/
    index.html
    oauth/google/callback.html
  test/
    widget_test.dart
    models_test.dart

supabase/
  migrations/
    20260302160000_init_nest.sql
    20260302173000_constraints_and_drive_tokens.sql
    20260303060000_community_sns.sql
    20260303130000_homeschool_invites.sql
    20260303143000_children_policy_fix.sql
    20260303145000_child_admin_rpc.sql
    20260303150000_invite_rpc_fix.sql
    20260303162000_class_groups_delete_and_member_search.sql
    20260303190000_member_unavailability_blocks.sql
    20260308201000_family_child_delete_policies.sql
    20260308223000_courses_delete_policy.sql
    20260308233000_classrooms.sql
    20260308235500_family_guardians_delete_policy.sql
    20260309003000_homeschool_join_requests_and_directory.sql
    20260309011500_homeschool_invites_name_snapshot.sql
```

## 4. Role Model and View Switching

### 4.1 Membership Roles

- `HOMESCHOOL_ADMIN`
- `STAFF`
- `TEACHER`
- `GUEST_TEACHER`
- `PARENT`
- `STUDENT` (2026-08 추가, 마이그레이션 `20260814090000_membership_role_student.sql`) — 아이 본인 계정. 다른 5개 역할과 달리 **가정 데이터 가시성이 본인/본인 가정으로 제한**된다 (§6.15, §7.4).

### 4.2 View Role Resolution

- A user can hold multiple roles in one homeschool.
- `NestController.availableViewRoles` computes switchable roles from active memberships.
- `NestController.changeViewRole()` sets the current active view role and persists preference in-memory by homeschool.
- Current role is shown and switched in the top context selector (`뷰 역할`).
- Header quick action:
  - when 2+ roles are available, a `뷰 전환` popup button is shown next to the current role chip
  - role switching works without opening the full context panel

### 4.3 Dynamic Tab Composition

Tabs are built dynamically in `HomePage._buildTabs`:

- Admin/Staff streamlined layout:
  - `Dashboard`
  - `Term Setup` (family/teacher/class/course setup)
  - `Schedule` (timetable authoring)
  - `System` (SNS moderation + Drive + membership + ops)
- Parent/Teacher user layout:
  - `Dashboard`
  - role hub (`Parent Hub` or `Teacher Hub`)
  - `Timetable`
  - `Gallery`
  - `Community`
- Parent/Teacher hubs share one visual frame (`HubScaffold`):
  - same header + KPI metric tiles
  - same section-chip navigation
  - same card density and spacing rhythm for predictable interaction

### 4.4 Global Context UX

- Top context controls use quick cards instead of stacked dropdowns:
  - `홈스쿨`, `학기`, `반`, `뷰 역할`
  - tap card -> searchable bottom-sheet picker
- Inline `설정 도움말` explains recommended selection order.
- Goal: reduce cognitive load and make context switching faster across all tabs.
- The same selection primitive is reused in tab forms:
  - `SelectFieldCard` (card-shaped selector)
  - `showSelectSheet` (searchable bottom-sheet chooser)
  - keeps mobile/web behavior consistent and avoids long dropdown lists.
- Full-width workspace policy:
  - desktop/mobile tab content uses full available width
  - no per-tab max-width clamp in the main panel and hub scaffold.

## 5. State and Data Flow

### 5.1 `NestController`

- Single source of UI/application state.
- Manages:
  - auth session and user
  - homeschool/term/class context
  - current view role and role capabilities
  - timetable data, gallery data, drive integration
  - community feed + moderation state
  - homeschool membership list for role administration
  - family/child/enrollment/teacher profile domain
  - teaching plans + student activity logs
  - announcements + audit logs

### 5.2 `NestRepository`

- Encapsulates Supabase table access and function invocation.
- Key role APIs:
  - `fetchMemberships(userId)`
  - `fetchHomeschoolMemberships(homeschoolId)`
  - `grantMembershipRole(homeschoolId, userId, role)`
  - `revokeMembershipRole(homeschoolId, userId, role)`
  - `fetchHomeschoolInvites(homeschoolId)`
  - `searchHomeschoolMembers(homeschoolId, query, limit)` (`search_homeschool_members` RPC)
  - `createHomeschoolInvite(...)`
  - `cancelHomeschoolInvite(inviteId)`
  - `acceptHomeschoolInvite(inviteToken)`
  - `searchHomeschoolDirectory(query, limit)` (`search_homeschool_directory` RPC)
  - `createHomeschoolJoinRequest(...)`
  - `fetchFamilies`, `createFamily`
  - `createCourse`, `updateCourse`, `deleteCourse`
  - `fetchClassrooms`, `createClassroom`, `updateClassroom`, `deleteClassroom`
  - `upsertFamilyGuardian`, `deleteFamilyGuardian`
  - `fetchFamilyGuardianUserIds`
  - `fetchChildren`, `createChild` (`create_child_admin` RPC)
  - `createClassGroup`, `updateClassGroup`, `deleteClassGroup`
  - `fetchClassEnrollments`, `upsertClassEnrollment`, `deleteClassEnrollment`
  - `fetchTeacherProfiles`, `createTeacherProfile`
  - `fetchMemberUnavailabilityBlocks`, `createMemberUnavailabilityBlock`, `deleteMemberUnavailabilityBlock`
  - `fetchSessionTeacherAssignments`, `setSessionMainTeacher`, `upsertSessionTeacherAssignment`
  - `fetchTeachingPlans`, `createTeachingPlan`
  - `fetchStudentActivityLogs`, `createStudentActivityLog`
  - `fetchAnnouncements`, `createAnnouncement`
  - `fetchAuditLogs`, `insertAuditLog`

## 6. Feature Architecture

### 6.1 Auth and Context Bootstrapping

1. Sign in/up via `Supabase.auth` (이메일) 또는 `lion_auth` 구글·카카오·네이버. 소셜 세션은 같은 Supabase 클라이언트라 `NestController`가 `onAuthStateChange`로 이어받는다. Apple 버튼은 심사/콘솔이 준비되기 전이라 숨긴다. 모바일 카카오는 공식 `loginWithKakaoAccount()`(Safari/Custom Tabs, 카카오톡 앱투앱 없음). 네이버는 `nid.naver.com` → `naver-oauth-bridge` → `nestnaverlogin://callback` → `social-broker`. 구글은 iOS `GIDClientID`가 있으면 네이티브 시트, 없으면 Supabase PKCE + `com.lionandthelab.nest://login-callback/`.
2. Load active memberships (`homeschool_memberships`) for current user.
3. Resolve current homeschool and view role.
4. Load dependent context in two waves:
  - 학기/반/교시와 `fetch_term_schedule_pack`(세션+교사 배정 1회)을, 초대·학사·개인 일정·캘린더와 동시에 읽는다
  - 가정/아이/수강은 반 목록이 생긴 뒤에 읽는다. 갤러리·커뮤니티는 해당 탭에서 `ensure*`
5. 반만 바꾸면 이미 받은 학기 팩에서 세션을 걸러 쓰고, 시간표 저장 뒤에만 팩을 다시 받는다

Admin dashboard onboarding:

- step-by-step setup roadmap cards with completion checks
  - 1) family/child setup
  - 2) class + child enrollment
  - 3) course preparation and class assignment path
  - 4) timetable generation/adjustment
- direct tab jump actions from roadmap (`Term Setup`, `Schedule`)

### 6.2 Timetable

- Admin view:
  - no AI prompt input in timetable management
  - no wizard/proposal panel/status side panel in main flow
  - explicit draft lifecycle:
    - `수정 확정` (board top-right): persist staged changes
    - discard/rollback is handled only via confirmation when switching class/tab with unsaved edits
  - unsaved-change guard on tab leave (warning dialog)
  - class-first editing UX:
    - dedicated class switcher card in schedule tab
    - current class summary (session count / assigned teacher count)
  - drag-and-drop schedule studio:
    - full-width prioritized timetable board (reduced horizontal scroll pressure)
    - course palette + teacher palette + room palette
    - drag course -> create session
    - drag session -> move session
    - drag teacher/room -> assign to slot/session
  - per-session setting modal on card tap:
    - main/assistant teacher assignment
    - location(room) assignment
  - room management UI:
    - room palette is synced from `Term Setup > 교실 관리`
    - manual room typing is removed from timetable board flow
  - export (시간표 / 교실 상황표) — PNG + 엑셀. 상세는 6.2.1d
- Parent/Teacher view:
  - read-only schedule visibility (editing hidden/disabled)
  - visual session cards with icon rows for course/time/teacher/room scanning.
  - parent timetable includes weekly board view (`요일 x 교시`) for selected child.
  - parent notice preview shows latest 3 announcements at home header with `모두 보기` jump.

### 6.2.1b Timetable Builder Redesign (2026 개편)

전체 설계 스펙: `docs/06_admin_timetable_redesign.md`. 기존 `_draftSessions`/`_draftAssignments`/`_commitDraftChanges` 드래프트 버퍼 위에 얹은 인플레이스 업그레이드(새 상태 라이브러리 없음, 단일 `NestController` 유지).

- 드래그 빌더 코어(Phase 1):
  - 모든 드래그가 즉시 `Draggable`(기존 `LongPressDraggable` 제거).
  - "수업 카드 조립" — 과목+주강사+장소를 한 번의 드래그로 배치(`ComposedSessionPayload`).
  - 드롭 전 실시간 충돌 표시(`DropConflictState`): 점유/교사충돌(HARD, 드롭 거부) · 불가시간(WARN, 허용). `_hasTeacherSlotConflict`는 DB 트리거(`enforce_teacher_timeslot_conflict`)를 그대로 반영(같은 time_slot_id·다른 course만 충돌, 합반 허용)하며 `allTermSessions`+`allTermSessionTeacherAssignments`로 전교 범위 검사.
  - 드래그-투-트래시 삭제(하드 `deleteSession`), 클라이언트 Undo/Redo(Ctrl+Z/Ctrl+Shift+Z), ARCHIVED 학기 frosted 잠금.
- 한눈에 보기(Phase 2):
  - `WholeSchoolOverlayBoard`(읽기 전용) — 요일×교시를 반/장소/선생 축으로 피벗, 교사·교실 더블부킹 강조.
  - `ObjectInspectorRail`(우측 ≥1500px) — 반/선생/가정 선택 시 등록 학생·세션·교사·불가시간·보호자 등 FK 관계를 읽기 전용으로 펼침.
  - `RoomNormalizer`로 장소 문자열 정규화/중복 제거.
- 오브젝트 워크스페이스(Phase 3):
  - `FamilyEnrollmentPanel` 다이얼로그 — 학생 카드를 반 드롭존에 드래그해 등록, 다중 선택 일괄 배정은 `syncClassEnrollments`(합집합 add-only). ARCHIVED/권한/busy 가드.
- 벌크 + 원자적 커밋(Phase 4):
  - 세션 ⋮/우클릭 컨텍스트 메뉴: 이 요일 전체/이 교시 모든 요일/주 전체 채우기/수업 카드 복제(드래프트 한정, 점유·충돌 칸 스킵).
  - `apply_timetable_draft` RPC(`supabase/migrations/20260610100000_*.sql`, SECURITY INVOKER, 단일 트랜잭션)로 커밋을 원자화. 마이그레이션 미배포 시 `TimetableBatchUnsupported`(PGRST202) 감지 → 기존 개별 호출 루프(`_commitDraftViaIndividualCalls`)로 자동 폴백. 웹 배포(GitHub Pages)는 프론트만 배포하므로 운영 활성 경로는 폴백 루프이며, RPC는 `scripts/deploy_supabase.sh` 적용 후 활성화.

### 6.2.1c 학기 네비게이터 / 다음 학기 미리 설정 (2026)

관리자가 다음 학기를 미리 만들어 설정하고, 지난/현재/예정 학기를 오가며 관리하는 상위 뷰.

- **날짜 기반 phase**: `Term.phaseAt(now)`(`nest_models.dart`)가 `start_date`/`end_date`를 오늘과 하루 단위로 비교해 `TermPhase.past/current/upcoming`을 파생한다. DB `term_status`(DRAFT/ACTIVE/ARCHIVED)와 **독립**적이다. 컨트롤러는 `phaseOf`, `pastTerms`/`currentTerm`/`upcomingTerms`, `selectedTermPhase`를 노출한다.
- **상단 학기 바** (`widgets/term_navigator_bar.dart`, 관리자 전용): `home_page.dart`의 데스크톱(`_MainPanel`)·모바일(`_MobileScaffold`) 탭 콘텐츠 위에 고정. 학기 칩(지난/현재/예정 배지) + ◀▶ 이동으로 `changeTerm`을 호출하면 모든 탭이 그 학기 기준으로 전환된다. `+ 예정 학기` 및 편집(연필)은 `TermEditorDialog`를 연다.
- **학부모/교사 학기 선택 칩** (`widgets/term_select_chip.dart`): 학부모/교사 컴팩트 헤더(데스크톱 `_buildParentDesktopHeader`·모바일 `_buildParentCompactHeader`, `isParentView || isTeacherView` 게이트)에 붙는 경량 학기 전환기. 현재 학기 이름 + 단계 배지를 보여주고, 탭하면 바텀시트에서 학기를 골라 `changeTerm`을 호출한다(생성/수정 없음). 정렬·배지 색은 관리자 바와 공유(`compareTermsByStartDate`, `termPhaseColor`).
- **기본 학기 선택**: `resolveTermSelection`(`nest_models.dart`) — 사용자가 이번 세션에서 `changeTerm`으로 직접 고른 경우(`_termSelectionIsExplicit`)에만 선택을 유지하고, 그 외(부팅·캐시 복원·재로드)는 `defaultTermForToday`(현재 → 직전 → 가장 이른 예정)로 재선택한다. `_restoreFromCache`도 캐시된 이전 학기 선택을 같은 규칙으로 재해석해(오프라인 포함) 학기 종속 캐시가 다른 학기 것이면 비운다. `updateTerm`/`deleteTerm`은 재해석으로 선택이 옮겨지면 `changeTerm` 수준의 하위 재로드를 수행한다. 학부모 자녀 반 번들(`home_page.dart`)은 자녀·학기·반 배정 복합 키 + 세대 토큰으로 무효화/재로드된다.
- **학기 CRUD**: `NestRepository.createTerm/updateTerm/deleteTerm` + `NestController.createTerm/updateTerm/deleteTerm`. 생성은 항상 `DRAFT`. 삭제는 반/세션/시간표/교실/자습이 `ON DELETE CASCADE`로 함께 지워지는 파괴적 작업이라, 앱단에서 **마지막 학기·ARCHIVED 삭제를 차단**하고 연쇄 삭제를 경고한다. DB단은 `terms_delete_admin_staff` RLS + `guard_delete_terms` BEFORE DELETE 트리거(ARCHIVED 차단)로 이중 방어(`20260708090000_term_delete_policy.sql`).
- **지난 학기 읽기 전용**: `isSelectedTermReadOnly = ARCHIVED || (past && !unlock)`. `togglePastTermEditing`으로 관리자가 해제(학기 전환 시 자동 재잠금). timetable/enrollment/family-admin(반·교실)/self-study의 편집 진입점이 이 플래그로 잠기고 배너를 표시한다. self-study 뮤테이션은 컨트롤러 `_assertSelectedTermEditable()`로 백스톱(자습 테이블엔 DB 소프트락 없음). 지난 학기는 UI 소프트 잠금.
- **ARCHIVED = 불가침 기록**: DB 트리거로 하드 잠금 — `guard_delete_terms`(삭제 금지) + `guard_update_archived_terms`(보관 상태 유지 시 이름·기간 수정 금지, 보관 해제(status 변경)만 허용) + 자습 3테이블 `guard_mutation_self_study_*`(반·수업 테이블과 동일 패턴). 앱단도 `updateTerm`/`deleteTerm`에서 동일 규칙을 선검증. 편집 다이얼로그는 보관 학기의 이름·기간 필드를 잠근다.

### 6.2.1d 시간표 / 교실 상황표 내보내기 (PNG · 엑셀, 2026-08)

편집 보드를 그대로 캡처하던 방식은 드래그용 셀(최소 높이 132px)에 작은 글씨가 얹혀 내보낸 이미지의 가독성이 떨어지고, 교실 상황표처럼 행이 많은 표는 캔버스 한계를 넘겨 PNG 저장이 조용히 실패했다. 내보내기를 편집 보드에서 떼어내 "읽기 위한 표"로 다시 그린다.

- **공용 데이터 모델** (`ui/tabs/timetable/timetable_export_board.dart`): `TimetableExportTable`(제목/열/구역) → `TimetableExportSection`(교실 상황표는 요일별) → `TimetableExportPeriod`(시간대 행) → `TimetableExportEntry`(과목·반·교실·교사). 미리보기·PNG·엑셀이 모두 이 한 모델에서 나오므로 세 결과물이 어긋나지 않는다. `timetable_tab.dart`의 `_buildTimetableExportTable`(편집 중인 드래프트 기준) / `_buildRoomUtilizationExportTable`(`allTermSessions` 기준)이 모델을 만든다.
- **읽기 전용 렌더러** `TimetableExportBoard`: 과목 20pt/보조 15pt 기준에 행 높이는 내용에 맞춰 늘어난다(고정 최소 높이 없음). 글자 크기 프리셋(`TimetableExportScale` 보통/크게/아주 크게, 기본 "크게")과 "빈 시간대 숨기기"(기본 켜짐)를 지원한다. 표 바깥 테두리 두께를 보드 전체 너비에 반영해야 안쪽 `Row`가 넘치지 않는다(위젯 테스트로 고정).
- **PNG 저장**: 배율은 고정 2배가 아니라 `_capturePixelRatio`가 긴 변 6000px·총 3200만 픽셀 안에서 최대 3배까지 잡는다(웹 캔버스는 한 변 8192px 부근에서 실패). 캡처 실패는 삼켜지지 않고 다이얼로그 안 문구로 표시된다(스낵바는 모달 뒤에 가려 보이지 않음).
- **엑셀 저장**: `services/xlsx_writer.dart`가 `package:archive`의 ZipEncoder로 OOXML을 직접 만든다(문자열 셀·열 너비·행 높이·병합·서식·틀 고정). 외부 엑셀 패키지는 `archive` 버전이 `flutter_native_splash → image`와 충돌해 쓸 수 없다. `timetable_excel_export.dart`가 워크북을 두 시트로 구성한다 — **표**(PNG와 같은 격자, 인쇄·배포용) / **목록**(수업 한 줄씩, 정렬·필터·일괄 수정용).
- **플랫폼 제약**: 파일 저장은 웹에서만 동작한다(`download_helper_stub`은 no-op). `DownloadHelper.isSupported`로 이를 감지해, 앱에서는 "저장했습니다"라고 잘못 알리는 대신 웹에서 내보내라고 안내한다.

### 6.2.1 Session Location Compatibility

- Some deployments had `class_sessions.location` while older ones did not.
- Repository layer now supports both schemas safely:
  - with location column: normal read/write
  - without location column: fallback queries/inserts without location
  - null violation on location: fallback value (`미정`) to keep DnD scheduling working
- Canonical migration: `20260306100000_session_location.sql`

### 6.3 Community

- User Feed (`community_feed_tab.dart`)
  - create post (text + optional media)
  - like, comment
  - report post (category + detail)
- Admin Moderation (`community_tab.dart`)
  - moderation metrics
  - open report queue and status resolution
  - post hide/unhide, pin/unpin, delete

### 6.4 Parent/Teacher Hub UX

- Parent view tabs:
  - `parent_timetable_tab.dart`
  - `parent_progress_tab.dart`
  - `parent_news_tab.dart`
  - child selection moved to home header bar (global for parent tabs)
  - parent child selector only exposes guardian-linked children (`NestController.myChildren`)
  - selected child 기준으로 반/시간표/학습 상태를 일관되게 제공
  - avatar-first visual identity for child/class entities in selectors and cards
- Teacher Hub (`teacher_hub_tab.dart`)
  - sections: `반 운영보드` / `수업 운영` / `아이 상태`
  - current teacher profiles를 기준으로 담당 반 자동 식별
  - 반별 시간표/공지/아동 상태를 한 반 컨텍스트로 관리
  - class-specific teaching plan, announcement, activity log authoring flow
  - class/session/teacher/activity/unavailability target selection uses searchable selector cards instead of dense dropdown stacks
  - session and activity timeline cards use avatar/icon metadata for quick class operations.

### 6.5 Form Interaction UX

- Term Setup (`family_admin_tab.dart`)
  - family tab migrated to card-first management flow (`가정 관리` + `아이 관리`)
  - family/child selection is unified as direct card-click interaction
  - class selection in class CRUD/enrollment migrated to direct card-click selection
  - day-of-week input migrated to quick chips for faster blocked-time authoring
  - teacher type input migrated to segmented control (`부모 교사`, `초청 교사`)
  - family/child/class lists upgraded with visual entity tiles (avatar + status/meta)
  - family card click opens unified create/edit dialog for family info
  - child card click opens unified create/edit dialog for child info (family reassignment + birth/profile edit)
  - teacher card click opens a unified create/edit dialog:
    - profile edit (`표시 이름`, `교사 유형`)
    - existing account link/unlink (name/email/UUID search)
    - unavailable-time add/remove in the same dialog
  - class tab onboarding draft generator removed to keep class setup focused on direct CRUD + enrollment
- Parent child selector (`home_page.dart` header bar)
  - child switching is centralized in global header and shared across all parent tabs
  - header context area (`홈스쿨/학기/반/뷰 역할`) is always expanded and full-width (no extra collapse open action required)
  - user identity line shows display name + email in header for quick account recognition
  - IA labels are Korean-first (관리자: `홈`, `학기 설정`, `시간표`, `소식`, `시스템` — §6.19 / 그 외: `교사 허브`, `갤러리`, `커뮤니티`)
  - desktop left rail top logo (`assets/logo.png`) is clickable and routes to home tab
  - each tab view includes a bottom micro-caption (`현재 탭: ...`) to clarify current workspace context
- Shared objective:
  - reduce initial setup friction in large homeschool contexts
  - keep one-tap edit flow while preserving existing backend model
- Both hubs use:
  - card-first layout with low cognitive load
  - section switching through `ChoiceChip` controls
  - animated section swap for continuity

### 6.5 Motion and Loading System

- **제로 레이턴시 탭**: 모바일 콘텐츠는 `IndexedStack`으로 즉시 바꾸고, 모션은 손끝과 카드 랜딩에만 쓴다. 반복 루프 애니메이션은 없다.
- `NestPressable`: 누르는 즉시(70ms) 0.97 스케일 + 햅틱, 손을 떼면 살짝 오버슈트하며 복귀
- `NestAppear`: 홈/온보딩 카드가 아래에서 한 번만 올라와 앉는다 (stagger 42ms)
- `NestDockBar`: 하단 탭. 선택 필과 아이콘만 움직이고 화면은 기다리지 않는다
- `showNestSheet`: 알림함·검색 시트. 딤 28% + 핸들
- 안드로이드 페이지 전환은 `NestPageTransitionsBuilder` (짧은 페이드+상승). iOS는 시스템 스와이프 백 유지
- 스플래시/리플은 끈다 (`NoSplash`). 하이라이트만 roseMist
- Busy/Loading
  - `NestLoadingScreen`: branded warm loading scene
  - `NestBusyOverlay`: 상단 2px 진행바 + 얇은 베일. `blocksUi`일 때만 포인터를 막는다
- Login: 카드 스케일 인 + 로그인/회원가입 필드 전환

### 6.6 Membership and Permission Admin

- `members_tab.dart` (HOMESCHOOL_ADMIN only):
  - quick self-role card (`내 계정 역할 전환`) to grant/revoke `PARENT`/`TEACHER`/`GUEST_TEACHER` on the current admin account
  - grant role to target `auth.users.id`
  - revoke specific role
  - guardrail: cannot remove last remaining `HOMESCHOOL_ADMIN`
  - invite by email with role pre-assignment
  - pending invite cancellation

### 6.7 Drive and Gallery

- OAuth start/complete through edge functions and web bridge.
- Drive tab is simplified for operators:
  - root folder + folder policy + OAuth actions
  - developer token fields hidden behind explicit advanced toggle
- Upload flow:
  1. create `media_upload_sessions`
  2. upload to Drive via edge function
  3. insert `media_assets` and optional child tagging
  4. show in gallery and community attachments

### 6.8 Invite Acceptance (시작하기)

- 소속이 없을 때 `시작하기`(`DashboardTab`)가 로그인 이메일과 맞는 대기 초대를 보여 준다.
- Accept flow:
  1. user clicks `초대 수락`
  2. app calls `accept_homeschool_invite` RPC
  3. DB activates `homeschool_memberships` row
  4. controller reloads memberships/context and role tabs

### 6.8.1 No-membership Onboarding UX

- 소속이 없으면 `HomePage`는 `시작하기` 탭 하나만 보여 준다 (`DashboardTab`).
- **메인**: 우리집 홈스쿨 개설. 기본값을 채워 바로 시작할 수 있게 하고, 짧은 팁을 위에 둔다.
- **서브**: 이미 있는 홈스쿨 참여. `이미 홈스쿨이 있나요?` 접기 안에 참여 코드 · 이름 검색 가입 요청.
- 이메일 초대가 있으면 접기 밖에 초대장을 바로 보여 준다.
- 홈스쿨 개설 flow:
  1. `우리집 홈스쿨 시작하기` → `HomeschoolCreateDialog`
  2. `bootstrapFrame()` → `createBootstrapFrame()` (홈스쿨 + 관리자 멤버십 + 학기/반/과목/슬롯). 반·과목·교시는 병렬 insert.
  3. 멤버십 + 학기/반만 맞춘 뒤 관리자 홈으로 전환. 초대·갤러리·일정 부가 데이터는 뒤에서 읽는다.
  4. 생성 중 중복 탭은 다이얼로그 `_submitting` + 컨트롤러 `_bootstrapInFlight` + `_runBusy` 재진입 거부로 막는다.
- 가입 요청 flow:
  1. user searches by homeschool name
  2. app calls `search_homeschool_directory` RPC
  3. user submits request note in modal
  4. app inserts `homeschool_join_requests` with `PENDING`

### 6.8.2 Homeschool Start Tips

- 정적 컨텐츠 (`ui/models/homeschool_start_tips.dart`). DB 없음. 법령·학력 인정·신고는 다루지 않는다.
- `HomeschoolTipsCard`가 날짜 기준 오늘의 팁 + 나머지 목록을 보여 준다.
- 온보딩(`시작하기`)·학부모 홈·관리자 홈에서 재사용한다.

### 6.9 Family and Enrollment Admin

  - `family_admin_tab.dart`:
  - term setup workspace with unit-level sections:
    - top KPI summary cards (large metric + unit):
      - families (`가정`), children (`명`), guardians (`명`), teachers (`명`), classes (`반`), courses (`개`), classrooms (`개`)
      - single-glance visibility so admins can read scale without counting cards
    - family (family card management + child card management with unified edit dialogs)
      - family edit dialog includes parent-account link/unlink controls (`family_guardians`)
      - family/child edit dialogs include delete actions with confirmation guardrails
    - teacher (teacher profile edit + account link/unlink + unavailability in one modal)
    - class (class cards + unified class create/edit modal)
    - class modal supports:
      - class create/update/delete
      - child assignment in the same modal with multi-select
    - course (course cards + unified course create/edit/delete modal)
    - classroom (classroom cards + unified classroom create/edit/delete modal)
    - section header count badges on each unit card:
      - family/child/teacher/class/course/classroom totals
  - setup progress bar + unit chips for direct switching
- `parent_timetable_tab.dart`:
  - selected child weekly schedule board (`요일 x 교시`) as primary view
  - class-level detail cards remain as secondary section
  - parent self-service unavailability registration/deletion (own account only)
- `teacher_hub_tab.dart`:
  - teacher self-service unavailability registration/deletion (own teacher profile only)

### 6.10 Teacher Plan and Activity Logs

- `teacher_hub_tab.dart`:
  - create teaching plan by class session
  - create student activity log by child/session
  - teacher-side announcement creation

### 6.11 Timetable Teacher Assignment

- `timetable_tab.dart`:
  - per-session teacher assignment dialog
  - main/assistant assignment controls
  - slot conflict warning badges (UI) + DB trigger enforcement
  - dirty-state synchronization guard:
    - after `수정 확정`, schedule draft dirty flag is force-synced to parent tab guard
    - prevents stale unsaved-change warning when navigating away from schedule tab
  - left palette quick resource management (without leaving schedule tab):
    - course quick create/delete
    - teacher quick create/delete
    - classroom quick create/delete (or palette-only cleanup for unlinked room tags)
  - export board width/padding calibration:
    - timetable/room-utilization PNG exports use symmetric left-right padding
    - avoids right edge sticking/clipping in exported images

### 6.12 Operations

- `ops_tab.dart` (Admin/Staff):
  - announcement posting and monitoring
  - audit log timeline (membership/report/timetable/invite actions)

### 6.13 System Admin Hub

- `system_admin_tab.dart`:
  - single admin tab that consolidates:
    - `SNS` moderation (`community_tab.dart`)
    - `Google Drive` integration (`drive_tab.dart`)
    - `Members` role/invite management (`members_tab.dart`)
    - `Ops` announcements + audit logs (`ops_tab.dart`)

### 6.14 UI Iteration Loop (100x)

- UI-only 반복 개선 로그를 `docs/ui_iteration_100.md`에 유지
- 루프 원칙:
  - 기능 추가 없이 인터랙션 마찰, 가독성, 일관성만 개선
  - 분석 → 개선제안 → 개선피드백 구조를 반복
- 이번 루프에서 코드 반영된 공통 개선:
  - `home_page.dart`: 반응형 헤더 액션 정렬 + 본문 최대 폭 제한
  - `hub_scaffold.dart`: 좁은 화면 섹션 선택 가로 스크롤 칩 + 레이아웃 폭 최적화
  - `system_admin_tab.dart`: 화면 폭별 세그먼트/칩 전환
  - `nest_theme.dart`: 버튼/세그먼트/네비/스낵바/바텀시트 스타일 통일

### 6.15 학생 계정 (Student Accounts, 2026-08)

아이가 직접 가입한 계정을 `children` 레코드에 연결해, 학부모를 거치지 않고 본인 시간표를 보고 결석을 신고할 수 있게 한다.

- **연결 모델**: `children.user_id uuid null references auth.users(id) on delete set null` + `uq_children_user_id` 부분 유니크 인덱스(`where user_id is not null`). `teacher_profiles.user_id`와 완전히 같은 패턴이며, 계정 1개는 자녀 1명에만 붙는다. 마이그레이션 `20260814091000_student_accounts.sql`.
- **합류 흐름**: 기존 참여 코드 온보딩(`request_join_with_code`)을 그대로 재사용한다. 학생은 역할 `STUDENT`로 요청하고, 관리자가 승인 화면에서 **어느 자녀인지** 고른다. `approve_join_request`는 4번째 인자 `p_child_id`를 받도록 교체됐다(기존 3-인자 시그니처는 `drop` — default 인자만 늘리면 "function is not unique" 모호성이 생긴다). 승인 시 멤버십 생성 **전에** 자녀의 홈스쿨 일치 여부를 먼저 검증하고, 이미 다른 계정이 연결된 자녀면 `CHILD_ALREADY_LINKED`로 거절한다.
- **관리자 수동 연결**: `link_child_account(child_id, user_id)` / `unlink_child_account(child_id)` RPC. 승인 밖에서(이미 멤버인 아이, 잘못 연결한 경우) 붙이고 뗀다. `link_child_account`는 STUDENT 멤버십이 없으면 함께 부여하되 기존 역할은 건드리지 않는다.
- **학생 전용 탭**: `student_home_tab.dart`(오늘 수업 + 변경 공지 + 결석 신고), `student_timetable_tab.dart`(주간 시간표 + 회차별 결석 신고). `HomePage._buildTabs()`에서 `STUDENT` 뷰 역할일 때 등록된다.
- **하위 호환**: `NestRepository`의 children select 는 `user_id`를 포함하되, 42703(컬럼 없음)을 만나면 레거시 select 로 폴백하고 `_childUserIdSupported=false`를 캐시한다. 마이그레이션 미배포 서버에서도 기존 화면이 그대로 뜬다.

### 6.16 수업 변경 공지 (Class Session Changes, 2026-08)

`class_sessions`는 "요일 × 교시" **주간 반복 템플릿**이라 날짜 컬럼이 없다. 그래서 "이번 주 목요일만 휴강", "다음 주부터 학기 끝까지 교실 이동" 같은 실제 운영 공지를 표현할 계층이 없었다. 마이그레이션 `20260814092000_class_session_changes.sql`.

- **테이블** `class_session_changes`: `change_type in ('CANCELED','TIME_MOVED','ROOM_MOVED','TEACHER_SUBSTITUTE','NOTE')` + 유효기간 `effective_from date not null` / `effective_to date null`.
  - `effective_to is null` → 학기 끝까지 계속 적용
  - `effective_from = effective_to` → 그 날짜 하루만 ("이번 주만")
  - `self_study_supervisions`의 `occurrence_date` 오버라이드와 같은 계층 구조다.
- **권한**: 그 수업의 담당 교사(`session_teacher_assignments` MAIN/ASSISTANT) 또는 반 담임(`class_groups.main_teacher_id`) 또는 ADMIN/STAFF. 시간표 테이블 자체의 쓰기 정책은 여전히 ADMIN/STAFF 전용이므로, **교사는 이 "변경 공지" 계층을 통해서만** 학생·학부모에게 변경을 알린다. 교사는 자기가 등록한 행만 수정/삭제할 수 있고 ADMIN/STAFF는 전부 가능하다.
- **헬퍼** `is_session_teacher(class_session_id)`: 배정 교사 ∪ 담임. `teacher_profiles.user_id`는 멤버십을 지워도 남기 때문에 **ACTIVE 멤버십을 함께 요구**한다(떠난 교사가 반 전체에 문자를 쏘는 것을 막는다).
- **UI**: `ui/tabs/timetable/class_change_dialog.dart` (등록 다이얼로그 + `ClassSessionChangeTile`). 교사 허브·시간표·학생/학부모 시간표에서 공유한다.
- `notified_at`: `nest-notify`가 발송을 마치면 채운다. 중복 발송 방지 및 "발송됨" 표시용.

### 6.17 결석 신고 (Absence Reports, 2026-08)

학생 본인 또는 보호자가 **다가오는** 특정 회차의 결석을 미리 알린다. 마이그레이션 `20260814093000_absence_reports.sql`.

- **회차 지정**: `(class_session_id, occurrence_date)` 조합. 세션에 날짜가 없으므로 RPC가 정합성을 검증한다 — 요일 일치(`extract(dow from date)`와 `time_slots.day_of_week`는 둘 다 0=일요일이라 오프셋 보정이 없다), 학기 기간 내, 과거 날짜 아님, 그리고 `class_enrollments` 수강 여부.
- **쓰기 경로**: INSERT 정책을 두지 않고 `report_absence()` security-definer RPC로만 생성한다. 검증을 우회할 수 없게 하기 위함이다. 같은 회차에 대해 살아있는 신고는 `uq_absence_active` 부분 유니크 인덱스로 1건만 유지하고, 철회했다 다시 신고하면 기존 행을 되살린다.
- **상태**: `SUBMITTED` → `ACKNOWLEDGED`(담당 교사 확인, `acknowledge_absence_report`) 또는 `CANCELED`(신고자 철회, `cancel_absence_report`).
- **가시성**: 그 자녀의 보호자 / 학생 본인 / 담당 교사 / ADMIN·STAFF. 신고자 본인의 UPDATE는 "철회"만 허용하며, WITH CHECK가 철회 후에도 행이 **여전히 본인과 관계된 자녀**를 가리키도록 강제한다(WITH CHECK는 OLD를 못 보므로 `child_id` 바꿔치기를 이 조건으로 막는다).
- **UI**: 학생은 `student_timetable_tab.dart` / `student_home_tab.dart`, 학부모는 `parent_timetable_tab.dart`. `NestController.absenceFor(sessionId:, date:, childId:)`는 **같은 반에 형제가 있을 때 오탐을 막으려면 반드시 `childId`를 넘겨야 한다.**

### 6.18 알림 발송 — `nest-notify` + Solapi (2026-08)

수업 변경과 결석 신고를 문자(추후 알림톡)로 통지한다. Edge Function `supabase/functions/nest-notify/index.ts`.

- **핵심 계약(D3)**: 클라이언트는 **수신자를 절대 지정하지 않는다.** 도메인 이벤트 `{ event: 'CLASS_CHANGE' | 'ABSENCE', id, channel?, force? }`만 보내고, 서버가 수신자를 해석하고 인가한다. "임의의 전화번호로 문자를 쏘는" 오남용 경로가 원천적으로 없다.
- **인가는 함수 안에서 직접 한다.** service_role 클라이언트는 RLS를 우회하므로 RLS에 기댈 수 없다.
  - `CLASS_CHANGE` → 담당 교사(ACTIVE 멤버십 필수) 또는 담임 또는 ADMIN/STAFF
  - `ABSENCE` → 학생 본인 / 그 자녀의 보호자 / ADMIN·STAFF
- **수신자 해석**: `recipients_for_class_session()` / `recipients_for_absence_report()` (마이그레이션 `20260814094000_notification_recipients.sql`). 두 함수 모두 **`service_role` 전용**이다 — `authenticated`에 열어두면 STUDENT 계정이 직접 호출해 같은 반 다른 가정의 계정 uuid를 수집할 수 있어 §7.4의 격리가 무너진다. RPC 호출이 실패하면 Edge Function이 동등한 인라인 조인으로 폴백한다.
  - 수업 변경 → 그 반 수강생의 학생 계정 + 가정 보호자 계정
  - 결석 신고 → 그 수업의 배정 교사 + 담임
- **상한과 중복 제거**: 수신자 uuid를 `Set`으로 dedupe한 뒤 `MAX_RECIPIENTS = 300` 초과 시 413으로 거절한다. `notified_at`이 있으면 `force: true` 없이는 재발송하지 않는다.
- **전화번호 해석**: `profiles.phone`을 1차로 보고 비어 있으면 `auth.users.raw_user_meta_data->>'phone_number'`로 폴백한다. `profiles.phone`은 컬럼만 있고 사실상 비어 있었으므로, `20260814089000_profiles_phone_sync.sql`이 가입 트리거 · 메타데이터 동기화 트리거 · 기존 사용자 백필의 세 경로에서 채운다. `normalize_kr_phone()` 정규화에 실패한 값은 **저장하지 않는다** (형식이 깨진 번호를 넣으면 엉뚱한 사람에게 문자가 간다).
- **정직한 결과 보고**: 응답은 `{ accepted, sent, skipped_no_phone, skipped_no_account, already_notified, message_id }`. `sent == 0`이면 UI가 절대 "보냈습니다"라고 말하지 않고, 전화번호 미등록 / 앱 미가입 인원 수를 그대로 노출한다 (`NestController._notifyStatusMessage`). 수신자 1명당 `notification_log` 1행을 남긴다.
- **채널**: 기본값은 `index.ts`의 `DEFAULT_CHANNEL = 'sms'` 상수 하나다. 카카오 알림톡 템플릿이 승인되고 `SOLAPI_PFID`가 설정되면 이 값을 `'auto'`로 바꾸고 `ALIMTALK_TEMPLATE_IDS`에 템플릿 코드만 채우면 전환된다(알림톡 시도 후 실패 시 문자 대체).
- **Solapi 모듈** `supabase/functions/_shared/solapi.ts`: HMAC-SHA256 서명 + `messages/v4/send-many`. `lion-notify`와 로직이 사실상 같지만 **의도된 중복**이다 — `lion-notify`는 lion_auth 모듈의 벤더링된 템플릿 원본이라 수정하지 않는 것이 규칙이다. 서명 방식과 엔드포인트는 두 함수가 같은 Solapi 계정을 쓰도록 동일하게 유지한다.
- 배포 시 `verify_jwt = true` (`supabase/config.toml`). 로그인 사용자만 호출할 수 있다.

### 6.19 관리자 뷰 개편 — 신학기 운영 (2026-08)

관리자 대시보드는 초대 · 가입 요청 · 세팅 가이드 · 지표 4칸 · 학사일정 · Drive · 공지 · 초기 세팅이 한 줄로 이어진 긴 스크롤이었다. 신학기에 가장 자주 하는 작업(공지 작성, 학사일정 등록)이 카드 안에 묻혀 있었고, 학사일정 날짜는 `yyyy-MM-dd` 직접 타이핑이라 모바일에서 특히 나빴다. 관리자 동선을 신학기 기준으로 다시 짰다.

**탭 구성 변경** (`HomePage._buildTabs`)

| 이전 | 이후 |
|---|---|
| 대시보드 · 학기 설정 · 시간표 · 자습 · 시스템 | 홈 · 학기 설정 · 시간표(+자습) · **소식** · 시스템 |

- 하단 네비게이션은 5칸이 한계다. 자습은 같은 학기 시간표 데이터를 다루는 이웃 작업이라 `timetable_workspace_tab.dart`의 세그먼트로 합치고, 그 자리에 공지·학사일정 전용 **소식** 탭을 넣었다.
- `TimetableWorkspaceTab`은 두 화면을 `IndexedStack`으로 유지한다(시간표 드래프트·자습 계획 선택 같은 편집 중 상태가 세그먼트 전환으로 날아가면 안 된다). 아직 열지 않은 쪽은 만들지 않아 첫 진입 비용은 그대로다.
- 미저장 시간표 경고(`_isScheduleTabLabel`)는 탭 라벨이 여전히 `시간표`라 그대로 동작한다.

**관리자 홈** (`tabs/admin_home_tab.dart`)

- 학기 상태 줄 — 기간과 `개학까지 D-14` 카운트다운. 학기 이름/전환은 바로 위 `TermNavigatorBar`가 이미 하므로 중복을 피해 한 줄로만 덧붙인다.
- **신학기 준비 체크리스트** — 진행률 + `다음 단계: …` 버튼. 단계 목록은 **기본으로 접혀 있다**. 9단계를 모두 펼치면 360px 폭에서 '빠른 작업'이 접히는 선 아래로 밀려난다.
- **빠른 작업** 8칸 그리드(공지 / 학사일정 / 가정·아이 / 선생님 / 반 / 과목 / 시간표 / 멤버). 타일 최소 폭 150px 기준으로 열 수를 계산해 모바일 2열 · 데스크톱 4열.
- 지표는 4칸 카드 그리드 → 한 줄 칩 스트립으로 축소하고, 자주 쓰지 않는 Drive 연결은 접힌 카드로 맨 아래.
- `dashboard_tab.dart`는 **소속 없는 사용자의 온보딩 전용**이다. 메인은 우리 홈스쿨 개설, 참여는 접힌 서브다. 기존 `_DriveIntegrationCard` → `widgets/drive_integration_card.dart`, `빠른 초기 세팅` → `widgets/quick_bootstrap_card.dart`로 승격 이동.

**소식 탭** (`tabs/admin_news_tab.dart`)

- 세그먼트 2개(공지사항 / 학사일정). 목록 위 전폭 48px 기본 동작 버튼 → 바텀시트 편집기.
- 날짜는 `showDatePicker`로 고른다(`_DatePickerField`). 여러 날 일정은 스위치 하나로 종료일 필드를 연다.
- 카드마다 오버플로 메뉴(수정 / 상단 고정 / 삭제) — 좁은 폭에서 버튼이 제목을 밀어내지 않게 한 곳에 모았다.

**섹션 딥링크** (`ui/models/tab_section_request.dart`)

- 체크리스트/빠른 작업은 탭뿐 아니라 **탭 안의 섹션**까지 지정해 이동한다(예: 학기 설정 탭의 `반`, 소식 탭의 `학사일정`).
- `HomePage`가 대상 탭 라벨 + `TabSectionRequest{section, nonce}`를 들고 있다가 해당 탭에만 넘긴다. `_buildTabs`는 매 빌드마다 새 위젯 인스턴스를 만들지만 State는 유지되므로, 같은 섹션을 연달아 요청해도 반응하도록 `nonce`로 요청을 구분하고 `didUpdateWidget`에서 처리한다.
- 섹션 키는 `ui/models/new_term_checklist.dart`의 `NewTermSections`에 모여 있고, `FamilyAdminTab`의 설정 단위 키와 같은 값을 쓴다.

**체크리스트 모델** (`ui/models/new_term_checklist.dart`)

- 컨트롤러를 참조하지 않고 개수/플래그만 받는 순수 함수 `buildNewTermChecklist(...)`. 단위 테스트는 `test/new_term_checklist_test.dart`.
- 반 · 시간표 · 학사일정은 학기 종속이라 `hasTerm`이 false면 잠긴다. 가정 · 선생님 · 과목 · 교실은 홈스쿨 단위라 학기가 없어도 미리 준비할 수 있다.
- 교실은 `optional: true` — 진행률 분모에서 빠진다. 교실을 안 쓰는 홈스쿨에서 체크리스트가 영원히 미완료로 남지 않게 한다.

**공지 수정/삭제**

- `NestController.updateAnnouncement` / `deleteAnnouncement`, `updateAcademicEvent` 추가.
- `announcements`에는 select/insert/update 정책만 있었다. RLS가 켜진 테이블에서 **정책이 없는 명령은 0건 매칭으로 조용히 성공**하므로 삭제가 아무 일도 안 하는 것처럼 보인다. `20260821090000_announcements_delete_policy.sql`이 update와 같은 조건(작성자 본인 또는 ADMIN/STAFF)으로 delete를 연다.
- 마이그레이션 배포 전에도 삭제된 척하지 않는다 — 리포지토리가 `.select('id')`로 실제 삭제 행 수를 돌려받고, 0건이면 컨트롤러가 한국어 안내로 던진다.
- `NestController.allAnnouncements` 추가 — 기존 `announcements`는 선택된 반으로 걸러진 목록(학부모·학생·교사 화면용)이라, 반을 골라둔 관리자가 다른 반 공지를 관리할 수 없었다.

### 6.20 수업 회차 내용 (Course Lessons, 2026-08)

날짜별 진도표("9월 15일 = 창세기 36장 / 에서의 자손 / 담당 리아")를 앱 안에서 관리한다. 마이그레이션 `20260824090000_course_lessons.sql`.

**회차의 주인은 세션이 아니라 과목이다 (핵심 설계 결정)**

`class_sessions`는 "요일 × 교시" 주간 반복 템플릿이라 회차 개념이 없다. 회차를 어디에 매달지가 이 기능의 유일한 설계 갈림길이었다.

- 세션에 매달면: JOY의 화요일 전교생 모임(과거 `통합QT`, 현재 `주중예배`)은 반 14개 × 교시 4개 = **`class_sessions` 56행**이다. 한 날짜의 진도를 56번 입력해야 한다.
- 과목에 매달면: 날짜당 1행이고, 그 과목이 걸린 모든 반/교시의 시간표 셀이 같은 회차를 읽는다.

반별로 진도가 갈리는 과목은 이 학교에서 **이미 과목 자체를 쪼개서 쓴다**(`수학A`/`수학B`, `영어(민준)`/`영어(시온)`, `소리영어(배우리)`/`소리영어(채리아)`). 스키마가 이미 그 구분을 담고 있으므로 과목 단위가 맞다.

**날짜 범위는 학기에 묶지 않는다**

`(course_id, lesson_date)`만으로 유일하고 `term_id` 컬럼이 없다. 학기는 날짜로 결정되고, 실제 운영에서는 학기 종료일을 넘겨서까지 진도표를 먼저 짜둔다(예: 2026 가을 종료 11/30, 진도표는 12/15까지). `term_id`를 두면 그런 회차가 제약에 걸리거나 학기 경계에서 사라진다. 같은 이유로 ARCHIVED 학기 가드 트리거도 두지 않았다 — 진도표는 학기 구성(반/교시/배정)과 달리 지난 학기에도 보정 입력이 필요하다.

**컬럼**: `title`(창세기 36장) · `subtitle`(에서의 자손) · `presenter`(담당) · `content`(준비물 등 여러 줄) · `is_confirmed`(원본 진도표의 ✔️ 표시).

- `presenter`는 `teacher_profiles` 참조가 아니라 **자유 텍스트**다. 발표 담당이 교사 계정이 없는 학부모·학생인 경우가 흔하다.

**권한**

- 조회: `is_course_member(course_id)` — 그 홈스쿨 구성원 전체. 진도표는 학생·학부모에게 공개하는 정보다.
- 쓰기: `is_course_teacher(course_id)`(그 과목의 배정 교사 ∪ 담임) 또는 ADMIN/STAFF. `is_session_teacher`와 같은 이유로 **ACTIVE 멤버십을 함께 요구**한다.
- `class_session_changes`와 달리 "자기가 만든 행만" 제약이 **없다**. 여러 교사가 돌아가며 담당하는 진도표는 공동 편집물이고, 이 테이블에는 문자 발송처럼 되돌릴 수 없는 부작용이 없다.
- **테넌트 경계는 과목의 홈스쿨에 고정한다** (`20260824120000_course_lessons_tenant_guard.sql`). 최초 버전의 `is_course_teacher`는 `teacher_profiles.homeschool_id`만 확인했는데, 이건 "교사가 속한 홈스쿨"이지 "과목이 속한 홈스쿨"이 아니다. `class_sessions`에는 course와 class_group이 같은 홈스쿨이어야 한다는 제약이 없으므로, 다른 홈스쿨의 course_id로 자기 반에 세션을 하나 만들면 남의 학교 진도표에 쓰기 권한이 생겼다(읽기는 여전히 막힌다). 두 분기 모두 `tp.homeschool_id = c.homeschool_id`를 요구하도록 고쳐 쓰기 경계를 조회 정책과 같은 컬럼에 맞췄다.
- **학기는 가리지 않는다(의도).** `courses`는 `unique (homeschool_id, name)`이라 학기마다 재사용되는 한 행이고 진도표는 지난 학기 보정 입력이 필요하므로, 과거 학기에 배정됐던 교사도 계속 담당으로 인정된다. 같은 홈스쿨 안의 협업 편집을 전제로 한 선택이다.

**UI 게이트와 RLS의 간극을 정직하게 처리한다**

`canManageCourseLessons`는 홈스쿨 단위(`isTeacherView || isAdminLike`)인데 RLS는 과목 단위다. 담당하지 않는 과목의 시간표 셀에서도 입력 버튼이 보이므로, 그 간극에 걸린 결과를 그대로 노출하지 않는다.

- 쓰기 실패의 `23505`(같은 날짜 중복) / `42501`(RLS 거부)은 `NestController._throwCourseLessonWriteError`가 한국어 안내로 바꾼다. 그러지 않으면 한국어 화면에 영어 SQL 원문이 스낵바로 뜬다.
- 삭제는 `deleteAnnouncement`와 같이 `.select('id')`로 **실제 삭제된 행 수**를 돌려받는다. RLS가 막으면 DELETE는 0행에 예외 없이 "성공"하므로(§6.19에서 공지 삭제로 이미 한 번 겪었다), 0건이면 지워진 척하지 않고 한국어 오류를 던진다.

**UI** (`ui/tabs/timetable/course_lesson_sheet.dart`)

- `buildCourseLessonRows(controller, courseId)`: **학기 기간 안에서 그 과목이 있는 요일을 모두 펼쳐** 빈 회차 자리를 먼저 만들고, 저장된 회차를 같은 날짜 자리에 붙인다. 그래서 아무것도 입력하지 않은 학기에서도 1회차·2회차… 목록이 보이고 관리자는 빈 칸만 채우면 된다. 학기 밖 날짜(저장된 회차)는 `isInTerm: false`로 함께 합쳐 목록에서 사라지지 않게 한다. 순수 함수이며 단위 테스트는 `test/course_lesson_test.dart`.
  - `isInTerm`은 **학기 기간만** 본다. 생성용 날짜 집합(학기 안 + 수업 요일)을 그대로 쓰면 학기 중의 보강(수업 요일이 아닌 날)이 `학기 밖`으로 잘못 찍힌다.
  - 날짜 커서는 매 스텝 `_dateOnly`로 되돌린다. `DateTime.add`는 UTC 타임라인 기준이라 서머타임이 있는 지역(웹은 해외에서도 열린다)에서 시각 성분이 남고, 그러면 시분초 0인 저장 회차 키와 매칭되지 않아 같은 날짜가 두 줄로 갈라진다.
- 목록 영역은 `Flexible`로 **헤더가 쓰고 남은 높이**를 받는다. 화면 높이의 고정 비율로 잡으면 헤더와 합이 화면을 넘겨 가로모드 폰·낮은 브라우저 창에서 오버플로가 난다(회귀 테스트가 짧은 뷰포트를 함께 검증한다).
- 새 회차의 기본 날짜는 **아직 비어 있는 첫 자리**다. "그 과목의 다음 수업일"을 그대로 쓰면, 진도표를 미리 채워둔 과목에서는 열자마자 중복 날짜가 잡힌다.
- **날짜 창 정합**: 날짜 선택 범위(`_pickLessonDate`)와 다시 읽어오는 창(`NestController.courseLessonWindowLeadDays` / `courseLessonWindowTrailDays`)은 같은 상수를 쓴다. 고를 수는 있는데 refetch에 안 잡히는 날짜가 있으면 저장 직후 그 회차가 목록에서 사라지고, 같은 날짜로 재시도하면 유니크 위반이 난다.
- 시트를 열 때 `loadCourseLessonsForCourse(courseId)`로 **그 과목만 날짜 창 없이** 다시 읽는다. 시트는 학기 맥락이 없는 학기 설정 → 과목 관리에서도 열리고 과목은 학기가 아니라 홈스쿨에 매달려 있어, 창으로 걸러진 회차를 숨기면 "비어 보이는데 등록하면 중복" 상태가 된다.
- `CourseLessonSummary`: 시간표 셀 상세에 끼우는 요약 블록. 편집 권한에 따라 "회차별 내용 입력" / "전체 진도표 보기"로 문구가 바뀐다. 기준일과의 실제 날짜 관계로 `(다음 회차)` / `(지난 회차)`를 구분한다.
- 이 요약을 담은 시트(교사 허브·시간표 셀 상세)는 `AnimatedBuilder`로 컨트롤러를 구독한다. 그러지 않으면 시트 위에서 회차를 저장하고 돌아왔을 때 옛 스냅샷이 남아 "저장이 안 됐다"로 보인다.
- 진입점 4곳: 관리자 시간표 수업 설정 다이얼로그, 시간표 셀 읽기 전용 상세, 교사 허브 수업 상세, 학기 설정 → 과목 관리의 과목 수정 다이얼로그. 학생·학부모 시간표 셀 상세에는 읽기 전용으로 붙는다.
- 회차 내용은 세션 id가 필요 없으므로 **아직 커밋되지 않은(tmp) 드래프트 세션에서도** 바로 입력할 수 있다.

**시드**: `scripts/seed_joy_qt_lessons.mjs` — JOY 화요일 전교생 모임의 2026 가을 진도표(9/1 개강예배 ~ 12/15) 14회차. 충돌 시 기본은 `do nothing`이라 **이미 있는 회차는 건드리지 않는다** — 앱에서 선생님이 고친 내용을 하드코딩 배열이 되돌리면 안 되기 때문이다(되돌리려면 `--overwrite`). `--apply` 없이 돌리면 미리보기만 출력한다. 실제 학생·교사 이름이 들어 있어 `.gitignore`의 `scripts/*joy*` 규칙에 걸리는 **로컬 스크립트**다(커밋되지 않는다).

### 6.21 학기 기본 선택과 학기별 스코핑 (2026-08)

**기본 학기 선택** (`defaultTermForToday`, `nest_models.dart`)

순서: ① 현재 학기 → ② 45일 이내로 다가오는 학기 → ③ 이미 시작한 학기 중 가장 최근 → ④ 가장 이른 예정 학기.

- ②가 없던 시절, 학기 사이 공백에서는 항상 "방금 끝난 학기"가 선택됐다. 짧은 방학에는 맞지만 **개학 직전에는 틀린다** — 2026-08-25(개학 7일 전)에 7월 31일 종료된 학기가 열렸고, 지난 학기는 읽기 전용이라 시간표 셀을 눌러도 반응이 없어 신규 기능이 통째로 없는 것처럼 보였다. `termLookaheadDays = 45`가 그 구간을 메운다. 원래 규칙(빈 미래 학기로 튀지 않는다 — "예승 버그")은 회귀 테스트로 그대로 지킨다.
- ①에서 **기간이 겹치는 현재 학기가 여럿이면 먼저 끝나는 쪽**을 고른다. 다음 학기 시작일을 앞 학기 종료일보다 이르게 만들어 두는 실수가 흔한데(JOY: 2027 가을 11-26 시작 vs 2026 가을 11-30 종료), 목록 순서에 기대면 반이 하나도 없는 학기로 학기 중에 튄다.

**학기별 스코핑 — 무엇이 학기에 매달려 있고 무엇이 아닌가**

| 학기 종속 | 홈스쿨 종속(학기마다 재사용) |
|---|---|
| `class_groups`, `time_slots`, `classrooms`, `class_sessions` | `courses`, `teacher_profiles`, `families`, `children` |

- `courses`는 `unique (homeschool_id, name)`, `teacher_profiles`도 홈스쿨 단위다. **재사용이 정상**이므로 `term_id`를 붙이면 안 된다 — 같은 과목을 학기마다 복제하게 되고 `course_lessons`가 학기 경계에서 갈라진다.
- 대신 화면에서 "이 학기에 실제로 쓰는 것"으로 걸러 준다: `NestController.courseIdsInSelectedTerm` / `teacherIdsInSelectedTerm`이 학기 전체 시간표(`allTermSessions`, `allTermSessionTeacherAssignments`)에서 뽑는다. 학기 설정의 과목·선생님 카드는 `이 학기 / 전체` 칩을 달고 기본은 이 학기다.
- **시간표 팔레트는 일부러 걸러지지 않는다.** 새 학기를 짤 때는 전체 카탈로그가 필요하고, 초안 세션은 아직 커밋 전이라 "사용중" 판정에 잡히지 않아 방금 배치한 과목이 목록에서 사라지는 역효과가 난다.
- 학기 시간표가 비어 있으면(신학기 세팅) 좁힐 대상이 없으므로 자동으로 전체를 보여준다. 빈 화면에 갇히지 않게 하는 안전장치다.

**삭제 가드는 반이 아니라 학기 전체를 본다**

과목 삭제 가드가 `controller.sessions`(선택된 반 하나)만 보면, 다른 반이 쓰는 과목에도 삭제 버튼이 열리고 DB의 `on delete restrict`가 뒤늦게 막으면서 영문 FK 오류가 화면에 뜬다. `courseIdsInSelectedTerm`으로 막고, 다른 학기가 쓰는 경우의 `23503`은 한국어로 변환한다. 그리고 `course_lessons`는 `on delete cascade`라 과목과 함께 조용히 지워지므로, 확인 문구에 회차 손실 건수를 반드시 노출한다.

### 6.22 모바일 네이티브 셸 · 역할별 부트 · 푸시 리마인더 (2026-09)

모바일(폭 < 1080)은 웹 카드 프레임을 벗고 `creamyWhite` 풀블리드 + `IndexedStack` 탭 유지를 쓴다. 헤더에 알림 벨이 있고, 전역 오버레이는 `NestController.blocksUi`일 때만 뜬다(캐시 히트 후 백그라운드 갱신은 화면을 막지 않는다).

**역할별 부트** (`_loadRoleScopedContext` / `_loadDeferredContext`)

- 시작 시: 학기·반·세션·아이/배정·공지·학사일정·알림함. 관리자만 가입/초대/아이등록 카운트.
- 탭 진입 시: 커뮤니티(`ensureCommunityFeed`), 갤러리(`ensureGalleryItems`). 감사로그·자습·교수계획·활동기록은 교사/관리자 지연 로드.

**푸시**

- 클라이언트: `NestPush`가 `initLionFirebase` + `LionMessagingController.registerPush`로 `push_tokens`에 등록. 미설정이면 no-op.
- 도메인 이벤트: `nest-notify` `dispatch()`가 SMS와 병행해 FCM을 보낸다(`CLASS_CHANGE`, `ABSENCE`). `lion-notify`는 벤더라 수정하지 않고 `_shared/fcm.ts`에 전송 로직을 복사했다.
- 인박스: `notification_log`의 `event_type` / `title` / `body` / `payload`. 벨에서 열어 시간표/홈으로 보낸다.

**리마인더** (`nest-remind`, 마이그레이션 `20260908120000_schedule_reminders.sql`)

- 아침 07:30 KST `MORNING_DIGEST`: 학부모·학생·교사에게 오늘 수업 요약. 수업 0개면 미발송. 방해금지 존중.
- 수업 30분 전 `CLASS_REMINDER`: 시작이 now+25~35분인 세션. 학생+보호자+담당 교사. 방해금지여도 발송.
- 주간 템플릿 + `class_session_changes`를 서버에서 해석한다. `CANCELED` 스킵, `TIME_MOVED`는 새 교시 시각.
- 중복 방지: `schedule_reminder_sends`. 설정: `notification_prefs.morning_digest_enabled` / `class_reminder_enabled`.
- 호출은 `x-cron-secret == NEST_CRON_SECRET`. `verify_jwt = false`. pg_cron이 없으면 `.github/workflows/nest_remind.yml`이 백업한다.
- 리마인더는 푸시만 보낸다. 문자는 수업변경·결석만.

순수 해석 로직은 `frontend/lib/src/services/schedule_occurrence.dart` (단위 테스트 `test/schedule_occurrence_test.dart`).

### 6.23 개인 일정 · 학기 달력 · Google Calendar (2026-09)

학기 시간표는 요일×교시 템플릿이라 날짜가 있는 일정을 담지 못했다. 두 계층을 겹쳐 보여 준다.

- **학사일정** (`academic_events`): 관리자/스태프가 학기 중간 행사·휴일·현장학습을 올린다. `kind` / 선택 시각 / `show_on_timetable`. `publish_announcement=true`(기본)면 트리거가 `[학사일정] 제목` 공지를 만들거나 맞춘다. 소식 탭 달력·주간 시간표 요일 헤더·학부모/학생 홈에 보인다.
- **개인 일정** (`personal_events`): 학부모(자녀)와 학생 본인만 CRUD. 교시와 시간이 겹치면 칸에 같이 보이고, `PRIORITIZE_PERSONAL`이면 수업을 흐리게 한다. 공식 결석 신고는 아니다.
- **학기 달력** (`TermCalendarView`): 월 격자 + 수업(로즈)/학사(클레이)/개인(세이지) 점. 날을 누르면 세 계층이 한 시트에 나온다. 학부모·학생 시간표의 `달력` 세그먼트, 관리자 소식의 학사일정 섹션 상단.
- **주 이동**: 주간 보드는 선택한 주의 실제 날짜를 헤더에 찍고, 그 날짜 기준으로 개인/학사 겹침을 계산한다. 빈 칸을 누르면 그 교시에 개인 일정을 넣을 수 있다.
- **Google Calendar**: 사용자별 `calendar_integrations`(토큰은 Edge Function만). 웹은 기존 Drive 콜백(`intent=calendar`), 앱은 `google-calendar-oauth` GET 리다이렉트. 동기화는 Nest 개인·학사 일정을 밀고, `[둥지]`가 아닌 Google 일정을 개인 일정으로 가져온다. Google Cloud에 `GOOGLE_CALENDAR_REDIRECT_URI`를 등록해야 앱 연결이 된다.

마이그레이션 `20260911120000_personal_events_and_calendar.sql`. 겹침 계산은 `schedule_overlap.dart`.

## 7. Database and RLS Notes

### 7.1 Core Membership Security

- `homeschool_memberships` insert/update/delete is admin-gated by RLS (`HOMESCHOOL_ADMIN`).
- App-level enforcement adds additional UX/guardrails (e.g., last admin protection), but DB RLS remains the source of truth.

### 7.2 Community Moderation Tables

Migration `20260303060000_community_sns.sql` includes:

- `community_posts` (with `is_hidden`, `is_pinned`, hidden metadata)
- `community_post_media`
- `community_post_comments`
- `community_post_reactions`
- `community_reports`

RLS summary:

- Members can read community content for their homeschool.
- Members can create posts/comments/reactions/report.
- Admin/Staff can moderate reports and post visibility/pinning/deletion.

### 7.3 Invite Table and RPC

Migration `20260303130000_homeschool_invites.sql` includes:

- `homeschool_invites` table (`PENDING`, `ACCEPTED`, `CANCELED`, `EXPIRED`)
- partial unique index preventing duplicate pending invites per homeschool/email/role
- `accept_homeschool_invite(token)` security-definer RPC:
  - auth/email verification
  - expiry check
  - membership upsert to `ACTIVE`
  - invite transition to `ACCEPTED`

Migration `20260303143000_children_policy_fix.sql`:

- children insert/update RLS check hardened for admin/staff membership join path

Migration `20260303145000_child_admin_rpc.sql`:

- `create_child_admin` RPC for stable admin/staff child creation flow

Migration `20260303150000_invite_rpc_fix.sql`:

- `accept_homeschool_invite` return signature fix to avoid output-variable collision

Migration `20260303162000_class_groups_delete_and_member_search.sql`:

- `class_groups` delete RLS policy for admin/staff
- `search_homeschool_members` security-definer RPC for account lookup by name/email/UUID

Migration `20260303190000_member_unavailability_blocks.sql`:

- `member_unavailability_blocks` table for teacher/parent unavailable time ranges
- owner kind split:
  - `TEACHER_PROFILE` (teacher profile scoped)
  - `MEMBER_USER` (parent account scoped)
- RLS:
  - member read access
  - admin/staff full management
  - owner self-management (teacher profile owner or parent user owner)
- update trigger: `set_updated_at()`

Migration `20260308201000_family_child_delete_policies.sql`:

- adds `families_delete_admin_staff` RLS policy
- adds `children_delete_admin_staff` RLS policy
- enables admin/staff delete flows used by family/child management dialogs

Migration `20260308223000_courses_delete_policy.sql`:

- adds `courses_delete_admin_staff` RLS policy
- enables admin/staff course delete flow (while keeping FK protection for in-use courses)

Migration `20260308233000_classrooms.sql`:

- adds `classrooms` table (`term_id`, `name`, `capacity`, `note`)
- adds `classrooms_*` RLS policies for member read and admin/staff CRUD
- enables term-level classroom resource management linked to timetable location assignment

Migration `20260308235500_family_guardians_delete_policy.sql`:

- adds `family_guardians_delete_admin_staff` RLS policy
- enables guardian unlink (`family_guardians` delete) from family management UI

Migration `20260309003000_homeschool_join_requests_and_directory.sql`:

- adds `homeschool_join_requests` table (`PENDING`, `APPROVED`, `REJECTED`, `CANCELED`)
- adds RLS for requester self-read/insert and admin/staff moderation
- adds `search_homeschool_directory(query, limit)` security-definer RPC
- enables authenticated non-members to discover homeschools and request joining without loosening `homeschools` base RLS

Migration `20260309011500_homeschool_invites_name_snapshot.sql`:

- adds `homeschool_invites.homeschool_name` snapshot column
- backfills existing invite rows with homeschool names
- adds triggers to keep invite name synced on invite insert/home rename
- fixes no-membership invite list showing `Unknown Homeschool` when relation join is blocked by RLS

Migration `20260309020000_teacher_profiles_delete_policy.sql`:

- adds `teacher_profiles_delete_admin_staff` RLS policy
- enables teacher delete flow used by schedule palette quick actions

### 7.4 Student Isolation (2026-08)

`STUDENT` 역할을 추가하면서 가정 데이터 3개 테이블의 SELECT 정책을 다시 만들었다 (`20260814091000_student_accounts.sql`).

**기존 5개 역할의 가시성은 그대로다.** 원래 술어는 `is_*_member(...)` = "그 홈스쿨의 ACTIVE 구성원"이었고, `STUDENT` 추가 이전에는 `membership_role`에 정확히 5개 값만 있었으므로 그 5개를 나열한 `has_*_role(...)`은 원래 술어와 동치다. 좁아진 것은 STUDENT 뿐이다.

| 테이블 | 이전 술어 | 현재 술어 |
|---|---|---|
| `children` | `is_child_member(id)` | `is_child_self(id)` OR `is_child_guardian(id)` OR `has_child_role(id, [5개 역할])` |
| `families` | `is_homeschool_member(homeschool_id)` | `is_family_of_current_user(id)` OR `has_homeschool_role(homeschool_id, [5개 역할])` |
| `family_guardians` | `is_family_member(family_id)` | `user_id = auth.uid()` OR `is_family_of_current_user(family_id)` OR `has_family_role(family_id, [5개 역할])` |

- **RESTRICTIVE 정책은 쓰지 않는다.** 다른 permissive 정책과 AND로 묶여 관리자 조회가 깨진다. 전부 permissive OR 술어여야 한다.
- 시간표 계열(`class_sessions` / `time_slots` / `class_groups` / `class_enrollments`)은 **기존대로 전교 공개를 유지**한다. 학생도 시간표는 그대로 본다.
- `children`의 INSERT/UPDATE/DELETE 정책은 손대지 않았다.
- 신규 헬퍼: `is_child_self` / `is_child_guardian` / `is_family_of_current_user` / `current_user_child_ids`.
- 수신자 해석 RPC(§6.18)를 `authenticated`가 아닌 `service_role`에만 부여하는 이유가 여기에 있다 — security definer 함수가 반 전체 계정 uuid를 돌려주므로, 클라이언트에 열면 이 격리가 무의미해진다.

### 7.5 `RETURNS TABLE` 42702 함정 (재발 주의)

`returns table (user_id uuid, ...)`는 `user_id`를 OUT 파라미터(=변수)로 만들기 때문에, 본문에서 같은 이름을 미한정으로 참조하면 `42702 ambiguous column reference`가 난다. 이 레포에서 이미 두 번 재발했다(`20260709120000`, `20260709130000`).

**규칙: 모든 `RETURNS TABLE` plpgsql 함수는 본문 첫 줄에 `#variable_conflict use_column`을 넣고 지역변수에 `v_` 접두사를 쓴다.** 적용 대상: `request_join_with_code`, `recipients_for_class_session`, `recipients_for_absence_report`.

### 7.6 Schedule reminders (2026-09)

Migration `20260908120000_schedule_reminders.sql`:

- `notification_prefs.morning_digest_enabled` / `class_reminder_enabled` (default true)
- `notification_log.event_type` / `title` / `body` / `payload` — 인박스와 리마인더 로그가 같은 행을 쓴다
- `schedule_reminder_sends` — 아침 요약은 `(event_type, occurrence_date, user_id)`, 수업 리마인더는 여기에 `class_session_id`를 더해 unique. 클라이언트 RLS는 막고 Edge Function(service role)만 기록한다
- `pg_cron` + `pg_net`이 있으면 5분(`CLASS_REMINDER`) / 22:30 UTC=`07:30` KST(`MORNING_DIGEST`). 확장이 없으면 마이그레이션이 조용히 건너뛰고 `.github/workflows/nest_remind.yml`이 백업한다

### 7.7 Personal events and calendar (2026-09)

Migration `20260911120000_personal_events_and_calendar.sql`:

- `personal_events` — 자녀 단위 날짜 일정. RLS는 보호자(`is_child_guardian`)와 학생 본인(`is_child_self`)만. 관리자/교사는 남의 개인 일정을 보지 않는다
- `calendar_integrations` — 사용자별 Google 토큰. authenticated 는 상태 컬럼만 SELECT. 쓰기는 Edge Function(service role)
- `academic_events` — `kind`, `start_time`, `end_time`, `publish_announcement`, `announcement_id`, `show_on_timetable`. 쓰기는 ADMIN/STAFF. 공지 동기화는 `sync_academic_event_announcement` 트리거

### 7.8 Term schedule pack (2026-09)

Migration `20260912020000_term_schedule_pack.sql`:

- `fetch_term_schedule_pack(term_id)` — 학기 전체 활성 세션 + 교사 배정을 jsonb 한 번에. `is_term_member` 가드, security definer
- 인덱스 `idx_class_sessions_group_active`, `idx_academic_events_school_term`

## 8. Environment Variables

Required `dart-define` values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional auth redirect overrides:

- `AUTH_EMAIL_REDIRECT_URL` (web, default: `https://lionandthelab.github.io/nest/`)
- `AUTH_EMAIL_REDIRECT_URL_MOBILE` (android/ios, default: `com.lionandthelab.nest://login-callback/`)

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Edge Function 시크릿 (`supabase secrets set`, 프론트엔드에는 절대 넣지 않는다):

- `SOLAPI_API_KEY` / `SOLAPI_API_SECRET` — Solapi 인증 (nest-notify, lion-notify 공용)
- `SOLAPI_SENDER` — 등록된 발신번호. 없으면 nest-notify가 500으로 거절한다.
- `SOLAPI_PFID` — 카카오 발신프로필. **알림톡으로 전환할 때만** 필요하며, 미설정 상태에서 `channel`을 `alimtalk`/`auto`로 부르면 400으로 거절된다(문자 발송에는 영향 없음).
- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` — Supabase가 자동 주입한다.
- `FCM_SERVICE_ACCOUNT` / `FCM_PROJECT_ID` — `nest-notify`·`nest-remind` 푸시. 없으면 푸시는 no-op이고 문자는 그대로 나간다.
- `NEST_CRON_SECRET` — `nest-remind`가 `x-cron-secret`과 비교한다. GitHub Actions 백업 워크플로(`.github/workflows/nest_remind.yml`)에도 같은 값을 넣는다.

## 9. Build, Test, and Deploy

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /nest/
flutter build appbundle --release
flutter build ios --release --no-codesign
```

- GitHub Pages workflow: `.github/workflows/flutter_web_pages.yml`
- Artifact: `frontend/build/web` to `gh-pages`
- Remote integration workflow: `.github/workflows/remote_e2e.yml`
- Schedule reminder backup: `.github/workflows/nest_remind.yml` (`SUPABASE_URL`, `NEST_CRON_SECRET`)
  - workflow condition guards use `env.*` (not direct `secrets.*` in `if`) to avoid GitHub Actions workflow validation failures.
  - `scripts/e2e_remote.mjs` callback file validation is repo-root relative to run on both local and CI environments.

## 10. OAuth Redirect URI

Keep Google Console redirect URI and Supabase `GOOGLE_REDIRECT_URI` aligned:

- Local: `http://localhost:8080/oauth/google/callback.html`
- GitHub Pages: `https://lionandthelab.github.io/nest/oauth/google/callback.html`

Supabase Auth redirect URLs for app login/signup/password reset:

- Web: `https://lionandthelab.github.io/nest/`
- Mobile deep link: `com.lionandthelab.nest://login-callback/`
- Mobile Naver browser callback: HTTPS `naver-oauth-bridge` → `nestnaverlogin://callback`

## 11. Operational Rules

- Never expose `service_role` in frontend.
- Keep token access restricted to admin RLS scopes.
- Keep edge function JWT/user checks enabled.
- Update this file whenever architecture-affecting code changes are introduced.

## 12. Mobile Release Readiness

- Android release network access enabled in main manifest (`INTERNET` permission).
- Android package/application id unified to `com.lionandthelab.nest`.
- Android deep link intent filter added for Supabase auth callback:
  - scheme: `com.lionandthelab.nest`
  - host: `login-callback`
- iOS bundle id unified to `com.lionandthelab.nest`.
- iOS URL type added for Supabase auth callback scheme `com.lionandthelab.nest`.
- Login page now uses empty credential fields (no seeded account/password in production build).
- Login page includes password reset email request flow.
- Android release signing:
  - if `android/key.properties` exists, release signing config is used
  - otherwise build falls back to debug signing for local verification
