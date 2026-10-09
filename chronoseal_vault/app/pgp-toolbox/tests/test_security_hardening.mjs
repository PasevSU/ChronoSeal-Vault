import assert from 'node:assert/strict'; import fs from 'node:fs';
const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8'); const app=fs.readFileSync(new URL('../scripts/app.js',import.meta.url),'utf8'); const server=fs.readFileSync(new URL('../server/server.js',import.meta.url),'utf8'); const pkg=JSON.parse(fs.readFileSync(new URL('../server/package.json',import.meta.url),'utf8'));
assert.doesNotMatch(html,/PGP\/MIME Email|mime-summary/); assert.doesNotMatch(app,/OpenPGPMime|currentMimeFile/);
assert.doesNotMatch(app,/privateKeyArmored\s*:/); assert.match(app,/privateMaterialIncluded:\s*false/);
assert.match(app,/revocationReason/); assert.match(app,/revocationString/); assert.match(app,/revokedClone = await decrypted\.revoke/); assert.match(app,/revokedClone\.getRevocationCertificate/);
assert.doesNotMatch(html,/certTrustLevel|certExpirationDays|certNote/); assert.match(app,/verifyAllUsers\(\[decryptedSigner\.toPublic\(\)\]/);
assert.match(app,/function escapeHtml/); assert.doesNotMatch(app,/innerHTML\s*=\s*`[^`]*\$\{error\.message\}/); assert.doesNotMatch(app,/innerHTML\s*=\s*`[^`]*\$\{item\.file\.name\}/);
assert.match(app,/dbReplaceAllKeys/); assert.match(app,/Unprotected private-key import is blocked/); assert.match(app,/s2kType:\s*openpgp\.enums\.s2k\.argon2/);
assert.match(app,/verifyAllUsers\(\[node\.parsed\]/); assert.match(app,/PASEVSU_FORTRESS_V2/); assert.match(app,/outerHeaderBinding/); assert.match(app,/PASEVSU_FORTRESS_STREAM_V3/); assert.match(app,/fortressVerifyAndStripBoundManifest/);
assert.match(server,/Content-Security-Policy/); assert.match(server,/vendorIntegrityState/); assert.match(server,/decodeURIComponent\(url\.pathname\)/); assert.match(server,/requestHostAllowed/); assert.match(server,/requestOriginAllowed/); assert.match(server,/lookup\(_hostname/); assert.match(server,/options\?\.all/); assert.match(server,/redirects-1/);
assert.deepEqual(pkg.dependencies ?? {},{}); assert.doesNotMatch(server,/from ['"]express|from ['"]cors|from ['"]helmet|express-rate-limit/);
console.log('[PASS] v2.1.1 security/correctness hardening static assertions');

assert.doesNotMatch(html,/removePassphraseButton/); assert.doesNotMatch(app,/removeKeyPassphrase/);
assert.match(app,/await parsed\.getExpirationTime\(\)/); assert.match(app,/await sk\.getExpirationTime\(\)/); assert.match(app,/await sub\.getExpirationTime\(\)/);
assert.match(app,/const localParsed = key\.privateKey/); assert.match(app,/if \(merged\.isPrivate\?\.\(\)\) key\.privateKey = merged\.armor\(\)/);
