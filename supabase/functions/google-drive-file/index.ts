import { corsHeaders } from "../_shared/cors.ts";
import { createAdminClient, json, requireUser } from "../_shared/supabase.ts";

/// 관리자 Drive에 있는 앨범 원본을 홈스쿨 구성원에게만 내보낸다.
///
/// 하이브리드 저장에서 썸네일은 Supabase 공개 버킷(CDN)에 있지만 원본은 관리자
/// Drive에만 있다. Drive 파일은 공개 공유돼 있지 않으므로(아동 사진에 "링크
/// 있는 누구나"는 쓸 수 없다) 클라이언트가 직접 받을 수 없고, 관리자 토큰을
/// 프론트에 내줄 수도 없다. 그래서 이 함수가 권한을 확인하고 바이트만 중계한다.
///
/// 호출부는 supabase.functions.invoke로 바이트를 받아 Image.memory로 그린다.

type Payload = {
  media_asset_id: string;
  /// "get"(기본) 이면 바이트를 중계하고, "delete" 면 Drive에서 파일을 지운다.
  /// 지우지 않으면 앨범에서 사진을 내려도 관리자 Drive 용량이 회수되지 않아
  /// 하이브리드 저장을 쓰는 이유 자체가 없어진다.
  action?: "get" | "delete";
};

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

    if (!payload.media_asset_id) {
      return json(400, { error: "media_asset_id is required" }, corsHeaders);
    }

    const action = payload.action === "delete" ? "delete" : "get";

    const { data: asset, error: assetErr } = await admin
      .from("media_assets")
      .select(
        "id, homeschool_id, drive_file_id, mime_type, file_name, uploader_user_id"
      )
      .eq("id", payload.media_asset_id)
      .maybeSingle();

    if (assetErr || !asset) {
      return json(404, { error: "ASSET_NOT_FOUND" }, corsHeaders);
    }
    if (!asset.drive_file_id) {
      return json(409, { error: "NOT_A_DRIVE_ASSET" }, corsHeaders);
    }

    // 역할은 보지 않는다. 그 홈스쿨의 활성 구성원이면 앨범을 볼 수 있다
    // (media_assets_select_member 정책과 같은 기준).
    const { data: membership } = await admin
      .from("homeschool_memberships")
      .select("role")
      .eq("homeschool_id", asset.homeschool_id)
      .eq("user_id", user.id)
      .eq("status", "ACTIVE")
      .limit(1)
      .maybeSingle();

    if (!membership) {
      return json(403, { error: "홈스쿨 권한이 없습니다." }, corsHeaders);
    }

    // 삭제는 보기보다 좁다. media_assets_delete_uploader_or_admin 정책과 같은
    // 기준으로, 본인이 올렸거나 그 홈스쿨의 관리자/스태프여야 한다.
    if (action === "delete") {
      const canDelete =
        asset.uploader_user_id === user.id ||
        membership.role === "HOMESCHOOL_ADMIN" ||
        membership.role === "STAFF";
      if (!canDelete) {
        return json(403, { error: "사진을 삭제할 권한이 없습니다." }, corsHeaders);
      }
    }

    const { data: integration } = await admin
      .from("drive_integrations")
      .select(
        "id, status, google_access_token, google_refresh_token, google_token_expires_at"
      )
      .eq("homeschool_id", asset.homeschool_id)
      .maybeSingle();

    if (!integration || integration.status !== "CONNECTED") {
      return json(409, { error: "DRIVE_NOT_CONNECTED" }, corsHeaders);
    }

    const accessToken = await freshAccessToken(admin, integration);
    if (!accessToken) {
      return json(409, { error: "DRIVE_ACCESS_TOKEN_MISSING" }, corsHeaders);
    }

    if (action === "delete") {
      const delRes = await fetch(
        `https://www.googleapis.com/drive/v3/files/${asset.drive_file_id}?supportsAllDrives=true`,
        { method: "DELETE", headers: { Authorization: `Bearer ${accessToken}` } }
      );

      // 404는 이미 없다는 뜻이니 성공으로 친다. 앨범에서 지운 사진이 Drive에도
      // 없는 상태가 목표이지, 삭제 호출이 성공하는 게 목표가 아니다.
      if (!delRes.ok && delRes.status !== 404) {
        const details = await delRes.text();
        return json(
          502,
          { error: "DRIVE_DELETE_FAILED", status: delRes.status, details },
          corsHeaders
        );
      }

      return json(200, { deleted: true }, corsHeaders);
    }

    const driveRes = await fetch(
      `https://www.googleapis.com/drive/v3/files/${asset.drive_file_id}?alt=media&supportsAllDrives=true`,
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    if (!driveRes.ok) {
      const details = await driveRes.text();
      return json(
        502,
        { error: "DRIVE_FETCH_FAILED", status: driveRes.status, details },
        corsHeaders
      );
    }

    return new Response(driveRes.body, {
      status: 200,
      headers: {
        ...corsHeaders,
        // 반드시 octet-stream 이어야 한다. supabase 함수 클라이언트는 이 타입일
        // 때만 바이트를 그대로 주고, image/jpeg 같은 타입은 UTF-8 문자열로
        // 디코딩해 버려 이미지가 깨진다(뷰어가 "원본을 불러오지 못했습니다"로 떴다).
        // 실제 타입은 아래 헤더로 따로 알린다.
        "Content-Type": "application/octet-stream",
        "X-Nest-Media-Type":
          asset.mime_type || driveRes.headers.get("content-type") ||
          "application/octet-stream",
        // 앨범 원본은 한 번 올라가면 바뀌지 않는다. 뷰어에서 좌우로 넘길 때
        // 같은 장을 다시 받지 않도록 브라우저 캐시에 맡긴다.
        "Cache-Control": "private, max-age=86400",
      },
    });
  } catch (err) {
    return json(
      500,
      {
        error: "DRIVE_FILE_FAILED",
        details: err instanceof Error ? err.message : String(err),
      },
      corsHeaders
    );
  }
});

async function freshAccessToken(
  admin: ReturnType<typeof createAdminClient>,
  integration: {
    id: string;
    google_access_token: string | null;
    google_refresh_token: string | null;
    google_token_expires_at: string | null;
  }
) {
  const expiresAt = integration.google_token_expires_at;
  const stillFresh =
    expiresAt && new Date(expiresAt).getTime() - Date.now() > 2 * 60 * 1000;

  if (integration.google_access_token && stillFresh) {
    return integration.google_access_token;
  }
  if (!integration.google_refresh_token) {
    return integration.google_access_token;
  }

  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    return integration.google_access_token;
  }

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: integration.google_refresh_token,
      grant_type: "refresh_token",
    }),
  });

  if (!tokenRes.ok) {
    return integration.google_access_token;
  }

  const tokenJson = await tokenRes.json();
  const accessToken = tokenJson.access_token as string | undefined;
  if (!accessToken) {
    return integration.google_access_token;
  }

  const expiresIn = Number(tokenJson.expires_in || 3600);
  await admin
    .from("drive_integrations")
    .update({
      google_access_token: accessToken,
      google_token_expires_at: new Date(
        Date.now() + expiresIn * 1000
      ).toISOString(),
    })
    .eq("id", integration.id);

  return accessToken;
}
