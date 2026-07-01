#!/usr/bin/env node
// 특정 아동을 자습 계획의 (그 아이 반) 모든 슬롯에서 제외한다(멱등).
// 사용법: CHILD_NAME=혜화 [PLAN_NAME="7월 공과 자습"] SUPABASE_SERVICE_ROLE_KEY=... node scripts/exclude_self_study_child.mjs
const BASE = "https://avursvhmilcsssabqtkx.supabase.co";
const SR = process.env.SUPABASE_SERVICE_ROLE_KEY;
const CHILD_NAME = process.env.CHILD_NAME;
const PLAN_NAME = process.env.PLAN_NAME || "7월 공과 자습";
if (!SR || !CHILD_NAME) { console.error("need SUPABASE_SERVICE_ROLE_KEY and CHILD_NAME"); process.exit(1); }
const H = { apikey: SR, Authorization: `Bearer ${SR}`, "Content-Type": "application/json" };
const g = async (t, q) => { const r = await fetch(`${BASE}/rest/v1/${t}?${q}`, { headers: H }); if (!r.ok) throw new Error(`${t}: ${r.status} ${await r.text()}`); return r.json(); };

const kids = await g("children", `name=eq.${encodeURIComponent(CHILD_NAME)}&select=id,name`);
if (kids.length !== 1) { console.error(`이름 "${CHILD_NAME}" 매칭 ${kids.length}건 (1건이어야 함): ${JSON.stringify(kids)}`); process.exit(1); }
const child = kids[0];
const plan = (await g("self_study_plans", `name=eq.${encodeURIComponent(PLAN_NAME)}&select=id`))[0];
if (!plan) { console.error(`계획 "${PLAN_NAME}" 없음`); process.exit(1); }
const gids = (await g("class_enrollments", `child_id=eq.${child.id}&select=class_group_id`)).map((e) => e.class_group_id);
if (!gids.length) { console.error("반 배정 없음"); process.exit(1); }
const slots = await g("self_study_slots", `plan_id=eq.${plan.id}&class_group_id=in.(${gids.join(",")})&select=id,day_of_week,room`);
console.log(`child=${child.name}(${child.id}) plan=${plan.id} slots=${slots.length}`);

const rows = slots.map((s) => ({ slot_id: s.id, child_id: child.id }));
const res = await fetch(`${BASE}/rest/v1/self_study_slot_exclusions?on_conflict=slot_id,child_id`, {
  method: "POST",
  headers: { ...H, Prefer: "resolution=ignore-duplicates,return=representation" },
  body: JSON.stringify(rows),
});
if (!res.ok) { console.error("insert 실패:", res.status, await res.text()); process.exit(1); }
const inserted = await res.json();
console.log(`✅ 제외 upsert 완료: 슬롯 ${slots.length}개 (신규 ${inserted.length}건)`);
