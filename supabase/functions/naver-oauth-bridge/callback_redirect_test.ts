// 네이버 브라우저 복귀 판정.
//
// Supabase Edge Function 응답은 게이트웨이가 `content-type: text/plain` +
// `content-security-policy: default-src 'none'; sandbox` 로 강제한다. 그래서
// HTML 본문·<script>·<meta refresh> 로는 앱으로 돌아갈 수 없다 — 사용자는
// 원문이 그대로 보이는 페이지에 갇힌다. 복귀는 302 Location 으로만 된다.
//
// 실행: deno test supabase/functions/naver-oauth-bridge/callback_redirect_test.ts

import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildCallbackRedirect } from "./callback_redirect.ts";

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
