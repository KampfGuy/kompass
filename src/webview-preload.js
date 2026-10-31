// Minimal, hardened preload for web pages in <webview>: detects login form submissions and offers autofill.
// It talks to the main process over ONE narrow channel set (kompass-pw:*). No Node APIs reach the page:
// this runs in an isolated world (contextIsolation + sandbox) and exposes nothing to the page's JavaScript.
const { ipcRenderer } = require('electron');
let lastSent = '';
function pwField(root) { return [...(root || document).querySelectorAll('input[type=password]')].find(i => i.offsetParent !== null || i.value); }
function userField(pw) {
  const form = pw.form || document;
  const ins = [...form.querySelectorAll('input')].filter(i => /^(text|email|tel|)$/.test(i.type) && i !== pw && i.offsetParent !== null);
  const before = ins.filter(i => i.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING);
  return before[before.length - 1] || ins[0] || null;
}
function capture(form) {
  const pw = pwField(form || document); if (!pw || !pw.value) return;
  const u = userField(pw); const user = u ? u.value : '';
  const key = location.origin + '|' + user + '|' + pw.value.length;
  if (key === lastSent) return; lastSent = key;
  ipcRenderer.send('kompass-pw:submit', { username: user, password: pw.value });
}
window.addEventListener('submit', (e) => capture(e.target), true);
window.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target && e.target.type === 'password') capture(e.target.form); }, true);
window.addEventListener('click', (e) => { const b = e.target && e.target.closest && e.target.closest('button,input[type=submit]'); if (b) setTimeout(() => capture(b.form), 0); }, true);
window.addEventListener('beforeunload', () => capture(null), true);

// autofill: ask main for saved usernames for THIS origin (main checks the sender's real URL)
let offered = false;
async function offer() {
  const pw = pwField(); if (!pw || offered) return;
  const users = await ipcRenderer.invoke('kompass-pw:query'); if (!users || !users.length) return;
  offered = true;
  const host = document.createElement('div');
  host.setAttribute('style', 'position:fixed;z-index:2147483647;right:16px;top:16px;background:#1b1f2a;color:#f0e6d2;font:13px system-ui,sans-serif;border:1px solid #d4a440;border-radius:12px;padding:8px 10px;box-shadow:0 8px 30px rgba(0,0,0,.35)');
  host.textContent = '🔑 Kompass: fill saved login ';
  for (const u of users.slice(0, 4)) {
    const b = document.createElement('button'); b.textContent = u || '(no username)';
    b.setAttribute('style', 'margin-left:6px;background:#d4a440;color:#120c05;border:0;border-radius:8px;padding:4px 8px;cursor:pointer');
    b.onclick = async (e) => {
      e.preventDefault(); const r = await ipcRenderer.invoke('kompass-pw:fill', u); if (!r) return;
      const p = pwField(); const uf = p && userField(p);
      const set = (el, v) => { if (!el) return; el.focus(); el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); el.dispatchEvent(new Event('change', { bubbles: true })); };
      set(uf, r.username); set(p, r.password); host.remove();
    };
    host.appendChild(b);
  }
  const x = document.createElement('button'); x.textContent = '×'; x.setAttribute('style', 'margin-left:6px;background:none;border:0;color:#f0e6d2;cursor:pointer'); x.onclick = () => host.remove(); host.appendChild(x);
  document.documentElement.appendChild(host);
}
const obs = () => { offer().catch(() => {}); };
window.addEventListener('DOMContentLoaded', () => { obs(); new MutationObserver(() => { if (!offered && pwField()) obs(); }).observe(document.documentElement, { childList: true, subtree: true }); });
