import { corsHeaders } from "../_shared/cors.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  homeschool_id: string;
  code: string;
  root_folder_id?: string;
  folder_policy?: "TERM_CLASS_DATE" | "CLASS_CHILD_DATE";
};

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
    const payload = (await req.json()) as Partial<Payload>;

    if (!payload.homeschool_id || !payload.code) {
      return json(400, { error: "homeschool_id and code are required" }, corsHeaders);
    }

    await assertRole(admin, payload.homeschool_id, user.id, ["HOMESCHOOL_ADMIN"]);

    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
    const redirectUri = Deno.env.get("GOOGLE_REDIRECT_URI");

    if (!clientId || !clientSecret || !redirectUri) {
      return json(400, { error: "Missing Google OAuth secrets" }, corsHeaders);
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({
        code: payload.code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: "authorization_code"
      })
    });

    if (!tokenRes.ok) {
      const text = await tokenRes.text();
      return json(400, { error: "Google token exchange failed", details: text }, corsHeaders);
    }

    const tokenJson = await tokenRes.json();
    const accessToken = tokenJson.access_token as string | undefined;
    const refreshToken = tokenJson.refresh_token as string | undefined;
    const expiresIn = Number(tokenJson.expires_in || 3600);
    const scope = tokenJson.scope as string | undefined;

    if (!accessToken) {
      return json(400, { error: "access_token missing from Google response" }, corsHeaders);
    }

    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    const { error: upsertErr } = await admin.from("drive_integrations").upsert(
      {
        homeschool_id: payload.homeschool_id,
        provider: "GOOGLE_DRIVE",
        status: "CONNECTED",
        root_folder_id: payload.root_folder_id || null,
        folder_policy: payload.folder_policy || "TERM_CLASS_DATE",
        connected_by_user_id: user.id,
        connected_at: new Date().toISOString(),
        google_access_token: accessToken,
        google_refresh_token: refreshToken || null,
        google_token_expires_at: expiresAt,
        oauth_scope: scope || null
      },
      { onConflict: "homeschool_id" }
    );

    if (upsertErr) {
      return json(500, { error: upsertErr.message }, corsHeaders);
    }

    return json(
      200,
      {
        connected: true,
        expires_at: expiresAt,
        has_refresh_token: Boolean(refreshToken)
      },
      corsHeaders
    );
  } catch (err) {
    return json(
      500,
      { error: err instanceof Error ? err.message : String(err) },
      corsHeaders
    );
  }
});
