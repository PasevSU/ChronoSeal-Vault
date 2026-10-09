import assert from 'node:assert/strict'; import fs from 'node:fs';
const report=fs.readFileSync(new URL('../scripts/report-engine.js',import.meta.url),'utf8'); const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
for(const marker of ["pasevsu-openpgp-report/2.1","SHA-256","SHA-512","pageIds","window.jspdf","publicKeyInventory"]) assert.ok(report.includes(marker),marker);
assert.doesNotMatch(report,/privateKey/); assert.doesNotMatch(html,/reportUnicodeConfirmed/); assert.match(html,/Deutsch \(verified built-in font path\)/); assert.match(report,/currentSnapshot/); assert.match(report,/reportResetSnapshotButton/);
console.log('[PASS] jsPDF technical report privacy/integrity contract');
