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

echo "Deploying edge functions..."
supabase functions deploy timetable-assistant-generate --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-upload --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-connect-start --project-ref "$PROJECT_REF"
supabase functions deploy google-drive-connect-complete --project-ref "$PROJECT_REF"

echo "Done."
