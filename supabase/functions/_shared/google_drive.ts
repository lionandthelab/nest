/// Drive 연결이 쓰는 리다이렉트 주소와 state 인코딩.
///
/// 웹은 팝업 + localStorage 핸드셰이크(callback.html)를 쓰고, 앱은 시스템
/// 브라우저로 나갔다가 이 함수로 돌아온다. 캘린더 연결과 같은 구조다.

/// Drive OAuth는 웹이든 앱이든 **같은** 리디렉션 URI를 쓴다.
///
/// Google은 redirect_uri 를 등록 목록과 정확히 대조하는데, 새 주소를 쓰려면
/// Google Cloud 콘솔에 사람이 직접 등록해야 한다. 등록 전까지는 앱에서 연결을
/// 시작하면 redirect_uri_mismatch 로 막힌다(2026-09-22 브라우저로 확인).
///
/// 그래서 앱도 이미 등록돼 있는 웹 콜백(callback.html)으로 돌아오고, 그 페이지가
/// 앱용 state 를 알아보면 google-drive-oauth 로 한 번 더 넘긴다. 콘솔을 건드리지
/// 않고도 앱 연결이 동작한다.
export function driveRedirectUri(_mode?: string) {
  return Deno.env.get("GOOGLE_REDIRECT_URI") || "";
}

/// 앱 모드에서 callback.html 이 코드를 넘길 주소.
export function driveOauthFunctionUrl() {
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/google-drive-oauth`;
}

/// state 에 실어 보내는 앱 모드 표식.
export const DRIVE_APP_INTENT = "drive_app";

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
