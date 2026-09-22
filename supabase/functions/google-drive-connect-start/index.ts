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
      // Google Cloud의 Data Access에 등록된 세 개만 요청한다. 여기 없는 스코프를
      // 섞으면(userinfo.email 등) 동의 화면이 "확인되지 않은 앱" 경고를 띄운다.
      // 연결 계정 이메일은 Drive의 about.get(fields=user)으로 받는다 —
      // drive.file 만으로 호출할 수 있다.
      scope:
        "https://www.googleapis.com/auth/drive.file " +
        "https://www.googleapis.com/auth/drive.appdata " +
        "https://www.googleapis.com/auth/drive.install",
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
