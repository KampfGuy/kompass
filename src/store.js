/* Kugel Store (Kompass 1.5): a free, serverless store of KampfScript programs.
 * Catalog = the public GitHub repo KampfGuy/kugel-store: index.json + entries/<id>.ks, read over raw.githubusercontent.com.
 * Publishing needs NO token: Kompass opens a prefilled "new issue" page on github.com in the user's normal browser;
 * the user signs in to GitHub there (their own account) and presses Submit. The maintainer reviews and merges it.
 * Nothing secret is stored in or sent by the app. Store code only ever runs in the sandboxed page runtime (run_page). */
'use strict';
const fs = require('fs'), path = require('path');
const REPO = 'KampfGuy/kugel-store';
const RAW = 'https://raw.githubusercontent.com/' + REPO + '/main';
const MAX_BYTES = 4 * 1024 * 1024;     // biggest store file Kompass will download
const MAX_CODE = 2 * 1024 * 1024;      // biggest program you can publish (the relay's limit)
const RELAY = 'https://kugel-store.kampfguy.workers.dev';   // free Cloudflare Worker that holds big submissions (no GitHub token)
const MAX_URL = 7500;                    // GitHub rejects very long prefilled URLs; above this the code goes to the clipboard
const fileOk = (n) => n === 'index.json' || /^entries\/[a-z0-9][a-z0-9_-]{0,47}\.ks$/.test(n);
const str = (v, n) => String(v === undefined || v === null ? '' : v).replace(/[\u0000-\u0008\u000b-\u001f]/g, '').slice(0, n);

function cleanIndex(j) {
  const list = Array.isArray(j) ? j : (j && Array.isArray(j.entries) ? j.entries : []);
  const out = [];
  for (const e of list.slice(0, 500)) {
    if (!e || typeof e !== 'object') continue;
    const id = str(e.id, 48); if (!/^[a-z0-9][a-z0-9_-]{0,47}$/.test(id)) continue;
    out.push({ id, title: str(e.title, 60) || id, author: str(e.author, 40) || 'unknown', description: str(e.description, 240),
      tags: Array.isArray(e.tags) ? e.tags.slice(0, 6).map(t => str(t, 20)) : [], file: 'entries/' + id + '.ks', icon: str(e.icon, 4) || '🎮' });
  }
  return out;
}

// get index.json or entries/x.ks: online first, bundled copy (resources/store) when offline
async function get(name, opts) {
  opts = opts || {};
  if (!fileOk(name)) return { ok: false, error: 'bad store file name' };
  const base = opts.base || process.env.KOMPASS_STORE_URL || RAW;
  const fetchFn = opts.fetch || globalThis.fetch;
  try {
    const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), opts.timeoutMs || (name.endsWith('.ks') ? 45000 : 15000));
    const r = await fetchFn(base + '/' + name + '?t=' + Date.now(), { signal: ctl.signal, redirect: 'error' }); clearTimeout(t);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const text = await r.text(); if (text.length > MAX_BYTES) throw new Error('too big');
    return { ok: true, text, source: 'online' };
  } catch (e) {
    if (opts.bundled) { try { return { ok: true, text: fs.readFileSync(path.join(opts.bundled, name), 'utf8'), source: 'offline copy', warn: e.message }; } catch (e2) {} }
    return { ok: false, error: 'Could not reach the Kugel Store: ' + e.message };
  }
}
async function index(opts) {
  const r = await get('index.json', opts); if (!r.ok) return r;
  try { return { ok: true, entries: cleanIndex(JSON.parse(r.text)), source: r.source }; } catch (e) { return { ok: false, error: 'index.json is broken: ' + e.message }; }
}

// a prefilled GitHub issue; the .ks code goes in the body (or to the clipboard when it is too long for a URL)
function publishUrl(p) {
  const title = str(p.title, 60).trim() || 'My KampfScript program', desc = str(p.description, 240).trim(), author = str(p.author, 40).trim();
  const code = String(p.code || '').slice(0, MAX_BYTES).replace(/```/g, '`\u200b``');
  const head = '### Title\n' + title + '\n\n### Author\n' + (author || '(your name)') + '\n\n### Description\n' + (desc || '(what is it?)') + '\n\n### Code\n';
  const mk = (body) => 'https://github.com/' + REPO + '/issues/new?labels=submission&title=' + encodeURIComponent('[Submit] ' + title) + '&body=' + encodeURIComponent(body);
  const full = mk(head + '```kampfscript\n' + code + '\n```\n\nSubmitted from Kompass ' + (p.version || '') + '.');
  if (full.length <= MAX_URL) return { url: full, copied: false };
  return { url: mk(head + '```kampfscript\n(The code was copied to your clipboard by Kompass — click here and press Ctrl+V)\n```\n\nSubmitted from Kompass ' + (p.version || '') + '.'), copied: true };
}
// publish(): small code -> prefilled issue with the code inline. Bigger code -> uploaded to the relay first and the
// issue just links to it (+ sha256); the kugel-store GitHub Action then copies it into the repo. If the relay can't be
// reached, fall back to the clipboard flow.
async function publish(p, opts) {
  opts = opts || {};
  const code = String(p.code || '');
  const bytes = Buffer.byteLength(code);
  if (bytes > MAX_CODE) return { ok: false, error: 'Your program is ' + (bytes / 1048576).toFixed(1) + ' MB — the store limit is 2 MB' };
  const small = publishUrl(p);
  if (!small.copied) return Object.assign({ ok: true, mode: 'inline', bytes }, small);
  const relay = opts.relay || process.env.KOMPASS_STORE_RELAY || RELAY, fetchFn = opts.fetch || globalThis.fetch;
  try {
    const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), opts.timeoutMs || 60000);
    const r = await fetchFn(relay + '/submit', { method: 'POST', signal: ctl.signal, headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ title: str(p.title, 60), author: str(p.author, 40), description: str(p.description, 240), code }) });
    clearTimeout(t);
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.ok || !/^https:\/\/[^\s]+\.ks$/.test(j.url || '')) throw new Error(j.error || ('HTTP ' + r.status));
    return Object.assign({ ok: true, mode: 'link', bytes, codeUrl: j.url, sha256: j.sha256, copied: false }, { url: linkUrl(p, j.url, j.sha256, bytes) });
  } catch (e) {
    return Object.assign({ ok: true, mode: 'clipboard', bytes, warn: 'Upload failed (' + e.message + ') — code copied to the clipboard instead' }, small);
  }
}
function linkUrl(p, codeUrl, sha, bytes) {
  const title = str(p.title, 60).trim() || 'My KampfScript program', desc = str(p.description, 240).trim(), author = str(p.author, 40).trim();
  const body = '### Title\n' + title + '\n\n### Author\n' + (author || '(your name)') + '\n\n### Description\n' + (desc || '(what is it?)') +
    '\n\n### Code\n' + codeUrl + '\n\n' + (bytes / 1024).toFixed(1) + ' KB, ' + (String(p.code || '').split('\n').length) + ' lines · sha256: ' + sha +
    '\n\n(Uploaded by Kompass ' + (p.version || '') + ' — the Kugel Store bot saves it into the repo when you submit this issue.)';
  return 'https://github.com/' + REPO + '/issues/new?labels=submission&title=' + encodeURIComponent('[Submit] ' + title) + '&body=' + encodeURIComponent(body);
}
module.exports = { REPO, RAW, RELAY, get, index, cleanIndex, publishUrl, publish, linkUrl, fileOk, MAX_URL, MAX_CODE, MAX_BYTES };
