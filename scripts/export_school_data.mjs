// Export JOY School homeschool data to markdown
// Usage: node --env-file=.env scripts/export_school_data.mjs

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://avursvhmilcsssabqtkx.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SERVICE_ROLE_KEY) { console.error('Missing SUPABASE_SERVICE_ROLE_KEY'); process.exit(1); }

const headers = {
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  Accept: 'application/json',
};

async function query(table, params = '') {
  const url = `${SUPABASE_URL}/rest/v1/${table}?${params}`;
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`${table}: ${res.status} ${await res.text()}`);
  return res.json();
}

async function main() {
  // Find JOY School
  const schools = await query('homeschools', 'select=*');
  const joy = schools.find(s => s.name.includes('JOY'));
  if (!joy) { console.error('JOY School not found'); process.exit(1); }
  const hid = joy.id;

  // Parallel queries
  const [memberships, families, children, guardians, teacherProfiles, courses, terms] = await Promise.all([
    query('homeschool_memberships', `homeschool_id=eq.${hid}&select=*`),
    query('families', `homeschool_id=eq.${hid}&select=*`),
    query('children', `select=*,families!inner(homeschool_id)&families.homeschool_id=eq.${hid}`),
    query('family_guardians', `select=*,families!inner(homeschool_id)&families.homeschool_id=eq.${hid}`),
    query('teacher_profiles', `homeschool_id=eq.${hid}&select=*`),
    query('courses', `homeschool_id=eq.${hid}&select=*`),
    query('terms', `homeschool_id=eq.${hid}&select=*`),
  ]);

  // Dependent queries (via term_id)
  const termIds = terms.map(t => t.id);
  const termFilter = termIds.length ? `term_id=in.(${termIds.join(',')})` : 'term_id=eq.none';
  const [classGroups, timeSlots, classrooms] = await Promise.all([
    query('class_groups', `${termFilter}&select=*`),
    query('time_slots', `${termFilter}&select=*`),
    query('classrooms', `${termFilter}&select=*`),
  ]);

  const groupIds = classGroups.map(g => g.id);
  const groupFilter = groupIds.length ? `class_group_id=in.(${groupIds.join(',')})` : 'class_group_id=eq.none';
  const classSessions = groupIds.length ? await query('class_sessions', `${groupFilter}&select=*`) : [];

  // Fetch auth users for membership/guardian info
  const userIds = new Set([
    ...memberships.map(m => m.user_id),
    ...guardians.map(g => g.user_id),
  ]);
  const users = {};
  for (const uid of userIds) {
    try {
      const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${uid}`, { headers });
      if (res.ok) { const u = await res.json(); users[uid] = u; }
    } catch (_) {}
  }

  const userName = (uid) => {
    const u = users[uid];
    if (!u) return uid;
    const name = u.user_metadata?.full_name || u.email || uid;
    return `${name} (${u.email || ''})`;
  };

  // Build markdown
  const lines = [];
  const add = (...l) => lines.push(...l);

  add(`# JOY School 현황`, '');
  add(`> 추출일: ${new Date().toISOString().slice(0, 10)}`, '');
  add(`- 홈스쿨 ID: \`${hid}\``);
  add(`- 이름: ${joy.name}`);
  add(`- 생성일: ${joy.created_at?.slice(0, 10) || ''}`, '');

  // Terms
  add(`## 학기 (Terms)`, '');
  if (terms.length === 0) add('없음', '');
  else {
    add('| 이름 | 시작일 | 종료일 | 상태 |', '|---|---|---|---|');
    for (const t of terms) add(`| ${t.name} | ${t.start_date || ''} | ${t.end_date || ''} | ${t.status || ''} |`);
    add('');
  }

  // Memberships
  add(`## 멤버십`, '');
  add('| 사용자 | 역할 | 상태 | 가입일 |', '|---|---|---|---|');
  for (const m of memberships) {
    add(`| ${userName(m.user_id)} | ${m.role} | ${m.status} | ${m.created_at?.slice(0, 10) || ''} |`);
  }
  add('');

  // Families
  add(`## 가정 (Families)`, '');
  for (const f of families) {
    add(`### ${f.family_name}`, '');
    add(`- ID: \`${f.id}\``);
    if (f.note) add(`- 메모: ${f.note}`);

    const fGuardians = guardians.filter(g => g.family_id === f.id);
    if (fGuardians.length) {
      add('', '**보호자:**', '');
      for (const g of fGuardians) {
        add(`- ${userName(g.user_id)} — ${g.guardian_type}`);
      }
    }

    const fChildren = children.filter(c => c.family_id === f.id);
    if (fChildren.length) {
      add('', '**아이:**', '');
      add('| 이름 | 생년월일 | 상태 |', '|---|---|---|');
      for (const c of fChildren) {
        add(`| ${c.name} | ${c.birth_date || '미등록'} | ${c.status} |`);
      }
    }
    add('');
  }

  // Teacher Profiles
  add(`## 교사 (Teacher Profiles)`, '');
  if (teacherProfiles.length === 0) add('없음', '');
  else {
    add('| 이름 | 사용자 | 전문분야 |', '|---|---|---|');
    for (const t of teacherProfiles) {
      add(`| ${t.display_name || ''} | ${userName(t.user_id)} | ${t.specialization || ''} |`);
    }
    add('');
  }

  // Courses
  add(`## 과목 (Courses)`, '');
  if (courses.length === 0) add('없음', '');
  else {
    add('| 이름 | 설명 | 색상 |', '|---|---|---|');
    for (const c of courses) {
      add(`| ${c.name} | ${c.description || ''} | ${c.color_hex || ''} |`);
    }
    add('');
  }

  // Classrooms
  add(`## 교실 (Classrooms)`, '');
  if (classrooms.length === 0) add('없음', '');
  else {
    add('| 이름 | 수용인원 |', '|---|---|');
    for (const c of classrooms) {
      add(`| ${c.name} | ${c.capacity || ''} |`);
    }
    add('');
  }

  // Class Groups
  add(`## 반 (Class Groups)`, '');
  if (classGroups.length === 0) add('없음', '');
  else {
    add('| 이름 | 담당교사 | 정원 | 학기 |', '|---|---|---|---|');
    for (const g of classGroups) {
      const teacher = teacherProfiles.find(t => t.id === g.main_teacher_id);
      const term = terms.find(t => t.id === g.term_id);
      add(`| ${g.name} | ${teacher?.display_name || ''} | ${g.capacity} | ${term?.name || ''} |`);
    }
    add('');
  }

  // Class Sessions
  add(`## 수업 시간 (Class Sessions)`, '');
  if (classSessions.length === 0) add('없음', '');
  else {
    const dayNames = { 0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토' };
    add('| 반 | 과목 | 요일 | 시작 | 종료 | 상태 |', '|---|---|---|---|---|---|');
    for (const s of classSessions) {
      const group = classGroups.find(g => g.id === s.class_group_id);
      const course = courses.find(c => c.id === s.course_id);
      const slot = timeSlots.find(t => t.id === s.time_slot_id);
      add(`| ${group?.name || ''} | ${course?.name || ''} | ${slot ? dayNames[slot.day_of_week] || slot.day_of_week : ''} | ${slot?.start_time || ''} | ${slot?.end_time || ''} | ${s.status || ''} |`);
    }
    add('');
  }

  const md = lines.join('\n');
  const fs = await import('fs');
  const outPath = 'joy_school_data.md';
  fs.writeFileSync(outPath, md, 'utf8');
  console.log(`Exported to ${outPath} (${lines.length} lines)`);
}

main().catch(e => { console.error(e); process.exit(1); });
