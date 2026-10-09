#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(process.argv[2]||path.join(__dirname,'..'));
const required=['config.yaml','Dockerfile','package.json','server.js','pgp-network-api.js','tsa-engine.js','pki-engine.js','app/index.html','app/scripts/app.js','app/scripts/identity-max.js','app/style/app.css','app/style/identity-max.css','rootfs/etc/services.d/pasevsu/run','tools/runtime_selftest.js','tools/RUNTIME_CONTRACT.json','tools/fixtures/hello-world.txt.ots','tools/generate_crypto_manifest.js','tools/verify_crypto_manifest.js','tools/release_gate.py','qualification/runtime_security_gate.js','_crypto/README.md','_crypto/trust/README.md'];
const endpoints=['/api/status','/api/hash','/api/text/manifest','/api/text/case','/api/ots/stamp','/api/ots/upgrade','/api/ots/verify','/api/ots/confirm-now','/api/case/artifact','/api/tsa/start','/api/tsa/stop','/api/tsa/stamp','/api/case/audit-verify','/api/case/preflight-verify','/api/case/finalize','/api/case/seal-verify','/api/case/closure','/api/storage/status','/api/import/list','/api/import/case','/api/case/export'];
const server=fs.readFileSync(path.join(root,'server.js'),'utf8'),missing=required.filter(x=>!fs.existsSync(path.join(root,x))),missingEndpoints=endpoints.filter(x=>!server.includes(x));
const contract=JSON.parse(fs.readFileSync(path.join(root,'tools/RUNTIME_CONTRACT.json'),'utf8'));const fixture=path.join(root,contract.otsFixture.path),fixtureSha=fs.existsSync(fixture)?crypto.createHash('sha256').update(fs.readFileSync(fixture)).digest('hex'):null;const docker=fs.readFileSync(path.join(root,'Dockerfile'),'utf8');const pkg=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8'));const config=fs.readFileSync(path.join(root,'config.yaml'),'utf8');const run=fs.readFileSync(path.join(root,'rootfs/etc/services.d/pasevsu/run'),'utf8');
const checks={
 runtimeContract:contract.openpgpVersion===pkg.dependencies.openpgp&&contract.opentimestampsVersion===pkg.dependencies.opentimestamps&&contract.sourceTreePolicy==='optional-development-evidence-not-ha-runtime',
 otsFixture:fixtureSha===contract.otsFixture.sha256,
 dockerSelftestDiagnostics:docker.includes('cat /opt/pasevsu/RUNTIME_SELFTEST.json')&&docker.includes('test "$rc" -eq 0'),
 freshPreflight:server.includes('strictPreflight')&&server.includes('TSA.validateExisting'),
 requiredFiles:missing.length===0,endpoints:missingEndpoints.length===0,
 noFullCryptoArchive:!fs.existsSync(path.join(root,'_crypto.7z'))&&!docker.includes('pasevsu_crypto.7z')&&!docker.includes('p7zip'),
 pinnedOtsPrimary:server.includes("const JS_OTS_CANDIDATES=[PINNED_JS_OTS,SOURCE_JS_OTS]")&&server.includes('javascript-opentimestamps-npm-pinned'),
 staticAssetAllowlist:server.includes('STATIC_ASSET_ALLOWLIST')&&server.includes('pgp-toolbox\\/tests\\/runtime_'),
 runtimeSecurityGate:server.includes("'runtime-security-gate'")&&fs.existsSync(path.join(root,'qualification/runtime_security_gate.js')),
 javaOtsHashPinned:server.includes('JAVA_OTS_EXPECTED_SHA256')&&server.includes('SHA256_PIN_REQUIRED')&&run.includes('CHRONOSEAL_JAVA_OTS_SHA256')&&config.includes('java_ots_sha256'),
 streamingIngest:server.includes('streamToTemp(req'),physicalSeal:server.includes('verifyPhysicalArtifacts'),sealedGuard:server.includes('assertWritable'),collisionGuard:server.includes('ARTIFACT_NAME_COLLISION'),workerLock:server.includes("withCaseLock(d,()=>confirmationCycle(d,false))"),
 configuredStorage:server.includes('CHRONOSEAL_EVIDENCE_ROOT')&&server.includes('CHRONOSEAL_IMPORT_ROOT')&&server.includes('CHRONOSEAL_EXPORT_ROOT')&&server.includes('CHRONOSEAL_STAGING_ROOT'),importPipeline:server.includes('importFileToCase')&&server.includes('IMPORT_STAGING_HASH_MISMATCH'),stagingUsed:server.includes('path.join(STAGING_ROOT,`.upload-'),verifiedExport:server.includes('exportSealedCase')&&server.includes('EXPORT_RECEIPT.json'),haIngressStreaming:config.includes('ingress_stream: true'),ingressPeerGuard:server.includes('172.30.32.2')&&server.includes('INGRESS_ONLY'),unifiedPgpApi:fs.readFileSync(path.join(root,'pgp-network-api.js'),'utf8').includes('/api/crypto-capabilities')
};
const ok=Object.values(checks).every(Boolean);console.log(JSON.stringify({schema:'pasevsu-package-completeness/v2',ok,checks,missing,missingEndpoints},null,2));process.exit(ok?0:10);
