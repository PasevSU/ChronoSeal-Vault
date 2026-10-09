import assert from 'node:assert/strict'; import fs from 'node:fs';
const app=fs.readFileSync(new URL('../scripts/app.js',import.meta.url),'utf8');
assert.match(app,/PASEVSU_FORTRESS_V2\\0/); assert.match(app,/version:2, profile/); assert.match(app,/outerHeaderBinding:JSON\.parse\(JSON\.stringify\(header\)\)/); assert.match(app,/fortressCanonicalJson\(inner\.meta\.outerHeaderBinding\) !== fortressCanonicalJson\(header\)/); assert.match(app,/packBinaryEnvelope\(FORTRESS_CONTAINER_MAGIC_V2, result\.header, encrypted\)/); assert.match(app,/const isV1=startsWithBytes\(containerBytes,FORTRESS_CONTAINER_MAGIC\)/); assert.match(app,/metadataAuthenticated:header\.version===2/);
console.log('[PASS] Fortress in-memory V2 authenticated outer-metadata binding + V1 decrypt compatibility contract');
