#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="avursvhmilcsssabqtkx"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required."
  exit 1
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "SUPABASE_SERVICE_ROLE_KEY is required."
  exit 1
fi

if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" || -z "${GOOGLE_REDIRECT_URI:-}" ]]; then
  echo "GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET/GOOGLE_REDIRECT_URI are required."
  exit 1
fi

echo "Setting Edge Function secrets..."
supabase secrets set \
  --project-ref "$PROJECT_REF" \
  SUPABASE_URL="https://${PROJECT_REF}.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" \
  GOOGLE_REDIRECT_URI="$GOOGLE_REDIRECT_URI"

# nest-notify(수업 변경/결석 알림)는 SOLAPI_API_KEY / SOLAPI_API_SECRET /
# SOLAPI_SENDER 시크릿을 사용한다. 이 값들은 lion_auth 메시징 셋업이 관리하므로
# (scripts/lion_auth_setup.mjs 의 messaging 단계, .env 기반) 여기서 다시 설정하지
# 않는다. 아직 등록 전이면 아래를 먼저 실행한다:
#   node scripts/lion_auth_setup.mjs
echo "Deploying edge functions..."
supabase functions deploy timetable-assistant-generate --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-upload --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-connect-start --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-connect-complete --project-ref "$PROJECT_REF"
supabase functions deploy nest-notify --project-ref "$PROJECT_REF"

echo "Done."
