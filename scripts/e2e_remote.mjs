#!/usr/bin/env node

const SUPABASE_URL = process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!ANON_KEY || !SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const now = Date.now();
const runTag = `e2e_${now}`;
const email = `${runTag}@nest.local`;
const password = `Nest!${Math.random().toString(36).slice(2)}A1`;
const invitedEmail = `parent_${runTag}@nest.local`;
const invitedPassword = `Nest!${Math.random().toString(36).slice(2)}B1`;

const report = {
  runTag,
  startedAt: new Date().toISOString(),
  steps: [],
  ids: {}
};

main()
  .then(async () => {
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
  const adminUser = await step("create_admin_user", async () => {
    const res = await api("POST", `/auth/v1/admin/users`, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`
      },
      body: {
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: `Nest E2E ${runTag}` }
      }
    });

    const createdUserId = res.user?.id || res.id;
    if (!createdUserId) {
      throw new Error(`admin user id missing in response: ${JSON.stringify(res)}`);
    }

    report.ids.userId = createdUserId;
    return { email, user_id: createdUserId };
  });

  const auth = await step("login_with_password", async () => {
    const res = await api("POST", `/auth/v1/token?grant_type=password`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${ANON_KEY}`
      },
      body: {
        email,
        password
      }
    });

    report.ids.accessTokenPrefix = String(res.access_token || "").slice(0, 12);
    return res;
  });

  const accessToken = auth.access_token;
  const userId = adminUser.user_id;

  const homeschool = await step("create_homeschool", async () => {
    const rows = await restInsert(accessToken, "homeschools", [
      {
        name: `Nest E2E School ${runTag}`,
        owner_user_id: userId,
        timezone: "Asia/Seoul"
      }
    ]);

    report.ids.homeschoolId = rows[0].id;
    return rows[0];
  });

  await step("owner_membership_created", async () => {
    const rows = await restSelect(
      accessToken,
      `homeschool_memberships?homeschool_id=eq.${homeschool.id}&user_id=eq.${userId}&select=id,role,status`
    );

    if (!rows.length) throw new Error("owner membership not created");
    if (rows[0].role !== "HOMESCHOOL_ADMIN") {
      throw new Error(`unexpected role: ${rows[0].role}`);
    }

    return rows[0];
  });

  const term = await step("create_term", async () => {
    const rows = await restInsert(accessToken, "terms", [
      {
        homeschool_id: homeschool.id,
        name: `2026 E2E Term ${runTag}`,
        start_date: "2026-03-02",
        end_date: "2026-07-31",
        status: "DRAFT"
      }
    ]);
    report.ids.termId = rows[0].id;
    return rows[0];
  });

  const classGroup = await step("create_class_group", async () => {
    const rows = await restInsert(accessToken, "class_groups", [
      {
        term_id: term.id,
        name: `E2E Class ${runTag}`,
        capacity: 12
      }
    ]);

    report.ids.classGroupId = rows[0].id;
    return rows[0];
  });

  const family = await step("create_family", async () => {
    const rows = await restInsert(accessToken, "families", [
      {
        homeschool_id: homeschool.id,
        family_name: `E2E Family ${runTag}`,
        note: "integration test family"
      }
    ]);
    report.ids.familyId = rows[0].id;
    return rows[0];
  });

  const child = await step("create_child", async () => {
    const row = await api("POST", `/rest/v1/rpc/create_child_admin`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`
      },
      body: {
        p_family_id: family.id,
        p_name: `E2E Child ${runTag}`,
        p_birth_date: "2018-03-01",
        p_profile_note: "integration child"
      }
    });
    report.ids.childId = row.id;
    return row;
  });

  await step("create_class_enrollment", async () => {
    const rows = await restInsert(accessToken, "class_enrollments", [
      {
        class_group_id: classGroup.id,
        child_id: child.id
      }
    ]);
    report.ids.classEnrollmentId = rows[0].id;
    return rows[0];
  });

  await step("create_courses", async () => {
    const rows = await restInsert(accessToken, "courses", [
      {
        homeschool_id: homeschool.id,
        name: `국어-${runTag}`,
        default_duration_min: 50
      },
      {
        homeschool_id: homeschool.id,
        name: `수학-${runTag}`,
        default_duration_min: 50
      },
      {
        homeschool_id: homeschool.id,
        name: `자연탐구-${runTag}`,
        default_duration_min: 50
      },
      {
        homeschool_id: homeschool.id,
        name: `미술-${runTag}`,
        default_duration_min: 50
      }
    ]);

    report.ids.courseIds = rows.map((r) => r.id);
    return { count: rows.length };
  });

  const slots = await step("create_time_slots", async () => {
    const rows = await restInsert(accessToken, "time_slots", [
      { term_id: term.id, day_of_week: 2, start_time: "09:30", end_time: "10:20" },
      { term_id: term.id, day_of_week: 2, start_time: "10:30", end_time: "11:20" },
      { term_id: term.id, day_of_week: 4, start_time: "09:30", end_time: "10:20" },
      { term_id: term.id, day_of_week: 4, start_time: "10:30", end_time: "11:20" }
    ]);

    report.ids.slotIds = rows.map((r) => r.id);
    return rows;
  });

  const generated = await step("invoke_timetable_assistant", async () => {
    const res = await api("POST", `/functions/v1/timetable-assistant-generate`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`
      },
      body: {
        term_id: term.id,
        class_group_id: classGroup.id,
        prompt: "화/목 오전 국어 수학 중심으로 편성해줘"
      }
    });

    if (!Array.isArray(res.sessions) || res.sessions.length === 0) {
      throw new Error("assistant returned no sessions");
    }

    return { session_count: res.sessions.length, source: res.source };
  });

  await step("create_proposal_and_rows", async () => {
    const proposalRows = await restInsert(accessToken, "timetable_proposals", [
      {
        term_id: term.id,
        prompt: "화/목 오전 국어 수학 중심으로 편성해줘",
        status: "GENERATED",
        generated_by_user_id: userId,
        summary_json: { source: "e2e" }
      }
    ]);

    const proposalId = proposalRows[0].id;
    report.ids.proposalId = proposalId;

    const courseIds = report.ids.courseIds;
    const slotIds = report.ids.slotIds;

    const proposalSessions = slotIds.slice(0, 2).map((slotId, i) => ({
      proposal_id: proposalId,
      class_group_id: classGroup.id,
      course_id: courseIds[i % courseIds.length],
      time_slot_id: slotId,
      teacher_assistant_ids_json: [],
      hard_conflicts_json: [],
      soft_warnings_json: []
    }));

    await restInsert(accessToken, "timetable_proposal_sessions", proposalSessions);
    return { proposal_id: proposalId, proposal_session_count: proposalSessions.length };
  });

  const sessions = await step("apply_proposal_into_class_sessions", async () => {
    const courseIds = report.ids.courseIds;
    const slotIds = report.ids.slotIds;

    const rows = await restInsert(accessToken, "class_sessions", [
      {
        class_group_id: classGroup.id,
        course_id: courseIds[0],
        time_slot_id: slotIds[0],
        title: "국어 수업",
        source_type: "AI_PROMPT",
        status: "PLANNED",
        created_by_user_id: userId
      },
      {
        class_group_id: classGroup.id,
        course_id: courseIds[1],
        time_slot_id: slotIds[1],
        title: "수학 수업",
        source_type: "AI_PROMPT",
        status: "PLANNED",
        created_by_user_id: userId
      }
    ]);

    report.ids.sessionIds = rows.map((r) => r.id);
    return rows;
  });

  await step("drag_drop_move_session", async () => {
    const movingSessionId = sessions[0].id;
    const targetSlotId = report.ids.slotIds[2];

    const updated = await restPatch(
      accessToken,
      `class_sessions?id=eq.${movingSessionId}`,
      {
        time_slot_id: targetSlotId,
        source_type: "MANUAL"
      }
    );

    if (!updated.length || updated[0].time_slot_id !== targetSlotId) {
      throw new Error("session move failed");
    }

    return {
      session_id: movingSessionId,
      new_slot_id: targetSlotId
    };
  });

  const teacher = await step("create_teacher_profile", async () => {
    const rows = await restInsert(accessToken, "teacher_profiles", [
      {
        homeschool_id: homeschool.id,
        user_id: userId,
        display_name: `E2E Teacher ${runTag}`,
        teacher_type: "GUEST_TEACHER"
      }
    ]);

    report.ids.teacherProfileId = rows[0].id;
    return rows[0];
  });

  await step("create_teaching_plan", async () => {
    const rows = await restInsert(accessToken, "teaching_plans", [
      {
        class_session_id: sessions[0].id,
        teacher_profile_id: teacher.id,
        objectives: "국어 읽기 기초",
        materials: "교재, 읽기 카드",
        activities: "읽기 및 발표"
      }
    ]);
    report.ids.teachingPlanId = rows[0].id;
    return rows[0];
  });

  await step("create_student_activity_log", async () => {
    const rows = await restInsert(accessToken, "student_activity_logs", [
      {
        child_id: child.id,
        class_session_id: sessions[0].id,
        recorded_by_teacher_id: teacher.id,
        activity_type: "OBSERVATION",
        content: "발표 참여도가 높음"
      }
    ]);
    report.ids.activityLogId = rows[0].id;
    return rows[0];
  });

  await step("create_announcement", async () => {
    const rows = await restInsert(accessToken, "announcements", [
      {
        homeschool_id: homeschool.id,
        class_group_id: classGroup.id,
        author_user_id: userId,
        title: `E2E Notice ${runTag}`,
        body: "이번 주 수업 준비물을 확인하세요.",
        pinned: true
      }
    ]);
    report.ids.announcementId = rows[0].id;
    return rows[0];
  });

  await step("create_audit_log", async () => {
    const rows = await restInsert(accessToken, "audit_logs", [
      {
        homeschool_id: homeschool.id,
        actor_user_id: userId,
        action_type: "E2E_ACTION",
        resource_type: "e2e",
        resource_id: runTag,
        after_json: { ok: true }
      }
    ]);
    report.ids.auditLogId = rows[0].id;
    return rows[0];
  });

  const invitedUser = await step("create_invited_parent_user", async () => {
    const res = await api("POST", `/auth/v1/admin/users`, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`
      },
      body: {
        email: invitedEmail,
        password: invitedPassword,
        email_confirm: true,
        user_metadata: { full_name: `Nest Parent ${runTag}` }
      }
    });

    const createdUserId = res.user?.id || res.id;
    if (!createdUserId) {
      throw new Error(`invited user id missing in response: ${JSON.stringify(res)}`);
    }

    report.ids.invitedUserId = createdUserId;
    return { user_id: createdUserId };
  });

  const invited = await step("create_invite_row", async () => {
    const rows = await restInsert(accessToken, "homeschool_invites", [
      {
        homeschool_id: homeschool.id,
        invite_email: invitedEmail,
        role: "PARENT",
        invited_by_user_id: userId,
        status: "PENDING"
      }
    ]);

    report.ids.inviteId = rows[0].id;
    report.ids.inviteToken = rows[0].invite_token;
    return rows[0];
  });

  const invitedAuth = await step("login_invited_parent", async () => {
    const res = await api("POST", `/auth/v1/token?grant_type=password`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${ANON_KEY}`
      },
      body: {
        email: invitedEmail,
        password: invitedPassword
      }
    });

    if (!res.access_token) {
      throw new Error("invited parent access token missing");
    }
    return res;
  });

  await step("accept_homeschool_invite_rpc", async () => {
    const accepted = await api("POST", `/rest/v1/rpc/accept_homeschool_invite`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${invitedAuth.access_token}`
      },
      body: {
        p_invite_token: invited.invite_token
      }
    });

    if (!accepted) {
      throw new Error("invite accept rpc returned empty result");
    }
    return accepted;
  });

  await step("verify_invited_membership_created", async () => {
    const rows = await restSelect(
      invitedAuth.access_token,
      `homeschool_memberships?homeschool_id=eq.${homeschool.id}&user_id=eq.${invitedUser.user_id}&role=eq.PARENT&select=id,role,status`
    );

    if (!rows.length) {
      throw new Error("invited parent membership was not created");
    }
    return rows[0];
  });

  await step("assign_teacher_success", async () => {
    const rows = await restInsert(accessToken, "session_teacher_assignments", [
      {
        class_session_id: sessions[0].id,
        teacher_profile_id: teacher.id,
        assignment_role: "MAIN"
      }
    ]);

    return rows[0];
  });

  await step("teacher_slot_conflict_blocked", async () => {
    const class2 = (
      await restInsert(accessToken, "class_groups", [
        {
          term_id: term.id,
          name: `E2E Class B ${runTag}`,
          capacity: 12
        }
      ])
    )[0];

    const conflictSession = (
      await restInsert(accessToken, "class_sessions", [
        {
          class_group_id: class2.id,
          course_id: report.ids.courseIds[2],
          time_slot_id: report.ids.slotIds[2],
          title: "충돌 테스트 수업",
          source_type: "MANUAL",
          status: "PLANNED",
          created_by_user_id: userId
        }
      ])
    )[0];

    const res = await api("POST", `/rest/v1/session_teacher_assignments`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
        Prefer: "return=representation"
      },
      body: {
        class_session_id: conflictSession.id,
        teacher_profile_id: teacher.id,
        assignment_role: "MAIN"
      },
      allowError: true
    });

    if (res.ok) {
      throw new Error("teacher slot conflict was not blocked");
    }

    return {
      blocked: true,
      status: res.status,
      message: res.body?.message || res.body?.error || "unknown"
    };
  });

  const oauthStart = await step("invoke_drive_connect_start", async () => {
    const res = await api("POST", `/functions/v1/google-drive-connect-start`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`
      },
      body: {
        homeschool_id: homeschool.id
      }
    });

    if (!res.auth_url || typeof res.auth_url !== "string") {
      throw new Error("missing auth_url");
    }

    if (!res.auth_url.includes("accounts.google.com")) {
      throw new Error("unexpected auth_url domain");
    }

    if (!res.auth_url.includes(encodeURIComponent("http://localhost:8080/oauth/google/callback.html"))) {
      throw new Error("redirect_uri not set to localhost callback");
    }

    return {
      auth_url_prefix: res.auth_url.slice(0, 140)
    };
  });

  await step("invoke_drive_connect_complete_invalid_code", async () => {
    const res = await api("POST", `/functions/v1/google-drive-connect-complete`, {
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`
      },
      body: {
        homeschool_id: homeschool.id,
        code: "invalid_code_for_e2e",
        root_folder_id: "root",
        folder_policy: "TERM_CLASS_DATE"
      },
      allowError: true
    });

    if (res.ok) {
      throw new Error("expected oauth complete to fail with invalid code");
    }

    return {
      expected_failure: true,
      status: res.status,
      error: res.body?.error || "unknown"
    };
  });

  await step("verify_callback_page_exists", async () => {
    const fs = await import("node:fs/promises");
    const path = "/Users/euiseokkim/Workspace/lionandthelab/beloved/frontend/web/oauth/google/callback.html";
    await fs.access(path);
    return { path };
  });

  report.summary = {
    success: true,
    generated_sessions: generated.session_count,
    oauth_url_ready: Boolean(oauthStart.auth_url_prefix),
    invite_flow: true
  };
}

async function step(name, fn) {
  const started = Date.now();
  try {
    const result = await fn();
    report.steps.push({
      name,
      ok: true,
      took_ms: Date.now() - started,
      result: compact(result)
    });
    return result;
  } catch (err) {
    report.steps.push({
      name,
      ok: false,
      took_ms: Date.now() - started,
      error: err instanceof Error ? err.message : String(err)
    });
    throw err;
  }
}

function compact(value) {
  try {
    const text = JSON.stringify(value);
    if (text.length <= 800) return value;
    return { note: "result truncated", preview: text.slice(0, 800) };
  } catch (_) {
    return value;
  }
}

async function restInsert(accessToken, table, rows) {
  return await api(`POST`, `/rest/v1/${table}`, {
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      Prefer: "return=representation"
    },
    body: rows
  });
}

async function restPatch(accessToken, path, patchBody) {
  return await api(`PATCH`, `/rest/v1/${path}`, {
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      Prefer: "return=representation"
    },
    body: patchBody
  });
}

async function restSelect(accessToken, queryPath) {
  return await api(`GET`, `/rest/v1/${queryPath}`, {
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${accessToken}`
    }
  });
}

async function api(method, path, { headers = {}, body, allowError = false } = {}) {
  const url = `${SUPABASE_URL}${path}`;
  const res = await fetch(url, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...headers
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });

  let parsed;
  const text = await res.text();
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = { raw: text };
  }

  if (!res.ok && !allowError) {
    throw new Error(`${method} ${path} failed (${res.status}): ${JSON.stringify(parsed)}`);
  }

  if (allowError) {
    return {
      ok: res.ok,
      status: res.status,
      body: parsed
    };
  }

  return parsed;
}
