'use strict';
const fs=require('fs'),path=require('path'),cp=require('child_process'),crypto=require('crypto');
const ROOT=path.resolve(process.argv[2]||__dirname),LOCK=path.join(ROOT,'.chronoseal-update.lock');
const token=crypto.randomBytes(24).toString('hex'); let fd=null;
function git(args){return cp.execFileSync('git',args,{cwd:ROOT,encoding:'utf8',env:{...process.env,GIT_TERMINAL_PROMPT:'0'}}).trim()}
function lock(){try{fd=fs.openSync(LOCK,'wx',0o600);fs.writeFileSync(fd,JSON.stringify({token,pid:process.pid,host:require('os').hostname(),createdAt:new Date().toISOString()}));fs.fsyncSync(fd)}catch(e){throw Error('UPDATE_LOCK_BUSY')}}
function unlock(){if(fd!==null){try{const x=JSON.parse(fs.readFileSync(LOCK));if(x.token!==token)throw Error('UPDATE_LOCK_OWNER_MISMATCH');fs.closeSync(fd);fd=null;fs.unlinkSync(LOCK)}catch(e){throw e}}}
function main(){lock();try{const branch=git(['branch','--show-current']);if(!branch)throw Error('DETACHED_HEAD');const dirty=git(['status','--porcelain']);if(dirty)throw Error('WORKTREE_DIRTY');const before=git(['rev-parse','HEAD']);git(['fetch','--prune','origin']);const upstream=git(['rev-parse','--abbrev-ref','--symbolic-full-name','@{u}']);const behind=Number(git(['rev-list','--count',`HEAD..${upstream}`]));const ahead=Number(git(['rev-list','--count',`${upstream}..HEAD`]));if(ahead&&behind)throw Error('BRANCH_DIVERGED');if(behind)git(['merge','--ff-only',upstream]);const after=git(['rev-parse','HEAD']);const result={ok:true,branch,upstream,before,after,updated:before!==after,ahead,behind};process.stdout.write(JSON.stringify(result,null,2)+'\n')}finally{unlock()}}
try{main()}catch(e){try{unlock()}catch{};process.stderr.write(JSON.stringify({ok:false,error:e.message})+'\n');process.exitCode=2}
