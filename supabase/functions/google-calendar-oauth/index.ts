import { calendarRedirectUri, decodeState } from "../_shared/google_calendar.ts";
import { createAdminClient } from "../_shared/supabase.ts";

function html(body: string, ok = true) {
  return new Response(
    `<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>Nest 캘린더</title>
    <style>body{font-family:sans-serif;background:#F9F7F2;color:#5A4637;display:grid;place-items:center;min-height:100vh;margin:0}
    .card{background:#fff;padding:24px;border-radius:16px;max-width:420px}</style></head>
    <body><article class="card">${body}</article></body></html>`,
    {
      status: ok ? 200 : 400,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    }
  );
}

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return html("<p>Method not allowed</p>", false);
  }

  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const err = url.searchParams.get("error");
  const state = url.searchParams.get("state");

  if (err) {
    return html(`<h1>연결이 취소되었습니다</h1><p>${err}</p>`, false);
  }
  if (!code || !state) {
    return html("<h1>인증 코드가 없습니다</h1><p>앱에서 다시 연결해 주세요.</p>", false);
  }

  try {
    const parsed = decodeState(state);
    const userId = String(parsed.user_id || "");
    const homeschoolId = String(parsed.homeschool_id || "");
    if (!userId || !homeschoolId) {
      return html("<h1>상태 값이 올바르지 않습니다</h1>", false);
    }

    const admin = createAdminClient();
    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
    const redirectUri = calendarRedirectUri("app");
    if (!clientId || !clientSecret || !redirectUri) {
      return html("<h1>서버 설정이 없습니다</h1>", false);
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
      return html(`<h1>토큰 교환 실패</h1><p>${await tokenRes.text()}</p>`, false);
    }

    const tokenJson = await tokenRes.json();
    const accessToken = tokenJson.access_token as string | undefined;
    if (!accessToken) return html("<h1>access_token 없음</h1>", false);

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
      // optional
    }

    const expiresIn = Number(tokenJson.expires_in || 3600);
    const { error } = await admin.from("calendar_integrations").upsert(
      {
        user_id: userId,
        homeschool_id: homeschoolId,
        provider: "GOOGLE",
        status: "CONNECTED",
        google_email: email,
        google_access_token: accessToken,
        google_refresh_token: tokenJson.refresh_token || undefined,
        google_token_expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
        oauth_scope: tokenJson.scope || "https://www.googleapis.com/auth/calendar.events",
        calendar_id: "primary",
      },
      { onConflict: "user_id" }
    );

    if (error) return html(`<h1>저장 실패</h1><p>${error.message}</p>`, false);

    return html(
      "<h1>Google 캘린더가 연결되었습니다</h1><p>이 창을 닫고 Nest 앱으로 돌아가 주세요.</p>"
    );
  } catch (error) {
    return html(
      `<h1>연결 실패</h1><p>${error instanceof Error ? error.message : String(error)}</p>`,
      false
    );
  }
});
