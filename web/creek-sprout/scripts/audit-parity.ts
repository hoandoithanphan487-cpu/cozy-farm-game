// N-031 deterministic parity audit (npm run audit:parity).
// 1) authority drift: locked Swift/docs sources and generator outputs must
//    hash-match what this port consumed
// 2) asset drift: every mirrored PNG/MP3 must match the recorded SHA-256
// 3) static guard: banned legacy CSS/DOM world patterns must never return
// Output: machine-readable JSON (--json) or human summary; exit 1 on any fail.

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const WEB_ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const REPO_ROOT = dirname(dirname(WEB_ROOT));
const jsonOut = process.argv.includes('--json');

function shaFile(path: string): string {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

const failures: string[] = [];
const passes: string[] = [];
const fail = (message: string) => failures.push(message);
const pass = (message: string) => passes.push(message);

const summary: Record<string, unknown> = { audit: 'n-031-web-r3', checks: {} };

// 1) authority lock ----------------------------------------------------------
const lockPath = join(WEB_ROOT, 'content', 'source-lock.json');
const lock = JSON.parse(readFileSync(lockPath, 'utf8')) as {
  swift: Array<{ relative: string; sha256: string }>;
  docs: Array<{ relative: string; sha256: string }>;
  generators: Array<{ relative: string; sha256: string }>;
};
for (const entry of [...lock.swift, ...lock.docs, ...lock.generators]) {
  const path = join(REPO_ROOT, entry.relative);
  try {
    const actual = shaFile(path);
    if (actual !== entry.sha256) {
      fail(`authority drift ${entry.relative}: lock ${entry.sha256} vs tree ${actual}`);
    } else pass(`authority ok ${entry.relative}`);
  } catch {
    fail(`authority missing ${entry.relative}`);
  }
}

// generated data header must still match the frozen contract hash
const mapData = readFileSync(join(WEB_ROOT, 'content', 'r22-map-data.ts'), 'utf8');
const contract = lock.docs.find((d) => d.relative.endsWith('n-015-map-layout-contract.json'));
if (contract) {
  const embedded = /R22_CONTRACT_SHA = "([0-9a-f]{64})"/.exec(mapData);
  if (!embedded || embedded[1] !== contract.sha256) {
    fail(`generated map data out of sync with the contract lock (${embedded?.[1] ?? 'missing'})`);
  } else pass('generated r22-map-data matches locked contract sha');
}
const worldLife = readFileSync(join(WEB_ROOT, 'content', 'r22-world-life.ts'), 'utf8');
const catalogLock = lock.swift.find((s) => s.relative.endsWith('Presentation/WorldLifeCatalog.swift'));
if (catalogLock) {
  const embedded = /R22_CATALOG_SHA = "([0-9a-f]{64})"/.exec(worldLife);
  if (!embedded || embedded[1] !== catalogLock.sha256) {
    fail('generated world-life data out of sync with WorldLifeCatalog.swift');
  } else pass('generated r22-world-life matches locked catalog sha');
}

// 2) asset mirror ------------------------------------------------------------
const manifestPath = join(REPO_ROOT, 'artifacts', 'integration', 'n-031-web-r3', 'asset-manifest.json');
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as {
  asset_count: number;
  assets: Array<{ id: string; web_relative: string; sha256: string; bytes: number }>;
};
let checkedAssets = 0;
for (const asset of manifest.assets) {
  const publicMarker = 'full-assets';
  const markerIndex = asset.web_relative.indexOf(publicMarker);
  const rel = markerIndex >= 0 ? asset.web_relative.slice(markerIndex) : asset.web_relative;
  const webPath = join(WEB_ROOT, 'public', rel);
  try {
    const actual = shaFile(webPath);
    checkedAssets += 1;
    if (actual !== asset.sha256) {
      fail(`asset drift ${rel}: manifest ${asset.sha256} vs web ${actual}`);
    }
  } catch {
    fail(`asset missing on web ${rel}`);
  }
}
if (checkedAssets === manifest.asset_count) pass(`all ${checkedAssets} mirrored assets hash-match`);
else fail(`checked ${checkedAssets}/${manifest.asset_count} assets`);

// 3) static guard: legacy CSS/DOM world must never reappear ------------------
const scannedFiles = [
  join(WEB_ROOT, 'app', 'page.tsx'),
  join(WEB_ROOT, 'app', 'globals.css'),
  join(WEB_ROOT, 'runtime', 'canvas-world.tsx'),
];
const bannedPatterns: Array<[string, RegExp]> = [
  ['legacy DOM world renderer', /\bfunction\s+World\s*\(/],
  ['css puzzle .world class', /\.world\s*\{/],
  ['css .stone-road', /\.stone-road\s*\{/],
  ['css .farm-canal', /\.farm-canal\s*\{/],
  ['css .creek band', /\.creek\s*\{/],
  ['css .world-object', /\.world-object\s*\{/],
  ['css .farm-tile', /\.farm-tile\s*\{/],
  ['css .market-lake', /\.market-lake\s*\{/],
  ['css .exit-marker', /\.exit-marker\s*\{/],
  ['css .horizon strip', /\.horizon\s*\{/],
  ['emoji world actor', /🚶|🌾|🌊|🏠/],
];
for (const file of scannedFiles) {
  const content = readFileSync(file, 'utf8');
  for (const [name, pattern] of bannedPatterns) {
    if (pattern.test(content)) {
      fail(`static guard ${name} found in ${file.split('/').slice(-2).join('/')}`);
    }
  }
}
pass(`static guard clean across ${scannedFiles.length} world-source files`);

// DOM world source is the canvas runtime only
const pageSource = readFileSync(join(WEB_ROOT, 'app', 'page.tsx'), 'utf8');
if (!pageSource.includes("from '@/runtime/canvas-world'")) {
  fail('page.tsx no longer consumes the Canvas world runtime');
} else pass('page.tsx consumes the Canvas world runtime');

// ---------------------------------------------------------------------------
const ok = failures.length === 0;
const report = {
  status: ok ? 'PASS' : 'FAIL',
  checks: {
    authority: passes.length,
    failures: failures.length,
    assetsChecked: checkedAssets,
  },
  failures,
};
summary.checks = report;
if (jsonOut) {
  console.log(JSON.stringify(summary, null, 2));
} else {
  for (const line of passes) console.log(`ok   ${line}`);
  for (const line of failures) console.log(`FAIL ${line}`);
  console.log(
    `\naudit:parity ${ok ? 'PASS' : 'FAIL'} — ${passes.length} ok / ${failures.length} failed / assets ${checkedAssets}`,
  );
}
process.exitCode = ok ? 0 : 1;
