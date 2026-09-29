'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const canon=o=>JSON.stringify(o,Object.keys(o||{}).sort());
class ChainOrchestrator{
 constructor(dir){this.dir=dir;fs.mkdirSync(dir,{recursive:true});this.stateFile=path.join(dir,'CHAIN_STATE.json');this.state=this.load()||{schema:'pasevsu-full-forensic-chain/v1',createdAt:new Date().toISOString(),status:'NEW',records:[]}}
 load(){try{return JSON.parse(fs.readFileSync(this.stateFile,'utf8'))}catch{return null}}
 save(){fs.writeFileSync(this.stateFile,JSON.stringify(this.state,null,2))}
 async run(steps,ctx={}){if(this.state.records.at(-1)?.status==='PENDING')this.state.records.pop();this.state.status='RUNNING';this.save();for(let i=this.state.records.length;i<steps.length;i++){const s=steps[i],prev=this.state.records.at(-1)?.recordSha256||null,rec={sequence:i+1,id:s.id,startedAt:new Date().toISOString(),previousRecordSha256:prev,status:'RUNNING'};try{const out=await s.run(ctx,this.state);rec.output=out;rec.status=out?.status||'PASS';rec.completedAt=new Date().toISOString();rec.recordSha256=crypto.createHash('sha256').update(canon(rec)).digest('hex');this.state.records.push(rec);this.state.status=rec.status==='PENDING'?'PENDING':rec.status==='PASS'?'RUNNING':'FAIL';this.save();if(rec.status!=='PASS')return this.state}catch(e){rec.status='FAIL';rec.error=e.message;rec.completedAt=new Date().toISOString();rec.recordSha256=crypto.createHash('sha256').update(canon(rec)).digest('hex');this.state.records.push(rec);this.state.status='FAIL';this.save();return this.state}}this.state.status='PASS';this.state.completedAt=new Date().toISOString();this.save();return this.state}
}
module.exports={ChainOrchestrator};
