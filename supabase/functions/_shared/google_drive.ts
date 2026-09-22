/// Drive 연결이 쓰는 리다이렉트 주소와 state 인코딩.
///
/// 웹은 팝업 + localStorage 핸드셰이크(callback.html)를 쓰고, 앱은 시스템
/// 브라우저로 나갔다가 이 함수로 돌아온다. 캘린더 연결과 같은 구조다.

export function driveRedirectUri(mode: string | undefined) {
  if (mode === "web") {
    return Deno.env.get("GOOGLE_REDIRECT_URI") || "";
  }
  return (
    Deno.env.get("GOOGLE_DRIVE_REDIRECT_URI") ||
    `${Deno.env.get("SUPABASE_URL")}/functions/v1/google-drive-oauth`
  );
}

/// 앱 사용자가 브라우저에서 인증을 마친 뒤 도착할 안내 페이지.
/// Edge Function은 HTML을 낼 수 없으므로(게이트웨이가 text/plain + sandbox로
/// 덮어쓴다) 웹 앱 오리진의 정적 페이지로 302를 보낸다.
export function driveDonePageUrl(ok: boolean, reason?: string) {
  const base =
    Deno.env.get("NEST_WEB_ORIGIN") || "https://nestapp.life";
  const params = new URLSearchParams({ status: ok ? "ok" : "error" });
  if (reason) params.set("reason", reason.slice(0, 200));
  return `${base}/oauth/google/connected.html?${params.toString()}`;
}

export function encodeState(payload: Record<string, unknown>) {
  return btoa(JSON.stringify(payload))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export function decodeState(state: string): Record<string, unknown> {
  const padded = state.replaceAll("-", "+").replaceAll("_", "/");
  return JSON.parse(atob(padded));
}
