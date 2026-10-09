#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),os=require('os'),http=require('http'),crypto=require('crypto'),cp=require('child_process');
const ROOT=path.resolve(__dirname,'..'), expectedVersion=require(path.join(ROOT,'package.json')).version;
const base=path.join(os.tmpdir(),`chronoseal-runtime-security-${process.pid}`);fs.rmSync(base,{recursive:true,force:true});for(const d of ['evidence','import','export','staging','runtime'])fs.mkdirSync(path.join(base,d),{recursive:true});
const fakeJar=path.join(base,'runtime','OtsCli.jar');fs.writeFileSync(fakeJar,'not-a-jar');const fakeHash=crypto.createHash('sha256').update(fs.readFileSync(fakeJar)).digest('hex');
function request(port,method,url,body=null,headers={}){return new Promise((resolve,reject)=>{const r=http.request({host:'127.0.0.1',port,method,path:url,headers},res=>{const a=[];res.on('data',c=>a.push(c));res.on('end',()=>resolve({status:res.statusCode,body:Buffer.concat(a)}))});r.on('error',reject);if(body)r.write(body);r.end()})}
async function wait(port){for(let i=0;i<50;i++){try{const r=await request(port,'GET','/api/status');if(r.status===200)return JSON.parse(r.body)}catch{}await new Promise(r=>setTimeout(r,100))}throw Error('SERVER_START_TIMEOUT')}
function spawnServer(port,sha=''){return cp.spawn(process.execPath,[path.join(ROOT,'server.js')],{cwd:ROOT,stdio:['ignore','pipe','pipe'],env:{...process.env,CHRONOSEAL_APP_ROOT:path.join(ROOT,'app'),CHRONOSEAL_PORT:String(port),CHRONOSEAL_EVIDENCE_ROOT:path.join(base,'evidence'),CHRONOSEAL_IMPORT_ROOT:path.join(base,'import'),CHRONOSEAL_EXPORT_ROOT:path.join(base,'export'),CHRONOSEAL_STAGING_ROOT:path.join(base,'staging'),CHRONOSEAL_JAVA_OTS_JAR:fakeJar,CHRONOSEAL_JAVA_OTS_SHA256:sha}})}
async function stop(p){if(!p.killed)p.kill('SIGTERM');await new Promise(r=>{const t=setTimeout(r,1500);p.once('exit',()=>{clearTimeout(t);r()})})}
(async()=>{
 const checks={};let p;
 try{
  const port=19000+(process.pid%500);p=spawnServer(port,'');const st=await wait(port);checks.version=st.version===expectedVersion;const jr=st.runtimes?.otsIndependent?.java;checks.unpinnedJavaRejected=jr?.ready===false&&jr?.candidates?.some(x=>x.entry===fakeJar&&x.reason==='SHA256_PIN_REQUIRED');
  const bad=await request(port,'POST','/api/admin/run',Buffer.from('{"id":"arbitrary-shell"}'),{'content-type':'application/json','content-length':24});let bj={};try{bj=JSON.parse(bad.body)}catch{}checks.adminAllowlistRejects=bad.status===403&&bj.error==='SCRIPT_NOT_ALLOWLISTED';
  const payload=Buffer.alloc(2*1024*1024,0x5a),h=crypto.createHash('sha256').update(payload).digest('hex'),hr=await request(port,'POST','/api/hash',payload,{'content-length':payload.length});const hj=JSON.parse(hr.body);checks.streamingHash=hr.status===200&&hj.bytes===payload.length&&hj.sha256===h;
  const allowed=await request(port,'GET','/pgp-toolbox/index.html'),blocked1=await request(port,'GET','/pgp-toolbox/server/server.js'),blocked2=await request(port,'GET','/pgp-toolbox/docs/ARCHITECTURE.md'),blocked3=await request(port,'GET','/pgp-toolbox/start.js');checks.staticAssetAllowlist=allowed.status===200&&blocked1.status===400&&blocked2.status===400&&blocked3.status===400;
  await stop(p);p=null;
  const port2=19500+(process.pid%500);p=spawnServer(port2,fakeHash);const st2=await wait(port2);const jr2=st2.runtimes?.otsIndependent?.java;checks.corruptPinnedJavaNotReady=jr2?.trusted===true&&jr2?.ready===false&&jr2?.reason==='JAVA_OTS_EXECUTION_FAILED';
 }finally{if(p)await stop(p);fs.rmSync(base,{recursive:true,force:true})}
 const failed=Object.entries(checks).filter(([,v])=>!v).map(([k])=>k),out={schema:'chronoseal-runtime-security-gate/v1',ok:failed.length===0,checks,failed};console.log(JSON.stringify(out,null,2));process.exit(out.ok?0:12);
})().catch(e=>{console.error(JSON.stringify({schema:'chronoseal-runtime-security-gate/v1',ok:false,error:e.stack||e.message},null,2));process.exit(12)});
