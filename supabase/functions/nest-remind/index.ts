// nest-remind — 아침 오늘 일정 / 수업 30분 전 푸시.
//
// 클라이언트는 호출하지 않는다. cron 또는 GitHub Actions 만
// `x-cron-secret: NEST_CRON_SECRET` 헤더로 POST 한다.
// { job: 'MORNING_DIGEST' | 'CLASS_REMINDER' }
//
// 문자는 보내지 않는다. 수업 변경·결석은 nest-notify 가 SMS+푸시를 담당한다.

import { createAdminClient, json } from "../_shared/supabase.ts";
import { sendFcmToTokens } from "../_shared/fcm.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

type Admin = ReturnType<typeof createAdminClient>;
type Job = "MORNING_DIGEST" | "CLASS_REMINDER";

interface Occurrence {
  sessionId: string;
  classGroupId: string;
  classGroupName: string;
  courseName: string;
  location: string;
  startTime: string;
  endTime: string;
  canceled: boolean;
}

interface Prefs {
  push_enabled: boolean;
  morning_digest_enabled: boolean;
  class_reminder_enabled: boolean;
  quiet_hours_start: string | null;
  quiet_hours_end: string | null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "허용되지 않는 메서드입니다." });
  }

  const expected = Deno.env.get("NEST_CRON_SECRET") ?? "";
  const provided = req.headers.get("x-cron-secret") ?? "";
  if (!expected || provided !== expected) {
    return json(401, { error: "cron 인증에 실패했습니다." });
  }

  let job: Job = "CLASS_REMINDER";
  try {
    const body = await req.json();
    if (body?.job === "MORNING_DIGEST" || body?.job === "CLASS_REMINDER") {
      job = body.job;
    }
  } catch {
    // 본문 없이 호출되면 30분 전 잡을 기본으로 한다.
  }

  const admin = createAdminClient();
  const seoul = nowInSeoul();

  try {
    const occurrences = await loadOccurrences(admin, seoul.date, seoul.dow);
    if (job === "MORNING_DIGEST") {
      const result = await sendMorningDigest(admin, seoul, occurrences);
      return json(200, { ok: true, job, ...result });
    }
    const result = await sendClassReminders(admin, seoul, occurrences);
    return json(200, { ok: true, job, ...result });
  } catch (error) {
    console.error("[nest-remind]", error);
    return json(500, {
      error: error instanceof Error ? error.message : "리마인더 발송 실패",
    });
  }
});

function nowInSeoul(): { date: string; minutes: number; dow: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  const dowMap: Record<string, number> = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };
  const hour = Number(get("hour") === "24" ? "0" : get("hour"));
  const minute = Number(get("minute"));
  return {
    date: `${get("year")}-${get("month")}-${get("day")}`,
    minutes: hour * 60 + minute,
    dow: dowMap[get("weekday")] ?? 0,
  };
}

function minutesFromTime(value: string): number {
  const [h, m] = value.split(":");
  return (Number(h) || 0) * 60 + (Number(m) || 0);
}

function shortTime(value: string): string {
  const [h, m] = value.split(":");
  return `${(h ?? "00").padStart(2, "0")}:${(m ?? "00").padStart(2, "0")}`;
}

function inQuietHours(prefs: Prefs, minutes: number): boolean {
  if (!prefs.quiet_hours_start || !prefs.quiet_hours_end) return false;
  const start = minutesFromTime(prefs.quiet_hours_start);
  const end = minutesFromTime(prefs.quiet_hours_end);
  if (start === end) return false;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}

function appliesOn(
  from: string,
  to: string | null,
  date: string,
): boolean {
  if (date < from) return false;
  if (!to) return true;
  return date <= to;
}

async function loadOccurrences(
  admin: Admin,
  date: string,
  dow: number,
): Promise<Occurrence[]> {
  const { data: terms, error: termErr } = await admin
    .from("terms")
    .select("id")
    .eq("status", "ACTIVE")
    .lte("start_date", date)
    .gte("end_date", date);
  if (termErr) throw termErr;
  const termIds = (terms ?? []).map((row) => row.id as string);
  if (termIds.length === 0) return [];

  const { data: groups, error: groupErr } = await admin
    .from("class_groups")
    .select("id, name, term_id")
    .in("term_id", termIds);
  if (groupErr) throw groupErr;
  const groupById = new Map(
    (groups ?? []).map((row) => [row.id as string, row]),
  );
  const groupIds = [...groupById.keys()];
  if (groupIds.length === 0) return [];

  const { data: sessions, error: sessionErr } = await admin
    .from("class_sessions")
    .select("id, class_group_id, course_id, time_slot_id, location")
    .in("class_group_id", groupIds);
  if (sessionErr) throw sessionErr;
  const sessionRows = sessions ?? [];
  if (sessionRows.length === 0) return [];

  const slotIds = [...new Set(sessionRows.map((row) => row.time_slot_id as string))];
  const courseIds = [...new Set(sessionRows.map((row) => row.course_id as string))];
  const sessionIds = sessionRows.map((row) => row.id as string);

  const [{ data: slots }, { data: courses }, { data: changes }] = await Promise.all([
    admin.from("time_slots").select("id, day_of_week, start_time, end_time").in("id", slotIds),
    admin.from("courses").select("id, name").in("id", courseIds),
    admin
      .from("class_session_changes")
      .select(
        "class_session_id, change_type, effective_from, effective_to, new_time_slot_id, new_location, created_at",
      )
      .in("class_session_id", sessionIds),
  ]);

  const slotById = new Map((slots ?? []).map((row) => [row.id as string, row]));
  const extraSlotIds = (changes ?? [])
    .map((row) => row.new_time_slot_id as string | null)
    .filter((id): id is string => !!id && !slotById.has(id));
  if (extraSlotIds.length > 0) {
    const { data: extra } = await admin
      .from("time_slots")
      .select("id, day_of_week, start_time, end_time")
      .in("id", extraSlotIds);
    for (const row of extra ?? []) slotById.set(row.id as string, row);
  }
  const courseById = new Map((courses ?? []).map((row) => [row.id as string, row.name as string]));

  const out: Occurrence[] = [];
  for (const session of sessionRows) {
    const change = pickChange((changes ?? []).filter((row) => row.class_session_id === session.id), date);
    let slot = slotById.get(session.time_slot_id as string);
    if (change?.change_type === "TIME_MOVED" && change.new_time_slot_id) {
      slot = slotById.get(change.new_time_slot_id as string) ?? slot;
    }
    if (!slot || Number(slot.day_of_week) !== dow) continue;
    const group = groupById.get(session.class_group_id as string);
    const location =
      (change?.new_location as string | undefined)?.trim() ||
      (session.location as string | undefined)?.trim() ||
      "";
    out.push({
      sessionId: session.id as string,
      classGroupId: session.class_group_id as string,
      classGroupName: (group?.name as string) ?? "",
      courseName: courseById.get(session.course_id as string) ?? "수업",
      location,
      startTime: slot.start_time as string,
      endTime: slot.end_time as string,
      canceled: change?.change_type === "CANCELED",
    });
  }
  out.sort((a, b) => a.startTime.localeCompare(b.startTime));
  return out;
}

function pickChange(
  rows: Array<Record<string, unknown>>,
  date: string,
): Record<string, unknown> | null {
  const matches = rows.filter((row) =>
    appliesOn(row.effective_from as string, (row.effective_to as string | null) ?? null, date),
  );
  if (matches.length === 0) return null;
  matches.sort((a, b) => {
    const rank = (row: Record<string, unknown>) => {
      const to = row.effective_to as string | null;
      if (!to) return 2;
      return to === (row.effective_from as string) ? 0 : 1;
    };
    const byRank = rank(a) - rank(b);
    if (byRank !== 0) return byRank;
    return String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""));
  });
  return matches[0];
}

async function recipientsForSession(
  admin: Admin,
  sessionId: string,
): Promise<Array<{ userId: string; kind: string }>> {
  const { data, error } = await admin.rpc("recipients_for_class_session", {
    p_class_session_id: sessionId,
    p_include_guardians: true,
    p_include_students: true,
    p_include_teachers: true,
  });
  if (error) {
    console.error("[nest-remind] recipients rpc", error.message);
    return [];
  }
  return (data ?? [])
    .map((row: { user_id?: string; recipient_kind?: string }) => ({
      userId: row.user_id ?? "",
      kind: row.recipient_kind ?? "",
    }))
    .filter((row: { userId: string }) => row.userId.length > 0);
}

async function loadPrefs(admin: Admin, userIds: string[]): Promise<Map<string, Prefs>> {
  const map = new Map<string, Prefs>();
  if (userIds.length === 0) return map;
  const { data } = await admin
    .from("notification_prefs")
    .select(
      "user_id, push_enabled, morning_digest_enabled, class_reminder_enabled, quiet_hours_start, quiet_hours_end",
    )
    .in("user_id", userIds);
  for (const row of data ?? []) {
    map.set(row.user_id as string, {
      push_enabled: row.push_enabled !== false,
      morning_digest_enabled: row.morning_digest_enabled !== false,
      class_reminder_enabled: row.class_reminder_enabled !== false,
      quiet_hours_start: (row.quiet_hours_start as string | null) ?? null,
      quiet_hours_end: (row.quiet_hours_end as string | null) ?? null,
    });
  }
  return map;
}

async function claimSend(
  admin: Admin,
  eventType: Job,
  date: string,
  userId: string,
  sessionId: string | null,
): Promise<boolean> {
  const { error } = await admin.from("schedule_reminder_sends").insert({
    event_type: eventType,
    occurrence_date: date,
    user_id: userId,
    class_session_id: sessionId,
  });
  if (error) {
    if (error.code === "23505") return false;
    console.error("[nest-remind] claim", error.message);
    return false;
  }
  return true;
}

async function pushToUsers(
  admin: Admin,
  userIds: string[],
  title: string,
  body: string,
  eventType: string,
  extra: Record<string, string>,
): Promise<number> {
  if (userIds.length === 0) return 0;
  const { data: tokens } = await admin
    .from("push_tokens")
    .select("user_id, token, platform")
    .in("user_id", userIds)
    .is("revoked_at", null);
  if (!tokens || tokens.length === 0) return 0;

  const results = await sendFcmToTokens({
    tokens: tokens as Array<{ user_id: string; token: string; platform: string }>,
    payload: {
      title,
      body,
      data: { event: eventType, tab: "시간표", ...extra },
    },
  });

  const logs = results.map((result) => ({
    requested_by: null,
    to_user_id: result.userId,
    channel: "push",
    status: result.ok ? "accepted" : "failed",
    provider_message_id: result.name ?? null,
    error: result.error ?? null,
    event_type: eventType,
    title,
    body,
    payload: { event: eventType, tab: "시간표", ...extra },
  }));
  const { error } = await admin.from("notification_log").insert(logs);
  if (error) console.error("[nest-remind] log", error.message);
  return results.filter((result) => result.ok).length;
}

async function sendMorningDigest(
  admin: Admin,
  seoul: { date: string; minutes: number },
  occurrences: Occurrence[],
): Promise<{ sent: number; skipped: number }> {
  const live = occurrences.filter((row) => !row.canceled);
  if (live.length === 0) return { sent: 0, skipped: 0 };

  const byUser = new Map<string, Occurrence[]>();
  for (const occurrence of live) {
    const recipients = await recipientsForSession(admin, occurrence.sessionId);
    for (const recipient of recipients) {
      const list = byUser.get(recipient.userId) ?? [];
      if (!list.some((row) => row.sessionId === occurrence.sessionId)) {
        list.push(occurrence);
      }
      byUser.set(recipient.userId, list);
    }
  }

  const prefs = await loadPrefs(admin, [...byUser.keys()]);
  let sent = 0;
  let skipped = 0;
  for (const [userId, rows] of byUser) {
    const pref = prefs.get(userId);
    if (pref && (!pref.push_enabled || !pref.morning_digest_enabled)) {
      skipped += 1;
      continue;
    }
    if (pref && inQuietHours(pref, seoul.minutes)) {
      skipped += 1;
      continue;
    }
    if (!(await claimSend(admin, "MORNING_DIGEST", seoul.date, userId, null))) {
      skipped += 1;
      continue;
    }
    const lines = rows.map(
      (row) =>
        `${shortTime(row.startTime)} ${row.courseName}${row.location ? ` · ${row.location}` : ""}`,
    );
    sent += await pushToUsers(
      admin,
      [userId],
      `오늘 수업 ${rows.length}개`,
      lines.join("\n"),
      "MORNING_DIGEST",
      { date: seoul.date },
    );
  }
  return { sent, skipped };
}

async function sendClassReminders(
  admin: Admin,
  seoul: { date: string; minutes: number },
  occurrences: Occurrence[],
): Promise<{ sent: number; skipped: number }> {
  const due = occurrences.filter((row) => {
    if (row.canceled) return false;
    const delta = minutesFromTime(row.startTime) - seoul.minutes;
    return delta >= 25 && delta < 35;
  });
  if (due.length === 0) return { sent: 0, skipped: 0 };

  let sent = 0;
  let skipped = 0;
  for (const occurrence of due) {
    const recipients = await recipientsForSession(admin, occurrence.sessionId);
    const prefs = await loadPrefs(
      admin,
      recipients.map((row) => row.userId),
    );
    for (const recipient of recipients) {
      const pref = prefs.get(recipient.userId);
      if (pref && (!pref.push_enabled || !pref.class_reminder_enabled)) {
        skipped += 1;
        continue;
      }
      if (
        !(await claimSend(
          admin,
          "CLASS_REMINDER",
          seoul.date,
          recipient.userId,
          occurrence.sessionId,
        ))
      ) {
        skipped += 1;
        continue;
      }
      const where = occurrence.location ? ` · ${occurrence.location}` : "";
      const title = `${occurrence.courseName} 30분 전`;
      const body = `${occurrence.classGroupName} ${occurrence.courseName}이 30분 뒤 시작해요${where}`;
      sent += await pushToUsers(
        admin,
        [recipient.userId],
        title,
        body,
        "CLASS_REMINDER",
        { session_id: occurrence.sessionId, date: seoul.date },
      );
    }
  }
  return { sent, skipped };
}
