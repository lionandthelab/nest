import { createAdminClient } from "./supabase.ts";

export type CalendarRow = {
  id: string;
  user_id: string;
  homeschool_id?: string | null;
  google_access_token: string | null;
  google_refresh_token: string | null;
  google_token_expires_at: string | null;
  calendar_id: string | null;
};

export const CALENDAR_APP_INTENT = "calendar_app";

export async function refreshCalendarToken(
  admin: ReturnType<typeof createAdminClient>,
  row: CalendarRow
): Promise<string | null> {
  let access = row.google_access_token;
  const expiresAt = row.google_token_expires_at;
  const stillFresh =
    expiresAt && new Date(expiresAt).getTime() - Date.now() > 2 * 60 * 1000;
  if (access && stillFresh) return access;
  if (!row.google_refresh_token) return access;

  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
  if (!clientId || !clientSecret) return access;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: row.google_refresh_token,
      grant_type: "refresh_token",
    }),
  });
  if (!tokenRes.ok) return access;

  const json = await tokenRes.json();
  access = json.access_token as string | undefined;
  if (!access) return row.google_access_token;

  const expiresIn = Number(json.expires_in || 3600);
  await admin
    .from("calendar_integrations")
    .update({
      google_access_token: access,
      google_token_expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
    })
    .eq("id", row.id);

  return access;
}

/// Google Cloud 콘솔에 등록된 단일 리디렉션 URI(callback.html)를 웹/앱 공통으로 사용한다.
export function calendarRedirectUri(_mode?: string) {
  return Deno.env.get("GOOGLE_REDIRECT_URI") || "";
}

export function calendarOauthFunctionUrl() {
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/google-calendar-oauth`;
}

export function calendarFeedUrl(token: string) {
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/google-calendar-oauth?token=${encodeURIComponent(token)}`;
}

export function calendarGoogleSubscribeUrl(token: string) {
  const httpsUrl = calendarFeedUrl(token);
  const webcalUrl = httpsUrl.replace(/^https?:\/\//i, "webcal://");
  return `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(webcalUrl)}`;
}

export function calendarDonePageUrl(ok: boolean, reason?: string) {
  const base = Deno.env.get("NEST_WEB_ORIGIN") || "https://nestapp.life";
  const params = new URLSearchParams({
    status: ok ? "ok" : "error",
    target: "calendar",
  });
  if (reason) params.set("reason", reason.slice(0, 200));
  return `${base}/oauth/google/connected.html?${params.toString()}`;
}

export function encodeState(payload: Record<string, unknown>) {
  return btoa(JSON.stringify(payload))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export function decodeState(state: string) {
  const normalized = state.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return JSON.parse(atob(padded)) as Record<string, unknown>;
}
