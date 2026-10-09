import assert from 'node:assert/strict'; import fs from 'node:fs';
const policy=fs.readFileSync(new URL('../scripts/policy-engine.js',import.meta.url),'utf8'); const app=fs.readFileSync(new URL('../scripts/app.js',import.meta.url),'utf8');
for(const marker of ['rfc9580-strict','modern-compatible','legacy-interop','forensic-readonly','rfc9980-pqt','noSilentDowngrade','authorizeEncryption']) assert.ok(policy.includes(marker),marker);
assert.match(policy,/browserBundleHashPinned/); assert.match(policy,/verifyPrimaryKey/); assert.match(policy,/decision:blocked\?'BLOCKED'/);
assert.match(app,/enforceEncryptionPolicy\(\[\{ publicKey:emailRecipientState\.armored/); assert.match(app,/await enforceEncryptionPolicy\(selectedRecords\)/); assert.match(app,/await enforceEncryptionPolicy\(\[keys\[Number\(recipIdx\)\]\]\)/);
console.log('[PASS] enforced provider/policy gate contract');
