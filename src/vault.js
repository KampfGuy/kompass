// Kompass password vault (main process only). scrypt(master) -> AES-256-GCM. Passwords never leave this
// module except: to the webview of the matching origin (autofill), to the clipboard, and to export files.
const crypto = require('crypto');
const fs = require('fs');
const N = 1 << 15, KEYLEN = 32;
const kdf = (pw, salt) => crypto.scryptSync(String(pw), salt, KEYLEN, { N, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
function seal(key, obj) {
  const iv = crypto.randomBytes(12); const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const data = Buffer.concat([c.update(JSON.stringify(obj), 'utf8'), c.final()]);
  return { iv: iv.toString('base64'), tag: c.getAuthTag().toString('base64'), data: data.toString('base64') };
}
function open(key, box) {
  const d = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(box.iv, 'base64')); d.setAuthTag(Buffer.from(box.tag, 'base64'));
  return JSON.parse(Buffer.concat([d.update(Buffer.from(box.data, 'base64')), d.final()]).toString('utf8'));
}
function originOf(u) { try { const x = new URL(u); return /^https?:$/.test(x.protocol) ? x.origin : ''; } catch (e) { return ''; } }
function generate(len) {
  const n = Math.max(8, Math.min(64, len | 0 || 20));
  const sets = ['ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%^&*-_=+?'];
  const all = sets.join(''); const out = sets.map(s => s[crypto.randomInt(s.length)]);
  while (out.length < n) out.push(all[crypto.randomInt(all.length)]);
  for (let i = out.length - 1; i > 0; i--) { const j = crypto.randomInt(i + 1); [out[i], out[j]] = [out[j], out[i]]; }
  return out.join('');
}
function csvCell(s) { s = String(s == null ? '' : s); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; }
function parseCsv(text) {
  const rows = []; let row = [], cell = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) { if (ch === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += ch; }
    else if (ch === '"') q = true; else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
    else cell += ch;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows.filter(r => r.some(c => c !== ''));
}

class Vault {
  constructor(file, opts) { this.file = file; this.key = null; this.items = []; this.timer = null; this.lockMs = (opts && opts.lockMs) || 5 * 60 * 1000; this.onLock = (opts && opts.onLock) || (() => {}); }
  exists() { return fs.existsSync(this.file); }
  unlocked() { return !!this.key; }
  touch() { clearTimeout(this.timer); if (this.key) { this.timer = setTimeout(() => this.lock(), this.lockMs); if (this.timer.unref) this.timer.unref(); } }
  lock() { this.key = null; this.items = []; clearTimeout(this.timer); this.onLock(); }
  unlock(master) {
    master = String(master || '');
    if (!this.exists()) {
      if (master.length < 8) return { ok: false, error: 'Choose a master password of at least 8 characters' };
      const salt = crypto.randomBytes(16); this.salt = salt; this.key = kdf(master, salt); this.items = []; this.write(); this.touch();
      return { ok: true, created: true };
    }
    const f = JSON.parse(fs.readFileSync(this.file, 'utf8'));
    const salt = Buffer.from(f.salt, 'base64'); const key = kdf(master, salt);
    try { this.items = open(key, f.box).items || []; } catch (e) { return { ok: false, error: 'Wrong master password' }; }
    this.salt = salt; this.key = key; this.touch(); return { ok: true };
  }
  write() { const tmp = this.file + '.tmp'; fs.writeFileSync(tmp, JSON.stringify({ v: 1, kdf: 'scrypt', N, salt: this.salt.toString('base64'), box: seal(this.key, { items: this.items }) })); fs.renameSync(tmp, this.file); }
  need() { if (!this.key) throw new Error('Vault is locked'); this.touch(); }
  list(q) {
    this.need(); q = String(q || '').toLowerCase();
    return this.items.filter(i => !q || (i.origin + ' ' + i.username).toLowerCase().includes(q))
      .map(i => ({ id: i.id, origin: i.origin, username: i.username, updated: i.updated }));
  }
  get(id) { this.need(); return this.items.find(i => i.id === id) || null; }
  forOrigin(origin) { if (!this.key || !origin) return []; this.touch(); return this.items.filter(i => i.origin === origin); }
  save(id, origin, username, password) {
    this.need(); const o = originOf(origin) || originOf('https://' + String(origin)); if (!o) throw new Error('Site must be a web address like https://example.com');
    let it = id ? this.items.find(i => i.id === id) : this.items.find(i => i.origin === o && i.username === username);
    if (!it) { it = { id: crypto.randomUUID(), created: Date.now() }; this.items.push(it); }
    Object.assign(it, { origin: o, username: String(username || '') }); if (password !== null && password !== undefined) it.password = String(password);
    it.updated = Date.now(); this.write(); return it.id;
  }
  remove(id) { this.need(); this.items = this.items.filter(i => i.id !== id); this.write(); }
  exportCsv() { this.need(); return 'url,username,password\n' + this.items.map(i => [i.origin, i.username, i.password].map(csvCell).join(',')).join('\n') + '\n'; }
  exportEncrypted(pass) { this.need(); const salt = crypto.randomBytes(16); return JSON.stringify({ kompassVaultExport: 1, salt: salt.toString('base64'), box: seal(kdf(pass, salt), { items: this.items }) }); }
  importText(text, pass) {
    this.need(); let rows = [];
    const t = String(text).trim();
    if (t.startsWith('{')) { const f = JSON.parse(t); try { rows = open(kdf(pass || '', Buffer.from(f.salt, 'base64')), f.box).items.map(i => [i.origin, i.username, i.password]); } catch (e) { throw new Error('Wrong password for the encrypted export'); } }
    else { const r = parseCsv(t); const h = r[0].map(x => x.toLowerCase()); const ui = h.indexOf('url'), ni = h.indexOf('username'), pi = h.indexOf('password'); if (ui < 0 || pi < 0) throw new Error('CSV needs url,username,password columns'); rows = r.slice(1).map(x => [x[ui], x[ni] || '', x[pi]]); }
    let n = 0; for (const [u, n_, p] of rows) { try { this.save(null, u, n_, p); n++; } catch (e) {} } return n;
  }
}
module.exports = { Vault, generate, originOf, parseCsv };
