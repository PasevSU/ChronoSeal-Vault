import http from 'node:http';
import https from 'node:https';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import dns from 'node:dns/promises';
import net from 'node:net';
import { fileURLToPath } from 'node:url';
import { splitEmailForWkd } from './wkd-utils.js';

const PORT = Number(process.env.PORT || 3000);
const HOST = '127.0.0.1';
const APP_VERSION = '2.1.1';
const APP_NAME = 'PasevSU PGP Toolbox';
const CANONICAL_ORIGIN = `http://${HOST}:${PORT}`;
const INSTANCE_ID = /^[a-f0-9]{32}$/i.test(process.env.PASEVSU_INSTANCE_ID || '') ? process.env.PASEVSU_INSTANCE_ID.toLowerCase() : null;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FRONTEND_ROOT = path.resolve(__dirname, '..');
const REQUEST_TIMEOUT_MS = 15000;
const MAX_KEY_BYTES = 200 * 1024;
const MAX_BODY_BYTES = 256 * 1024;
const EMAIL_KEY_CACHE_TTL_MS = 15 * 60 * 1000;
const emailKeyCache = new Map();
const rateBuckets = new Map();

const ALLOWED_SERVERS = new Map([
  ['keys.openpgp.org',       'https://keys.openpgp.org'],
  ['keyserver.ubuntu.com',   'https://keyserver.ubuntu.com'],
  ['keys.mailvelope.com',    'https://keys.mailvelope.com'],
  ['keyserver.pgp.com',      'https://keyserver.pgp.com'],
  ['pgp.key-server.io',      'https://pgp.key-server.io'],
  ['keys.gnupg.net',         'https://keys.gnupg.net'],
  ['pgp.uni-mainz.de',       'https://pgp.uni-mainz.de'],
  ['keyserver.cryptnet.net', 'https://keyserver.cryptnet.net'],
  ['keys.niif.hu',           'https://keys.niif.hu'],
  ['pgp.mit.edu',            'https://pgp.mit.edu']
]);

function resolveCryptoRoot() {
  const candidates = [
    process.env.PASEVSU_CRYPTO_HOME,
    path.join(path.dirname(FRONTEND_ROOT), '_crypto'),
    path.join(FRONTEND_ROOT, '_crypto')
  ].filter(Boolean);
  for (const candidate of candidates) {
    try { if (fs.statSync(candidate).isDirectory()) return path.resolve(candidate); } catch {}
  }
  return path.resolve(candidates[0] || path.join(path.dirname(FRONTEND_ROOT), '_crypto'));
}
const CRYPTO_ROOT = resolveCryptoRoot();

function securityHeaders(contentType = '') {
  const headers = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Resource-Policy': 'same-origin',
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; font-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'; worker-src 'self' blob:; manifest-src 'self'"
  };
  if (contentType) headers['Content-Type'] = contentType;
  return headers;
}

function send(res, status, body, contentType = 'text/plain; charset=utf-8', extra = {}) {
  const data = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
  res.writeHead(status, { ...securityHeaders(contentType), 'Content-Length': data.length, ...extra });
  res.end(data);
}
function json(res, status, value, extra = {}) {
  send(res, status, JSON.stringify(value), 'application/json; charset=utf-8', { 'Cache-Control': 'no-store', ...extra });
}

function requestHostAllowed(req) {
  const host = String(req.headers.host || '').toLowerCase();
  return host === `${HOST}:${PORT}` || host === `localhost:${PORT}`;
}
function requestOriginAllowed(req) {
  const origin = req.headers.origin;
  return !origin || origin === CANONICAL_ORIGIN;
}
function sameOriginGuard(req, res) {
  if (!requestHostAllowed(req)) {
    json(res, 403, { ok:false, error:'Host not allowed.' });
    return false;
  }
  if (!requestOriginAllowed(req)) {
    json(res, 403, { ok:false, error:'Origin not allowed.' });
    return false;
  }
  return true;
}

function rateLimitOk(req) {
  const now = Date.now();
  const key = req.socket.remoteAddress || 'loopback';
  const bucket = rateBuckets.get(key) || { start: now, count: 0 };
  if (now - bucket.start >= 60_000) { bucket.start = now; bucket.count = 0; }
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= 60;
}
setInterval(() => {
  const cutoff = Date.now() - 120_000;
  for (const [key, bucket] of rateBuckets) if (bucket.start < cutoff) rateBuckets.delete(key);
}, 60_000).unref();

function fileInfo(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return { exists:true, file:stat.isFile(), directory:stat.isDirectory(), bytes:stat.isFile() ? stat.size : null };
  } catch { return { exists:false, file:false, directory:false, bytes:null }; }
}
function sha256File(filePath) {
  try { return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex'); } catch { return null; }
}
function readTextSafe(filePath) { try { return fs.readFileSync(filePath, 'utf8').trim(); } catch { return null; } }
function hashStampMatches(filePath) { const expected=readTextSafe(filePath + '.sha256')?.toLowerCase(); const actual=sha256File(filePath); return Boolean(expected && actual && expected === actual); }
const RUNTIME_VENDOR_FILES = Object.freeze({
  '/scripts/openpgp.min.js': path.join(FRONTEND_ROOT, 'scripts', 'openpgp.min.js'),
  '/scripts/qrcode.min.js': path.join(FRONTEND_ROOT, 'scripts', 'qrcode.min.js'),
  '/scripts/jspdf.umd.min.js': path.join(FRONTEND_ROOT, 'scripts', 'jspdf.umd.min.js')
});
function vendorIntegrityState() {
  const entries = Object.entries(RUNTIME_VENDOR_FILES).map(([urlPath, file]) => ({ urlPath, present:fileInfo(file).file, hashPinned:hashStampMatches(file) }));
  return { ready:entries.every(x => x.present && x.hashPinned), entries };
}
function readJsonSafe(filePath) { try { return JSON.parse(fs.readFileSync(filePath, 'utf8')); } catch { return null; } }
function detectCryptoCapabilities() {
  const openpgpRoot = path.join(CRYPTO_ROOT, 'openpgpjs');
  const openpgpPackage = readJsonSafe(path.join(openpgpRoot, 'package.json'));
  const pqRoot = path.join(openpgpRoot, 'src', 'crypto', 'public_key', 'post_quantum');
  const browserBundle = path.join(FRONTEND_ROOT, 'scripts', 'openpgp.min.js');
  const qrBundle = path.join(FRONTEND_ROOT, 'scripts', 'qrcode.min.js');
  const qrLocalPreferred = fileInfo(path.join(CRYPTO_ROOT, 'qrcodejs', 'qrcode.js')).file
    ? path.join(CRYPTO_ROOT, 'qrcodejs', 'qrcode.js') : path.join(CRYPTO_ROOT, 'qrcodejs', 'qrcode.min.js');
  const jsPdfRoot = path.join(CRYPTO_ROOT, 'jsPDF');
  const jsPdfPackage = readJsonSafe(path.join(jsPdfRoot, 'package.json'));
  const jsPdfLocalBundle = fileInfo(path.join(jsPdfRoot, 'dist', 'jspdf.umd.min.js')).file
    ? path.join(jsPdfRoot, 'dist', 'jspdf.umd.min.js') : path.join(jsPdfRoot, 'dist', 'jspdf.umd.js');
  const jsPdfRuntimeBundle = path.join(FRONTEND_ROOT, 'scripts', 'jspdf.umd.min.js');
  const pqFiles = {
    index:fileInfo(path.join(pqRoot, 'index.js')).exists,
    mlKem:fileInfo(path.join(pqRoot, 'kem', 'ml_kem.js')).exists,
    mlDsa:fileInfo(path.join(pqRoot, 'signature', 'ml_dsa.js')).exists
  };
  return {
    ok:true, generatedAt:new Date().toISOString(), project:{ version:APP_VERSION, node:process.version },
    cryptoRoot:{ configured:Boolean(process.env.PASEVSU_CRYPTO_HOME), present:fileInfo(CRYPTO_ROOT).directory, locationClass:path.resolve(CRYPTO_ROOT) === path.resolve(path.join(FRONTEND_ROOT,'_crypto')) ? 'project-local' : 'external-or-sibling' },
    openpgp:{ sourcePresent:fileInfo(openpgpRoot).directory, sourceVersion:openpgpPackage?.version || null, browserBundlePresent:fileInfo(browserBundle).file, browserBundleBytes:fileInfo(browserBundle).bytes, browserBundleSha256:sha256File(browserBundle), browserBundleHashPinned:hashStampMatches(browserBundle), postQuantumSource:{ present:pqFiles.index && pqFiles.mlKem && pqFiles.mlDsa, files:pqFiles, runtimeVerified:false, note:'Source presence is not runtime proof. PQ/T remains disabled until exact RFC 9980 runtime algorithms are exposed and tested.' } },
    vendorRuntime:{
      qr:{ provider:readTextSafe(path.join(FRONTEND_ROOT,'scripts','qrcode.provider')), bundlePresent:fileInfo(qrBundle).file, bundleBytes:fileInfo(qrBundle).bytes, bundleSha256:sha256File(qrBundle), bundleHashPinned:hashStampMatches(qrBundle), localSourcePresent:fileInfo(qrLocalPreferred).file, localSourceFile:fileInfo(qrLocalPreferred).file ? path.basename(qrLocalPreferred) : null, localSourceSha256:sha256File(qrLocalPreferred), hashMatchesLocal:Boolean(sha256File(qrBundle) && sha256File(qrBundle) === sha256File(qrLocalPreferred)) },
      jsPDF:{ provider:readTextSafe(path.join(FRONTEND_ROOT,'scripts','jspdf.provider')), runtimeVersion:readTextSafe(path.join(FRONTEND_ROOT,'scripts','jspdf.version')), sourcePresent:fileInfo(jsPdfRoot).directory, sourceVersion:jsPdfPackage?.version || null, localBundlePresent:fileInfo(jsPdfLocalBundle).file, localBundleFile:fileInfo(jsPdfLocalBundle).file ? path.basename(jsPdfLocalBundle) : null, localSourceSha256:sha256File(jsPdfLocalBundle), runtimeBundlePresent:fileInfo(jsPdfRuntimeBundle).file, runtimeBundleBytes:fileInfo(jsPdfRuntimeBundle).bytes, runtimeBundleSha256:sha256File(jsPdfRuntimeBundle), runtimeBundleHashPinned:hashStampMatches(jsPdfRuntimeBundle), hashMatchesLocal:Boolean(sha256File(jsPdfRuntimeBundle) && sha256File(jsPdfRuntimeBundle) === sha256File(jsPdfLocalBundle)) }
    },
    discovery:{ localStore:true, wkd:true, vksFallback:true, order:['local-browser-store','WKD','keys.openpgp.org-VKS'] },
    experimental:{ persistentSymmetricKeys:{ enabled:false, sourceDetected:false, reason:'Draft feature intentionally disabled in production mode.' } }
  };
}

function isPrivateOrLocalAddress(address) {
  if (!address) return true;
  const raw = String(address).trim().toLowerCase();
  const mapped = raw.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isPrivateOrLocalAddress(mapped[1]);
  const family = net.isIP(raw);
  if (family === 4) {
    const parts = raw.split('.').map(Number);
    if (parts.length !== 4 || parts.some(n => !Number.isInteger(n) || n < 0 || n > 255)) return true;
    const [a,b] = parts;
    return a === 0 || a === 10 || a === 127 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 198 && (b === 18 || b === 19)) ||
      a >= 224;
  }
  if (family === 6) {
    if (raw === '::' || raw === '::1') return true;
    if (raw.startsWith('fc') || raw.startsWith('fd')) return true;
    if (/^fe[89ab]/.test(raw)) return true;
    if (raw.startsWith('ff')) return true;
    return false;
  }
  return true;
}

async function resolvePublicHost(hostname) {
  if (!hostname || net.isIP(hostname) || hostname === 'localhost' || hostname.endsWith('.local')) throw new Error('Local/IP hosts are blocked.');
  const results = await dns.lookup(hostname, { all:true, verbatim:true });
  if (!results.length) throw new Error('Host does not resolve.');
  if (results.some(r => isPrivateOrLocalAddress(r.address))) throw new Error('Host resolves to a private/local address and is blocked.');
  return results[0];
}

async function hostResolvesPublicly(hostname) {
  try { await resolvePublicHost(hostname); return true; }
  catch (error) { if (['ENOTFOUND','ENODATA','EAI_NONAME'].includes(error?.code)) return false; throw error; }
}

async function httpsPinned(urlInput, { method='GET', headers={}, body=null, maxBytes=MAX_KEY_BYTES, redirects=3 } = {}) {
  const url = new URL(urlInput);
  if (url.protocol !== 'https:') throw new Error('Only HTTPS upstreams are allowed.');
  const resolved = await resolvePublicHost(url.hostname);
  const response = await new Promise((resolve, reject) => {
    const req = https.request({
      protocol:'https:', hostname:url.hostname, port:url.port || 443, path:`${url.pathname}${url.search}`,
      method, headers:{ ...headers, Host:url.host }, servername:url.hostname,
      lookup(_hostname, options, callback) {
        if (options?.all) callback(null, [{ address:resolved.address, family:resolved.family }]);
        else callback(null, resolved.address, resolved.family);
      },
      timeout:REQUEST_TIMEOUT_MS
    }, res => {
      const chunks=[]; let total=0;
      res.on('data', chunk => { total += chunk.length; if (total > maxBytes) { req.destroy(new Error('Upstream response exceeds size limit.')); return; } chunks.push(chunk); });
      res.on('end', () => resolve({ status:res.statusCode || 0, headers:res.headers, data:Buffer.concat(chunks) }));
    });
    req.on('timeout', () => req.destroy(new Error('Upstream request timeout.')));
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
  if ([301,302,303,307,308].includes(response.status) && response.headers.location) {
    if (redirects <= 0) throw new Error('Too many upstream redirects.');
    const next = new URL(response.headers.location, url);
    if (method !== 'GET' && response.status !== 307 && response.status !== 308) throw new Error('Unsafe redirect for non-GET upstream request.');
    return httpsPinned(next, { method, headers, body, maxBytes, redirects:redirects-1 });
  }
  return response;
}

async function fetchBinaryKey(url) {
  try {
    const upstream = await httpsPinned(url, { headers:{ Accept:'application/octet-stream, application/pgp-keys;q=0.9, */*;q=0.1', 'User-Agent':`PasevSU-PGP-Toolbox/${APP_VERSION}` }, maxBytes:MAX_KEY_BYTES });
    if (upstream.status === 404) return { ok:false, notFound:true, status:404 };
    if (upstream.status < 200 || upstream.status >= 300) return { ok:false, status:upstream.status, error:`WKD HTTP ${upstream.status}` };
    if (!upstream.data.length) return { ok:false, error:'WKD returned an empty key block.' };
    return { ok:true, data:upstream.data };
  } catch (error) { return { ok:false, error:error.message }; }
}

async function discoverViaWkd(email) {
  const parts = splitEmailForWkd(email);
  if (!parts) return { ok:false, error:'Invalid email for WKD.' };
  const { localOriginal, domain, hu } = parts;
  const advancedHost = `openpgpkey.${domain}`;
  const advancedExists = await hostResolvesPublicly(advancedHost);
  let method, url;
  if (advancedExists) {
    method='advanced';
    url=`https://${advancedHost}/.well-known/openpgpkey/${domain}/hu/${hu}?l=${encodeURIComponent(localOriginal)}`;
  } else {
    if (!(await hostResolvesPublicly(domain))) return { ok:false, notFound:true, error:'Recipient domain does not resolve for WKD.' };
    method='direct';
    url=`https://${domain}/.well-known/openpgpkey/hu/${hu}?l=${encodeURIComponent(localOriginal)}`;
  }
  return { ...(await fetchBinaryKey(url)), method, hu, domain };
}

function normalizeEmailAddress(value) {
  const raw=String(value || '').trim();
  if (raw.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) return null;
  const at=raw.lastIndexOf('@');
  return `${raw.slice(0,at)}@${raw.slice(at+1).toLowerCase()}`;
}

async function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks=[]; let total=0, rejected=false;
    req.on('data', chunk => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) { if (!rejected) { rejected=true; reject(Object.assign(new Error('Request body too large.'),{status:413})); } return; }
      if (!rejected) chunks.push(chunk);
    });
    req.on('end', () => { if (!rejected) resolve(Buffer.concat(chunks)); });
    req.on('error', error => { if (!rejected) reject(error); });
  });
}
async function parseBody(req) {
  const raw=(await readBody(req)).toString('utf8');
  const type=String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
  if (type === 'application/json') return raw ? JSON.parse(raw) : {};
  if (type === 'application/x-www-form-urlencoded') return Object.fromEntries(new URLSearchParams(raw));
  throw Object.assign(new Error('Unsupported Content-Type.'),{status:415});
}

const MIME = new Map([
  ['.html','text/html; charset=utf-8'],['.js','text/javascript; charset=utf-8'],['.mjs','text/javascript; charset=utf-8'],['.css','text/css; charset=utf-8'],['.json','application/json; charset=utf-8'],['.webmanifest','application/manifest+json; charset=utf-8'],['.svg','image/svg+xml'],['.png','image/png'],['.txt','text/plain; charset=utf-8']
]);
function serveFile(res, filePath, { noStore=false, head=false } = {}) {
  const resolved=path.resolve(filePath);
  if (!resolved.startsWith(FRONTEND_ROOT + path.sep) && resolved !== path.join(FRONTEND_ROOT,'index.html')) return json(res,403,{ok:false,error:'Forbidden.'});
  let stat; try { stat=fs.statSync(resolved); } catch { return json(res,404,{ok:false,error:'Not found.'}); }
  if (!stat.isFile()) return json(res,404,{ok:false,error:'Not found.'});
  const type=MIME.get(path.extname(resolved).toLowerCase()) || 'application/octet-stream';
  res.writeHead(200,{ ...securityHeaders(type), 'Content-Length':stat.size, 'Cache-Control':noStore ? 'no-store' : 'no-cache' });
  if (head) return res.end();
  fs.createReadStream(resolved).pipe(res);
}

async function handleApi(req,res,url) {
  if (!rateLimitOk(req)) return json(res,429,{ok:false,error:'Rate limit exceeded.'},{'Retry-After':'60'});
  if (req.method === 'GET' && url.pathname === '/api/health') {
    const vendors=vendorIntegrityState();
    return json(res,200,{ok:true,app:APP_NAME,version:APP_VERSION,canonicalOrigin:CANONICAL_ORIGIN,instanceId:INSTANCE_ID,ts:Date.now(),vendorReady:vendors.ready,vendors:vendors.entries});
  }
  if (req.method === 'GET' && url.pathname === '/api/crypto-capabilities') return json(res,200,detectCryptoCapabilities());
  if (req.method === 'GET' && url.pathname === '/api/discover-email') {
    const email=normalizeEmailAddress(url.searchParams.get('email'));
    if (!email) return json(res,400,{ok:false,error:'Invalid email address.'});
    const cached=emailKeyCache.get(email);
    if (cached && Date.now()-cached.at < EMAIL_KEY_CACHE_TTL_MS) return json(res,200,{ok:true,...cached.payload,cached:true});
    try {
      const wkd=await discoverViaWkd(email);
      if (wkd.ok) {
        const payload={source:'wkd',method:wkd.method,exactEmailRequested:email,binaryBase64:wkd.data.toString('base64'),verifiedEmail:false,note:'Browser must verify that the certificate contains the exact requested email User ID.'};
        emailKeyCache.set(email,{payload,at:Date.now()});
        return json(res,200,{ok:true,...payload,cached:false});
      }
    } catch {}
    try {
      const upstream=await httpsPinned(`https://keys.openpgp.org/vks/v1/by-email/${encodeURIComponent(email)}`,{headers:{Accept:'application/pgp-keys','User-Agent':`PasevSU-PGP-Toolbox/${APP_VERSION}`},maxBytes:MAX_KEY_BYTES});
      if (upstream.status === 404) return json(res,404,{ok:false,error:'No public key found through WKD or the verified exact-email VKS directory.'});
      if (upstream.status === 429) return json(res,429,{ok:false,error:'Email lookup rate limit reached.'});
      if (upstream.status < 200 || upstream.status >= 300) return json(res,502,{ok:false,error:`Directory HTTP ${upstream.status}`});
      const armored=upstream.data.toString('utf8');
      if (!armored.includes('-----BEGIN PGP PUBLIC KEY BLOCK-----')) return json(res,502,{ok:false,error:'Directory returned an invalid public-key response.'});
      const payload={source:'keys.openpgp.org-vks',method:'exact-email',verifiedEmail:true,exactEmailRequested:email,armored};
      emailKeyCache.set(email,{payload,at:Date.now()});
      return json(res,200,{ok:true,...payload,cached:false});
    } catch (error) { return json(res,502,{ok:false,error:error.message}); }
  }

  const publishMatch=url.pathname.match(/^\/api\/publish\/([^/]+)$/);
  if (req.method === 'POST' && publishMatch) {
    const host=decodeURIComponent(publishMatch[1]); const base=ALLOWED_SERVERS.get(host);
    if (!base) return json(res,400,{ok:false,error:'Server not whitelisted.'});
    try {
      const body=await parseBody(req); const keytext=body?.keytext;
      if (typeof keytext !== 'string' || !keytext.length) return json(res,400,{ok:false,error:'Missing keytext.'});
      if (Buffer.byteLength(keytext,'utf8') > MAX_KEY_BYTES) return json(res,413,{ok:false,error:'Key too large.'});
      if (!keytext.includes('-----BEGIN PGP PUBLIC KEY BLOCK-----')) return json(res,400,{ok:false,error:'Only armored public keys may be published.'});
      const encoded=new URLSearchParams({keytext}).toString();
      const upstream=await httpsPinned(`${base}/pks/add`,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(encoded),'User-Agent':`PasevSU-PGP-Toolbox/${APP_VERSION}`},body:encoded,maxBytes:64*1024,redirects:0});
      const ok=upstream.status>=200 && upstream.status<300; const verifying=host==='keys.openpgp.org';
      return json(res,upstream.status || 502,{ok,host,status:upstream.status,verifying,message:verifying && ok ? 'Check email to confirm UID.' : upstream.data.toString('utf8').slice(0,512)});
    } catch (error) { return json(res,error.status || 502,{ok:false,host,error:error.message}); }
  }

  const lookupMatch=url.pathname.match(/^\/api\/lookup\/([^/]+)\/([^/]+)$/);
  if (req.method === 'GET' && lookupMatch) {
    const host=decodeURIComponent(lookupMatch[1]); const query=decodeURIComponent(lookupMatch[2]); const base=ALLOWED_SERVERS.get(host);
    if (!base) return json(res,400,{ok:false,error:'Server not whitelisted.'});
    if (!/^(0x)?[0-9A-Fa-f]{8,64}$/.test(query)) return json(res,400,{ok:false,error:'Invalid query.'});
    const normalized=query.startsWith('0x') ? query : `0x${query}`;
    try {
      const upstream=await httpsPinned(`${base}/pks/lookup?op=get&search=${encodeURIComponent(normalized)}&options=mr`,{headers:{'User-Agent':`PasevSU-PGP-Toolbox/${APP_VERSION}`},maxBytes:MAX_KEY_BYTES});
      if (upstream.status===404) return json(res,404,{ok:false,error:'Not found.'});
      if (upstream.status<200 || upstream.status>=300) return json(res,502,{ok:false,error:`Upstream HTTP ${upstream.status}`});
      const armored=upstream.data.toString('utf8');
      if (!armored.includes('-----BEGIN PGP')) return json(res,404,{ok:false,error:'Not found.'});
      return json(res,200,{ok:true,host,armored});
    } catch (error) { return json(res,502,{ok:false,host,error:error.message}); }
  }
  return json(res,404,{ok:false,error:'API route not found.'});
}

async function handler(req,res) {
  try {
    if (!sameOriginGuard(req,res)) return;
    if (req.method === 'OPTIONS') {
      res.writeHead(204,{...securityHeaders(),'Access-Control-Allow-Origin':CANONICAL_ORIGIN,'Access-Control-Allow-Methods':'GET, POST, OPTIONS','Access-Control-Allow-Headers':'Content-Type','Access-Control-Max-Age':'600'}); res.end(); return;
    }
    const url=new URL(req.url || '/',CANONICAL_ORIGIN);
    if (url.pathname.startsWith('/api/')) return await handleApi(req,res,url);
    if (req.method !== 'GET' && req.method !== 'HEAD') return json(res,405,{ok:false,error:'Method not allowed.'});
    if (url.pathname==='/' || url.pathname==='/index.html') return serveFile(res,path.join(FRONTEND_ROOT,'index.html'),{noStore:true,head:req.method==='HEAD'});
    if (url.pathname==='/manifest.webmanifest') return serveFile(res,path.join(FRONTEND_ROOT,'manifest.webmanifest'),{head:req.method==='HEAD'});
    if (url.pathname==='/service-worker.js') return serveFile(res,path.join(FRONTEND_ROOT,'service-worker.js'),{noStore:true,head:req.method==='HEAD'});
    let decodedPath;
    try { decodedPath=decodeURIComponent(url.pathname); } catch { return json(res,400,{ok:false,error:'Bad request.'}); }
    if (decodedPath.includes('\0') || decodedPath.includes('\\')) return json(res,400,{ok:false,error:'Bad request.'});
    const normalized=path.posix.normalize(decodedPath);
    const parts=normalized.split('/').filter(Boolean);
    const allowedDirs=new Set(['style','scripts','icons','tests']);
    if (parts.length < 2 || !allowedDirs.has(parts[0])) return json(res,404,{ok:false,error:'Not found.'});
    const base=path.resolve(FRONTEND_ROOT,parts[0]);
    const target=path.resolve(base,...parts.slice(1));
    const rel=path.relative(base,target);
    if (!rel || rel.startsWith('..') || path.isAbsolute(rel)) return json(res,403,{ok:false,error:'Forbidden.'});
    const vendorFile=RUNTIME_VENDOR_FILES[normalized];
    if (vendorFile && !hashStampMatches(vendorFile)) return json(res,503,{ok:false,error:'Vendor integrity verification failed.'});
    return serveFile(res,target,{noStore:parts[0]==='tests',head:req.method==='HEAD'});
  } catch (error) { return json(res,500,{ok:false,error:'Internal server error.',detail:process.env.PASEVSU_DEBUG==='1' ? error.message : undefined}); }
}

const server=http.createServer(handler);
server.on('clientError',(_err,socket)=>{ try { socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n'); } catch {} });
server.listen(PORT,HOST,()=>console.log(`${APP_NAME} v${APP_VERSION}: ${CANONICAL_ORIGIN}/`));
