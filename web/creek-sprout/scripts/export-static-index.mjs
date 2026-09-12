/**
 * Static export for hosts that serve plain files (Vercel, Netlify, S3, ...).
 *
 * `vinext build` emits a Cloudflare-Workers bundle (dist/server/index.js with a
 * `default.fetch` handler) and the client assets (dist/client). The game page is
 * a client-rendered React app, so its server response is a normal HTML shell the
 * browser hydrates — writing that shell to dist/client/index.html turns the
 * build into a fully static site.
 *
 * Usage: npm run build && node scripts/export-static-index.mjs
 */
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const serverEntry = fileURLToPath(new URL('../dist/server/index.js', import.meta.url));
const indexOut = new URL('../dist/client/index.html', import.meta.url);

const mod = await import(serverEntry);
const handler = mod.default;

if (!handler || typeof handler.fetch !== 'function') {
  console.error('[export-static-index] dist/server/index.js 没有 fetch handler;先运行 npm run build');
  process.exit(1);
}

const response = await handler.fetch(
  new Request('https://creek-sprout.static/', { headers: { accept: 'text/html' } }),
  {},
  {},
);

if (!response || !response.ok) {
  console.error('[export-static-index] SSR 返回', response && response.status);
  process.exit(1);
}

const html = await response.text();
if (!html.includes('<!DOCTYPE html')) {
  console.error('[export-static-index] SSR 输出不是 HTML 文档');
  process.exit(1);
}

await writeFile(indexOut, html, 'utf8');
console.log(
  `[export-static-index] 已写入 dist/client/index.html(${html.length} 字节)`,
);
