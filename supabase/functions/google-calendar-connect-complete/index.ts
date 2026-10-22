import { corsHeaders } from "../_shared/cors.ts";
import {
  calendarFeedUrl,
  calendarGoogleSubscribeUrl,
  calendarRedirectUri,
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
      code?: string;
      redirect_mode?: string;
    };

    if (!payload.homeschool_id) {
      return json(400, { error: "homeschool_id is required" }, corsHeaders);
    }

    if (!payload.code || payload.code === "instant_feed") {
      const { data: existing } = await admin
        .from("calendar_integrations")
        .select("calendar_id")
        .eq("user_id", user.id)
        .maybeSingle();

      const existingCalId = String(existing?.calendar_id || "");
      const feedToken = existingCalId.startsWith("feed:")
        ? existingCalId.slice(5)
        : generateFeedToken(user.id);

      const { error } = await admin.from("calendar_integrations").upsert(
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
          last_synced_at: new Date().toISOString(),
        },
        { onConflict: "user_id" }
      );

      if (error) throw new Error(error.message);

      return json(
        200,
        {
          connected: true,
          google_email: user.email || null,
          feed_url: calendarFeedUrl(feedToken),
          google_subscribe_url: calendarGoogleSubscribeUrl(feedToken),
          has_refresh_token: true,
        },
        corsHeaders
      );
    }

    const stored = await exchangeAndStore({
      admin,
      userId: user.id,
      userEmail: user.email || null,
      homeschoolId: payload.homeschool_id,
      code: payload.code,
      redirectUri: calendarRedirectUri(payload.redirect_mode ?? "web"),
    });

    return json(200, stored, corsHeaders);
  } catch (err) {
    return json(
      400,
      { error: err instanceof Error ? err.message : String(err) },
      corsHeaders
    );
  }
});

export async function exchangeAndStore(args: {
  admin: ReturnType<typeof createAdminClient>;
  userId: string;
  userEmail: string | null;
  homeschoolId: string;
  code: string;
  redirectUri: string;
}) {
  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
  if (!clientId || !clientSecret || !args.redirectUri) {
    throw new Error("Google OAuth 설정이 없습니다.");
  }

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: args.code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: args.redirectUri,
      grant_type: "authorization_code",
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Google token exchange failed: ${text}`);
  }

  const tokenJson = await tokenRes.json();
  const accessToken = tokenJson.access_token as string | undefined;
  const refreshToken = tokenJson.refresh_token as string | undefined;
  const expiresIn = Number(tokenJson.expires_in || 3600);
  if (!accessToken) throw new Error("access_token missing");

  const email = args.userEmail;
  const { error } = await args.admin.from("calendar_integrations").upsert(
    {
      user_id: args.userId,
      homeschool_id: args.homeschoolId,
      provider: "GOOGLE",
      status: "CONNECTED",
      google_email: email,
      google_access_token: accessToken,
      google_refresh_token: refreshToken || undefined,
      google_token_expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
      oauth_scope: tokenJson.scope || "https://www.googleapis.com/auth/calendar.events",
      calendar_id: "primary",
      last_synced_at: new Date().toISOString(),
    },
    { onConflict: "user_id" }
  );

  if (error) throw new Error(error.message);

  return {
    connected: true,
    google_email: email,
    has_refresh_token: Boolean(refreshToken),
  };
}
