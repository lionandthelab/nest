#!/usr/bin/env node

const SUPABASE_URL = process.env.SUPABASE_URL || "https://avursvhmilcsssabqtkx.supabase.co";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@nest.local";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "NestAdmin!2026";
const ADMIN_FULL_NAME = process.env.ADMIN_FULL_NAME || "Nest Admin";
const DEFAULT_HOMESCHOOL_NAME =
  process.env.DEFAULT_HOMESCHOOL_NAME || "Nest Default Homeschool";
const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Asia/Seoul";

if (!SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const report = {
  startedAt: new Date().toISOString(),
  supabaseUrl: SUPABASE_URL,
  adminEmail: ADMIN_EMAIL,
  defaultHomeschool: DEFAULT_HOMESCHOOL_NAME,
};

main()
  .then(() => {
    report.finishedAt = new Date().toISOString();
    console.log(JSON.stringify(report, null, 2));
  })
  .catch((error) => {
    report.finishedAt = new Date().toISOString();
    report.failed = error instanceof Error ? error.message : String(error);
    console.error(JSON.stringify(report, null, 2));
    process.exit(1);
  });

async function main() {
  const user = await ensureAdminUser();
  report.userId = user.id;

  const homeschool = await ensureHomeschool(user.id);
  report.homeschoolId = homeschool.id;

  await ensureAdminMembership(homeschool.id, user.id);
  report.membership = "HOMESCHOOL_ADMIN";
}

async function ensureAdminUser() {
  const existing = await findUserByEmail(ADMIN_EMAIL);
  if (existing) {
    report.userCreated = false;
    return existing;
  }

  const created = await api("POST", "/auth/v1/admin/users", {
    headers: adminHeaders(),
    body: {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      email_confirm: true,
      user_metadata: {
        full_name: ADMIN_FULL_NAME,
      },
    },
  });

  const user = created.user || created;
  if (!user?.id) {
    throw new Error("Created user id missing");
  }

  report.userCreated = true;
  return user;
}

async function ensureHomeschool(ownerUserId) {
  const params = new URLSearchParams({
    select: "id,name,owner_user_id,timezone",
    owner_user_id: `eq.${ownerUserId}`,
    name: `eq.${DEFAULT_HOMESCHOOL_NAME}`,
    limit: "1",
  });

  const existingRows = await api("GET", `/rest/v1/homeschools?${params.toString()}`, {
    headers: restHeaders(),
  });

  if (Array.isArray(existingRows) && existingRows.length > 0) {
    report.homeschoolCreated = false;
    return existingRows[0];
  }

  const createdRows = await api("POST", "/rest/v1/homeschools", {
    headers: {
      ...restHeaders(),
      Prefer: "return=representation",
    },
    body: {
      name: DEFAULT_HOMESCHOOL_NAME,
      owner_user_id: ownerUserId,
      timezone: DEFAULT_TIMEZONE,
    },
  });

  const created = Array.isArray(createdRows) ? createdRows[0] : null;
  if (!created?.id) {
    throw new Error("Created homeschool id missing");
  }

  report.homeschoolCreated = true;
  return created;
}

async function ensureAdminMembership(homeschoolId, userId) {
  const params = new URLSearchParams({
    select: "id,role,status",
    homeschool_id: `eq.${homeschoolId}`,
    user_id: `eq.${userId}`,
    role: "eq.HOMESCHOOL_ADMIN",
    limit: "1",
  });

  const rows = await api(
    "GET",
    `/rest/v1/homeschool_memberships?${params.toString()}`,
    {
      headers: restHeaders(),
    }
  );

  if (Array.isArray(rows) && rows.length > 0) {
    report.membershipCreated = false;
    return rows[0];
  }

  const upsert = await api(
    "POST",
    "/rest/v1/homeschool_memberships?on_conflict=homeschool_id,user_id,role",
    {
      headers: {
        ...restHeaders(),
        Prefer: "resolution=merge-duplicates,return=representation",
      },
      body: {
        homeschool_id: homeschoolId,
        user_id: userId,
        role: "HOMESCHOOL_ADMIN",
        status: "ACTIVE",
      },
    }
  );

  report.membershipCreated = true;
  return Array.isArray(upsert) ? upsert[0] : upsert;
}

async function findUserByEmail(email) {
  let page = 1;

  while (true) {
    const query = new URLSearchParams({
      page: String(page),
      per_page: "200",
    });

    const res = await api("GET", `/auth/v1/admin/users?${query.toString()}`, {
      headers: adminHeaders(),
    });

    const users = Array.isArray(res?.users) ? res.users : [];
    const found = users.find(
      (user) => String(user.email || "").toLowerCase() === email.toLowerCase()
    );

    if (found) {
      return found;
    }

    if (users.length < 200) {
      break;
    }

    page += 1;
  }

  return null;
}

function adminHeaders() {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  };
}

function restHeaders() {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };
}

async function api(method, path, { headers = {}, body } = {}) {
  const url = `${SUPABASE_URL}${path}`;

  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let parsed;

  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_error) {
    parsed = { raw: text };
  }

  if (!response.ok) {
    throw new Error(`${method} ${path} failed (${response.status}): ${JSON.stringify(parsed)}`);
  }

  return parsed;
}
