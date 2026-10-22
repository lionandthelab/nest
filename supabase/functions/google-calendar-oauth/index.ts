import {
  calendarDonePageUrl,
  calendarRedirectUri,
  decodeState,
} from "../_shared/google_calendar.ts";
import { createAdminClient } from "../_shared/supabase.ts";

function seeOther(location: string) {
  return new Response(null, { status: 302, headers: { Location: location } });
}

function escapeIcsText(raw: string | null | undefined): string {
  if (!raw) return "";
  return raw
    .replaceAll("\\", "\\\\")
    .replaceAll(";", "\\;")
    .replaceAll(",", "\\,")
    .replaceAll(/\r?\n/g, "\\n");
}

function toIcsDate(isoDate: string): string {
  return isoDate.replaceAll("-", "").slice(0, 8);
}

function nextIsoDate(isoDate: string): string {
  const date = new Date(`${isoDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

function toIcsUtcDateTime(isoDateTime: string): string {
  const d = new Date(isoDateTime);
  if (Number.isNaN(d.getTime())) {
    return new Date().toISOString().replaceAll(/[-:]/g, "").replace(/\.\d+Z$/, "Z");
  }
  return d.toISOString().replaceAll(/[-:]/g, "").replace(/\.\d+Z$/, "Z");
}

function toIcsLocalTime(clock: string | null | undefined, fallback = "090000"): string {
  if (!clock) return fallback;
  const parts = clock.trim().split(":");
  const hh = (parts[0] || "09").padStart(2, "0");
  const mm = (parts[1] || "00").padStart(2, "0");
  const ss = (parts[2] || "00").padStart(2, "0");
  return `${hh}${mm}${ss}`;
}

/// First date >= termStartDate that matches dayOfWeek (0=Sun..6=Sat).
function firstOccurrenceDate(termStartDate: string, dayOfWeek: number): string {
  const d = new Date(`${termStartDate}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return termStartDate;
  const currentDow = d.getUTCDay();
  const delta = (dayOfWeek - currentDow + 7) % 7;
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}

const ICS_BYDAY = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

async function serveIcsFeed(token: string): Promise<Response> {
  const admin = createAdminClient();
  const { data: integ } = await admin
    .from("calendar_integrations")
    .select("id, user_id, homeschool_id, status")
    .eq("calendar_id", `feed:${token}`)
    .eq("status", "CONNECTED")
    .maybeSingle();

  if (!integ || !integ.homeschool_id) {
    return new Response("Calendar feed not found", {
      status: 404,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  const userId = String(integ.user_id);
  const homeschoolId = String(integ.homeschool_id);

  const [{ data: school }, { data: academics }, { data: personals }, { data: terms }] =
    await Promise.all([
      admin.from("homeschools").select("name").eq("id", homeschoolId).maybeSingle(),
      admin
        .from("academic_events")
        .select("id, title, description, event_date, end_date, start_time, end_time")
        .eq("homeschool_id", homeschoolId)
        .order("event_date", { ascending: true })
        .limit(300),
      admin
        .from("personal_events")
        .select("id, title, notes, starts_at, ends_at")
        .eq("homeschool_id", homeschoolId)
        .eq("owner_user_id", userId)
        .limit(300),
      admin
        .from("terms")
        .select("id, name, start_date, end_date, status")
        .eq("homeschool_id", homeschoolId)
        .order("start_date", { ascending: false })
        .limit(5),
    ]);

  const schoolName = String(school?.name || "Nest 홈스쿨");
  const nowStamp = toIcsUtcDateTime(new Date().toISOString());

  const lines: string[] = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Nest Homeschool//Calendar//KO",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:[둥지] ${escapeIcsText(schoolName)}`,
    "X-WR-TIMEZONE:Asia/Seoul",
    "BEGIN:VTIMEZONE",
    "TZID:Asia/Seoul",
    "BEGIN:STANDARD",
    "TZOFFSETFROM:+0900",
    "TZOFFSETTO:+0900",
    "TZNAME:KST",
    "DTSTART:19700101T000000",
    "END:STANDARD",
    "END:VTIMEZONE",
  ];

  // 1) 학사일정
  for (const ev of academics || []) {
    const uid = `academic-${ev.id}@nestapp.life`;
    const summary = escapeIcsText(`[둥지] ${ev.title || "학사일정"}`);
    const desc = escapeIcsText(ev.description || "Nest 학사일정");
    const startDate = String(ev.event_date || "");
    if (!startDate) continue;
    const endDate = String(ev.end_date || startDate);

    lines.push("BEGIN:VEVENT");
    lines.push(`UID:${uid}`);
    lines.push(`DTSTAMP:${nowStamp}`);
    if (!ev.start_time) {
      lines.push(`DTSTART;VALUE=DATE:${toIcsDate(startDate)}`);
      lines.push(`DTEND;VALUE=DATE:${toIcsDate(nextIsoDate(endDate))}`);
    } else {
      const dStr = toIcsDate(startDate);
      const eStr = toIcsDate(endDate);
      const tStart = toIcsLocalTime(ev.start_time as string, "090000");
      const tEnd = toIcsLocalTime(
        (ev.end_time as string | null) || (ev.start_time as string),
        "100000"
      );
      lines.push(`DTSTART;TZID=Asia/Seoul:${dStr}T${tStart}`);
      lines.push(`DTEND;TZID=Asia/Seoul:${eStr}T${tEnd}`);
    }
    lines.push(`SUMMARY:${summary}`);
    lines.push(`DESCRIPTION:${desc}`);
    lines.push("END:VEVENT");
  }

  // 2) 개인 일정
  for (const pev of personals || []) {
    if (!pev.starts_at || !pev.ends_at) continue;
    lines.push("BEGIN:VEVENT");
    lines.push(`UID:personal-${pev.id}@nestapp.life`);
    lines.push(`DTSTAMP:${nowStamp}`);
    lines.push(`DTSTART:${toIcsUtcDateTime(String(pev.starts_at))}`);
    lines.push(`DTEND:${toIcsUtcDateTime(String(pev.ends_at))}`);
    lines.push(`SUMMARY:${escapeIcsText(String(pev.title || "개인 일정"))}`);
    if (pev.notes) {
      lines.push(`DESCRIPTION:${escapeIcsText(String(pev.notes))}`);
    }
    lines.push("END:VEVENT");
  }

  // 3) 현재 학기 주간 수업 시간표
  const activeTerm =
    (terms || []).find((t) => t.status === "ACTIVE") || (terms || [])[0];
  if (activeTerm?.id && activeTerm.start_date && activeTerm.end_date) {
    const termId = String(activeTerm.id);
    const [{ data: groups }, { data: slots }, { data: courses }] =
      await Promise.all([
        admin
          .from("class_groups")
          .select("id, name")
          .eq("term_id", termId),
        admin
          .from("time_slots")
          .select("id, day_of_week, start_time, end_time")
          .eq("term_id", termId),
        admin
          .from("courses")
          .select("id, name")
          .eq("homeschool_id", homeschoolId),
      ]);

    const groupIds = (groups || []).map((g) => String(g.id));
    if (groupIds.length > 0) {
      const { data: sessions } = await admin
        .from("class_sessions")
        .select("id, class_group_id, course_id, time_slot_id, title, location, status")
        .in("class_group_id", groupIds)
        .neq("status", "CANCELED");

      const groupById = new Map(
        (groups || []).map((g) => [String(g.id), String(g.name || "")])
      );
      const slotById = new Map(
        (slots || []).map((s) => [String(s.id), s])
      );
      const courseById = new Map(
        (courses || []).map((c) => [String(c.id), String(c.name || "")])
      );
      const untilUtc = `${toIcsDate(String(activeTerm.end_date))}T235959Z`;

      for (const sess of sessions || []) {
        const slot = slotById.get(String(sess.time_slot_id));
        if (!slot) continue;
        const dow = Number(slot.day_of_week ?? 1);
        const byDay = ICS_BYDAY[dow] || "MO";
        const firstDate = firstOccurrenceDate(String(activeTerm.start_date), dow);
        const dStr = toIcsDate(firstDate);
        const tStart = toIcsLocalTime(String(slot.start_time || "09:00"), "090000");
        const tEnd = toIcsLocalTime(String(slot.end_time || "09:50"), "095000");
        const groupName = groupById.get(String(sess.class_group_id)) || "";
        const courseName =
          courseById.get(String(sess.course_id)) || String(sess.title || "수업");
        const summary = groupName
          ? `[${groupName}] ${courseName}`
          : courseName;

        lines.push("BEGIN:VEVENT");
        lines.push(`UID:session-${sess.id}@nestapp.life`);
        lines.push(`DTSTAMP:${nowStamp}`);
        lines.push(`DTSTART;TZID=Asia/Seoul:${dStr}T${tStart}`);
        lines.push(`DTEND;TZID=Asia/Seoul:${dStr}T${tEnd}`);
        lines.push(`RRULE:FREQ=WEEKLY;BYDAY=${byDay};UNTIL=${untilUtc}`);
        lines.push(`SUMMARY:${escapeIcsText(summary)}`);
        if (sess.location) {
          lines.push(`LOCATION:${escapeIcsText(String(sess.location))}`);
        }
        lines.push("END:VEVENT");
      }
    }
  }

  lines.push("END:VCALENDAR");

  return new Response(lines.join("\r\n") + "\r\n", {
    status: 200,
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="nest-calendar.ics"',
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return seeOther(calendarDonePageUrl(false, "method"));
  }

  const url = new URL(req.url);
  const feedToken = url.searchParams.get("token");
  if (feedToken && feedToken.trim().length > 0) {
    return await serveIcsFeed(feedToken.trim());
  }

  const code = url.searchParams.get("code");
  const err = url.searchParams.get("error");
  const state = url.searchParams.get("state");

  if (err) {
    return seeOther(calendarDonePageUrl(false, err));
  }
  if (!code || !state) {
    return seeOther(calendarDonePageUrl(false, "no_code"));
  }

  try {
    const parsed = decodeState(state);
    const userId = String(parsed.user_id || "");
    const homeschoolId = String(parsed.homeschool_id || "");
    if (!userId || !homeschoolId) {
      return seeOther(calendarDonePageUrl(false, "bad_state"));
    }

    const admin = createAdminClient();
    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
    const redirectUri = calendarRedirectUri("app");
    if (!clientId || !clientSecret || !redirectUri) {
      return seeOther(calendarDonePageUrl(false, "server_config"));
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: "authorization_code",
      }),
    });
    if (!tokenRes.ok) {
      return seeOther(calendarDonePageUrl(false, "token_exchange"));
    }

    const tokenJson = await tokenRes.json();
    const accessToken = tokenJson.access_token as string | undefined;
    if (!accessToken) return seeOther(calendarDonePageUrl(false, "no_access_token"));

    const expiresIn = Number(tokenJson.expires_in || 3600);
    const { error } = await admin.from("calendar_integrations").upsert(
      {
        user_id: userId,
        homeschool_id: homeschoolId,
        provider: "GOOGLE",
        status: "CONNECTED",
        google_access_token: accessToken,
        google_refresh_token: tokenJson.refresh_token || undefined,
        google_token_expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
        oauth_scope: tokenJson.scope || "https://www.googleapis.com/auth/calendar.events",
        calendar_id: "primary",
        last_synced_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );

    if (error) return seeOther(calendarDonePageUrl(false, "save_failed"));

    return seeOther(calendarDonePageUrl(true));
  } catch (_) {
    return seeOther(calendarDonePageUrl(false, "unexpected"));
  }
});
