// Kompass auto-updater (no installer needed). Works with the portable .exe:
//   1. ask the GitHub releases API for the latest release of KampfGuy/kompass
//   2. if it is newer (semver), read its kompass-update.json manifest (name, size, sha512 of the portable exe)
//   3. download the new exe next to our data folder with progress, verify size + sha512
//   4. when the user restarts (or quits), a tiny helper script waits for Kompass to exit,
//      replaces the exe at PORTABLE_EXECUTABLE_FILE and (optionally) starts it again.
// Pure Node (no electron import) so it can be unit-tested; main.js wires it to the app.
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto'), cp = require('child_process');

const DEFAULT_API = 'https://api.github.com/repos/KampfGuy/kompass/releases/latest';
const MANIFEST = 'kompass-update.json';

function parseVer(v) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?/.exec(String(v || '').trim());
  if (!m) return null;
  return { nums: [+m[1], +m[2], +m[3]], pre: m[4] ? m[4].split('.') : [] };
}
// semver compare: -1 a<b, 0 equal, 1 a>b; prerelease < release; invalid versions sort lowest
function compareVersions(a, b) {
  const A = parseVer(a), B = parseVer(b);
  if (!A || !B) return A ? 1 : B ? -1 : 0;
  for (let i = 0; i < 3; i++) if (A.nums[i] !== B.nums[i]) return A.nums[i] > B.nums[i] ? 1 : -1;
  if (!A.pre.length || !B.pre.length) return A.pre.length === B.pre.length ? 0 : A.pre.length ? -1 : 1;
  for (let i = 0; i < Math.max(A.pre.length, B.pre.length); i++) {
    const x = A.pre[i], y = B.pre[i];
    if (x === undefined) return -1; if (y === undefined) return 1;
    const nx = /^\d+$/.test(x), ny = /^\d+$/.test(y);
    if (nx && ny && +x !== +y) return +x > +y ? 1 : -1;
    if (nx !== ny) return nx ? -1 : 1;
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
}

function sha512File(file) {
  return new Promise((res, rej) => { const h = crypto.createHash('sha512'); fs.createReadStream(file).on('error', rej).on('data', d => h.update(d)).on('end', () => res(h.digest('base64'))); });
}

async function getJson(url, fetchImpl, timeoutMs) {
  const ac = new AbortController(); const t = setTimeout(() => ac.abort(), timeoutMs || 15000);
  try {
    const r = await fetchImpl(url, { headers: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'Kompass-Updater' }, signal: ac.signal });
    if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + url);
    return await r.json();
  } finally { clearTimeout(t); }
}

// Returns null when up to date, else {version, notes, url, asset:{name,size,sha512,url}, kind}
async function checkLatest({ current, apiUrl = DEFAULT_API, fetchImpl = fetch, kind = 'portable' }) {
  const rel = await getJson(apiUrl, fetchImpl);
  if (!rel || rel.draft || rel.prerelease) return null;
  const version = String(rel.tag_name || '').replace(/^v/, '');
  if (compareVersions(version, current) <= 0) return null;
  const assets = rel.assets || [];
  const info = { version, notes: rel.body || '', url: rel.html_url || '', asset: null, kind };
  const man = assets.find(a => a.name === MANIFEST);
  if (!man) return info;  // newer release but no manifest: can only offer the download page
  const m = await getJson(man.browser_download_url, fetchImpl);
  if (m.version && compareVersions(m.version, version) !== 0) throw new Error('manifest version mismatch');
  const f = (m.files || []).find(x => x.kind === kind) || null;
  if (f) {
    const a = assets.find(x => x.name === f.name);
    if (a) info.asset = { name: f.name, size: +f.size, sha512: f.sha512, url: a.browser_download_url };
  }
  return info;
}

// Download with progress; verifies size + sha512; atomically renames into dest. Returns dest.
async function download({ url, size, sha512, dest, fetchImpl = fetch, onProgress = () => {}, timeoutMs = 30 * 60 * 1000 }) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  if (fs.existsSync(dest)) {  // already downloaded earlier (e.g. previous session)
    try { if (fs.statSync(dest).size === size && await sha512File(dest) === sha512) { onProgress(size, size); return dest; } } catch (e) {}
    try { fs.unlinkSync(dest); } catch (e) {}
  }
  const tmp = dest + '.part';
  const ac = new AbortController(); const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const r = await fetchImpl(url, { headers: { 'User-Agent': 'Kompass-Updater', 'Accept': 'application/octet-stream' }, signal: ac.signal });
    if (!r.ok || !r.body) throw new Error('HTTP ' + r.status + ' downloading update');
    const total = size || +r.headers.get('content-length') || 0;
    const out = fs.createWriteStream(tmp); const h = crypto.createHash('sha512'); let got = 0;
    const reader = r.body.getReader();
    for (;;) {
      const { done, value } = await reader.read(); if (done) break;
      const buf = Buffer.from(value); got += buf.length; h.update(buf);
      if (!out.write(buf)) await new Promise(res => out.once('drain', res));
      onProgress(got, total);
    }
    await new Promise((res, rej) => out.end(err => err ? rej(err) : res()));
    if (size && got !== size) throw new Error('size mismatch: got ' + got + ', expected ' + size);
    const digest = h.digest('base64');
    if (!sha512 || digest !== sha512) throw new Error('sha512 mismatch');
    fs.renameSync(tmp, dest);
    return dest;
  } catch (e) { try { fs.unlinkSync(tmp); } catch (x) {} throw e; }
  finally { clearTimeout(t); }
}

// Helper script that waits for Kompass (and the portable launcher) to exit, swaps the exe and relaunches.
function helperScript({ platform, newFile, target, relaunch, log }) {
  if (platform === 'win32') {
    const q = s => String(s).replace(/%/g, '%%');
    return [
      '@echo off', 'setlocal',
      `set "NEW=${q(newFile)}"`, `set "TARGET=${q(target)}"`, `set "LOG=${q(log)}"`, 'set /a N=0',
      'echo [%date% %time%] waiting for Kompass to exit >> "%LOG%"',
      ':retry',
      'ping -n 2 127.0.0.1 >nul',
      'copy /Y /B "%NEW%" "%TARGET%" >nul 2>&1',
      'if not errorlevel 1 goto done',
      'set /a N+=1',
      'if %N% LSS 180 goto retry',
      'echo [%date% %time%] gave up: exe still locked >> "%LOG%"',
      'goto end',
      ':done',
      'del /F /Q "%NEW%" >nul 2>&1',
      'echo [%date% %time%] updated %TARGET% >> "%LOG%"',
      relaunch ? 'start "" "%TARGET%"' : 'rem no relaunch',
      ':end',
      '(goto) 2>nul & del "%~f0"', ''].join('\r\n');
  }
  const sq = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
  return ['#!/bin/sh', `NEW=${sq(newFile)}`, `TARGET=${sq(target)}`, `LOG=${sq(log)}`, `PID=${'$'}1`,
    'n=0; while kill -0 "$PID" 2>/dev/null && [ $n -lt 180 ]; do sleep 0.5; n=$((n+1)); done',
    'cp -f "$NEW" "$TARGET.new" && chmod +x "$TARGET.new" && mv -f "$TARGET.new" "$TARGET" && rm -f "$NEW" && echo "updated $TARGET" >> "$LOG" || { echo "update failed" >> "$LOG"; exit 1; }',
    relaunch ? '"$TARGET" >/dev/null 2>&1 &' : ':', 'rm -f "$0"', ''].join('\n');
}

// Write + spawn the helper (detached). Caller should quit the app right after.
function applyUpdate({ newFile, target, relaunch = true, workDir, platform = process.platform, pid = process.pid, spawn = cp.spawn }) {
  const log = path.join(workDir, 'update.log');
  const script = path.join(workDir, platform === 'win32' ? 'kompass-update.cmd' : 'kompass-update.sh');
  fs.writeFileSync(script, helperScript({ platform, newFile, target, relaunch, log }), { mode: 0o755 });
  const child = platform === 'win32'
    ? spawn('cmd.exe', ['/d', '/c', script], { detached: true, stdio: 'ignore', windowsHide: true })
    : spawn('/bin/sh', [script, String(pid)], { detached: true, stdio: 'ignore' });
  child.unref();
  return script;
}

// Orchestrates periodic checks + state for the UI. env decides what kind of install we are.
class Updater {
  constructor({ current, workDir, settingsFile, env = process.env, platform = process.platform, apiUrl, fetchImpl = (...a) => fetch(...a), onState = () => {}, intervalMs = 4 * 3600 * 1000, spawn, log = () => {} }) {
    Object.assign(this, { current, workDir, settingsFile, platform, fetchImpl, onState, intervalMs, spawn, log });
    this.apiUrl = env.KOMPASS_UPDATE_API || apiUrl || DEFAULT_API;
    this.target = env.KOMPASS_UPDATE_TARGET || env.PORTABLE_EXECUTABLE_FILE || '';
    this.kind = this.target ? 'portable' : 'manual';  // zip / unpacked builds: we only point to the download
    this.settings = { autoUpdate: true };
    try { Object.assign(this.settings, JSON.parse(fs.readFileSync(settingsFile, 'utf8'))); } catch (e) {}
    this.state = { status: 'idle', current, latest: '', progress: 0, error: '', url: '', kind: this.kind, autoUpdate: this.settings.autoUpdate, checkedAt: 0 };
    this.timer = null; this.busy = null; this.ready = null;
  }
  set(p) { Object.assign(this.state, p); try { this.onState(Object.assign({}, this.state)); } catch (e) {} }
  setAuto(on) {
    this.settings.autoUpdate = !!on;
    try { fs.writeFileSync(this.settingsFile, JSON.stringify(this.settings)); } catch (e) {}
    this.set({ autoUpdate: !!on });
    if (on) this.start(); else this.stop();
  }
  start(firstDelayMs = 8000) {
    this.stop(); if (!this.settings.autoUpdate) return;
    this.first = setTimeout(() => this.check(false), firstDelayMs);
    this.timer = setInterval(() => this.check(false), this.intervalMs);
    if (this.timer.unref) { this.timer.unref(); this.first.unref(); }
  }
  stop() { clearTimeout(this.first); clearInterval(this.timer); this.timer = null; }
  // manual=true: user pressed "Check for updates" -> show errors; automatic checks stay silent
  check(manual) {
    if (this.busy) return this.busy;
    if (this.ready) return Promise.resolve(this.state);
    this.busy = (async () => {
      if (manual) this.set({ status: 'checking', error: '' });
      try {
        const info = await checkLatest({ current: this.current, apiUrl: this.apiUrl, fetchImpl: this.fetchImpl, kind: 'portable' });
        this.state.checkedAt = Date.now();
        if (!info) { if (manual) this.set({ status: 'uptodate' }); return this.state; }
        if (this.kind !== 'portable' || !info.asset) { this.set({ status: 'available', latest: info.version, url: info.url }); return this.state; }
        this.set({ status: 'downloading', latest: info.version, url: info.url, progress: 0 });
        const dest = path.join(this.workDir, 'Kompass-' + info.version + '-portable.exe.update');
        let last = 0;
        await download({ url: info.asset.url, size: info.asset.size, sha512: info.asset.sha512, dest, fetchImpl: this.fetchImpl,
          onProgress: (g, t) => { const p = t ? Math.floor(g * 100 / t) : 0; if (p !== last) { last = p; this.set({ progress: p }); } } });
        this.ready = { file: dest, version: info.version };
        this.set({ status: 'ready', progress: 100 });
      } catch (e) {
        this.log('[updater] ' + (e && e.message || e));
        if (manual) this.set({ status: 'error', error: String(e && e.message || e) });
        else if (this.state.status === 'downloading') this.set({ status: 'idle' });  // silent: try again next time
      } finally { this.busy = null; }
      return this.state;
    })();
    return this.busy;
  }
  // relaunch=true for "Restart to update"; false when the app is simply quitting with an update pending
  install(relaunch = true) {
    if (!this.ready || !this.target) return false;
    applyUpdate({ newFile: this.ready.file, target: this.target, relaunch, workDir: this.workDir, platform: this.platform, spawn: this.spawn });
    this.ready = null; this.set({ status: 'installing' });
    return true;
  }
}

module.exports = { compareVersions, parseVer, checkLatest, download, helperScript, applyUpdate, sha512File, Updater, DEFAULT_API, MANIFEST };
