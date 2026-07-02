#!/usr/bin/env node
/**
 * JOY 자습 배정 추가 조정 (엑셀 외 추가 요청분).
 *
 * 요청1: 월·수 9-10 아이작에 하늘·예나(중2A)를 9:00-9:30 자습으로 추가.
 *        (중2A는 9:30부터 수업이라 60분 미만 공강 → 자동배치가 스킵했던 케이스.
 *         출석부는 30분 밴드로 렌더되어 9:00-9:30 자습 / 9:30-10:00 수업(X)로 표기됨.)
 * 요청2: 월·수 11-12 304호에 주원(중3J) 자습 슬롯 추가.
 * 요청3: 화 9-10 사랑은 예승(초3)·지완(초5)만 남기고 나머지(지후·예훈·하린) 제외.
 * 요청4: 금 9-12 304호에서 주원(중3J) 제외.
 *
 * 멱등: 슬롯은 (계획·반·요일·시간·방)이 이미 있으면 생성하지 않고, 제외는
 * unique(slot_id, child_id)로 중복 무시. 여러 번 실행해도 결과 동일.
 *
 * ⚠ 관리자 UI에서 '다시 배치'하면 자동 생성이 명단을 덮어쓰므로,
 *   reconcile_joy_excel_roster.mjs 재실행 후 이 스크립트도 다시 실행해야 함.
 *
 * 실행: node scripts/adjust_joy_self_study.mjs           # 적용
 *       DRY=1 node scripts/adjust_joy_self_study.mjs     # 미적용(현재 상태만 조회)
 * 토큰: .env 의 SUPABASE_TOKEN (Supabase 관리 액세스 토큰) 자동 로드.
 */
import { readFileSync } from "node:fs";

function loadEnv() {
  if (process.env.SUPABASE_TOKEN) return;
  try {
    for (const line of readFileSync(".env", "utf-8").split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim();
    }
  } catch {}
}
loadEnv();

const REF = process.env.SUPABASE_PROJECT_REF || "avursvhmilcsssabqtkx";
const TOK = process.env.SUPABASE_TOKEN;
const DRY = process.env.DRY === "1";
if (!TOK) { console.error("need SUPABASE_TOKEN (.env)"); process.exit(1); }

async function sql(query) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
    method: "POST",
    headers: { Authorization: "Bearer " + TOK, "Content-Type": "application/json" },
    body: JSON.stringify({ query }),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`SQL ${r.status}: ${text.slice(0, 800)}`);
  try { return JSON.parse(text); } catch { return text; }
}

const PLAN = "7월 공과 자습";

const MUTATION = `
do $$
declare
  pid uuid; tid uuid; hid uuid;
  g2a uuid; g3j uuid; t_jiyeon uuid; t_sujin uuid;
begin
  select id, term_id into pid, tid from self_study_plans where name='${PLAN}' limit 1;
  select homeschool_id into hid from terms where id = tid;
  select id into g2a from class_groups where term_id=tid and name='중2A';
  select id into g3j from class_groups where term_id=tid and name='중3J';
  select id into t_jiyeon from teacher_profiles where homeschool_id=hid and display_name='김지연' limit 1;
  select id into t_sujin  from teacher_profiles where homeschool_id=hid and display_name='김수진' limit 1;

  -- 요청1: 중2A 월(1)·수(3) 09:00-09:30 아이작 슬롯 (없으면 생성)
  insert into self_study_slots (plan_id, class_group_id, day_of_week, start_time, end_time, room, supervisor_teacher_id)
  select pid, g2a, d, time '09:00', time '09:30', '아이작', t_jiyeon
  from unnest(array[1,3]) as d
  where not exists (
    select 1 from self_study_slots s
    where s.plan_id=pid and s.class_group_id=g2a and s.day_of_week=d
      and s.start_time=time '09:00' and s.end_time=time '09:30' and trim(s.room)='아이작');

  -- 요청1: 새 중2A 아이작 슬롯에서 은유 제외 → 명단 하늘·예나
  insert into self_study_slot_exclusions (slot_id, child_id)
  select s.id, c.id
  from self_study_slots s
  join class_enrollments ce on ce.class_group_id=s.class_group_id
  join children c on c.id=ce.child_id and c.name='은유'
  where s.plan_id=pid and s.class_group_id=g2a and s.day_of_week in (1,3)
    and s.start_time=time '09:00' and trim(s.room)='아이작'
  on conflict (slot_id, child_id) do nothing;

  -- 요청2: 중3J 월(1)·수(3) 11:00-12:00 304호 슬롯 (없으면 생성) → 명단 주원
  insert into self_study_slots (plan_id, class_group_id, day_of_week, start_time, end_time, room, supervisor_teacher_id)
  select pid, g3j, d, time '11:00', time '12:00', '304호', t_sujin
  from unnest(array[1,3]) as d
  where not exists (
    select 1 from self_study_slots s
    where s.plan_id=pid and s.class_group_id=g3j and s.day_of_week=d
      and s.start_time=time '11:00' and s.end_time=time '12:00' and trim(s.room)='304호');

  -- 요청3: 화(2) 9-10 사랑은 예승(초3)·지완(초5)만 → 나머지 전원 제외
  insert into self_study_slot_exclusions (slot_id, child_id)
  select s.id, ce.child_id
  from self_study_slots s
  join class_groups g on g.id=s.class_group_id
  join class_enrollments ce on ce.class_group_id=s.class_group_id
  join children c on c.id=ce.child_id
  where s.plan_id=pid and s.day_of_week=2 and trim(s.room)='사랑'
    and not ((g.name='초3' and c.name='예승') or (g.name='초5' and c.name='지완'))
  on conflict (slot_id, child_id) do nothing;

  -- 요청4: 금(5) 304호 중3J 슬롯에서 주원 제외
  insert into self_study_slot_exclusions (slot_id, child_id)
  select s.id, c.id
  from self_study_slots s
  join class_enrollments ce on ce.class_group_id=s.class_group_id
  join children c on c.id=ce.child_id and c.name='주원'
  where s.plan_id=pid and s.class_group_id=g3j and s.day_of_week=5 and trim(s.room)='304호'
  on conflict (slot_id, child_id) do nothing;
end $$;
`;

const VERIFY = `
with sr as (
  select s.day_of_week as dow, to_char(s.start_time,'HH24:MI') st, to_char(s.end_time,'HH24:MI') et,
         nullif(trim(s.room),'') room, g.name grp,
         (select coalesce(array_agg(c.name order by c.name), array[]::text[])
            from class_enrollments ce join children c on c.id=ce.child_id
           where ce.class_group_id=s.class_group_id
             and not exists (select 1 from self_study_slot_exclusions x
                             where x.slot_id=s.id and x.child_id=ce.child_id)) roster
  from self_study_slots s
  join self_study_plans p on p.id=s.plan_id and p.name='${PLAN}'
  join class_groups g on g.id=s.class_group_id
  where (s.day_of_week in (1,3) and trim(s.room) in ('아이작','304호'))
     or (s.day_of_week=2 and trim(s.room)='사랑')
     or (s.day_of_week=5 and trim(s.room)='304호')
)
select (array['일','월','화','수','목','금','토'])[dow+1] as day, st, et,
       coalesce(room,'(미정)') as room, grp,
       array_length(roster,1) as n, array_to_string(roster,',') as roster
from sr
where array_length(roster,1) is not null
order by dow, st, room, grp;
`;

const label = (r) => `  ${r.day} ${r.st}-${r.et} ${String(r.room).padEnd(5)} ${String(r.grp).padEnd(5)} → ${r.n}명 [${r.roster}]`;

if (DRY) {
  console.log(`DRY-RUN: 변경 미적용. 현재 대상 (요일·방) 명단:\n`);
  const before = await sql(VERIFY);
  before.forEach((r) => console.log(label(r)));
  console.log(`\n(적용하려면 DRY 없이 실행)`);
} else {
  await sql(MUTATION);
  console.log(`✅ 적용 완료. 대상 (요일·방) 명단:\n`);
  const after = await sql(VERIFY);
  after.forEach((r) => console.log(label(r)));
}
