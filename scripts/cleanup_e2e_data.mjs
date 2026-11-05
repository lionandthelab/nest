#!/usr/bin/env node
// E2E 자동화 테스트가 생성한 임시 홈스쿨·Auth 계정을 안전하게 정리하는 스크립트.
//
// 안전 가드레일:
// 1. 오직 자동화 E2E 이메일 패턴(`e2e_*@nest.local`, `parent_e2e_*@nest.local`,
//    `probe_*@nest.local`, `nest-onboard-*@example.com`)만 삭제 대상으로 삼는다.
//    영구 QA 계정(`qa-*@lionandthelab.com`, `admin@nest.local`, `*@joy.app`) 및
//    실제 사용자 계정은 절대 건드리지 않는다.
// 2. 홈스쿨은 `Nest E2E School e2e_*` / `Probe *` 패턴이거나 소유자가 위 E2E 계정인
//    경우만 후보로 삼되, 소속 멤버 중 E2E 계정이 아닌 사용자가 1명이라도 있으면
//    절대 삭제하지 않고 건너뛴다.
// 3. FK RESTRICT 제약을 피하기 위해 항상 홈스쿨(CASCADE) → Auth 사용자 순서로 삭제한다.
//
// 사용법:
//   node scripts/cleanup_e2e_data.mjs --dry-run
//   node scripts/cleanup_e2e_data.mjs --execute
//   node scripts/cleanup_e2e_data.mjs --execute --max-age-minutes=30

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const E2E_EMAIL_PATTERNS = [
  /^(parent_)?e2e_\d+@nest\.local$/i,
  /^probe_\d+@nest\.local$/i,
  /^nest-onboard-\d+@example\.com$/i,
];

const E2E_HOMESCHOOL_PATTERNS = [
  /^Nest E2E School e2e_\d+$/,
  /^Probe \d+$/,
];

export function isE2eEmail(email) {
  if (typeof email !== "string") return false;
  const trimmed = email.trim();
  return E2E_EMAIL_PATTERNS.some((re) => re.test(trimmed));
}

export function isE2eHomeschoolName(name) {
  if (typeof name !== "string") return false;
  const trimmed = name.trim();
  return E2E_HOMESCHOOL_PATTERNS.some((re) => re.test(trimmed));
}

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const env = {};
  for (const line of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match || line.trim().startsWith("#")) continue;
    env[match[1]] = match[2].replace(/^["']|["']$/g, "");
  }
  return env;
}

export async function resolveSupabaseCredentials() {
  const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const merged = {
    ...parseEnvFile(path.join(rootDir, ".env")),
    ...parseEnvFile(path.join(rootDir, "packages", "lion_auth", ".env")),
    ...process.env,
  };
  const projectRef = merged.SUPABASE_PROJECT_REF || "avursvhmilcsssabqtkx";
  const supabaseUrl = merged.SUPABASE_URL || `https://${projectRef}.supabase.co`;
  let serviceRoleKey = merged.SUPABASE_SERVICE_ROLE_KEY || "";

  if (!serviceRoleKey) {
    const accessToken = merged.SUPABASE_ACCESS_TOKEN || merged.SUPABASE_TOKEN || "";
    if (accessToken) {
      const res = await fetch(
        `https://api.supabase.com/v1/projects/${projectRef}/api-keys?reveal=true`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      if (res.ok) {
        const keys = await res.json();
        const found = Array.isArray(keys)
          ? keys.find((k) => k.name === "service_role" || k.type === "secret")
          : null;
        serviceRoleKey = found?.api_key || "";
      }
    }
  }

  return { supabaseUrl, serviceRoleKey };
}

async function fetchAllAuthUsers(supabaseUrl, headers) {
  const all = [];
  let page = 1;
  while (true) {
    const res = await fetch(
      `${supabaseUrl}/auth/v1/admin/users?page=${page}&per_page=1000`,
      { headers }
    );
    if (!res.ok) {
      throw new Error(`Failed to list auth users (${res.status})`);
    }
    const data = await res.json();
    const batch = data?.users || [];
    all.push(...batch);
    if (batch.length < 1000) break;
    page += 1;
  }
  return all;
}

export async function cleanupE2eData({
  supabaseUrl,
  serviceRoleKey,
  maxAgeMs = 0,
  specificHomeschoolIds = [],
  specificUserIds = [],
  dryRun = false,
}) {
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing supabaseUrl or serviceRoleKey for E2E cleanup");
  }

  const headers = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  const now = Date.now();
  const specificHsSet = new Set(specificHomeschoolIds.filter(Boolean));
  const specificUserSet = new Set(specificUserIds.filter(Boolean));

  const [allUsers, allHomeschools, allMemberships] = await Promise.all([
    fetchAllAuthUsers(supabaseUrl, headers),
    fetch(`${supabaseUrl}/rest/v1/homeschools?select=id,name,owner_user_id,created_at`, {
      headers,
    }).then((r) => r.json()),
    fetch(`${supabaseUrl}/rest/v1/homeschool_memberships?select=homeschool_id,user_id,role`, {
      headers,
    }).then((r) => r.json()),
  ]);

  const userById = new Map(allUsers.map((u) => [u.id, u]));
  const allE2eUserIds = new Set(
    allUsers.filter((u) => isE2eEmail(u.email)).map((u) => u.id)
  );

  const isOldEnough = (iso) => {
    if (maxAgeMs <= 0) return true;
    const createdMs = Date.parse(iso || "");
    if (Number.isNaN(createdMs)) return false;
    return now - createdMs >= maxAgeMs;
  };

  // 1) 삭제할 E2E 홈스쿨 선정 (비-E2E 멤버가 단 1명이라도 있으면 절대 삭제하지 않음)
  const targetHomeschools = [];
  const skippedHomeschools = [];

  for (const hs of Array.isArray(allHomeschools) ? allHomeschools : []) {
    const isExplicit = specificHsSet.has(hs.id);
    const isPatternOrOwnedByE2e =
      isE2eHomeschoolName(hs.name) || allE2eUserIds.has(hs.owner_user_id);

    if (!isExplicit && !isPatternOrOwnedByE2e) continue;
    if (!isExplicit && !isOldEnough(hs.created_at)) continue;

    const members = (Array.isArray(allMemberships) ? allMemberships : []).filter(
      (m) => m.homeschool_id === hs.id
    );
    const nonE2eMember = members.find(
      (m) => !allE2eUserIds.has(m.user_id) && !specificUserSet.has(m.user_id)
    );
    if (nonE2eMember) {
      skippedHomeschools.push({
        id: hs.id,
        name: hs.name,
        reason: `non-e2e member present (${userById.get(nonE2eMember.user_id)?.email || nonE2eMember.user_id})`,
      });
      continue;
    }

    targetHomeschools.push(hs);
  }

  // 2) 삭제할 E2E Auth 계정 선정
  const targetHsIdSet = new Set(targetHomeschools.map((h) => h.id));
  const remainingHomeschools = (Array.isArray(allHomeschools) ? allHomeschools : []).filter(
    (h) => !targetHsIdSet.has(h.id)
  );
  const remainingOwnerIds = new Set(remainingHomeschools.map((h) => h.owner_user_id));

  const targetUsers = [];
  for (const u of allUsers) {
    const isExplicit = specificUserSet.has(u.id);
    if (!isExplicit && !isE2eEmail(u.email)) continue;
    if (!isExplicit && !isOldEnough(u.created_at)) continue;
    // 안전 장치: 만약 삭제되지 않은 홈스쿨의 소유자라면 FK RESTRICT 방지를 위해 건너뜀
    if (remainingOwnerIds.has(u.id)) continue;
    targetUsers.push(u);
  }

  const summary = {
    dryRun,
    matchedHomeschools: targetHomeschools.length,
    matchedUsers: targetUsers.length,
    deletedHomeschools: 0,
    deletedUsers: 0,
    skippedHomeschools,
    errors: [],
  };

  if (dryRun) {
    summary.homeschoolPreview = targetHomeschools.map((h) => ({
      id: h.id,
      name: h.name,
      ownerEmail: userById.get(h.owner_user_id)?.email || h.owner_user_id,
      createdAt: h.created_at,
    }));
    summary.userPreview = targetUsers.map((u) => ({
      id: u.id,
      email: u.email,
      createdAt: u.created_at,
    }));
    return summary;
  }

  // 3) 홈스쿨 삭제: PostgreSQL CASCADE 순서에서 teacher_profiles가 terms보다 먼저 지워질 때
  //    session_teacher_assignments / teaching_plans RESTRICT에 걸리지 않도록
  //    terms → families → teacher_profiles → homeschools 순서로 정리한다.
  const failedHomeschoolOwnerIds = new Set();
  for (const hs of targetHomeschools) {
    try {
      const encodedId = encodeURIComponent(hs.id);
      for (const childTable of ["terms", "families", "teacher_profiles"]) {
        await fetch(
          `${supabaseUrl}/rest/v1/${childTable}?homeschool_id=eq.${encodedId}`,
          { method: "DELETE", headers }
        );
      }

      const res = await fetch(
        `${supabaseUrl}/rest/v1/homeschools?id=eq.${encodedId}`,
        {
          method: "DELETE",
          headers,
        }
      );
      if (!res.ok) {
        const text = await res.text();
        failedHomeschoolOwnerIds.add(hs.owner_user_id);
        summary.errors.push(`homeschool ${hs.id} (${hs.name}): ${res.status} ${text}`);
      } else {
        summary.deletedHomeschools += 1;
      }
    } catch (err) {
      failedHomeschoolOwnerIds.add(hs.owner_user_id);
      summary.errors.push(
        `homeschool ${hs.id}: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  // 4) Auth 사용자 삭제
  for (const u of targetUsers) {
    if (failedHomeschoolOwnerIds.has(u.id)) continue;
    try {
      const res = await fetch(
        `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(u.id)}`,
        {
          method: "DELETE",
          headers,
        }
      );
      if (!res.ok && res.status !== 404) {
        const text = await res.text();
        summary.errors.push(`user ${u.id} (${u.email}): ${res.status} ${text}`);
      } else {
        summary.deletedUsers += 1;
      }
    } catch (err) {
      summary.errors.push(
        `user ${u.id}: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  return summary;
}

const isDirectRun =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isDirectRun) {
  (async () => {
    const args = process.argv.slice(2);
    const execute = args.includes("--execute") || process.env.EXECUTE === "1";
    const maxAgeArg = args.find((a) => a.startsWith("--max-age-minutes="));
    const maxAgeMinutes = maxAgeArg ? Number(maxAgeArg.split("=")[1] || "0") : 0;
    const maxAgeMs = Math.max(0, maxAgeMinutes) * 60 * 1000;

    const { supabaseUrl, serviceRoleKey } = await resolveSupabaseCredentials();
    if (!serviceRoleKey) {
      console.error("Missing SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_ACCESS_TOKEN in .env)");
      process.exit(1);
    }

    const result = await cleanupE2eData({
      supabaseUrl,
      serviceRoleKey,
      maxAgeMs,
      dryRun: !execute,
    });

    console.log(JSON.stringify(result, null, 2));
    if (result.errors.length > 0) {
      process.exit(1);
    }
  })().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
