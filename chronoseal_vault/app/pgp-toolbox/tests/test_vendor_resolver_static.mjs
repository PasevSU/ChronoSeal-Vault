import assert from 'node:assert/strict'; import fs from 'node:fs';
const ps=fs.readFileSync(new URL('../setup_vendor.ps1',import.meta.url),'utf8'); const sh=fs.readFileSync(new URL('../setup_vendor.sh',import.meta.url),'utf8'); const resolver=fs.readFileSync(new URL('../vendor_resolver.ps1',import.meta.url),'utf8');
for(const text of [ps,sh]){assert.match(text,/6\.3\.1/);assert.match(text,/4\.2\.1/);assert.match(text,/PASEVSU_ALLOW_VENDOR_DOWNLOAD/);assert.match(text,/sha256/i);}
assert.match(ps,/HashStamp/); assert.match(sh,/verify_existing/); assert.match(resolver,/\.sha256/); assert.match(resolver,/Kind='sibling'/);
console.log('[PASS] central _crypto + local SHA-256 pinning contract');
