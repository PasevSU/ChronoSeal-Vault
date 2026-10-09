'use strict';
const fs=require('fs'),path=require('path'),cp=require('child_process'); const R=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(R,p),'utf8'); const html=read('app/index.html'), admin=read('app/scripts/admin-integration.js'), server=read('server.js'), config=read('config.yaml'), donorApp=read('app/pgp-toolbox/scripts/app.js'), donorRuntime=read('app/pgp-toolbox/scripts/runtime-capabilities.js'), donorBootstrap=read('app/pgp-toolbox/scripts/bootstrap.js'), pgpApi=read('pgp-network-api.js');
const checks={
 expertWorkspace:/data-view="pgpexpert"/.test(html)&&/pgp-toolbox\/index\.html/.test(html),
 adminPanel:/data-view="admin"/.test(html)&&/id="view-admin"/.test(html),
 htmlPreflight:/adminPreviewFrame/.test(html)&&/previewHtml/.test(admin),
 temporaryKeys:/Temporary Key Vault/.test(html)&&/const tempKeys=new Map/.test(admin)&&/expiresAt/.test(admin),
 pgpImport:/readPrivateKey/.test(admin)&&/readKey/.test(admin)&&/binaryKey/.test(admin)&&/armoredKey/.test(admin),
 jsonImport:/parseJson/.test(admin)&&/JSON\.parse/.test(admin),
 multipleIdentities:/chronoseal-identities-v1/.test(admin)&&/identityNewProfile/.test(admin),
 adminAllowlist:/ADMIN_SCRIPTS=Object\.freeze/.test(server)&&/SCRIPT_NOT_ALLOWLISTED/.test(server)&&/data-script="runtime-security-gate"/.test(html),
 updater:['updater.js','update_chronoseal.sh','Update_ChronoSeal.cmd','Update_ChronoSeal.ps1'].every(f=>fs.existsSync(path.join(R,f))),
 donorAdvanced:['advanced-core.js','policy-engine.js','runtime-capabilities.js','report-engine.js'].every(f=>fs.existsSync(path.join(R,'app/pgp-toolbox/scripts',f))),
 donorApp:fs.existsSync(path.join(R,'app/pgp-toolbox/scripts/app.js')),
 jsPdf:fs.existsSync(path.join(R,'app/vendor/jspdf.umd.min.js')),
 unicodeFonts:fs.existsSync(path.join(R,'app/vendor/fonts/Roboto-Regular.ttf'))&&fs.existsSync(path.join(R,'app/vendor/fonts/Roboto-Bold.ttf')),
 haIngressStreaming:/ingress_stream:\s*true/.test(config),
 haAdminPanel:/panel_admin:\s*true/.test(config),
 ingressPeerGuard:/172\.30\.32\.2/.test(server)&&/INGRESS_ONLY/.test(server),
 embeddedNoLocalhostRedirect:!/window\.location\.replace/.test(donorBootstrap)&&!/127\.0\.0\.1:3000/.test(donorBootstrap),
 embeddedRelativeApi:/PROXY_CANDIDATES[\s\S]*'\.\.'/.test(donorApp)&&/fetch\('\.\.\/api\/crypto-capabilities'/.test(donorRuntime),
 unifiedPgpApi:['/api/health','/api/crypto-capabilities','/api/discover-email'].every(x=>pgpApi.includes(x))&&pgpApi.includes('api\\/publish')&&pgpApi.includes('api\\/lookup'),
 noBundledDonorNodeModules:!fs.existsSync(path.join(R,'app/pgp-toolbox/server/node_modules')),
 haSlimRuntime:!fs.existsSync(path.join(R,'_crypto.7z'))&&!read('Dockerfile').includes('p7zip'),
 pinnedOtsAuthority:/const JS_OTS_CANDIDATES=\[PINNED_JS_OTS,SOURCE_JS_OTS\]/.test(server)&&/opentimestamps-npm-pinned/.test(server),
 javaOtsFailClosed:/JAVA_OTS_EXPECTED_SHA256/.test(server)&&/SHA256_PIN_REQUIRED/.test(server)
};
const failed=Object.entries(checks).filter(([,v])=>!v).map(([k])=>k);console.log(JSON.stringify({schema:'chronoseal-integration-gate/v1',ok:!failed.length,checks,failed},null,2));process.exitCode=failed.length?2:0;
