// Update JOY School database based on annotated joy_school_data.md
// Usage: node --env-file=.env scripts/update_joy_school.mjs

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://avursvhmilcsssabqtkx.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!KEY) { console.error('Missing SUPABASE_SERVICE_ROLE_KEY'); process.exit(1); }

const hdrs = {
  apikey: KEY, Authorization: `Bearer ${KEY}`,
  Accept: 'application/json', 'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

async function get(table, params = '') {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, { headers: hdrs });
  if (!r.ok) throw new Error(`GET ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}
async function patch(table, params, body) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, { method: 'PATCH', headers: hdrs, body: JSON.stringify(body) });
  if (!r.ok) throw new Error(`PATCH ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}
async function del(table, params) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, { method: 'DELETE', headers: hdrs });
  if (!r.ok) throw new Error(`DELETE ${table}: ${r.status} ${await r.text()}`);
}
async function post(table, body) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, { method: 'POST', headers: hdrs, body: JSON.stringify(body) });
  if (!r.ok) throw new Error(`POST ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}

async function main() {
  // ── Find JOY School & term ──
  const schools = await get('homeschools', 'select=*');
  const joy = schools.find(s => s.name.includes('JOY'));
  if (!joy) { console.error('JOY School not found'); process.exit(1); }
  const hid = joy.id;
  console.log(`JOY School: ${hid}`);

  const terms = await get('terms', `homeschool_id=eq.${hid}&select=*`);
  const term = terms[0];
  if (!term) { console.error('No term found'); process.exit(1); }
  console.log(`Term: ${term.name} (${term.id})`);

  // ═══════════════════════════════════════════════════
  // 1. DELETE families marked for deletion
  // ═══════════════════════════════════════════════════
  const familiesToDelete = [
    '0bdc6271-e6c5-4dc4-a15c-a88bb9df69c2', // 영주리아
    '502ba8f1-7316-4126-9c4a-e1ddb4d4bd5a', // 영길수아
    '77a50241-d481-4cb3-963e-835d5ce75145', // 강래준형
    '86c85750-bb54-40b1-9a24-301d4a22e9b7', // 성수혜경
    '6fc01191-2125-488b-ae8f-186630b03b7a', // 한성미영
    '0cdec7ff-ef3e-432c-bc84-4ffcd5fa5cb3', // 걸미령
    'fe9dc927-5406-408b-8a9e-9bb4fcfd8ddb', // 의석정니
    '0f8857e4-7ff0-44a5-b164-b5d615429b0a', // 도경예리
  ];

  // First delete children in those families (to avoid FK issues with class_enrollments)
  const childrenInDeletedFamilies = await get('children', `family_id=in.(${familiesToDelete.join(',')})&select=id,name,family_id`);
  console.log(`\n── Deleting ${childrenInDeletedFamilies.length} children from ${familiesToDelete.length} families ──`);
  for (const child of childrenInDeletedFamilies) {
    // Delete class enrollments first
    await del('class_enrollments', `child_id=eq.${child.id}`).catch(() => {});
    await del('children', `id=eq.${child.id}`);
    console.log(`  Deleted child: ${child.name} (${child.id})`);
  }

  // Delete family_guardians then families
  for (const fid of familiesToDelete) {
    await del('family_guardians', `family_id=eq.${fid}`).catch(() => {});
    await del('families', `id=eq.${fid}`);
    console.log(`  Deleted family: ${fid}`);
  }

  // ═══════════════════════════════════════════════════
  // 2. RENAME families
  // ═══════════════════════════════════════════════════
  const familyRenames = [
    ['7bceaf4c-a1b4-47c2-8f39-c806dc417dbb', '추민성♡강미령 가정'],
    ['42a905a6-0104-48be-9b6f-6ba1d989c778', '지정엽♡신혜미 가정'],
    ['7f98b63b-78d2-437b-827e-f3bb54eac3e0', '최호석♡배우리 가정'],
    ['5011c30c-c2ac-49a2-829e-4e427fdd85bf', '윤결♡오미령 가정'],
    ['79b2d3ad-c839-4da1-b29a-c2d457b2f040', '김의석♡최정니 가정'],
    ['fe422d2b-e822-4a42-a2d1-ef01e065ec90', '안영길♡오수아 가정'],
    ['06e5ce25-aa77-40ab-8747-bd5325f2299c', '채영주♡채리아 가정'],
    ['850f47fe-0587-4adf-a060-2764440f5dee', '장세윤♡강유정 가정'],
    ['0758c75a-09df-41dc-826e-b2a5b6df02f8', '홍천수♡황정애 가정'],
    ['0e037ce2-5658-4777-be95-b216ed0db451', '김명일♡노윤경 가정'],
    ['247c53d4-0b5d-4e36-8d05-6d10709f1ecd', '이장관♡나혜정 가정'],
    ['41c36f34-3671-44a7-86c7-a736f1b7d677', '이임시♡김지연 가정'],
    ['bfb3ce7b-d937-4193-9ed2-da871574f0c6', '차도성♡김수진 가정'],
    ['66699b87-fc72-4403-b208-af92e03dce59', '황도경♡설예리 가정'],
    ['e8e1c974-662b-4e19-b169-a5d2a850c334', '김강래♡김준형 가정'],
    ['37191e78-fc11-4f04-be81-3729d26ea0c8', '임성수♡최혜경 가정'],
  ];

  console.log(`\n── Renaming ${familyRenames.length} families ──`);
  for (const [id, newName] of familyRenames) {
    await patch('families', `id=eq.${id}`, { family_name: newName });
    console.log(`  ${id} → ${newName}`);
  }

  // ═══════════════════════════════════════════════════
  // 3. TEACHER profile updates (rename + merge duplicates)
  // ═══════════════════════════════════════════════════
  const teachers = await get('teacher_profiles', `homeschool_id=eq.${hid}&select=*`);
  const tByName = Object.fromEntries(teachers.map(t => [t.display_name, t]));

  console.log(`\n── Updating teacher profiles ──`);

  // Rename teachers
  const teacherRenames = [
    ['진아', '양진아'],
    ['누리', '양누리'],
  ];
  for (const [oldName, newName] of teacherRenames) {
    const t = tByName[oldName];
    if (t) {
      await patch('teacher_profiles', `id=eq.${t.id}`, { display_name: newName });
      console.log(`  Renamed: ${oldName} → ${newName}`);
    } else {
      console.log(`  Not found: ${oldName}`);
    }
  }

  // Merge duplicate teachers: reassign session_teacher_assignments, then delete duplicate
  const teacherMerges = [
    ['준현', '김준형'],   // 준현 is same as 김준형
    ['승화', '채송화'],   // 승화 is same as 채송화
    ['홍도경', '황도경'], // 홍도경 is same as 황도경
  ];
  for (const [dupName, keepName] of teacherMerges) {
    const dup = tByName[dupName];
    const keep = tByName[keepName];
    if (!dup || !keep) {
      console.log(`  Merge skip: ${dupName} → ${keepName} (not found)`);
      continue;
    }
    // Reassign session_teacher_assignments
    await patch('session_teacher_assignments', `teacher_profile_id=eq.${dup.id}`, { teacher_profile_id: keep.id }).catch(() => []);
    // Update class_groups main_teacher_id
    await patch('class_groups', `main_teacher_id=eq.${dup.id}`, { main_teacher_id: keep.id }).catch(() => []);
    // Delete duplicate
    await del('teacher_profiles', `id=eq.${dup.id}`);
    console.log(`  Merged: ${dupName} → ${keepName} (deleted ${dup.id})`);
  }

  // ═══════════════════════════════════════════════════
  // 4. RENAME course: 수학(준현) → 수학(준형)
  // ═══════════════════════════════════════════════════
  const courses = await get('courses', `homeschool_id=eq.${hid}&select=*`);
  const mathCourse = courses.find(c => c.name === '수학(준현)');
  if (mathCourse) {
    await patch('courses', `id=eq.${mathCourse.id}`, { name: '수학(준형)' });
    console.log(`\n── Renamed course: 수학(준현) → 수학(준형) ──`);
  }

  // ═══════════════════════════════════════════════════
  // 5. ADD classrooms: 304호, 303호, 자모실, 코너방, 드림방, 아이작, 예서집
  // ═══════════════════════════════════════════════════
  const newClassrooms = ['304호', '303호', '자모실', '코너방', '드림방', '아이작', '예서집'];
  const existingRooms = await get('classrooms', `term_id=eq.${term.id}&select=*`);
  const existingNames = new Set(existingRooms.map(r => r.name));

  console.log(`\n── Adding classrooms ──`);
  for (const name of newClassrooms) {
    if (existingNames.has(name)) {
      console.log(`  Already exists: ${name}`);
      continue;
    }
    await post('classrooms', { term_id: term.id, name, capacity: 10, note: '' });
    console.log(`  Added: ${name}`);
  }

  // ═══════════════════════════════════════════════════
  // 6. ASSIGN locations to sessions based on timetable
  // ═══════════════════════════════════════════════════
  console.log(`\n── Assigning session locations ──`);

  // Refresh data
  const updatedCourses = await get('courses', `homeschool_id=eq.${hid}&select=*`);
  const courseByName = Object.fromEntries(updatedCourses.map(c => [c.name, c]));
  const classGroups = await get('class_groups', `term_id=eq.${term.id}&select=*`);
  const cgByName = Object.fromEntries(classGroups.map(g => [g.name, g]));
  const timeSlots = await get('time_slots', `term_id=eq.${term.id}&select=*`);
  const groupIds = classGroups.map(g => g.id);
  const sessions = await get('class_sessions', `class_group_id=in.(${groupIds.join(',')})&select=*`);

  // Helper: find session(s) matching criteria
  function findSessions(className, courseName, dayOfWeek, startTimes) {
    const cg = cgByName[className];
    const co = courseByName[courseName];
    if (!cg || !co) return [];
    return sessions.filter(s => {
      if (s.class_group_id !== cg.id || s.course_id !== co.id) return false;
      const slot = timeSlots.find(t => t.id === s.time_slot_id);
      if (!slot || slot.day_of_week !== dayOfWeek) return false;
      return startTimes.includes(slot.start_time);
    });
  }

  // Location mapping from timetable image
  // [className, courseName, dayOfWeek, [startTimes], location]
  const locationAssignments = [
    // ── 수요일 (Wednesday = 3) ──
    ['중2', '수학(수진)', 3, ['09:30:00'], '304호'],
    ['중2', '수학(수진)', 3, ['10:00:00', '10:30:00'], '믿음'],
    ['중3', '수학(준형)', 3, ['11:00:00', '11:30:00'], '믿음'],
    ['중3', '수학(준형)', 3, ['14:30:00', '15:00:00'], '믿음'],
    ['중3', '영문법', 3, ['09:30:00', '10:00:00', '10:30:00'], '소망'],
    ['중2', '영문법', 3, ['11:00:00', '11:30:00'], '소망'],
    ['4학년', '한자', 3, ['11:00:00', '11:30:00'], '사랑'],
    ['5학년', '한자', 3, ['11:00:00', '11:30:00'], '사랑'],
    ['3학년', '소리영어(배우리)', 3, ['09:00:00', '09:30:00'], '코너방'],
    ['1학년', '소리영어(배우리)', 3, ['10:00:00', '10:30:00'], '코너방'],
    ['2학년', '소리영어(배우리)', 3, ['11:00:00', '11:30:00'], '코너방'],
    ['4학년', '독서', 3, ['09:30:00', '10:00:00', '10:30:00'], '자모실'],
    ['2학년', '함께 책 읽기', 3, ['10:00:00', '10:30:00'], '303호'],
    ['3학년', '함께 책 읽기', 3, ['10:00:00', '10:30:00'], '자모실'],
    ['중3', '독서(승화)', 3, ['13:00:00', '13:30:00'], '믿음'],

    // ── 목요일 (Thursday = 4) ──
    ['중2', '성경적 세계관', 4, ['09:00:00', '09:30:00'], '304호'],
    ['중3', '성경적 세계관', 4, ['09:00:00', '09:30:00'], '304호'],
    ['중2', '독서', 4, ['10:30:00', '11:00:00', '11:30:00'], '믿음'],
    ['5학년', '독서', 4, ['09:30:00', '10:00:00'], '소망'],
    ['3학년', '한자', 4, ['09:00:00', '09:30:00'], '사랑'],
    ['4학년', '소리영어(채리아)', 4, ['10:00:00', '10:30:00'], '사랑'],
    ['5학년', '소리영어(채리아)', 4, ['11:00:00', '11:30:00'], '사랑'],
    ['1학년', '한자', 4, ['10:00:00', '10:30:00'], '코너방'],
    ['중3', '과학(진아)', 4, ['10:30:00', '11:00:00', '11:30:00'], '아이작'],
    ['2학년', '한자', 4, ['11:00:00', '11:30:00'], '예서집'],
    ['3학년', '자기주도학습', 4, ['10:00:00', '10:30:00'], '자모실'],
    ['2학년', '자기주도학습', 4, ['10:00:00', '10:30:00'], '드림방'],
    ['3학년', '워십댄스', 4, ['15:00:00', '15:30:00'], '스타홀'],
  ];

  let updated = 0;
  for (const [className, courseName, day, startTimes, location] of locationAssignments) {
    const matched = findSessions(className, courseName, day, startTimes);
    if (matched.length === 0) {
      console.log(`  No match: ${className} ${courseName} day=${day} ${startTimes[0]}`);
      continue;
    }
    for (const session of matched) {
      await patch('class_sessions', `id=eq.${session.id}`, { location });
      updated++;
    }
    console.log(`  ${className} ${courseName} day=${day} → ${location} (${matched.length} slots)`);
  }
  console.log(`  Total updated: ${updated} sessions`);

  console.log('\n✓ All updates complete!');
}

main().catch(e => { console.error(e); process.exit(1); });
