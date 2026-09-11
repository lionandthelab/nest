import { createAdminClient } from "./supabase.ts";

export type CalendarRow = {
  id: string;
  user_id: string;
  google_access_token: string | null;
  google_refresh_token: string | null;
  google_token_expires_at: string | null;
  calendar_id: string | null;
};

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

export function calendarRedirectUri(mode: string | undefined) {
  if (mode === "web") {
    return Deno.env.get("GOOGLE_REDIRECT_URI") || "";
  }
  return (
    Deno.env.get("GOOGLE_CALENDAR_REDIRECT_URI") ||
    `${Deno.env.get("SUPABASE_URL")}/functions/v1/google-calendar-oauth`
  );
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
