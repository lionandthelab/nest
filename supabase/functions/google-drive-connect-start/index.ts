import { corsHeaders } from "../_shared/cors.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  homeschool_id: string;
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

    if (!payload.homeschool_id) {
      return json(400, { error: "homeschool_id is required" }, corsHeaders);
    }

    await assertRole(admin, payload.homeschool_id, user.id, ["HOMESCHOOL_ADMIN"]);

    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const redirectUri = Deno.env.get("GOOGLE_REDIRECT_URI");

    if (!clientId || !redirectUri) {
      return json(400, { error: "Missing GOOGLE_CLIENT_ID or GOOGLE_REDIRECT_URI" }, corsHeaders);
    }

    const stateObj = {
      homeschool_id: payload.homeschool_id,
      user_id: user.id,
      ts: Date.now()
    };

    const state = base64UrlEncode(JSON.stringify(stateObj));

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      scope: "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.metadata.readonly",
      state
    });

    return json(
      200,
      {
        auth_url: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
        state
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

function base64UrlEncode(input: string) {
  return btoa(input).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
