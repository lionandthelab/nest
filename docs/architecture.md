# Nest Flutter Architecture

Last updated: 2026-03-08

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
- Membership onboarding via email invite:
  - admin invite create/cancel
  - invited user self-accept from dashboard
- Prompt timetable generation plus manual drag-and-drop editing.
- Questionnaire-based schedule concierge with multiple draft options and live conflict checks.
- Google Drive based media upload and gallery sharing.

## 2. System Overview

- Frontend: Flutter (`frontend/`)
- Backend: Supabase
  - Auth: email/password
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
        tabs/
          dashboard_tab.dart
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
```

## 4. Role Model and View Switching

### 4.1 Membership Roles

- `HOMESCHOOL_ADMIN`
- `STAFF`
- `TEACHER`
- `GUEST_TEACHER`
- `PARENT`

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
  - `fetchFamilies`, `createFamily`
  - `createCourse`, `deleteCourse`
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

1. Sign in/up via `Supabase.auth`.
2. Load active memberships (`homeschool_memberships`) for current user.
3. Resolve current homeschool and view role.
4. Load dependent context:
  - terms, class groups
  - timetable assets and sessions
  - drive integration
  - gallery items
  - community feed (+ reports for admin/staff)

Admin dashboard onboarding:

- step-by-step setup roadmap cards with completion checks
  - 1) family/child setup
  - 2) class + child enrollment
  - 3) course preparation and class assignment path
  - 4) timetable generation/adjustment
- direct tab jump actions from roadmap (`Term Setup`, `Schedule`)

### 6.2 Timetable

- Admin view:
  - simple `AI 배정` chat input (single prompt) that generates a local draft for current class
  - inline help tooltip/dialog for AI prompt examples and save flow guidance
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
    - room palette add/remove for quick reuse
  - room utilization export:
    - all-class board by day/period showing room assignment status
    - export to PNG from `장소 상황표 내보내기`
- Parent/Teacher view:
  - read-only schedule visibility (editing hidden/disabled)
  - visual session cards with icon rows for course/time/teacher/room scanning.

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
  - shared child context via `child_selector_header.dart`
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
- Parent child selector (`child_selector_header.dart`)
  - child switching uses searchable selector sheet for large sibling lists
- Shared objective:
  - reduce initial setup friction in large homeschool contexts
  - keep one-tap edit flow while preserving existing backend model
- Both hubs use:
  - card-first layout with low cognitive load
  - section switching through `ChoiceChip` controls
  - animated section swap for continuity

### 6.5 Motion and Loading System

- Global state transition animation
  - `NestAppRoot`: animated switch between bootstrap/login/home
- Main workspace transition animation
  - `HomePage._MainPanel`: animated tab content replacement (`fade + slide`)
- Busy/Loading feedback
  - `NestLoadingScreen`: branded warm loading scene
  - `NestBusyOverlay`: modal-style smooth busy overlay during mutations
- Login interaction animation
  - sign-in/sign-up mode change animates confirm-password field expansion/collapse

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

### 6.8 Invite Acceptance (Dashboard)

- `Dashboard` renders pending invites matched to logged-in email.
- Accept flow:
  1. user clicks `초대 수락`
  2. app calls `accept_homeschool_invite` RPC
  3. DB activates `homeschool_memberships` row
  4. controller reloads memberships/context and role tabs

### 6.9 Family and Enrollment Admin

- `family_admin_tab.dart`:
  - term setup workspace with unit-level sections:
    - family (family card management + child card management with unified edit dialogs)
    - family/child edit dialogs include delete actions with confirmation guardrails
    - teacher (teacher profile edit + account link/unlink + unavailability in one modal)
    - class (class cards + unified class create/edit modal)
    - class modal supports:
      - class create/update/delete
      - child assignment in the same modal with multi-select
    - course (course create/delete and duration)
  - setup progress bar + unit chips for direct switching
- `parent_timetable_tab.dart`:
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

## 8. Environment Variables

Required `dart-define` values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## 9. Build, Test, and Deploy

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /nest/
```

- GitHub Pages workflow: `.github/workflows/flutter_web_pages.yml`
- Artifact: `frontend/build/web` to `gh-pages`
- Remote integration workflow: `.github/workflows/remote_e2e.yml`
  - workflow condition guards use `env.*` (not direct `secrets.*` in `if`) to avoid GitHub Actions workflow validation failures.
  - `scripts/e2e_remote.mjs` callback file validation is repo-root relative to run on both local and CI environments.

## 10. OAuth Redirect URI

Keep Google Console redirect URI and Supabase `GOOGLE_REDIRECT_URI` aligned:

- Local: `http://localhost:8080/oauth/google/callback.html`
- GitHub Pages: `https://lionandthelab.github.io/nest/oauth/google/callback.html`

## 11. Operational Rules

- Never expose `service_role` in frontend.
- Keep token access restricted to admin RLS scopes.
- Keep edge function JWT/user checks enabled.
- Update this file whenever architecture-affecting code changes are introduced.
