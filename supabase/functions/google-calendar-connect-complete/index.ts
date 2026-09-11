import { corsHeaders } from "../_shared/cors.ts";
import { calendarRedirectUri } from "../_shared/google_calendar.ts";
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
      code?: string;
      redirect_mode?: string;
    };

    if (!payload.homeschool_id || !payload.code) {
      return json(400, { error: "homeschool_id and code are required" }, corsHeaders);
    }

    const stored = await exchangeAndStore({
      admin,
      userId: user.id,
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

  let email: string | null = null;
  try {
    const info = await fetch("https://www.googleapis.com/oauth2/v2/userinfo", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (info.ok) {
      const body = await info.json();
      email = typeof body.email === "string" ? body.email : null;
    }
  } catch {
    // email is optional
  }

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
