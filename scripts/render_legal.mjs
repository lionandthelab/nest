#!/usr/bin/env node
// 법무 문서 렌더러 — 단일 소스(frontend/assets/legal/*.md)에서
// 웹 배포용 정적 HTML(frontend/web/*.html)을 생성한다.
//
// 이 HTML은 소셜 로그인 OAuth 콘솔(Google/Kakao/Naver)에 제출할
// 공개 URL 용도다. 배포 후 접근 경로:
//   https://nestapp.life/privacy.html
//   https://nestapp.life/terms.html
//
// 인앱(Flutter) 페이지와 같은 마크다운을 공유하므로 내용이 갈라지지 않는다.
// 마크다운 수정 후 이 스크립트를 다시 실행하면 HTML이 갱신된다.
//
// 사용법: node scripts/render_legal.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LEGAL_DIR = path.join(ROOT, 'frontend', 'assets', 'legal');
const WEB_DIR = path.join(ROOT, 'frontend', 'web');

const DOCS = [
  { md: 'privacy.md', html: 'privacy.html', title: '개인정보처리방침' },
  { md: 'terms.md', html: 'terms.html', title: '이용약관' },
];

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

// **굵게** 인라인만 지원 (법무 문서에 충분)
function inline(text) {
  return escapeHtml(text).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
}

function renderMarkdown(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let paragraph = [];
  let listType = null; // 'ul' | 'ol'
  let inComment = false;

  const flushParagraph = () => {
    if (paragraph.length) {
      out.push(`<p>${inline(paragraph.join(' '))}</p>`);
      paragraph = [];
    }
  };
  const closeList = () => {
    if (listType) {
      out.push(`</${listType}>`);
      listType = null;
    }
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (inComment) {
      if (line.includes('-->')) inComment = false;
      continue;
    }
    if (line.startsWith('<!--')) {
      if (!line.includes('-->')) inComment = true;
      continue;
    }

    if (line === '') {
      flushParagraph();
      closeList();
      continue;
    }

    // 표
    if (line.startsWith('|') && line.endsWith('|')) {
      flushParagraph();
      closeList();
      const rows = [];
      let j = i;
      while (j < lines.length &&
             lines[j].trim().startsWith('|') &&
             lines[j].trim().endsWith('|')) {
        const cells = lines[j].trim().split('|').slice(1, -1).map((c) => c.trim());
        const isDivider = cells.every((c) => /^:?-{2,}:?$/.test(c));
        if (!isDivider) rows.push(cells);
        j++;
      }
      i = j - 1;
      const [head, ...body] = rows;
      const thead = head
        ? `<thead><tr>${head.map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead>`
        : '';
      const tbody = `<tbody>${body
        .map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`)
        .join('')}</tbody>`;
      out.push(`<table>${thead}${tbody}</table>`);
      continue;
    }

    if (line.startsWith('### ')) {
      flushParagraph(); closeList();
      out.push(`<h3>${inline(line.slice(4))}</h3>`);
    } else if (line.startsWith('## ')) {
      flushParagraph(); closeList();
      out.push(`<h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith('# ')) {
      flushParagraph(); closeList();
      out.push(`<h1>${inline(line.slice(2))}</h1>`);
    } else if (line.startsWith('- ')) {
      flushParagraph();
      if (listType !== 'ul') { closeList(); out.push('<ul>'); listType = 'ul'; }
      out.push(`<li>${inline(line.slice(2))}</li>`);
    } else if (/^\d+\.\s/.test(line)) {
      flushParagraph();
      if (listType !== 'ol') { closeList(); out.push('<ol>'); listType = 'ol'; }
      out.push(`<li>${inline(line.replace(/^\d+\.\s/, ''))}</li>`);
    } else {
      paragraph.push(line);
    }
  }
  flushParagraph();
  closeList();
  return out.join('\n');
}

function pageTemplate(title, bodyHtml) {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title} · Nest</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" rel="stylesheet">
<style>
  :root {
    --dusty-rose:#DCAE96; --cream:#F9F7F2; --wood:#5A4637;
    --sage:#8A9A84; --clay:#B48268; --rose-mist:#F4E4DB;
  }
  * { box-sizing:border-box; }
  body {
    margin:0; background:var(--cream); color:var(--wood);
    font-family:'Pretendard','Malgun Gothic',-apple-system,sans-serif;
    line-height:1.6; -webkit-font-smoothing:antialiased;
  }
  .wrap { max-width:760px; margin:0 auto; padding:48px 22px 80px; }
  .brand {
    display:inline-block; font-weight:800; font-size:15px; letter-spacing:.5px;
    color:var(--dusty-rose); text-decoration:none; margin-bottom:28px;
  }
  h1 { font-size:30px; font-weight:800; margin:0 0 10px; color:var(--wood); }
  h2 { font-size:20px; font-weight:700; margin:34px 0 10px; color:var(--wood); }
  h3 { font-size:16px; font-weight:700; margin:22px 0 8px; color:var(--clay); }
  p { margin:0 0 12px; color:#4a4038; }
  ul,ol { margin:0 0 14px; padding-left:22px; color:#4a4038; }
  li { margin-bottom:6px; }
  strong { font-weight:700; color:var(--wood); }
  table {
    border-collapse:collapse; width:100%; margin:14px 0;
    border:1px solid var(--rose-mist); border-radius:10px; overflow:hidden;
  }
  th,td { padding:11px 13px; text-align:left; border:1px solid var(--rose-mist); font-size:14px; }
  th { background:rgba(244,228,219,.5); font-weight:700; }
  .foot { margin-top:44px; padding-top:18px; border-top:1px solid var(--rose-mist);
          font-size:13px; color:#9a8e82; }
  .foot a { color:var(--clay); }
  /* 이 파일은 scripts/render_legal.mjs 가 자동 생성합니다. 직접 수정 금지. */
</style>
</head>
<body>
  <div class="wrap">
    <a class="brand" href="./">🪺 Nest</a>
    ${bodyHtml}
    <div class="foot">
      본 문서는 Nest 앱 내 <b>설정 &gt; 약관 및 정책</b>에서도 확인할 수 있습니다.<br>
      문의: <a href="mailto:mysmaxlab@gmail.com">mysmaxlab@gmail.com</a>
    </div>
  </div>
</body>
</html>
`;
}

let count = 0;
for (const doc of DOCS) {
  const mdPath = path.join(LEGAL_DIR, doc.md);
  if (!fs.existsSync(mdPath)) {
    console.error(`[render-legal] 소스 없음: ${mdPath}`);
    process.exitCode = 1;
    continue;
  }
  const md = fs.readFileSync(mdPath, 'utf8');
  const html = pageTemplate(doc.title, renderMarkdown(md));
  const outPath = path.join(WEB_DIR, doc.html);
  fs.writeFileSync(outPath, html, 'utf8');
  console.log(`[render-legal] ${doc.md} -> web/${doc.html} (${html.length} bytes)`);
  count++;
}
console.log(`[render-legal] 완료 (${count}개)`);
