// 네이버는 custom scheme 을 Callback URL 로 받지 않는다.
// HTTPS 로 받은 code/state 를 302 로 앱 스킴에 넘긴다.
//
// 복귀 판정과 그 근거는 callback_redirect.ts 에 있다.

import { buildCallbackRedirect } from "./callback_redirect.ts";

Deno.serve((req) => buildCallbackRedirect(new URL(req.url)));
