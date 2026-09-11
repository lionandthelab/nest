import { corsHeaders } from "../_shared/cors.ts";
import { calendarRedirectUri, encodeState } from "../_shared/google_calendar.ts";
import { createAdminClient, json, requireUser } from "../_shared/supabase.ts";

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

    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const redirectUri = calendarRedirectUri(payload.redirect_mode);
    if (!clientId || !redirectUri) {
      return json(400, { error: "Google Calendar OAuth 설정이 없습니다." }, corsHeaders);
    }

    const state = encodeState({
      homeschool_id: payload.homeschool_id,
      user_id: user.id,
      intent: "calendar",
      ts: Date.now(),
    });

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: "true",
      scope: "https://www.googleapis.com/auth/calendar.events",
      state,
    });

    return json(
      200,
      {
        auth_url: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
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
