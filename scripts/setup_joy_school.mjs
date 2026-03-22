#!/usr/bin/env node

/**
 * Joy School 시간표 데이터 셋업 스크립트 (30분 슬롯 기반)
 * 사용법: node --env-file=.env scripts/setup_joy_school.mjs
 */

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const report = { startedAt: new Date().toISOString(), steps: [], ids: {} };

main()
  .then(() => {
    report.finishedAt = new Date().toISOString();
    console.log(JSON.stringify(report, null, 2));
  })
  .catch((err) => {
    report.finishedAt = new Date().toISOString();
    report.failed = err.message;
    console.error(JSON.stringify(report, null, 2));
    process.exit(1);
  });

async function main() {
  // ── Step 1: Find Joy School ──────────────────────────────
  const homeschool = await step("find_joy_school", async () => {
    const rows = await svcSelect(
      `homeschools?name=ilike.*joy*&select=id,name,owner_user_id&limit=1`
    );
    if (!rows.length) throw new Error("Joy School not found");
    return rows[0];
  });
  const homeschoolId = homeschool.id;
  const ownerUserId = homeschool.owner_user_id;

  // ── Step 2: Term ─────────────────────────────────────────
  const term = await step("find_or_create_term", async () => {
    const existing = await svcSelect(
      `terms?homeschool_id=eq.${homeschoolId}&select=id,name&order=created_at.desc&limit=5`
    );
    const found = existing.find(
      (t) => t.name.includes("2026") || t.name.includes("1학기")
    );
    if (found) return found;
    const rows = await svcInsert("terms", [
      {
        homeschool_id: homeschoolId,
        name: "2026학년 1학기",
        start_date: "2026-03-02",
        end_date: "2026-07-31",
        status: "ACTIVE",
      },
    ]);
    return rows[0];
  });
  const termId = term.id;

  // ── Step 3: Teachers ─────────────────────────────────────
  const teacherNames = [
    "황정애", "강미령", "채리아", "양나영", "배우리",
    "수진", "예리", "준현", "진아", "승화", "홍도경", "누리",
  ];
  const teachers = await step("find_or_create_teachers", async () => {
    const existing = await svcSelect(
      `teacher_profiles?homeschool_id=eq.${homeschoolId}&select=id,display_name`
    );
    const result = {};
    for (const name of teacherNames) {
      const found = existing.find((t) => t.display_name === name);
      if (found) {
        result[name] = found;
      } else {
        const rows = await svcInsert("teacher_profiles", [
          { homeschool_id: homeschoolId, display_name: name, teacher_type: "GUEST_TEACHER" },
        ]);
        result[name] = rows[0];
      }
    }
    return result;
  });

  // ── Step 4: Courses ──────────────────────────────────────
  const courseDefs = [
    "주중예배", "독서", "한자", "소리영어(배우리)", "소리영어(채리아)",
    "워십댄스", "함께 책 읽기", "자기주도학습",
    "수학(수진)", "수학(준현)", "영독해", "영문법", "영단어/듣기",
    "과학(진아)", "독서(승화)", "성경적 세계관",
    "영어 모의test", "수학 모의test", "국어 문법과 논리",
  ];
  const courses = await step("find_or_create_courses", async () => {
    const existing = await svcSelect(
      `courses?homeschool_id=eq.${homeschoolId}&select=id,name`
    );
    const result = {};
    for (const name of courseDefs) {
      const found = existing.find((c) => c.name === name);
      if (found) {
        result[name] = found;
      } else {
        const rows = await svcInsert("courses", [
          { homeschool_id: homeschoolId, name, default_duration_min: 30 },
        ]);
        result[name] = rows[0];
      }
    }
    return result;
  });

  // ── Step 5: Families + Children ──────────────────────────
  const familyDefs = [
    ["예서+예훈 가족", [["예서", 2016], ["예훈", 2014]]],
    ["가은+경준 가족", [["가은", 2015], ["경준", 2015]]],
    ["예승 가족", [["예승", 2015]]],
    ["지애 가족", [["지애", 2015]]],
    ["주안 가족", [["주안", 2013]]],
    ["한결 가족", [["한결", 2017]]],
    ["신우 가족", [["신우", 2017]]],
    ["라엘 가족", [["라엘", 2017]]],
    ["동하 가족", [["동하", 2016]]],
    ["혜화 가족", [["혜화", 2016]]],
    ["지후 가족", [["지후", 2015]]],
    ["하린 가족", [["하린", 2014]]],
    ["지완 가족", [["지완", 2013]]],
    ["천수정애 가족", [["하나", 2012], ["예나", 2013]]],
    ["명일윤경 가족", [["노을", 2011], ["하늘", 2013]]],
    ["장관혜정 가족", [["은유", 2013]]],
    ["성함지연 가족", [["주원", 2011]]],
    ["도성수진 가족", [["혜인", 2011]]],
    ["예진 가족", [["예진", 2011]]],
  ];

  const children = await step("find_or_create_families_and_children", async () => {
    const existingFamilies = await svcSelect(
      `families?homeschool_id=eq.${homeschoolId}&select=id,family_name`
    );
    const familyIds = existingFamilies.map((f) => f.id);
    const existingChildren = familyIds.length
      ? await svcSelect(`children?family_id=in.(${familyIds.join(",")})&select=id,name,family_id`)
      : [];
    const result = {};
    for (const [familyName, childDefs] of familyDefs) {
      let family = existingFamilies.find((f) => f.family_name === familyName);
      if (!family) {
        const rows = await svcInsert("families", [
          { homeschool_id: homeschoolId, family_name: familyName, note: "" },
        ]);
        family = rows[0];
      }
      for (const [childName, birthYear] of childDefs) {
        let child = existingChildren.find((c) => c.name === childName);
        if (!child) {
          const rows = await svcInsert("children", [
            { family_id: family.id, name: childName, birth_date: `${birthYear}-03-01`, profile_note: "", status: "ACTIVE" },
          ]);
          child = rows[0];
        }
        result[childName] = child;
      }
    }
    return result;
  });

  // ── Step 6: Class Groups + Enrollments ───────────────────
  const classGroupDefs = [
    { name: "1학년", capacity: 5, students: ["한결", "신우", "라엘"] },
    { name: "2학년", capacity: 5, students: ["동하", "예서", "혜화"] },
    { name: "3학년", capacity: 8, students: ["가은", "경준", "지후", "예승", "지애"] },
    { name: "4학년", capacity: 5, students: ["하린", "예훈"] },
    { name: "5학년", capacity: 5, students: ["지완", "주안"] },
    { name: "중2", capacity: 5, students: ["은유", "예나", "하늘"] },
    { name: "중3", capacity: 8, students: ["예진", "노을", "주원", "혜인", "하나"] },
  ];

  const classGroups = await step("find_or_create_class_groups", async () => {
    const existing = await svcSelect(`class_groups?term_id=eq.${termId}&select=id,name,capacity`);
    const result = {};
    for (const def of classGroupDefs) {
      let cg = existing.find((g) => g.name === def.name);
      if (!cg) {
        const rows = await svcInsert("class_groups", [
          { term_id: termId, name: def.name, capacity: def.capacity },
        ]);
        cg = rows[0];
      }
      result[def.name] = cg;
      const enrollments = await svcSelect(`class_enrollments?class_group_id=eq.${cg.id}&select=id,child_id`);
      const enrolled = new Set(enrollments.map((e) => e.child_id));
      for (const name of def.students) {
        const child = children[name];
        if (child && !enrolled.has(child.id)) {
          await svcInsert("class_enrollments", [{ class_group_id: cg.id, child_id: child.id }]);
        }
      }
    }
    return result;
  });

  // ── Step 7: Delete old sessions & time slots, recreate ───
  await step("delete_old_sessions_and_slots", async () => {
    const allCgIds = Object.values(classGroups).map((g) => g.id);
    if (allCgIds.length) {
      // Delete sessions (cascades to assignments)
      await svcDelete(`class_sessions?class_group_id=in.(${allCgIds.join(",")})`);
    }
    // Delete time slots for this term
    await svcDelete(`time_slots?term_id=eq.${termId}`);
    return { deleted: true };
  });

  // ── Step 8: Create 30-min time slots ─────────────────────
  // Collect all needed 30-min slots from session definitions
  const slotSet = new Set();
  for (const [, day, startH, startM, endH, endM] of SESSION_DEFS) {
    let cursor = startH * 60 + startM;
    const end = endH * 60 + endM;
    while (cursor < end) {
      const s = `${String(Math.floor(cursor/60)).padStart(2,'0')}:${String(cursor%60).padStart(2,'0')}`;
      const e30 = cursor + 30;
      const e = `${String(Math.floor(e30/60)).padStart(2,'0')}:${String(e30%60).padStart(2,'0')}`;
      slotSet.add(`${day}_${s}_${e}`);
      cursor += 30;
    }
  }

  const timeSlots = await step("create_30min_time_slots", async () => {
    const result = {};
    for (const key of [...slotSet].sort()) {
      const [dayStr, start, end] = key.split("_");
      const rows = await svcInsert("time_slots", [
        { term_id: termId, day_of_week: parseInt(dayStr), start_time: start, end_time: end },
      ]);
      result[key] = rows[0];
    }
    return result;
  });

  // ── Step 9: Create sessions for each 30-min slot ─────────
  const slot = (day, hh, mm) => {
    const s = `${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}`;
    const e30 = hh * 60 + mm + 30;
    const e = `${String(Math.floor(e30/60)).padStart(2,'0')}:${String(e30%60).padStart(2,'0')}`;
    const key = `${day}_${s}_${e}`;
    const ts = timeSlots[key];
    if (!ts) throw new Error(`Slot not found: ${key}`);
    return ts.id;
  };

  await step("create_sessions_and_assignments", async () => {
    let created = 0, assigned = 0, conflicts = 0;

    for (const [cgName, day, startH, startM, endH, endM, courseName, teacherName] of SESSION_DEFS) {
      const classGroupId = classGroups[cgName]?.id;
      const courseId = courses[courseName]?.id;
      if (!classGroupId || !courseId) {
        console.warn(`  ⚠ Skip: ${cgName} ${courseName} - not found`);
        continue;
      }

      // Expand into 30-min slots
      let cursor = startH * 60 + startM;
      const endMin = endH * 60 + endM;
      while (cursor < endMin) {
        const hh = Math.floor(cursor / 60);
        const mm = cursor % 60;
        const timeSlotId = slot(day, hh, mm);

        const rows = await svcInsert("class_sessions", [
          {
            class_group_id: classGroupId,
            course_id: courseId,
            time_slot_id: timeSlotId,
            title: courseName,
            source_type: "MANUAL",
            status: "PLANNED",
            created_by_user_id: ownerUserId,
          },
        ]);
        created++;

        if (teacherName) {
          const teacherProfileId = teachers[teacherName]?.id;
          if (teacherProfileId) {
            try {
              await svcInsert("session_teacher_assignments", [
                { class_session_id: rows[0].id, teacher_profile_id: teacherProfileId, assignment_role: "MAIN" },
              ]);
              assigned++;
            } catch {
              conflicts++;
            }
          }
        }

        cursor += 30;
      }
    }

    return { created, assigned, conflicts };
  });

  console.log("\n✅ Joy School setup complete!");
}

// ── Session definitions ────────────────────────────────────
// [classGroup, day(0-6), startHour, startMin, endHour, endMin, course, teacher|null]
const SESSION_DEFS = [
  // ════════ 초등 1학년 (화,수,목) ════════
  ["1학년", 2, 10, 0, 12, 0, "주중예배", null],
  ["1학년", 3, 10, 0, 11, 0, "소리영어(배우리)", "배우리"],
  ["1학년", 4, 10, 0, 11, 0, "한자", "강미령"],

  // ════════ 초등 2학년 (화,수,목) ════════
  ["2학년", 2, 10, 0, 12, 0, "주중예배", null],
  ["2학년", 3, 10, 0, 11, 0, "함께 책 읽기", null],
  ["2학년", 3, 11, 0, 12, 0, "소리영어(배우리)", "배우리"],
  ["2학년", 4, 10, 0, 11, 0, "자기주도학습", null],
  ["2학년", 4, 11, 0, 12, 0, "한자", "강미령"],

  // ════════ 초등 3학년 (화,수,목) ════════
  ["3학년", 2, 10, 0, 12, 0, "주중예배", null],
  ["3학년", 3, 9, 0, 10, 0, "소리영어(배우리)", "배우리"],
  ["3학년", 3, 10, 0, 11, 0, "함께 책 읽기", null],
  ["3학년", 4, 9, 0, 10, 0, "한자", "강미령"],
  ["3학년", 4, 10, 0, 11, 0, "자기주도학습", null],

  // ════════ 초등 4학년 (화,수,목,금) ════════
  ["4학년", 2, 10, 0, 12, 0, "주중예배", null],
  ["4학년", 3, 9, 30, 11, 0, "독서", "황정애"],
  ["4학년", 3, 11, 0, 12, 0, "한자", "강미령"],
  ["4학년", 4, 10, 0, 11, 0, "소리영어(채리아)", "채리아"],
  ["4학년", 5, 10, 0, 11, 0, "워십댄스", "양나영"],

  // ════════ 초등 5학년 (화,수,목,금) ════════
  ["5학년", 2, 10, 0, 12, 0, "주중예배", null],
  ["5학년", 3, 11, 0, 12, 0, "한자", "강미령"],
  ["5학년", 4, 9, 30, 11, 0, "독서", "황정애"],
  ["5학년", 4, 11, 0, 12, 0, "소리영어(채리아)", "채리아"],
  ["5학년", 5, 10, 0, 11, 0, "워십댄스", "양나영"],

  // ════════ 중2 (월~금) ════════
  ["중2", 1, 9, 30, 11, 0, "수학(수진)", "수진"],
  ["중2", 1, 11, 0, 12, 0, "영독해", "예리"],
  ["중2", 2, 9, 0, 10, 0, "한자", "강미령"],
  ["중2", 2, 10, 0, 12, 0, "주중예배", null],
  ["중2", 2, 13, 0, 14, 30, "과학(진아)", "진아"],
  ["중2", 3, 9, 30, 11, 0, "수학(수진)", "수진"],
  ["중2", 3, 11, 0, 12, 0, "영문법", "예리"],
  ["중2", 4, 9, 0, 10, 0, "성경적 세계관", "홍도경"],
  ["중2", 4, 10, 30, 12, 0, "독서", "황정애"],
  ["중2", 5, 9, 0, 12, 0, "자기주도학습", null],
  ["중2", 5, 13, 0, 14, 0, "영어 모의test", null],
  ["중2", 5, 14, 0, 15, 0, "수학 모의test", null],
  ["중2", 5, 15, 0, 16, 30, "국어 문법과 논리", "누리"],

  // ════════ 중3 (월~금) ════════
  ["중3", 1, 9, 30, 11, 0, "영독해", "예리"],
  ["중3", 1, 11, 0, 12, 0, "수학(준현)", "준현"],
  ["중3", 1, 13, 0, 14, 0, "수학(준현)", "준현"],
  ["중3", 2, 9, 0, 10, 0, "영단어/듣기", null],
  ["중3", 2, 10, 0, 12, 0, "주중예배", null],
  ["중3", 3, 9, 30, 11, 0, "영문법", "예리"],
  ["중3", 3, 11, 0, 12, 0, "수학(준현)", "준현"],
  ["중3", 3, 13, 0, 14, 30, "독서(승화)", "승화"],
  ["중3", 3, 14, 30, 15, 30, "수학(준현)", "준현"],
  ["중3", 4, 9, 0, 10, 0, "성경적 세계관", "홍도경"],
  ["중3", 4, 10, 30, 12, 0, "과학(진아)", "진아"],
  ["중3", 5, 9, 0, 12, 0, "자기주도학습", null],
  ["중3", 5, 13, 0, 14, 0, "영어 모의test", null],
  ["중3", 5, 14, 0, 15, 0, "수학 모의test", null],
  ["중3", 5, 15, 0, 16, 30, "국어 문법과 논리", "누리"],
];

// ── Helpers ────────────────────────────────────────────────

function svcHeaders() {
  return { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` };
}

async function svcInsert(table, rows) {
  return await api("POST", `/rest/v1/${table}`, {
    headers: { ...svcHeaders(), Prefer: "return=representation" },
    body: rows,
  });
}

async function svcSelect(queryPath) {
  return await api("GET", `/rest/v1/${queryPath}`, { headers: svcHeaders() });
}

async function svcDelete(queryPath) {
  return await api("DELETE", `/rest/v1/${queryPath}`, { headers: svcHeaders() });
}

async function api(method, path, { headers = {}, body } = {}) {
  const url = `${SUPABASE_URL}${path}`;
  const res = await fetch(url, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed;
  try { parsed = text ? JSON.parse(text) : null; } catch { parsed = { raw: text }; }
  if (!res.ok) throw new Error(`${method} ${path} failed (${res.status}): ${JSON.stringify(parsed)}`);
  return parsed;
}

async function step(name, fn) {
  const started = Date.now();
  try {
    const result = await fn();
    report.steps.push({ name, ok: true, took_ms: Date.now() - started });
    console.log(`  ✓ ${name} (${Date.now() - started}ms)`);
    return result;
  } catch (err) {
    report.steps.push({ name, ok: false, took_ms: Date.now() - started, error: err.message });
    console.error(`  ✗ ${name}: ${err.message}`);
    throw err;
  }
}
