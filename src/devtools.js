/* Kompass KampfScript DevTools (F12 / Ctrl+Shift+I) — look inside the running browser.ks.
 * Separate from Chromium devtools for web pages (Ctrl+Shift+J / Settings → Page devtools).
 * Panels: Inspector · Console · Events · Debugger · Source · Performance · Errors.
 * Talks to the interpreter only through the hooks in lang.js (hooks.builtin / invoke / statement,
 * interp.callStack, interp.repl, interp.globals) — loaded before host.js so nothing is missed. */
(function () {
  'use strict';
  const K = window.KampfScript;
  const T0 = performance.now();
  const h = (tag, cls, txt) => { const e = document.createElement(tag); if (cls) e.className = cls; if (txt !== undefined) e.textContent = txt; return e; };
  const main = () => window.KompassMain;
  const short = (v, n) => { let s; try { s = K.show(v, true); } catch (e) { s = '?'; } n = n || 60; return s.length > n ? s.slice(0, n - 1) + '…' : s; };
  const argp = (v) => {
    if (typeof v === 'string') return JSON.stringify(v.length > 26 ? v.slice(0, 25) + '…' : v);
    if (Array.isArray(v)) return '[' + v.length + ' items]';
    if (v instanceof K.KMap) { const ks = [...v.m.keys()]; return '{' + ks.slice(0, 3).join(', ') + (ks.length > 3 ? ', …' : '') + '}'; }
    return short(v, 28);
  };
  const ts = () => ((performance.now() - T0) / 1000).toFixed(3);
  const CORE = new Set(Object.keys(new K.Interpreter({}).globals.vars));

  // ---------------- data collected all the time (cheap ring buffers)
  const events = []; let evDirty = true; let evPaused = false; let evSeq = 0;
  const perf = new Map(); let perfDirty = true;
  const errors = []; let errDirty = true;
  const conLines = [];
  function pushEv(kind, name, detail, line) {
    if (evPaused) return;
    events.push({ n: ++evSeq, t: ts(), kind, name, detail, line: line || 0 });
    if (events.length > 2000) events.splice(0, events.length - 1500);
    evDirty = true;
  }

  // ---------------- debugger state
  const bps = new Set();
  const dbg = { paused: null, resume: null, gate: null, openGate: null, stepping: false };
  function syncHook() {
    const m = main(); if (!m || !m.hooks) return;
    m.hooks.statement = (bps.size || dbg.stepping || dbg.paused) ? statementHook : null;
  }
  function statementHook(s, env, it) {
    if (dbg.paused) return dbg.gate;                     // another callback is paused: everyone waits
    if (!(dbg.stepping || bps.has(s.line))) return null;
    dbg.stepping = false;
    dbg.paused = { line: s.line, type: s.type, env, stack: it.callStack.map(f => ({ name: f.name, line: f.line, env: f.env })) };
    dbg.gate = new Promise(r => { dbg.openGate = r; });
    pushEv('pause', 'paused', (bps.has(s.line) ? 'breakpoint' : 'step') + ' at line ' + s.line, s.line);
    api.toggle(true); show('debugger');
    return new Promise(r => { dbg.resume = r; });
  }
  function resume(step) {
    if (!dbg.paused) { if (step) { dbg.stepping = true; syncHook(); render(); } return; }
    dbg.stepping = !!step;
    const r = dbg.resume, g = dbg.openGate;
    dbg.paused = null; dbg.resume = null; dbg.gate = null;
    syncHook(); r(); g(); render();
  }

  // ---------------- UI shell
  const root = h('div', 'dt-root'); root.hidden = true;
  const grip = h('div', 'dt-grip');
  const head = h('div', 'dt-head');
  const brand = h('div', 'dt-brand'); brand.append(h('span', 'dt-logo', '{ }'), h('span', '', 'KampfScript DevTools'));
  const tabsEl = h('div', 'dt-tabs');
  const meter = h('div', 'dt-meter');
  const pauseBtn = h('button', 'dt-btn', '⏸ Pause'); pauseBtn.title = 'Pause at the next KampfScript statement (F8)';
  const closeBtn = h('button', 'dt-btn dt-x', '✕'); closeBtn.title = 'Close (F12)';
  head.append(brand, tabsEl, meter, pauseBtn, closeBtn);
  const body = h('div', 'dt-body');
  root.append(grip, head, body);
  const panels = {}; const tabBtns = {};
  let active = 'inspector';
  const PANELS = [['inspector', 'Inspector'], ['console', 'Console'], ['events', 'Events'], ['debugger', 'Debugger'], ['source', 'Source / AST'], ['perf', 'Performance'], ['errors', 'Errors']];
  for (const [id, name] of PANELS) {
    const b = h('button', 'dt-tab', name); b.onclick = () => show(id); tabsEl.appendChild(b); tabBtns[id] = b;
    const p = h('div', 'dt-panel dt-' + id); p.hidden = true; body.appendChild(p); panels[id] = p;
  }
  const errBadge = h('span', 'dt-badge'); tabBtns.errors.appendChild(errBadge);
  pauseBtn.onclick = () => { if (dbg.paused) resume(false); else { dbg.stepping = true; syncHook(); pushEv('pause', 'pause requested', 'waiting for the next statement'); render(); } };
  closeBtn.onclick = () => api.toggle(false);
  // resize by dragging the grip
  grip.addEventListener('mousedown', (e) => {
    e.preventDefault(); const y0 = e.clientY, h0 = root.offsetHeight;
    const mv = (ev) => { const hh = Math.max(160, Math.min(window.innerHeight - 120, h0 + (y0 - ev.clientY))); document.body.style.setProperty('--dt-h', hh + 'px'); };
    const up = () => { window.removeEventListener('mousemove', mv); window.removeEventListener('mouseup', up); };
    window.addEventListener('mousemove', mv); window.addEventListener('mouseup', up);
  });
  function show(id) {
    if (!panels[id]) return; active = id;
    for (const k in panels) { panels[k].hidden = k !== id; tabBtns[k].classList.toggle('on', k === id); }
    render(true);
  }

  // ---------------- tree view (inspector + scopes)
  const expanded = new Set(['']);
  function kids(v) {
    if (Array.isArray(v)) return v.map((x, i) => [String(i), x]);
    if (v instanceof K.KMap) return [...v.m.entries()];
    if (v instanceof K.KFunc) return [['params', v.params.slice()], ['defined at line', v.body && v.body[0] ? v.body[0].line : '?']];
    if (v instanceof K.KHandle) return [['kind', v.kind], ['element', v.el && v.el.tagName ? '<' + v.el.tagName.toLowerCase() + (v.el.className ? '.' + String(v.el.className).split(' ').join('.') : '') + '>' : '?'], ['text', v.el && v.el.textContent !== undefined ? String(v.el.value !== undefined && v.el.tagName !== 'BUTTON' ? v.el.value : v.el.textContent).slice(0, 80) : '']];
    return null;
  }
  function preview(v) {
    if (Array.isArray(v)) return 'list(' + v.length + ') ' + short(v, 70);
    if (v instanceof K.KMap) return 'map{' + v.m.size + '} ' + short(v, 70);
    if (v instanceof K.KFunc) return 'fn ' + (v.name || '') + '(' + v.params.join(', ') + ')';
    if (v instanceof K.KBuiltin) return 'builtin ' + v.name + '()';
    if (v instanceof K.KHandle) return '<' + v.kind + '>';
    return short(v, 90);
  }
  function tnode(parent, name, v, path) {
    const key = path.join('\u0001');
    const ch = kids(v);
    const row = h('div', 'dt-tn');
    const tw = h('span', 'dt-tw', ch && ch.length ? (expanded.has(key) ? '▾' : '▸') : ' ');
    const nm = h('span', 'dt-k', name);
    const ty = h('span', 'dt-ty t-' + K.typeOf(v), K.typeOf(v));
    const pv = h('span', 'dt-v t-' + K.typeOf(v), preview(v));
    row.append(tw, nm, ty, pv); parent.appendChild(row);
    if (ch && ch.length) {
      row.classList.add('dt-exp');
      row.onclick = (e) => { e.stopPropagation(); if (expanded.has(key)) expanded.delete(key); else expanded.add(key); render(true); };
      if (expanded.has(key)) {
        const sub = h('div', 'dt-sub'); parent.appendChild(sub);
        const lim = ch.slice(0, 300);
        for (const [k, x] of lim) tnode(sub, k, x, path.concat(k));
        if (ch.length > lim.length) sub.appendChild(h('div', 'dt-dim', '… ' + (ch.length - lim.length) + ' more'));
      }
    }
  }
  function envVars(env, withCore) {
    const out = [];
    for (const [k, v] of env.vars) { if (!withCore && (v instanceof K.KBuiltin)) continue; out.push([k, v]); }
    return out.sort((a, b) => (a[1] instanceof K.KFunc) - (b[1] instanceof K.KFunc) || a[0].localeCompare(b[0]));
  }

  // ---------------- Inspector
  const insBar = h('div', 'dt-bar');
  const insFilter = h('input', 'dt-in'); insFilter.placeholder = 'Filter globals…';
  const insCore = h('label', 'dt-chk'); const insCoreBox = h('input'); insCoreBox.type = 'checkbox'; insCore.append(insCoreBox, ' built-ins');
  const insFns = h('label', 'dt-chk'); const insFnsBox = h('input'); insFnsBox.type = 'checkbox'; insFnsBox.checked = true; insFns.append(insFnsBox, ' functions');
  const insAuto = h('label', 'dt-chk'); const insAutoBox = h('input'); insAutoBox.type = 'checkbox'; insAutoBox.checked = true; insAuto.append(insAutoBox, ' live');
  const insRefresh = h('button', 'dt-btn', '↻'); insRefresh.onclick = () => render(true);
  const insInfo = h('span', 'dt-dim');
  insBar.append(insFilter, insFns, insCore, insAuto, insRefresh, insInfo);
  const insTree = h('div', 'dt-tree');
  panels.inspector.append(insBar, insTree);
  insFilter.oninput = insCoreBox.onchange = insFnsBox.onchange = () => render(true);
  function renderInspector() {
    const m = main(); if (!m) return;
    insTree.replaceChildren();
    const f = insFilter.value.trim().toLowerCase();
    let vars = envVars(m.globals, insCoreBox.checked).filter(([k, v]) => (!f || k.toLowerCase().includes(f)) && (insFnsBox.checked || !(v instanceof K.KFunc || v instanceof K.KBuiltin)));
    insInfo.textContent = vars.length + ' globals · click ▸ to expand maps & lists';
    for (const [k, v] of vars) tnode(insTree, k, v, ['g', k]);
  }

  // ---------------- Console / REPL
  const conOut = h('div', 'dt-con');
  const conIn = h('textarea', 'dt-repl'); conIn.rows = 2; conIn.spellcheck = false;
  conIn.placeholder = 'KampfScript in the live browser.ks — e.g.  tab_url(current)   settings.theme = "neon"; apply_look()   (Enter runs, Shift+Enter new line, ↑ history)';
  const conBar = h('div', 'dt-bar');
  const conClear = h('button', 'dt-btn', 'Clear'); conClear.onclick = () => { conLines.length = 0; conOut.replaceChildren(); };
  conBar.append(h('span', 'dt-dim', 'Runs in browser.ks globals (breakpoints are ignored here). print() output from browser.ks also appears here.'), conClear);
  const conRow = h('div', 'dt-conrow'); conRow.append(h('span', 'dt-prompt', '›'), conIn);
  panels.console.append(conBar, conOut, conRow);
  const hist = []; let histI = 0;
  function conAdd(cls, text) {
    conLines.push([cls, text]); if (conLines.length > 800) conLines.splice(0, 200);
    if (!root.hidden && active === 'console') { const d = h('div', 'dt-cl ' + cls, text); conOut.appendChild(d); conOut.scrollTop = conOut.scrollHeight; }
  }
  async function consoleRun(src) {
    if (!src.trim()) return;
    hist.push(src); histI = hist.length;
    conAdd('in', '› ' + src);
    try { const v = await main().repl(src); conAdd('val', '← ' + (v === null || v === undefined ? 'nil' : K.show(v, true))); }
    catch (e) { conAdd('err', '✖ ' + (e.message || e)); api.error(e, 'console'); }
    if (active === 'inspector') render(true);
  }
  conIn.addEventListener('keydown', (e) => {
    e.stopPropagation();
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); const s = conIn.value; conIn.value = ''; consoleRun(s); }
    else if (e.key === 'ArrowUp' && !conIn.value.includes('\n') && hist.length) { e.preventDefault(); histI = Math.max(0, histI - 1); conIn.value = hist[histI]; }
    else if (e.key === 'ArrowDown' && !conIn.value.includes('\n') && hist.length) { e.preventDefault(); histI = Math.min(hist.length, histI + 1); conIn.value = hist[histI] || ''; }
    else if (e.key === 'F12' || (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === 'i')) { e.preventDefault(); api.toggle(false); }
  });
  function renderConsole() {
    conOut.replaceChildren(); for (const [c, t] of conLines) conOut.appendChild(h('div', 'dt-cl ' + c, t));
    conOut.scrollTop = conOut.scrollHeight; setTimeout(() => conIn.focus(), 0);
  }

  // ---------------- Events log
  const evBar = h('div', 'dt-bar');
  const evFilter = h('input', 'dt-in'); evFilter.placeholder = 'Filter (e.g. tab_navigate, title, key:)';
  const mkChk = (txt, on) => { const l = h('label', 'dt-chk'); const b = h('input'); b.type = 'checkbox'; b.checked = on; l.append(b, ' ' + txt); evBar.appendChild(l); b.onchange = () => { evDirty = true; render(true); }; return b; };
  evBar.appendChild(evFilter);
  const evNative = mkChk('native calls', true), evEngine = mkChk('engine events', true), evCb = mkChk('callbacks', true), evCore = mkChk('core built-ins', false);
  const evPause = h('button', 'dt-btn', '⏸ Freeze'); evPause.onclick = () => { evPaused = !evPaused; evPause.textContent = evPaused ? '▶ Record' : '⏸ Freeze'; };
  const evClear = h('button', 'dt-btn', 'Clear'); evClear.onclick = () => { events.length = 0; evDirty = true; render(true); };
  evBar.append(evPause, evClear);
  const evTable = h('div', 'dt-evs');
  panels.events.append(evBar, evTable);
  evFilter.oninput = () => { evDirty = true; render(true); };
  const KIND = { native: ['→', 'native call'], core: ['·', 'core built-in'], engine: ['⇠', 'engine event'], cb: ['↪', 'callback'], pause: ['⏸', 'debugger'], err: ['✖', 'error'] };
  function renderEvents() {
    if (!evDirty) return; evDirty = false;
    const f = evFilter.value.trim().toLowerCase();
    const rows = events.filter(e => (e.kind !== 'native' || evNative.checked) && (e.kind !== 'engine' || evEngine.checked) && (e.kind !== 'cb' || evCb.checked) && (e.kind !== 'core' || evCore.checked) && (!f || (e.name + ' ' + e.detail).toLowerCase().includes(f))).slice(-400);
    evTable.replaceChildren();
    for (const e of rows) {
      const r = h('div', 'dt-ev k-' + e.kind);
      r.append(h('span', 'dt-evt', e.t + 's'), h('span', 'dt-evk', KIND[e.kind][0]), h('span', 'dt-evn', e.name), h('span', 'dt-evd', e.detail), h('span', 'dt-evl', e.line ? 'line ' + e.line : ''));
      r.title = KIND[e.kind][1];
      if (e.line) { r.classList.add('dt-link'); r.onclick = () => openSource(e.line); }
      evTable.appendChild(r);
    }
    evTable.scrollTop = evTable.scrollHeight;
  }

  // ---------------- Debugger
  const dbBar = h('div', 'dt-bar');
  const dbResume = h('button', 'dt-btn go', '▶ Resume (F8)'); dbResume.onclick = () => resume(false);
  const dbStep = h('button', 'dt-btn', '⤵ Step (F10)'); dbStep.onclick = () => resume(true);
  const bpIn = h('input', 'dt-in dt-short'); bpIn.placeholder = 'line #';
  const bpAdd = h('button', 'dt-btn', '+ Breakpoint'); bpAdd.onclick = () => { const n = parseInt(bpIn.value, 10); if (n > 0) { bps.add(n); bpIn.value = ''; syncHook(); render(true); } };
  bpIn.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter') bpAdd.click(); });
  const bpClear = h('button', 'dt-btn', 'Clear breakpoints'); bpClear.onclick = () => { bps.clear(); syncHook(); render(true); };
  dbBar.append(dbResume, dbStep, bpIn, bpAdd, bpClear);
  const dbGrid = h('div', 'dt-dbgrid');
  const dbLeft = h('div', 'dt-dbcol'), dbMid = h('div', 'dt-dbcol'), dbRight = h('div', 'dt-dbcol');
  dbGrid.append(dbLeft, dbMid, dbRight);
  panels.debugger.append(dbBar, dbGrid);
  const srcLines = () => (window.native ? window.native.browserSource() : '').split('\n');
  function renderDebugger() {
    const m = main(); if (!m) return;
    dbResume.disabled = !dbg.paused; dbStep.textContent = dbg.paused ? '⤵ Step (F10)' : '⤵ Pause at next';
    dbLeft.replaceChildren(h('div', 'dt-h', 'Status'));
    const st = h('div', 'dt-kv');
    const kv = (k, v) => { st.append(h('span', 'dt-dim', k), h('span', '', String(v))); };
    kv('state', dbg.paused ? '⏸ paused at line ' + dbg.paused.line + ' (' + dbg.paused.type + ')' : dbg.stepping ? 'waiting for next statement…' : '▶ running');
    kv('total steps', m.totalSteps.toLocaleString());
    kv('steps this callback', m.steps.toLocaleString() + ' / ' + m.maxSteps.toLocaleString());
    kv('call depth', m.depth);
    kv('breakpoints', bps.size ? [...bps].sort((a, b) => a - b).join(', ') : 'none');
    dbLeft.appendChild(st);
    dbLeft.appendChild(h('div', 'dt-h', 'Breakpoints'));
    if (!bps.size) dbLeft.appendChild(h('div', 'dt-dim', 'Click a line number in Source / AST, or type a line above.'));
    const lines = srcLines();
    for (const n of [...bps].sort((a, b) => a - b)) {
      const r = h('div', 'dt-bp'); r.append(h('span', 'dt-dot', '●'), h('span', 'dt-ln', String(n)), h('span', 'dt-code', (lines[n - 1] || '').trim().slice(0, 60)));
      const x = h('button', 'dt-btn dt-mini', '✕'); x.onclick = () => { bps.delete(n); syncHook(); render(true); }; r.appendChild(x);
      dbLeft.appendChild(r);
    }
    dbMid.replaceChildren(h('div', 'dt-h', 'Call stack'));
    const stack = dbg.paused ? dbg.paused.stack : m.callStack;
    if (!stack.length) dbMid.appendChild(h('div', 'dt-dim', dbg.paused ? '(top level of browser.ks)' : 'Nothing running right now — browser.ks is idle, waiting for events. Pause or set a breakpoint to catch it in action.'));
    if (dbg.paused && stack.length) dbMid.appendChild(h('div', 'dt-dim', 'Frames of callbacks that are waiting while paused are included.'));
    if (dbg.paused) { const r = h('div', 'dt-frame top'); r.append(h('span', '', '▶ line ' + dbg.paused.line), h('span', 'dt-dim', ' current statement')); r.onclick = () => openSource(dbg.paused.line); dbMid.appendChild(r); }
    for (const f of stack.slice().reverse()) { const r = h('div', 'dt-frame'); r.append(h('span', 'dt-fn', f.name + '()'), h('span', 'dt-dim', ' called from line ' + f.line)); r.onclick = () => openSource(f.line); dbMid.appendChild(r); }
    if (dbg.paused) {
      dbMid.appendChild(h('div', 'dt-h', 'Source'));
      const pre = h('div', 'dt-ctx');
      for (let i = Math.max(1, dbg.paused.line - 4); i <= Math.min(lines.length, dbg.paused.line + 4); i++) {
        const r = h('div', 'dt-sl' + (i === dbg.paused.line ? ' cur' : '') + (bps.has(i) ? ' bp' : '')); r.append(h('span', 'dt-ln', String(i)), h('span', 'dt-code', lines[i - 1])); pre.appendChild(r);
      }
      dbMid.appendChild(pre);
    }
    dbRight.replaceChildren(h('div', 'dt-h', dbg.paused ? 'Scope (innermost first)' : 'Scope'));
    if (!dbg.paused) { dbRight.appendChild(h('div', 'dt-dim', 'Local variables appear here while paused. Globals are in the Inspector.')); return; }
    let env = dbg.paused.env, depth = 0;
    while (env && env !== m.globals && depth < 12) {
      const vars = envVars(env, false);
      const box = h('div', 'dt-scope'); box.appendChild(h('div', 'dt-dim', depth === 0 ? 'block' : 'outer ' + depth));
      if (!vars.length) box.appendChild(h('div', 'dt-dim', '(empty)'));
      for (const [k, v] of vars) tnode(box, k, v, ['s', depth, k]);
      dbRight.appendChild(box); env = env.parent; depth++;
    }
    dbRight.appendChild(h('div', 'dt-dim', '+ ' + envVars(m.globals, false).length + ' globals (Inspector)'));
  }

  // ---------------- Source / tokens / AST
  const srBar = h('div', 'dt-bar');
  const srSel = h('select', 'dt-in');
  const srMode = h('div', 'dt-seg');
  let srView = 'code';
  for (const [v, t] of [['code', 'Code'], ['tokens', 'Tokens'], ['ast', 'AST']]) { const b = h('button', 'dt-segb', t); b.dataset.v = v; b.onclick = () => { srView = v; render(true); }; srMode.appendChild(b); }
  const srInfo = h('span', 'dt-dim');
  srBar.append(srSel, srMode, srInfo);
  const srPaste = h('textarea', 'dt-paste'); srPaste.spellcheck = false; srPaste.placeholder = 'Paste any KampfScript here…'; srPaste.value = 'let x = [1, 2, 3]\nfn total(xs) {\n  let t = 0\n  for v in xs { t += v }\n  return t\n}\nprint(total(x))';
  srPaste.addEventListener('keydown', (e) => e.stopPropagation());
  srPaste.oninput = () => render(true);
  const srOut = h('div', 'dt-src');
  panels.source.append(srBar, srPaste, srOut);
  srSel.onchange = () => render(true);
  let srScrollTo = 0;
  function srFiles() {
    const cur = srSel.value || '@browser';
    srSel.replaceChildren();
    const opt = (v, t) => { const o = h('option', '', t); o.value = v; srSel.appendChild(o); };
    opt('@browser', 'browser.ks (running)'); opt('@paste', '(paste your own .ks)');
    try { for (const f of window.native.listScripts()) opt(f, 'scripts/' + f); } catch (e) {}
    srSel.value = cur;
  }
  function srText() {
    const v = srSel.value;
    if (v === '@paste') return srPaste.value;
    if (v === '@browser' || !v) return window.native.browserSource();
    return window.native.readScript(v) || '';
  }
  function astNode(parent, n, label, path) {
    const key = 'ast\u0001' + path.join('\u0001');
    const isNode = n && typeof n === 'object' && !Array.isArray(n) && n.type;
    const isArr = Array.isArray(n);
    const row = h('div', 'dt-tn');
    if (!isNode && !isArr) { row.append(h('span', 'dt-tw', ' '), h('span', 'dt-k', label), h('span', 'dt-v t-' + typeof n, JSON.stringify(n))); parent.appendChild(row); return; }
    const open = expanded.has(key) || path.length < 2;
    const summary = isArr ? '[' + n.length + ']' : n.type + (n.name ? ' ' + n.name : n.op ? ' ' + n.op : n.type === 'Lit' ? ' ' + JSON.stringify(n.value) : '');
    row.append(h('span', 'dt-tw', (isArr ? n.length : 1) ? (open ? '▾' : '▸') : ' '), h('span', 'dt-k', label), h('span', 'dt-ast t-' + (isArr ? 'list' : 'node'), summary));
    if (isNode && n.line) { const l = h('span', 'dt-evl dt-link', 'line ' + n.line); l.onclick = (e) => { e.stopPropagation(); srView = 'code'; srScrollTo = n.line; render(true); }; row.appendChild(l); }
    row.classList.add('dt-exp'); row.onclick = (e) => { e.stopPropagation(); if (open) { expanded.delete(key); if (path.length < 2) expanded.add(key + '\u0001closed'); } else expanded.add(key); render(true); };
    parent.appendChild(row);
    if (!open || expanded.has(key + '\u0001closed')) return;
    const sub = h('div', 'dt-sub'); parent.appendChild(sub);
    if (isArr) n.slice(0, 400).forEach((x, i) => astNode(sub, x, String(i), path.concat(i)));
    else for (const k of Object.keys(n)) { if (k === 'type' || k === 'line') continue; astNode(sub, n[k], k, path.concat(k)); }
  }
  function renderSource() {
    srFiles();
    for (const b of srMode.children) b.classList.toggle('on', b.dataset.v === srView);
    srPaste.hidden = srSel.value !== '@paste';
    const text = srText(); const isBrowser = srSel.value === '@browser' || !srSel.value;
    srOut.replaceChildren();
    if (srView === 'code') {
      const lines = text.split('\n');
      srInfo.textContent = lines.length + ' lines' + (isBrowser ? ' · click a line number to toggle a breakpoint' : '');
      let err = null; try { K.parse(text); } catch (e) { err = e; }
      if (err) srOut.appendChild(h('div', 'dt-cl err', '✖ ' + err.message));
      const frag = document.createDocumentFragment();
      lines.forEach((l, i) => {
        const n = i + 1; const r = h('div', 'dt-sl' + (bps.has(n) && isBrowser ? ' bp' : '') + (dbg.paused && isBrowser && dbg.paused.line === n ? ' cur' : '') + (err && err.line === n ? ' errl' : ''));
        const ln = h('span', 'dt-ln', String(n));
        if (isBrowser) ln.onclick = () => { if (bps.has(n)) bps.delete(n); else bps.add(n); syncHook(); r.classList.toggle('bp', bps.has(n)); };
        r.append(ln, h('span', 'dt-code', l)); frag.appendChild(r);
        r.dataset.n = n;
      });
      srOut.appendChild(frag);
      if (srScrollTo) { const t = srOut.querySelector('[data-n="' + srScrollTo + '"]'); if (t) { t.classList.add('flash'); srOut.scrollTop = t.offsetTop - srOut.clientHeight / 3; } srScrollTo = 0; }
    } else if (srView === 'tokens') {
      let toks; try { toks = K.tokenize(text); } catch (e) { srOut.appendChild(h('div', 'dt-cl err', '✖ ' + e.message)); return; }
      srInfo.textContent = toks.length + ' tokens' + (toks.length > 3000 ? ' (showing first 3000)' : '');
      const wrap = h('div', 'dt-toks'); let line = 0, lineEl = null;
      for (const t of toks.slice(0, 3000)) {
        if (t.line !== line) { line = t.line; lineEl = h('div', 'dt-tokline'); lineEl.appendChild(h('span', 'dt-ln', String(line))); wrap.appendChild(lineEl); }
        if (t.type === 'nl' || t.type === 'eof') continue;
        const c = h('span', 'dt-tok tk-' + t.type, t.type === 'str' ? JSON.stringify(t.value) : String(t.value)); c.title = t.type + ' @ line ' + t.line; lineEl.appendChild(c);
      }
      srOut.appendChild(wrap);
    } else {
      let ast; try { ast = K.parse(text); } catch (e) { srOut.appendChild(h('div', 'dt-cl err', '✖ ' + e.message)); return; }
      srInfo.textContent = ast.body.length + ' top-level statements · click ▸ to expand';
      astNode(srOut, ast.body, 'Program', ['p']);
    }
  }
  function openSource(line) { api.toggle(true); srSel.value = '@browser'; srView = 'code'; srScrollTo = line; show('source'); }

  // ---------------- Performance
  const pfBar = h('div', 'dt-bar');
  const pfReset = h('button', 'dt-btn', 'Reset'); pfReset.onclick = () => { perf.clear(); perfDirty = true; render(true); };
  const pfInfo = h('span', 'dt-dim');
  pfBar.append(pfInfo, pfReset);
  const pfTable = h('div', 'dt-pf');
  panels.perf.append(pfBar, pfTable);
  let lastSteps = 0, lastT = performance.now(), rate = 0;
  function renderPerf() {
    const rows = [...perf.entries()].sort((a, b) => b[1].steps - a[1].steps);
    const max = rows.length ? rows[0][1].steps : 1;
    pfInfo.textContent = 'Steps per event handler (each KampfScript statement or call = 1 step) · now ' + Math.round(rate).toLocaleString() + ' steps/s';
    pfTable.replaceChildren();
    const hd = h('div', 'dt-pfr hd'); for (const t of ['handler / event', 'calls', 'total steps', 'avg', 'max', 'ms', 'errors', '']) hd.appendChild(h('span', '', t)); pfTable.appendChild(hd);
    for (const [k, p] of rows.slice(0, 200)) {
      const r = h('div', 'dt-pfr');
      const barW = h('span', 'dt-pfbar'); const fill = h('i'); fill.style.width = Math.max(2, Math.round(100 * p.steps / max)) + '%'; barW.appendChild(fill);
      r.append(h('span', 'dt-fn', k), h('span', '', p.calls), h('span', '', p.steps.toLocaleString()), h('span', '', Math.round(p.steps / p.calls)), h('span', '', p.max), h('span', '', p.ms), h('span', p.errors ? 'dt-red' : '', p.errors), barW);
      pfTable.appendChild(r);
    }
    if (!rows.length) pfTable.appendChild(h('div', 'dt-dim', 'No callbacks yet — click around the browser.'));
  }

  // ---------------- Errors
  const erBar = h('div', 'dt-bar');
  const erClear = h('button', 'dt-btn', 'Clear'); erClear.onclick = () => { errors.length = 0; errDirty = true; const b = document.getElementById('boot-error'); if (b) b.hidden = true; render(true); };
  erBar.append(h('span', 'dt-dim', 'Errors from browser.ks, its callbacks and the console. Click one to jump to the line in the editor.'), erClear);
  const erList = h('div', 'dt-errs');
  panels.errors.append(erBar, erList);
  function renderErrors() {
    erList.replaceChildren();
    if (!errors.length) erList.appendChild(h('div', 'dt-dim', 'No errors. 🎉'));
    for (const e of errors.slice().reverse()) {
      const r = h('div', 'dt-err'); r.append(h('span', 'dt-evt', e.t + 's'), h('span', 'dt-src-tag', e.where), h('span', 'dt-red', e.msg), h('span', 'dt-evl', e.line ? 'line ' + e.line + ' ↗' : ''));
      if (e.line && e.where !== 'console') { r.classList.add('dt-link'); r.onclick = () => window.KompassEditor && window.KompassEditor.openAt('@browser', e.line); }
      erList.appendChild(r);
    }
  }

  // ---------------- render loop
  let lastRender = 0;
  function render(force) {
    if (root.hidden) return;
    const m = main();
    if (m) meter.textContent = 'Σ ' + m.totalSteps.toLocaleString() + ' steps · ' + Math.round(rate).toLocaleString() + '/s · depth ' + m.depth + (dbg.paused ? ' · ⏸ line ' + dbg.paused.line : '');
    pauseBtn.textContent = dbg.paused ? '▶ Resume' : '⏸ Pause'; pauseBtn.classList.toggle('go', !!dbg.paused);
    errBadge.textContent = errors.length ? String(errors.length) : ''; root.classList.toggle('paused', !!dbg.paused);
    if (!force && performance.now() - lastRender < 400) return; lastRender = performance.now();
    if (active === 'inspector') { if (force || insAutoBox.checked) renderInspector(); }
    else if (active === 'console') { if (force) renderConsole(); }
    else if (active === 'events') { if (force) evDirty = true; renderEvents(); }
    else if (active === 'debugger') renderDebugger();
    else if (active === 'source') { if (force) renderSource(); }
    else if (active === 'perf') { if (force || perfDirty) { perfDirty = false; renderPerf(); } }
    else if (active === 'errors') { if (force || errDirty) { errDirty = false; renderErrors(); } }
  }
  setInterval(() => {
    const m = main(); const now = performance.now();
    if (m) { rate = (m.totalSteps - lastSteps) * 1000 / Math.max(1, now - lastT); lastSteps = m.totalSteps; lastT = now; }
    if (!root.hidden) render(false);
  }, 1000);
  window.addEventListener('keydown', (e) => {
    if (root.hidden) return;
    if (e.key === 'F8') { e.preventDefault(); if (dbg.paused) resume(false); else pauseBtn.click(); }
    if (e.key === 'F10') { e.preventDefault(); resume(true); }
  });

  // ---------------- public API (called by host.js hooks, browser.ks via ks_devtools(), and tests)
  const api = {
    builtin(name, args, line) {
      const m = main(); const native = m && m.nativeNames ? m.nativeNames.has(name) : !CORE.has(name);
      pushEv(native ? 'native' : 'core', name + '(' + args.map(argp).join(', ') + ')', '', line);
    },
    event(ev, id, val) { pushEv('engine', 'on_tab_event ' + ev, 'tab ' + id + (val !== undefined && val !== null ? ' · ' + short(val, 70) : '')); },
    invoked(label, steps, ms, err) {
      const p = perf.get(label) || { calls: 0, steps: 0, max: 0, ms: 0, errors: 0 };
      p.calls++; p.steps += steps; p.max = Math.max(p.max, steps); p.ms += ms; if (err) p.errors++;
      perf.set(label, p); perfDirty = true;
      pushEv('cb', label, steps + ' steps · ' + ms + ' ms' + (err ? ' · error' : ''));
      if (!root.hidden) render();
    },
    print(s) { conAdd('out', String(s)); },
    error(e, where) {
      const msg = e && (e.kmsg || e.message) || String(e);
      errors.push({ t: ts(), msg, line: e && e.line || 0, where: where || 'browser.ks' });
      if (errors.length > 300) errors.shift();
      errDirty = true; pushEv('err', 'error', msg, e && e.line);
      if (where !== 'console') conAdd('err', '✖ ' + (e && e.message || msg));
      render();
    },
    toggle(on) {
      root.hidden = on === undefined ? !root.hidden : !on;
      document.body.classList.toggle('dt-open', !root.hidden);
      if (!root.hidden) show(active);
    },
    show,
    get open() { return !root.hidden; },
    expandPath(path) { let p = ['g']; for (const k of path) { p = p.concat(k); expanded.add(p.join('\u0001')); } render(true); },
    consoleRun(src) { show('console'); return consoleRun(src); },
    breakpoints: bps, setBreakpoint(n, on) { if (on === false) bps.delete(n); else bps.add(n); syncHook(); render(true); },
    resume,
    get paused() { return dbg.paused; },
    openSource,
  };
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(root));
  if (document.body) document.body.appendChild(root);
  window.KompassDevtools = api;
})();
