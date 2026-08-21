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
  if (event !== "CLASS_CHANGE" && event !== "ABSENCE") {
    return json(
      400,
      { error: "event 는 'CLASS_CHANGE' 또는 'ABSENCE' 여야 합니다." },
      corsHeaders
    );
  }

  const targetId = typeof body?.id === "string" ? body.id.trim() : "";
  if (!UUID_RE.test(targetId)) {
    return json(400, { error: "id 는 uuid 형식이어야 합니다." }, corsHeaders);
  }

  const requestedChannel = body?.channel ?? DEFAULT_CHANNEL;
  if (
    requestedChannel !== "sms" &&
    requestedChannel !== "alimtalk" &&
    requestedChannel !== "auto"
  ) {
    return json(
      400,
      { error: "channel 은 'sms', 'alimtalk', 'auto' 중 하나여야 합니다." },
      corsHeaders
    );
  }
  const channel: SolapiChannel = requestedChannel;
  const force = body?.force === true;

  try {
    if (event === "CLASS_CHANGE") {
      return await handleClassChange(admin, callerId, targetId, channel, force);
    }
    return await handleAbsence(admin, callerId, targetId, channel, force);
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
    rowId: changeId
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
    rowId: reportId
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
}

async function dispatch(admin: Admin, args: DispatchArgs): Promise<Response> {
  const { callerId, channel, recipients, message, table, rowId } = args;

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

  // 보낼 번호가 하나도 없으면 "성공"으로 위장하지 않는다.
  if (targets.length === 0) {
    return json(
      200,
      {
        accepted: false,
        sent: 0,
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
    error: result.error ?? null
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
      skipped_no_phone: skippedNoPhone,
      skipped_no_account: skippedNoAccount,
      message_id: result.messageId ?? null
    },
    corsHeaders
  );
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
