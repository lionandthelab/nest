# Nest Supabase Edge Functions

## 포함된 함수

- `timetable-assistant-generate`
- `google-drive-upload`
- `google-drive-connect-start`
- `google-drive-connect-complete`

## 필요한 Secrets

```bash
supabase secrets set \
  SUPABASE_URL="https://avursvhmilcsssabqtkx.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>" \
  GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>" \
  GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>" \
  GOOGLE_REDIRECT_URI="<GOOGLE_REDIRECT_URI>"
```

## 배포 예시

```bash
supabase functions deploy timetable-assistant-generate --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-upload --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-connect-start --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-connect-complete --project-ref avursvhmilcsssabqtkx
```

## 주의

- `google-drive-upload`는 `drive_integrations.google_access_token`이 저장되어 있어야 동작합니다.
- Access token 만료 시 refresh token + Google client secret으로 자동 갱신을 시도합니다.
