// Kompass — Electron shell. It only hosts the KampfScript runtime (renderer) and exposes native services.
// All browser UI/logic lives in browser.ks.
const { app, BrowserWindow, ipcMain, session, shell, Menu, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

const DEV_RES = path.join(__dirname, '..', 'resources');
const RES = app.isPackaged ? path.join(process.resourcesPath, 'ks') : DEV_RES;
const DATA = path.join(app.getPath('userData'), 'kompass');
const SCRIPTS = path.join(DATA, 'scripts');
fs.mkdirSync(SCRIPTS, { recursive: true });

// Strip "Electron/x" from the UA so sites like YouTube treat us like regular Chrome.
app.userAgentFallback = app.userAgentFallback.replace(/\s?Electron\/[\d.]+/, '').replace(/\s?kompass\/[\d.]+/i, '');

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
  win.loadFile(path.join(__dirname, 'index.html'));
}

app.on('web-contents-created', (_e, contents) => {
  // Harden every <webview>: no node, sandboxed, no preload, isolated.
  contents.on('will-attach-webview', (_ev, webPreferences, params) => {
    delete webPreferences.preload;
    webPreferences.nodeIntegration = false;
    webPreferences.contextIsolation = true;
    webPreferences.sandbox = true;
    webPreferences.webSecurity = true;
    if (!/^(https?:|about:blank|data:)/.test(params.src || 'about:blank')) params.src = 'about:blank';
  });
  if (contents.getType() === 'webview') {
    contents.setWindowOpenHandler(({ url }) => { if (win) win.webContents.send('kompass:open-tab', url); return { action: 'deny' }; });
    contents.on('before-input-event', (ev, input) => {
      // forward browser shortcuts from inside pages to the KampfScript chrome
      if (input.type !== 'keyDown') return;
      const k = (input.control ? 'ctrl+' : '') + (input.shift ? 'shift+' : '') + (input.alt ? 'alt+' : '') + input.key.toLowerCase();
      if (/^(ctrl\+|alt\+)/.test(k) || k === 'f5' || k === 'f12') { if (win) win.webContents.send('kompass:key', k); }
    });
  } else if (contents !== (win && win.webContents)) {
    contents.setWindowOpenHandler(() => ({ action: 'deny' }));
  }
});

app.whenReady().then(() => {
  session.fromPartition('persist:kompass').webRequest.onBeforeRequest((d, cb) => {
    if (blockOn && d.resourceType !== 'mainFrame' && isBlocked(d.url)) { blockedCount++; return cb({ cancel: true }); }
    cb({});
  });
  session.fromPartition('persist:kompass').setPermissionRequestHandler((_wc, perm, cb) => cb(['fullscreen', 'clipboard-sanitized-write', 'media'].includes(perm) && perm !== 'media'));
  Menu.setApplicationMenu(null);
  createWindow();
});
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
ipcMain.on('kompass:quit', () => app.quit());
ipcMain.on('kompass:version', e => { e.returnValue = app.getVersion(); });
ipcMain.handle('kompass:clear-data', async () => {
  const ses = session.fromPartition('persist:kompass');
  await ses.clearStorageData(); await ses.clearCache(); await ses.clearHostResolverCache();
  for (const f of ['history.json']) { try { fs.unlinkSync(path.join(DATA, f)); } catch (e) {} }
  return true;
});
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
