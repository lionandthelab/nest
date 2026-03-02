import { corsHeaders } from "../_shared/cors.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  homeschool_id: string;
  upload_session_id: string;
  file_name: string;
  mime_type: string;
  file_base64: string;
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

    await assertRole(admin, payload.homeschool_id, user.id, [
      "HOMESCHOOL_ADMIN",
      "STAFF",
      "TEACHER",
      "GUEST_TEACHER"
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

    if (integration.status !== "CONNECTED") {
      return json(409, { error: "DRIVE_NOT_CONNECTED", details: "Integration is not connected" }, corsHeaders);
    }

    let accessToken = integration.google_access_token;

    if (!accessToken) {
      return json(409, { error: "DRIVE_ACCESS_TOKEN_MISSING" }, corsHeaders);
    }

    const refreshed = await maybeRefreshToken(admin, integration.id, integration.google_refresh_token, integration.google_token_expires_at);
    if (refreshed?.access_token) {
      accessToken = refreshed.access_token;
    }

    const uploadResult = await uploadToDrive({
      accessToken,
      name: payload.file_name,
      mimeType: payload.mime_type,
      base64: payload.file_base64,
      parentFolderId: integration.root_folder_id || null
    });

    await admin
      .from("media_upload_sessions")
      .update({ status: "UPLOADING" })
      .eq("id", payload.upload_session_id)
      .eq("homeschool_id", payload.homeschool_id);

    return json(
      200,
      {
        drive_file_id: uploadResult.id,
        drive_web_view_link: uploadResult.webViewLink || null,
        drive_name: uploadResult.name || payload.file_name
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

async function maybeRefreshToken(
  admin: ReturnType<typeof createAdminClient>,
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
