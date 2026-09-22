import { corsHeaders } from "../_shared/cors.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  homeschool_id: string;
  upload_session_id: string;
  file_name: string;
  mime_type: string;
  file_base64: string;
  /// 관리자 Drive 안에서 파일이 들어갈 경로. 보통 ["2026-1학기", "미술", "2026-09-22"].
  /// 비면 루트 폴더 바로 아래에 둔다.
  folder_segments?: string[];
};

type Integration = {
  id: string;
  status: string;
  root_folder_id: string | null;
  google_access_token: string | null;
  google_refresh_token: string | null;
  google_token_expires_at: string | null;
};

type Admin = ReturnType<typeof createAdminClient>;

const DRIVE_FOLDER_MIME = "application/vnd.google-apps.folder";
/// 앱이 스스로 만드는 기본 루트. 관리자가 폴더 ID를 직접 붙여 넣지 않아도
/// 앨범이 한곳에 모이도록 한다.
const DEFAULT_ROOT_NAME = "Nest 앨범";

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

    if (
      !payload.homeschool_id ||
      !payload.upload_session_id ||
      !payload.file_name ||
      !payload.mime_type ||
      !payload.file_base64
    ) {
      return json(
        400,
        { error: "homeschool_id, upload_session_id, file_name, mime_type, file_base64 are required" },
        corsHeaders
      );
    }

    // PARENT도 앨범에 사진을 올린다. 예전에는 교사/관리자만 통과해서, 학부모가
    // 올린 사진은 Storage에만 남고 Drive에는 영영 미러되지 않았다.
    await assertRole(admin, payload.homeschool_id, user.id, [
      "HOMESCHOOL_ADMIN",
      "STAFF",
      "TEACHER",
      "GUEST_TEACHER",
      "PARENT"
    ]);

    const { data: integration, error: integErr } = await admin
      .from("drive_integrations")
      .select(
        "id, status, root_folder_id, google_access_token, google_refresh_token, google_token_expires_at"
      )
      .eq("homeschool_id", payload.homeschool_id)
      .maybeSingle();

    if (integErr || !integration) {
      return json(409, { error: "DRIVE_NOT_CONNECTED", details: integErr?.message || "No integration" }, corsHeaders);
    }

    const integ = integration as Integration;

    if (integ.status !== "CONNECTED") {
      return json(409, { error: "DRIVE_NOT_CONNECTED", details: "Integration is not connected" }, corsHeaders);
    }

    let accessToken = integ.google_access_token;

    if (!accessToken) {
      return json(409, { error: "DRIVE_ACCESS_TOKEN_MISSING" }, corsHeaders);
    }

    const refreshed = await maybeRefreshToken(
      admin,
      integ.id,
      integ.google_refresh_token,
      integ.google_token_expires_at
    );
    if (refreshed?.access_token) {
      accessToken = refreshed.access_token;
    }

    const parentFolderId = await resolveTargetFolder({
      admin,
      integration: integ,
      accessToken,
      segments: sanitizeSegments(payload.folder_segments)
    });

    const uploadResult = await uploadToDrive({
      accessToken,
      name: payload.file_name,
      mimeType: payload.mime_type,
      base64: payload.file_base64,
      parentFolderId
    });

    await admin
      .from("media_upload_sessions")
      .update({ status: "UPLOADING", target_folder_id: parentFolderId })
      .eq("id", payload.upload_session_id)
      .eq("homeschool_id", payload.homeschool_id);

    return json(
      200,
      {
        drive_file_id: uploadResult.id,
        drive_web_view_link: uploadResult.webViewLink || null,
        drive_name: uploadResult.name || payload.file_name,
        drive_folder_id: parentFolderId
      },
      corsHeaders
    );
  } catch (err) {
    return json(
      500,
      {
        error: "UPLOAD_FAILED",
        details: err instanceof Error ? err.message : String(err)
      },
      corsHeaders
    );
  }
});

/// Drive 폴더 이름으로 쓸 수 없는 문자를 걷어내고 빈 조각을 버린다.
/// 경로 조각이 그대로 캐시 키가 되므로 정규화를 한곳에서 끝낸다.
export function sanitizeSegments(segments: unknown): string[] {
  if (!Array.isArray(segments)) return [];

  return segments
    .filter((segment): segment is string => typeof segment === "string")
    .map((segment) =>
      segment
        .replace(/[\/\\]/g, "-")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 80)
    )
    .filter((segment) => segment.length > 0 && segment !== "." && segment !== "..")
    .slice(0, 4);
}

/// 경로 조각을 한 단계씩 내려가며 폴더를 확보한다. 각 단계의 id는
/// drive_folder_nodes에 경로 문자열로 캐시되므로 두 번째 파일부터는
/// Drive API 왕복이 0회가 된다.
async function resolveTargetFolder(args: {
  admin: Admin;
  integration: Integration;
  accessToken: string;
  segments: string[];
}) {
  let parentId = args.integration.root_folder_id?.trim() || null;

  if (!parentId) {
    parentId = await ensureFolder({
      admin: args.admin,
      integrationId: args.integration.id,
      accessToken: args.accessToken,
      pathKey: "/",
      name: DEFAULT_ROOT_NAME,
      parentId: null
    });
  }

  let pathKey = "";
  for (const segment of args.segments) {
    pathKey = pathKey ? `${pathKey}/${segment}` : segment;
    parentId = await ensureFolder({
      admin: args.admin,
      integrationId: args.integration.id,
      accessToken: args.accessToken,
      pathKey,
      name: segment,
      parentId
    });
  }

  return parentId;
}

async function ensureFolder(args: {
  admin: Admin;
  integrationId: string;
  accessToken: string;
  pathKey: string;
  name: string;
  parentId: string | null;
}) {
  const { data: cached } = await args.admin
    .from("drive_folder_nodes")
    .select("folder_id")
    .eq("drive_integration_id", args.integrationId)
    .eq("path_key", args.pathKey)
    .maybeSingle();

  if (cached?.folder_id) {
    return cached.folder_id as string;
  }

  const folderId =
    (await findFolder(args.accessToken, args.name, args.parentId)) ??
    (await createFolder(args.accessToken, args.name, args.parentId));

  // 동시 업로드가 같은 폴더를 만들 수 있다. unique(integration, path_key)에
  // 부딪히면 먼저 이긴 쪽의 id를 쓴다.
  const { error: insertErr } = await args.admin
    .from("drive_folder_nodes")
    .insert({
      drive_integration_id: args.integrationId,
      path_key: args.pathKey,
      folder_id: folderId
    });

  if (insertErr) {
    const { data: winner } = await args.admin
      .from("drive_folder_nodes")
      .select("folder_id")
      .eq("drive_integration_id", args.integrationId)
      .eq("path_key", args.pathKey)
      .maybeSingle();

    if (winner?.folder_id) {
      return winner.folder_id as string;
    }
  }

  return folderId;
}

async function findFolder(accessToken: string, name: string, parentId: string | null) {
  const escaped = name.replaceAll("\\", "\\\\").replaceAll("'", "\\'");
  const clauses = [
    `name = '${escaped}'`,
    `mimeType = '${DRIVE_FOLDER_MIME}'`,
    "trashed = false"
  ];

  if (parentId) {
    clauses.push(`'${parentId}' in parents`);
  }

  const params = new URLSearchParams({
    q: clauses.join(" and "),
    fields: "files(id,name)",
    pageSize: "1",
    supportsAllDrives: "true",
    includeItemsFromAllDrives: "true"
  });

  const res = await fetch(`https://www.googleapis.com/drive/v3/files?${params.toString()}`, {
    headers: { Authorization: `Bearer ${accessToken}` }
  });

  if (!res.ok) {
    return null;
  }

  const body = await res.json();
  const first = Array.isArray(body.files) ? body.files[0] : null;
  return first?.id ? (first.id as string) : null;
}

async function createFolder(accessToken: string, name: string, parentId: string | null) {
  const metadata: Record<string, unknown> = {
    name,
    mimeType: DRIVE_FOLDER_MIME
  };

  if (parentId) {
    metadata.parents = [parentId];
  }

  const res = await fetch(
    "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&fields=id,name",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(metadata)
    }
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Google Drive folder create failed: ${res.status} ${errText}`);
  }

  const body = await res.json();
  if (!body.id) {
    throw new Error("Google Drive folder create returned no id");
  }

  return body.id as string;
}

async function maybeRefreshToken(
  admin: Admin,
  integrationId: string,
  refreshToken: string | null,
  expiresAt: string | null
) {
  if (!refreshToken) return null;

  if (expiresAt) {
    const expireMs = new Date(expiresAt).getTime();
    if (!Number.isNaN(expireMs) && expireMs - Date.now() > 2 * 60 * 1000) {
      return null;
    }
  }

  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");

  if (!clientId || !clientSecret) {
    return null;
  }

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: "refresh_token"
  });

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });

  if (!tokenRes.ok) {
    return null;
  }

  const tokenJson = await tokenRes.json();
  const accessToken = tokenJson.access_token as string;
  const expiresIn = Number(tokenJson.expires_in || 3600);

  if (!accessToken) return null;

  await admin
    .from("drive_integrations")
    .update({
      google_access_token: accessToken,
      google_token_expires_at: new Date(Date.now() + expiresIn * 1000).toISOString()
    })
    .eq("id", integrationId);

  return {
    access_token: accessToken,
    expires_in: expiresIn
  };
}

async function uploadToDrive(args: {
  accessToken: string;
  name: string;
  mimeType: string;
  base64: string;
  parentFolderId: string | null;
}) {
  const boundary = `nest-${crypto.randomUUID()}`;

  const metadata: Record<string, unknown> = {
    name: args.name
  };

  if (args.parentFolderId) {
    metadata.parents = [args.parentFolderId];
  }

  const bytes = base64ToBytes(args.base64);

  const body = new Blob([
    `--${boundary}\r\n`,
    "Content-Type: application/json; charset=UTF-8\r\n\r\n",
    JSON.stringify(metadata),
    "\r\n",
    `--${boundary}\r\n`,
    `Content-Type: ${args.mimeType}\r\n\r\n`,
    bytes,
    "\r\n",
    `--${boundary}--`
  ]);

  const uploadRes = await fetch(
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${args.accessToken}`,
        "Content-Type": `multipart/related; boundary=${boundary}`
      },
      body
    }
  );

  if (!uploadRes.ok) {
    const errText = await uploadRes.text();
    throw new Error(`Google Drive upload failed: ${uploadRes.status} ${errText}`);
  }

  return await uploadRes.json();
}

function base64ToBytes(base64: string) {
  const normalized = base64.replace(/\s/g, "");
  const raw = atob(normalized);
  const out = new Uint8Array(raw.length);

  for (let i = 0; i < raw.length; i += 1) {
    out[i] = raw.charCodeAt(i);
  }

  return out;
}
