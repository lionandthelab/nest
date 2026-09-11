// 네이버는 custom scheme을 Callback URL로 받지 않는다.
// HTTPS로 받은 code/state를 앱 스킴으로 넘기고, 브라우저에 남는 안내를 보여 준다.

function sanitize(value: string) {
  return value.replace(/[^A-Za-z0-9._~-]/g, "");
}

Deno.serve((req) => {
  const url = new URL(req.url);
  const code = sanitize(url.searchParams.get("code") ?? "");
  const state = sanitize(url.searchParams.get("state") ?? "");
  const error = sanitize(url.searchParams.get("error") ?? "");

  const dest = new URL("nestnaverlogin://callback");
  if (error) dest.searchParams.set("error", error);
  if (code) dest.searchParams.set("code", code);
  if (state) dest.searchParams.set("state", state);
  const href = dest.toString();

  const html = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="0;url=${href}">
  <title>Nest</title>
  <style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;
      background:#F9F7F2;color:#5A4637;font-family:-apple-system,sans-serif}
    .card{text-align:center;padding:28px}
    a{color:#B48268}
  </style>
  <script>location.replace(${JSON.stringify(href)});</script>
</head>
<body>
  <div class="card">
    <p>Nest로 돌아가는 중이에요.</p>
    <p><a href="${href}">앱이 안 열리면 여기를 눌러 주세요</a></p>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
});
