// nest-notify — Nest 도메인 이벤트 기반 알림 발송 (문자/알림톡, Solapi).
//
// 설계 원칙: 클라이언트는 **수신자를 지정하지 않는다.** 도메인 이벤트 `{event, id}`
// 만 보내고, 이 함수가 service_role 로 수신자를 해석하고 인가까지 직접 검증한다.
// (service_role 은 RLS 를 우회하므로 인가는 반드시 여기서 SQL 로 확인해야 한다.)
//
// 요청 계약 (POST, JSON):
//   { event: 'CLASS_CHANGE' | 'ABSENCE',
//     id: string,                       // uuid — class_session_changes.id / absence_reports.id
//     channel?: 'sms' | 'alimtalk' | 'auto',
//     force?: boolean }                 // true 면 notified_at 이 있어도 재발송
//
// 응답 (200):
//   { accepted: boolean, sent: number,
//     skipped_no_phone: number,         // 계정은 있으나 유효한 휴대폰 번호가 없음
//     skipped_no_account: number,       // 연결된 계정 자체가 없음(학생 미가입, 교사 미연결 등)
//     already_notified?: boolean,
//     message_id: string | null }
//
// 필요 시크릿: SOLAPI_API_KEY, SOLAPI_API_SECRET, SOLAPI_SENDER
//              SOLAPI_PFID (알림톡 전환 시에만 필요)
// 자동 주입: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// verify_jwt = true 로 배포한다(로그인 사용자만 호출).

import { corsHeaders } from "../_shared/cors.ts";
import { sendFcmToTokens } from "../_shared/fcm.ts";
import { createAdminClient, json, requireUser } from "../_shared/supabase.ts";
import {
  buildSolapiMessages,
  normalizePhone,
  solapiSendMany,
  type SolapiChannel
} from "../_shared/solapi.ts";

// ─────────────────────────────────────────────── 상수

/**
 * 기본 발송 채널.
 * 현재는 'sms'. 카카오 알림톡 템플릿 승인 + SOLAPI_PFID 설정이 끝나면
 * 이 값만 'auto' 로 바꾸면 알림톡(실패 시 문자 대체)으로 전환된다.
 */
const DEFAULT_CHANNEL: SolapiChannel = "sms";

/**
 * 알림톡 템플릿 코드.
 * TODO(알림톡): 카카오 비즈메시지 템플릿 승인 후 실제 템플릿 코드를 채운다.
 *               빈 문자열이면 templateId 를 보내지 않는다(문자 발송에는 영향 없음).
 */
const ALIMTALK_TEMPLATE_IDS: Record<NotifyEvent, string> = {
  CLASS_CHANGE: "",
  ABSENCE: ""
};

/** 1회 발송 상한(수신 계정 수). 초과하면 413 으로 거절한다. */
const MAX_RECIPIENTS = 300;

/** auth.users 메타데이터 조회 동시 실행 수. */
const AUTH_LOOKUP_CONCURRENCY = 10;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const DAY_LABELS = ["일", "월", "화", "수", "목", "금", "토"];

const ADMIN_ROLES = ["HOMESCHOOL_ADMIN", "STAFF"];

// ─────────────────────────────────────────────── 타입

type NotifyEvent = "CLASS_CHANGE" | "ABSENCE";

type Row = Record<string, unknown>;

type Admin = ReturnType<typeof createAdminClient>;

interface NotifyRequest {
  event?: string;
  id?: string;
  channel?: string;
  force?: boolean;
}

/**
 * 해석된 수신 대상.
 * - `userIds`  : 실제로 문자를 보낼 계정 uuid (중복 허용, dispatch 에서 dedupe)
 * - `noAccount`: 연결된 계정이 아예 없어 도달 불가한 대상 수
 *                (미가입 학생 + 보호자도 없음, user_id 미연결 교사 등)
 */
interface RecipientSet {
  userIds: string[];
  noAccount: number;
}

interface SessionContext {
  sessionId: string;
  classGroupId: string;
  classGroupName: string;
  termId: string;
  homeschoolId: string;
  mainTeacherProfileId: string | null;
  courseName: string;
  dayOfWeek: number | null;
  startTime: string;
  endTime: string;
  location: string | null;
}

interface MessagePayload {
  text: string;
  title?: string;
  templateId?: string;
  variables: Record<string, string>;
}

// ─────────────────────────────────────────────── 핸들러

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "허용되지 않는 메서드입니다." }, corsHeaders);
  }

  let admin: Admin;
  try {
    admin = createAdminClient();
  } catch (err) {
    console.error("[nest-notify] admin client 생성 실패:", err);
    return json(500, { error: "서버 설정이 올바르지 않습니다." }, corsHeaders);
  }

  let callerId: string;
  try {
    const user = await requireUser(req, admin);
    callerId = user.id;
  } catch {
    return json(401, { error: "로그인이 필요합니다." }, corsHeaders);
  }

  let body: NotifyRequest;
  try {
    body = (await req.json()) as NotifyRequest;
  } catch {
    return json(400, { error: "요청 본문(JSON)이 올바르지 않습니다." }, corsHeaders);
  }

  const event = body?.event;

  // TEST — 자기 자신에게만 보내는 확인용 푸시.
  //
  // 수신자를 클라이언트가 지정하지 않는다는 이 함수의 원칙을 지킨다. 대상은
  // 언제나 호출자 본인이고, 본문에 아무 것도 받지 않는다.
  //
  // 왜 필요한가: 알림은 "켰는데 안 오는" 경우가 가장 흔한 고장이다. 기기 권한,
  // 토큰 등록, 방해 금지 모드 중 어디서 막혔는지 사용자는 알 수 없고, 그냥
  // 앱이 고장났다고 여긴다. 직접 한 번 받아보게 해야 신뢰하고 켜 둔다.
  if (event === "TEST") {
    const sent = await pushToSelf(admin, callerId);
    return json(
      200,
      {
        accepted: true,
        sent,
        error: sent === 0
          ? "이 기기에 등록된 알림 토큰이 없습니다. 기기 알림 권한을 확인해 주세요."
          : null
      },
      corsHeaders
    );
  }

const SUPPORTED_EVENTS = new Set([
  "CLASS_CHANGE",
  "ABSENCE",
  "ABSENCE_ACK",
  "CHAT_MESSAGE",
  "ANNOUNCEMENT",
  "ACADEMIC_EVENT",
  "STUDENT_LOG",
  "TEACHING_PLAN",
  "COMMUNITY_POST",
  "COMMUNITY_COMMENT",
  "GALLERY_UPLOAD",
]);

  if (!event || !SUPPORTED_EVENTS.has(event)) {
    return json(
      400,
      {
        error:
          "지원하지 않는 event 입니다. (CLASS_CHANGE, ABSENCE, ABSENCE_ACK, CHAT_MESSAGE, ANNOUNCEMENT, ACADEMIC_EVENT, STUDENT_LOG, TEACHING_PLAN, COMMUNITY_POST, COMMUNITY_COMMENT, GALLERY_UPLOAD, TEST)",
      },
      corsHeaders
    );
  }

  const targetId = typeof body?.id === "string" ? body.id.trim() : "";
  if (!UUID_RE.test(targetId)) {
    return json(400, { error: "id 는 uuid 형식이어야 합니다." }, corsHeaders);
  }

  if (event === "CHAT_MESSAGE") {
    try {
      return await handleChatMessage(admin, callerId, targetId);
    } catch (err) {
      console.error("[nest-notify] CHAT_MESSAGE 처리 실패:", err);
      return json(500, { error: "채팅 알림 발송 처리 중 오류가 발생했습니다." }, corsHeaders);
    }
  }

  if (
    event === "ABSENCE_ACK" ||
    event === "ANNOUNCEMENT" ||
    event === "ACADEMIC_EVENT" ||
    event === "STUDENT_LOG" ||
    event === "TEACHING_PLAN" ||
    event === "COMMUNITY_POST" ||
    event === "COMMUNITY_COMMENT" ||
    event === "GALLERY_UPLOAD"
  ) {
    try {
      return await handlePurePushDomainEvent(admin, callerId, event, targetId);
    } catch (err) {
      console.error(`[nest-notify] ${event} 처리 실패:`, err);
      return json(500, { error: "푸시 알림 발송 처리 중 오류가 발생했습니다." }, corsHeaders);
    }
  }

  const requestedChannel = body?.channel ?? DEFAULT_CHANNEL;
  if (
    requestedChannel !== "sms" &&
    requestedChannel !== "alimtalk" &&
    requestedChannel !== "auto" &&
    requestedChannel !== "push"
  ) {
    return json(
      400,
      { error: "channel 은 'sms', 'alimtalk', 'auto', 'push' 중 하나여야 합니다." },
      corsHeaders
    );
  }
  const channel = requestedChannel;
  const force = body?.force === true;

  try {
    if (event === "CLASS_CHANGE") {
      return await handleClassChange(admin, callerId, targetId, channel as SolapiChannel, force);
    }
    return await handleAbsence(admin, callerId, targetId, channel as SolapiChannel, force);
  } catch (err) {
    console.error("[nest-notify] 처리 실패:", err);
    return json(500, { error: "알림 발송 처리 중 오류가 발생했습니다." }, corsHeaders);
  }
});

// ─────────────────────────────────────────────── 이벤트: 수업 변경

async function handleClassChange(
  admin: Admin,
  callerId: string,
  changeId: string,
  channel: SolapiChannel,
  force: boolean
): Promise<Response> {
  const changeResult = await admin
    .from("class_session_changes")
    .select("*")
    .eq("id", changeId)
    .maybeSingle();

  if (changeResult.error) {
    if (isMissingRelation(changeResult.error)) {
      return json(
        503,
        { error: "수업 변경 알림 기능이 아직 준비되지 않았습니다. 관리자에게 문의해 주세요." },
        corsHeaders
      );
    }
    throw new Error(`class_session_changes 조회 실패: ${changeResult.error.message}`);
  }

  const change = changeResult.data as Row | null;
  if (!change) {
    return json(404, { error: "수업 변경 정보를 찾을 수 없습니다." }, corsHeaders);
  }

  const sessionId = pickString(change, "class_session_id");
  if (!sessionId) {
    return json(422, { error: "수업 변경 정보에 연결된 수업이 없습니다." }, corsHeaders);
  }

  const ctx = await loadSessionContext(admin, sessionId);
  if (!ctx) {
    return json(404, { error: "수업 정보를 찾을 수 없습니다." }, corsHeaders);
  }

  // 인가: 담당 교사(MAIN/ASSISTANT) 또는 담임 또는 ADMIN/STAFF.
  const authorized = await canManageSession(admin, callerId, ctx);
  if (!authorized) {
    return json(403, { error: "이 수업의 변경 알림을 보낼 권한이 없습니다." }, corsHeaders);
  }

  if (!force && pickString(change, "notified_at")) {
    return json(
      200,
      {
        accepted: false,
        sent: 0,
        skipped_no_phone: 0,
        skipped_no_account: 0,
        already_notified: true,
        message_id: null
      },
      corsHeaders
    );
  }

  const recipients = await resolveClassChangeRecipients(admin, ctx);
  const message = await buildClassChangeMessage(admin, change, ctx);

  return await dispatch(admin, {
    callerId,
    channel,
    recipients,
    message,
    table: "class_session_changes",
    rowId: changeId,
    eventType: "CLASS_CHANGE"
  });
}

// ─────────────────────────────────────────────── 이벤트: 결석 신고

async function handleAbsence(
  admin: Admin,
  callerId: string,
  reportId: string,
  channel: SolapiChannel,
  force: boolean
): Promise<Response> {
  const reportResult = await admin
    .from("absence_reports")
    .select("*")
    .eq("id", reportId)
    .maybeSingle();

  if (reportResult.error) {
    if (isMissingRelation(reportResult.error)) {
      return json(
        503,
        { error: "결석 신고 알림 기능이 아직 준비되지 않았습니다. 관리자에게 문의해 주세요." },
        corsHeaders
      );
    }
    throw new Error(`absence_reports 조회 실패: ${reportResult.error.message}`);
  }

  const report = reportResult.data as Row | null;
  if (!report) {
    return json(404, { error: "결석 신고 정보를 찾을 수 없습니다." }, corsHeaders);
  }

  const sessionId = pickString(report, "class_session_id");
  const childId = pickString(report, "child_id");
  if (!sessionId || !childId) {
    return json(422, { error: "결석 신고 정보가 올바르지 않습니다." }, corsHeaders);
  }

  // 철회된 신고는 알리지 않는다.
  if (pickString(report, "status") === "CANCELED") {
    return json(422, { error: "철회된 결석 신고는 알릴 수 없습니다." }, corsHeaders);
  }

  const ctx = await loadSessionContext(admin, sessionId);
  if (!ctx) {
    return json(404, { error: "수업 정보를 찾을 수 없습니다." }, corsHeaders);
  }

  const childResult = await admin.from("children").select("*").eq("id", childId).maybeSingle();
  if (childResult.error) {
    throw new Error(`children 조회 실패: ${childResult.error.message}`);
  }
  const child = childResult.data as Row | null;
  if (!child) {
    return json(404, { error: "학생 정보를 찾을 수 없습니다." }, corsHeaders);
  }

  // 인가: 학생 본인 / 그 자녀의 보호자 / ADMIN·STAFF.
  const authorized = await canReportAbsence(admin, callerId, child, ctx.homeschoolId);
  if (!authorized) {
    return json(403, { error: "이 학생의 결석을 신고할 권한이 없습니다." }, corsHeaders);
  }

  if (!force && pickString(report, "notified_at")) {
    return json(
      200,
      {
        accepted: false,
        sent: 0,
        skipped_no_phone: 0,
        skipped_no_account: 0,
        already_notified: true,
        message_id: null
      },
      corsHeaders
    );
  }

  const recipients = await resolveAbsenceRecipients(admin, ctx, reportId);
  const message = buildAbsenceMessage(report, child, ctx);

  return await dispatch(admin, {
    callerId,
    channel,
    recipients,
    message,
    table: "absence_reports",
    rowId: reportId,
    eventType: "ABSENCE"
  });
}

// ─────────────────────────────────────────────── 공통 발송 파이프라인

interface DispatchArgs {
  callerId: string;
  channel: SolapiChannel;
  recipients: RecipientSet;
  message: MessagePayload;
  table: string;
  rowId: string;
  eventType: string;
}

async function dispatch(admin: Admin, args: DispatchArgs): Promise<Response> {
  const { callerId, channel, recipients, message, table, rowId, eventType } = args;

  // 계정이 아예 없는 대상(학생 미가입, 교사 계정 미연결 등).
  const skippedNoAccount = recipients.noAccount;

  // 수신자 uuid 중복 제거.
  const userIds = Array.from(new Set(recipients.userIds));

  if (userIds.length > MAX_RECIPIENTS) {
    return json(
      413,
      {
        error: `한 번에 보낼 수 있는 인원(${MAX_RECIPIENTS}명)을 초과했습니다. 대상을 나누어 발송해 주세요.`
      },
      corsHeaders
    );
  }

  const phoneByUserId = await lookupPhones(admin, userIds);
  const targets = userIds
    .map((userId) => ({ userId, phone: phoneByUserId.get(userId) ?? null }))
    .filter((t): t is { userId: string; phone: string } => t.phone !== null);

  const skippedNoPhone = userIds.length - targets.length;

  const pushTitle = message.title ?? message.text.split("\n")[0] ?? "네스트 알림";
  const pushSent = await sendDomainPush(admin, {
    callerId,
    userIds,
    title: pushTitle,
    body: message.text,
    eventType,
    rowId
  });

  // 푸시 전용 호출이거나 번호가 없어도 푸시가 나갔으면 성공으로 본다.
  if ((channel as string) === "push" || targets.length === 0) {
    return json(
      200,
      {
        accepted: pushSent > 0,
        sent: (channel as string) === "push" ? pushSent : 0,
        push_sent: pushSent,
        skipped_no_phone: skippedNoPhone,
        skipped_no_account: skippedNoAccount,
        message_id: null
      },
      corsHeaders
    );
  }

  const from = Deno.env.get("SOLAPI_SENDER") ?? "";
  if (!from) {
    console.error("[nest-notify] SOLAPI_SENDER 미설정");
    return json(500, { error: "발신번호가 설정되지 않았습니다." }, corsHeaders);
  }

  const pfId = Deno.env.get("SOLAPI_PFID") ?? "";
  if (channel !== "sms" && !pfId) {
    return json(
      400,
      { error: "알림톡 발신프로필이 설정되지 않아 알림톡을 보낼 수 없습니다." },
      corsHeaders
    );
  }

  const templateId =
    channel === "sms" || !message.templateId ? undefined : message.templateId;

  const solapiMessages = buildSolapiMessages({
    channel,
    from,
    pfId,
    recipients: targets.map((t) => ({ phone: t.phone })),
    text: message.text,
    templateId,
    variables: templateId ? message.variables : undefined
  });

  const result = await solapiSendMany(solapiMessages);

  // 수신자 1명당 1행 감사 로그.
  const logs = targets.map((t) => ({
    requested_by: callerId,
    to_user_id: t.userId,
    channel,
    template_id: templateId ?? null,
    status: result.ok ? "accepted" : "failed",
    provider_message_id: result.messageId ?? null,
    error: result.error ?? null,
    event_type: eventType,
    title: pushTitle,
    body: message.text
  }));
  const logResult = await admin.from("notification_log").insert(logs);
  if (logResult.error) {
    console.error("[nest-notify] notification_log 기록 실패:", logResult.error.message);
  }

  if (!result.ok) {
    return json(502, { error: `문자 발송에 실패했습니다: ${result.error}` }, corsHeaders);
  }

  const updateResult = await admin
    .from(table)
    .update({ notified_at: new Date().toISOString() })
    .eq("id", rowId);
  if (updateResult.error) {
    console.error(
      `[nest-notify] ${table}.notified_at 갱신 실패:`,
      updateResult.error.message
    );
  }

  return json(
    200,
    {
      accepted: true,
      sent: targets.length,
      push_sent: pushSent,
      skipped_no_phone: skippedNoPhone,
      skipped_no_account: skippedNoAccount,
      message_id: result.messageId ?? null
    },
    corsHeaders
  );
}

// ─────────────────────────────────────────────── 이벤트: 홈스쿨 채팅

async function handleChatMessage(
  admin: Admin,
  callerId: string,
  messageId: string
): Promise<Response> {
  const msgResult = await admin
    .from("homeschool_chat_messages")
    .select("*")
    .eq("id", messageId)
    .maybeSingle();

  if (msgResult.error) {
    if (isMissingRelation(msgResult.error)) {
      return json(
        503,
        { error: "채팅 알림 기능이 아직 준비되지 않았습니다." },
        corsHeaders
      );
    }
    throw new Error(`homeschool_chat_messages 조회 실패: ${msgResult.error.message}`);
  }

  const msg = msgResult.data as Row | null;
  if (!msg) {
    return json(404, { error: "채팅 메시지를 찾을 수 없습니다." }, corsHeaders);
  }

  const homeschoolId = pickString(msg, "homeschool_id");
  const senderUserId = pickString(msg, "sender_user_id");
  if (!homeschoolId || !senderUserId) {
    return json(422, { error: "채팅 메시지 정보가 올바르지 않습니다." }, corsHeaders);
  }

  // 발신자 본인 또는 관리자/스태프만 알림 발송을 트리거할 수 있다.
  const isSender = callerId === senderUserId;
  const memberOk = await isActiveMember(admin, homeschoolId, callerId);
  if (!memberOk || (!isSender && !(await isAdminOrStaff(admin, homeschoolId, callerId)))) {
    return json(403, { error: "채팅 알림을 보낼 권한이 없습니다." }, corsHeaders);
  }

  const recipientUserId = pickString(msg, "recipient_user_id");
  const classGroupId = pickString(msg, "class_group_id");
  const senderName = pickString(msg, "sender_name") ?? "구성원";
  const messageType = (pickString(msg, "message_type") ?? "TEXT").toUpperCase();
  const content = pickString(msg, "content") ?? "";
  const metadata = (msg.metadata && typeof msg.metadata === "object" && !Array.isArray(msg.metadata))
    ? (msg.metadata as Record<string, unknown>)
    : {};

  // 홈스쿨 이름 및 반 이름 조회
  const [hsResult, cgResult] = await Promise.all([
    admin.from("homeschools").select("name").eq("id", homeschoolId).maybeSingle(),
    classGroupId
      ? admin.from("class_groups").select("name").eq("id", classGroupId).maybeSingle()
      : Promise.resolve({ data: null, error: null })
  ]);
  const homeschoolName = pickString((hsResult.data as Row | null), "name") ?? "홈스쿨";
  const classGroupName = pickString((cgResult.data as Row | null), "name");

  // 수신자 목록 계산 (발신자 본인 제외)
  let targetUserIds: string[] = [];
  if (recipientUserId) {
    if (recipientUserId !== senderUserId) {
      targetUserIds = [recipientUserId];
    }
  } else {
    const memberSet = new Set<string>();
    const { data: memberships } = await admin
      .from("homeschool_memberships")
      .select("user_id")
      .eq("homeschool_id", homeschoolId)
      .eq("status", "ACTIVE");
    for (const row of (memberships ?? []) as Row[]) {
      const uid = pickString(row, "user_id");
      if (uid && uid !== senderUserId) memberSet.add(uid);
    }

    const { data: teachers } = await admin
      .from("teacher_profiles")
      .select("user_id")
      .eq("homeschool_id", homeschoolId);
    for (const row of (teachers ?? []) as Row[]) {
      const uid = pickString(row, "user_id");
      if (uid && uid !== senderUserId) memberSet.add(uid);
    }

    const { data: families } = await admin
      .from("families")
      .select("id")
      .eq("homeschool_id", homeschoolId);
    const familyIds = ((families ?? []) as Row[])
      .map((row) => pickString(row, "id"))
      .filter((v): v is string => !!v);
    if (familyIds.length > 0) {
      const { data: guardians } = await admin
        .from("family_guardians")
        .select("user_id")
        .in("family_id", familyIds);
      for (const row of (guardians ?? []) as Row[]) {
        const uid = pickString(row, "user_id");
        if (uid && uid !== senderUserId) memberSet.add(uid);
      }
    }

    targetUserIds = Array.from(memberSet);
  }

  let title = `[${homeschoolName} 채팅] ${senderName}`;
  if (recipientUserId) {
    title = `[${homeschoolName}] ${senderName}님의 1:1 메시지`;
  } else if (classGroupName) {
    title = `[${homeschoolName} · ${classGroupName}] ${senderName}`;
  }

  let bodyText = content;
  if (messageType === "IMAGE") {
    bodyText = content ? `📷 사진: ${content}` : "📷 사진을 공유했습니다.";
  } else if (messageType === "VIDEO") {
    bodyText = content ? `🎬 동영상: ${content}` : "🎬 동영상을 공유했습니다.";
  } else if (messageType === "SCHEDULE") {
    const scheduleTitle = typeof metadata.title === "string" && metadata.title.trim()
      ? metadata.title.trim()
      : (content || "새 일정");
    bodyText = `📅 일정 공유: ${scheduleTitle}`;
  } else if (messageType === "CONTACT") {
    const contactName = typeof metadata.contact_name === "string" && metadata.contact_name.trim()
      ? metadata.contact_name.trim()
      : (content || "연락처");
    bodyText = `👤 연락처 공유: ${contactName}`;
  } else if (messageType === "FILE") {
    bodyText = content ? `📎 파일: ${content}` : "📎 파일을 공유했습니다.";
  }
  if (!bodyText) {
    bodyText = "새 채팅 메시지가 도착했습니다.";
  }

  const pushSent = await sendDomainPush(admin, {
    callerId,
    userIds: targetUserIds,
    title,
    body: bodyText.slice(0, 180),
    eventType: "CHAT_MESSAGE",
    rowId: messageId,
    tab: "채팅"
  });

  return json(
    200,
    {
      accepted: true,
      sent: pushSent,
      push_sent: pushSent,
      skipped_no_phone: 0,
      skipped_no_account: 0,
      message_id: messageId
    },
    corsHeaders
  );
}

function prefColumnForEvent(eventType: string): string | null {
  switch (eventType) {
    case "CLASS_CHANGE":
      return "class_change_enabled";
    case "ABSENCE":
    case "ABSENCE_ACK":
      return "absence_enabled";
    case "ANNOUNCEMENT":
      return "announcement_enabled";
    case "ACADEMIC_EVENT":
      return "academic_event_enabled";
    case "STUDENT_LOG":
    case "TEACHING_PLAN":
      return "student_log_enabled";
    case "CHAT_MESSAGE":
      return "chat_enabled";
    case "COMMUNITY_POST":
    case "COMMUNITY_COMMENT":
      return "community_enabled";
    case "GALLERY_UPLOAD":
      return "gallery_enabled";
    default:
      return null;
  }
}

function nowMinutesInSeoul(): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "0";
  const h = Number(get("hour") === "24" ? "0" : get("hour")) || 0;
  const m = Number(get("minute")) || 0;
  return h * 60 + m;
}

function parseHhMmToMinutes(raw: unknown): number | null {
  if (typeof raw !== "string" || !raw.includes(":")) return null;
  const [hStr, mStr] = raw.trim().split(":");
  const h = Number(hStr);
  const m = Number(mStr);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  return h * 60 + m;
}

function isUserInQuietHours(row: Row, nowMinutes: number): boolean {
  const start = parseHhMmToMinutes(row.quiet_hours_start);
  const end = parseHhMmToMinutes(row.quiet_hours_end);
  if (start === null || end === null || start === end) return false;
  if (start < end) {
    return nowMinutes >= start && nowMinutes < end;
  }
  // 자정을 넘기는 방해금지 구간 (예: 21:00 ~ 07:00)
  return nowMinutes >= start || nowMinutes < end;
}

async function resolveAllHomeschoolUserIds(
  admin: Admin,
  homeschoolId: string,
  excludeUserId?: string
): Promise<string[]> {
  const memberSet = new Set<string>();
  const { data: memberships } = await admin
    .from("homeschool_memberships")
    .select("user_id")
    .eq("homeschool_id", homeschoolId)
    .eq("status", "ACTIVE");
  for (const row of (memberships ?? []) as Row[]) {
    const uid = pickString(row, "user_id");
    if (uid && uid !== excludeUserId) memberSet.add(uid);
  }

  const { data: teachers } = await admin
    .from("teacher_profiles")
    .select("user_id")
    .eq("homeschool_id", homeschoolId);
  for (const row of (teachers ?? []) as Row[]) {
    const uid = pickString(row, "user_id");
    if (uid && uid !== excludeUserId) memberSet.add(uid);
  }

  const { data: families } = await admin
    .from("families")
    .select("id")
    .eq("homeschool_id", homeschoolId);
  const familyIds = ((families ?? []) as Row[])
    .map((row) => pickString(row, "id"))
    .filter((v): v is string => !!v);
  if (familyIds.length > 0) {
    const [{ data: guardians }, { data: children }] = await Promise.all([
      admin.from("family_guardians").select("user_id").in("family_id", familyIds),
      admin.from("children").select("user_id").in("family_id", familyIds),
    ]);
    for (const row of (guardians ?? []) as Row[]) {
      const uid = pickString(row, "user_id");
      if (uid && uid !== excludeUserId) memberSet.add(uid);
    }
    for (const row of (children ?? []) as Row[]) {
      const uid = pickString(row, "user_id");
      if (uid && uid !== excludeUserId) memberSet.add(uid);
    }
  }
  return Array.from(memberSet);
}

async function resolveClassGroupUserIds(
  admin: Admin,
  classGroupId: string,
  excludeUserId?: string
): Promise<string[]> {
  const roster = await loadClassRoster(admin, classGroupId);
  const set = new Set<string>();
  for (const uid of roster.userIds) {
    if (uid && uid !== excludeUserId) set.add(uid);
  }
  const { data: sessions } = await admin
    .from("class_sessions")
    .select("id")
    .eq("class_group_id", classGroupId);
  const sessionIds = ((sessions ?? []) as Row[])
    .map((r) => pickString(r, "id"))
    .filter((v): v is string => !!v);
  if (sessionIds.length > 0) {
    const { data: assigns } = await admin
      .from("session_teacher_assignments")
      .select("teacher_profile_id")
      .in("class_session_id", sessionIds);
    const tpIds = ((assigns ?? []) as Row[])
      .map((r) => pickString(r, "teacher_profile_id"))
      .filter((v): v is string => !!v);
    if (tpIds.length > 0) {
      const { data: tps } = await admin
        .from("teacher_profiles")
        .select("user_id")
        .in("id", tpIds);
      for (const row of (tps ?? []) as Row[]) {
        const uid = pickString(row, "user_id");
        if (uid && uid !== excludeUserId) set.add(uid);
      }
    }
  }
  return Array.from(set);
}

async function handlePurePushDomainEvent(
  admin: Admin,
  callerId: string,
  event: string,
  targetId: string
): Promise<Response> {
  let targetUserIds: string[] = [];
  let title = "네스트 알림";
  let bodyText = "새로운 소식이 도착했습니다.";
  let tab = "홈";

  if (event === "ANNOUNCEMENT") {
    const { data: row } = await admin
      .from("announcements")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "공지사항을 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const homeschoolId = pickString(r, "homeschool_id") ?? "";
    const classGroupId = pickString(r, "class_group_id");
    const annTitle = pickString(r, "title") ?? "새 공지사항";
    const annBody = pickString(r, "body") ?? "";
    const [{ data: hs }, cg] = await Promise.all([
      admin.from("homeschools").select("name").eq("id", homeschoolId).maybeSingle(),
      classGroupId
        ? admin.from("class_groups").select("name").eq("id", classGroupId).maybeSingle()
        : Promise.resolve({ data: null }),
    ]);
    const hsName = pickString(hs as Row | null, "name") ?? "홈스쿨";
    const cgName = pickString(cg.data as Row | null, "name");
    title = cgName ? `[${hsName} · ${cgName} 공지] ${annTitle}` : `[${hsName} 공지] ${annTitle}`;
    bodyText = (annBody || annTitle).slice(0, 180);
    tab = "홈";
    targetUserIds = classGroupId
      ? await resolveClassGroupUserIds(admin, classGroupId, callerId)
      : await resolveAllHomeschoolUserIds(admin, homeschoolId, callerId);
  } else if (event === "ACADEMIC_EVENT") {
    const { data: row } = await admin
      .from("academic_events")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "학사 일정을 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const homeschoolId = pickString(r, "homeschool_id") ?? "";
    const evTitle = pickString(r, "title") ?? "새 학사 일정";
    const evDate = pickString(r, "event_date") ?? "";
    const endDate = pickString(r, "end_date");
    const desc = pickString(r, "description") ?? "";
    const { data: hs } = await admin
      .from("homeschools")
      .select("name")
      .eq("id", homeschoolId)
      .maybeSingle();
    const hsName = pickString(hs as Row | null, "name") ?? "홈스쿨";
    title = `[${hsName} 학사일정] ${evTitle}`;
    const dateRange = endDate ? `${evDate} ~ ${endDate}` : evDate;
    bodyText = [dateRange, desc].filter(Boolean).join(" · ").slice(0, 180) || evTitle;
    tab = "시간표";
    targetUserIds = await resolveAllHomeschoolUserIds(admin, homeschoolId, callerId);
  } else if (event === "STUDENT_LOG") {
    const { data: row } = await admin
      .from("student_activity_logs")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "활동 기록을 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const childId = pickString(r, "child_id") ?? "";
    const content = pickString(r, "content") ?? "";
    const teacherId = pickString(r, "recorded_by_teacher_id");
    const [{ data: child }, teacherRes] = await Promise.all([
      admin.from("children").select("name, family_id, user_id").eq("id", childId).maybeSingle(),
      teacherId
        ? admin.from("teacher_profiles").select("display_name").eq("id", teacherId).maybeSingle()
        : Promise.resolve({ data: null }),
    ]);
    const cRow = child as Row | null;
    const childName = pickString(cRow, "name") ?? "학생";
    const teacherName = pickString(teacherRes.data as Row | null, "display_name");
    const familyId = pickString(cRow, "family_id");
    const recipientSet = new Set<string>();
    const studentUid = pickString(cRow, "user_id");
    if (studentUid && studentUid !== callerId) recipientSet.add(studentUid);
    if (familyId) {
      const { data: guardians } = await admin
        .from("family_guardians")
        .select("user_id")
        .eq("family_id", familyId);
      for (const g of (guardians ?? []) as Row[]) {
        const uid = pickString(g, "user_id");
        if (uid && uid !== callerId) recipientSet.add(uid);
      }
    }
    title = teacherName
      ? `[${childName} 활동 기록] ${teacherName} 선생님의 새 기록`
      : `[${childName} 활동 기록] 새 수업 기록이 등록되었어요`;
    bodyText = content.slice(0, 180) || "앱에서 아이의 오늘 활동 기록을 확인해 보세요.";
    tab = "홈";
    targetUserIds = Array.from(recipientSet);
  } else if (event === "TEACHING_PLAN") {
    const { data: row } = await admin
      .from("teaching_plans")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "수업 계획을 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const sessionId = pickString(r, "class_session_id") ?? "";
    const objectives = pickString(r, "objectives") ?? "";
    const ctx = await loadSessionContext(admin, sessionId);
    if (!ctx) {
      return json(404, { error: "수업 정보를 찾을 수 없습니다." }, corsHeaders);
    }
    title = `[${ctx.classGroupName} · ${ctx.courseName}] 새 수업 계획 등록`;
    bodyText = objectives.slice(0, 180) || "새 수업 계획과 준비물을 확인해 보세요.";
    tab = "시간표";
    targetUserIds = await resolveClassGroupUserIds(admin, ctx.classGroupId, callerId);
  } else if (event === "ABSENCE_ACK") {
    const { data: row } = await admin
      .from("absence_reports")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "결석 신고를 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const sessionId = pickString(r, "class_session_id") ?? "";
    const childId = pickString(r, "child_id") ?? "";
    const occDate = pickString(r, "occurrence_date") ?? "";
    const reportedBy = pickString(r, "reported_by_user_id");
    const [ctx, { data: child }] = await Promise.all([
      loadSessionContext(admin, sessionId),
      admin.from("children").select("name, family_id, user_id").eq("id", childId).maybeSingle(),
    ]);
    const cRow = child as Row | null;
    const childName = pickString(cRow, "name") ?? "학생";
    const courseName = ctx?.courseName ?? "수업";
    const recipientSet = new Set<string>();
    if (reportedBy && reportedBy !== callerId) recipientSet.add(reportedBy);
    const studentUid = pickString(cRow, "user_id");
    if (studentUid && studentUid !== callerId) recipientSet.add(studentUid);
    const familyId = pickString(cRow, "family_id");
    if (familyId) {
      const { data: guardians } = await admin
        .from("family_guardians")
        .select("user_id")
        .eq("family_id", familyId);
      for (const g of (guardians ?? []) as Row[]) {
        const uid = pickString(g, "user_id");
        if (uid && uid !== callerId) recipientSet.add(uid);
      }
    }
    title = `[결석 신고 확인] ${childName} (${courseName})`;
    bodyText = `${occDate} ${courseName} 수업 결석 신고를 담당 선생님이 확인했습니다.`;
    tab = "시간표";
    targetUserIds = Array.from(recipientSet);
  } else if (event === "COMMUNITY_POST") {
    const { data: row } = await admin
      .from("community_posts")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!row) {
      return json(404, { error: "게시글을 찾을 수 없습니다." }, corsHeaders);
    }
    const r = row as Row;
    const homeschoolId = pickString(r, "homeschool_id") ?? "";
    const classGroupId = pickString(r, "class_group_id");
    const authorName = pickString(r, "author_display_name") ?? "구성원";
    const content = pickString(r, "content") ?? "";
    const { data: hs } = await admin
      .from("homeschools")
      .select("name")
      .eq("id", homeschoolId)
      .maybeSingle();
    const hsName = pickString(hs as Row | null, "name") ?? "홈스쿨";
    title = `[${hsName} 커뮤니티] ${authorName}님의 새 글`;
    bodyText = content.slice(0, 180) || "커뮤니티에 새 게시글이 올라왔습니다.";
    tab = "커뮤니티";
    targetUserIds = classGroupId
      ? await resolveClassGroupUserIds(admin, classGroupId, callerId)
      : await resolveAllHomeschoolUserIds(admin, homeschoolId, callerId);
  } else if (event === "COMMUNITY_COMMENT") {
    const { data: post } = await admin
      .from("community_posts")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!post) {
      return json(404, { error: "게시글을 찾을 수 없습니다." }, corsHeaders);
    }
    const pRow = post as Row;
    const postAuthorId = pickString(pRow, "author_user_id");
    const { data: comments } = await admin
      .from("community_post_comments")
      .select("author_user_id, author_display_name, content, created_at")
      .eq("post_id", targetId)
      .order("created_at", { ascending: false })
      .limit(25);
    const cRows = (comments ?? []) as Row[];
    const latest = cRows[0];
    const commenterName = pickString(latest, "author_display_name") ?? "구성원";
    const commentText = pickString(latest, "content") ?? "새 댓글이 달렸습니다.";
    const recipientSet = new Set<string>();
    if (postAuthorId && postAuthorId !== callerId) recipientSet.add(postAuthorId);
    for (const c of cRows) {
      const uid = pickString(c, "author_user_id");
      if (uid && uid !== callerId) recipientSet.add(uid);
    }
    title = `[커뮤니티 댓글] ${commenterName}님이 댓글을 남겼어요`;
    bodyText = commentText.slice(0, 180);
    tab = "커뮤니티";
    targetUserIds = Array.from(recipientSet);
  } else if (event === "GALLERY_UPLOAD") {
    const { data: media } = await admin
      .from("media_assets")
      .select("*")
      .eq("id", targetId)
      .maybeSingle();
    if (!media) {
      return json(404, { error: "앨범 미디어를 찾을 수 없습니다." }, corsHeaders);
    }
    const mRow = media as Row;
    const homeschoolId = pickString(mRow, "homeschool_id") ?? "";
    const classGroupId = pickString(mRow, "class_group_id");
    const mediaType = (pickString(mRow, "media_type") ?? "PHOTO").toUpperCase();
    const desc = pickString(mRow, "description") || pickString(mRow, "title") || "";
    const { data: hs } = await admin
      .from("homeschools")
      .select("name")
      .eq("id", homeschoolId)
      .maybeSingle();
    const hsName = pickString(hs as Row | null, "name") ?? "홈스쿨";
    title = `[${hsName} 추억 앨범] 새 ${mediaType === "VIDEO" ? "동영상" : "사진"}이 올라왔어요`;
    bodyText = (desc || "추억 앨범에서 새로 올라온 사진·영상을 확인해 보세요.").slice(0, 180);
    tab = "앨범";
    targetUserIds = classGroupId
      ? await resolveClassGroupUserIds(admin, classGroupId, callerId)
      : await resolveAllHomeschoolUserIds(admin, homeschoolId, callerId);
  }

  const pushSent = await sendDomainPush(admin, {
    callerId,
    userIds: targetUserIds,
    title,
    body: bodyText,
    eventType: event,
    rowId: targetId,
    tab,
  });

  return json(
    200,
    {
      accepted: true,
      sent: pushSent,
      push_sent: pushSent,
      skipped_no_phone: 0,
      skipped_no_account: 0,
      message_id: targetId,
    },
    corsHeaders
  );
}

async function sendDomainPush(
  admin: Admin,
  args: {
    callerId: string;
    userIds: string[];
    title: string;
    body: string;
    eventType: string;
    rowId: string;
    tab?: string;
  }
): Promise<number> {
  if (args.userIds.length === 0) return 0;
  try {
    let prefsRows: Row[] = [];
    const { data: fullPrefs, error: prefsErr } = await admin
      .from("notification_prefs")
      .select("*")
      .in("user_id", args.userIds);
    if (!prefsErr && fullPrefs) {
      prefsRows = fullPrefs as Row[];
    } else {
      const { data: basicPrefs } = await admin
        .from("notification_prefs")
        .select("user_id, push_enabled, quiet_hours_start, quiet_hours_end")
        .in("user_id", args.userIds);
      prefsRows = (basicPrefs ?? []) as Row[];
    }

    const prefCol = prefColumnForEvent(args.eventType);
    const nowMinutes = nowMinutesInSeoul();
    const disabled = new Set<string>();
    const quietHoursUsers = new Set<string>();

    for (const row of prefsRows) {
      const uid = pickString(row, "user_id");
      if (!uid) continue;
      if (row.push_enabled === false) {
        disabled.add(uid);
        continue;
      }
      if (prefCol && row[prefCol] === false) {
        disabled.add(uid);
        continue;
      }
      if (isUserInQuietHours(row, nowMinutes)) {
        quietHoursUsers.add(uid);
      }
    }

    const allowed = [...new Set(args.userIds.filter((id) => !disabled.has(id)))];
    if (allowed.length === 0) return 0;

    // 방해금지 시간이 아닌 사용자에게만 실시간 기기 푸시(FCM)를 발송하고,
    // 방해금지 시간 중인 사용자에게는 앱 내 알림함(inbox_only)으로만 조용히 기록한다.
    const fcmEligibleUserIds = allowed.filter((id) => !quietHoursUsers.has(id));

    const { data: tokens } = fcmEligibleUserIds.length > 0
      ? await admin
          .from("push_tokens")
          .select("user_id, token, platform")
          .in("user_id", fcmEligibleUserIds)
          .is("revoked_at", null)
      : { data: [] };

    const activeTokens = (tokens ?? []) as Array<{
      user_id: string;
      token: string;
      platform: string;
    }>;
    const usersWithTokens = new Set(activeTokens.map((t) => t.user_id));
    const payloadData = {
      event: args.eventType,
      id: args.rowId,
      tab: args.tab ?? "시간표"
    };

    const results = activeTokens.length > 0
      ? await sendFcmToTokens({
        tokens: activeTokens,
        payload: {
          title: args.title,
          body: args.body,
          data: payloadData
        }
      })
      : [];

    // 만료/삭제된 FCM 토큰(UNREGISTERED)은 즉시 폐기 처리하여 다음 발송 지연을 막는다.
    const deadTokens = results
      .filter((r) => r.unregistered && r.token)
      .map((r) => r.token);
    if (deadTokens.length > 0) {
      await admin
        .from("push_tokens")
        .update({ revoked_at: new Date().toISOString() })
        .in("token", deadTokens);
    }

    const fcmLogs = results.map((result) => ({
      requested_by: args.callerId,
      to_user_id: result.userId,
      channel: "push",
      status: result.ok ? "accepted" : "failed",
      provider_message_id: result.name ?? null,
      error: result.error ?? null,
      event_type: args.eventType,
      title: args.title,
      body: args.body,
      payload: payloadData
    }));

    const inboxOnlyUserIds = allowed.filter((id) => !usersWithTokens.has(id));
    const inboxOnlyLogs = inboxOnlyUserIds.map((userId) => ({
      requested_by: args.callerId,
      to_user_id: userId,
      channel: "push",
      status: "inbox_only",
      provider_message_id: null,
      error: null,
      event_type: args.eventType,
      title: args.title,
      body: args.body,
      payload: payloadData
    }));

    const logs = [...fcmLogs, ...inboxOnlyLogs];
    if (logs.length > 0) {
      const { error } = await admin.from("notification_log").insert(logs);
      if (error) console.error("[nest-notify] push log", error.message);
    }
    return results.filter((result) => result.ok).length + inboxOnlyUserIds.length;
  } catch (error) {
    console.error("[nest-notify] push", error);
    return 0;
  }
}

// ─────────────────────────────────────────────── 수신자 해석

async function resolveClassChangeRecipients(
  admin: Admin,
  ctx: SessionContext
): Promise<RecipientSet> {
  // 반 명부는 항상 읽는다. RPC 는 "보낼 수 있는 계정"만 돌려주므로
  // 도달 불가 인원(noAccount)은 명부에서 직접 세어야 정확하다.
  const roster = await loadClassRoster(admin, ctx.classGroupId);

  const viaRpc = await tryRecipientsRpc(admin, "recipients_for_class_session", {
    p_class_session_id: ctx.sessionId
  });

  return { userIds: viaRpc ?? roster.userIds, noAccount: roster.noAccount };
}

/** 반 수강생 → 학생 계정 + 가정 보호자 계정, 그리고 도달 불가 인원 수. */
async function loadClassRoster(
  admin: Admin,
  classGroupId: string
): Promise<RecipientSet> {
  const enrollments = await admin
    .from("class_enrollments")
    .select("child_id")
    .eq("class_group_id", classGroupId);
  if (enrollments.error) {
    throw new Error(`class_enrollments 조회 실패: ${enrollments.error.message}`);
  }

  const childIds = Array.from(
    new Set(
      (enrollments.data ?? [])
        .map((row) => pickString(row as Row, "child_id"))
        .filter((v): v is string => !!v)
    )
  );
  if (childIds.length === 0) return { userIds: [], noAccount: 0 };

  const childrenResult = await admin.from("children").select("*").in("id", childIds);
  if (childrenResult.error) {
    throw new Error(`children 조회 실패: ${childrenResult.error.message}`);
  }
  const children = ((childrenResult.data ?? []) as Row[]).filter(
    (row) => pickString(row, "status") !== "INACTIVE"
  );

  const familyIds = Array.from(
    new Set(
      children.map((row) => pickString(row, "family_id")).filter((v): v is string => !!v)
    )
  );

  const guardiansByFamily = new Map<string, string[]>();
  if (familyIds.length > 0) {
    const guardians = await admin
      .from("family_guardians")
      .select("family_id, user_id")
      .in("family_id", familyIds);
    if (guardians.error) {
      throw new Error(`family_guardians 조회 실패: ${guardians.error.message}`);
    }
    for (const row of (guardians.data ?? []) as Row[]) {
      const familyId = pickString(row, "family_id");
      const userId = pickString(row, "user_id");
      if (!familyId || !userId) continue;
      const list = guardiansByFamily.get(familyId) ?? [];
      list.push(userId);
      guardiansByFamily.set(familyId, list);
    }
  }

  const userIds: string[] = [];
  let noAccount = 0;
  for (const child of children) {
    const familyId = pickString(child, "family_id");
    // children.user_id = 학생 계정 연결 컬럼(20260814091000).
    const studentUserId = pickString(child, "user_id");
    const guardianIds = familyId ? (guardiansByFamily.get(familyId) ?? []) : [];

    if (studentUserId) userIds.push(studentUserId);
    userIds.push(...guardianIds);

    // 학생 계정도 없고 보호자 계정도 없으면 이 학생에게는 도달할 방법이 없다.
    if (!studentUserId && guardianIds.length === 0) noAccount += 1;
  }

  return { userIds, noAccount };
}

async function resolveAbsenceRecipients(
  admin: Admin,
  ctx: SessionContext,
  reportId: string
): Promise<RecipientSet> {
  const teachers = await loadSessionTeachers(admin, ctx);

  const viaRpc = await tryRecipientsRpc(admin, "recipients_for_absence_report", {
    p_report_id: reportId
  });

  return { userIds: viaRpc ?? teachers.userIds, noAccount: teachers.noAccount };
}

/** 담당 교사(MAIN/ASSISTANT). 배정이 없으면 담임으로 대체. */
async function loadSessionTeachers(
  admin: Admin,
  ctx: SessionContext
): Promise<RecipientSet> {
  const assignments = await admin
    .from("session_teacher_assignments")
    .select("teacher_profile_id")
    .eq("class_session_id", ctx.sessionId);
  if (assignments.error) {
    throw new Error(`session_teacher_assignments 조회 실패: ${assignments.error.message}`);
  }

  const profileIds = Array.from(
    new Set(
      (assignments.data ?? [])
        .map((row) => pickString(row as Row, "teacher_profile_id"))
        .filter((v): v is string => !!v)
    )
  );
  if (profileIds.length === 0 && ctx.mainTeacherProfileId) {
    profileIds.push(ctx.mainTeacherProfileId);
  }
  if (profileIds.length === 0) return { userIds: [], noAccount: 0 };

  const profiles = await admin
    .from("teacher_profiles")
    .select("id, user_id")
    .in("id", profileIds);
  if (profiles.error) {
    throw new Error(`teacher_profiles 조회 실패: ${profiles.error.message}`);
  }

  const userIds: string[] = [];
  let noAccount = 0;
  for (const row of (profiles.data ?? []) as Row[]) {
    const userId = pickString(row, "user_id");
    if (userId) userIds.push(userId);
    // 엑셀에서 만들어진 교사 프로필은 계정이 연결되지 않은 경우가 있다.
    else noAccount += 1;
  }

  return { userIds, noAccount };
}

/**
 * 수신자 해석 RPC 호출. 아직 배포되지 않았거나 실패하면 null 을 돌려주고
 * 호출부가 동등한 인라인 조인 결과로 폴백한다.
 *
 * RPC 계약: `returns table (user_id uuid, recipient_kind text)`
 * — 계정이 연결된 대상만 돌려주므로 도달 불가 인원 수는 호출부가 따로 센다.
 */
async function tryRecipientsRpc(
  admin: Admin,
  fn: string,
  params: Record<string, string>
): Promise<string[] | null> {
  const { data, error } = await admin.rpc(fn, params);
  if (error) {
    if (!isMissingFunction(error)) {
      console.error(`[nest-notify] ${fn} 실패, 폴백 사용:`, error.message);
    }
    return null;
  }
  if (!Array.isArray(data)) return null;

  return (data as Row[])
    .map((row) => pickString(row, "user_id"))
    .filter((v): v is string => !!v);
}

// ─────────────────────────────────────────────── 전화번호 조회

/**
 * 수신자 uuid → 정규화된 휴대폰 번호.
 * 1차로 profiles.phone 을 보고, 비어 있으면 auth.users 메타데이터
 * (raw_user_meta_data->>'phone_number')로 폴백한다. 실제 데이터는 대부분
 * 후자에 들어 있다.
 */
async function lookupPhones(admin: Admin, userIds: string[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  if (userIds.length === 0) return result;

  const profiles = await admin.from("profiles").select("id, phone").in("id", userIds);
  if (profiles.error) {
    throw new Error(`profiles 조회 실패: ${profiles.error.message}`);
  }
  for (const row of (profiles.data ?? []) as Row[]) {
    const id = pickString(row, "id");
    const phone = normalizePhone(pickString(row, "phone"));
    if (id && phone) result.set(id, phone);
  }

  const missing = userIds.filter((id) => !result.has(id));
  for (let i = 0; i < missing.length; i += AUTH_LOOKUP_CONCURRENCY) {
    const chunk = missing.slice(i, i + AUTH_LOOKUP_CONCURRENCY);
    const found = await Promise.all(chunk.map((id) => lookupAuthPhone(admin, id)));
    chunk.forEach((id, index) => {
      const phone = found[index];
      if (phone) result.set(id, phone);
    });
  }

  return result;
}

async function lookupAuthPhone(admin: Admin, userId: string): Promise<string | null> {
  try {
    const { data, error } = await admin.auth.admin.getUserById(userId);
    if (error || !data?.user) return null;
    const meta = (data.user.user_metadata ?? {}) as Record<string, unknown>;
    return (
      normalizePhone(typeof meta.phone_number === "string" ? meta.phone_number : null) ??
      normalizePhone(typeof meta.phone === "string" ? meta.phone : null) ??
      normalizePhone(data.user.phone ?? null)
    );
  } catch (err) {
    console.error("[nest-notify] auth 사용자 조회 실패:", err);
    return null;
  }
}

// ─────────────────────────────────────────────── 인가

async function isAdminOrStaff(
  admin: Admin,
  homeschoolId: string,
  userId: string
): Promise<boolean> {
  const { data, error } = await admin
    .from("homeschool_memberships")
    .select("id")
    .eq("homeschool_id", homeschoolId)
    .eq("user_id", userId)
    .eq("status", "ACTIVE")
    .in("role", ADMIN_ROLES)
    .limit(1);
  if (error) {
    throw new Error(`homeschool_memberships 조회 실패: ${error.message}`);
  }
  return (data ?? []).length > 0;
}

/** 호출자가 이 홈스쿨의 ACTIVE 구성원인지(역할 무관). */
async function isActiveMember(
  admin: Admin,
  homeschoolId: string,
  userId: string
): Promise<boolean> {
  const { data, error } = await admin
    .from("homeschool_memberships")
    .select("id")
    .eq("homeschool_id", homeschoolId)
    .eq("user_id", userId)
    .eq("status", "ACTIVE")
    .limit(1);
  if (error) {
    throw new Error(`homeschool_memberships 조회 실패: ${error.message}`);
  }
  return (data ?? []).length > 0;
}

/**
 * 호출자의 교사 프로필 id 목록.
 *
 * ⚠️ ACTIVE 멤버십을 함께 요구한다. teacher_profiles.user_id 는 멤버십을 지워도
 * 남기 때문에(정리 트리거 없음), 이 확인이 없으면 홈스쿨을 떠난 교사가 여전히
 * 담당 수업 판정을 통과해 그 반 전체 학부모에게 문자를 보낼 수 있다.
 * DB 쪽 is_session_teacher() 의 조건과 일치시킨 것이다.
 */
async function callerTeacherProfileIds(
  admin: Admin,
  homeschoolId: string,
  userId: string
): Promise<string[]> {
  if (!(await isActiveMember(admin, homeschoolId, userId))) return [];

  const { data, error } = await admin
    .from("teacher_profiles")
    .select("id")
    .eq("homeschool_id", homeschoolId)
    .eq("user_id", userId);
  if (error) {
    throw new Error(`teacher_profiles 조회 실패: ${error.message}`);
  }
  return ((data ?? []) as Row[])
    .map((row) => pickString(row, "id"))
    .filter((v): v is string => !!v);
}

/** 담당 교사(MAIN/ASSISTANT) 또는 담임 또는 ADMIN/STAFF 인지 확인. */
async function canManageSession(
  admin: Admin,
  callerId: string,
  ctx: SessionContext
): Promise<boolean> {
  if (await isAdminOrStaff(admin, ctx.homeschoolId, callerId)) return true;

  const profileIds = await callerTeacherProfileIds(admin, ctx.homeschoolId, callerId);
  if (profileIds.length === 0) return false;

  if (ctx.mainTeacherProfileId && profileIds.includes(ctx.mainTeacherProfileId)) {
    return true;
  }

  const { data, error } = await admin
    .from("session_teacher_assignments")
    .select("id")
    .eq("class_session_id", ctx.sessionId)
    .in("teacher_profile_id", profileIds)
    .limit(1);
  if (error) {
    throw new Error(`session_teacher_assignments 조회 실패: ${error.message}`);
  }
  return (data ?? []).length > 0;
}

/** 학생 본인 / 보호자 / ADMIN·STAFF 인지 확인. */
async function canReportAbsence(
  admin: Admin,
  callerId: string,
  child: Row,
  homeschoolId: string
): Promise<boolean> {
  if (pickString(child, "user_id") === callerId) return true;

  const familyId = pickString(child, "family_id");
  if (familyId) {
    const { data, error } = await admin
      .from("family_guardians")
      .select("id")
      .eq("family_id", familyId)
      .eq("user_id", callerId)
      .limit(1);
    if (error) {
      throw new Error(`family_guardians 조회 실패: ${error.message}`);
    }
    if ((data ?? []).length > 0) return true;
  }

  return await isAdminOrStaff(admin, homeschoolId, callerId);
}

// ─────────────────────────────────────────────── 수업 컨텍스트

async function loadSessionContext(
  admin: Admin,
  sessionId: string
): Promise<SessionContext | null> {
  const sessionResult = await admin
    .from("class_sessions")
    .select("id, class_group_id, course_id, time_slot_id, title, location")
    .eq("id", sessionId)
    .maybeSingle();
  if (sessionResult.error) {
    throw new Error(`class_sessions 조회 실패: ${sessionResult.error.message}`);
  }
  const session = sessionResult.data as Row | null;
  if (!session) return null;

  const classGroupId = pickString(session, "class_group_id");
  const courseId = pickString(session, "course_id");
  const timeSlotId = pickString(session, "time_slot_id");
  if (!classGroupId) return null;

  const [groupResult, courseResult, slotResult] = await Promise.all([
    admin
      .from("class_groups")
      .select("id, name, term_id, main_teacher_id")
      .eq("id", classGroupId)
      .maybeSingle(),
    courseId
      ? admin.from("courses").select("id, name").eq("id", courseId).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    timeSlotId
      ? admin
          .from("time_slots")
          .select("id, day_of_week, start_time, end_time")
          .eq("id", timeSlotId)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null })
  ]);

  if (groupResult.error) {
    throw new Error(`class_groups 조회 실패: ${groupResult.error.message}`);
  }
  const group = groupResult.data as Row | null;
  if (!group) return null;

  const termId = pickString(group, "term_id");
  if (!termId) return null;

  const termResult = await admin
    .from("terms")
    .select("id, homeschool_id")
    .eq("id", termId)
    .maybeSingle();
  if (termResult.error) {
    throw new Error(`terms 조회 실패: ${termResult.error.message}`);
  }
  const term = termResult.data as Row | null;
  const homeschoolId = term ? pickString(term, "homeschool_id") : null;
  if (!homeschoolId) return null;

  const course = (courseResult.data ?? null) as Row | null;
  const slot = (slotResult.data ?? null) as Row | null;

  return {
    sessionId,
    classGroupId,
    classGroupName: pickString(group, "name") ?? "",
    termId,
    homeschoolId,
    mainTeacherProfileId: pickString(group, "main_teacher_id"),
    courseName: (course ? pickString(course, "name") : null) ?? pickString(session, "title") ?? "수업",
    dayOfWeek: slot ? pickNumber(slot, "day_of_week") : null,
    startTime: formatTime(slot ? pickString(slot, "start_time") : null),
    endTime: formatTime(slot ? pickString(slot, "end_time") : null),
    location: pickString(session, "location")
  };
}

// ─────────────────────────────────────────────── 메시지 조립
//
// 알림톡 전환 대비: 본문 텍스트와 템플릿 변수를 한 번에 만들어 돌려준다.
// 알림톡 템플릿이 승인되면 ALIMTALK_TEMPLATE_IDS 에 코드만 채우면 된다.

async function buildClassChangeMessage(
  admin: Admin,
  change: Row,
  ctx: SessionContext
): Promise<MessagePayload> {
  const changeType = normalizeChangeType(
    pickString(change, "change_type", "kind", "type")
  );
  const from = pickString(change, "effective_from");
  const to = pickString(change, "effective_to");
  const reason = pickString(change, "reason", "note", "memo");
  const period = periodText(from, to);
  const dayLabel = ctx.dayOfWeek === null ? "" : `${DAY_LABELS[ctx.dayOfWeek] ?? ""}요일`;
  const timeRange = ctx.startTime && ctx.endTime ? `${ctx.startTime}-${ctx.endTime}` : "";
  const when = [period, dayLabel, timeRange].filter((v) => v.length > 0).join(" ");
  const classLabel = [ctx.classGroupName, ctx.courseName].filter((v) => !!v).join(" ");

  let detail: string;
  switch (changeType) {
    case "CANCEL":
      detail = `${when} 수업이 휴강되었습니다.`;
      break;
    case "TIME": {
      const next = await resolveNewTimeText(admin, change, ctx);
      detail = next
        ? `${when} 수업이 ${next} 로 변경되었습니다.`
        : `${when} 수업 시간이 변경되었습니다.`;
      break;
    }
    case "LOCATION": {
      const newLocation = pickString(change, "new_location", "location");
      if (newLocation && ctx.location) {
        detail = `${when} 수업 장소가 ${ctx.location} → ${newLocation} 로 변경되었습니다.`;
      } else if (newLocation) {
        detail = `${when} 수업 장소가 ${newLocation} 로 변경되었습니다.`;
      } else {
        detail = `${when} 수업 장소가 변경되었습니다.`;
      }
      break;
    }
    case "SUBSTITUTE": {
      const teacherName = await resolveSubstituteTeacherName(admin, change);
      detail = teacherName
        ? `${when} 수업은 ${teacherName} 선생님이 진행합니다.`
        : `${when} 수업의 담당 선생님이 변경되었습니다.`;
      break;
    }
    default:
      detail = `${when} 수업에 변경 사항이 있습니다.`;
      break;
  }

  const lines = [`[네스트] ${classLabel} 수업 변경 안내`, detail];
  if (reason) lines.push(`사유: ${reason}`);

  return {
    text: lines.join("\n"),
    templateId: ALIMTALK_TEMPLATE_IDS.CLASS_CHANGE || undefined,
    variables: {
      "#{class_name}": ctx.classGroupName,
      "#{course_name}": ctx.courseName,
      "#{period}": period,
      "#{day}": dayLabel,
      "#{time}": timeRange,
      "#{detail}": detail,
      "#{reason}": reason ?? ""
    }
  };
}

function buildAbsenceMessage(report: Row, child: Row, ctx: SessionContext): MessagePayload {
  const childName = pickString(child, "name") ?? "학생";
  const dateIso =
    pickString(report, "occurrence_date", "absence_date", "session_date", "target_date") ?? "";
  const dateLabel = formatDateWithDay(dateIso);
  const reason = pickString(report, "reason", "note", "memo");
  const timeRange = ctx.startTime && ctx.endTime ? `${ctx.startTime}-${ctx.endTime}` : "";
  const subject = timeRange ? `${ctx.courseName}(${timeRange})` : ctx.courseName;

  const lines = [
    "[네스트] 결석 예정 알림",
    `${childName} 학생이 ${dateLabel} ${subject} 수업에 결석 예정입니다.`
  ];
  if (reason) lines.push(`사유: ${reason}`);

  return {
    text: lines.join("\n"),
    templateId: ALIMTALK_TEMPLATE_IDS.ABSENCE || undefined,
    variables: {
      "#{child_name}": childName,
      "#{class_name}": ctx.classGroupName,
      "#{course_name}": ctx.courseName,
      "#{date}": dateLabel,
      "#{time}": timeRange,
      "#{reason}": reason ?? ""
    }
  };
}

async function resolveNewTimeText(
  admin: Admin,
  change: Row,
  ctx: SessionContext
): Promise<string | null> {
  const newSlotId = pickString(change, "new_time_slot_id", "new_slot_id");
  if (newSlotId) {
    const { data, error } = await admin
      .from("time_slots")
      .select("day_of_week, start_time, end_time")
      .eq("id", newSlotId)
      .maybeSingle();
    if (!error && data) {
      const row = data as Row;
      const day = pickNumber(row, "day_of_week");
      const dayLabel = day === null ? "" : `${DAY_LABELS[day] ?? ""}요일`;
      const start = formatTime(pickString(row, "start_time"));
      const end = formatTime(pickString(row, "end_time"));
      const range = start && end ? `${start}-${end}` : "";
      const text = [dayLabel, range].filter((v) => v.length > 0).join(" ");
      return text.length > 0 ? text : null;
    }
  }

  const start = formatTime(pickString(change, "new_start_time"));
  const end = formatTime(pickString(change, "new_end_time"));
  if (!start && !end) return null;
  const day = pickNumber(change, "new_day_of_week");
  const dayLabel =
    day === null
      ? ctx.dayOfWeek === null
        ? ""
        : `${DAY_LABELS[ctx.dayOfWeek] ?? ""}요일`
      : `${DAY_LABELS[day] ?? ""}요일`;
  const range = start && end ? `${start}-${end}` : start || end;
  return [dayLabel, range].filter((v) => v.length > 0).join(" ");
}

async function resolveSubstituteTeacherName(
  admin: Admin,
  change: Row
): Promise<string | null> {
  const profileId = pickString(
    change,
    "substitute_teacher_profile_id",
    "substitute_teacher_id",
    "new_teacher_profile_id"
  );
  if (!profileId) return null;

  const { data, error } = await admin
    .from("teacher_profiles")
    .select("display_name")
    .eq("id", profileId)
    .maybeSingle();
  if (error || !data) return null;
  return pickString(data as Row, "display_name");
}

/**
 * class_session_changes.change_type 정규화.
 * DB 체크 제약값은 CANCELED / TIME_MOVED / ROOM_MOVED / TEACHER_SUBSTITUTE / NOTE 이며,
 * 유사 표기도 함께 받아들인다(그 외는 NOTE 로 처리).
 */
function normalizeChangeType(raw: string | null): string {
  const value = (raw ?? "").toUpperCase();
  if (["CANCELED", "CANCELLED", "CANCEL", "CLOSED"].includes(value)) return "CANCEL";
  if (["TIME_MOVED", "TIME", "TIME_CHANGE", "RESCHEDULE", "SLOT"].includes(value)) {
    return "TIME";
  }
  if (
    ["ROOM_MOVED", "ROOM", "ROOM_CHANGE", "LOCATION", "LOCATION_CHANGE"].includes(value)
  ) {
    return "LOCATION";
  }
  if (
    ["TEACHER_SUBSTITUTE", "SUBSTITUTE", "SUBSTITUTE_TEACHER", "TEACHER", "TEACHER_CHANGE"]
      .includes(value)
  ) {
    return "SUBSTITUTE";
  }
  return "NOTE";
}

// ─────────────────────────────────────────────── 포맷 유틸

/** `09:00:00` → `09:00` */
function formatTime(raw: string | null): string {
  if (!raw) return "";
  const match = /^(\d{1,2}):(\d{2})/.exec(raw);
  if (!match) return raw;
  return `${match[1].padStart(2, "0")}:${match[2]}`;
}

/** `2026-09-03` → `9월 3일` */
function formatDate(raw: string | null): string {
  if (!raw) return "";
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (!match) return raw;
  return `${Number(match[2])}월 ${Number(match[3])}일`;
}

/** `2026-09-03` → `9월 3일(목)` */
function formatDateWithDay(raw: string | null): string {
  const base = formatDate(raw);
  if (!raw || !base) return base;
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (!match) return base;
  const day = new Date(`${match[1]}-${match[2]}-${match[3]}T00:00:00Z`).getUTCDay();
  const label = DAY_LABELS[day];
  return label ? `${base}(${label})` : base;
}

/** 적용 기간 문구. to 가 null 이면 학기 종료까지. */
function periodText(from: string | null, to: string | null): string {
  if (!from) return "";
  const fromLabel = formatDate(from);
  if (!to) return `${fromLabel}부터 학기 종료까지`;
  if (to === from) return fromLabel;
  return `${fromLabel}~${formatDate(to)}`;
}

// ─────────────────────────────────────────────── 안전 접근 유틸

function pickString(row: Row | null, ...keys: string[]): string | null {
  if (!row) return null;
  for (const key of keys) {
    const value = row[key];
    if (typeof value === "string" && value.trim().length > 0) return value.trim();
  }
  return null;
}

function pickNumber(row: Row | null, ...keys: string[]): number | null {
  if (!row) return null;
  for (const key of keys) {
    const value = row[key];
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

/** 테이블이 아직 없는 경우(마이그레이션 미배포). */
function isMissingRelation(error: { code?: string; message?: string }): boolean {
  const code = error?.code ?? "";
  const message = (error?.message ?? "").toLowerCase();
  return (
    code === "42P01" ||
    code === "PGRST205" ||
    message.includes("does not exist") ||
    message.includes("could not find the table")
  );
}

/** RPC 가 아직 없는 경우(마이그레이션 미배포). */
function isMissingFunction(error: { code?: string; message?: string }): boolean {
  const code = error?.code ?? "";
  const message = (error?.message ?? "").toLowerCase();
  return (
    code === "PGRST202" ||
    code === "42883" ||
    message.includes("does not exist") ||
    message.includes("could not find the function")
  );
}


/**
 * 호출자 본인의 기기에만 확인용 푸시를 보낸다.
 * 반환값은 실제로 전달된 기기 수. 0 이면 토큰이 없다는 뜻이다.
 */
async function pushToSelf(
  admin: ReturnType<typeof createAdminClient>,
  userId: string
): Promise<number> {
  const title = "알림이 잘 오고 있어요";
  const body = "이렇게 수업 변경·시작 전 안내를 보내드립니다.";
  const payloadData = { event: "TEST", tab: "시간표" };

  const { data: tokens } = await admin
    .from("push_tokens")
    .select("user_id, token, platform")
    .eq("user_id", userId)
    .is("revoked_at", null);

  if (!tokens || tokens.length === 0) {
    const { error } = await admin.from("notification_log").insert({
      requested_by: userId,
      to_user_id: userId,
      channel: "push",
      status: "inbox_only",
      provider_message_id: null,
      error: null,
      event_type: "TEST",
      title,
      body,
      payload: payloadData
    });
    if (error) console.error("[nest-notify] test inbox log", error.message);
    return 0;
  }

  const results = await sendFcmToTokens({
    tokens: tokens as Array<{ user_id: string; token: string; platform: string }>,
    payload: {
      title,
      body,
      data: payloadData
    }
  });
  const logs = results.map((result) => ({
    requested_by: userId,
    to_user_id: result.userId,
    channel: "push",
    status: result.ok ? "accepted" : "failed",
    provider_message_id: result.name ?? null,
    error: result.error ?? null,
    event_type: "TEST",
    title,
    body,
    payload: payloadData
  }));
  const { error } = await admin.from("notification_log").insert(logs);
  if (error) console.error("[nest-notify] test push log", error.message);
  return results.filter((row) => row.ok).length;
}
