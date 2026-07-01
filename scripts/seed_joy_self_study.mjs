#!/usr/bin/env node
/**
 * JOY HOMESCHOOL 공과(수업외 자습) 시간표 샘플 시드.
 *
 * 앱의 자동 배치 로직(frontend/lib/src/services/self_study_planner.dart)과 동일한
 * 공강 계산을 JS로 재현하여, JOY 최신 학기의 수업 시간표(class_sessions/time_slots)
 * 를 기준으로 "7월 공과 자습" 계획과 자습 슬롯을 만든다. 방(room)은 수기 출석부
 * (ground truth)에 맞춘 best-effort 기본값을 넣고, 감독/제외는 비워 둔다.
 *
 * 사용법:
 *   DRY=1 SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed_joy_self_study.mjs  # 미리보기
 *   SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed_joy_self_study.mjs         # 실제 적용
 */
const URL = process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DRY = process.env.DRY === "1";
if (!KEY) {
  console.error("Missing SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const H = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  Accept: "application/json",
  "Content-Type": "application/json",
};

async function api(method, path, body) {
  const res = await fetch(`${URL}/rest/v1/${path}`, {
    method,
    headers:
      method === "POST" || method === "PATCH"
        ? { ...H, Prefer: "return=representation" }
        : H,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let p;
  try {
    p = text ? JSON.parse(text) : null;
  } catch {
    p = { raw: text };
  }
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}: ${JSON.stringify(p)}`);
  return p;
}
const get = (t, q = "") => api("GET", `${t}?${q}`);
const post = (t, rows) => api("POST", t, rows);
const patch = (t, q, body) => api("PATCH", `${t}?${q}`, body);
const del = (t, q) => api("DELETE", `${t}?${q}`);

// ── 자습 배치 설정 (앱 기본값과 동일) ──
const PLAN_NAME = "7월 공과 자습";
const DAYS = [1, 2, 3, 4, 5]; // 월~금
const WINDOW_START = 9 * 60; // 09:00
const WINDOW_END = 12 * 60; // 12:00
const MIN_GAP = 60;
const PERIOD_START = "2026-07-01";
const PERIOD_END = "2026-07-31";

const toMin = (t) => {
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
};
const fmt = (m) =>
  `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}:00`;
const hm = (m) => {
  const h = Math.floor(m / 60);
  const mm = m % 60;
  return mm === 0 ? `${h}` : `${h}:${String(mm).padStart(2, "0")}`;
};
const rangeLabel = (s, e) => `${hm(s)}-${hm(e)}시`;
const weekday = (d) => ["일", "월", "화", "수", "목", "금", "토"][d] ?? `${d}`;

function gradeInfo(name) {
  const m = name.match(/^(초|중|고)\s*([1-6])/);
  if (!m) return { band: "?", grade: 0 };
  return { band: m[1], grade: parseInt(m[2], 10) };
}
function gradeLabel(name) {
  const { band, grade } = gradeInfo(name);
  if (band === "?") return name;
  return band === "초" ? `${grade}학년` : `${band}${grade}`;
}

// 수기 출석부(ground truth)에 맞춘 best-effort 방 기본값.
function roomFor(name, day, start) {
  const { band, grade } = gradeInfo(name);
  if (band === "초") {
    if (day === 1) return "중예배실"; // 월 9-12 초등 전체
    if (day === 2) return "사랑"; // 화 9-10
    if (day === 3) return grade >= 6 ? "304호" : "아이작"; // 수: 초2/초5 아이작, 초6 304호
    if (day === 4) return start >= 11 * 60 ? "소망" : "믿음"; // 목: 9-10 믿음, 11-12 소망
    if (day === 5) return "믿음/소망"; // 금 9-12
  } else if (band === "중" || band === "고") {
    if (day === 5) return "304호"; // 금 9-12 중등
    if (start >= 11 * 60) return "304호"; // 11-12 중3
    return grade >= 3 ? "믿음" : "아이작"; // 9-10 중2/중3
  }
  return "";
}

// 앱과 동일한 공강 → 슬롯 알고리즘.
function generate(groupIds, occByGroupDay) {
  const out = [];
  for (const gid of groupIds) {
    for (const day of DAYS) {
      const occ = (occByGroupDay[gid]?.[day] || [])
        .map((o) => [Math.max(o[0], WINDOW_START), Math.min(o[1], WINDOW_END)])
        .filter((iv) => iv[1] > iv[0])
        .sort((a, b) => a[0] - b[0]);
      const merged = [];
      for (const iv of occ) {
        if (!merged.length || iv[0] > merged[merged.length - 1][1]) {
          merged.push([iv[0], iv[1]]);
        } else if (iv[1] > merged[merged.length - 1][1]) {
          merged[merged.length - 1][1] = iv[1];
        }
      }
      let cursor = WINDOW_START;
      for (const m of merged) {
        if (m[0] - cursor >= MIN_GAP) out.push({ gid, day, start: cursor, end: m[0] });
        if (m[1] > cursor) cursor = m[1];
      }
      if (WINDOW_END - cursor >= MIN_GAP) out.push({ gid, day, start: cursor, end: WINDOW_END });
    }
  }
  return out;
}

async function main() {
  const schools = await get("homeschools", "select=id,name,owner_user_id");
  const joy = schools.find((s) => /joy/i.test(s.name));
  if (!joy) throw new Error("JOY not found");
  const terms = await get(
    "terms",
    `homeschool_id=eq.${joy.id}&select=id,name,status,start_date,end_date&order=created_at.desc`,
  );
  if (!terms.length) throw new Error("No term");
  const term = terms[0];
  console.log(`[ctx] JOY=${joy.id} term="${term.name}" (${term.status}) ${term.id}  DRY=${DRY}`);

  const groups = await get("class_groups", `term_id=eq.${term.id}&select=id,name`);
  const gName = Object.fromEntries(groups.map((g) => [g.id, g.name]));
  const groupIds = groups.map((g) => g.id);
  const slots = await get(
    "time_slots",
    `term_id=eq.${term.id}&select=id,day_of_week,start_time,end_time`,
  );
  const slotById = Object.fromEntries(slots.map((s) => [s.id, s]));
  const sessions = groupIds.length
    ? await get(
        "class_sessions",
        `class_group_id=in.(${groupIds.join(",")})&select=class_group_id,time_slot_id,status`,
      )
    : [];

  // 점유 구간: 반 × 요일.
  const occ = {};
  for (const se of sessions) {
    if ((se.status || "").toUpperCase() === "CANCELED") continue;
    const ts = slotById[se.time_slot_id];
    if (!ts) continue;
    (occ[se.class_group_id] ??= {})[ts.day_of_week] ??= [];
    occ[se.class_group_id][ts.day_of_week].push([
      toMin(ts.start_time),
      toMin(ts.end_time),
    ]);
  }
  console.log(`[load] groups=${groups.length} slots=${slots.length} sessions=${sessions.length}`);

  const generated = generate(groupIds, occ);
  const groupIndex = Object.fromEntries(groupIds.map((g, i) => [g, i]));
  const slotRows = generated.map((g) => ({
    class_group_id: g.gid,
    day_of_week: g.day,
    start_time: fmt(g.start),
    end_time: fmt(g.end),
    room: roomFor(gName[g.gid], g.day, g.start),
    supervisor_teacher_id: null,
    label: `${gradeLabel(gName[g.gid])} 자습`,
    sort_order: g.day * 100000 + g.start * 100 + (groupIndex[g.gid] ?? 0),
  }));

  // 요약 출력(요일 → 방 → 반).
  console.log(`\n[plan] "${PLAN_NAME}"  요일=${DAYS.map(weekday).join("")} 창=${hm(WINDOW_START)}-${hm(WINDOW_END)}시 최소공강=${MIN_GAP}분`);
  console.log(`[slots] 생성 ${slotRows.length}개`);
  for (const day of DAYS) {
    const dayRows = generated
      .map((g, i) => ({ g, r: slotRows[i] }))
      .filter((x) => x.g.day === day)
      .sort((a, b) => a.r.sort_order - b.r.sort_order);
    if (!dayRows.length) continue;
    console.log(`  [${weekday(day)}]`);
    for (const { g, r } of dayRows) {
      console.log(
        `    ${gName[g.gid].padEnd(5)} ${rangeLabel(g.start, g.end).padEnd(9)} → ${r.room || "(미정)"}`,
      );
    }
  }

  if (DRY) {
    console.log("\nDRY-RUN complete (no writes). 실제 적용하려면 DRY 없이 다시 실행하세요.");
    return;
  }

  // 계획 upsert (이름 기준).
  const existing = await get(
    "self_study_plans",
    `term_id=eq.${term.id}&name=eq.${encodeURIComponent(PLAN_NAME)}&select=id`,
  );
  let planId;
  const planBody = {
    term_id: term.id,
    name: PLAN_NAME,
    days: DAYS,
    window_start: fmt(WINDOW_START).slice(0, 5),
    window_end: fmt(WINDOW_END).slice(0, 5),
    period_start: PERIOD_START,
    period_end: PERIOD_END,
    min_gap_minutes: MIN_GAP,
    note: "수기 7월 공과(자습) 출석부를 기준으로 자동 생성한 샘플. 방은 best-effort 기본값.",
    created_by_user_id: joy.owner_user_id,
  };
  if (existing.length) {
    planId = existing[0].id;
    await patch("self_study_plans", `id=eq.${planId}`, planBody);
    console.log(`\n[plan] 기존 계획 갱신 ${planId}`);
  } else {
    const created = await post("self_study_plans", planBody);
    planId = created[0].id;
    console.log(`\n[plan] 신규 계획 생성 ${planId}`);
  }

  // 슬롯 전면 재생성.
  await del("self_study_slots", `plan_id=eq.${planId}`);
  const withPlan = slotRows.map((r) => ({ ...r, plan_id: planId }));
  for (let i = 0; i < withPlan.length; i += 200) {
    await post("self_study_slots", withPlan.slice(i, i + 200));
  }
  console.log(`[slots] ${withPlan.length}개 삽입 완료`);
  console.log("\n✅ JOY 공과 자습 샘플 시드 완료. 앱 관리자 → 자습 탭에서 검토하세요.");
}

main().catch((e) => {
  console.error("FAILED:", e.message);
  process.exit(1);
});
