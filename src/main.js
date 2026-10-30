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
function browserSource() {
  if (!fs.existsSync(userBrowserKs)) fs.copyFileSync(path.join(RES, 'browser.ks'), userBrowserKs);
  return fs.readFileSync(userBrowserKs, 'utf8');
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
