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
  /// "disconnect"이면 기존 Google OAuth 토큰을 Google 서버에서 revoke한 뒤 DB 연결을 해제한다.
  action?: string;
};

async function revokeGoogleTokenBestEffort(token: string | null | undefined) {
  if (!token || typeof token !== "string" || token.trim().length === 0) return;
  try {
    await fetch("https://oauth2.googleapis.com/revoke", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ token: token.trim() }),
    });
  } catch (_) {
    // best-effort
  }
}

function hasUnverifiedScope(scope: string | null | undefined): boolean {
  if (!scope) return false;
  return (
    scope.includes("readonly") ||
    scope.includes("userinfo") ||
    scope.includes("calendar")
  );
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
    const payload = (await req.json()) as Partial<Payload>;

    if (!payload.homeschool_id) {
      return json(400, { error: "homeschool_id is required" }, corsHeaders);
    }

    await assertRole(admin, payload.homeschool_id, user.id, ["HOMESCHOOL_ADMIN"]);

    if (payload.action === "disconnect") {
      const { data: existing } = await admin
        .from("drive_integrations")
        .select("google_refresh_token, google_access_token")
        .eq("homeschool_id", payload.homeschool_id)
        .maybeSingle();

      if (existing) {
        await revokeGoogleTokenBestEffort(
          (existing.google_refresh_token as string | null) ||
            (existing.google_access_token as string | null)
        );
      }

      await admin
        .from("drive_integrations")
        .update({
          status: "DISCONNECTED",
          google_access_token: null,
          google_refresh_token: null,
          google_token_expires_at: null,
          oauth_scope: null,
        })
        .eq("homeschool_id", payload.homeschool_id);

      return json(200, { disconnected: true }, corsHeaders);
    }

    // 이전에 미검증/민감 스코프(drive.metadata.readonly, userinfo.email, calendar 등)가
    // 같은 OAuth 클라이언트에 부여된 적이 있으면 Google 동의 화면이 "Google에서 확인하지 않은 앱"
    // 경고를 띄운다. 새 동의 화면을 열기 전에 오염된 기존 토큰을 Google에서 먼저 revoke한다.
    const { data: driveRows } = await admin
      .from("drive_integrations")
      .select("id, google_refresh_token, google_access_token, oauth_scope")
      .or(`homeschool_id.eq.${payload.homeschool_id},connected_by_user_id.eq.${user.id}`);

    for (const row of driveRows || []) {
      if (hasUnverifiedScope(row.oauth_scope as string | null)) {
        await revokeGoogleTokenBestEffort(
          (row.google_refresh_token as string | null) ||
            (row.google_access_token as string | null)
        );
      }
    }

    const { data: calRows } = await admin
      .from("calendar_integrations")
      .select("id, google_refresh_token, google_access_token, oauth_scope")
      .eq("user_id", user.id);

    for (const row of calRows || []) {
      if (hasUnverifiedScope(row.oauth_scope as string | null)) {
        await revokeGoogleTokenBestEffort(
          (row.google_refresh_token as string | null) ||
            (row.google_access_token as string | null)
        );
      }
    }

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
      // 웹에서도 도메인 전환(github.io -> nestapp.life)으로 localStorage가 비어 있을 때
      // oauth_fn 폴백으로 연결을 마무리할 수 있게 항상 넣어 둔다.
      intent: isApp ? DRIVE_APP_INTENT : "drive",
      oauth_fn: driveOauthFunctionUrl(),
      ts: Date.now()
    };

    const state = base64UrlEncode(JSON.stringify(stateObj));

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      // 중요: true로 두면 과거에 같은 Google 계정이 허용했던 미검증/민감 스코프
      // (drive.metadata.readonly, calendar.events 등)까지 동의 화면에 합쳐져서
      // "Google에서 확인하지 않은 앱" 경고가 뜬다. 반드시 false로 고정한다.
      include_granted_scopes: "false",
      // 비민감(Non-sensitive) 스코프인 drive.file 만 요청한다.
      // 연결 계정 이메일은 Drive의 about.get(fields=user)으로 받는다.
      scope: "https://www.googleapis.com/auth/drive.file",
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
