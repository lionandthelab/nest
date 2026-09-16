// 네이버 콜백 → 앱 스킴 복귀 판정 (순수 함수).
//
// 네이버 콘솔은 Callback URL 로 custom scheme 을 받지 않아 HTTPS 를 한 번
// 거쳐야 한다. 그 한 번을 **302 Location** 으로 끝낸다.
//
// HTML 안내 페이지를 쓰지 않는 이유: Supabase Edge Function 응답은
// 게이트웨이가 `content-type: text/plain` 과
// `content-security-policy: default-src 'none'; sandbox` 를 강제한다.
// 그래서 <script>·<meta refresh>·<a> 가 전부 죽고, 사용자에게는 HTML 원문이
// 글자 그대로 보이는 페이지만 남는다. 로그인은 끝났는데 앱으로 못 돌아간다.

/// 스킴 URL 에 그대로 실어도 안전한 문자만 남긴다.
/// `&` `=` 같은 문자가 남으면 쿼리가 쪼개져 다른 파라미터로 둔갑한다.
export function sanitize(value: string): string {
  return value.replace(/[^A-Za-z0-9._~-]/g, "");
}

export const APP_CALLBACK = "nestnaverlogin://callback";

/// 새 앱이 state 앞에 붙이는 표식.
///
/// supabase_flutter 는 PKCE 모드에서 `?code=` 가 붙은 **모든** 딥링크를 자기
/// 콜백으로 착각한다(_isAuthCallbackDeeplink). 그래서 네이버 코드는 `code` 가
/// 아닌 이름으로 넘겨야 한다.
///
/// 이름을 한 번에 바꾸면 이미 설치된 앱이 `code` 를 못 찾아 네이버 로그인이
/// 즉시 죽는다. 표식이 있는 요청(=새 앱)에만 새 이름을 쓰고, 없으면 예전대로
/// 둔다. 새 앱이 충분히 퍼지면 이 분기를 지운다.
///
/// sanitize 를 통과해야 하므로 영숫자만 쓴다.
export const APP_STATE_MARKER = "nestv2";

/// 요청 URL 의 code/state/error 를 앱 스킴으로 넘기는 302 응답을 만든다.
export function buildCallbackRedirect(url: URL): Response {
  const code = sanitize(url.searchParams.get("code") ?? "");
  const state = sanitize(url.searchParams.get("state") ?? "");
  const error = sanitize(url.searchParams.get("error") ?? "");

  const codeParam = state.startsWith(APP_STATE_MARKER) ? "naver_code" : "code";

  const dest = new URL(APP_CALLBACK);
  if (error) dest.searchParams.set("error", error);
  if (code) dest.searchParams.set(codeParam, code);
  if (state) dest.searchParams.set("state", state);

  return new Response(null, {
    status: 302,
    headers: {
      "Location": dest.toString(),
      "Cache-Control": "no-store",
    },
  });
}
