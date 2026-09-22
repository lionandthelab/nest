import {
  decodeState,
  driveDonePageUrl,
  driveRedirectUri,
} from "../_shared/google_drive.ts";
import { createAdminClient } from "../_shared/supabase.ts";

/// 앱(모바일/데스크톱)에서 시작한 Drive 연결이 돌아오는 자리.
///
/// 웹은 팝업 + localStorage 핸드셰이크를 쓰지만, 앱에는 팝업이 없어 시스템
/// 브라우저로 나갔다가 여기로 돌아온다. Edge Function은 HTML을 낼 수 없으므로
/// (게이트웨이가 text/plain + sandbox CSP로 덮어쓴다) 안내 문구 대신
/// 웹 앱 오리진의 정적 페이지로 302를 보낸다. 앱은 그동안 DB를 폴링한다.

function seeOther(location: string) {
  return new Response(null, { status: 302, headers: { Location: location } });
}

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return seeOther(driveDonePageUrl(false, "method"));
  }

  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const oauthError = url.searchParams.get("error");
  const state = url.searchParams.get("state");

  if (oauthError) {
    return seeOther(driveDonePageUrl(false, oauthError));
  }
  if (!code || !state) {
    return seeOther(driveDonePageUrl(false, "no_code"));
  }

  try {
    const parsed = decodeState(state);
    const userId = String(parsed.user_id || "");
    const homeschoolId = String(parsed.homeschool_id || "");
    if (!userId || !homeschoolId) {
      return seeOther(driveDonePageUrl(false, "bad_state"));
    }

    const admin = createAdminClient();
    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
    const redirectUri = driveRedirectUri("app");
    if (!clientId || !clientSecret || !redirectUri) {
      return seeOther(driveDonePageUrl(false, "server_config"));
    }

    // state는 서명돼 있지 않다. 그래서 여기서 다시 한 번, 이 사용자가 정말 그
    // 홈스쿨의 관리자인지 확인한다. 확인 없이 토큰을 심으면 남의 홈스쿨에 자기
    // Drive를 붙일 수 있다.
    const { data: membership } = await admin
      .from("homeschool_memberships")
      .select("role")
      .eq("homeschool_id", homeschoolId)
      .eq("user_id", userId)
      .eq("status", "ACTIVE")
      .eq("role", "HOMESCHOOL_ADMIN")
      .limit(1)
      .maybeSingle();

    if (!membership) {
      return seeOther(driveDonePageUrl(false, "forbidden"));
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: "authorization_code",
      }),
    });

    if (!tokenRes.ok) {
      return seeOther(driveDonePageUrl(false, "token_exchange"));
    }

    const tokenJson = await tokenRes.json();
    const accessToken = tokenJson.access_token as string | undefined;
    if (!accessToken) {
      return seeOther(driveDonePageUrl(false, "no_access_token"));
    }

    const expiresIn = Number(tokenJson.expires_in || 3600);
    const email = await lookupEmail(accessToken);

    const { error: upsertErr } = await admin.from("drive_integrations").upsert(
      {
        homeschool_id: homeschoolId,
        provider: "GOOGLE_DRIVE",
        status: "CONNECTED",
        folder_policy: "TERM_CLASS_DATE",
        connected_by_user_id: userId,
        connected_at: new Date().toISOString(),
        google_access_token: accessToken,
        google_refresh_token: (tokenJson.refresh_token as string) || null,
        google_token_expires_at: new Date(
          Date.now() + expiresIn * 1000
        ).toISOString(),
        google_email: email,
        oauth_scope: (tokenJson.scope as string) || null,
      },
      { onConflict: "homeschool_id" }
    );

    if (upsertErr) {
      return seeOther(driveDonePageUrl(false, "save_failed"));
    }

    return seeOther(driveDonePageUrl(true));
  } catch (_err) {
    return seeOther(driveDonePageUrl(false, "unexpected"));
  }
});

async function lookupEmail(accessToken: string): Promise<string | null> {
  try {
    const res = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) return null;
    const body = await res.json();
    return typeof body.email === "string" ? body.email : null;
  } catch (_) {
    return null;
  }
}
