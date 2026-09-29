from pathlib import Path
import hashlib, json, subprocess, sys, re
try:
    import yaml
except Exception as e:
    print('[FAIL] PyYAML required for release validation:', e); sys.exit(2)
root=Path(__file__).resolve().parents[1]
repo=root.parent
required=['config.yaml','Dockerfile','server.js','tsa-engine.js','pki-engine.js','package.json','app/index.html','app/scripts/app.js','app/scripts/identity-max.js','app/style/app.css','rootfs/etc/services.d/pasevsu/run','_crypto.7z','tools/generate_crypto_manifest.js','tools/verify_crypto_manifest.js','tools/runtime_selftest.js','tools/package_completeness.js']
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
if config.get('ports') not in ({},None): errors.append('CONFIG ports must remain empty for ingress-only operation')
package=json.loads((root/'package.json').read_text(encoding='utf-8'))
if package.get('version')!=config.get('version'): errors.append('VERSION config.yaml != package.json')
docker=(root/'Dockerfile').read_text(encoding='utf-8')
if f'ARG BUILD_VERSION={config.get("version")}' not in docker: errors.append('VERSION Dockerfile != config.yaml')
for rel in ['server.js','tsa-engine.js','pki-engine.js','app/scripts/app.js','app/scripts/identity-max.js']:
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

for opt in ['evidence_root','import_root','export_root','staging_root','auto_export_copy','copy_original_to_export']:
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

archive_hash=hashlib.sha256((root/'_crypto.7z').read_bytes()).hexdigest()
if archive_hash not in docker: errors.append('CRYPTO ARCHIVE SHA-256 is not pinned in Dockerfile')
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
