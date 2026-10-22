import { corsHeaders } from "../_shared/cors.ts";
import {
  calendarDonePageUrl,
  calendarFeedUrl,
  calendarGoogleSubscribeUrl,
  calendarRedirectUri,
  encodeState,
} from "../_shared/google_calendar.ts";
import { createAdminClient, json, requireUser } from "../_shared/supabase.ts";

function generateFeedToken(userId: string): string {
  const random = crypto.randomUUID().replaceAll("-", "");
  const prefix = userId.replaceAll("-", "").slice(0, 12);
  return `${prefix}_${random}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, corsHeaders);
    }

    const admin = createAdminClient();
    const user = await requireUser(req, admin);
    const payload = (await req.json()) as {
      homeschool_id?: string;
      redirect_mode?: string;
    };

    if (!payload.homeschool_id) {
      return json(400, { error: "homeschool_id is required" }, corsHeaders);
    }

    // 기존에 오염된 OAuth 스코프(calendar.events 등)가 있다면 Google에서 먼저 revoke하여
    // 같은 클라이언트를 쓰는 Google Drive 연결에서 "확인되지 않은 앱" 경고가 뜨지 않게 한다.
    const { data: existing } = await admin
      .from("calendar_integrations")
      .select("calendar_id, google_refresh_token, google_access_token")
      .eq("user_id", user.id)
      .maybeSingle();

    const oldToken =
      (existing?.google_refresh_token as string | null) ||
      (existing?.google_access_token as string | null);
    if (oldToken && !String(existing?.calendar_id || "").startsWith("feed:")) {
      try {
        await fetch("https://oauth2.googleapis.com/revoke", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ token: oldToken }),
        });
      } catch (_) {
        // best-effort
      }
    }

    const existingCalId = String(existing?.calendar_id || "");
    const feedToken = existingCalId.startsWith("feed:")
      ? existingCalId.slice(5)
      : generateFeedToken(user.id);

    const nowIso = new Date().toISOString();
    const { error: upsertErr } = await admin.from("calendar_integrations").upsert(
      {
        user_id: user.id,
        homeschool_id: payload.homeschool_id,
        provider: "GOOGLE",
        status: "CONNECTED",
        google_email: user.email || null,
        google_access_token: null,
        google_refresh_token: null,
        google_token_expires_at: null,
        oauth_scope: "ical_feed",
        calendar_id: `feed:${feedToken}`,
        last_synced_at: nowIso,
      },
      { onConflict: "user_id" }
    );

    if (upsertErr) {
      return json(400, { error: upsertErr.message }, corsHeaders);
    }

    const state = encodeState({
      homeschool_id: payload.homeschool_id,
      user_id: user.id,
      intent: "calendar",
      ts: Date.now(),
    });

    const isWeb = payload.redirect_mode === "web";
    const redirectUri = calendarRedirectUri(payload.redirect_mode);
    const authUrl = isWeb && redirectUri
      ? `${redirectUri}?code=instant_feed&state=${encodeURIComponent(state)}`
      : calendarDonePageUrl(true);

    return json(
      200,
      {
        connected: true,
        auth_url: authUrl,
        feed_url: calendarFeedUrl(feedToken),
        google_subscribe_url: calendarGoogleSubscribeUrl(feedToken),
        state,
      },
      corsHeaders
    );
  } catch (err) {
    return json(
      400,
      { error: err instanceof Error ? err.message : String(err) },
      corsHeaders
    );
  }
});
