import assert from 'node:assert/strict'; import {spawn} from 'node:child_process'; import http from 'node:http'; import {setTimeout as sleep} from 'node:timers/promises';
const port=31873; const child=spawn(process.execPath,[new URL('../server/server.js',import.meta.url).pathname],{env:{...process.env,PORT:String(port),PASEVSU_INSTANCE_ID:'0123456789abcdef0123456789abcdef'},stdio:['ignore','pipe','pipe']});
let logs=''; child.stdout.on('data',d=>logs+=d); child.stderr.on('data',d=>logs+=d);
function req(path,{method='GET',host=`127.0.0.1:${port}`,origin,body,headers={}}={}){return new Promise((resolve,reject)=>{const r=http.request({hostname:'127.0.0.1',port,path,method,headers:{Host:host,...(origin?{Origin:origin}:{}),...headers}},res=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:Buffer.concat(chunks).toString()}));});r.on('error',reject);if(body)r.write(body);r.end();});}
try{
  let ready=false; for(let i=0;i<40;i++){try{const r=await req('/api/health');if(r.status===200){ready=true;break;}}catch{} await sleep(50);} assert.ok(ready,`server not ready: ${logs}`);
  const health=await req('/api/health'); const h=JSON.parse(health.body); assert.equal(h.version,'2.1.1'); assert.equal(h.instanceId,'0123456789abcdef0123456789abcdef'); assert.equal(h.vendorReady,false); assert.match(health.headers['content-security-policy'],/script-src 'self'/); assert.match(health.headers['content-security-policy'],/connect-src 'self'/);
  assert.equal((await req('/api/health',{host:`evil.test:${port}`})).status,403); assert.equal((await req('/api/health',{origin:'https://evil.example'})).status,403);
  const head=await req('/',{method:'HEAD'}); assert.equal(head.status,200); assert.equal(head.body,'');
  assert.equal((await req('/server/server.js')).status,404); assert.equal((await req('/../server/server.js')).status,404); assert.equal((await req('/scripts/%2f..%2fserver/server.js')).status,404); assert.equal((await req('/scripts/openpgp.min.js')).status,503); assert.equal((await req('/scripts/%E0%A4%A')).status,400);
  const caps=await req('/api/crypto-capabilities'); assert.equal(caps.status,200); assert.doesNotMatch(caps.body,/\/mnt\/|[A-Za-z]:\\\\/); assert.doesNotMatch(caps.body,/OpenTimestamps|OtsCli/);
  const huge='keytext='+encodeURIComponent('-----BEGIN PGP PUBLIC KEY BLOCK-----\n'+'A'.repeat(300000)); const tooBig=await req('/api/publish/keys.openpgp.org',{method:'POST',body:huge,headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(huge)}}); assert.equal(tooBig.status,413);
  console.log('[PASS] dependency-free loopback server runtime/security contract');
} finally { child.kill('SIGTERM'); }
