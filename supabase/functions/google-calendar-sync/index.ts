import { corsHeaders } from "../_shared/cors.ts";
import { refreshCalendarToken } from "../_shared/google_calendar.ts";
import { createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type PersonalRow = {
  id: string;
  title: string;
  notes: string;
  starts_at: string;
  ends_at: string;
  source: string;
  google_event_id: string | null;
};

type AcademicRow = {
  id: string;
  title: string;
  description: string;
  event_date: string;
  end_date: string | null;
  start_time: string | null;
  end_time: string | null;
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
    const payload = (await req.json()) as {
      action?: string;
      homeschool_id?: string;
      child_id?: string;
    };

    if (payload.action === "disconnect") {
      await admin
        .from("calendar_integrations")
        .delete()
        .eq("user_id", user.id);
      return json(200, { disconnected: true }, corsHeaders);
    }

    if (!payload.homeschool_id || !payload.child_id) {
      return json(400, { error: "homeschool_id and child_id are required" }, corsHeaders);
    }

    const { data: integration, error: integErr } = await admin
      .from("calendar_integrations")
      .select(
        "id, user_id, google_access_token, google_refresh_token, google_token_expires_at, calendar_id"
      )
      .eq("user_id", user.id)
      .eq("status", "CONNECTED")
      .maybeSingle();

    if (integErr || !integration) {
      return json(400, { error: "Google 캘린더가 연결되어 있지 않습니다." }, corsHeaders);
    }

    const access = await refreshCalendarToken(admin, integration);
    if (!access) {
      return json(400, { error: "캘린더 토큰을 갱신하지 못했습니다." }, corsHeaders);
    }

    const calendarId = encodeURIComponent(integration.calendar_id || "primary");
    const pushed = await pushNestEvents({
      admin,
      access,
      calendarId,
      userId: user.id,
      homeschoolId: payload.homeschool_id,
      childId: payload.child_id,
    });

    const pulled = await pullGoogleEvents({
      admin,
      access,
      calendarId,
      userId: user.id,
      homeschoolId: payload.homeschool_id,
      childId: payload.child_id,
    });

    await admin
      .from("calendar_integrations")
      .update({ last_synced_at: new Date().toISOString() })
      .eq("id", integration.id);

    return json(200, { pushed, pulled }, corsHeaders);
  } catch (err) {
    return json(
      400,
      { error: err instanceof Error ? err.message : String(err) },
      corsHeaders
    );
  }
});

async function pushNestEvents(args: {
  admin: ReturnType<typeof createAdminClient>;
  access: string;
  calendarId: string;
  userId: string;
  homeschoolId: string;
  childId: string;
}) {
  const { data: personals } = await args.admin
    .from("personal_events")
    .select("id, title, notes, starts_at, ends_at, source, google_event_id")
    .eq("child_id", args.childId)
    .eq("owner_user_id", args.userId)
    .eq("source", "NEST");

  const { data: academics } = await args.admin
    .from("academic_events")
    .select("id, title, description, event_date, end_date, start_time, end_time")
    .eq("homeschool_id", args.homeschoolId)
    .eq("show_on_timetable", true)
    .limit(200);

  let count = 0;
  for (const row of (personals || []) as PersonalRow[]) {
    const body = {
      summary: row.title,
      description: `${row.notes || ""}\n\nNest 개인 일정`.trim(),
      start: { dateTime: row.starts_at },
      end: { dateTime: row.ends_at },
    };
    const eventId = await upsertGoogleEvent({
      access: args.access,
      calendarId: args.calendarId,
      existingId: row.google_event_id,
      body,
    });
    if (eventId && eventId !== row.google_event_id) {
      await args.admin
        .from("personal_events")
        .update({ google_event_id: eventId, google_calendar_id: "primary" })
        .eq("id", row.id);
    }
    count += 1;
  }

  for (const row of (academics || []) as AcademicRow[]) {
    const allDay = !row.start_time;
    const startDate = row.event_date;
    const endDate = row.end_date || row.event_date;
    const body = allDay
      ? {
          summary: `[둥지] ${row.title}`,
          description: row.description || "Nest 학사일정",
          start: { date: startDate },
          end: { date: nextDate(endDate) },
        }
      : {
          summary: `[둥지] ${row.title}`,
          description: row.description || "Nest 학사일정",
          start: { dateTime: `${startDate}T${normalizeClock(row.start_time)}` },
          end: {
            dateTime: `${endDate}T${normalizeClock(row.end_time || row.start_time)}`,
          },
        };
    await upsertGoogleEvent({
      access: args.access,
      calendarId: args.calendarId,
      existingId: null,
      body,
    });
    count += 1;
  }

  return count;
}

async function pullGoogleEvents(args: {
  admin: ReturnType<typeof createAdminClient>;
  access: string;
  calendarId: string;
  userId: string;
  homeschoolId: string;
  childId: string;
}) {
  const now = new Date();
  const timeMin = new Date(now.getTime() - 7 * 86400000).toISOString();
  const timeMax = new Date(now.getTime() + 120 * 86400000).toISOString();
  const res = await fetch(
    `https://www.googleapis.com/calendar/v3/calendars/${args.calendarId}/events?singleEvents=true&orderBy=startTime&timeMin=${encodeURIComponent(timeMin)}&timeMax=${encodeURIComponent(timeMax)}`,
    { headers: { Authorization: `Bearer ${args.access}` } }
  );
  if (!res.ok) return 0;
  const json = await res.json();
  const items = (json.items || []) as Array<{
    id: string;
    summary?: string;
    description?: string;
    start?: { dateTime?: string; date?: string };
    end?: { dateTime?: string; date?: string };
  }>;

  let count = 0;
  for (const item of items) {
    if (!item.id || (item.summary || "").startsWith("[둥지]")) continue;
    const startsAt = item.start?.dateTime ||
      (item.start?.date ? `${item.start.date}T00:00:00Z` : null);
    const endsAt = item.end?.dateTime ||
      (item.end?.date ? `${item.end.date}T00:00:00Z` : null);
    if (!startsAt || !endsAt) continue;

    const row = {
      homeschool_id: args.homeschoolId,
      owner_user_id: args.userId,
      child_id: args.childId,
      title: item.summary || "Google 일정",
      notes: item.description || "",
      starts_at: startsAt,
      ends_at: endsAt,
      source: "GOOGLE",
      google_event_id: item.id,
      google_calendar_id: "primary",
      conflict_policy: "KEEP_BOTH",
    };
    const { data: existing } = await args.admin
      .from("personal_events")
      .select("id")
      .eq("owner_user_id", args.userId)
      .eq("google_event_id", item.id)
      .maybeSingle();
    if (existing?.id) {
      await args.admin.from("personal_events").update(row).eq("id", existing.id);
    } else {
      await args.admin.from("personal_events").insert(row);
    }
    count += 1;
  }
  return count;
}

async function upsertGoogleEvent(args: {
  access: string;
  calendarId: string;
  existingId: string | null;
  body: Record<string, unknown>;
}) {
  const base = `https://www.googleapis.com/calendar/v3/calendars/${args.calendarId}/events`;
  const url = args.existingId ? `${base}/${args.existingId}` : base;
  const res = await fetch(url, {
    method: args.existingId ? "PATCH" : "POST",
    headers: {
      Authorization: `Bearer ${args.access}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args.body),
  });
  if (!res.ok) return args.existingId;
  const json = await res.json();
  return typeof json.id === "string" ? json.id : args.existingId;
}

function normalizeClock(value: string | null) {
  if (!value) return "09:00:00";
  return value.length === 5 ? `${value}:00` : value;
}

function nextDate(isoDate: string) {
  const date = new Date(`${isoDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
