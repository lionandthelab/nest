#!/usr/bin/env node
// QA 역할별 계정 + 작은 학기/시간표. 비밀번호는 저장소에 쓰지 않고 stdout과 /tmp 에만 남긴다.

const SUPABASE_URL = process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const PASSWORD = process.env.TEST_ACCOUNT_PASSWORD || `NestQa!${new Date().getFullYear()}#cal`;
const SCHOOL_NAME = process.env.QA_HOMESCHOOL_NAME || "Nest QA 일정학교";

const ACCOUNTS = [
  { email: "qa-admin@lionandthelab.com", name: "QA 관리자", role: "HOMESCHOOL_ADMIN" },
  { email: "qa-parent@lionandthelab.com", name: "QA 학부모", role: "PARENT" },
  { email: "qa-teacher@lionandthelab.com", name: "QA 교사", role: "TEACHER" },
  { email: "qa-student@lionandthelab.com", name: "QA 학생", role: "STUDENT" },
];

if (!SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const report = { school: SCHOOL_NAME, users: {} };

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

async function main() {
  const users = {};
  for (const account of ACCOUNTS) {
    users[account.role] = await ensureUser(account);
  }

  const school = await ensureSchool(users.HOMESCHOOL_ADMIN.id);
  for (const account of ACCOUNTS) {
    await ensureMembership(school.id, users[account.role].id, account.role);
  }

  const term = await ensureTerm(school.id);
  const slots = await ensureSlots(term.id);
  const course = await ensureCourse(school.id);
  const klass = await ensureClass(term.id);
  await ensureSessions(klass.id, course.id, slots);
  const family = await ensureFamily(school.id);
  const child = await ensureChild(school.id, family.id);
  await ensureGuardian(family.id, users.PARENT.id);
  await ensureEnrollment(klass.id, child.id);
  await linkStudent(child.id, users.STUDENT.id);
  await ensureTeacherProfile(school.id, users.TEACHER.id);
  await ensureAcademicEvent(school.id, term.id, users.HOMESCHOOL_ADMIN.id);

  report.homeschoolId = school.id;
  report.termId = term.id;
  report.childId = child.id;
  report.password = PASSWORD;
  report.logins = ACCOUNTS.map((row) => ({
    role: row.role,
    email: row.email,
    password: PASSWORD,
  }));

  const text = [
    "Nest QA 테스트 계정",
    `홈스쿨: ${SCHOOL_NAME}`,
    ...report.logins.map((row) => `${row.role}\t${row.email}\t${row.password}`),
    "",
  ].join("\n");

  await DenoWriteForbidden(text);
  console.log(JSON.stringify(report, null, 2));
}

async function DenoWriteForbidden(text) {
  const { writeFileSync } = await import("node:fs");
  writeFileSync("/tmp/nest-qa-accounts.txt", text);
}

async function ensureUser(account) {
  const existing = await findUserByEmail(account.email);
  if (existing) {
    await api("PUT", `/auth/v1/admin/users/${existing.id}`, {
      headers: adminHeaders(),
      body: {
        password: PASSWORD,
        email_confirm: true,
        user_metadata: { full_name: account.name },
      },
    });
    report.users[account.email] = { id: existing.id, created: false };
    return existing;
  }
  const created = await api("POST", "/auth/v1/admin/users", {
    headers: adminHeaders(),
    body: {
      email: account.email,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: account.name },
    },
  });
  const user = created.user || created;
  report.users[account.email] = { id: user.id, created: true };
  return user;
}

async function ensureSchool(ownerId) {
  const rows = await restGet("homeschools", { name: `eq.${SCHOOL_NAME}`, select: "id,name" });
  if (rows[0]) return rows[0];
  const created = await restPost("homeschools", {
    name: SCHOOL_NAME,
    owner_user_id: ownerId,
    timezone: "Asia/Seoul",
  });
  return created[0];
}

async function ensureMembership(homeschoolId, userId, role) {
  const rows = await restGet("homeschool_memberships", {
    homeschool_id: `eq.${homeschoolId}`,
    user_id: `eq.${userId}`,
    role: `eq.${role}`,
    select: "id",
  });
  if (rows[0]) return rows[0];
  return restPost("homeschool_memberships", {
    homeschool_id: homeschoolId,
    user_id: userId,
    role,
    status: "ACTIVE",
  });
}

async function ensureTerm(homeschoolId) {
  const rows = await restGet("terms", {
    homeschool_id: `eq.${homeschoolId}`,
    name: "eq.QA 가을학기",
    select: "id,name",
  });
  if (rows[0]) return rows[0];
  const today = new Date();
  const start = new Date(today.getFullYear(), today.getMonth() - 1, 1);
  const end = new Date(today.getFullYear(), today.getMonth() + 2, 0);
  const created = await restPost("terms", {
    homeschool_id: homeschoolId,
    name: "QA 가을학기",
    status: "ACTIVE",
    start_date: isoDate(start),
    end_date: isoDate(end),
  });
  return created[0];
}

async function ensureSlots(termId) {
  const existing = await restGet("time_slots", { term_id: `eq.${termId}`, select: "id,day_of_week,start_time,end_time" });
  if (existing.length > 0) return existing;
  const rows = [];
  for (const day of [1, 2, 3, 4, 5]) {
    for (const [start, end] of [
      ["09:00:00", "09:50:00"],
      ["10:00:00", "10:50:00"],
      ["11:00:00", "11:50:00"],
    ]) {
      rows.push({
        term_id: termId,
        day_of_week: day,
        start_time: start,
        end_time: end,
      });
    }
  }
  return restPost("time_slots", rows);
}

async function ensureCourse(homeschoolId) {
  const rows = await restGet("courses", {
    homeschool_id: `eq.${homeschoolId}`,
    name: "eq.QA 국어",
    select: "id,name",
  });
  if (rows[0]) return rows[0];
  const created = await restPost("courses", {
    homeschool_id: homeschoolId,
    name: "QA 국어",
    default_duration_min: 50,
  });
  return created[0];
}

async function ensureClass(termId) {
  const rows = await restGet("class_groups", {
    term_id: `eq.${termId}`,
    name: "eq.QA 새싹반",
    select: "id,name",
  });
  if (rows[0]) return rows[0];
  const created = await restPost("class_groups", {
    term_id: termId,
    name: "QA 새싹반",
    capacity: 12,
  });
  return created[0];
}

async function ensureSessions(classGroupId, courseId, slots) {
  const existing = await restGet("class_sessions", {
    class_group_id: `eq.${classGroupId}`,
    select: "id",
  });
  if (existing.length > 0) return existing;
  const mondaySlots = slots.filter((slot) => slot.day_of_week === 1);
  const payload = mondaySlots.map((slot) => ({
    class_group_id: classGroupId,
    course_id: courseId,
    time_slot_id: slot.id,
    title: "",
    source_type: "MANUAL",
    status: "CONFIRMED",
  }));
  return restPost("class_sessions", payload);
}

async function ensureFamily(homeschoolId) {
  const rows = await restGet("families", {
    homeschool_id: `eq.${homeschoolId}`,
    family_name: "eq.QA 가정",
    select: "id,family_name",
  });
  if (rows[0]) return rows[0];
  const created = await restPost("families", {
    homeschool_id: homeschoolId,
    family_name: "QA 가정",
  });
  return created[0];
}

async function ensureChild(homeschoolId, familyId) {
  const rows = await restGet("children", {
    family_id: `eq.${familyId}`,
    name: "eq.QA 아이",
    select: "id,name,user_id",
  });
  if (rows[0]) return rows[0];
  const created = await restPost("children", {
    family_id: familyId,
    name: "QA 아이",
    birth_date: "2016-03-01",
    status: "ACTIVE",
  });
  return created[0];
}

async function ensureGuardian(familyId, userId) {
  const rows = await restGet("family_guardians", {
    family_id: `eq.${familyId}`,
    user_id: `eq.${userId}`,
    select: "id",
  });
  if (rows[0]) return rows[0];
  return restPost("family_guardians", {
    family_id: familyId,
    user_id: userId,
    guardian_type: "GUARDIAN",
  });
}

async function ensureEnrollment(classGroupId, childId) {
  const rows = await restGet("class_enrollments", {
    class_group_id: `eq.${classGroupId}`,
    child_id: `eq.${childId}`,
    select: "id",
  });
  if (rows[0]) return rows[0];
  return restPost("class_enrollments", { class_group_id: classGroupId, child_id: childId });
}

async function linkStudent(childId, userId) {
  await api("PATCH", `/rest/v1/children?id=eq.${childId}`, {
    headers: restHeaders(),
    body: { user_id: userId },
  });
}

async function ensureTeacherProfile(homeschoolId, userId) {
  const rows = await restGet("teacher_profiles", {
    homeschool_id: `eq.${homeschoolId}`,
    user_id: `eq.${userId}`,
    select: "id",
  });
  if (rows[0]) return rows[0];
  return restPost("teacher_profiles", {
    homeschool_id: homeschoolId,
    user_id: userId,
    display_name: "QA 교사",
    teacher_type: "PARENT_TEACHER",
  });
}

async function ensureAcademicEvent(homeschoolId, termId, userId) {
  const rows = await restGet("academic_events", {
    homeschool_id: `eq.${homeschoolId}`,
    title: "eq.QA 현장학습",
    select: "id",
  });
  if (rows[0]) return rows[0];
  const day = isoDate(new Date(Date.now() + 3 * 86400000));
  const payload = {
    homeschool_id: homeschoolId,
    term_id: termId,
    title: "QA 현장학습",
    description: "운동화와 도시락",
    event_date: day,
    created_by_user_id: userId,
    kind: "FIELD_TRIP",
    publish_announcement: true,
    show_on_timetable: true,
  };
  try {
    return await restPost("academic_events", payload);
  } catch {
    delete payload.kind;
    delete payload.publish_announcement;
    delete payload.show_on_timetable;
    return restPost("academic_events", payload);
  }
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function findUserByEmail(email) {
  let page = 1;
  while (page <= 20) {
    const result = await api("GET", `/auth/v1/admin/users?page=${page}&per_page=200`, {
      headers: adminHeaders(),
    });
    const list = result.users || result;
    if (!Array.isArray(list) || list.length === 0) return null;
    const hit = list.find((row) => row.email === email);
    if (hit) return hit;
    page += 1;
  }
  return null;
}

async function restGet(table, query) {
  const params = new URLSearchParams(query);
  const rows = await api("GET", `/rest/v1/${table}?${params}`, { headers: restHeaders() });
  return Array.isArray(rows) ? rows : [];
}

async function restPost(table, body) {
  const rows = await api("POST", `/rest/v1/${table}`, {
    headers: { ...restHeaders(), Prefer: "return=representation" },
    body,
  });
  return Array.isArray(rows) ? rows : [rows];
}

function adminHeaders() {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };
}

function restHeaders() {
  return {
    ...adminHeaders(),
    Prefer: "return=representation",
  };
}

async function api(method, path, { headers, body } = {}) {
  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${method} ${path} ${response.status} ${text}`);
  }
  return text ? JSON.parse(text) : null;
}
