#!/usr/bin/env node
// lion_auth 자동 셋업 — .env만 채우면 대시보드 클릭 없이 전부 CLI로 처리한다.
//
// 사용법:
//   node scripts/lion_auth_setup.mjs all       # supabase + android + ios + broker + doctor
//   node scripts/lion_auth_setup.mjs doctor    # 상태 진단만
//   node scripts/lion_auth_setup.mjs supabase  # Management API로 provider 설정 + Naver 시크릿
//   node scripts/lion_auth_setup.mjs android   # AndroidManifest.xml 패치 (멱등)
//   node scripts/lion_auth_setup.mjs ios       # Info.plist 패치 (Nid* 키만 자동, 스킴은 안내 출력)
//   node scripts/lion_auth_setup.mjs broker    # social-broker Edge Function 배포 (supabase CLI)
//   node scripts/lion_auth_setup.mjs messaging  # 마이그레이션 + Solapi/FCM 시크릿 + lion-notify 배포
//   node scripts/lion_auth_setup.mjs migrate-messaging  # push_tokens 등 마이그레이션만
//   node scripts/lion_auth_setup.mjs messaging-secrets  # Solapi/FCM 시크릿 주입만
//   node scripts/lion_auth_setup.mjs notify     # lion-notify Edge Function 배포만
//
// 값 발급 방법: packages/lion_auth/SETUP.md

import { execSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ENV_PATH = path.join(ROOT, '.env');
// LION_* 키는 .env.example이 있는 packages/lion_auth/.env 에 채우는 것이
// 자연스러우므로 두 위치를 병합해서 읽는다(패키지 값이 우선).
const PACKAGE_ENV_PATH = path.join(ROOT, 'packages', 'lion_auth', '.env');
const MANIFEST_PATH = path.join(
  ROOT, 'frontend', 'android', 'app', 'src', 'main', 'AndroidManifest.xml',
);
const PLIST_PATH = path.join(ROOT, 'frontend', 'ios', 'Runner', 'Info.plist');
const MANAGEMENT_API = 'https://api.supabase.com/v1';
const MESSAGING_MIGRATION_HOST = path.join(
  ROOT, 'supabase', 'migrations', '20260707100000_lion_messaging.sql',
);
const MESSAGING_MIGRATION_TEMPLATE = path.join(
  ROOT, 'packages', 'lion_auth', 'server', 'supabase', 'migrations',
  '20260707100000_lion_messaging.sql',
);

// ---------------------------------------------------------------- env

function parseEnv(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const env = {};
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match || line.trim().startsWith('#')) continue;
    env[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

const env = { ...parseEnv(ENV_PATH), ...parseEnv(PACKAGE_ENV_PATH) };
// 기존 Nest 스크립트들과의 호환: SUPABASE_TOKEN도 액세스 토큰으로 인정.
env.SUPABASE_ACCESS_TOKEN = env.SUPABASE_ACCESS_TOKEN || env.SUPABASE_TOKEN;

function projectRef() {
  if (env.SUPABASE_PROJECT_REF) return env.SUPABASE_PROJECT_REF;
  const url = env.SUPABASE_URL ?? '';
  const match = url.match(/https:\/\/([a-z0-9]+)\.supabase\.co/);
  return match ? match[1] : '';
}

// ------------------------------------------------------- management api

async function managementApi(method, apiPath, body) {
  const token = env.SUPABASE_ACCESS_TOKEN;
  if (!token) throw new Error('.env에 SUPABASE_ACCESS_TOKEN이 없습니다.');
  const response = await fetch(`${MANAGEMENT_API}${apiPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(`Management API ${method} ${apiPath} 실패 (${response.status}): ${text}`);
  }
  return data;
}

async function configureSupabase() {
  const ref = projectRef();
  if (!ref) throw new Error('.env에 SUPABASE_PROJECT_REF(또는 SUPABASE_URL)가 없습니다.');

  console.log(`\n[supabase] 프로젝트 ${ref} auth provider 설정 중...`);
  const patch = {};

  if (env.LION_GOOGLE_WEB_CLIENT_ID) {
    // client_id는 콤마 구분 목록 — id_token audience 검증에 웹/Android/iOS 모두 허용.
    const ids = [
      env.LION_GOOGLE_WEB_CLIENT_ID,
      env.LION_GOOGLE_ANDROID_CLIENT_ID,
      env.LION_GOOGLE_IOS_CLIENT_ID,
    ].filter(Boolean);
    patch.external_google_enabled = true;
    patch.external_google_client_id = ids.join(',');
    if (env.LION_GOOGLE_WEB_CLIENT_SECRET) {
      patch.external_google_secret = env.LION_GOOGLE_WEB_CLIENT_SECRET;
    }
    patch.external_google_skip_nonce_check = true; // GIS 웹 버튼은 nonce를 보내지 않음
  }

  if (env.LION_KAKAO_REST_API_KEY) {
    // 첫 항목(REST API 키)이 OAuth 리다이렉트용, 나머지는 id_token audience 허용용.
    const ids = [
      env.LION_KAKAO_REST_API_KEY,
      env.LION_KAKAO_NATIVE_APP_KEY,
      env.LION_KAKAO_JS_KEY,
    ].filter(Boolean);
    patch.external_kakao_enabled = true;
    patch.external_kakao_client_id = ids.join(',');
    if (env.LION_KAKAO_CLIENT_SECRET) {
      patch.external_kakao_secret = env.LION_KAKAO_CLIENT_SECRET;
    }
  }

  if (Object.keys(patch).length === 0) {
    console.log('[supabase] 설정할 Google/Kakao 키가 .env에 없습니다. 건너뜀.');
  } else {
    await managementApi('PATCH', `/projects/${ref}/config/auth`, patch);
    console.log(`[supabase] provider 설정 완료: ${Object.keys(patch).join(', ')}`);
  }

  if (env.LION_NAVER_CLIENT_ID && env.LION_NAVER_CLIENT_SECRET) {
    await managementApi('POST', `/projects/${ref}/secrets`, [
      { name: 'NAVER_CLIENT_ID', value: env.LION_NAVER_CLIENT_ID },
      { name: 'NAVER_CLIENT_SECRET', value: env.LION_NAVER_CLIENT_SECRET },
    ]);
    console.log('[supabase] social-broker용 NAVER 시크릿 주입 완료');
  } else {
    console.log('[supabase] LION_NAVER_CLIENT_ID/SECRET 없음 — Naver 시크릿 건너뜀.');
  }
}

// ------------------------------------------------------------ android

const MANIFEST_BEGIN = '<!-- lion_auth:begin (자동 생성 - 직접 수정 금지, lion_auth_setup.mjs가 관리) -->';
const MANIFEST_END = '<!-- lion_auth:end -->';

function androidBlock() {
  const lines = [MANIFEST_BEGIN];
  if (env.LION_KAKAO_NATIVE_APP_KEY) {
    lines.push(
      '        <activity',
      '            android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"',
      '            android:exported="true">',
      '            <intent-filter android:label="flutter_web_auth">',
      '                <action android:name="android.intent.action.VIEW" />',
      '                <category android:name="android.intent.category.DEFAULT" />',
      '                <category android:name="android.intent.category.BROWSABLE" />',
      `                <data android:scheme="kakao${env.LION_KAKAO_NATIVE_APP_KEY}" android:host="oauth" />`,
      '            </intent-filter>',
      '        </activity>',
    );
  }
  if (env.LION_NAVER_CLIENT_ID) {
    lines.push(
      `        <meta-data android:name="com.naver.sdk.clientId" android:value="${env.LION_NAVER_CLIENT_ID}" />`,
      `        <meta-data android:name="com.naver.sdk.clientSecret" android:value="${env.LION_NAVER_CLIENT_SECRET ?? ''}" />`,
      '        <meta-data android:name="com.naver.sdk.clientName" android:value="Nest" />',
    );
  }
  lines.push(`        ${MANIFEST_END}`);
  return lines.join('\n');
}

function patchAndroid() {
  console.log('\n[android] AndroidManifest.xml 패치 중...');
  if (!fs.existsSync(MANIFEST_PATH)) {
    throw new Error(`매니페스트를 찾을 수 없습니다: ${MANIFEST_PATH}`);
  }
  let manifest = fs.readFileSync(MANIFEST_PATH, 'utf8');
  const block = androidBlock();

  if (manifest.includes(MANIFEST_BEGIN)) {
    const pattern = new RegExp(
      `[ \\t]*${escapeRegExp(MANIFEST_BEGIN)}[\\s\\S]*?${escapeRegExp(MANIFEST_END)}`,
    );
    manifest = manifest.replace(pattern, `        ${block.trimStart()}`);
    console.log('[android] 기존 lion_auth 블록 갱신');
  } else {
    manifest = manifest.replace('</application>', `${block}\n    </application>`);
    console.log('[android] lion_auth 블록 추가');
  }
  fs.writeFileSync(MANIFEST_PATH, manifest, 'utf8');
  console.log('[android] 완료');
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ---------------------------------------------------------------- ios

const PLIST_BEGIN = '<!-- lion_auth:begin -->';
const PLIST_END = '<!-- lion_auth:end -->';

function patchIos() {
  console.log('\n[ios] Info.plist 패치 중...');
  if (!fs.existsSync(PLIST_PATH)) {
    console.log(`[ios] Info.plist 없음 (${PLIST_PATH}) — 건너뜀.`);
    return;
  }
  let plist = fs.readFileSync(PLIST_PATH, 'utf8');

  const entries = [PLIST_BEGIN];
  if (env.LION_NAVER_CLIENT_ID) {
    entries.push(
      `\t<key>NidClientID</key>\n\t<string>${env.LION_NAVER_CLIENT_ID}</string>`,
      `\t<key>NidClientSecret</key>\n\t<string>${env.LION_NAVER_CLIENT_SECRET ?? ''}</string>`,
      '\t<key>NidAppName</key>\n\t<string>Nest</string>',
      '\t<key>NidUrlScheme</key>\n\t<string>nestnaverlogin</string>',
    );
  }
  entries.push(PLIST_END);
  const block = entries.join('\n');

  if (plist.includes(PLIST_BEGIN)) {
    const pattern = new RegExp(
      `[ \\t]*${escapeRegExp(PLIST_BEGIN)}[\\s\\S]*?${escapeRegExp(PLIST_END)}`,
    );
    plist = plist.replace(pattern, `\t${block.trimStart()}`);
  } else {
    plist = plist.replace(/<\/dict>\s*<\/plist>\s*$/, `${block}\n</dict>\n</plist>\n`);
  }
  fs.writeFileSync(PLIST_PATH, plist, 'utf8');
  console.log('[ios] Nid* 키 주입 완료');

  // CFBundleURLTypes/LSApplicationQueriesSchemes는 기존 항목과 병합이 필요해
  // 자동 패치 대신 추가할 스니펫을 출력한다 (iOS 빌드는 macOS에서 수행).
  console.log(`[ios] 아래 항목은 기존 CFBundleURLTypes/LSApplicationQueriesSchemes에 수동 병합 필요:
  - URL Scheme 추가: kakao${env.LION_KAKAO_NATIVE_APP_KEY ?? '{네이티브앱키}'} , nestnaverlogin
  - LSApplicationQueriesSchemes 추가: kakaokompassauth, kakaotalk, naversearchapp, naversearchthirdlogin`);
}

// -------------------------------------------------------------- broker

function deployBroker() {
  const ref = projectRef();
  console.log('\n[broker] social-broker Edge Function 배포 중...');

  // 로그인 전(익명) 클라이언트가 브로커를 호출하므로 --no-verify-jwt 필요.
  // supabase CLI가 PATH에 없으면 npx로 폴백한다. 인증은 SUPABASE_ACCESS_TOKEN.
  const deployArgs = [
    'functions', 'deploy', 'social-broker',
    '--project-ref', ref, '--no-verify-jwt',
  ];
  const child = spawnSync('supabase', ['--version'], { shell: true, encoding: 'utf8' });
  const runner = child.status === 0 ? 'supabase' : 'npx --yes supabase';
  if (runner.startsWith('npx')) {
    console.log('[broker] supabase CLI 미설치 → npx supabase 로 실행');
  }

  const result = spawnSync(`${runner} ${deployArgs.join(' ')}`, {
    cwd: ROOT,
    stdio: 'inherit',
    shell: true,
    env: { ...process.env, SUPABASE_ACCESS_TOKEN: env.SUPABASE_ACCESS_TOKEN },
  });
  if (result.status !== 0) {
    console.log(`[broker] 배포 실패. 수동 배포:
  npx supabase functions deploy social-broker --project-ref ${ref} --no-verify-jwt`);
    return;
  }
  console.log('[broker] 배포 완료');
}

// ----------------------------------------------------------- messaging

const MESSAGING_SECRET_NAMES = [
  'SOLAPI_API_KEY', 'SOLAPI_API_SECRET', 'SOLAPI_SENDER', 'SOLAPI_PFID',
  'FCM_PROJECT_ID', 'FCM_SERVICE_ACCOUNT',
];

async function configureMessagingSecrets() {
  const ref = projectRef();
  if (!ref) throw new Error('.env에 SUPABASE_PROJECT_REF(또는 SUPABASE_URL)가 없습니다.');
  console.log('\n[messaging] Solapi/FCM 시크릿 주입 중...');
  const secrets = MESSAGING_SECRET_NAMES
    .filter((name) => env[name])
    .map((name) => ({ name, value: env[name] }));
  if (secrets.length === 0) {
    console.log('[messaging] .env에 SOLAPI_*/FCM_* 값이 없습니다. 건너뜀.');
    return;
  }
  await managementApi('POST', `/projects/${ref}/secrets`, secrets);
  console.log(`[messaging] 시크릿 주입 완료: ${secrets.map((s) => s.name).join(', ')}`);
}

async function migrateMessaging() {
  const ref = projectRef();
  if (!ref) throw new Error('.env에 SUPABASE_PROJECT_REF(또는 SUPABASE_URL)가 없습니다.');
  console.log('\n[messaging] lion_messaging 마이그레이션 적용 중...');
  const file = fs.existsSync(MESSAGING_MIGRATION_HOST)
    ? MESSAGING_MIGRATION_HOST
    : MESSAGING_MIGRATION_TEMPLATE;
  const sql = fs.readFileSync(file, 'utf8');
  await managementApi('POST', `/projects/${ref}/database/query`, { query: sql });
  await managementApi('POST', `/projects/${ref}/database/query`, {
    query:
      "insert into supabase_migrations.schema_migrations(version,name) " +
      "values ('20260707100000','lion_messaging') on conflict do nothing;",
  });
  console.log('[messaging] 마이그레이션 적용 완료 (push_tokens/notification_log/notification_prefs)');
}

function deployNotify() {
  const ref = projectRef();
  console.log('\n[messaging] lion-notify Edge Function 배포 중...');
  // 로그인된 사용자만 호출하므로 JWT 검증을 켠 채 배포한다(브로커와 반대).
  const deployArgs = ['functions', 'deploy', 'lion-notify', '--project-ref', ref];
  const child = spawnSync('supabase', ['--version'], { shell: true, encoding: 'utf8' });
  const runner = child.status === 0 ? 'supabase' : 'npx --yes supabase';
  if (runner.startsWith('npx')) {
    console.log('[messaging] supabase CLI 미설치 → npx supabase 로 실행');
  }
  const result = spawnSync(`${runner} ${deployArgs.join(' ')}`, {
    cwd: ROOT,
    stdio: 'inherit',
    shell: true,
    env: { ...process.env, SUPABASE_ACCESS_TOKEN: env.SUPABASE_ACCESS_TOKEN },
  });
  if (result.status !== 0) {
    console.log(`[messaging] 배포 실패. 수동 배포:
  npx supabase functions deploy lion-notify --project-ref ${ref}`);
    return;
  }
  console.log('[messaging] 배포 완료');
}

// -------------------------------------------------------------- doctor

async function doctor() {
  console.log('\n===== lion_auth doctor =====');
  const required = [
    'LION_GOOGLE_WEB_CLIENT_ID',
    'LION_GOOGLE_WEB_CLIENT_SECRET',
    'LION_KAKAO_NATIVE_APP_KEY',
    'LION_KAKAO_JS_KEY',
    'LION_KAKAO_REST_API_KEY',
    'LION_NAVER_CLIENT_ID',
    'LION_NAVER_CLIENT_SECRET',
    'SUPABASE_ACCESS_TOKEN',
  ];
  let ok = true;
  console.log('\n-- .env --');
  for (const key of required) {
    const present = Boolean(env[key]);
    if (!present) ok = false;
    console.log(`  ${present ? 'O' : 'X'} ${key}`);
  }
  console.log(`  ${projectRef() ? 'O' : 'X'} SUPABASE_PROJECT_REF (해석값: ${projectRef() || '없음'})`);

  console.log('\n-- AndroidManifest --');
  const manifestPatched =
    fs.existsSync(MANIFEST_PATH) &&
    fs.readFileSync(MANIFEST_PATH, 'utf8').includes(MANIFEST_BEGIN);
  console.log(`  ${manifestPatched ? 'O' : 'X'} lion_auth 블록 (android 명령으로 주입)`);

  console.log('\n-- 메시징 .env (알림톡/푸시) --');
  for (const name of MESSAGING_SECRET_NAMES) {
    console.log(`  ${env[name] ? 'O' : 'X'} ${name}`);
  }
  console.log(`  ${env.LION_FCM_WEB_VAPID_KEY ? 'O' : 'X'} LION_FCM_WEB_VAPID_KEY (웹 푸시 공개키)`);

  const ref = projectRef();
  if (env.SUPABASE_ACCESS_TOKEN && ref) {
    console.log('\n-- Supabase 서버 설정 --');
    try {
      const config = await managementApi('GET', `/projects/${ref}/config/auth`);
      console.log(`  ${config.external_google_enabled ? 'O' : 'X'} Google provider 활성`);
      console.log(`  ${config.external_kakao_enabled ? 'O' : 'X'} Kakao provider 활성`);
      const functions = await managementApi('GET', `/projects/${ref}/functions`);
      const brokerDeployed = Array.isArray(functions) &&
        functions.some((fn) => fn.slug === 'social-broker');
      console.log(`  ${brokerDeployed ? 'O' : 'X'} social-broker 배포됨`);
      const secrets = await managementApi('GET', `/projects/${ref}/secrets`);
      const naverSecret = Array.isArray(secrets) &&
        secrets.some((s) => s.name === 'NAVER_CLIENT_ID');
      console.log(`  ${naverSecret ? 'O' : 'X'} NAVER_CLIENT_ID 시크릿`);

      const notifyDeployed = Array.isArray(functions) &&
        functions.some((fn) => fn.slug === 'lion-notify');
      console.log(`  ${notifyDeployed ? 'O' : 'X'} lion-notify 배포됨`);
      const solapiSecret = Array.isArray(secrets) &&
        secrets.some((s) => s.name === 'SOLAPI_API_KEY');
      console.log(`  ${solapiSecret ? 'O' : 'X'} SOLAPI_API_KEY 시크릿`);
      const fcmSecret = Array.isArray(secrets) &&
        secrets.some((s) => s.name === 'FCM_SERVICE_ACCOUNT');
      console.log(`  ${fcmSecret ? 'O' : 'X'} FCM_SERVICE_ACCOUNT 시크릿`);
      try {
        const rows = await managementApi('POST', `/projects/${ref}/database/query`, {
          query: "select to_regclass('public.push_tokens') as t;",
        });
        const exists = Array.isArray(rows) && rows[0] && rows[0].t;
        console.log(`  ${exists ? 'O' : 'X'} push_tokens 테이블 (migrate-messaging 로 생성)`);
      } catch (tableError) {
        console.log(`  X push_tokens 조회 실패: ${tableError.message}`);
      }
    } catch (error) {
      ok = false;
      console.log(`  X 서버 조회 실패: ${error.message}`);
    }
  } else {
    console.log('\n-- Supabase 서버 설정: SUPABASE_ACCESS_TOKEN 없음, 조회 생략 --');
  }

  console.log(`\n진단 결과: ${ok ? '설정 준비됨' : '누락 항목 있음 (X 표시 참고)'}`);
  return ok;
}

// ---------------------------------------------------------------- main

const command = process.argv[2] ?? 'doctor';

try {
  switch (command) {
    case 'doctor':
      process.exitCode = (await doctor()) ? 0 : 1;
      break;
    case 'supabase':
      await configureSupabase();
      break;
    case 'android':
      patchAndroid();
      break;
    case 'ios':
      patchIos();
      break;
    case 'broker':
      deployBroker();
      break;
    case 'messaging':
      await migrateMessaging();
      await configureMessagingSecrets();
      deployNotify();
      await doctor();
      break;
    case 'migrate-messaging':
      await migrateMessaging();
      break;
    case 'messaging-secrets':
      await configureMessagingSecrets();
      break;
    case 'notify':
      deployNotify();
      break;
    case 'all':
      await configureSupabase();
      patchAndroid();
      patchIos();
      deployBroker();
      await migrateMessaging();
      await configureMessagingSecrets();
      deployNotify();
      await doctor();
      break;
    default:
      console.error(
        `알 수 없는 명령: ${command} ` +
        `(doctor|supabase|android|ios|broker|messaging|migrate-messaging|messaging-secrets|notify|all)`,
      );
      process.exitCode = 1;
  }
} catch (error) {
  console.error(`\n실패: ${error.message}`);
  process.exitCode = 1;
}
