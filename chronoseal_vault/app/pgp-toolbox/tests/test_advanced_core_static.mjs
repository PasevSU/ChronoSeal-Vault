import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const core = fs.readFileSync(path.join(root, 'scripts', 'advanced-core.js'), 'utf8');
const app = fs.readFileSync(path.join(root, 'scripts', 'app.js'), 'utf8');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const required = [
  'verifyPrimaryKey', 'verifyAllUsers', '.verify(date, config)', 'addSubkey',
  '.revoke(key.keyPacket', 'decryptSessionKeys', 'getEncryptionKeyIDs', 'getSigningKeyIDs',
  'allowUnauthenticatedMessages: false', 'allowUnauthenticatedStream: false',
  'enforceGrammar', 'minRSABits', 'maxDecompressedMessageSize', 'openpgp.unarmor', 'SHA-512'
];
for (const marker of required) {
  if (!core.includes(marker)) throw new Error(`advanced core marker missing: ${marker}`);
}
for (const marker of ['expectSigned', 'signatureNotations', 'wildcard', 'signingKeyIDs', 'preferredSymmetricAlgorithm: selectedAlgorithm', 'Session-key algorithm mismatch', 'preferredCompressionAlgorithm']) {
  if (!app.includes(marker)) throw new Error(`signed-encryption marker missing: ${marker}`);
}
for (const marker of ['advanced-summary','advLifecycleKey','advValidationKey','advSessionMessage','encryptSignEnabled','decryptExpectSigned','advArmorInput','encryptCompression']) {
  if (!html.includes(marker)) throw new Error(`advanced UI marker missing: ${marker}`);
}
if (/openpgp\.config\s*=/.test(core + app)) throw new Error('global openpgp.config assignment detected');
if (/allowUnauthenticatedMessages\s*:\s*true/.test(core + app)) throw new Error('insecure unauthenticated-message mode enabled');
if (/allowUnauthenticatedStream\s*:\s*true/.test(core + app)) throw new Error('insecure unauthenticated-stream mode enabled');
console.log('[PASS] Advanced OpenPGP Core static policy/API checks');
