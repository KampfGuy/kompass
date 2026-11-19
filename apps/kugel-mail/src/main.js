// Kugel Mail — main process. Holds accounts (passwords encrypted with the OS key store via safeStorage),
// talks IMAP/SMTP, and gives the window only cleaned-up message data.
'use strict';
const { app, BrowserWindow, ipcMain, safeStorage, dialog, shell, session, Menu } = require('electron');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { PRESETS, MailAccount, testAccount, friendly } = require('./mailcore');

app.setName('Kugel Mail');
if (process.env.KUGELMAIL_DATA) app.setPath('userData', process.env.KUGELMAIL_DATA);
const DATA = () => app.getPath('userData');
const ACC_FILE = () => path.join(DATA(), 'accounts.json');
let win = null;
const live = new Map();     // id -> MailAccount
const memPass = new Map();  // id -> password, only when the OS key store is unavailable
let accounts = [];

function secureStoreOK() {
  // tests on Linux without a keyring: exercise the same encrypt/decrypt path with Chromium's basic key (never used on Windows, which has DPAPI)
  if (process.platform === 'linux' && process.env.KUGELMAIL_TEST_ALLOW_BASIC && safeStorage.setUsePlainTextEncryption) safeStorage.setUsePlainTextEncryption(true);
  if (!safeStorage.isEncryptionAvailable()) return false;
  if (process.platform === 'linux' && safeStorage.getSelectedStorageBackend && safeStorage.getSelectedStorageBackend() === 'basic_text') return !!process.env.KUGELMAIL_TEST_ALLOW_BASIC;
  return true;
}
function loadAccounts() { try { accounts = JSON.parse(fs.readFileSync(ACC_FILE(), 'utf8')).accounts || []; } catch (e) { accounts = []; } }
function saveAccounts() { fs.mkdirSync(DATA(), { recursive: true }); fs.writeFileSync(ACC_FILE() + '.tmp', JSON.stringify({ v: 1, accounts }, null, 1)); fs.renameSync(ACC_FILE() + '.tmp', ACC_FILE()); }
const pub = (a) => ({ id: a.id, email: a.email, name: a.name, user: a.user, preset: a.preset, imap: a.imap, smtp: a.smtp, saved: !!a.pass || memPass.has(a.id) });
function password(a) { if (memPass.has(a.id)) return memPass.get(a.id); if (!a.pass) throw new Error('Password needed — open the account settings'); return safeStorage.decryptString(Buffer.from(a.pass, 'base64')); }
function acct(id) {
  if (live.has(id)) return live.get(id);
  const a = accounts.find((x) => x.id === id); if (!a) throw new Error('Unknown account');
  const m = new MailAccount(Object.assign({}, a, { pass: password(a) })); live.set(id, m); return m;
}
function cleanCfg(c) {
  const s = (v, n) => String(v == null ? '' : v).trim().slice(0, n || 200);
  const srv = (x) => ({ host: s(x && x.host).toLowerCase(), port: +(x && x.port) || 0, security: s(x && x.security) });
  return { email: s(c.email), name: s(c.name), user: s(c.user) || s(c.email), preset: s(c.preset) || 'custom', imap: srv(c.imap), smtp: srv(c.smtp) };
}

// every IPC handler returns {ok, value} or {ok:false, error} so the window can show friendly messages
const handle = (name, fn) => ipcMain.handle(name, async (e, ...args) => {
  if (!win || e.sender !== win.webContents) return { ok: false, error: 'denied' };
  try { return { ok: true, value: await fn(...args) }; } catch (err) { return { ok: false, error: friendly(err) }; }
});
handle('presets', () => ({ presets: PRESETS, secure: secureStoreOK() }));
handle('accounts', () => accounts.map(pub));
handle('account-save', async (cfg, pass, id) => {
  const c = cleanCfg(cfg || {});
  if (!/^[^@\s]+@[^@\s]+$/.test(c.email)) throw Object.assign(new Error('Please type a full email address'), { plain: true });
  const old = id ? accounts.find((x) => x.id === id) : null;
  const pw = pass ? String(pass) : old ? password(old) : '';
  if (!pw) throw Object.assign(new Error('Please type the (app) password'), { plain: true });
  await testAccount(Object.assign({}, c, { pass: pw }));
  const a = Object.assign(old || { id: crypto.randomUUID() }, c);
  if (secureStoreOK()) { a.pass = safeStorage.encryptString(pw).toString('base64'); memPass.delete(a.id); } else { delete a.pass; memPass.set(a.id, pw); }
  if (!old) accounts.push(a);
  if (live.has(a.id)) { live.get(a.id).close(); live.delete(a.id); }
  saveAccounts(); return pub(a);
});
handle('account-remove', async (id) => { if (live.has(id)) { await live.get(id).close(); live.delete(id); } memPass.delete(id); accounts = accounts.filter((a) => a.id !== id); saveAccounts(); return true; });
handle('folders', (id) => acct(id).folders());
handle('messages', (id, folder, page) => acct(id).messages(String(folder), page, 50));
handle('search', (id, folder, q) => acct(id).search(String(folder), q));
handle('open', (id, folder, uid, remote) => { allowRemote = !!remote; return acct(id).open(String(folder), +uid, { remote: !!remote }); });
handle('flag', (id, folder, uid, flag, on) => acct(id).flag(String(folder), +uid, flag, !!on));
handle('delete', (id, folder, uid) => acct(id).remove(String(folder), +uid));
handle('send', (id, msg) => {
  const m = msg || {}; const list = (s) => String(s || '').split(/[,;]/).map((x) => x.trim()).filter(Boolean);
  const to = list(m.to); if (!to.length) throw Object.assign(new Error('Who is it for? Type an address in To'), { plain: true });
  if (to.concat(list(m.cc)).some((x) => !/@/.test(x))) throw Object.assign(new Error('One of the addresses does not look right'), { plain: true });
  const files = (m.files || []).map((p) => String(p)).filter((p) => pickedFiles.has(p)).map((p) => ({ path: p, filename: path.basename(p) }));
  const fwd = (m.forwardAttachments || []).map((i) => { const x = acct(id).attachment(String(m.forwardFolder), +m.forwardUid, +i); return { filename: x.filename, content: x.content }; });
  return acct(id).send({ to, cc: list(m.cc), subject: String(m.subject || '').slice(0, 500), text: String(m.text || ''), inReplyTo: m.inReplyTo, references: m.references, attachments: files.concat(fwd) });
});
const pickedFiles = new Set();
handle('pick-files', async () => {
  const testPick = process.env.KUGELMAIL_TEST_PICK; let r;
  if (testPick) r = { canceled: false, filePaths: testPick.split(path.delimiter) };
  else r = await dialog.showOpenDialog(win, { title: 'Attach files', properties: ['openFile', 'multiSelections'] });
  if (r.canceled) return [];
  return r.filePaths.map((p) => { const st = fs.statSync(p); if (st.size > 25 * 1024 * 1024) throw new Error(path.basename(p) + ' is bigger than 25 MB — most mail servers refuse that'); pickedFiles.add(p); return { path: p, name: path.basename(p), size: st.size }; });
});
handle('save-attachment', async (id, folder, uid, i) => {
  const a = acct(id).attachment(String(folder), +uid, +i); const safe = path.basename(a.filename).replace(/[\\/:*?"<>|]/g, '_') || 'attachment';
  let file;
  if (process.env.KUGELMAIL_TEST_SAVE_DIR) file = path.join(process.env.KUGELMAIL_TEST_SAVE_DIR, safe);
  else { const r = await dialog.showSaveDialog(win, { defaultPath: path.join(app.getPath('downloads'), safe) }); if (r.canceled) return null; file = r.filePath; }
  fs.writeFileSync(file, a.content); return path.basename(file);
});
handle('open-link', (url) => { if (/^(https?:|mailto:)/i.test(String(url))) shell.openExternal(String(url)); return true; });

let allowRemote = false; // remote images only for the message the user said "load images" for

function createWindow() {
  win = new BrowserWindow({ width: 1200, height: 780, minWidth: 760, minHeight: 480, title: 'Kugel Mail', backgroundColor: '#f4f6fb', icon: path.join(__dirname, 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: true, webviewTag: false } });
  win.webContents.setWindowOpenHandler(({ url }) => { if (/^(https?:|mailto:)/i.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (url !== win.webContents.getURL()) e.preventDefault(); });
  win.webContents.on('will-frame-navigate', (e) => { if (!e.isMainFrame && !/^about:/.test(e.url)) { e.preventDefault(); if (/^(https?:|mailto:)/i.test(e.url)) shell.openExternal(e.url); } });
  win.loadFile(path.join(__dirname, 'ui', 'index.html'));
}
app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  const ses = session.defaultSession;
  ses.setPermissionRequestHandler((wc, perm, cb) => cb(false));
  ses.webRequest.onBeforeRequest((d, cb) => { const remote = /^(https?|wss?|ftp):/i.test(d.url); cb({ cancel: remote && !(allowRemote && d.resourceType === 'image') }); });
  loadAccounts(); createWindow();
});
app.on('window-all-closed', async () => { for (const m of live.values()) await m.close(); app.quit(); });

// ---- scripted self-test: KUGELMAIL_TEST_SCRIPT=/path/test.js exports async (h) => {}
if (process.env.KUGELMAIL_TEST_SCRIPT) {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const js = (code) => win.webContents.executeJavaScript(code);
  const out = process.env.KUGELMAIL_TEST_OUT || require('os').tmpdir();
  const shot = async (name) => { const img = await win.webContents.capturePage(); fs.writeFileSync(path.join(out, name), img.toPNG()); console.log('[test] wrote ' + name); };
  const mouse = (type, x, y) => win.webContents.sendInputEvent({ type, x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
  const click = async (x, y) => { mouse('mouseMove', x, y); await wait(30); mouse('mouseDown', x, y); await wait(40); mouse('mouseUp', x, y); await wait(150); };
  const type = async (s) => { for (const ch of s) { win.webContents.sendInputEvent({ type: 'char', keyCode: ch }); await wait(8); } };
  const errs = [];
  app.whenReady().then(async () => {
    win.webContents.on('console-message', (e, level, m) => { const msg = String((e && e.message) || m || ''); if (level >= 2 || /error/i.test(msg)) { errs.push(msg); console.log('[test] CONSOLE', msg.slice(0, 300)); } });
    let code = 0;
    try { await wait(1500); await require(process.env.KUGELMAIL_TEST_SCRIPT)({ win, app, js, wait, shot, click, type, mouse, errs, out, fs, path, dataDir: DATA() }); }
    catch (e) { console.log('[test] FAILED', (e && e.stack) || e); code = 1; }
    console.log('[test] console errors:', errs.length); app.exit(code);
  });
}
