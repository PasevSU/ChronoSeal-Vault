import { webcrypto } from 'node:crypto';

const crypto = webcrypto;
const BLOCK = 1024 * 1024;
function u32be(n) { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, n, false); return b; }
function concatBytes(...parts) { const out = new Uint8Array(parts.reduce((n,p)=>n+p.length,0)); let o=0; for (const p of parts) { out.set(p,o); o+=p.length; } return out; }
function hex(bytes) { return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''); }
class StreamChainHasher {
  constructor() { this.state=new TextEncoder().encode('PASEVSU-SHA512-CHAIN-V1'); this.pending=new Uint8Array(0); this.blockIndex=0; this.totalBytes=0; }
  async commit(block) { this.state=new Uint8Array(await crypto.subtle.digest('SHA-512', concatBytes(this.state,u32be(this.blockIndex),u32be(block.length),block))); this.blockIndex++; this.totalBytes+=block.length; }
  async update(chunk) { const bytes=chunk instanceof Uint8Array?chunk:new Uint8Array(chunk); if(!bytes.length)return; const data=this.pending.length?concatBytes(this.pending,bytes):bytes; let o=0; while(data.length-o>=BLOCK){ await this.commit(data.subarray(o,o+BLOCK)); o+=BLOCK; } this.pending=data.slice(o); }
  async finish(){ if(this.pending.length||this.blockIndex===0) await this.commit(this.pending); this.pending=new Uint8Array(0); return hex(this.state); }
}
async function digest(data, sizes) { const h=new StreamChainHasher(); let o=0; for(const size of sizes){ if(o>=data.length)break; await h.update(data.subarray(o,Math.min(data.length,o+size))); o+=size; } if(o<data.length) await h.update(data.subarray(o)); return { digest:await h.finish(), bytes:h.totalBytes }; }
const data=new Uint8Array(3*BLOCK+12345); for(let i=0;i<data.length;i++) data[i]=(i*131+17)&255;
const results=[
  await digest(data,[data.length]),
  await digest(data,Array(100).fill(65536)),
  await digest(data,[1,17,999,1048575,7,2000000,3])
];
const ok=results.every(r=>r.digest===results[0].digest && r.bytes===data.length);
console.log(JSON.stringify({ok,size:data.length,digest:results[0].digest,variants:results.length},null,2));
if(!ok) process.exit(1);
