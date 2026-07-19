# Mobile Release Checklist (Android/iOS)

Last updated: 2026-07-19

## 0) Fastlane 배포 (권장)

수동 Xcode/콘솔 업로드 대신 fastlane 레인으로 배포한다. 인증은 전부
비대화식(App Store Connect API 키 / Play 서비스 계정)이다.

### 1회 사전 준비

- **iOS**: `frontend/ios/fastlane/.env` 작성 — `.env.example` 참고
  (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `FASTLANE_TEAM_ID`).
- **Android**: `frontend/android/fastlane/.env`에 `GOOGLE_PLAY_JSON_KEY`
  (Play 서비스 계정 JSON 경로) 지정 + `frontend/android/key.properties`
  (업로드 키 서명, 아래 §7) 배치.
- 두 `.env`와 `key.properties`는 gitignore 되어 있다 — 절대 커밋 금지.

### 릴리스 절차

1. `frontend/pubspec.yaml`의 `version: X.Y.Z+BUILD`에서 **BUILD를 올린다**
   (스토어 업로드마다 필수 — 레인이 스토어 최신 번호와 비교해 검증한다).
2. iOS — `cd frontend/ios`:
   - `fastlane ios status` — pubspec vs TestFlight/App Store 버전 확인
   - `fastlane ios build` — 서명된 릴리스 IPA 빌드만
   - `fastlane ios upload` — 빌드된 IPA를 TestFlight 업로드만
   - `fastlane ios beta` — 빌드 + TestFlight 업로드
   - `fastlane ios release` — 빌드 + 업로드 + **프로덕션 심사 제출**(승인 시 자동 출시)
   - `fastlane ios submit build:N` — 이미 업로드된 빌드 N을 심사 제출만
3. Android — `cd frontend/android`:
   - `fastlane android internal` — 내부 테스트 트랙 업로드
   - `fastlane android production` — **프로덕션 트랙** 업로드(검토 통과 시 즉시 공개)
   - `fastlane android promote` — internal에 올린 빌드를 프로덕션으로 승격

첫 자동화 배포는 `internal`/`beta`로 올려 확인한 뒤 `promote`/`submit`을
권장한다. 이하 §1~§7은 수동 절차 및 스토어 요건 체크리스트다.

## 1) Auth Redirect Setup (Supabase Dashboard)

Add these redirect URLs in Supabase Auth settings:

- `https://lionandthelab.github.io/nest/`
- `com.lionandthelab.nest://login-callback/`

If you use custom values, pass them via `dart-define`:

- `AUTH_EMAIL_REDIRECT_URL`
- `AUTH_EMAIL_REDIRECT_URL_MOBILE`

## 2) Android

Current project state:

- Application ID: `com.lionandthelab.nest`
- Deep link callback:
  - scheme: `com.lionandthelab.nest`
  - host: `login-callback`
- Internet permission: enabled in `main` manifest.

Release signing setup:

1. Create `frontend/android/key.properties`
2. Fill:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

3. Build:

```bash
cd frontend
flutter build appbundle --release
```

Output:

- `frontend/build/app/outputs/bundle/release/app-release.aab`

## 3) iOS

Current project state:

- Bundle ID: `com.lionandthelab.nest`
- URL scheme for auth callback: `com.lionandthelab.nest`

Build for validation (no signing):

```bash
cd frontend
flutter build ios --release --no-codesign
```

For App Store delivery:

1. Open `frontend/ios/Runner.xcworkspace` in Xcode
2. Select Team/Signing for Runner target
3. Archive and upload to TestFlight/App Store Connect

## 4) QA Pass Before Store Upload

- Parent login/signup/password reset
- Teacher login/signup/password reset
- Role switch for multi-role accounts
- Parent child selection + timetable visibility
- Teacher class operation + student status logging
- Community feed read/write
- Gallery upload/open link
- Session persistence after app restart

## 5) Pre-Submission Checklist (Store Requirements)

These items must be confirmed before uploading the build to App Store Connect or Play Console.

### Legal & Privacy
- [ ] Privacy policy hosted at a public URL (e.g. `https://lionandthelab.github.io/nest/privacy`)
- [ ] Terms of service hosted at a public URL (e.g. `https://lionandthelab.github.io/nest/terms`)
- [ ] Support email confirmed active: `contact@lionandthelab.com`
- [ ] Both URLs return HTTP 200 from an external network (not localhost)

### Content Rating
- [ ] Google Play: IARC questionnaire completed (expected result: Everyone)
- [ ] Apple App Store: Age rating set to 4+
- [ ] "Designed for Families" / "Made for Kids" — both left unchecked (adult-facing tool)
- [ ] App description contains no language implying direct child use

### Data Safety / Privacy Labels
- [ ] Google Play Data Safety section filled in (see `docs/app_store_review_guide.md` §2)
- [ ] Apple Privacy Nutrition Labels filled in (see `docs/app_store_review_guide.md` §3)
- [ ] Collected data in labels matches what the app actually collects

### Export Compliance (iOS)
- [ ] `Info.plist` contains `ITSAppUsesNonExemptEncryption = false`
- [ ] App Store Connect export compliance answered: standard HTTPS/TLS only

### Account Deletion (Apple mandatory since 2022)
- [ ] In-app account deletion flow is reachable (Settings → Delete Account)
- [ ] Deletion removes personal data per privacy policy

### Reviewer Test Accounts
- [ ] Three accounts created and tested: admin, parent, teacher
- [ ] Credentials entered in App Store Connect / Play Console review notes
- [ ] Sample homeschool data populated (semester, class, timetable, community post)

### Screenshots & Assets
- [ ] Screenshots match current build UI (no outdated screens)
- [ ] iOS: 6.7" (1290×2796) set uploaded as minimum
- [ ] Android: phone screenshots (1080×1920) + feature graphic (1024×500) uploaded
- [ ] App icon 1024×512 (Play) and 1024×1024 (App Store) confirmed no rounded corners applied manually

## 6) Version Numbering Strategy

Current version: `2.0.0+1` (pubspec.yaml)

### Format
```
version: MAJOR.MINOR.PATCH+BUILD
```

| Segment | When to increment | Example |
|---------|-------------------|---------|
| MAJOR | Breaking redesign or architecture change | 3.0.0 |
| MINOR | New feature or significant UX addition | 2.1.0 |
| PATCH | Bug fix, copy change, minor UI tweak | 2.0.1 |
| BUILD (+N) | Every store upload, even for same version | 2.0.0+2 |

### Rules
- The `+BUILD` number must increase with every upload to App Store Connect or Play Console, even if `MAJOR.MINOR.PATCH` stays the same.
- Never reuse a build number for the same platform. Keep a local log or use CI to auto-increment.
- TestFlight and Production can share the same build number on iOS.
- Google Play internal track, alpha, beta, and production must all use unique version codes.

### Suggested increment log (update this table on each release)

| Date | Version | Build | Platform | Track | Notes |
|------|---------|-------|----------|-------|-------|
| 2026-03-13 | 2.0.0 | 1 | Android + iOS | Internal / TestFlight | Initial store submission |
| 2026-07-19 | 2.0.7 | 8 | iOS | App Store 심사 제출 | fastlane 첫 자동 배포 (Xcode 26.5, 승인 시 자동 출시) |
| 2026-07-19 | 2.0.7 | 8 | Android | Internal | fastlane 첫 자동 배포. 프로덕션은 콘솔 필수 신고 완료 후 promote |

## 7) Signing Configuration Reminders

### Android
- `key.properties` is gitignored — never commit it.
- Store the keystore file (`.jks`) and `key.properties` in a secure location outside the repo (e.g. 1Password, AWS Secrets Manager, or a private CI secret).
- If the upload keystore is lost, Google Play allows a key rotation request — but it requires advance setup via Play App Signing. Enable Play App Signing immediately after first upload.
- Build command for production AAB:

```bash
cd frontend
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

### iOS
- Distribution certificate and provisioning profile must be renewed annually.
- Use Xcode's "Automatically manage signing" for simplicity, or export a manual profile for CI.
- Archive and upload via Xcode Organizer or `xcodebuild`:

```bash
cd frontend
flutter build ios --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
# Then archive in Xcode: Product > Archive > Distribute App
```

- Verify bundle ID is `com.lionandthelab.nest` in both Xcode and App Store Connect before uploading.

### Environment Variables
All sensitive credentials are injected via `--dart-define` at build time. Do not hardcode them in source files. The required keys are:

| Key | Description |
|-----|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key |
| `AUTH_EMAIL_REDIRECT_URL` | Web auth redirect (optional override) |
| `AUTH_EMAIL_REDIRECT_URL_MOBILE` | Mobile deep link redirect (optional override) |

