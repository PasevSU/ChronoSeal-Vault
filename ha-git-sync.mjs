#!/usr/bin/env node
import { spawn } from 'child_process';
import { platform } from 'os';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname  = path.dirname(fileURLToPath(import.meta.url));
const REPO_PATH  = process.env.REPO_PATH || process.cwd();
const BRANCH     = process.env.BRANCH    || 'main';

function runWindows() {
  const ps1 = path.join(__dirname, 'ha-git-sync.ps1');
  console.log('[JS] Windows -> PowerShell watcher');
  const child = spawn('powershell.exe', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', ps1,
    '-RepoPath', REPO_PATH,
    '-Branch', BRANCH
  ], { stdio: 'inherit' });
  child.on('exit', (code, signal) =>
    process.exit(code ?? (signal ? 1 : 0)));
}

function runLinux() {
  const sh = path.join(__dirname, 'ha-git-sync.sh');
  console.log('[JS] Linux -> bash watcher');
  const child = spawn('bash', [sh], {
    stdio: 'inherit',
    env: { ...process.env, REPO_PATH, BRANCH }
  });
  child.on('exit', (code, signal) =>
    process.exit(code ?? (signal ? 1 : 0)));
}

platform() === 'win32' ? runWindows() : runLinux();
