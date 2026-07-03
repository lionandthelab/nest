#!/usr/bin/env node
// 감독(및 교사) 프로필 ↔ 실제 가입 계정 연결 현황 리컨사일.
//
// 배경: 엑셀/시드 스크립트가 만든 teacher_profiles 는 display_name(한글 이름)만 있고
// user_id 가 null 이라 실제 가입 계정과 연결되지 않는다. 그래서 감독 선생님이
// 계정으로 로그인해도 앱이 "이 사람 = 그 교사"로 인식하지 못해 감독표가 안 뜬다.
//
// 이 스크립트는 teacher_profiles.display_name 과 가입 멤버(profiles.full_name)를
// 이름으로 매칭해 teacher_profiles.user_id 를 역채운다.
//   - 기본은 DRY(리포트만, 쓰기 없음).
//   - APPLY=1 일 때만 "정확히 1명 일치" 건에 한해 실제 PATCH.
//   - ALL_TEACHERS=1 이면 감독뿐 아니라 모든 교사 프로필로 대상 확장(기본은 감독만).
//
// 사용법:
//   SUPABASE_SERVICE_ROLE_KEY=... node scripts/reconcile_supervisor_accounts.mjs            # 미리보기
//   APPLY=1 SUPABASE_SERVICE_ROLE_KEY=... node scripts/reconcile_supervisor_accounts.mjs     # 1:1 매칭만 연결
//   ALL_TEACHERS=1 SUPABASE_SERVICE_ROLE_KEY=... node scripts/reconcile_supervisor_accounts.mjs
const BASE = process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const SR = process.env.SUPABASE_SERVICE_ROLE_KEY;
const APPLY = process.env.APPLY === "1";
const ALL_TEACHERS = process.env.ALL_TEACHERS === "1";
if (!SR) { console.error("need SUPABASE_SERVICE_ROLE_KEY"); process.exit(1); }
const H = { apikey: SR, Authorization: `Bearer ${SR}`, "Content-Type": "application/json" };
const g = async (t, q) => {
  const r = await fetch(`${BASE}/rest/v1/${t}?${q}`, { headers: H });
  if (!r.ok) throw new Error(`${t}: ${r.status} ${await r.text()}`);
  return r.json();
};
// 공백 제거 후 비교 — 이름 표기 흔들림('김 지연' vs '김지연')을 흡수.
const norm = (s) => (s || "").replace(/\s+/g, "").trim();

// 1) JOY 홈스쿨
const schools = await g("homeschools", "select=id,name");
const joy = schools.find((s) => /joy/i.test(s.name));
if (!joy) throw new Error("JOY homeschool not found");
const hid = joy.id;

// 2) 교사 프로필
const teachers = await g("teacher_profiles", `homeschool_id=eq.${hid}&select=id,display_name,user_id,teacher_type`);

// 3) 활성 멤버십 + 프로필(이름)
const mships = await g("homeschool_memberships", `homeschool_id=eq.${hid}&status=eq.ACTIVE&select=user_id,role`);
const rolesByUser = {};
for (const m of mships) (rolesByUser[m.user_id] ??= []).push(m.role);
const userIds = [...new Set(mships.map((m) => m.user_id))];
const profs = userIds.length ? await g("profiles", `id=in.(${userIds.join(",")})&select=id,full_name,email`) : [];
const profById = Object.fromEntries(profs.map((p) => [p.id, p]));

// 이름(정규화된 full_name) → [member]
const membersByName = {};
for (const uid of userIds) {
  const p = profById[uid];
  const nm = norm(p?.full_name);
  if (!nm) continue;
  (membersByName[nm] ??= []).push({ userId: uid, name: p.full_name, email: p.email, roles: rolesByUser[uid] || [] });
}

// 4) 실제 감독으로 배정된 teacher_profile id 집합(슬롯 감독 + 회전 감독)
const terms = await g("terms", `homeschool_id=eq.${hid}&select=id`);
const termIds = terms.map((t) => t.id);
const plans = termIds.length ? await g("self_study_plans", `term_id=in.(${termIds.join(",")})&select=id`) : [];
const planIds = plans.map((p) => p.id);
const supIds = new Set();
if (planIds.length) {
  const slots = await g("self_study_slots", `plan_id=in.(${planIds.join(",")})&select=supervisor_teacher_id`);
  for (const s of slots) if (s.supervisor_teacher_id) supIds.add(s.supervisor_teacher_id);
  const rots = await g("self_study_supervisions", `plan_id=in.(${planIds.join(",")})&select=supervisor_teacher_id`);
  for (const r of rots) if (r.supervisor_teacher_id) supIds.add(r.supervisor_teacher_id);
}

// 5) 분류
const cats = { linked: [], matchOne: [], ambiguous: [], noAccount: [] };
for (const t of teachers) {
  const isSup = supIds.has(t.id);
  if (!ALL_TEACHERS && !isSup) continue; // 기본은 감독만
  const rec = { ...t, isSup };
  if (t.user_id) {
    const p = profById[t.user_id];
    rec.linkedTo = p ? `${p.full_name || "(이름없음)"} <${p.email || "?"}>` : `${t.user_id} (멤버 아님)`;
    cats.linked.push(rec);
    continue;
  }
  const matches = membersByName[norm(t.display_name)] || [];
  if (matches.length === 1) { rec.match = matches[0]; cats.matchOne.push(rec); }
  else if (matches.length > 1) { rec.matches = matches; cats.ambiguous.push(rec); }
  else cats.noAccount.push(rec);
}

// 6) 리포트
const star = (r) => (r.isSup ? "⭐" : "  ");
const roleTag = (roles) => (roles.length ? `[${roles.join(",")}]` : "[역할없음]");
console.log(`\n=== 감독 계정 연결 현황 (JOY) ${ALL_TEACHERS ? "· 전체 교사" : "· 감독만"} ===`);
console.log(`교사 프로필 ${teachers.length}개 · 감독 배정 ${supIds.size}개 · 활성 멤버 ${userIds.length}명   (⭐=실제 감독)\n`);

console.log(`▶ 연결 가능 (정확히 1명 일치) — ${cats.matchOne.length}건 ${APPLY ? "→ 이번에 연결" : "(APPLY=1 로 연결)"}`);
for (const r of cats.matchOne) console.log(`  ${star(r)} ${r.display_name.padEnd(6)} → ${r.match.name} <${r.match.email}> ${roleTag(r.match.roles)}`);

console.log(`\n▶ 동명이인/중복 — ${cats.ambiguous.length}건 (수동 확정 필요)`);
for (const r of cats.ambiguous) console.log(`  ${star(r)} ${r.display_name.padEnd(6)} → ${r.matches.map((m) => `${m.name}<${m.email}>${roleTag(m.roles)}`).join(" | ")}`);

console.log(`\n▶ 미가입 (일치 계정 없음) — ${cats.noAccount.length}건`);
for (const r of cats.noAccount) console.log(`  ${star(r)} ${r.display_name}`);

console.log(`\n▶ 이미 연결됨 — ${cats.linked.length}건`);
for (const r of cats.linked) console.log(`  ${star(r)} ${r.display_name.padEnd(6)} → ${r.linkedTo}`);

// 7) 적용
if (!APPLY) {
  console.log(`\nDRY-RUN (쓰기 없음). 위 '연결 가능' 목록을 확인한 뒤 APPLY=1 로 실행하세요.`);
  process.exit(0);
}
let done = 0;
for (const r of cats.matchOne) {
  const res = await fetch(`${BASE}/rest/v1/teacher_profiles?id=eq.${r.id}`, {
    method: "PATCH", headers: { ...H, Prefer: "return=minimal" },
    body: JSON.stringify({ user_id: r.match.userId }),
  });
  if (!res.ok) throw new Error(`patch ${r.display_name}: ${res.status} ${await res.text()}`);
  done++;
}
console.log(`\n✅ ${done}건 user_id 연결 완료. 앱이 이 계정을 해당 교사로 인식합니다.`);
console.log(`   (교사 뷰는 즉시 '내 감독' 노출. 학부모 뷰 노출은 2단계 UI 작업 후 적용.)`);
