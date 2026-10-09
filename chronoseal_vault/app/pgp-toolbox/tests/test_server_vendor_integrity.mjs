import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp, mkdir, copyFile, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {setTimeout as sleep} from 'node:timers/promises';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)); const project=path.resolve(here,'..');
const root=await mkdtemp(path.join(tmpdir(),'pasevsu-server-')); const serverDir=path.join(root,'server'); const scripts=path.join(root,'scripts');
await mkdir(serverDir,{recursive:true}); await mkdir(scripts,{recursive:true});
await copyFile(path.join(project,'server','server.js'),path.join(serverDir,'server.js')); await copyFile(path.join(project,'server','wkd-utils.js'),path.join(serverDir,'wkd-utils.js'));
await writeFile(path.join(root,'index.html'),'<!doctype html><title>test</title>'); await writeFile(path.join(root,'manifest.webmanifest'),'{}'); await writeFile(path.join(root,'service-worker.js'),'');
for(const name of ['openpgp.min.js','qrcode.min.js','jspdf.umd.min.js']){const data=Buffer.from(`/* ${name} verified fixture */`); await writeFile(path.join(scripts,name),data); await writeFile(path.join(scripts,name+'.sha256'),crypto.createHash('sha256').update(data).digest('hex')+'\n');}
const port=31874; const child=spawn(process.execPath,[path.join(serverDir,'server.js')],{env:{...process.env,PORT:String(port),PASEVSU_INSTANCE_ID:'fedcba9876543210fedcba9876543210'},stdio:['ignore','pipe','pipe']});
function req(p){return new Promise((resolve,reject)=>{const r=http.request({hostname:'127.0.0.1',port,path:p,headers:{Host:`127.0.0.1:${port}`}},res=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,body:Buffer.concat(chunks).toString()}));});r.on('error',reject);r.end();});}
try{let ready=false;for(let i=0;i<40;i++){try{const r=await req('/api/health');if(r.status===200){ready=true;break;}}catch{}await sleep(50);}assert.ok(ready);let h=JSON.parse((await req('/api/health')).body);assert.equal(h.vendorReady,true);assert.equal((await req('/scripts/openpgp.min.js')).status,200);
await writeFile(path.join(scripts,'openpgp.min.js'),'tampered');h=JSON.parse((await req('/api/health')).body);assert.equal(h.vendorReady,false);assert.equal((await req('/scripts/openpgp.min.js')).status,503);console.log('[PASS] server vendor integrity gate detects runtime tampering and fails closed');}
finally{child.kill('SIGTERM');await rm(root,{recursive:true,force:true});}
