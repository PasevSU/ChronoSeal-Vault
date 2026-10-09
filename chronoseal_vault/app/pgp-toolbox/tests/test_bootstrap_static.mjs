import fs from 'node:fs';
import assert from 'node:assert/strict';
const s=fs.readFileSync(new URL('../scripts/bootstrap.js',import.meta.url),'utf8');
assert.match(s,/PASEVSU_EMBEDDED_ORIGIN\s*=\s*true/);
assert.doesNotMatch(s,/window\.location\.replace/);
assert.doesNotMatch(s,/new URL\(['"]http:\/\/127\.0\.0\.1:3000\//);
console.log('[PASS] Home Assistant Ingress embedded-origin bootstrap contract');
