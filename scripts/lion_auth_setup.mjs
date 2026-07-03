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
//
// 값 발급 방법: packages/lion_auth/SETUP.md

import { execSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ENV_PATH = path.join(ROOT, '.env');
const MANIFEST_PATH = path.join(
  ROOT, 'frontend', 'android', 'app', 'src', 'main', 'AndroidManifest.xml',
);
const PLIST_PATH = path.join(ROOT, 'frontend', 'ios', 'Runner', 'Info.plist');
const MANAGEMENT_API = 'https://api.supabase.com/v1';

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

const env = parseEnv(ENV_PATH);
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
  const probe = spawnSync('supabase', ['--version'], { shell: true, encoding: 'utf8' });
  if (probe.status !== 0) {
    console.log(`[broker] supabase CLI를 찾지 못했습니다. 수동 배포 명령:
  supabase functions deploy social-broker --project-ref ${ref}`);
    return;
  }
  execSync(`supabase functions deploy social-broker --project-ref ${ref}`, {
    cwd: ROOT,
    stdio: 'inherit',
  });
  console.log('[broker] 배포 완료');
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
    case 'all':
      await configureSupabase();
      patchAndroid();
      patchIos();
      deployBroker();
      await doctor();
      break;
    default:
      console.error(`알 수 없는 명령: ${command} (doctor|supabase|android|ios|broker|all)`);
      process.exitCode = 1;
  }
} catch (error) {
  console.error(`\n실패: ${error.message}`);
  process.exitCode = 1;
}
