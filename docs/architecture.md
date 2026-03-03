# Nest Flutter Architecture

Last updated: 2026-03-03

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
        tabs/
          dashboard_tab.dart
          parent_hub_tab.dart
          teacher_hub_tab.dart
          timetable_tab.dart
          gallery_tab.dart
          community_feed_tab.dart
          community_tab.dart
          members_tab.dart
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

### 4.3 Dynamic Tab Composition

Tabs are built dynamically in `HomePage._buildTabs`:

- Always: `Dashboard`, `Timetable`, `Gallery`
- Parent role: `Parent Hub`
- Teacher/GUEST_TEACHER role: `Teacher Hub`
- Non-admin: `Community` (user feed)
- Admin/Staff: `SNS Admin` (moderation)
- HOMESCHOOL_ADMIN only: `Drive`, `Members`

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

### 5.2 `NestRepository`

- Encapsulates Supabase table access and function invocation.
- Key role APIs:
  - `fetchMemberships(userId)`
  - `fetchHomeschoolMemberships(homeschoolId)`
  - `grantMembershipRole(homeschoolId, userId, role)`
  - `revokeMembershipRole(homeschoolId, userId, role)`
  - `fetchHomeschoolInvites(homeschoolId)`
  - `createHomeschoolInvite(...)`
  - `cancelHomeschoolInvite(inviteId)`
  - `acceptHomeschoolInvite(inviteToken)`

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

### 6.2 Timetable

- Admin view:
  - prompt generation + apply/discard proposals
  - drag-and-drop manual board edits
- Parent/Teacher view:
  - read-only schedule visibility (editing hidden/disabled)

### 6.3 Community

- User Feed (`community_feed_tab.dart`)
  - create post (text + optional media)
  - like, comment
  - report post (category + detail)
- Admin Moderation (`community_tab.dart`)
  - moderation metrics
  - open report queue and status resolution
  - post hide/unhide, pin/unpin, delete

### 6.4 Membership and Permission Admin

- `members_tab.dart` (HOMESCHOOL_ADMIN only):
  - grant role to target `auth.users.id`
  - revoke specific role
  - guardrail: cannot remove last remaining `HOMESCHOOL_ADMIN`
  - invite by email with role pre-assignment
  - pending invite cancellation

### 6.5 Drive and Gallery

- OAuth start/complete through edge functions and web bridge.
- Upload flow:
  1. create `media_upload_sessions`
  2. upload to Drive via edge function
  3. insert `media_assets` and optional child tagging
  4. show in gallery and community attachments

### 6.6 Invite Acceptance (Dashboard)

- `Dashboard` renders pending invites matched to logged-in email.
- Accept flow:
  1. user clicks `초대 수락`
  2. app calls `accept_homeschool_invite` RPC
  3. DB activates `homeschool_memberships` row
  4. controller reloads memberships/context and role tabs

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

## 10. OAuth Redirect URI

Keep Google Console redirect URI and Supabase `GOOGLE_REDIRECT_URI` aligned:

- Local: `http://localhost:8080/oauth/google/callback.html`
- GitHub Pages: `https://lionandthelab.github.io/nest/oauth/google/callback.html`

## 11. Operational Rules

- Never expose `service_role` in frontend.
- Keep token access restricted to admin RLS scopes.
- Keep edge function JWT/user checks enabled.
- Update this file whenever architecture-affecting code changes are introduced.
