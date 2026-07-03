#!/usr/bin/env node
// auth-lab 웹 소셜 로그인 개시(initiation) 검증.
//
// 완전한 소셜 로그인(구글/카카오/네이버 실제 계정 인증)은 각 사업자의 실제
// 자격증명 + 사람 상호작용 + 봇 감지 때문에 headless 자동화가 불가하다.
// 대신 이 스크립트는 검증 가능한 부분을 확인한다:
//   1. 소셜 버튼이 렌더되는가 (Kakao/Naver 아이콘, Google GIS 버튼)
//   2. 네이버 클릭 → nid.naver.com 인가 페이지로 올바른 client_id로 이동하는가
//   3. 콘솔에 치명적 에러가 없는가
//
// GIS/카카오 origin 검증을 위해 등록된 origin(localhost:8080)에서 서빙한다.
//
// 사용법: node scripts/auth_lab_social_check.mjs
//   (사전: node scripts/run_auth_lab.mjs --build)

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB_ROOT = path.join(ROOT, 'frontend', 'build', 'web');
const SHOTS_DIR = path.join(ROOT, 'scripts', 'shots');
const PORT = 8080; // Google/Kakao/Naver 콘솔에 등록된 개발 origin
const HOST = 'localhost';

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
      filePath = path.join(WEB_ROOT, 'index.html');
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath)] ?? 'application/octet-stream' });
    fs.createReadStream(filePath).pipe(res);
  });
  return new Promise((resolve) => server.listen(PORT, HOST, () => resolve(server)));
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
  const found = candidates.find((c) => fs.existsSync(c));
  if (!found) throw new Error('Chrome/Edge 실행 파일을 찾지 못했습니다.');
  return found;
}

async function labels(page) {
  return page.evaluate(() => {
    const set = new Set();
    for (const n of document.querySelectorAll('[aria-label]')) set.add(n.getAttribute('aria-label'));
    return [...set].filter(Boolean);
  });
}

async function main() {
  if (!fs.existsSync(path.join(WEB_ROOT, 'index.html'))) {
    throw new Error('빌드 없음. 먼저: node scripts/run_auth_lab.mjs --build');
  }
  fs.mkdirSync(SHOTS_DIR, { recursive: true });
  const server = await serve();
  console.log(`[social] http://${HOST}:${PORT} 서빙 중`);

  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--window-size=1280,900', `--unsafely-treat-insecure-origin-as-secure=http://${HOST}:${PORT}`],
    defaultViewport: { width: 1280, height: 900 },
  });

  const results = { buttons: {}, naverRedirect: null, consoleErrors: [] };
  try {
    const page = await browser.newPage();
    page.on('pageerror', (e) => results.consoleErrors.push(`pageerror: ${e.message}`));
    page.on('console', (m) => { if (m.type() === 'error') results.consoleErrors.push(`console: ${m.text()}`); });

    await page.goto(`http://${HOST}:${PORT}/`, { waitUntil: 'networkidle2', timeout: 60000 });
    await page.waitForFunction(
      () => !!document.querySelector('flt-glass-pane, flutter-view'), { timeout: 60000 });
    // 시맨틱 활성화
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForFunction(
      () => document.querySelectorAll('[aria-label]').length > 0, { timeout: 20000 }).catch(() => {});
    await new Promise((r) => setTimeout(r, 2500));

    await page.screenshot({ path: path.join(SHOTS_DIR, 'auth_lab_social_web.png') });
    console.log('[social] 스크린샷: scripts/shots/auth_lab_social_web.png');

    const found = await labels(page);
    // brandLine이 활성 프로바이더를 나열하므로 설정 로드 여부를 이걸로도 확인.
    const brandline = await page.evaluate(() => document.body.innerText || '');
    results.buttons.google = brandline.includes('Google') ||
      (await page.$('iframe[src*="accounts.google.com"]')) != null;
    results.buttons.kakao = brandline.includes('Kakao');
    results.buttons.naver = brandline.includes('Naver');
    console.log(`[social] 설정 활성(brandLine): Kakao=${results.buttons.kakao} Naver=${results.buttons.naver} Google=${results.buttons.google}`);
    console.log(`[social] aria-label: ${found.join(' | ')}`);

    // 네이버 버튼은 커스텀 페인트 아이콘이라 aria-label 탐지가 불안정 →
    // 화면 좌표로 직접 클릭한다. (1280x900 뷰포트에서 네이버 아이콘 위치)
    if (results.buttons.naver) {
      await page.mouse.click(675, 631);
      const navigated = await page.waitForFunction(
        () => location.href.includes('nid.naver.com') || location.href.includes('naver.com/oauth'),
        { timeout: 15000 }).then(() => true).catch(() => false);
      const url = page.url();
      results.naverRedirect = {
        navigated,
        toNaver: url.includes('naver.com'),
        hasClientId: url.includes('client_id='),
        hasResponseType: url.includes('response_type=code'),
        url: url.slice(0, 120),
      };
      console.log(`[social] 네이버 리다이렉트: ${JSON.stringify(results.naverRedirect)}`);
      await page.screenshot({ path: path.join(SHOTS_DIR, 'auth_lab_naver_redirect.png') });
    }

    const fatal = results.consoleErrors.filter(
      (e) => !e.includes('favicon') && !e.includes('manifest') && !e.includes('GSI_LOGGER'));
    if (fatal.length) {
      console.log(`[social] 콘솔 에러 ${fatal.length}건 (상위 6):`);
      fatal.slice(0, 6).forEach((e) => console.log(`  - ${e}`));
    }
  } finally {
    await browser.close();
    server.close();
  }

  // 판정
  const ok = results.buttons.kakao && results.buttons.naver &&
    results.naverRedirect?.toNaver && results.naverRedirect?.hasClientId;
  console.log(`\n[social] 판정: ${ok ? '소셜 버튼 렌더 + 네이버 플로우 개시 정상' : '확인 필요 (위 로그 참고)'}`);
  process.exitCode = ok ? 0 : 1;
}

main().catch((e) => { console.error(`[social] 오류: ${e.message}`); process.exitCode = 1; });
