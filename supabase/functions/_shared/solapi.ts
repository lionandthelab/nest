// Solapi(알림톡/SMS) 발송 공용 모듈.
//
// ⚠️ 코드 중복에 대하여 — 이 파일의 HMAC 서명/전송 로직은
// `supabase/functions/lion-notify/index.ts` 와 사실상 동일하다. 의도된 중복이다.
// lion-notify 는 lion_auth 모듈의 **벤더링된 템플릿 원본**이라 각 서비스에서
// 수정하지 않는 것이 규칙이고(_shared 없이 자체 완결로 작성된 이유도 그것),
// 따라서 lion-notify 를 리팩터링해 이 모듈을 import 하게 만들 수 없다.
// 대신 서명 방식(HMAC-SHA256)과 엔드포인트를 lion-notify 와 **동일하게 유지**해
// 두 함수가 같은 Solapi 계정/발신번호로 문제없이 공존하도록 한다.
// lion-notify 의 Solapi 규약이 바뀌면 이 파일도 같이 맞춰야 한다.
//
// 필요 시크릿: SOLAPI_API_KEY, SOLAPI_API_SECRET, SOLAPI_SENDER(발신번호),
//              SOLAPI_PFID(카카오 발신프로필 — 알림톡 사용 시에만 필요)

/** 발송 채널. 'auto' 는 알림톡 시도 후 실패 시 SMS/LMS 자동 대체. */
export type SolapiChannel = "sms" | "alimtalk" | "auto";

export interface SolapiMessage {
  to: string;
  from: string;
  text?: string;
  kakaoOptions?: {
    pfId: string;
    templateId?: string;
    variables?: Record<string, string>;
    disableSms?: boolean;
  };
}

export interface SolapiSendResult {
  ok: boolean;
  messageId?: string;
  error?: string;
}

const SOLAPI_SEND_MANY_URL = "https://api.solapi.com/messages/v4/send-many";

const encoder = new TextEncoder();

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Solapi Authorization 헤더.
 * `HMAC-SHA256 apiKey=..., date=..., salt=..., signature=hmac(secret, date + salt)`
 */
export async function solapiAuthHeader(): Promise<string> {
  const apiKey = Deno.env.get("SOLAPI_API_KEY") ?? "";
  const apiSecret = Deno.env.get("SOLAPI_API_SECRET") ?? "";
  const date = new Date().toISOString();
  const salt = crypto.randomUUID().replace(/-/g, "");
  const signature = await hmacSha256Hex(apiSecret, date + salt);
  return `HMAC-SHA256 apiKey=${apiKey}, date=${date}, salt=${salt}, signature=${signature}`;
}

/** Solapi send-many 호출. 성공 시 groupId 를 messageId 로 돌려준다. */
export async function solapiSendMany(
  messages: SolapiMessage[]
): Promise<SolapiSendResult> {
  if (messages.length === 0) {
    return { ok: false, error: "발송할 메시지가 없습니다." };
  }

  const apiKey = Deno.env.get("SOLAPI_API_KEY") ?? "";
  const apiSecret = Deno.env.get("SOLAPI_API_SECRET") ?? "";
  if (!apiKey || !apiSecret) {
    return { ok: false, error: "Solapi 인증 정보(SOLAPI_API_KEY/SECRET)가 설정되지 않았습니다." };
  }

  let response: Response;
  try {
    response = await fetch(SOLAPI_SEND_MANY_URL, {
      method: "POST",
      headers: {
        Authorization: await solapiAuthHeader(),
        "Content-Type": "application/json; charset=utf-8"
      },
      body: JSON.stringify({ messages })
    });
  } catch (err) {
    return {
      ok: false,
      error: `Solapi 연결 실패: ${err instanceof Error ? err.message : String(err)}`
    };
  }

  const data = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok) {
    const errorMessage =
      (typeof data?.errorMessage === "string" ? data.errorMessage : undefined) ??
      (typeof data?.message === "string" ? data.message : undefined) ??
      `Solapi ${response.status}`;
    return { ok: false, error: errorMessage };
  }

  const groupInfo = data?.groupInfo as Record<string, unknown> | undefined;
  const messageId =
    (typeof data?.groupId === "string" ? data.groupId : undefined) ??
    (typeof groupInfo?.groupId === "string" ? groupInfo.groupId : undefined);

  return { ok: true, messageId };
}

export interface BuildSolapiMessagesArgs {
  channel: SolapiChannel;
  from: string;
  pfId: string;
  recipients: { phone: string }[];
  text: string;
  templateId?: string;
  variables?: Record<string, string>;
}

/**
 * 채널에 맞춰 Solapi 메시지 배열을 만든다.
 * - `sms`      : 순수 문자(길면 Solapi 가 자동으로 LMS 처리)
 * - `alimtalk` : 알림톡 전용(disableSms=true → 실패 시 대체 발송 없음)
 * - `auto`     : 알림톡 시도 후 실패 시 SMS/LMS 자동 대체
 */
export function buildSolapiMessages(args: BuildSolapiMessagesArgs): SolapiMessage[] {
  const { channel, from, pfId, recipients, text, templateId, variables } = args;

  return recipients.map((recipient) => {
    if (channel === "sms") {
      return { to: recipient.phone, from, text };
    }
    return {
      to: recipient.phone,
      from,
      text: text || undefined,
      kakaoOptions: {
        pfId,
        templateId,
        variables,
        disableSms: channel === "alimtalk"
      }
    };
  });
}

/**
 * 한국 휴대폰 번호 정규화.
 * 숫자만 남기고 `+82` / `82` 국가번호 접두를 `0` 으로 바꾼다.
 * 유효한 휴대폰 번호(`01[016789]` + 7~8자리)가 아니면 null 을 돌려준다.
 */
export function normalizePhone(raw: string | null | undefined): string | null {
  if (raw === null || raw === undefined) return null;

  let digits = String(raw).trim();
  if (digits.length === 0) return null;

  // 국가번호 접두 처리 전에 구분자만 제거한다.
  digits = digits.replace(/^\+/, "");
  digits = digits.replace(/\D/g, "");
  if (digits.length === 0) return null;

  if (digits.startsWith("82")) {
    const rest = digits.slice(2);
    digits = rest.startsWith("0") ? rest : `0${rest}`;
  }

  return /^01[016789]\d{7,8}$/.test(digits) ? digits : null;
}
