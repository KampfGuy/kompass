// Kugel Mail window. All mail text goes into the page with textContent (never innerHTML);
// message HTML is already cleaned in the main process and is shown in a sandboxed frame without scripts.
'use strict';
const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const S = { presets: {}, secure: true, accounts: [], acc: null, folders: [], folder: 'INBOX', items: [], page: 0, total: 0, sel: null, view: null, query: '', editing: null, preset: 'gmail', compose: null };

async function api(name, ...a) { const r = await window.mail[name](...a); if (!r.ok) throw new Error(r.error); return r.value; }
function toast(msg, bad) { const t = $('toast'); t.textContent = msg; t.className = 'show' + (bad ? ' bad' : ''); clearTimeout(toast.t); toast.t = setTimeout(() => (t.className = ''), 3500); }
const show = (id) => { for (const v of ['setup', 'main']) $(v).hidden = v !== id; };
const fmtSize = (n) => (n > 1048576 ? (n / 1048576).toFixed(1) + ' MB' : n > 1024 ? Math.round(n / 1024) + ' KB' : n + ' B');
function fmtDate(iso) {
  if (!iso) return ''; const d = new Date(iso), now = new Date();
  if (d.toDateString() === now.toDateString()) return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  if (d.getFullYear() === now.getFullYear()) return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  return d.toLocaleDateString();
}
const FICON = { '\\Inbox': '📥', '\\Sent': '📤', '\\Drafts': '📝', '\\Trash': '🗑', '\\Junk': '⚠', '\\Archive': '🗄', '\\All': '📚', '\\Flagged': '⭐' };

// ---------- account setup
function fillPreset(k) {
  S.preset = k; const p = S.presets[k];
  for (const b of $('presets').children) b.classList.toggle('on', b.dataset.k === k);
  $('preset-note').textContent = p.note;
  $('s-pass-label').textContent = k === 'gmail' || k === 'yahoo' ? 'App password' : 'Password';
  $('s-ihost').value = p.imap.host; $('s-iport').value = p.imap.port; $('s-isec').value = p.imap.security;
  $('s-shost').value = p.smtp.host; $('s-sport').value = p.smtp.port; $('s-ssec').value = p.smtp.security;
  $('s-adv').open = k === 'custom';
}
function openSetup(acc) {
  S.editing = acc || null; $('setup-err').textContent = '';
  $('setup-title').textContent = acc ? 'Account settings' : S.accounts.length ? 'Add another account' : 'Add your email account';
  $('s-cancel').hidden = !S.accounts.length; $('s-remove').hidden = !acc;
  if (acc) {
    fillPreset(S.presets[acc.preset] ? acc.preset : 'custom');
    $('s-name').value = acc.name; $('s-email').value = acc.email; $('s-user').value = acc.user; $('s-pass').value = ''; $('s-pass').placeholder = acc.saved ? '(saved — leave empty to keep)' : 'type it again';
    $('s-ihost').value = acc.imap.host; $('s-iport').value = acc.imap.port; $('s-isec').value = acc.imap.security;
    $('s-shost').value = acc.smtp.host; $('s-sport').value = acc.smtp.port; $('s-ssec').value = acc.smtp.security;
  } else { fillPreset('gmail'); for (const i of ['s-name', 's-email', 's-user', 's-pass']) $(i).value = ''; $('s-pass').placeholder = 'paste it here'; }
  show('setup'); $(acc ? 's-pass' : 's-email').focus();
}
async function saveSetup() {
  const btn = $('s-save'); $('setup-err').textContent = ''; btn.disabled = true; btn.textContent = 'Checking…';
  const cfg = { name: $('s-name').value, email: $('s-email').value, user: $('s-user').value || $('s-email').value, preset: S.preset,
    imap: { host: $('s-ihost').value, port: $('s-iport').value, security: $('s-isec').value }, smtp: { host: $('s-shost').value, port: $('s-sport').value, security: $('s-ssec').value } };
  try {
    const a = await api('accountSave', cfg, $('s-pass').value, S.editing && S.editing.id);
    $('s-pass').value = ''; S.accounts = await api('accounts'); toast('Connected to ' + a.email); await useAccount(a.id); show('main');
  } catch (e) { $('setup-err').textContent = e.message; }
  finally { btn.disabled = false; btn.textContent = 'Test & save'; }
}
$('s-email').addEventListener('input', () => {
  const v = $('s-email').value.toLowerCase(); if (!S.editing) $('s-user').value = $('s-email').value;
  const guess = /@(gmail|googlemail)\./.test(v) ? 'gmail' : /@(outlook|hotmail|live|msn)\./.test(v) ? 'outlook' : /@(yahoo|ymail)\./.test(v) ? 'yahoo' : null;
  if (guess && guess !== S.preset) fillPreset(guess);
});
$('s-save').onclick = saveSetup;
$('s-pass').addEventListener('keydown', (e) => { if (e.key === 'Enter') saveSetup(); });
$('s-cancel').onclick = () => show('main');
$('s-remove').onclick = async () => {
  if (!confirm('Remove ' + S.editing.email + ' from Kugel Mail? (Your mail stays on the server.)')) return;
  await api('accountRemove', S.editing.id); S.accounts = await api('accounts');
  if (S.accounts.length) { await useAccount(S.accounts[0].id); show('main'); } else openSetup();
};

// ---------- folders & list
function renderAccounts() {
  const p = $('acct-pick'); p.textContent = '';
  for (const a of S.accounts) { const o = el('option', null, a.email); o.value = a.id; p.append(o); }
  p.value = S.acc; p.hidden = S.accounts.length < 2;
}
async function useAccount(id) { S.acc = id; S.folder = 'INBOX'; renderAccounts(); await loadFolders(); await loadList(); }
async function loadFolders() {
  try { S.folders = await api('folders', S.acc); } catch (e) { toast(e.message, true); S.folders = []; }
  const nav = $('folders'); nav.textContent = '';
  for (const f of S.folders) {
    const b = el('button', 'folder' + (f.path === S.folder ? ' on' : '')); b.dataset.path = f.path;
    b.append(el('span', 'fi', FICON[f.special] || '📁'), el('span', 'fn', f.name));
    if (f.unseen) b.append(el('span', 'badge', String(f.unseen)));
    b.onclick = async () => { S.folder = f.path; $('search').value = ''; S.query = ''; for (const x of nav.children) x.classList.toggle('on', x === b); await loadList(); };
    nav.append(b);
  }
}
async function loadList(more) {
  if (!more) { S.page = 0; S.items = []; }
  const box = $('msgs'); if (!more) { box.textContent = ''; box.append(el('div', 'loading', 'Loading…')); }
  try {
    const r = S.query ? await api('search', S.acc, S.folder, S.query) : await api('messages', S.acc, S.folder, S.page);
    S.total = r.total; S.items = S.items.concat(r.items);
  } catch (e) { toast(e.message, true); }
  renderList();
}
function renderList() {
  const box = $('msgs'); box.textContent = '';
  if (!S.items.length) box.append(el('div', 'loading', S.query ? 'Nothing found for "' + S.query + '".' : 'This folder is empty.'));
  for (const m of S.items) {
    const r = el('div', 'msg' + (m.seen ? '' : ' unread') + (S.sel === m.uid ? ' on' : '')); r.dataset.uid = m.uid; r.tabIndex = -1;
    const top = el('div', 'm-top'); top.append(el('span', 'm-from', m.from), el('span', 'm-date', fmtDate(m.date)));
    const sub = el('div', 'm-sub'); if (m.flagged) sub.append(el('span', 'star', '⭐ ')); if (m.attachments) sub.append(el('span', 'clip', '📎 ')); sub.append(document.createTextNode(m.subject));
    r.append(top, sub); r.onclick = () => openMsg(m.uid); box.append(r);
  }
  $('more').hidden = !!S.query || S.items.length >= S.total;
}
$('more').onclick = () => { S.page++; loadList(true); };
let searchT; $('search').addEventListener('input', () => { clearTimeout(searchT); searchT = setTimeout(() => { S.query = $('search').value.trim(); loadList(); }, 350); });
$('refresh').onclick = async () => { await loadFolders(); await loadList(); toast('Up to date'); };
$('acct-pick').onchange = () => useAccount($('acct-pick').value);

// ---------- reading
function frameDoc(v, remote) {
  const csp = "default-src 'none'; img-src data:" + (remote ? ' https: http:' : '') + "; style-src 'unsafe-inline'; font-src data:";
  const head = '<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="' + csp + '"><base target="_blank">' +
    '<style>body{font:14px/1.5 "Segoe UI",system-ui,sans-serif;color:#1d2433;margin:14px;word-wrap:break-word;overflow-wrap:anywhere}img{max-width:100%;height:auto}pre{white-space:pre-wrap;font:inherit;margin:0}a{color:#2f6fed}img:not([src]){display:inline-block;min-width:16px;min-height:12px;background:#eef1f7;border:1px dashed #c4cbe0}</style></head><body>';
  if (v.html) return head + v.html + '</body></html>';
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const body = esc(v.text || '').replace(/(https?:\/\/[^\s<>"]+)/g, '<a href="$1">$1</a>');
  return head + '<pre>' + body + '</pre></body></html>';
}
async function openMsg(uid, remote) {
  S.sel = uid; for (const r of $('msgs').children) r.classList.toggle('on', +r.dataset.uid === uid);
  $('reader-empty').hidden = false; $('reader-empty').textContent = 'Opening…'; $('reader-body').hidden = true;
  let v; try { v = await api('open', S.acc, S.folder, uid, !!remote); } catch (e) { $('reader-empty').textContent = e.message; return; }
  if (S.sel !== uid) return;
  S.view = Object.assign(v, { uid });
  const it = S.items.find((m) => m.uid === uid); if (it && !it.seen) { it.seen = true; renderList(); bumpUnread(-1); }
  $('r-subject').textContent = v.subject; $('r-from').textContent = v.from; $('r-to').textContent = v.to; $('r-cc').textContent = v.cc; $('r-cc-row').hidden = !v.cc;
  $('r-date').textContent = v.date ? new Date(v.date).toLocaleString() : '';
  $('r-blocked').hidden = !(v.blocked > 0 && !remote); $('r-blocked-n').textContent = v.blocked;
  const att = $('r-att'); att.textContent = '';
  v.attachments.forEach((a) => { const b = el('button', 'att'); b.append(el('span', null, '📎 ' + a.filename), el('small', null, ' ' + fmtSize(a.size))); b.title = 'Save ' + a.filename;
    b.onclick = async () => { try { const n = await api('saveAttachment', S.acc, S.folder, uid, a.i); if (n) toast('Saved ' + n); } catch (e) { toast(e.message, true); } }; att.append(b); });
  $('r-frame').srcdoc = frameDoc(v, remote);
  $('reader-empty').hidden = true; $('reader-body').hidden = false;
}
function bumpUnread(d) { const f = S.folders.find((x) => x.path === S.folder); if (!f) return; f.unseen = Math.max(0, f.unseen + d); const b = [...$('folders').children].find((x) => x.dataset.path === S.folder); if (!b) return; let badge = b.querySelector('.badge'); if (!f.unseen) { if (badge) badge.remove(); return; } if (!badge) { badge = el('span', 'badge'); b.append(badge); } badge.textContent = f.unseen; }
$('r-load').onclick = () => openMsg(S.sel, true);
$('r-unread').onclick = async () => { const uid = S.sel; await api('flag', S.acc, S.folder, uid, '\\Seen', false); const it = S.items.find((m) => m.uid === uid); if (it) it.seen = false; bumpUnread(1); S.sel = null; renderList(); $('reader-body').hidden = true; $('reader-empty').hidden = false; $('reader-empty').textContent = 'Marked as unread.'; };
async function delSel() {
  if (!S.sel) return; const uid = S.sel, i = S.items.findIndex((m) => m.uid === uid);
  try { await api('delete', S.acc, S.folder, uid); } catch (e) { return toast(e.message, true); }
  S.items.splice(i, 1); S.total--; S.sel = null; renderList(); toast('Deleted'); loadFolders();
  const next = S.items[Math.min(i, S.items.length - 1)]; if (next) openMsg(next.uid); else { $('reader-body').hidden = true; $('reader-empty').hidden = false; $('reader-empty').textContent = 'Pick a message to read it.'; }
}
$('r-del').onclick = delSel;

// ---------- writing
const myEmail = () => (S.accounts.find((a) => a.id === S.acc) || {}).email || '';
const quote = (v) => '\n\nOn ' + (v.date ? new Date(v.date).toLocaleString() : '') + ', ' + v.from + ' wrote:\n' + (v.text || '').split('\n').map((l) => '> ' + l).join('\n');
function compose(kind) {
  const v = S.view; S.compose = { kind, files: [], fwd: [] };
  $('c-to').value = ''; $('c-cc').value = ''; $('c-subject').value = ''; $('c-text').value = ''; $('c-err').textContent = '';
  if (v && (kind === 'reply' || kind === 'all')) {
    $('c-to').value = v.replyTo || v.from;
    if (kind === 'all') { const me = myEmail().toLowerCase(); $('c-cc').value = [v.to, v.cc].join(', ').split(',').map((x) => x.trim()).filter((x) => x && !x.toLowerCase().includes(me)).join(', '); }
    $('c-subject').value = /^re:/i.test(v.subject) ? v.subject : 'Re: ' + v.subject; $('c-text').value = quote(v);
    S.compose.inReplyTo = v.messageId; S.compose.references = (v.references || []).concat(v.messageId ? [v.messageId] : []);
  } else if (v && kind === 'fwd') {
    $('c-subject').value = /^fwd?:/i.test(v.subject) ? v.subject : 'Fwd: ' + v.subject;
    $('c-text').value = '\n\n---------- Forwarded message ----------\nFrom: ' + v.from + '\nDate: ' + (v.date ? new Date(v.date).toLocaleString() : '') + '\nSubject: ' + v.subject + '\nTo: ' + v.to + '\n\n' + (v.text || '');
    S.compose.fwd = v.attachments.map((a) => a.i); S.compose.fwdUid = v.uid; S.compose.fwdFolder = S.folder; S.compose.fwdNames = v.attachments;
  }
  $('c-title').textContent = { new: 'New message', reply: 'Reply', all: 'Reply all', fwd: 'Forward' }[kind];
  renderFiles(); $('composer').hidden = false; (kind === 'reply' || kind === 'all' ? $('c-text') : $('c-to')).focus();
  if (kind === 'reply' || kind === 'all') $('c-text').setSelectionRange(0, 0);
}
function renderFiles() {
  const box = $('c-files'); box.textContent = ''; const c = S.compose;
  const chip = (name, size, rm) => { const s = el('span', 'chip'); s.append(el('span', null, '📎 ' + name + (size ? ' (' + fmtSize(size) + ')' : ''))); const x = el('button', 'x', '✕'); x.title = 'Remove'; x.onclick = rm; s.append(x); box.append(s); };
  c.files.forEach((f, i) => chip(f.name, f.size, () => { c.files.splice(i, 1); renderFiles(); }));
  (c.fwdNames || []).filter((a) => c.fwd.includes(a.i)).forEach((a) => chip(a.filename, a.size, () => { c.fwd = c.fwd.filter((x) => x !== a.i); renderFiles(); }));
}
$('compose').onclick = () => compose('new'); $('r-reply').onclick = () => compose('reply'); $('r-all').onclick = () => compose('all'); $('r-fwd').onclick = () => compose('fwd');
$('c-attach').onclick = async () => { try { S.compose.files.push(...(await api('pickFiles'))); renderFiles(); } catch (e) { $('c-err').textContent = e.message; } };
$('c-close').onclick = () => { if (($('c-text').value.trim() || $('c-to').value.trim()) && S.compose.kind === 'new' && !confirm('Throw away this message?')) return; $('composer').hidden = true; };
async function send() {
  const btn = $('c-send'); const c = S.compose; $('c-err').textContent = ''; btn.disabled = true; btn.textContent = 'Sending…';
  try {
    await api('send', S.acc, { to: $('c-to').value, cc: $('c-cc').value, subject: $('c-subject').value, text: $('c-text').value, files: c.files.map((f) => f.path),
      inReplyTo: c.inReplyTo, references: c.references, forwardAttachments: c.fwd, forwardUid: c.fwdUid, forwardFolder: c.fwdFolder });
    $('composer').hidden = true; toast('Sent ✓');
  } catch (e) { $('c-err').textContent = e.message; } finally { btn.disabled = false; btn.textContent = 'Send'; }
}
$('c-send').onclick = send;

// ---------- misc
$('b-acct').onclick = () => openSetup(S.accounts.find((a) => a.id === S.acc));
$('b-add').onclick = () => openSetup();
$('b-help').onclick = () => ($('help').hidden = false); $('h-close').onclick = () => ($('help').hidden = true);
document.addEventListener('keydown', (e) => {
  const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName);
  if (e.key === 'Escape') { $('help').hidden = true; if (!$('composer').hidden) $('c-close').click(); }
  if (!$('composer').hidden) { if (e.ctrlKey && e.key === 'Enter') send(); return; }
  if ($('main').hidden) return;
  if (e.ctrlKey && e.key.toLowerCase() === 'n') { e.preventDefault(); compose('new'); }
  else if (e.ctrlKey && e.key.toLowerCase() === 'r' && S.view) { e.preventDefault(); compose('reply'); }
  else if (e.ctrlKey && e.key.toLowerCase() === 'f') { e.preventDefault(); $('search').focus(); }
  else if (e.key === 'F5') { e.preventDefault(); $('refresh').click(); }
  else if (!typing && e.key === 'Delete') delSel();
  else if (!typing && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) { e.preventDefault(); const i = S.items.findIndex((m) => m.uid === S.sel); const n = S.items[Math.max(0, Math.min(S.items.length - 1, i + (e.key === 'ArrowDown' ? 1 : -1)))]; if (n) openMsg(n.uid); }
});
setInterval(() => { if (S.acc && !$('main').hidden && !S.query && document.hasFocus()) loadFolders().then(() => { if (S.page === 0) api('messages', S.acc, S.folder, 0).then((r) => { if (r.items.length && (!S.items.length || r.items[0].uid !== S.items[0].uid)) { S.items = r.items; S.total = r.total; renderList(); } }).catch(() => {}); }); }, 120000);

(async () => {
  const p = await api('presets'); S.presets = p.presets; S.secure = p.secure;
  for (const k of ['gmail', 'outlook', 'yahoo', 'custom']) { const b = el('button', 'preset', S.presets[k].label); b.dataset.k = k; b.onclick = () => fillPreset(k); $('presets').append(b); }
  $('secure-note').textContent = S.secure ? '🔒 Your password is encrypted by Windows and stays on this PC.' : '⚠ This PC has no secure password store, so Kugel Mail will forget your password when it closes.';
  S.accounts = await api('accounts');
  if (S.accounts.length) { show('main'); await useAccount(S.accounts[0].id); } else openSetup();
})();
