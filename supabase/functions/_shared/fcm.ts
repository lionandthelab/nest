import { JWT } from "npm:google-auth-library@9";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id?: string;
}

function parseServiceAccount(raw: string): ServiceAccount {
  try {
    return JSON.parse(raw);
  } catch {
    return JSON.parse(atob(raw));
  }
}

let cachedFcmToken: { token: string; exp: number } | null = null;

async function fcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedFcmToken && cachedFcmToken.exp - 60 > now) {
    return cachedFcmToken.token;
  }
  const client = new JWT({
    email: sa.client_email,
    key: sa.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { token } = await client.getAccessToken();
  if (!token) throw new Error("FCM 액세스 토큰 발급 실패");
  cachedFcmToken = { token, exp: now + 3300 };
  return token;
}

export interface DomainPushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendFcmToTokens(args: {
  tokens: Array<{ user_id: string; token: string; platform: string }>;
  payload: DomainPushPayload;
}): Promise<Array<{ userId: string; ok: boolean; name?: string; error?: string }>> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";
  if (!raw) {
    return args.tokens.map((row) => ({
      userId: row.user_id,
      ok: false,
      error: "FCM_SERVICE_ACCOUNT 미설정",
    }));
  }

  const sa = parseServiceAccount(raw);
  const projectId = Deno.env.get("FCM_PROJECT_ID") ?? sa.project_id ?? "";
  const accessToken = await fcmAccessToken(sa);
  const results = [];

  for (const row of args.tokens) {
    const message: Record<string, unknown> = {
      token: row.token,
      notification: { title: args.payload.title, body: args.payload.body },
    };
    if (args.payload.data && Object.keys(args.payload.data).length > 0) {
      message.data = args.payload.data;
    }
    if (row.platform === "android") message.android = { priority: "high" };
    if (row.platform === "ios") {
      message.apns = {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      };
    }
    if (row.platform === "web") {
      message.webpush = {
        notification: { title: args.payload.title, body: args.payload.body },
      };
    }

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      },
    );
    const data = await response.json().catch(() => ({}));
    results.push({
      userId: row.user_id,
      ok: response.ok,
      name: data?.name,
      error: response.ok ? undefined : data?.error?.message ?? `FCM ${response.status}`,
    });
  }
  return results;
}
