import { corsHeaders } from "../_shared/cors.ts";
import { assertRole, createAdminClient, json, requireUser } from "../_shared/supabase.ts";

type Payload = {
  term_id: string;
  class_group_id: string;
  prompt: string;
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

    if (!payload.term_id || !payload.class_group_id || !payload.prompt) {
      return json(400, { error: "term_id, class_group_id, prompt are required" }, corsHeaders);
    }

    const { data: term, error: termErr } = await admin
      .from("terms")
      .select("id, homeschool_id")
      .eq("id", payload.term_id)
      .maybeSingle();

    if (termErr || !term) {
      return json(404, { error: "Term not found" }, corsHeaders);
    }

    await assertRole(admin, term.homeschool_id, user.id, ["HOMESCHOOL_ADMIN", "STAFF"]);

    const [courseRes, slotRes, sessionRes] = await Promise.all([
      admin
        .from("courses")
        .select("id, name")
        .eq("homeschool_id", term.homeschool_id)
        .order("name"),
      admin
        .from("time_slots")
        .select("id, day_of_week, start_time, end_time")
        .eq("term_id", payload.term_id)
        .order("day_of_week")
        .order("start_time"),
      admin
        .from("class_sessions")
        .select("id, time_slot_id, course_id")
        .eq("class_group_id", payload.class_group_id)
        .neq("status", "CANCELED")
    ]);

    if (courseRes.error || slotRes.error || sessionRes.error) {
      return json(
        500,
        {
          error: "Failed to load base data",
          details: [courseRes.error?.message, slotRes.error?.message, sessionRes.error?.message].filter(
            Boolean
          )
        },
        corsHeaders
      );
    }

    const courses = courseRes.data || [];
    const slots = slotRes.data || [];
    const sessions = sessionRes.data || [];

    const occupied = new Set(sessions.map((s) => s.time_slot_id));
    const freeSlots = slots.filter((s) => !occupied.has(s.id));

    const selectedCourses = pickCoursesByPrompt(payload.prompt, courses);
    const selectedSlots = pickSlotsByPrompt(payload.prompt, freeSlots);

    const maxItems = Math.min(4, selectedCourses.length, selectedSlots.length);

    const generatedSessions = [];
    for (let i = 0; i < maxItems; i += 1) {
      generatedSessions.push({
        class_group_id: payload.class_group_id,
        course_id: selectedCourses[i % selectedCourses.length].id,
        time_slot_id: selectedSlots[i].id,
        teacher_main_id: null,
        teacher_assistant_ids_json: [],
        hard_conflicts_json: [],
        soft_warnings_json: []
      });
    }

    const hardConflicts = freeSlots.length
      ? []
      : [
          {
            code: "NO_FREE_SLOT",
            message: "No free timeslots available for the class group."
          }
        ];

    const explanation = explainPlan(payload.prompt, selectedCourses, selectedSlots, generatedSessions.length);

    return json(
      200,
      {
        source: "edge-function",
        sessions: generatedSessions,
        hard_conflicts: hardConflicts,
        soft_warnings: [],
        explanation
      },
      corsHeaders
    );
  } catch (err) {
    return json(
      400,
      {
        error: err instanceof Error ? err.message : "Unknown error"
      },
      corsHeaders
    );
  }
});

function pickCoursesByPrompt(prompt: string, courses: Array<{ id: string; name: string }>) {
  if (!courses.length) return [];

  const p = prompt.toLowerCase();
  const rules = [
    { words: ["국어", "문해", "읽기", "language"], key: "국어" },
    { words: ["수학", "math"], key: "수학" },
    { words: ["과학", "자연", "science"], key: "자연" },
    { words: ["미술", "art"], key: "미술" }
  ];

  const out: Array<{ id: string; name: string }> = [];

  for (const rule of rules) {
    if (rule.words.some((w) => p.includes(w))) {
      const found = courses.find((c) => c.name.includes(rule.key));
      if (found && !out.some((v) => v.id === found.id)) {
        out.push(found);
      }
    }
  }

  if (!out.length) {
    out.push(...courses.slice(0, 4));
  }

  return out;
}

function pickSlotsByPrompt(
  prompt: string,
  freeSlots: Array<{ id: string; day_of_week: number; start_time: string }>
) {
  const p = prompt.toLowerCase();
  const preferMorning = p.includes("오전") || p.includes("morning");
  const preferTueThu = p.includes("화") || p.includes("목") || p.includes("tue") || p.includes("thu");

  let candidate = [...freeSlots];

  if (preferMorning) {
    const morning = candidate.filter((s) => s.start_time < "12:00");
    if (morning.length) candidate = morning;
  }

  if (preferTueThu) {
    const tueThu = candidate.filter((s) => s.day_of_week === 2 || s.day_of_week === 4);
    if (tueThu.length) candidate = tueThu;
  }

  return candidate;
}

function explainPlan(
  prompt: string,
  selectedCourses: Array<{ name: string }>,
  selectedSlots: Array<{ day_of_week: number; start_time: string }>,
  count: number
) {
  const courseText = selectedCourses.map((c) => c.name).join(", ") || "과목 없음";
  const slotPreview = selectedSlots
    .slice(0, count)
    .map((s) => `${s.day_of_week}-${s.start_time}`)
    .join(", ");

  return `Prompt="${prompt}" 기반으로 ${count}개 세션을 제안했습니다. 과목:${courseText}. 슬롯:${slotPreview}`;
}
