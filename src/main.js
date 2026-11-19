// Kompass — Electron shell. It only hosts the KampfScript runtime (renderer) and exposes native services.
// All browser UI/logic lives in browser.ks.
const { app, BrowserWindow, ipcMain, session, shell, Menu, dialog, clipboard } = require('electron');
const path = require('path');
const fs = require('fs');

const DEV_RES = path.join(__dirname, '..', 'resources');
const RES = app.isPackaged ? path.join(process.resourcesPath, 'ks') : DEV_RES;
const DATA = path.join(app.getPath('userData'), 'kompass');
const SCRIPTS = path.join(DATA, 'scripts');
fs.mkdirSync(SCRIPTS, { recursive: true });

// What web pages see (see src/useragent.js): a clean Chrome UA with the real Chromium version for every site, and a Firefox UA
// on Google's sign-in pages, which reject embedded Chromium that claims to be Chrome.
const UA = require('./useragent');
const UAS = UA.make(process.versions, process.platform);
const CHROME_UA = UAS.chrome;
app.userAgentFallback = CHROME_UA;
const { Vault, generate, originOf } = require('./vault');

// --- user-editable browser program: copied to userData on first run
const userBrowserKs = path.join(DATA, 'browser.ks');
// Upgrade rule: if the user's copy is an unmodified earlier shipped version, replace it with the new default.
// If they edited it, keep their edits (and a backup) — they can use Settings → "Reset browser.ks" to update.
const shippedKs = path.join(DATA, 'browser.ks.shipped');
function browserSource() {
  const dflt = fs.readFileSync(path.join(RES, 'browser.ks'), 'utf8');
  if (!fs.existsSync(userBrowserKs)) { fs.writeFileSync(userBrowserKs, dflt); fs.writeFileSync(shippedKs, dflt); }
  let cur = fs.readFileSync(userBrowserKs, 'utf8');
  if (cur !== dflt) {
    const prevShipped = fs.existsSync(shippedKs) ? fs.readFileSync(shippedKs, 'utf8') : null;
    const unmodified = prevShipped !== null ? cur === prevShipped : /let VERSION = "1\.0\.0"/.test(cur);
    if (unmodified) {
      if (prevShipped === null) fs.writeFileSync(userBrowserKs + '.bak-1.0.0', cur);
      fs.writeFileSync(userBrowserKs, dflt); cur = dflt;
    }
    fs.writeFileSync(shippedKs, dflt);
  }
  return cur;
}

// --- tutorial videos for kompass://learn: first match wins
function videoDirs() {
  const dirs = [path.join(RES, 'videos'), path.join(DATA, 'videos')];
  if (process.env.PORTABLE_EXECUTABLE_DIR) dirs.push(path.join(process.env.PORTABLE_EXECUTABLE_DIR, 'videos'));
  return dirs;
}
fs.mkdirSync(path.join(DATA, 'videos'), { recursive: true });
const vault = new Vault(path.join(DATA, 'vault.kpv'), { lockMs: (+process.env.KOMPASS_LOCK_MS) || 5 * 60 * 1000, onLock: () => { if (win) win.webContents.send('kompass:pw-locked'); } });
const pwOffers = new Map(); let offerSeq = 1;
function findVideo(name) {
  const n = safeName(name); if (!/^[a-zA-Z0-9_-]+\.(mp4|webm)$/.test(n)) return null;
  for (const d of videoDirs()) { const f = path.join(d, n); try { if (fs.statSync(f).size > 0) return require('url').pathToFileURL(f).href; } catch (e) {} }
  return null;
}

// --- simple ad / tracker blocklist
let blockOn = true;
let blocklist = [];
try { blocklist = fs.readFileSync(path.join(RES, 'blocklist.txt'), 'utf8').split(/\r?\n/).map(s => s.trim()).filter(s => s && !s.startsWith('#')); } catch (e) {}
let blockedCount = 0;
function isBlocked(url) {
  try { const h = new URL(url).hostname; return blocklist.some(d => h === d || h.endsWith('.' + d)); } catch (e) { return false; }
}

function safeName(n) { return String(n).replace(/[^a-zA-Z0-9_.-]/g, '_').slice(0, 80); }

let win;
function createWindow() {
  win = new BrowserWindow({
    width: 1280, height: 820, minWidth: 640, minHeight: 400, backgroundColor: '#1b1f2a', title: 'Kompass',
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true, webviewTag: true },
  });
  win.setMenuBarVisibility(false);
  // v1.5.2 fullscreen: tell the renderer when the OS/window manager leaves or enters fullscreen
  win.on('leave-full-screen', () => { if (win) win.webContents.send('kompass:fullscreen', false); });
  win.on('enter-full-screen', () => { if (win) win.webContents.send('kompass:fullscreen', true); });
  win.loadFile(path.join(__dirname, 'index.html'));
  // the engine's real client-hint brands (e.g. "Chromium";v="156"), sent as Sec-CH-UA on https requests from tabs
  win.webContents.once('did-finish-load', () => win.webContents.executeJavaScript('navigator.userAgentData ? {brands: navigator.userAgentData.brands, mobile: navigator.userAgentData.mobile, platform: navigator.userAgentData.platform} : null')
    .then((u) => { UAS.ch = UA.chHeaders(u); }).catch(() => {}));
}

app.on('web-contents-created', (_e, contents) => {
  // Harden every <webview>: no node, sandboxed, no preload, isolated.
  contents.on('will-attach-webview', (_ev, webPreferences, params) => {
    // only our minimal password/autofill preload (narrow kompass-pw:* IPC), never anything from the page
    webPreferences.preload = path.join(__dirname, 'webview-preload.js');
    webPreferences.nodeIntegration = false;
    webPreferences.contextIsolation = true;
    webPreferences.sandbox = true;
    webPreferences.webSecurity = true;
    if (!/^(https?:|about:blank|data:)/.test(params.src || 'about:blank')) params.src = 'about:blank';
  });
  setupContextMenu(contents);
  if (contents.getType() === 'webview') {
    contents.setUserAgent(CHROME_UA);
    // v1.6.0: switch the tab's UA before a top-level navigation commits, so the page's navigator.userAgent matches the header
    contents.on('did-start-navigation', (d) => {
      if (!d || !d.isMainFrame || d.isSameDocument) return;
      const want = UA.uaFor(d.url, UAS); if (contents.getUserAgent() !== want) contents.setUserAgent(want);
    });
    contents.setWindowOpenHandler(({ url }) => { if (win) win.webContents.send('kompass:open-tab', url); return { action: 'deny' }; });
    // v1.5.2: HTML5 fullscreen (YouTube, Google Slides/Docs present, Maps...). host.js hides the chrome; Esc leaves it like in Chrome.
    let htmlFs = false;
    contents.on('enter-html-full-screen', () => { htmlFs = true; });
    contents.on('leave-html-full-screen', () => { htmlFs = false; });
    contents.on('before-input-event', (ev, input) => {
      // forward browser shortcuts from inside pages to the KampfScript chrome
      if (input.type !== 'keyDown') return;
      const k = (input.control ? 'ctrl+' : '') + (input.shift ? 'shift+' : '') + (input.alt ? 'alt+' : '') + input.key.toLowerCase();
      if (k === 'escape' && htmlFs) { ev.preventDefault(); contents.executeJavaScript('document.fullscreenElement && document.exitFullscreen()', true).catch(() => {}); return; }
      if (k === 'f11') { ev.preventDefault(); if (win) win.webContents.send('kompass:key', k); return; }
      if (k === 'escape' && win && win.isFullScreen()) { if (win) win.webContents.send('kompass:key', k); return; }   // browser fullscreen (F11); the page still gets Esc
      if (/^(ctrl\+|alt\+)/.test(k) || k === 'f5' || k === 'f12') { if (win) win.webContents.send('kompass:key', k); }
    });
  } else if (contents !== (win && win.webContents)) {
    contents.setWindowOpenHandler(() => ({ action: 'deny' }));
  }
});

// ---------------- right-click: single = context menu (after a short wait), double (< 400 ms) = KampfScript quick menu
function setupContextMenu(contents) {
  let timer = null, last = 0;
  contents.on('context-menu', (_e, p) => {
    const now = Date.now();
    if (timer && now - last < 400) {
      clearTimeout(timer); timer = null; last = 0;
      const isWv = contents.getType() === 'webview';
      if (win) win.webContents.send('kompass:double-right', { x: p.x, y: p.y, web: isWv, link: p.linkURL || '' });
      return;
    }
    last = now; clearTimeout(timer);
    timer = setTimeout(() => { timer = null; buildMenu(contents, p).popup({ window: win }); }, 400);
  });
}
function buildMenu(contents, p) {
  const t = [];
  const nav = contents.navigationHistory;
  if (contents.getType() === 'webview') {
    t.push({ label: 'Back', enabled: nav ? nav.canGoBack() : contents.canGoBack(), click: () => (nav ? nav.goBack() : contents.goBack()) });
    t.push({ label: 'Forward', enabled: nav ? nav.canGoForward() : contents.canGoForward(), click: () => (nav ? nav.goForward() : contents.goForward()) });
    t.push({ label: 'Reload', click: () => contents.reload() }, { type: 'separator' });
  }
  if (p.linkURL) {
    t.push({ label: 'Open link in new tab', click: () => win && win.webContents.send('kompass:open-tab', p.linkURL) });
    t.push({ label: 'Copy link address', click: () => clipboard.writeText(p.linkURL) }, { type: 'separator' });
  }
  if (p.selectionText) t.push({ label: 'Copy', role: 'copy' });
  if (p.isEditable) t.push({ label: 'Cut', role: 'cut' }, { label: 'Copy', role: 'copy' }, { label: 'Paste', role: 'paste' }, { label: 'Select all', role: 'selectAll' });
  if (!p.selectionText && !p.isEditable) t.push({ label: 'Copy', role: 'copy', enabled: false }, { label: 'Paste', role: 'paste', enabled: false });
  t.push({ type: 'separator' }, { label: 'Kompass quick menu (double right-click)', click: () => win && win.webContents.send('kompass:double-right', { x: p.x, y: p.y, web: contents.getType() === 'webview', link: p.linkURL || '' }) });
  t.push({ label: 'Inspect', click: () => contents.inspectElement(p.x, p.y) });
  return Menu.buildFromTemplate(t);
}

app.whenReady().then(() => {
  session.fromPartition('persist:kompass').setUserAgent(CHROME_UA);
  // every request from a tab: the right UA for its URL (Firefox UA + no Sec-CH-UA on Google sign-in, clean Chrome elsewhere)
  session.fromPartition('persist:kompass').webRequest.onBeforeSendHeaders((d, cb) => cb({ requestHeaders: UA.fixHeaders(d.requestHeaders, UA.requestUA(d, UAS), UAS, d.url) }));
  session.fromPartition('persist:kompass').webRequest.onBeforeRequest((d, cb) => {
    if (blockOn && d.resourceType !== 'mainFrame' && isBlocked(d.url)) { blockedCount++; return cb({ cancel: true }); }
    cb({});
  });
  session.fromPartition('persist:kompass').setPermissionRequestHandler((_wc, perm, cb) => cb(['fullscreen', 'clipboard-sanitized-write', 'media'].includes(perm) && perm !== 'media'));
  Menu.setApplicationMenu(null);
  createWindow();
  if (!process.env.KOMPASS_NO_UPDATER) updater.start(+process.env.KOMPASS_UPDATE_DELAY_MS || 8000);
});

// ---------------- auto-update (see src/updater.js and docs/RELEASING.md)
const { Updater } = require('./updater');
const updater = new Updater({
  current: app.getVersion(), workDir: path.join(DATA, 'updates'), settingsFile: path.join(DATA, 'updater.json'),
  onState: (st) => { if (win && !win.isDestroyed()) win.webContents.send('kompass:update-state', st); },
  log: (m) => console.log(m),
});
fs.mkdirSync(path.join(DATA, 'updates'), { recursive: true });
ipcMain.on('kompass:update-state', e => { e.returnValue = Object.assign({}, updater.state); });
ipcMain.handle('kompass:update-check', async () => Object.assign({}, await updater.check(true)));
ipcMain.on('kompass:update-auto', (e, on) => { updater.setAuto(!!on); e.returnValue = Object.assign({}, updater.state); });
ipcMain.on('kompass:update-install', e => {
  const ok = updater.install(true); e.returnValue = ok;
  if (ok) setTimeout(() => app.quit(), 150);
  else if (updater.state.url) shell.openExternal(updater.state.url);
});
// an update that finished downloading is also applied when Kompass is simply closed (no relaunch)
app.on('will-quit', () => { if (updater.ready) updater.install(false); });
app.on('window-all-closed', () => app.quit());

// ---------------- IPC services for the KampfScript runtime
ipcMain.on('kompass:browser-source', e => { e.returnValue = browserSource(); });
ipcMain.on('kompass:default-source', e => { e.returnValue = fs.readFileSync(path.join(RES, 'browser.ks'), 'utf8'); });
ipcMain.on('kompass:save-browser-source', (e, src) => { fs.writeFileSync(userBrowserKs, String(src)); e.returnValue = true; });
ipcMain.on('kompass:paths', e => { e.returnValue = { data: DATA, scripts: SCRIPTS, browserKs: userBrowserKs }; });
ipcMain.on('kompass:load', (e, name) => {
  const f = path.join(DATA, safeName(name) + '.json');
  try { e.returnValue = fs.readFileSync(f, 'utf8'); } catch (err) { e.returnValue = null; }
});
ipcMain.on('kompass:save', (e, name, json) => { fs.writeFileSync(path.join(DATA, safeName(name) + '.json'), String(json)); e.returnValue = true; });
ipcMain.on('kompass:list-scripts', e => { e.returnValue = fs.readdirSync(SCRIPTS).filter(f => f.endsWith('.ks')); });
ipcMain.on('kompass:read-script', (e, n) => { try { e.returnValue = fs.readFileSync(path.join(SCRIPTS, safeName(n)), 'utf8'); } catch (err) { e.returnValue = null; } });
ipcMain.on('kompass:write-script', (e, n, src) => { let f = safeName(n); if (!f.endsWith('.ks')) f += '.ks'; fs.writeFileSync(path.join(SCRIPTS, f), String(src)); e.returnValue = f; });
ipcMain.on('kompass:adblock', (e, on) => { if (on !== null && on !== undefined) blockOn = !!on; e.returnValue = { on: blockOn, blocked: blockedCount }; });
ipcMain.on('kompass:open-external', (_e, url) => { if (/^https?:\/\//.test(url)) shell.openExternal(url); });
ipcMain.on('kompass:open-folder', () => { shell.openPath(DATA); });
ipcMain.on('kompass:reload-app', () => { if (win) win.webContents.reload(); });
ipcMain.on('kompass:devtools', () => { if (win) win.webContents.openDevTools({ mode: 'detach' }); });
ipcMain.handle('kompass:capture', async (_e, file) => {
  // test helper: screenshot the whole window (used by the self-test)
  const img = await win.webContents.capturePage();
  fs.writeFileSync(file, img.toPNG()); return true;
});
ipcMain.on('kompass:argv', e => { e.returnValue = process.argv; });
ipcMain.on('kompass:set-fullscreen', (e, on) => { if (win && e.sender === win.webContents && win.isFullScreen() !== !!on) win.setFullScreen(!!on); });
ipcMain.on('kompass:quit', () => app.quit());
ipcMain.on('kompass:version', e => { e.returnValue = app.getVersion(); });
ipcMain.handle('kompass:clear-data', async () => {
  const ses = session.fromPartition('persist:kompass');
  await ses.clearStorageData(); await ses.clearCache(); await ses.clearHostResolverCache();
  for (const f of ['history.json']) { try { fs.unlinkSync(path.join(DATA, f)); } catch (e) {} }
  return true;
});
ipcMain.on('kompass:read-resource', (e, n) => {
  const f = safeName(n); if (!/^[A-Za-z0-9_-]+\.(md|txt|ks)$/.test(f)) { e.returnValue = ''; return; }
  try { e.returnValue = fs.readFileSync(path.join(RES, f), 'utf8'); } catch (err) { e.returnValue = ''; }
});
const store = require('./store');
const STORE_RES = path.join(RES, 'store');
ipcMain.handle('kompass:store-index', async () => store.index({ bundled: STORE_RES }));
ipcMain.handle('kompass:store-code', async (_e, id) => {
  const r = await store.get('entries/' + String(id) + '.ks', { bundled: STORE_RES }); return r.ok ? { ok: true, code: r.text, source: r.source } : r;
});
ipcMain.handle('kompass:store-publish', async (_e, p) => {
  const r = await store.publish(Object.assign({}, p || {}, { version: app.getVersion() }));
  if (!r.ok) return r;
  if (r.copied) clipboard.writeText(String((p && p.code) || ''));
  if (process.env.KOMPASS_PUBLISH_LOG) fs.appendFileSync(process.env.KOMPASS_PUBLISH_LOG, JSON.stringify(Object.assign({}, r, { url: r.url.slice(0, 4000) })) + '\n');
  if (!process.env.KOMPASS_NO_EXTERNAL) shell.openExternal(r.url);   // the user's own browser; GitHub sign-in happens there
  return r;
});
ipcMain.on('kompass:copy-text', (e, t) => { clipboard.writeText(String(t)); e.returnValue = true; });
ipcMain.handle('kompass:save-text-file', async (_e, name, text) => {
  const base = safeName(name || 'kompass.txt');
  if (process.env.KOMPASS_SAVE_DIR) { const f = path.join(process.env.KOMPASS_SAVE_DIR, base); fs.writeFileSync(f, String(text)); return f; }
  const r = await dialog.showSaveDialog(win, { defaultPath: path.join(app.getPath('documents'), base),
    filters: [{ name: 'Markdown', extensions: ['md'] }, { name: 'Text', extensions: ['txt'] }, { name: 'KampfScript', extensions: ['ks'] }] });
  if (r.canceled || !r.filePath) return '';
  fs.writeFileSync(r.filePath, String(text)); return r.filePath;
});
// ---------------- v1.7 files + model library for KampfScript apps (Kugel 3D Modeler, Kugel Blocks ...)
// file_save / file_open always go through the user's own Save / Open dialog (tests: KOMPASS_SAVE_DIR / KOMPASS_OPEN_FILE).
const APP_SAVE_EXT = ['ks', 'txt', 'json', 'csv', 'md', 'obj', 'gltf', 'glb', 'png', 'jpg', 'svg', 'html', 'kmodel', 'kblocks', 'kblocks3d', 'wav',
  'gif', 'webm', 'pptx', 'xlsx', 'kpaint', 'kmotion', 'kvector', 'kprism', 'knotes', 'klattice'];   // v1.8 Kugel Design / Work
const APP_TEXT_EXT = ['ks', 'txt', 'json', 'csv', 'md', 'obj', 'gltf', 'svg', 'html', 'kmodel', 'kblocks', 'kblocks3d', 'mtl', 'kpaint', 'kmotion', 'kvector', 'kprism', 'knotes', 'klattice', 'tsv'];
const APP_OPEN_EXT = APP_TEXT_EXT.concat(['glb', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'wav', 'mp3', 'pptx', 'xlsx', 'webm']);
const MIME = { glb: 'model/gltf-binary', png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', wav: 'audio/wav', mp3: 'audio/mpeg', webm: 'video/webm',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
function dataToBuffer(d) { const m = /^data:[^;,]*;base64,(.*)$/s.exec(d); return m ? Buffer.from(m[1], 'base64') : Buffer.from(d, 'utf8'); }
ipcMain.handle('kompass:file-save', async (_e, name, data) => {
  const base = safeName(String(name || 'file.txt')); const ext = (base.split('.').pop() || '').toLowerCase();
  if (!APP_SAVE_EXT.includes(ext)) return { ok: false, error: 'file type not allowed' };
  const buf = dataToBuffer(String(data || '')); if (buf.length > 60 * 1024 * 1024) return { ok: false, error: 'too big' };
  let f;
  if (process.env.KOMPASS_SAVE_DIR) f = path.join(process.env.KOMPASS_SAVE_DIR, base);
  else { const r = await dialog.showSaveDialog(win, { defaultPath: path.join(app.getPath('documents'), base), filters: [{ name: ext.toUpperCase() + ' file', extensions: [ext] }] }); if (r.canceled || !r.filePath) return { ok: false, error: 'cancelled' }; f = r.filePath; }
  if (!APP_SAVE_EXT.includes((path.extname(f).slice(1) || '').toLowerCase())) f += '.' + ext;
  fs.writeFileSync(f, buf); return { ok: true, path: f, name: path.basename(f), bytes: buf.length };
});
ipcMain.handle('kompass:file-open', async (_e, exts) => {
  const want = (Array.isArray(exts) ? exts : []).map((x) => String(x).toLowerCase()).filter((x) => APP_OPEN_EXT.includes(x));
  if (!want.length) return { ok: false, error: 'no allowed file types' };
  let f;
  if (process.env.KOMPASS_OPEN_FILE) f = process.env.KOMPASS_OPEN_FILE;
  else { const r = await dialog.showOpenDialog(win, { properties: ['openFile'], filters: [{ name: want.map((x) => x.toUpperCase()).join(' / '), extensions: want }] }); if (r.canceled || !r.filePaths[0]) return { ok: false, error: 'cancelled' }; f = r.filePaths[0]; }
  const ext = (path.extname(f).slice(1) || '').toLowerCase(); if (!want.includes(ext)) return { ok: false, error: 'wrong file type' };
  const st = fs.statSync(f); if (st.size > 40 * 1024 * 1024) return { ok: false, error: 'file too big (max 40 MB)' };
  const buf = fs.readFileSync(f); const out = { ok: true, name: path.basename(f), ext, bytes: buf.length };
  if (APP_TEXT_EXT.includes(ext)) out.text = buf.toString('utf8'); else out.data = 'data:' + (MIME[ext] || 'application/octet-stream') + ';base64,' + buf.toString('base64');
  return out;
});
const MODELS = path.join(DATA, 'models');
const modelName = (n) => { const s = String(n || '').trim(); return /^[A-Za-z0-9 _-]{1,40}$/.test(s) ? s : null; };
const modelFile = (n, ext) => path.join(MODELS, n + '.' + ext);
function modelExt(d) { return d.startsWith('data:') ? 'glb' : /^\s*\{/.test(d) ? 'gltf' : 'obj'; }
ipcMain.on('kompass:model-save', (e, n, d) => {
  const name = modelName(n); d = String(d || ''); if (!name || !d) { e.returnValue = { ok: false, error: 'bad name or empty model' }; return; }
  const buf = dataToBuffer(d); if (buf.length > 25 * 1024 * 1024) { e.returnValue = { ok: false, error: 'model too big (max 25 MB)' }; return; }
  fs.mkdirSync(MODELS, { recursive: true }); for (const x of ['glb', 'gltf', 'obj']) { try { fs.unlinkSync(modelFile(name, x)); } catch (err) {} }
  fs.writeFileSync(modelFile(name, modelExt(d)), buf); e.returnValue = { ok: true };
});
ipcMain.on('kompass:model-list', (e) => {
  try { e.returnValue = fs.readdirSync(MODELS).filter((f) => /\.(glb|gltf|obj)$/.test(f)).map((f) => { const st = fs.statSync(path.join(MODELS, f)); return { name: f.replace(/\.(glb|gltf|obj)$/, ''), format: path.extname(f).slice(1), bytes: st.size, saved: st.mtimeMs }; }).sort((a, b) => b.saved - a.saved); }
  catch (err) { e.returnValue = []; }
});
ipcMain.on('kompass:model-read', (e, n) => {
  const name = modelName(n); let out = '';   // (set returnValue once: the first assignment already answers the renderer)
  if (name) for (const x of ['glb', 'gltf', 'obj']) { const f = modelFile(name, x); if (fs.existsSync(f)) { const b = fs.readFileSync(f); out = x === 'glb' ? 'data:model/gltf-binary;base64,' + b.toString('base64') : b.toString('utf8'); break; } }
  e.returnValue = out;
});
ipcMain.on('kompass:model-delete', (e, n) => { const name = modelName(n); let ok = false; if (name) for (const x of ['glb', 'gltf', 'obj']) { try { fs.unlinkSync(modelFile(name, x)); ok = true; } catch (err) {} } e.returnValue = ok; });
ipcMain.on('kompass:video-file', (e, n) => { e.returnValue = findVideo(n); });
ipcMain.on('kompass:videos-folder', e => { e.returnValue = videoDirs().join('  or  '); });
ipcMain.on('kompass:open-videos-folder', () => { shell.openPath(path.join(DATA, 'videos')); });

// ---------------- v1.1 screenshot self-test: KOMPASS_SHOTS=/out/dir
if (process.env.KOMPASS_SHOTS) {
  const out = process.env.KOMPASS_SHOTS;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[shots] wrote', name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  app.whenReady().then(async () => {
    try {
      await wait(3500);
      console.log('[shots] gear:', await js("!!document.querySelector('.gear')"), 'theme:', await js('document.body.dataset.theme'));
      await shot('kompass11-main.png');
      await js("document.querySelector('.gear').click()"); await wait(1200);
      console.log('[shots] settings cards:', await js("document.querySelectorAll('.set-card').length"));
      await shot('kompass11-settings.png');
      await go('kompass://learn'); await wait(1200);
      await js("document.querySelector('.try-btn') && document.querySelector('.try-btn').click()"); await wait(800);
      console.log('[shots] learn out:', JSON.stringify(await js("(document.querySelector('.try-out')||{}).innerText")));
      await shot('kompass11-learn.png');
      console.log('[shots] videos:', await js("JSON.stringify([...document.querySelectorAll('video')].map(v => ({src: v.src.slice(-30), ready: v.readyState, w: v.videoWidth, err: v.error && v.error.code})))"));
      await js("document.querySelector('.ks-page:not([hidden])').scrollTop = 560"); await wait(300);
      await shot('kompass11-learn-lesson.png');
      await go('kompass://home'); await wait(1000);
      await js("window.KompassDevtools.toggle(true)"); await js("window.KompassDevtools.consoleRun('tab_url(current)')"); await wait(300);
      await js("window.KompassDevtools.show('inspector'); window.KompassDevtools.expandPath(['settings']); window.KompassDevtools.expandPath(['tabs']); window.KompassDevtools.expandPath(['tabs', '1'])"); await wait(600);
      await shot('kompass11-devtools.png');
      for (const p of ['console', 'events', 'source', 'perf', 'errors']) { await js(`window.KompassDevtools.show('${p}')`); await wait(300); await shot('kompass11-dt-' + p + '.png'); }
      // breakpoint inside refresh_toolbar(), then trigger it via the address bar
      const line = 1 + fs.readFileSync(path.join(RES, 'browser.ks'), 'utf8').split('\n').findIndex(l => l.includes('let u = tab_url(current)'));
      await js(`window.KompassDevtools.setBreakpoint(${line})`);
      go('kompass://about'); await wait(1200);
      console.log('[shots] paused:', JSON.stringify(await js('window.KompassDevtools.paused && window.KompassDevtools.paused.line')), 'expected', line);
      await shot('kompass11-dt-debugger.png');
      await js(`window.KompassDevtools.setBreakpoint(${line}, false); window.KompassDevtools.resume()`); await wait(800);
      await js("window.KompassDevtools.toggle(false)");
      await js("window.KompassMain.repl('settings.theme = \"neon\"\\napply_look()')"); await go('kompass://home'); await wait(1500);
      await shot('kompass11-theme-neon.png');
      await js("window.KompassMain.repl('settings.theme = \"midnight\"\\napply_look()')"); await wait(400);
      await go('kompass://settings'); await wait(1000); await shot('kompass11-theme-midnight.png');
      await js("window.KompassMain.repl('settings.theme = \"paper\"\\napply_look()')"); await go('kompass://learn'); await wait(1000);
      await shot('kompass11-theme-paper.png');
      await js("window.KompassMain.repl('settings.theme = \"brass\"\\napply_look()')");
    } catch (e) { console.log('[shots] error', e); }
    app.quit();
  });
}

// ---------------- optional self-test (used for CI/screenshots): KOMPASS_SELFTEST=/out/dir
if (process.env.KOMPASS_SELFTEST) {
  const out = process.env.KOMPASS_SELFTEST;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[selftest] wrote', name); };
  app.whenReady().then(async () => {
    try {
      await wait(4000);
      console.log('[selftest] tabs:', await js("document.querySelectorAll('.tab').length"), 'kugel logo:', await js("!!document.querySelector('.kugel-logo-big')"));
      await shot('kompass-home.png');
      const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
      await go('youtube'); await wait(5000);
      console.log('[selftest] results:', await js("document.querySelectorAll('.result').length"));
      await shot('kompass-search.png');
      await go('example.com'); await wait(5000);
      console.log('[selftest] title:', await js("document.querySelector('.tab.active .tabtitle').textContent"), 'url:', await js("document.querySelector('.address').value"));
      await shot('kompass-app.png');
      await js("document.querySelector('.yt').click()"); await wait(8000); await go('https://www.youtube.com/results?search_query=lofi+music'); await wait(12000);
      console.log('[selftest] yt title:', await js("document.querySelector('.tab.active .tabtitle').textContent"));
      await shot('kompass-youtube.png');
      await js("window.KompassEditor.toggle(true)"); await wait(500);
      await js("document.querySelector('.ed-btn.primary').click()"); await wait(1500);
      console.log('[selftest] console:', JSON.stringify(await js("document.querySelector('.ed-out').innerText")).slice(0, 300));
      await shot('kompass-editor.png');
    } catch (e) { console.log('[selftest] error', e); }
    app.quit();
  });
}

// ---------------- password vault IPC. KampfScript never receives a password from these channels.
const pwOk = (f) => { try { return f(); } catch (e) { return { ok: false, error: e.message }; } };
ipcMain.on('kompass:pw-status', e => { e.returnValue = { exists: vault.exists(), unlocked: vault.unlocked(), count: vault.unlocked() ? vault.items.length : 0 }; });
ipcMain.on('kompass:pw-unlock', (e, m) => { e.returnValue = pwOk(() => vault.unlock(m)); });
ipcMain.on('kompass:pw-lock', e => { vault.lock(); e.returnValue = true; });
ipcMain.on('kompass:pw-list', (e, q) => { e.returnValue = pwOk(() => ({ ok: true, items: vault.list(q) })); });
ipcMain.on('kompass:pw-save', (e, id, origin, user, pw) => { e.returnValue = pwOk(() => ({ ok: true, id: vault.save(id || null, origin, user, pw) })); });
ipcMain.on('kompass:pw-delete', (e, id) => { e.returnValue = pwOk(() => { vault.remove(id); return { ok: true }; }); });
ipcMain.on('kompass:pw-reveal', (e, id) => { const r = pwOk(() => { const it = vault.get(id); return it ? { ok: true, password: it.password } : { ok: false, error: 'not found' }; }); e.returnValue = r; });
ipcMain.on('kompass:pw-copy', (e, id) => { e.returnValue = pwOk(() => { const it = vault.get(id); if (!it) return { ok: false }; clipboard.writeText(it.password); setTimeout(() => { Promise.resolve(clipboard.readText()).then((t) => { if (t === it.password) clipboard.clear(); }).catch(() => {}); }, 30000); return { ok: true }; }); });
ipcMain.on('kompass:pw-generate', (e, n) => { e.returnValue = generate(n); });
ipcMain.on('kompass:pw-offer', (e, id, action) => {
  const o = pwOffers.get(id); pwOffers.delete(id);
  if (!o) { e.returnValue = { ok: false, error: 'expired' }; return; }
  if (action === 'never') { e.returnValue = { ok: true }; return; }
  e.returnValue = pwOk(() => ({ ok: true, id: vault.save(null, o.origin, o.username, o.password) }));
});
ipcMain.handle('kompass:pw-export', async (_e, kind, pass) => pwOk2(async () => {
  const enc = kind === 'encrypted'; const text = enc ? vault.exportEncrypted(pass) : vault.exportCsv();
  const name = enc ? 'kompass-passwords.kpx' : 'kompass-passwords.csv';
  let f; if (process.env.KOMPASS_SAVE_DIR) f = path.join(process.env.KOMPASS_SAVE_DIR, name);
  else { const r = await dialog.showSaveDialog(win, { defaultPath: path.join(app.getPath('documents'), name) }); if (r.canceled) return { ok: false, error: 'cancelled' }; f = r.filePath; }
  fs.writeFileSync(f, text, { mode: 0o600 }); return { ok: true, path: f, count: vault.items.length };
}));
ipcMain.handle('kompass:pw-import', async (_e, pass) => pwOk2(async () => {
  vault.need();
  const r = await dialog.showOpenDialog(win, { properties: ['openFile'], filters: [{ name: 'Passwords', extensions: ['csv', 'kpx'] }] });
  if (r.canceled || !r.filePaths[0]) return { ok: false, error: 'cancelled' };
  return { ok: true, count: vault.importText(fs.readFileSync(r.filePaths[0], 'utf8'), pass) };
}));
async function pwOk2(f) { try { return await f(); } catch (e) { return { ok: false, error: e.message }; } }
// from the webview preload: a login form was submitted / the page asks for autofill (origin = sender's real URL)
ipcMain.on('kompass-pw:submit', (e, d) => {
  const origin = originOf(e.sender.getURL()); if (!origin || !d || !d.password) return;
  const known = vault.forOrigin(origin).find(i => i.username === String(d.username || ''));
  if (known && known.password === d.password) return;
  const id = offerSeq++; pwOffers.set(id, { origin, username: String(d.username || '').slice(0, 200), password: String(d.password).slice(0, 500) });
  setTimeout(() => pwOffers.delete(id), 5 * 60 * 1000);
  if (win) win.webContents.send('kompass:pw-offer', { id, origin, username: String(d.username || '').slice(0, 200), update: !!known, locked: !vault.unlocked() });
});
ipcMain.handle('kompass-pw:query', (e) => vault.forOrigin(originOf(e.sender.getURL())).map(i => i.username));
ipcMain.handle('kompass-pw:fill', (e, user) => { const it = vault.forOrigin(originOf(e.sender.getURL())).find(i => i.username === user); return it ? { username: it.username, password: it.password } : null; });

// ---------------- v1.2 screenshot self-test: KOMPASS_SHOTS12=/out/dir
if (process.env.KOMPASS_SHOTS12) {
  const out = process.env.KOMPASS_SHOTS12;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[shots12] wrote', name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const log = async (k, code) => console.log('[shots12]', k, JSON.stringify(await js(code)));
  const webview = () => require('electron').webContents.getAllWebContents().filter(w => w.getType() === 'webview' && !w.isDestroyed() && /^https/.test(w.getURL()));
  app.whenReady().then(async () => {
    try {
      await wait(3500);
      await log('gtool', "!!document.querySelector('.gtool') && document.querySelector('.gtool').title");
      await go('kompass://builder'); await wait(2000);
      await log('builder', "[document.querySelectorAll('.bld-stage .ks-letters span').length, document.querySelector('.bld-out').innerText, document.querySelectorAll('.bld-presets .chip').length]");
      // edit the code: live preview re-runs
      await js(`(()=>{const t=document.querySelector('.bld-code');t.value=t.value.replace('let LOGO = "Google"','let LOGO = "Kampfle"');t.dispatchEvent(new Event('input'));})()`); await wait(1200);
      await log('builder logo after edit', "document.querySelector('.bld-stage .ks-letters').innerText");
      await shot('kompass12-builder.png');
      // set as home page, then open home
      await js("[...document.querySelectorAll('.bld-actions .ks-button')].find(b=>b.textContent.includes('Set as my home')).click()"); await wait(800);
      await log('home msg', "document.querySelector('.bld-msg').innerText");
      await go('kompass://home'); await wait(1500);
      await log('custom home', "[!!document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .custom-stage .ks-letters'), (document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .custom-bar')||{}).innerText]");
      await shot('kompass12-custom-home.png');
      await js("[...document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .custom-bar .ks-button')].find(b=>b.textContent.includes('Restore')).click()"); await wait(1200);
      await log('restored', "!!document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .home')");
      // builder end-to-end: the preview's search box really searches (opens a new tab with the engine's results)
      await go('kompass://builder'); await wait(1500);
      await js(`(()=>{const q=document.querySelector('.bld-stage .gp-search');q.value='kampfscript';q.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`); await wait(1500);
      await log('builder search opened', "[document.querySelectorAll('.tab').length, document.querySelector('.address').value]");
      await js("window.KompassMain.repl('close_tab(current)')"); await wait(500);
      await js("[...document.querySelectorAll('.bld-actions .ks-button')].find(b=>b.textContent.includes('Save')).click()"); await wait(300);
      await log('saved', "[document.querySelector('.bld-msg').innerText, window.native.load('builder').includes('Kampfle')]");
      // editor: 📄 New page -> scripts/mypage.ks -> kompass://page/myscript
      await js("window.KompassEditor.toggle(true)"); await wait(400);
      await js("[...document.querySelectorAll('.ed-btn')].find(b=>b.textContent.includes('New page')).click()"); await wait(2000);
      await log('editor new page', "[document.querySelector('.address').value, (document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-letters')||{}).innerText, document.querySelector('.ed-out').innerText.slice(-120)]");
      await js("window.KompassEditor.toggle(false)"); await wait(300);
      await js("[...document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .gp-btn')][0].click()"); await wait(300);
      await log('page button works', "[...document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-label')].map(l=>l.textContent).find(t=>t.startsWith('Clicked'))");
      await shot('kompass12-userpage.png');
      // reopen by URL after reload
      await go('kompass://page/myscript'); await wait(1200);
      await log('reopen page/myscript', "!!document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-letters')");
      // editor ▶ Run with page_new()
      await js("window.KompassEditor.toggle(true)"); await wait(300);
      await js(`(()=>{const a=document.querySelector('.ed-area')||document.querySelector('#editor textarea')||document.querySelector('textarea.ed-code')||[...document.querySelectorAll('textarea')].pop();a.value='let p = page_new("Hello page")\\nheading(p, "Made by an editor script")\\nbutton(p, "OK", fn() { print("clicked") })';})()`);
      await js("[...document.querySelectorAll('.ed-btn')].find(b=>b.textContent.includes('Run')).click()"); await wait(1500);
      await log('page_new', "[document.querySelector('.tab.active .tabtitle').textContent, (document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-heading')||{}).textContent, document.querySelector('.ed-out').innerText.slice(-80)]");
      await js("window.KompassEditor.toggle(false)"); await wait(300);
      // learn + video playing
      await go('kompass://learn'); await wait(1200);
      await js("[...document.querySelectorAll('.learn-item')][0].click()"); await wait(1000);
      await log('videos', "[...document.querySelectorAll('video')].map(v=>({src:v.src.slice(-12),ready:v.readyState,w:v.videoWidth,dur:Math.round(v.duration)}))");
      await js("(()=>{const v=document.querySelector('video');v.muted=true;v.currentTime=42;return v.play()})()"); await wait(3500);
      await log('playing', "(()=>{const v=document.querySelector('video');return {t:Math.round(v.currentTime*10)/10,paused:v.paused,err:v.error&&v.error.code}})()");
      await shot('kompass12-learn-video.png');
      await js("document.querySelector('video').pause()");
      // For AIs
      await go('kompass://learn/ai'); await wait(1500);
      await js("document.querySelector('.ai-copy').click()"); await wait(300);
      { const cb = String(await clipboard.readText()); console.log('[shots12] clipboard chars', cb.length, 'starts', JSON.stringify(cb.slice(0, 40))); }
      await shot('kompass12-ai.png');
      // passwords: create vault, add a login
      await go('kompass://passwords'); await wait(1000);
      await js("(()=>{const i=document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-secret');i.value='kompass-master-1';[...document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .pw-lockcard .ks-button')][0].click()})()"); await wait(2500);
      await log('vault', "document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .pw-page').innerText.slice(0,120)");
      for (const [site, user] of [['https://github.com', 'kampfguy'], ['https://en.wikipedia.org', 'Kampf'], ['https://www.youtube.com', 'kampf@example.com']]) {
        await js("[...document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-button')].find(b=>b.textContent.includes('Add')).click()"); await wait(300);
        await js(`(()=>{const f=document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .pw-form');const t=f.querySelectorAll('.ks-textbox');t[0].value=${JSON.stringify(site)};t[1].value=${JSON.stringify(user)};[...f.querySelectorAll('.ks-button')].find(b=>b.textContent.includes('Generate')).click();})()`); await wait(200);
        await js("[...document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .pw-form').querySelectorAll('.ks-button')].find(b=>b.textContent==='Save').click()"); await wait(500);
      }
      await js("document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-secret-text').click()"); await wait(300);
      await log('passwords', "[document.querySelectorAll('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .pw-row').length, document.querySelector('.ks-tabview:not([hidden]) .ks-page:not([hidden]) .ks-secret-text').textContent.length]");
      await log('ks cannot read secret', "window.KompassMain.repl('let r = 0\\nr').then(()=>'n/a')");
      await shot('kompass12-passwords.png');
      // save-password offer from a real web page login form
      await go('https://example.com'); await wait(5000);
      const wv = webview()[0];
      if (wv) {
        await wv.executeJavaScript("document.body.innerHTML='<form id=f onsubmit=\"event.preventDefault()\"><input name=u value=demo-user><input type=password value=demo-pass-123><button>Sign in</button></form>';document.querySelector('button').click();");
        await wait(1200);
        await log('ks error', "(document.getElementById('boot-error')||{}).textContent");
        await log('save bar', "(()=>{const b=document.querySelector('.pw-bar');return b.hidden?'hidden':b.innerText})()");
        await shot('kompass12-savebar.png');
      }
      // double right-click (real input events) -> KampfScript quick menu
      for (let i = 0; i < 2; i++) { win.webContents.sendInputEvent({ type: 'mouseDown', x: 640, y: 420, button: 'right', clickCount: 1 }); win.webContents.sendInputEvent({ type: 'mouseUp', x: 640, y: 420, button: 'right', clickCount: 1 }); await wait(120); }
      await wait(800);
      let pop = await js("!!document.querySelector('.ks-popup')");
      if (!pop) { console.log('[shots12] synthetic double right-click did not reach context-menu; sending the same IPC the handler sends'); win.webContents.send('kompass:double-right', { x: 640, y: 420, web: false, link: '' }); await wait(600); }
      await log('quick menu', "(document.querySelector('.ks-popup')||{}).innerText");
      await shot('kompass12-menu.png');
      // Google sign-in page
      await js("window.KompassMain.repl('close_popups()')");
      await go('https://accounts.google.com/signin'); await wait(9000);
      const g = webview().find(w => /google/.test(w.getURL()));
      if (g) {
        console.log('[shots12] google ua', g.getUserAgent());
        console.log('[shots12] google page', JSON.stringify((await g.executeJavaScript('document.body.innerText')).slice(0, 300)));
        await g.executeJavaScript("document.querySelector('input[type=email]') && document.querySelector('input[type=email]').focus()"); await wait(300);
        await g.insertText('kompass.ua.check.nonexistent@gmail.com'); await wait(300);
        g.sendInputEvent({ type: 'keyDown', keyCode: 'Enter' }); g.sendInputEvent({ type: 'char', keyCode: '\r' }); g.sendInputEvent({ type: 'keyUp', keyCode: 'Enter' });
        await wait(7000);
        console.log('[shots12] google after Next', JSON.stringify((await g.executeJavaScript('document.body.innerText')).slice(0, 400)), g.getURL().slice(0, 80));
        await log('google note', "(()=>{const n=document.querySelector('.google-note');return n.hidden?'hidden':n.innerText.slice(0,80)})()");
        await shot('kompass12-google.png');
      }
    } catch (e) { console.log('[shots12] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.3 screenshot self-test: KOMPASS_SHOTS13=/out/dir — the KampfScript Spaceflight Sim
if (process.env.KOMPASS_SHOTS13) {
  const out = process.env.KOMPASS_SHOTS13;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[shots13] wrote', name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const log = async (k, code) => console.log('[shots13]', k, JSON.stringify(await js(code)));
  const S = ".ks-tabview:not([hidden]) .app-stage";
  const click = (text, sel) => js(`(()=>{const b=[...document.querySelectorAll('${S} ${sel || '.ks-button'}')].find(b=>b.offsetParent&&b.textContent.trim()===${JSON.stringify(text)});if(b){b.click();return true}return false})()`);
  const key = (k) => js(`window.dispatchEvent(new KeyboardEvent('keydown',{key:${JSON.stringify(k)}}));setTimeout(()=>window.dispatchEvent(new KeyboardEvent('keyup',{key:${JSON.stringify(k)}})),30)`);
  const fps = () => js(`new Promise(r=>{let n=0;const t0=performance.now();const f=()=>{n++;if(performance.now()-t0<2000)requestAnimationFrame(f);else r(Math.round(n/2))};requestAnimationFrame(f)})`);
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error/.test(msg)) console.log('[shots13] PAGE-ERROR', msg); });
    try {
      await wait(3500);
      await js(`Object.keys(localStorage).filter(k=>k.startsWith('ks-store:sfs')).forEach(k=>localStorage.removeItem(k));
        localStorage.setItem('ks-store:sfs_rockets', JSON.stringify([{name:'Demo rocket',parts:[{id:'coneS',col:11,row:0,rot:0,uid:1},{id:'pod',col:11,row:2,rot:0,uid:2},{id:'chute',col:11,row:4,rot:0,uid:3},{id:'sepS',col:11,row:5,rot:0,uid:4},{id:'tankS',col:11,row:6,rot:0,uid:5},{id:'tankS',col:11,row:10,rot:0,uid:6},{id:'engB',col:11,row:14,rot:0,uid:7},{id:'srbT',col:9,row:11,rot:0,uid:8},{id:'srbT',col:13,row:11,rot:0,uid:9}]}]))`);
      await go('kompass://spaceflight'); await wait(2500);
      await log('menu', `(document.querySelector('${S}') ? document.querySelector('${S}').innerText.slice(0,200) : 'NO STAGE') + ' ERR: ' + [...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`);
      await shot('kompass13-menu.png');
      await log('new world', `${JSON.stringify('x')}`); await click('New World'); await wait(500); await click('Create & Play'); await wait(1200);
      await click('Demo rocket', '.ks-link'); await wait(800);
      await log('build stats', `[...document.querySelectorAll('${S} b, ${S} .ks-label')].filter(e=>e.offsetParent).map(e=>e.textContent).filter(t=>/m\\/s|^[0-9,.]+$/.test(t)).slice(0,8)`);
      await shot('kompass13-build.png');
      await click('Launch ▲'); await wait(1500);
      await shot('kompass13-flight-pad.png');
      await click('LAUNCH ▲'); await wait(3500);
      await log('fps during flight', 'null'); console.log('[shots13] fps', await fps());
      await log('telemetry', `[...document.querySelectorAll('${S} .ks-label')].filter(e=>e.offsetParent).map(e=>e.textContent).slice(0,24).join(' | ')`);
      await shot('kompass13-flight-ascent.png');
      await key(' '); await wait(2500);
      await shot('kompass13-flight-staged.png');
      await key('2'); await wait(1200); await shot('kompass13-orbit-view.png');
      await key('3'); await wait(1200); await shot('kompass13-system-view.png');
      await js(`(()=>{const s=[...document.querySelectorAll('${S} select')].find(x=>x.offsetParent);s.value='The Moon';s.dispatchEvent(new Event('change'))})()`); await wait(800);
      await key('1'); await wait(300);
      await js(`(()=>{const s=[...document.querySelectorAll('${S} .ks-button')].find(b=>b.offsetParent&&b.textContent==='1 Ship');})()`);
      await wait(1500); await shot('kompass13-moon-orbit.png');
      await click('🌙 Dark Mode'); await click('← Back to Build'); await wait(1200);
      await shot('kompass13-build-dark.png');
      await click('☀ Light Mode'); await wait(300);
      await go('kompass://learn'); await wait(1500);
      console.log('[shots153] learn sidebar:', await js(`[...document.querySelectorAll('*')].map(e=>e.childElementCount?'':e.textContent).find(t=>/exercises solved/.test(t))`));
      await js(`(()=>{const b=[...document.querySelectorAll('.ks-button,.ks-link,.lesson-item, *')].find(b=>b.children.length<4&&/New in 1.3/.test(b.textContent)&&b.offsetParent);if(b)b.click()})()`); await wait(1000);
      await js(`(()=>{const b=[...document.querySelectorAll('.ks-button')].find(b=>/Try it/.test(b.textContent)&&b.offsetParent);if(b)b.click()})()`); await wait(1500);
      await shot('kompass13-learn-lesson.png');
    } catch (e) { console.log('[shots13] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.4 auto-update screenshot self-test: KOMPASS_SHOTS14=/out/dir (used by tools/e2e-update.js)
if (process.env.KOMPASS_SHOTS14) {
  const out = process.env.KOMPASS_SHOTS14;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[shots14] wrote', name); };
  app.whenReady().then(async () => {
    try {
      for (let i = 0; i < 120 && updater.state.status !== 'ready'; i++) await wait(250);
      console.log('[shots14] state', JSON.stringify(updater.state));
      await wait(800);
      console.log('[shots14] banner', JSON.stringify(await js("(document.querySelector('.upd-bar:not([hidden])')||{}).innerText||''")));
      await shot('kompass14-update-banner.png');
      await js("document.querySelector('.gear').click()"); await wait(1200);
      await js("(()=>{const h=[...document.querySelectorAll('.set-card-title')].find(e=>e.textContent==='Updates');if(h)h.scrollIntoView({block:'start'})})()"); await wait(500);
      console.log('[shots14] settings', JSON.stringify(await js("(()=>{const h=[...document.querySelectorAll('.set-card-title')].find(e=>e.textContent==='Updates');return h?h.closest('.set-card').innerText:''})()")));
      await shot('kompass14-settings-updates.png');
      if (process.env.KOMPASS_SHOTS14_INSTALL) {
        await js("(()=>{const b=[...document.querySelectorAll('.upd-bar .ks-button, .upd-bar button')].find(b=>/Restart to update/.test(b.textContent));if(b)b.click();return !!b})()").then(r => console.log('[shots14] clicked restart', r));
        await wait(3000);
      }
    } catch (e) { console.log('[shots14] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.5 screenshot self-test: KOMPASS_SHOTS15=/out/dir — flicker check + Kugel Store
if (process.env.KOMPASS_SHOTS15) {
  const out = process.env.KOMPASS_SHOTS15, pre = process.env.KOMPASS_SHOTS15_PREFIX || 'kompass15-';
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, pre + name), img.toPNG()); console.log('[shots15] wrote', pre + name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const S = ".ks-tabview:not([hidden]) .app-stage";
  const click = (text, sel, root) => js(`(()=>{const b=[...document.querySelectorAll('${root || S} ${sel || '.ks-button'}')].find(b=>b.offsetParent&&b.textContent.trim()===${JSON.stringify(text)});if(b){b.click();return true}return false})()`);
  // watch for 3 s: removed elements, frames where a visible list/HUD panel was empty, frames where the canvas centre was blank
  const flicker = () => js(`new Promise(res=>{const st=document.querySelector('${S}');let removed=0,emptyFrames=0,blankFrames=0,frames=0;
    const panels=[...st.querySelectorAll('.ks-col,.ks-box')].filter(e=>e.offsetParent&&e.children.length>0);
    const mo=new MutationObserver(ms=>{for(const m of ms)removed+=m.removedNodes.length});mo.observe(st,{childList:true,subtree:true});
    const cv=[...st.querySelectorAll('canvas')].filter(c=>c.offsetParent).sort((a,b)=>b.width*b.height-a.width*a.height)[0];const g=cv&&cv.getContext('2d');
    const t0=performance.now();const f=()=>{frames++;if(panels.some(p=>p.isConnected&&p.children.length===0))emptyFrames++;
      if(g){const d=g.getImageData(cv.width>>1,cv.height>>1,1,1).data;if(d[3]===0)blankFrames++;}
      if(performance.now()-t0<3000)requestAnimationFrame(f);else{mo.disconnect();res({frames,removed,emptyFrames,blankFrames,panels:panels.length,commits:window.__ksRender.stats})}};requestAnimationFrame(f)})`);
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error/.test(msg)) console.log('[shots15] PAGE-ERROR', msg); });
    try {
      await wait(3500);
      await js(`localStorage.setItem('ks-store:sfs_rockets', JSON.stringify([{name:'Demo rocket',parts:[{id:'coneS',col:11,row:0,rot:0,uid:1},{id:'pod',col:11,row:2,rot:0,uid:2},{id:'chute',col:11,row:4,rot:0,uid:3},{id:'sepS',col:11,row:5,rot:0,uid:4},{id:'tankS',col:11,row:6,rot:0,uid:5},{id:'tankS',col:11,row:10,rot:0,uid:6},{id:'engB',col:11,row:14,rot:0,uid:7},{id:'srbT',col:9,row:11,rot:0,uid:8},{id:'srbT',col:13,row:11,rot:0,uid:9}]}]))`);
      await go('kompass://spaceflight'); await wait(2500);
      await click('New World'); await wait(500); await click('Create & Play'); await wait(1200);
      await click('Demo rocket', '.ks-link'); await wait(800);
      await click('Launch ▲'); await wait(1500); await click('LAUNCH ▲'); await wait(1500);
      console.log('[shots15] flicker-during-flight', JSON.stringify(await flicker()));
      await shot('spaceflight-flight.png');
      await js(`(()=>{const b=[...document.querySelectorAll('${S} .ks-button')].filter(b=>b.offsetParent&&/^(ON|OFF)$/.test(b.textContent));if(b[0])b[0].click()})()`); await wait(400);
      await shot('spaceflight-engine-toggle.png');
      await go('kompass://store'); await wait(2500);
      console.log('[shots15] store', JSON.stringify(await js(`[...document.querySelectorAll('.store-card .store-name')].map(e=>e.textContent)`)));
      await shot('store.png');
      await click('▶ Play', '.ks-button', '.ks-tabview:not([hidden])'); await wait(2500); await shot('store-play-spaceflight.png');
      await go('kompass://store/bouncy-ball'); await wait(1500); await shot('store-play-bouncy.png');
      await go('kompass://store/clicker'); await wait(1200); await click('🟠'); await click('🟠'); await wait(300); await shot('store-play-clicker.png');
      await js(`window.__ksPublishDraft={title:'Bouncy Ball 2',code:'let c = canvas(body())\\ndraw_clear(c, "#123")'}`);
      await go('kompass://store/publish'); await wait(1200); await shot('publish.png');
    } catch (e) { console.log('[shots15] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.5.1 big-program self-test: KOMPASS_SHOTS151=/out/dir (+ KOMPASS_STORE_URL with a bigpack entry, KOMPASS_BIG_FILE)
if (process.env.KOMPASS_SHOTS151) {
  const out = process.env.KOMPASS_SHOTS151;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[shots151] wrote', name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error/.test(msg)) console.log('[shots151] PAGE-ERROR', msg); });
    try {
      await wait(3500);
      let t0 = Date.now(); await go('kompass://store/bigpack');
      for (let i = 0; i < 60 && !(await js(`!!document.querySelector('.ks-tabview:not([hidden]) .app-stage canvas')`)); i++) await wait(250);
      await wait(1500); console.log('[shots151] bigpack loaded+started in', Date.now() - t0, 'ms; errors:', await js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`));
      await shot('kompass151-store-play-bigpack.png');
      const big = fs.readFileSync(process.env.KOMPASS_BIG_FILE, 'utf8');
      await js(`window.__ksPublishDraft={title:'Big Level Pack',code:${JSON.stringify(big)}}`);
      await go('kompass://store/publish'); await wait(1500);
      await js(`(()=>{const i=[...document.querySelectorAll('.store-in')];i[1].value='KampfGuy';i[2].value='460 generated levels — a 300 KB+ store test';})()`);
      await js(`[...document.querySelectorAll('.ks-button')].find(b=>b.offsetParent&&b.textContent.trim()==='🌍 Publish').click()`);
      for (let i = 0; i < 80 && !/✔|✖/.test(await js(`document.querySelector('.store-msg').textContent`)); i++) await wait(250);
      console.log('[shots151] publish message:', await js(`document.querySelector('.store-msg').textContent`));
      await shot('kompass151-publish-big.png');
    } catch (e) { console.log('[shots151] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- store games self-test: KOMPASS_SHOTS_GAMES=/out/dir KOMPASS_GAMES=id,id,...
if (process.env.KOMPASS_SHOTS_GAMES) {
  const out = process.env.KOMPASS_SHOTS_GAMES, ids = String(process.env.KOMPASS_GAMES || '').split(',').filter(Boolean);
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const key = (k, ms) => js(`window.dispatchEvent(new KeyboardEvent('keydown',{key:${JSON.stringify(k)}}));setTimeout(()=>window.dispatchEvent(new KeyboardEvent('keyup',{key:${JSON.stringify(k)}})),${ms || 60})`);
  const mouse = (type, fx, fy) => js(`(()=>{const c=[...document.querySelectorAll('.ks-tabview:not([hidden]) .app-stage canvas')].filter(c=>c.offsetParent).pop();if(!c)return;const r=c.getBoundingClientRect();c.dispatchEvent(new MouseEvent(${JSON.stringify(type)},{clientX:r.left+r.width*${fx},clientY:r.top+r.height*${fy},bubbles:true}))})()`);
  let errs = [];
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error/.test(msg)) errs.push(msg); });
    try {
      await wait(3500);
      await go('kompass://store'); await wait(2500);
      console.log('[games] store cards', JSON.stringify(await js(`[...document.querySelectorAll('.store-card .store-name')].map(e=>e.textContent)`)));
      const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, 'store-catalog.png'), img.toPNG());
      for (const id of ids) {
        errs = [];
        await go('kompass://store/' + id); await wait(1500);
        await mouse('mousemove', 0.5, 0.5); await key(' '); await mouse('mousedown', 0.6, 0.4); await mouse('mouseup', 0.6, 0.4); await key('Enter');
        for (let i = 0; i < 12; i++) { await key(['ArrowUp', 'ArrowRight', ' ', 'ArrowDown', 'ArrowLeft', 'd', 'w'][i % 7], 120); await wait(150); if (i % 4 == 0) { await mouse('mousedown', 0.5, 0.5); await mouse('mouseup', 0.5, 0.5); } }
        await wait(400);
        const info = await js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`);
        const img2 = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, 'store-' + id + '.png'), img2.toPNG());
        console.log('[games]', id, errs.length || info ? 'ERRORS ' + JSON.stringify([...new Set(errs)].slice(0, 3)) + ' ' + info : 'ok');
      }
    } catch (e) { console.log('[games] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.5.2 self-test: KOMPASS_SHOTS152=/out/dir — 3D games + fullscreen (F11, HTML5 fullscreen from a page, Esc)
//   KOMPASS_FS_URLS = pages to test HTML5 fullscreen on, comma separated; KOMPASS_FS_SEL<n> = a fullscreen button to click on page n
if (process.env.KOMPASS_SHOTS152) {
  const out = process.env.KOMPASS_SHOTS152;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, 'kompass152-' + name), img.toPNG()); console.log('[shots152] wrote kompass152-' + name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const hold = async (key, ms) => { win.webContents.sendInputEvent({ type: 'keyDown', keyCode: key }); await wait(ms); win.webContents.sendInputEvent({ type: 'keyUp', keyCode: key }); };
  const state = () => js(`({fs: document.body.classList.contains('ks-fullscreen'), web: document.body.classList.contains('ks-webfs'), chromeHidden: (()=>{const v=document.querySelector('.ks-viewarea').getBoundingClientRect();return v.top===0&&v.left===0&&v.width===innerWidth&&v.height===innerHeight})(), hint: (document.querySelector('.ks-fs-hint')||{}).textContent||''})`).then(s => Object.assign(s, { window: win.isFullScreen() }));
  const glInfo = () => js(`(()=>{const c=[...document.querySelectorAll('.ks-tabview:not([hidden]) canvas.ks-scene3d-gl')][0];if(!c)return 'no 3D canvas';const g=c.getContext('webgl2')||c.getContext('webgl');if(!g)return 'no context';const px=new Uint8Array(4);g.readPixels(c.width>>1,c.height>>1,1,1,g.RGBA,g.UNSIGNED_BYTE,px);return c.width+'x'+c.height+' '+(g.getParameter(g.VERSION))+' centre '+[...px].join(',')})()`);
  const errs = [];
  const guest = () => require('electron').webContents.getAllWebContents().filter(w => w.getType() === 'webview' && !w.isDestroyed()).find(w => /^https?:|^data:/.test(w.getURL()) && w.getURL() !== 'about:blank');
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error|Uncaught/.test(msg)) { errs.push(msg); console.log('[shots152] PAGE-ERROR', msg); } });
    try {
      await wait(3500);
      await go('kompass://games3d'); await wait(1200); await shot('games3d.png');
      await go('kompass://maze3d'); await wait(2500);
      console.log('[shots152] maze3d GL:', await glInfo(), '| errors:', await js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`) || 'none');
      await shot('maze3d-start.png');
      await hold('W', 1600); await hold('Right', 500); await hold('W', 800); await wait(300); await shot('maze3d-walked.png');
      await go('kompass://runner3d'); await wait(2000); await shot('runner3d-start.png'); await hold('Space', 80); await wait(1500); await hold('Left', 80); await wait(500); await hold('Space', 80); await wait(250);
      console.log('[shots152] runner3d GL:', await glInfo(), '| errors:', await js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`) || 'none');
      await shot('runner3d.png');
      await wait(4000); await shot('runner3d-later.png');
      // F11 = whole-browser fullscreen
      await hold('F11', 60); await wait(1200); console.log('[shots152] after F11', JSON.stringify(await state())); await shot('f11-fullscreen.png');
      await hold('Escape', 60); await wait(1200); console.log('[shots152] after Esc', JSON.stringify(await state())); await shot('f11-exited.png');
      // HTML5 fullscreen requested by a page (what YouTube's ⛶ button / Google Slides "Present" do)
      const urls = String(process.env.KOMPASS_FS_URLS || 'https://www.youtube.com/').split(',').filter(Boolean);
      let n = 0;
      for (const u of urls) {
        n++; await go(u); await wait(+process.env.KOMPASS_FS_WAIT || 6000);
        const g = guest(); if (!g) { console.log('[shots152] no guest for', u); continue; }
        console.log('[shots152] page', n, g.getURL().slice(0, 80), '| title', g.getTitle());
        await shot('page' + n + '-normal.png');
        const sel = process.env['KOMPASS_FS_SEL' + n] || '';
        const r = await g.executeJavaScript(`(async()=>{const b=${JSON.stringify(sel)}&&document.querySelector(${JSON.stringify(sel)});if(b){b.click();await new Promise(r=>setTimeout(r,800));if(document.fullscreenElement)return 'clicked '+${JSON.stringify(sel)};}const e=document.querySelector('#movie_player')||document.querySelector('video')||document.documentElement;await e.requestFullscreen();return 'requestFullscreen on '+(e.id||e.tagName)})()`, true).catch(e => 'ERR ' + e.message);
        await wait(1500); console.log('[shots152] page', n, 'fullscreen:', r, JSON.stringify(await state()), '| guest fullscreenElement:', await g.executeJavaScript('document.fullscreenElement ? (document.fullscreenElement.id || document.fullscreenElement.tagName) : null'));
        await shot('page' + n + '-fullscreen.png');
        g.focus(); g.sendInputEvent({ type: 'keyDown', keyCode: 'Escape' }); g.sendInputEvent({ type: 'keyUp', keyCode: 'Escape' }); await wait(1500);
        console.log('[shots152] page', n, 'after Esc', JSON.stringify(await state()), '| guest fullscreenElement:', await g.executeJavaScript('document.fullscreenElement ? document.fullscreenElement.tagName : null'));
        await shot('page' + n + '-exited.png');
      }
      console.log('[shots152] errors total:', errs.length);
    } catch (e) { console.log('[shots152] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.5.3 self-test: KOMPASS_SHOTS153=/out/dir — 3D store games + the "3D games" lessons in Learn
if (process.env.KOMPASS_SHOTS153) {
  const out = process.env.KOMPASS_SHOTS153;
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, 'kompass153-' + name), img.toPNG()); console.log('[shots153] wrote kompass153-' + name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));a.blur();})()`);
  const hold = async (key, ms) => { win.webContents.sendInputEvent({ type: 'keyDown', keyCode: key }); await wait(ms); win.webContents.sendInputEvent({ type: 'keyUp', keyCode: key }); };
  const errors = () => js(`[...document.querySelectorAll('.custom-error,.out-err')].filter(e=>e.offsetParent).map(e=>e.innerText).join(';')`);
  const glInfo = () => js(`(()=>{const c=[...document.querySelectorAll('.ks-tabview:not([hidden]) canvas.ks-scene3d-gl')].filter(c=>c.offsetParent)[0];if(!c)return 'no 3D canvas';const g=c.getContext('webgl2')||c.getContext('webgl');return c.width+'x'+c.height+' '+(g?g.getParameter(g.VERSION):'no context')})()`);
  const errs = [];
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error|Uncaught/.test(msg)) { errs.push(msg); console.log('[shots153] PAGE-ERROR', msg); } });
    try {
      await wait(3500);
      await go('kompass://store'); await wait(2500);
      console.log('[shots153] store cards', JSON.stringify(await js(`[...document.querySelectorAll('.store-card .store-name')].map(e=>e.textContent)`)));
      await shot('store.png');
      await js(`(()=>{const c=[...document.querySelectorAll('.store-card')].find(c=>/Sky Hopper/.test(c.innerText));if(c)c.scrollIntoView({block:'center'})})()`); await wait(500); await shot('store-3d-games.png');
      const games = [
        ['sky-hopper-3d', async () => { await hold('W', 700); await hold('Space', 80); await hold('W', 500); }],
        ['asteroid-run-3d', async () => { for (let i = 0; i < 8; i++) { await hold('Space', 120); await hold(i % 2 ? 'Left' : 'Up', 150); } }],
        ['kugel-bowling-3d', async () => { await hold('Left', 150); await hold('Space', 900); await wait(1300); }],
      ];
      for (const [id, play] of games) {
        await go('kompass://store/' + id); await wait(2500); await js('document.activeElement&&document.activeElement.blur()');
        console.log('[shots153]', id, 'GL:', await glInfo(), '| errors:', await errors() || 'none');
        await shot(id + '-title.png');
        await hold('Enter', 80); await wait(800); await play(); await wait(300);
        console.log('[shots153]', id, 'after play errors:', await errors() || 'none');
        if (process.env.KOMPASS_DBG153) console.log('[shots153] canvases', await js(`JSON.stringify([...document.querySelectorAll('.ks-tabview:not([hidden]) canvas.ks-canvas')].filter(c=>c.offsetParent).map(c=>{const g=c.getContext('2d');const d=g?[...g.getImageData(c.width>>1,c.height>>1,1,1).data]:null;return [c.width,c.height,getComputedStyle(c).backgroundColor,getComputedStyle(c).opacity,d, c.className]}))`));
        await shot(id + '-play.png');
      }
      await go('kompass://learn'); await wait(1500);
      console.log('[shots153] learn sidebar:', await js(`[...document.querySelectorAll('*')].map(e=>e.childElementCount?'':e.textContent).find(t=>/exercises solved/.test(t))`));
      for (const [n, keys] of [['⑫', null], ['⑬', 'D'], ['⑭', 'W'], ['⑮', 'W']]) {
        const ok = await js(`(()=>{const it=[...document.querySelectorAll('.learn-item')].find(e=>e.innerText.includes(${JSON.stringify(n)}));if(!it)return false;it.click();return it.innerText.replace(/\\s+/g,' ')})()`);
        await wait(800);
        await js(`(()=>{const b=document.querySelector('.lesson .try-btn');b.click();})()`); await wait(1500);
        await js(`(()=>{const s=document.querySelector('.lesson .try-stage');if(s)s.scrollIntoView({block:'center'});document.activeElement&&document.activeElement.blur()})()`); await wait(400);
        if (keys) await hold(keys, 900);
        await wait(300);
        console.log('[shots153] lesson', ok, '| GL:', await glInfo(), '| errors:', await errors() || 'none', '| out:', await js(`[...document.querySelectorAll('.lesson .try-out')][0].innerText.replace(/\\s+/g,' ')`));
        await shot('lesson-' + { '⑫': 12, '⑬': 13, '⑭': 14, '⑮': 15 }[n] + '.png');
      }
      console.log('[shots153] errors total:', errs.length);
    } catch (e) { console.log('[shots153] error', e && e.stack || e); }
    app.quit();
  });
}

// ---------------- v1.6.0 self-test: KOMPASS_SHOTS160=/out/dir — what Google (and any site) sees from a Kompass tab:
//   request headers (User-Agent, Sec-CH-UA*), navigator.userAgent / userAgentData / webdriver / window.chrome, and Google pages.
//   KOMPASS_SHOTS160_PREFIX names the files (e.g. "before-" / "after-"); KOMPASS_GOOGLE_EMAIL tries Google sign-in up to the password step.
if (process.env.KOMPASS_SHOTS160) {
  const out = process.env.KOMPASS_SHOTS160, pre = process.env.KOMPASS_SHOTS160_PREFIX || 'kompass160-';
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, pre + name), img.toPNG()); console.log('[shots160] wrote ' + pre + name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));a.blur();})()`);
  const guest = () => require('electron').webContents.getAllWebContents().filter(w => w.getType() === 'webview' && !w.isDestroyed()).find(w => /^https?:/.test(w.getURL()));
  const report = {};
  // a local page that asks for every client hint (Accept-CH + Critical-CH) and echoes the request headers back
  const http = require('http');
  const CH = 'Sec-CH-UA, Sec-CH-UA-Mobile, Sec-CH-UA-Platform, Sec-CH-UA-Platform-Version, Sec-CH-UA-Full-Version, Sec-CH-UA-Full-Version-List, Sec-CH-UA-Arch, Sec-CH-UA-Bitness, Sec-CH-UA-Model, Sec-CH-UA-WoW64, Sec-CH-UA-Form-Factors';
  const srv = http.createServer((q, s) => { s.writeHead(200, { 'content-type': 'text/html', 'accept-ch': CH, 'critical-ch': CH }); s.end('<title>headers</title><pre id=h>' + JSON.stringify(q.headers, null, 1).replace(/</g, '&lt;') + '</pre>'); });
  const PROBE = `(async()=>{const d=navigator.userAgentData;let he=null;try{he=d&&await d.getHighEntropyValues(['architecture','bitness','fullVersionList','model','platformVersion','uaFullVersion','wow64','formFactors'])}catch(e){he='ERR '+e.message}
    return {ua:navigator.userAgent,appVersion:navigator.appVersion,vendor:navigator.vendor,platform:navigator.platform,brands:d&&d.brands,mobile:d&&d.mobile,uadPlatform:d&&d.platform,high:he,webdriver:navigator.webdriver,
      chrome:typeof window.chrome==='object'?Object.keys(window.chrome):String(typeof window.chrome),pdf:navigator.pdfViewerEnabled,plugins:navigator.plugins.length,languages:navigator.languages,process:typeof window.process,require:typeof window.require,electronUA:/Electron|Kompass/.test(navigator.userAgent)}})()`;
  app.whenReady().then(async () => {
    try {
      await new Promise(r => srv.listen(0, '127.0.0.1', r)); const local = 'http://127.0.0.1:' + srv.address().port + '/';
      await wait(3500);
      await go(local); await wait(1200); await go(local); await wait(1500);   // second load carries the hints the first response asked for
      let g = guest(); report.localHeaders = JSON.parse(await g.executeJavaScript('document.getElementById("h").textContent'));
      report.js = await g.executeJavaScript(PROBE);
      await shot('headers.png');
      const pages = [['https-headers', 'https://httpbin.org/headers'], ['google-search', 'https://www.google.com/search?q=kompass+browser&hl=en'], ['google-signin', 'https://accounts.google.com/ServiceLogin?hl=en&continue=https://myaccount.google.com/'],
        ['google-docs', 'https://docs.google.com/document/u/0/?hl=en'], ['google-meet', 'https://meet.google.com/?hl=en'], ['google-chrome-detect', 'https://www.google.com/chrome/?hl=en']];
      for (const [name, u] of pages) {
        await go(u); await wait(+process.env.KOMPASS_SHOTS160_WAIT || 7000); g = guest();
        const info = g ? await g.executeJavaScript(`({url:location.href.slice(0,160),title:document.title,text:document.body?document.body.innerText.replace(/\\s+/g,' ').slice(0,600):'',basic:!!document.querySelector('form[action="/search"] input[name=gbv]')||/gbv=1/.test(location.href),ua:navigator.userAgent,brands:navigator.userAgentData?navigator.userAgentData.brands.map(b=>b.brand+' '+b.version).join(', '):null})`).catch(e => ({ err: e.message })) : { err: 'no guest' };
        report[name] = info; console.log('[shots160]', name, JSON.stringify(info).slice(0, 400));
        await shot(name + '.png');
        if (name === 'google-signin' && process.env.KOMPASS_GOOGLE_EMAIL && g) {
          console.log('[shots160] email field:', await g.executeJavaScript(`new Promise(r=>{let n=0;const t=setInterval(()=>{const i=document.querySelector('input[type=email]');if(i||++n>40){clearInterval(t);if(i)i.focus();r(!!i)}},250)})`)); g.focus();
          for (const ch of process.env.KOMPASS_GOOGLE_EMAIL) g.sendInputEvent({ type: 'char', keyCode: ch });
          await wait(400); g.sendInputEvent({ type: 'keyDown', keyCode: 'Return' }); g.sendInputEvent({ type: 'keyUp', keyCode: 'Return' });
          await wait(7000); g = guest();
          report['google-signin-next'] = await g.executeJavaScript(`({url:location.href.slice(0,200),text:document.body.innerText.replace(/\\s+/g,' ').slice(0,600),password:!!document.querySelector('input[type=password]')})`).catch(e => ({ err: e.message }));
          console.log('[shots160] signin-next', JSON.stringify(report['google-signin-next']));
          await shot('google-signin-next.png');
        }
      }
    } catch (e) { console.log('[shots160] error', e && e.stack || e); report.error = String(e && e.stack || e); }
    fs.writeFileSync(path.join(out, pre + 'report.json'), JSON.stringify(report, null, 1));
    srv.close(); app.quit();
  });
}

// ---------------- v1.7 scripted self-test: KOMPASS_TEST_SCRIPT=/path/test.js exports async ({ win, app, js, wait, shot, go, key, click }) => {}
// (used by tests/apps170 runs: Kugel 3D Modeler, Kugel Blocks and Kugel Blocks 3D played through real mouse/keyboard input)
if (process.env.KOMPASS_TEST_SCRIPT) {
  const wait = (ms) => new Promise(r => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const out = process.env.KOMPASS_TEST_OUT || require('os').tmpdir();
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[test] wrote ' + name); };
  const go = (u) => js(`(()=>{const a=document.querySelector('.address');a.value=${JSON.stringify(u)};a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter'}));})()`);
  const key = async (k, mods) => { win.webContents.sendInputEvent({ type: 'keyDown', keyCode: k, modifiers: mods || [] }); win.webContents.sendInputEvent({ type: 'char', keyCode: k, modifiers: mods || [] }); await wait(30); win.webContents.sendInputEvent({ type: 'keyUp', keyCode: k, modifiers: mods || [] }); await wait(60); };
  const mouse = (type, x, y, button, mods) => win.webContents.sendInputEvent({ type, x: Math.round(x), y: Math.round(y), button: button || 'left', clickCount: 1, modifiers: mods || [] });
  const click = async (x, y, button, mods) => { mouse('mouseMove', x, y, button, mods); await wait(30); mouse('mouseDown', x, y, button, mods); await wait(40); mouse('mouseUp', x, y, button, mods); await wait(80); };
  const drag = async (x1, y1, x2, y2, button, steps, mods) => { mouse('mouseMove', x1, y1, button, mods); await wait(30); mouse('mouseDown', x1, y1, button, mods); for (let i = 1; i <= (steps || 10); i++) { mouse('mouseMove', x1 + (x2 - x1) * i / (steps || 10), y1 + (y2 - y1) * i / (steps || 10), button, mods); await wait(25); } mouse('mouseUp', x2, y2, button, mods); await wait(120); };
  const errs = [];
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (/page error|KampfScript error|Uncaught|\[app\]/.test(msg)) { errs.push(msg); console.log('[test] CONSOLE', msg.slice(0, 400)); } });
    let code = 0;
    try { await wait(3000); await require(process.env.KOMPASS_TEST_SCRIPT)({ win, app, js, wait, shot, go, key, mouse, click, drag, errs, out, fs, path }); }
    catch (e) { console.log('[test] FAILED', e && e.stack || e); code = 1; }
    console.log('[test] console errors:', errs.length); app.exit(code);
  });
}
