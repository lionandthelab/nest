#!/usr/bin/env node
// messaging-lab headless 웹 스모크 테스트.
//
// 1) frontend/build/web (사전 빌드: node scripts/run_messaging_lab.mjs --build)을 정적 서빙
// 2) 설치된 Chrome을 headless로 띄우고 notifications 권한을 미리 허용
// 3) 렌더 확인 + 스크린샷
// 4) TEST_EMAIL/TEST_PASSWORD가 있으면 로그인 후 메시징 패널/버튼 노출까지 검증
//
// 참고: 실제 푸시 토큰 발급은 Firebase 설정(1-F) 이후에만 가능하다. 그린필드
// 상태에서는 "패널/버튼 구조 노출"까지가 자동 검증 범위이며, 토큰/DB행/실발송은
// 콘솔 설정 후 수동으로 확인한다(SETUP.md 5단계).
//
// 사용법:
//   node scripts/messaging_lab_smoke.mjs
//   $env:TEST_EMAIL='tester@joy.app'; $env:TEST_PASSWORD='...'; node scripts/messaging_lab_smoke.mjs

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB_ROOT = path.join(ROOT, 'frontend', 'build', 'web');
const SHOTS_DIR = path.join(ROOT, 'scripts', 'shots');
const PORT = Number(process.env.PORT ?? 8124);
const TEST_EMAIL = process.env.TEST_EMAIL ?? '';
const TEST_PASSWORD = process.env.TEST_PASSWORD ?? '';

const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript',
  '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff': 'font/woff', '.woff2': 'font/woff2',
};

function serve() {
  const server = http.createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let filePath = path.join(WEB_ROOT, urlPath === '/' ? 'index.html' : urlPath);
    if (!filePath.startsWith(WEB_ROOT)) { res.writeHead(403); res.end(); return; }
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(WEB_ROOT, 'index.html'); // SPA 폴백
    }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(filePath)] ?? 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(res);
  });
  return new Promise((resolve) => server.listen(PORT, () => resolve(server)));
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    `${process.env.LOCALAPPDATA}/Google/Chrome/Application/chrome.exe`,
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  ].filter(Boolean);
  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) throw new Error('Chrome/Edge 실행 파일을 찾지 못했습니다. CHROME_PATH를 지정하세요.');
  return found;
}

async function dumpSemantics(page) {
  return page.evaluate(() => {
    const labels = new Set();
    for (const node of document.querySelectorAll('[aria-label]')) {
      labels.add(node.getAttribute('aria-label'));
    }
    for (const node of document.querySelectorAll(
      'flt-semantics[role], [role="button"], [role="heading"], flt-semantics')) {
      const text = (node.textContent ?? '').trim();
      if (text && text.length < 80) labels.add(text);
    }
    return [...labels].filter(Boolean).slice(0, 100);
  });
}

async function typeInto(page, labelPart, value) {
  const handle = await page.waitForFunction((part) => {
    const nodes = [...document.querySelectorAll('input, textarea, [aria-label]')];
    return nodes.find((node) =>
      (node.getAttribute('aria-label') ?? '').includes(part));
  }, { timeout: 15000 }, labelPart);
  const element = handle.asElement();
  for (let attempt = 0; attempt < 3; attempt++) {
    await element.click();
    await new Promise((resolve) => setTimeout(resolve, 400));
    await element.evaluate((input) => { input.value = ''; });
    await page.keyboard.down('Control');
    await page.keyboard.press('KeyA');
    await page.keyboard.up('Control');
    await page.keyboard.press('Delete');
    await element.type(value, { delay: 30 });
    const typed = await element.evaluate((input) => input.value);
    if (typed === value) return;
  }
  throw new Error(`${labelPart} 입력 실패`);
}

async function main() {
  if (!fs.existsSync(path.join(WEB_ROOT, 'index.html'))) {
    throw new Error('빌드가 없습니다. 먼저: node scripts/run_messaging_lab.mjs --build');
  }
  fs.mkdirSync(SHOTS_DIR, { recursive: true });

  const server = await serve();
  const origin = `http://127.0.0.1:${PORT}`;
  console.log(`[smoke] ${origin} 서빙 중 (${WEB_ROOT})`);

  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--window-size=1280,900'],
    defaultViewport: { width: 1280, height: 900 },
  });

  const failures = [];
  try {
    // 웹 푸시 토큰 획득 시도가 권한 프롬프트에 막히지 않도록 미리 허용.
    await browser.defaultBrowserContext().overridePermissions(origin, ['notifications']);

    const page = await browser.newPage();
    const consoleErrors = [];
    page.on('pageerror', (error) => consoleErrors.push(`pageerror: ${error.message}`));
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(`console: ${message.text()}`);
    });

    await page.goto(`${origin}/`, { waitUntil: 'networkidle2', timeout: 60000 });

    await page.waitForFunction(
      () => !!document.querySelector('flt-glass-pane, flutter-view'),
      { timeout: 60000 },
    );
    console.log('[smoke] Flutter 렌더 확인');

    await page.evaluate(() => {
      document.querySelector('flt-semantics-placeholder')?.click();
    });
    await page.waitForFunction(
      () => document.querySelectorAll('[aria-label]').length > 0,
      { timeout: 20000 },
    ).catch(() => console.log('[smoke] 경고: 시맨틱 트리가 노출되지 않음'));

    await new Promise((resolve) => setTimeout(resolve, 1500));
    await page.screenshot({ path: path.join(SHOTS_DIR, 'messaging_lab_web.png') });
    console.log('[smoke] 스크린샷: scripts/shots/messaging_lab_web.png');

    const labels = await dumpSemantics(page);
    const hasLoginUi =
      labels.some((label) => label.includes('이메일')) &&
      labels.some((label) => label.includes('비밀번호'));
    if (!hasLoginUi) {
      failures.push(`로그인 UI 시맨틱 미확인 (labels: ${labels.join(' | ').slice(0, 300)})`);
    } else {
      console.log('[smoke] 로그인 UI 시맨틱 확인');
    }

    if (TEST_EMAIL && TEST_PASSWORD && hasLoginUi) {
      console.log(`[smoke] 이메일 로그인 E2E 시작: ${TEST_EMAIL}`);
      await typeInto(page, '이메일', TEST_EMAIL);
      await typeInto(page, '비밀번호', TEST_PASSWORD);

      const clicked = await page.evaluate(() => {
        const nodes = [...document.querySelectorAll('[role="button"], flt-semantics')];
        const button = nodes.find((node) => {
          const label = (node.getAttribute('aria-label') ?? node.textContent ?? '').trim();
          return label === '로그인';
        });
        if (!button) return false;
        button.click();
        return true;
      });
      if (!clicked) failures.push('로그인 버튼을 찾지 못했습니다.');

      // 로그인 후 메시징 패널(제목 '메시징 검증')과 버튼 노출 확인.
      const panelShown = clicked && await page.waitForFunction(() => {
        const texts = [...document.querySelectorAll('[aria-label], flt-semantics')]
          .map((node) => (node.getAttribute('aria-label') ?? '') + '|' + (node.textContent ?? ''));
        return texts.some((text) => text.includes('메시징 검증'));
      }, { timeout: 30000 }).then(() => true).catch(() => false);

      await page.screenshot({ path: path.join(SHOTS_DIR, 'messaging_lab_web_panel.png') });
      console.log('[smoke] 스크린샷: scripts/shots/messaging_lab_web_panel.png');

      if (panelShown) {
        const after = await dumpSemantics(page);
        const hasButtons = ['권한 요청', '토큰 등록', '나에게 SMS']
          .every((needle) => after.some((label) => label.includes(needle)));
        if (hasButtons) {
          console.log('[smoke] 메시징 패널 + 액션 버튼 노출 확인');
        } else {
          failures.push(`메시징 버튼 일부 미확인 (labels: ${after.join(' | ').slice(0, 400)})`);
        }
      } else {
        const after = await dumpSemantics(page);
        failures.push(`로그인 후 메시징 패널 미확인 (labels: ${after.join(' | ').slice(0, 400)})`);
      }
    } else if (TEST_EMAIL) {
      console.log('[smoke] 로그인 UI 미확인으로 E2E 생략');
    } else {
      console.log('[smoke] TEST_EMAIL 미지정 — 렌더/구조 스모크만 수행');
    }

    const fatalConsole = consoleErrors.filter(
      (error) => !error.includes('favicon') && !error.includes('manifest'));
    if (fatalConsole.length > 0) {
      console.log(`[smoke] 콘솔 에러 ${fatalConsole.length}건:`);
      for (const error of fatalConsole.slice(0, 5)) console.log(`  - ${error}`);
    }
  } finally {
    await browser.close();
    server.close();
  }

  if (failures.length > 0) {
    console.error(`\n[smoke] 실패:\n${failures.map((failure) => `  - ${failure}`).join('\n')}`);
    process.exitCode = 1;
  } else {
    console.log('\n[smoke] 전체 통과');
  }
}

main().catch((error) => {
  console.error(`[smoke] 오류: ${error.message}`);
  process.exitCode = 1;
});
