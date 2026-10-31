/* Built-in KampfScript editor + console (Ctrl+Shift+K). Runs your own .ks scripts, or edits browser.ks itself. */
(function () {
  'use strict';
  const K = window.KampfScript;
  const h = (tag, cls, txt) => { const e = document.createElement(tag); if (cls) e.className = cls; if (txt !== undefined) e.textContent = txt; return e; };
  const PAGE_SAMPLE = `# kompass://page/NAME — a page written in KampfScript (scripts/NAME.ks).
# Edit, press 💾 Save, then reload the tab (F5). Page API: search(text), lucky(text), open_url(url), engine()
let page = col(body(), "gp-page")
setstyle(page, "background", "#fdfbf6")
setstyle(page, "color", "#202124")
spacer(page, 50)
let logo = colorletters(page, "My Page", ["#4285f4", "#ea4335", "#fbbc05", "#34a853"], "gp-logo")
setfont(logo, "Arial", 64, "bold")
let n = 0
let shown = label(page, "Clicked 0 times")
button(page, "Click me", fn() {
  n += 1
  settext(shown, "Clicked " + n + " times")
}, "gp-btn")
let bar = row(page, "gp-searchbar")
let q = textbox(bar, "Search " + engine(), fn(t) { search(t) }, "gp-search")
`;
  const SAMPLE = `# Welcome to the KampfScript console!  Ctrl+Enter runs.
let name = "Kampf"
print("Hello, " + name + "!")

fn fib(n) { if n < 2 { return n } return fib(n - 1) + fib(n - 2) }
for i in range(10) { print(i, fib(i)) }

# Scripts can draw UI in the stage below and open browser tabs:
let r = row(body())
button(r, "Open YouTube", fn() { open_tab("https://www.youtube.com") })
button(r, "Search Kugel for cats", fn() { open_tab("kompass://search?q=cats") })
button(r, "Learn KampfScript", fn() { open_tab("kompass://learn") })
`;
  const root = h('div', 'ed-root'); root.hidden = true;
  const bar = h('div', 'ed-bar');
  const title = h('span', 'ed-title', '⚡ KampfScript editor');
  const fileSel = h('select', 'ed-select');
  const mk = (t, f, cls) => { const b = h('button', 'ed-btn' + (cls ? ' ' + cls : ''), t); b.onclick = f; bar.appendChild(b); return b; };
  const nameBox = h('input', 'ed-name'); nameBox.placeholder = 'new name.ks'; nameBox.value = 'myscript.ks';
  bar.append(title, fileSel, nameBox);
  const area = h('textarea', 'ed-code'); area.spellcheck = false;
  const split = h('div', 'ed-split');
  const out = h('pre', 'ed-out');
  const stage = h('div', 'ed-stage');
  split.append(out, stage);
  root.append(bar, area, split);
  document.body.appendChild(root);

  let current = null; // file name, or '@browser'
  let running = null;
  function log(s, cls) { const l = h('div', cls || '', s); out.appendChild(l); out.scrollTop = out.scrollHeight; }
  function refreshFiles() {
    fileSel.replaceChildren();
    const opt = (v, t) => { const o = h('option', '', t); o.value = v; fileSel.appendChild(o); };
    opt('@new', '(new script)'); opt('@browser', '★ browser.ks (the browser itself)');
    for (const f of window.native.listScripts()) opt(f, f);
    fileSel.value = current || '@new';
  }
  function load(name) {
    current = name;
    if (name === '@browser') area.value = window.native.browserSource();
    else if (name === '@new' || !name) { current = null; area.value = SAMPLE; }
    else area.value = window.native.readScript(name) || '';
    refreshFiles();
  }
  fileSel.onchange = () => load(fileSel.value);
  async function run() {
    if (running) running.stop();
    out.replaceChildren(); stage.replaceChildren();
    if (current === '@browser') { log('This is browser.ks. Use "Save & restart browser" to apply it.', 'ed-info'); try { K.parse(area.value); log('✔ Syntax OK', 'ed-ok'); } catch (e) { log('✖ ' + e.message, 'ed-err'); } return; }
    const it = window.KompassRuntime.makeRuntime({
      rootHandle: new K.KHandle('box', stage), maxSteps: 500000,
      onPrint: (s) => log(s), onError: (e) => log('✖ ' + e.message, 'ed-err'),
      extra: {
        open_tab: { fn: ([u]) => { window.KompassMain.openTabFromPage(K.show(u)); return null; }, min: 1, max: 1 },
        search: { fn: ([q]) => { window.KompassMain.openTabFromPage(K.show(q)); return null; }, min: 1, max: 1 },
        lucky: { fn: ([q]) => { window.KompassMain.openTabFromPage(K.show(q)); return null; }, min: 1, max: 1 },
        open_url: { fn: ([u]) => { window.KompassMain.openTabFromPage(K.show(u)); return null; }, min: 1, max: 1 },
        engine: { fn: () => 'kompass', min: 0, max: 0 },
        // page_new(title) -> a box in a NEW kompass://script tab; draw a whole page into it with the UI built-ins
        page_new: { fn: async ([t]) => { const title = K.show(t === undefined ? 'Script page' : t).replace(/[^\w .,!?'()\-]/g, '').slice(0, 60) || 'Script page'; return await window.KompassMain.repl('page_for_script("' + title + '")'); }, min: 0, max: 1 },
      },
    });
    running = it; const t0 = performance.now();
    try { const r = await it.run(area.value); log('✔ done in ' + r.steps + ' steps, ' + Math.round(performance.now() - t0) + ' ms', 'ed-ok'); }
    catch (e) { log('✖ ' + e.message, 'ed-err'); }
  }
  function save() {
    if (current === '@browser') { try { K.parse(area.value); } catch (e) { log('✖ Not saved, syntax error: ' + e.message, 'ed-err'); return false; } window.native.saveBrowserSource(area.value); log('Saved browser.ks', 'ed-ok'); return true; }
    let name = current;
    if (!name) { name = nameBox.value.trim() || 'myscript.ks'; }
    current = window.native.writeScript(name, area.value); refreshFiles(); log('Saved ' + current + ' in ' + window.native.paths().scripts, 'ed-ok'); return true;
  }
  mk('▶ Run', run, 'primary');
  mk('■ Stop', () => { if (running) { running.stop(); log('stopped', 'ed-info'); } });
  mk('💾 Save', save);
  mk('📄 New page', () => {
    let n = (nameBox.value.trim() || 'mypage').replace(/\.ks$/, '').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 40) || 'mypage';
    if (window.native.readScript(n + '.ks') !== null && !confirm(n + '.ks exists. Open it as a page (OK) or cancel?')) return;
    if (window.native.readScript(n + '.ks') === null) window.native.writeScript(n + '.ks', PAGE_SAMPLE.replace(/NAME/g, n));
    load(n + '.ks');
    window.KompassMain.repl('new_tab("kompass://page/' + n + '")');
    log('Saved scripts/' + n + '.ks and opened kompass://page/' + n + ' — edit, 💾 Save, then ↻ reload the tab', 'ed-ok');
  });
  mk('↻ Save & restart browser', () => { if (current !== '@browser') { load('@browser'); log('Opened browser.ks — edit it, then press this again.', 'ed-info'); return; } if (save()) window.native.reloadApp(); });
  mk('⟲ Reset browser.ks', () => { if (confirm('Restore the original browser.ks?')) { window.native.saveBrowserSource(window.native.defaultSource()); window.native.reloadApp(); } });
  mk('📁 Data folder', () => window.native.openFolder());
  mk('📘 Learn', () => window.KompassMain.openTabFromPage('kompass://learn'));
  mk('{ } DevTools', () => window.KompassDevtools && window.KompassDevtools.toggle(true));
  mk('✕', () => api.toggle(false), 'ed-close');
  area.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.ctrlKey) { e.preventDefault(); run(); }
    if (e.key === 's' && e.ctrlKey) { e.preventDefault(); save(); }
    if (e.key === 'Tab') { e.preventDefault(); const s = area.selectionStart; area.setRangeText('  ', s, area.selectionEnd, 'end'); }
  });
  const api = {
    toggle(on) { root.hidden = on === undefined ? !root.hidden : !on; document.body.classList.toggle('ed-open', !root.hidden); if (!root.hidden) { if (!area.value) load(null); area.focus(); } },
    open(f) { api.toggle(true); if (f) load(f); },
    openAt(f, line) {
      api.open(f);
      const lines = area.value.split('\n'); const n = Math.max(1, Math.min(lines.length, line | 0));
      const start = lines.slice(0, n - 1).join('\n').length + (n > 1 ? 1 : 0);
      setTimeout(() => { area.focus(); area.setSelectionRange(start, start + lines[n - 1].length); area.scrollTop = Math.max(0, (n - 6) * 19.5); }, 30);
      log('Jumped to line ' + n + ' of ' + (f === '@browser' ? 'browser.ks' : f), 'ed-info');
    },
    log(s) { if (!root.hidden) log('[browser.ks] ' + s, 'ed-info'); },
  };
  refreshFiles();
  window.KompassEditor = api;
})();
