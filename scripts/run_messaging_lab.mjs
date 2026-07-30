#!/usr/bin/env node
// messaging-lab 런처 — .env의 클라이언트 안전 키를 dart-define으로 주입해
// 독립 검증 타깃(main_messaging_lab.dart)을 실행/빌드한다.
//
// 사용법:
//   node scripts/run_messaging_lab.mjs                    # Chrome, http://localhost:8080
//   node scripts/run_messaging_lab.mjs -d emulator-5554   # Android 에뮬레이터
//   node scripts/run_messaging_lab.mjs --build            # 웹 릴리스 빌드만 (headless 테스트용)
//
// 주의: Solapi/FCM '서버 시크릿'(SOLAPI_API_SECRET, FCM_SERVICE_ACCOUNT 등)은
//       절대 dart-define으로 넘기지 않는다 — 발송은 lion-notify Edge Function에서만.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const FRONTEND = path.join(ROOT, 'frontend');

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

// 루트 .env + packages/lion_auth/.env 병합(패키지 값 우선).
const env = {
  ...parseEnv(path.join(ROOT, '.env')),
  ...parseEnv(path.join(ROOT, 'packages', 'lion_auth', '.env')),
};

// 클라이언트에 주입해도 되는 '공개' 키만 전달한다.
// (SOLAPI_API_KEY/SECRET, FCM_SERVICE_ACCOUNT 등 발송 시크릿은 제외 — 서버 전용)
const DEFINE_KEYS = [
  // 세션 확보용 로그인 키(이메일만으로도 동작).
  'LION_GOOGLE_WEB_CLIENT_ID',
  'LION_KAKAO_NATIVE_APP_KEY',
  'LION_KAKAO_JS_KEY',
  // 메시징 클라이언트 값.
  'LION_FCM_WEB_VAPID_KEY', // 웹 푸시 공개키
  'LION_SOLAPI_TEMPLATE_ID', // 알림톡 테스트 템플릿 코드(선택)
  // 웹 Firebase 설정(공개값 — 웹 앱에 그대로 노출되는 값).
  'LION_FCM_WEB_API_KEY',
  'LION_FCM_WEB_APP_ID',
  'LION_FCM_WEB_SENDER_ID',
  'LION_FCM_WEB_PROJECT_ID',
];

const defines = DEFINE_KEYS.filter((key) => env[key])
  .flatMap((key) => ['--dart-define', `${key}=${env[key]}`]);

const args = process.argv.slice(2);
const build = args.includes('--build');
const deviceIndex = Math.max(args.indexOf('-d'), args.indexOf('--device'));
const device = deviceIndex >= 0 ? args[deviceIndex + 1] : 'chrome';
const portIndex = args.indexOf('--port');
const port = portIndex >= 0 ? args[portIndex + 1] : '8080';

const flutterArgs = build
  ? ['build', 'web', '-t', 'lib/main_messaging_lab.dart', '--release', ...defines]
  : [
      'run',
      '-t', 'lib/main_messaging_lab.dart',
      '-d', device,
      ...(device === 'chrome' || device === 'web-server'
        ? ['--web-port', port]
        : []),
      ...defines,
    ];

const activeKeys = DEFINE_KEYS.filter((key) => env[key]);
console.log(`[messaging-lab] 주입된 키: ${activeKeys.length ? activeKeys.join(', ') : '(없음 — 로그인/구조만 확인 가능)'}`);
console.log(`[messaging-lab] flutter ${flutterArgs.join(' ')}\n`);

const result = spawnSync('flutter', flutterArgs, {
  cwd: FRONTEND,
  stdio: 'inherit',
  shell: true,
});
process.exitCode = result.status ?? 1;
