'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');

function logEvent(message, level='info') {
  const entry = { timestamp: new Date().toISOString(), level, message };
  console.log(`[OTS][${level}] ${message}`);
  return entry;
}
function scanPendingOts(dir=path.resolve('data/pending')) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, {withFileTypes:true})
    .filter(e => e.isFile() && e.name.toLowerCase().endsWith('.ots'))
    .map(e => path.join(dir,e.name));
}
function createSha256File(file, verification={}) {
  const hash=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const out=`${file}.sha256`;
  fs.writeFileSync(out, `${hash}  ${path.basename(file)}\n`);
  return out;
}
async function upgradeTimestamp(otsPath) {
  return {status:'pending', path:otsPath, reason:'OTS_UPGRADE_REQUIRES_CALENDAR_ADAPTER'};
}
async function verifyTimestamp(otsPath) {
  if (!fs.existsSync(otsPath)) return {verified:false,error:'FILE_NOT_FOUND'};
  return {verified:false,error:'OTS_VERIFICATION_ADAPTER_REQUIRED',path:otsPath};
}
module.exports={scanPendingOts,upgradeTimestamp,verifyTimestamp,createSha256File,logEvent};
