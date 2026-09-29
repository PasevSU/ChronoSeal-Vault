'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=process.argv[2]||path.resolve(__dirname,'..','_crypto'),mf=path.join(root,'CRYPTO_MANIFEST.json');
if(!fs.existsSync(mf)){console.error('[FAIL] CRYPTO_MANIFEST.json missing');process.exit(3)}
const m=JSON.parse(fs.readFileSync(mf,'utf8'));let bad=0;
for(const r of m.files||[]){const p=path.resolve(root,r.path);if(!(p===root||p.startsWith(root+path.sep))||!fs.existsSync(p)){console.error('[MISSING]',r.path);bad++;continue}const h=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');if(h!==String(r.sha256).toLowerCase()){console.error('[MISMATCH]',r.path);bad++}}
if(bad){console.error(`[FAIL] ${bad} crypto file(s)`);process.exit(2)}console.log(`[PASS] ${(m.files||[]).length} crypto files verified`);
