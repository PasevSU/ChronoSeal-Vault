from pathlib import Path
import hashlib, json, subprocess, sys, re
try:
    import yaml
except Exception as e:
    print('[FAIL] PyYAML required for release validation:', e); sys.exit(2)
root=Path(__file__).resolve().parents[1]
repo=root.parent
required=['config.yaml','Dockerfile','server.js','pgp-network-api.js','tsa-engine.js','pki-engine.js','package.json','app/index.html','app/scripts/app.js','app/scripts/identity-max.js','app/style/app.css','rootfs/etc/services.d/pasevsu/run','_crypto/README.md','_crypto/trust/README.md','tools/generate_crypto_manifest.js','tools/verify_crypto_manifest.js','tools/runtime_selftest.js','tools/RUNTIME_CONTRACT.json','tools/fixtures/hello-world.txt.ots','tools/package_completeness.js','qualification/runtime_security_gate.js']
errors=[]
for rel in required:
    p=root/rel
    if not p.is_file() or p.stat().st_size==0: errors.append(f'MISSING/EMPTY {rel}')
for p in [repo/'repository.yaml', root/'config.yaml']:
    try:
        obj=yaml.safe_load(p.read_text(encoding='utf-8'))
        if not isinstance(obj,dict): raise ValueError('root must be mapping')
    except Exception as e: errors.append(f'YAML {p.name}: {e}')
config=yaml.safe_load((root/'config.yaml').read_text(encoding='utf-8'))
for k in ['name','version','slug','description','arch']:
    if k not in config: errors.append(f'CONFIG missing {k}')
if config.get('url')!='https://github.com/PasevSU/ChronoSeal-Vault': errors.append('CONFIG url mismatch')
if config.get('ingress_port')!=8099: errors.append('CONFIG ingress_port must be 8099')
if config.get('ingress_stream') is not True: errors.append('CONFIG ingress_stream must be true for large evidence uploads')
if config.get('panel_admin') is not True: errors.append('CONFIG panel_admin must be true')
if config.get('backup')!='cold': errors.append('CONFIG backup must be cold for evidence consistency')
if config.get('ports') not in ({},None): errors.append('CONFIG ports must remain empty for ingress-only operation')
package=json.loads((root/'package.json').read_text(encoding='utf-8'))
if package.get('version')!=config.get('version'): errors.append('VERSION config.yaml != package.json')
docker=(root/'Dockerfile').read_text(encoding='utf-8')
if f'ARG BUILD_VERSION={config.get("version")}' not in docker: errors.append('VERSION Dockerfile != config.yaml')
# Runtime contract is a release-critical source of truth.
try:
    contract=json.loads((root/'tools/RUNTIME_CONTRACT.json').read_text(encoding='utf-8'))
    if contract.get('openpgpVersion')!=package.get('dependencies',{}).get('openpgp'): errors.append('CONTRACT openpgp version mismatch')
    if contract.get('opentimestampsVersion')!=package.get('dependencies',{}).get('opentimestamps'): errors.append('CONTRACT opentimestamps version mismatch')
    fixture=root/contract.get('otsFixture',{}).get('path','')
    if not fixture.is_file(): errors.append('CONTRACT OTS fixture missing')
    elif hashlib.sha256(fixture.read_bytes()).hexdigest()!=contract.get('otsFixture',{}).get('sha256'): errors.append('CONTRACT OTS fixture SHA-256 mismatch')
    if contract.get('sourceTreePolicy')!='optional-development-evidence-not-ha-runtime': errors.append('CONTRACT sourceTreePolicy mismatch')
except Exception as e: errors.append(f'RUNTIME CONTRACT: {e}')
for token,msg in [('RUNTIME_CONTRACT.json','Dockerfile does not copy runtime contract'),('tools/fixtures','Dockerfile does not copy runtime fixtures'),('cat /opt/pasevsu/RUNTIME_SELFTEST.json','Dockerfile hides runtime self-test diagnostics'),('test "$rc" -eq 0','Dockerfile runtime self-test is not fail-closed')]:
    if token not in docker: errors.append(msg)
for rel in ['server.js','pgp-network-api.js','tsa-engine.js','pki-engine.js','app/scripts/app.js','app/scripts/identity-max.js']:
    r=subprocess.run(['node','--check',str(root/rel)],capture_output=True,text=True)
    if r.returncode: errors.append(f'JS {rel}: {r.stderr.strip()}')
html=(root/'app/index.html').read_text(encoding='utf-8')
for ref in re.findall(r'(?:src|href)=["\']([^"\']+)',html):
    if ref.startswith(('http:','https:','data:','#')): continue
    if ref=='vendor/openpgp.min.js': continue # generated from pinned openpgp@6.3.1 in Docker build
    if not (root/'app'/ref).is_file(): errors.append(f'BROKEN HTML REF {ref}')
run=(root/'rootfs/etc/services.d/pasevsu/run').read_text(encoding='utf-8')
if 'exec node /opt/pasevsu/server.js' not in run: errors.append('STARTUP run script does not exec server.js')
if re.search(r'^\s*CMD\s+',docker,re.M): errors.append('DUPLICATE STARTUP: Dockerfile CMD plus s6 service')
server=(root/'server.js').read_text(encoding='utf-8')
for ep in ['/api/ots/upgrade','/api/ots/verify','/api/ots/confirm-now','/api/case/audit-verify','/api/case/finalize','/api/case/seal-verify','/api/case/export']:
    if ep not in server: errors.append(f'MISSING ENDPOINT {ep}')
if "ingressOnly:true" in server: errors.append('HARDCODED ingressOnly runtime claim forbidden')
if '172.30.32.2' not in server or 'INGRESS_ONLY' not in server: errors.append('INGRESS source-IP guard missing')
pgpapi=(root/'pgp-network-api.js').read_text(encoding='utf-8')
for ep in ['/api/health','/api/crypto-capabilities','/api/discover-email']:
    if ep not in pgpapi: errors.append(f'MISSING PGP ENDPOINT {ep}')
if 'api\\/publish' not in pgpapi or 'api\\/lookup' not in pgpapi: errors.append('MISSING PGP publish/lookup routes')

for opt in ['evidence_root','import_root','export_root','staging_root','auto_export_copy','copy_original_to_export','java_ots_jar','java_ots_sha256']:
    if opt not in config.get('options',{}): errors.append(f'CONFIG missing storage option {opt}')
for token,msg in [('CHRONOSEAL_EVIDENCE_ROOT','evidence path not wired'),('CHRONOSEAL_IMPORT_ROOT','import path not wired'),('CHRONOSEAL_EXPORT_ROOT','export path not wired'),('CHRONOSEAL_STAGING_ROOT','staging path not wired'),('exportSealedCase','verified export implementation missing')]:
    if token not in server: errors.append(msg)


for token,msg in [('streamToTemp(req','STREAMING ingestion missing'),('verifyPhysicalArtifacts','PHYSICAL seal verification missing'),('ARTIFACT_NAME_COLLISION','artifact collision guard missing'),('assertWritable','central sealed guard missing')]:
    if token not in server: errors.append(msg)
if 'Load .ots' in html or 'evidenceOtsFile' in (root/'app/scripts/app.js').read_text(encoding='utf-8'): errors.append('DEAD OTS import UI forbidden')

if "manifest absent; source tree will be runtime-probed" in (root/'tools/verify_crypto_manifest.js').read_text(encoding='utf-8'): errors.append('FALSE PASS crypto manifest verifier')

if not (root/'tools/runtime_selftest.js').exists(): errors.append('RUNTIME SELFTEST missing')
if 'runtime_selftest.js /opt/pasevsu' not in docker: errors.append('Docker build does not execute runtime selftest')
if 'opentimestamps": "^' in (root/'package.json').read_text(encoding='utf-8'): errors.append('NON-PINNED opentimestamps dependency')
if "probeCommand(process.execPath,[entry,'--help'])" not in server: errors.append('OTS READY is not based on executable runtime probe')

if (root/'_crypto.7z').exists(): errors.append('FULL _crypto.7z must not be shipped in the HA runtime package')
if 'p7zip' in docker or 'pasevsu_crypto.7z' in docker: errors.append('Dockerfile still carries source-archive extraction tooling')
if "const JS_OTS_CANDIDATES=[PINNED_JS_OTS,SOURCE_JS_OTS]" not in server: errors.append('PINNED npm OTS is not primary')
if 'JAVA_OTS_EXPECTED_SHA256' not in server or 'SHA256_PIN_REQUIRED' not in server: errors.append('External Java OTS is not SHA-256 fail-closed')
run=(root/'rootfs/etc/services.d/pasevsu/run').read_text(encoding='utf-8')
if 'CHRONOSEAL_JAVA_OTS_SHA256' not in run: errors.append('Java OTS SHA-256 option not wired')
if "'runtime-security-gate'" not in server: errors.append('Runtime security gate not exposed through Admin allowlist')
if 'STATIC_ASSET_ALLOWLIST' not in server: errors.append('Static web asset allowlist missing')
donor_hashes=root/'qualification_donor_assets.sha256'
if not donor_hashes.is_file(): errors.append('Donor asset hash manifest missing')
else:
    vr=subprocess.run(['sha256sum','-c',donor_hashes.name],cwd=root,capture_output=True,text=True)
    if vr.returncode: errors.append('Donor asset hash verification failed: '+(vr.stdout+vr.stderr).strip())
if (root/'BUILD_MANIFEST.json').exists(): errors.append('STALE BUILD_MANIFEST.json forbidden; RELEASE_MANIFEST is authoritative')
if errors:
    print('\n'.join('[FAIL] '+e for e in errors)); sys.exit(2)
files=[]
for p in sorted(x for x in root.rglob('*') if x.is_file() and x.name!='RELEASE_MANIFEST.json'):
    rel=p.relative_to(root).as_posix()
    h=hashlib.sha256(p.read_bytes()).hexdigest()
    files.append({'path':rel,'bytes':p.stat().st_size,'sha256':h})
manifest={'schema':'pasevsu-release-manifest/v2','version':config['version'],'repository':'https://github.com/PasevSU/ChronoSeal-Vault','files':files}
(root/'RELEASE_MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(f'[PASS] release gate: {len(files)} files; version={config["version"]}')
