import assert from 'node:assert/strict'; import fs from 'node:fs';
const client=fs.readFileSync(new URL('../scripts/runtime-capabilities.js',import.meta.url),'utf8'); const server=fs.readFileSync(new URL('../server/server.js',import.meta.url),'utf8');
assert.match(client,/ml\[-_\]\?kem|ml\[-_\]\?dsa|slh\[-_\]\?dsa/); assert.doesNotMatch(client,/\/ml\|slh\|kem\|dsa\/i/);
assert.match(client,/browserBundleHashPinned/); assert.match(server,/browserBundleHashPinned/); assert.match(server,/hashStampMatches/);
assert.doesNotMatch(server,/OtsCli|OpenTimestamps|typescript-opentimestamps/); assert.match(server,/locationClass/); assert.doesNotMatch(server,/cryptoRoot:\{[^}]*path:/s);
console.log('[PASS] runtime capability/PQ false-positive hardening');
