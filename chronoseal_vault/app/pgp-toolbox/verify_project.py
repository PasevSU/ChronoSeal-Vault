from __future__ import annotations
import hashlib, json, re, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
errors=[]; warnings=[]
REQUIRED=['index.html','manifest.webmanifest','service-worker.js','style/app.css','scripts/bootstrap.js','scripts/i18n.js','scripts/app.js','scripts/advanced-core.js','scripts/runtime-capabilities.js','scripts/policy-engine.js','scripts/report-engine.js','server/server.js','server/wkd-utils.js','server/package.json','README.md','CHANGELOG.md','docs/ARCHITECTURE.md','docs/SECURITY_HARDENING_V21.md','docs/CRYPTO_RUNTIME_V21.md','docs/PROVIDER_POLICY_V21.md','docs/FORTRESS_STREAMING_V3.md','docs/REPORT_ENGINE_V21.md','docs/TEST_REPORT.md','docs/FINAL_AUDIT_V211.md','start.ps1','stop.ps1','setup_vendor.ps1','setup_vendor.sh','vendor_resolver.ps1','PasevSU_PGP_Toolbox.vbs','PasevSU_PGP_Toolbox_Stop.vbs']
for rel in REQUIRED:
    if not (ROOT/rel).is_file(): errors.append(f'missing required file: {rel}')
for rel in ['manifest.webmanifest','server/package.json']:
    try: json.loads((ROOT/rel).read_text())
    except Exception as e: errors.append(f'invalid JSON {rel}: {e}')
html=(ROOT/'index.html').read_text(); css=(ROOT/'style/app.css').read_text(); app=(ROOT/'scripts/app.js').read_text(); advanced=(ROOT/'scripts/advanced-core.js').read_text(); runtime=(ROOT/'scripts/runtime-capabilities.js').read_text(); policy=(ROOT/'scripts/policy-engine.js').read_text(); report=(ROOT/'scripts/report-engine.js').read_text(); i18n=(ROOT/'scripts/i18n.js').read_text(); server=(ROOT/'server/server.js').read_text(); sw=(ROOT/'service-worker.js').read_text(); bootstrap=(ROOT/'scripts/bootstrap.js').read_text(); setup=(ROOT/'setup_vendor.ps1').read_text(); setup_sh=(ROOT/'setup_vendor.sh').read_text(); resolver=(ROOT/'vendor_resolver.ps1').read_text(); start=(ROOT/'start.ps1').read_text()
all_js='\n'.join([app,advanced,runtime,policy,report,i18n])
ids=re.findall(r'\bid=["\']([^"\']+)',html)
if len(ids)!=len(set(ids)): errors.append('duplicate HTML ids detected')
refs=set(re.findall(r'getElementById\(["\']([^"\']+)',all_js))
for helper in ['el','value','checked','isoDateOrNow','\\$']:
    refs.update(re.findall(r'(?<![\w$])'+helper+r'\(["\']([^"\']+)',all_js))
missing=sorted(refs-set(ids))
if missing: errors.append('JS helper/direct references missing HTML ids: '+', '.join(missing))
controls=set(re.findall(r'<(?:input|select|textarea|button)[^>]+id="([^"]+)"',html)); unbound=sorted(controls-refs-{'theme-toggle'})
if unbound: errors.append('unbound form/button controls: '+', '.join(unbound))
cards=html.count('<details class="card"')
if cards!=21: errors.append(f'expected 21 top-level tool sections, found {cards}')
if 'mime-summary' in html or 'OpenPGPMime' in app: errors.append('unverified PGP/MIME feature must not be advertised')
if re.search(r'<script>(?:.|\n)*?</script>',html): errors.append('inline script block violates strict CSP contract')
if re.search(r'\son(?:click|change|input|load|error|submit)=',html,re.I): errors.append('inline event handler violates strict CSP contract')
for marker in ['http://127.0.0.1:3000/','window.location.replace','scripts/bootstrap.js']:
    if marker not in bootstrap+html: errors.append(f'bootstrap marker missing: {marker}')
if 'privateKeyArmored:' in app or 'privateMaterialIncluded: false' not in app: errors.append('public manifest private-material exclusion contract missing')
for marker in ['revocationReason','revocationString','revokedClone = await decrypted.revoke','revokedClone.getRevocationCertificate']:
    if marker not in app: errors.append(f'revocation correctness marker missing: {marker}')
for marker in ['certTrustLevel','certExpirationDays','certNote']:
    if marker in html: errors.append(f'unsupported certification control still present: {marker}')
if 'verifyAllUsers([decryptedSigner.toPublic()]' not in app: errors.append('post-certification verification missing')
if '/ml|slh|kem|dsa/i' in runtime: errors.append('classical DSA false-positive PQ detector still present')
for marker in ['ml[-_]?kem','ml[-_]?dsa','slh[-_]?dsa']:
    if marker not in runtime: errors.append(f'exact PQ marker missing: {marker}')
for marker in ['authorizeEncryption','browserBundleHashPinned','noSilentDowngrade']:
    if marker not in policy: errors.append(f'policy gate marker missing: {marker}')
if app.count('enforceEncryptionPolicy(')<4: errors.append('not all intended encryption paths are policy-gated')
for marker in ['PASEVSU_FORTRESS_STREAM_V3','fortressVerifyAndStripBoundManifest','metadataBinding']:
    if marker not in app: errors.append(f'Fortress V3 marker missing: {marker}')
if 'caches.match' in sw or 'cache.put' in sw or 'PRECACHE' in sw: errors.append('Service Worker must be network-only')
for marker in ['Content-Security-Policy','requestHostAllowed','requestOriginAllowed','lookup(_hostname','redirects-1']:
    if marker not in server: errors.append(f'server hardening marker missing: {marker}')
for forbidden in ['express','express-rate-limit','helmet({','cors(']:
    if forbidden in server: errors.append(f'external server dependency remains: {forbidden}')
pkg=json.loads((ROOT/'server/package.json').read_text())
if pkg.get('version')!='2.1.1' or pkg.get('dependencies'): errors.append('server package must be v2.1.1 with zero runtime dependencies')
if 'OpenTimestamps' in runtime or 'OtsCli' in runtime or 'OtsCli' in server: errors.append('non-PGP OpenTimestamps capability leaked into PGP runtime')
for marker in ['PASEVSU_ALLOW_VENDOR_DOWNLOAD','.sha256','RequiredOpenPgpVersion','6.3.1','RequiredJsPdfVersion','4.2.1']:
    if marker not in setup+resolver: errors.append(f'vendor integrity marker missing: {marker}')
if 'network bootstrap is disabled' not in setup.lower(): errors.append('PowerShell vendor bootstrap is not fail-closed by default')
if 'verify_existing' not in setup_sh: errors.append('shell vendor hash verification missing')
if "$RequiredServerVersion = '2.1.1'" not in start or 'if (-not $?)' not in start: errors.append('Windows launcher version/PowerShell success contract missing')
if re.search(r'npm\s+(?:install|start)',start,re.I): errors.append('launcher must not require npm install/start')
if 'dbReplaceAllKeys' not in app: errors.append('atomic IndexedDB replacement missing')
if 'removePassphraseButton' in html or 'removeKeyPassphrase' in app: errors.append('unprotected private-key persistence path remains')
if 'await parsed.getExpirationTime()' not in app or 'await sk.getExpirationTime()' not in app or 'await sub.getExpirationTime()' not in app: errors.append('async expiration-time handling incomplete')
if 'FORTRESS_CONTAINER_MAGIC_V2' not in app or 'outerHeaderBinding' not in app: errors.append('Fortress in-memory V2 metadata binding missing')
if 'vendorIntegrityState' not in server or 'decodeURIComponent(url.pathname)' not in server: errors.append('server vendor/path hardening missing')
if 'PASEVSU_INSTANCE_ID' not in server or 'PASEVSU_INSTANCE_ID' not in start or 'vendorReady' not in start: errors.append('launcher instance/vendor-ready health binding missing')
if 'Unprotected private-key import is blocked' not in app: errors.append('unprotected private-key import guard missing')
if app.count('s2kType: openpgp.enums.s2k.argon2')<3: errors.append('Argon2 private/backup protection coverage incomplete')
if 'verifyAllUsers([node.parsed]' not in app: errors.append('Web of Trust cryptographic edge verification missing')
if 'privateKey' in report: errors.append('report engine must not collect private key material')
if 'reportUnicodeConfirmed' in html: errors.append('dead report Unicode control remains')
for marker in ['minmax(0, 1fr)','box-sizing: border-box','.section-guide','.language-switch']:
    if marker not in css: errors.append(f'responsive CSS marker missing: {marker}')
for marker in ["new Set(['bg', 'de'])",'installAccordion()','installGuides()','data-language']:
    if marker not in i18n+html: errors.append(f'BG/DE/accordion marker missing: {marker}')
# syntax checks
node=shutil.which('node')
if node:
    for p in sorted(list((ROOT/'scripts').glob('*.js'))+list((ROOT/'server').glob('*.js'))+list((ROOT/'tests').glob('*.mjs'))+list((ROOT/'tests').glob('*.js'))+[ROOT/'service-worker.js']):
        if p.name.endswith('.min.js'): continue
        r=subprocess.run([node,'--check',str(p)],capture_output=True,text=True)
        if r.returncode: errors.append(f'node --check failed: {p.relative_to(ROOT)}: {r.stderr.strip()}')
else: warnings.append('node unavailable; JS syntax checks skipped')
bash=shutil.which('bash')
if bash:
    r=subprocess.run([bash,'-n',str(ROOT/'setup_vendor.sh')],capture_output=True,text=True)
    if r.returncode: errors.append('setup_vendor.sh syntax failed: '+r.stderr.strip())
# optional vendor state
for rel in ['scripts/openpgp.min.js','scripts/qrcode.min.js','scripts/jspdf.umd.min.js']:
    p=ROOT/rel
    if not p.exists(): warnings.append(f'runtime vendor not embedded; target _crypto resolver will install: {rel}')
    elif not (ROOT/(rel+'.sha256')).exists(): errors.append(f'runtime vendor lacks SHA-256 sidecar: {rel}')
# manifest verification when v2.1 manifest has been generated
mp=ROOT/'PROJECT_MANIFEST.json'
if mp.exists():
    try:
        m=json.loads(mp.read_text())
        if m.get('version')=='2.1.1':
            for item in m.get('files',[]):
                fp=ROOT/item['path']
                if not fp.is_file(): errors.append('manifest missing file: '+item['path']); continue
                digest=hashlib.sha256(fp.read_bytes()).hexdigest()
                if digest!=item['sha256']: errors.append('manifest hash mismatch: '+item['path'])
    except Exception as e: errors.append(f'manifest verification failed: {e}')
print('PasevSU PGP Toolbox v2.1.1 verification')
print('========================================')
print(f'HTML IDs: {len(ids)} / unique {len(set(ids))}')
print(f'Bound DOM controls: {len(controls)} / {len(controls)-len(unbound)}')
print(f'Top-level tool sections: {cards}')
print('Languages: BG + DE')
for w in warnings: print('[WARN]',w)
for e in errors: print('[FAIL]',e)
print('[PASS] comprehensive static/release contract' if not errors else f'[FAIL] {len(errors)} error(s)')
sys.exit(1 if errors else 0)
