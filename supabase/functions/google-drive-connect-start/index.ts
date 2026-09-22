import { corsHeaders } from "../_shared/cors.ts";
import {
  DRIVE_APP_INTENT,
  driveOauthFunctionUrl,
  driveRedirectUri,
} from "../_shared/google_drive.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  homeschool_id: string;
  /// "web"이면 팝업 + callback.html, 그 외에는 앱용 리다이렉트 함수로 돌아온다.
  redirect_mode?: string;
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
    const redirectUri = driveRedirectUri(payload.redirect_mode);

    if (!clientId || !redirectUri) {
      return json(400, { error: "Missing GOOGLE_CLIENT_ID or GOOGLE_REDIRECT_URI" }, corsHeaders);
    }

    const isApp = payload.redirect_mode === "app";

    const stateObj = {
      homeschool_id: payload.homeschool_id,
      user_id: user.id,
      // 앱 모드면 callback.html 이 이 표식을 보고 엣지 함수로 넘긴다.
      intent: isApp ? DRIVE_APP_INTENT : "drive",
      oauth_fn: isApp ? driveOauthFunctionUrl() : undefined,
      ts: Date.now()
    };

    const state = base64UrlEncode(JSON.stringify(stateObj));

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: "true",
      // 연결 화면에서 "어느 계정인지" 보여 주려면 이메일이 필요하다.
      scope:
        "https://www.googleapis.com/auth/drive.file " +
        "https://www.googleapis.com/auth/drive.appdata " +
        "https://www.googleapis.com/auth/drive.install " +
        "https://www.googleapis.com/auth/userinfo.email",
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
