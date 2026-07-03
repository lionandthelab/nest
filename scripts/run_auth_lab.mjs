#!/usr/bin/env node
// auth-lab 런처 — .env의 LION_* 키를 dart-define으로 주입해
// 독립 테스트 타깃(main_auth_lab.dart)을 실행/빌드한다.
//
// 사용법:
//   node scripts/run_auth_lab.mjs                    # Chrome, http://localhost:8080
//   node scripts/run_auth_lab.mjs -d emulator-5554   # Android 에뮬레이터
//   node scripts/run_auth_lab.mjs --build            # 웹 릴리스 빌드만 (headless 테스트용)

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
// LION_* 키는 .env.example이 있는 패키지 폴더에 채우는 것이 자연스럽다.
const env = {
  ...parseEnv(path.join(ROOT, '.env')),
  ...parseEnv(path.join(ROOT, 'packages', 'lion_auth', '.env')),
};

// 클라이언트에 주입해도 되는 키만 전달한다. (NAVER_CLIENT_SECRET은
// Android 매니페스트/서버 브로커 전용 — dart-define으로 넘기지 않는다)
const DEFINE_KEYS = [
  'LION_GOOGLE_WEB_CLIENT_ID',
  'LION_GOOGLE_IOS_CLIENT_ID',
  'LION_KAKAO_NATIVE_APP_KEY',
  'LION_KAKAO_JS_KEY',
  'LION_NAVER_CLIENT_ID',
  'LION_NAVER_WEB_REDIRECT_URI',
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
  ? ['build', 'web', '-t', 'lib/main_auth_lab.dart', '--release', ...defines]
  : [
      'run',
      '-t', 'lib/main_auth_lab.dart',
      '-d', device,
      ...(device === 'chrome' || device === 'web-server'
        ? ['--web-port', port]
        : []),
      ...defines,
    ];

const activeKeys = DEFINE_KEYS.filter((key) => env[key]);
console.log(`[auth-lab] 주입된 키: ${activeKeys.length ? activeKeys.join(', ') : '(없음 — 이메일 로그인만 테스트 가능)'}`);
console.log(`[auth-lab] flutter ${flutterArgs.join(' ')}\n`);

const result = spawnSync('flutter', flutterArgs, {
  cwd: FRONTEND,
  stdio: 'inherit',
  shell: true,
});
process.exitCode = result.status ?? 1;
