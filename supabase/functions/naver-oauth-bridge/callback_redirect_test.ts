// 네이버 브라우저 복귀 판정.
//
// Supabase Edge Function 응답은 게이트웨이가 `content-type: text/plain` +
// `content-security-policy: default-src 'none'; sandbox` 로 강제한다. 그래서
// HTML 본문·<script>·<meta refresh> 로는 앱으로 돌아갈 수 없다 — 사용자는
// 원문이 그대로 보이는 페이지에 갇힌다. 복귀는 302 Location 으로만 된다.
//
// 실행: deno test supabase/functions/naver-oauth-bridge/callback_redirect_test.ts

import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { APP_STATE_MARKER, buildCallbackRedirect } from "./callback_redirect.ts";

function locationOf(url: string): string {
  const res = buildCallbackRedirect(new URL(url));
  assertEquals(res.status, 302);
  return res.headers.get("location") ?? "";
}

Deno.test("code/state 를 앱 스킴으로 302 전달한다", () => {
  const location = locationOf("https://x/functions/v1/b?code=ABC123&state=S1");
  assertStringIncludes(location, "nestnaverlogin://callback?");
  assertStringIncludes(location, "code=ABC123");
  assertStringIncludes(location, "state=S1");
});

Deno.test("HTML 본문에 기대지 않는다 (게이트웨이가 text/plain 으로 바꾼다)", () => {
  const res = buildCallbackRedirect(
    new URL("https://x/functions/v1/b?code=A&state=B"),
  );
  assertEquals(res.status, 302);
  assertEquals(res.headers.get("location")?.startsWith("nestnaverlogin://"), true);
});

Deno.test("사용자가 거부하면 error 를 그대로 넘긴다", () => {
  const location = locationOf("https://x/functions/v1/b?error=access_denied");
  assertStringIncludes(location, "error=access_denied");
});

Deno.test("스킴 주입이 될 수 있는 문자는 떨군다", () => {
  const location = locationOf("https://x/functions/v1/b?code=A%26evil%3D1&state=S");
  // sanitize 로 & 와 = 가 사라져 파라미터가 쪼개지지 않는다.
  assertEquals(new URL(location).searchParams.get("code"), "Aevil1");
});

// supabase_flutter 는 PKCE 모드에서 `?code=` 가 붙은 **모든** 딥링크를 자기
// 콜백으로 착각해 코드 교환을 시도한다(_isAuthCallbackDeeplink). 네이버 코드가
// Supabase 로 날아가고, 직전 구글/카카오 시도가 남긴 code_verifier 가 있으면
// 그 교환이 실제로 수행된다. 파라미터 이름을 바꿔 아예 눈에 띄지 않게 한다.
//
// 다만 브릿지를 한 번에 바꾸면 이미 설치된 앱들이 `code` 를 못 찾아 네이버
// 로그인이 즉시 죽는다. 그래서 새 앱만 state 에 표식을 달고, 브릿지는 그
// 표식이 있을 때만 새 이름으로 내보낸다.
Deno.test("표식이 있는 state 면 naver_code 로 내보낸다", () => {
  const res = buildCallbackRedirect(
    new URL(`https://x/f?code=ABC&state=${APP_STATE_MARKER}XYZ`),
  );
  const location = res.headers.get("location") ?? "";
  const params = new URL(location).searchParams;
  assertEquals(params.get("naver_code"), "ABC");
  assertEquals(params.get("code"), null, "code 가 남으면 충돌이 그대로다");
  assertEquals(params.get("state"), `${APP_STATE_MARKER}XYZ`);
});

Deno.test("표식이 없는 state 면 기존 code 이름을 유지한다 (구버전 앱)", () => {
  const res = buildCallbackRedirect(new URL("https://x/f?code=ABC&state=OLD1"));
  const params = new URL(res.headers.get("location") ?? "").searchParams;
  assertEquals(params.get("code"), "ABC");
  assertEquals(params.get("naver_code"), null);
});

Deno.test("표식이 있어도 거부 응답은 error 를 그대로 넘긴다", () => {
  const res = buildCallbackRedirect(
    new URL(`https://x/f?error=access_denied&state=${APP_STATE_MARKER}Z`),
  );
  assertStringIncludes(res.headers.get("location") ?? "", "error=access_denied");
});
