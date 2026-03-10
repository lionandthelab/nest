# Mobile Release Checklist (Android/iOS)

Last updated: 2026-03-10

## 1) Auth Redirect Setup (Supabase Dashboard)

Add these redirect URLs in Supabase Auth settings:

- `https://lionandthelab.github.io/nest/`
- `io.lionandthelab.nest://login-callback/`

If you use custom values, pass them via `dart-define`:

- `AUTH_EMAIL_REDIRECT_URL`
- `AUTH_EMAIL_REDIRECT_URL_MOBILE`

## 2) Android

Current project state:

- Application ID: `io.lionandthelab.nest`
- Deep link callback:
  - scheme: `io.lionandthelab.nest`
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

- Bundle ID: `io.lionandthelab.nest`
- URL scheme for auth callback: `io.lionandthelab.nest`

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

