/* Kompass host runtime: runs resources/browser.ks with KampfScript and provides native built-ins.
 * The host owns no browser logic: tabs, address bar, bookmarks, history, start page are all in browser.ks. */
(function () {
  'use strict';
  const K = window.KampfScript;
  const { KError, KMap, KHandle } = K;
  const PROXY = 'https://kampfos-proxy.kampfguy.workers.dev';
  const B = (fn, min, max) => ({ fn, min: min || 0, max: max === undefined ? 99 : max });

  // ---------- value conversion JS <-> KampfScript
  function toK(v) {
    if (v === undefined || v === null) return null;
    if (Array.isArray(v)) return v.map(toK);
    if (typeof v === 'object') { const m = new KMap(); for (const k of Object.keys(v)) m.m.set(k, toK(v[k])); return m; }
    return v;
  }
  function toJS(v) {
    if (Array.isArray(v)) return v.map(toJS);
    if (v instanceof KMap) { const o = {}; for (const [k, x] of v.m) o[k] = toJS(x); return o; }
    if (v instanceof KHandle || (v && v.call)) return null;
    return v;
  }
  const S = (v) => K.show(v);
  const addCls = (e, s) => { for (const c of s.split(/\s+/).filter(Boolean)) e.classList.add(styleOk(c)); };
  const styleOk = (s) => { if (!/^[a-zA-Z0-9_-]+$/.test(s)) throw new KError('bad style name: ' + s); return s; };


  // v1.3 games: global keyboard state (key_down) + per-page keypress handlers
  const KEYS = new Set(); const keyRuntimes = new Set();
  const normKey = (k) => { k = String(k || '').toLowerCase(); return k === ' ' ? 'space' : k.startsWith('arrow') ? k.slice(5) : k === 'esc' ? 'escape' : k; };
  const typing = (e) => e.target && e.target.closest && e.target.closest('input,textarea,select,[contenteditable]');
  window.addEventListener('keydown', (e) => {
    if (typing(e)) return; const k = normKey(e.key); KEYS.add(k);
    for (const r of keyRuntimes) { if (!r.alive()) { keyRuntimes.delete(r); continue; } if (r.visible()) { if (['space', 'up', 'down', 'left', 'right'].includes(k)) e.preventDefault(); if (!e.repeat) r.press(k); } }
  }, true);
  window.addEventListener('keyup', (e) => KEYS.delete(normKey(e.key)), true);
  window.addEventListener('blur', () => KEYS.clear());
  const COLOR = /^(#[0-9a-fA-F]{3,8}|(rgb|rgba|hsl|hsla)\([0-9., %]+\)|[a-zA-Z]{3,20})$/;
  const CSS_PROPS = ['color', 'background', 'background-color', 'font-family', 'font-size', 'font-weight', 'font-style', 'letter-spacing', 'line-height', 'text-align', 'text-transform', 'text-shadow',
    'padding', 'margin', 'width', 'height', 'max-width', 'min-width', 'min-height', 'border', 'border-radius', 'box-shadow', 'gap', 'opacity', 'justify-content', 'align-items', 'flex-wrap', 'flex', 'cursor',
    // v1.3 layout for app-like pages (floating panels, overlays)
    'position', 'left', 'top', 'right', 'bottom', 'z-index', 'display', 'flex-direction', 'overflow', 'overflow-y', 'max-height', 'pointer-events', 'white-space', 'border-color', 'border-top', 'border-bottom', 'transform', 'transition', 'backdrop-filter', 'font-variant-numeric', 'accent-color', 'user-select', 'align-self', 'inset', 'margin-left', 'margin-right', 'margin-top', 'margin-bottom', 'padding-left', 'padding-right', 'padding-top', 'padding-bottom', 'border-left', 'border-right', 'text-overflow', 'vertical-align', 'text-decoration', 'outline', 'box-sizing', 'word-break'];
  const FONTS = ['Arial', 'Helvetica', 'Georgia', 'Times New Roman', 'Verdana', 'Trebuchet MS', 'Courier New', 'Segoe UI', 'Kompass Sans', 'Kompass Mono', 'system-ui', 'serif', 'sans-serif', 'monospace', 'cursive'];
  function closePopups() { for (const p of document.querySelectorAll('.ks-popup')) p.remove(); }
  window.addEventListener('mousedown', (e) => { if (!e.target.closest || !e.target.closest('.ks-popup')) closePopups(); }, true);
  window.addEventListener('keydown', (e) => { if (e.key === 'Escape') closePopups(); }, true);
  function cssLen(v, who) {
    if (typeof v === 'number') return v + 'px';
    const s = S(v); if (!/^(\d+(\.\d+)?(px|%|em|rem|vh|vw)|auto)$/.test(s)) throw new KError(who + ': size must be a number (pixels) or like "50%", "2em", "auto"'); return s;
  }
  function cssOk(prop, v, who) {
    const p = prop.toLowerCase(); if (!CSS_PROPS.includes(p)) throw new KError(who + ': property not allowed: ' + prop + ' (see css_props())');
    const val = typeof v === 'number' ? (['opacity', 'font-weight', 'line-height', 'flex', 'z-index'].includes(p) ? String(v) : v + 'px') : S(v);
    if (val.length > 160 || !/^[#a-zA-Z0-9 .,%()\-"'\/]*$/.test(val) || /url|image|expression|@import|\\/i.test(val)) throw new KError(who + ': value not allowed: ' + val);
    return [p, val];
  }

  const R = window.KompassRender.createRenderer();
  window.__ksRender = R;
  function makeRuntime(opts) {
    let interp;
    const cb = (f, label) => (...args) => R.run(() => interp.invoke(f, args.map(toK), label));
    const HEX = /^#[0-9a-fA-F]{3,8}$/;
    const THEMES = ['brass', 'midnight', 'neon', 'paper'];
    const isFn = (f) => f && (f instanceof K.KFunc || f instanceof K.KBuiltin);
    const secretEl = (x, who) => { if (!(x instanceof KHandle) || x.kind !== 'secret') throw new KError(who + ' needs a pw_input() field'); return x.el; };
    const el = (x, who) => { if (!(x instanceof KHandle) || !x.el) throw new KError(who + ' needs a UI element, got ' + K.typeOf(x)); return x.el; };
    const make = (kind, tag, cls, parent, who) => {
      const e = document.createElement(tag); if (cls) e.className = cls;
      R.target(el(parent, who)).appendChild(e); const h = new KHandle(kind, e); R.track(e, h); return h;
    };
    // v1.3: a page's timers / frame loops / key handlers stop by themselves once its stage leaves the screen
    const rootEl = () => opts.rootHandle && opts.rootHandle.el;
    const alive = () => !interp.stopped && (!opts.sandbox || !!(rootEl() && rootEl().isConnected));
    const visible = () => { const r = rootEl(); return !r || !r.getClientRects || r.getClientRects().length > 0; };
    const frames = new Map(); let frameIds = 1;
    const col = (c, who) => { const v = S(c); if (!COLOR.test(v)) throw new KError(who + ': color must be like "#ff4500", "rgba(0,0,0,0.5)" or a name like "white"'); return v; };
    const cv = (x, who) => { if (!(x instanceof KHandle) || x.kind !== 'canvas') throw new KError(who + ' needs a canvas from canvas(parent), got ' + K.typeOf(x)); R.touched(x); return x; };
    const N = (v, who, d) => { if (v === undefined || v === null) { if (d !== undefined) return d; throw new KError(who + ': missing a number'); } if (typeof v !== 'number' || !isFinite(v)) { if (typeof v === 'number') return 0; throw new KError(who + ': expected a number, got ' + K.typeOf(v)); } return v; };
    const pts = (l, who) => { if (!Array.isArray(l)) throw new KError(who + ' needs a list of points like [[x, y], ...] or [vec(x, y), ...]'); return l.map(p => Array.isArray(p) ? [+p[0] || 0, +p[1] || 0] : p instanceof KMap ? [+p.m.get('x') || 0, +p.m.get('y') || 0] : [0, 0]); };
    // a color can also be a LIST: ["#333", "#999", "#333"] = left-to-right gradient, ["down", c1, c2] = top-to-bottom
    const style = (g, color, box, who) => {
      if (!Array.isArray(color)) return col(color, who);
      let cs = color.map(S), down = false; if (cs[0] === 'down' || cs[0] === 'across') { down = cs[0] === 'down'; cs = cs.slice(1); }
      if (cs.length < 2) throw new KError(who + ': a gradient needs at least 2 colors');
      const [x, y, w, h] = box || [0, 0, 100, 100]; const gr = down ? g.createLinearGradient(x, y, x, y + h) : g.createLinearGradient(x, y, x + w, y);
      cs.forEach((c, i) => gr.addColorStop(i / (cs.length - 1), col(c, who))); return gr;
    };
    const paint = (g, color, lw, who, box) => { if (lw === undefined || lw === null) { g.fillStyle = style(g, color, box, who); g.fill(); } else { g.strokeStyle = style(g, color, box, who); g.lineWidth = N(lw, who); g.stroke(); } };
    const bboxOf = (P) => { let a = Infinity, b = Infinity, c = -Infinity, d = -Infinity; for (const q of P) { a = Math.min(a, q[0]); b = Math.min(b, q[1]); c = Math.max(c, q[0]); d = Math.max(d, q[1]); } return [a, b, c - a, d - b]; };
    const fitCanvas = (h) => {
      const c = h.el, r = c.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
      const w = Math.max(1, Math.round((h.fixedW || r.width) * dpr)), hh = Math.max(1, Math.round((h.fixedH || r.height) * dpr));
      R.sizeBack(h, w, hh);   // only the back buffer; the visible canvas is resized at commit, together with the redraw
      h.w = w / dpr; h.h = hh / dpr; h.g.setTransform(dpr, 0, 0, dpr, 0, 0); h.depth = 0;
    };
    const ui = {
      body: B(() => opts.rootHandle, 0, 0),
      box: B(([p, s]) => { const h = make('box', 'div', 'ks-box', p, 'box()'); if (s) addCls(h.el, S(s)); return h; }, 1, 2),
      row: B(([p, s]) => { const h = make('row', 'div', 'ks-row', p, 'row()'); if (s) addCls(h.el, S(s)); return h; }, 1, 2),
      col: B(([p, s]) => { const h = make('col', 'div', 'ks-col', p, 'col()'); if (s) addCls(h.el, S(s)); return h; }, 1, 2),
      label: B(([p, t, s]) => { const h = make('label', 'span', 'ks-label', p, 'label()'); h.el.textContent = S(t); if (s) addCls(h.el, S(s)); return h; }, 2, 3),
      heading: B(([p, t, s]) => { const h = make('heading', 'h1', 'ks-heading', p, 'heading()'); h.el.textContent = S(t); if (s) addCls(h.el, S(s)); return h; }, 2, 3),
      button: B(([p, t, f, s]) => { const h = make('button', 'button', 'ks-button', p, 'button()'); h.el.textContent = S(t); if (s) addCls(h.el, S(s)); if (isFn(f)) h.el.addEventListener('click', (e) => { e.stopPropagation(); cb(f, 'click: ' + S(t).slice(0, 24))(); }); return h; }, 2, 4),
      link: B(([p, t, f, s]) => { const h = make('link', 'a', 'ks-link', p, 'link()'); h.el.textContent = S(t); h.el.href = '#'; if (s) addCls(h.el, S(s)); if (isFn(f)) h.el.addEventListener('click', (e) => { e.preventDefault(); cb(f)(); }); return h; }, 2, 4),
      textbox: B(([p, ph, onEnter, s]) => {
        const h = make('textbox', 'input', 'ks-textbox', p, 'textbox()'); h.el.placeholder = ph ? S(ph) : ''; h.el.spellcheck = false;
        if (s) addCls(h.el, S(s));
        if (isFn(onEnter)) h.el.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); cb(onEnter, 'enter: ' + (h.el.placeholder || 'textbox').slice(0, 24))(h.el.value); } });
        h.el.addEventListener('focus', () => setTimeout(() => h.el.select(), 0));
        return h;
      }, 1, 4),
      image: B(([p, url, s]) => { const h = make('image', 'img', 'ks-image', p, 'image()'); const u = S(url); if (/^(https?:|data:image\/)/.test(u)) h.el.src = u; if (s) addCls(h.el, S(s)); h.el.onerror = () => { h.el.style.visibility = 'hidden'; }; return h; }, 2, 3),
      codebox: B(([p, t, s]) => {
        const h = make('textbox', 'textarea', 'ks-codebox', p, 'codebox()'); h.el.value = t ? S(t) : ''; h.el.spellcheck = false;
        if (s) addCls(h.el, S(s));
        const fit = () => { if (h.el.classList.contains('fill')) return; h.el.style.height = 'auto'; h.el.style.height = Math.min(420, h.el.scrollHeight + 4) + 'px'; };
        h.el.addEventListener('input', fit); setTimeout(fit, 0);
        h.el.addEventListener('keydown', (e) => { if (e.key === 'Tab') { e.preventDefault(); const i = h.el.selectionStart; h.el.setRangeText('  ', i, h.el.selectionEnd, 'end'); } e.stopPropagation(); });
        return h;
      }, 1, 3),
      video: B(([p, url, s]) => {
        const h = make('video', 'video', 'ks-video', p, 'video()'); const u = S(url);
        if (!/^(https:|file:)/.test(u)) throw new KError('video(): only https: or local file: URLs');
        h.el.src = u; h.el.controls = true; h.el.preload = 'metadata'; if (s) addCls(h.el, S(s));
        return h;
      }, 2, 3),
      setcolor: B(([x, c, which]) => { const e = el(x, 'setcolor()'); const v = S(c); if (!HEX.test(v)) throw new KError('setcolor(): use a hex color like #c9a227'); if (which === 'text') e.style.color = v; else e.style.background = v; return null; }, 2, 3),
      set_theme: B(([n]) => { const v = S(n).toLowerCase(); if (!THEMES.includes(v)) throw new KError('set_theme(): one of ' + THEMES.join(', ')); document.body.dataset.theme = v; return null; }, 1, 1),
      themes: B(() => THEMES.slice(), 0, 0),
      set_accent: B(([c]) => { const v = c ? S(c) : ''; if (v === '') { document.body.style.removeProperty('--acc'); return null; } if (!HEX.test(v)) throw new KError('set_accent(): use a hex color like #c9a227'); document.body.style.setProperty('--acc', v); return null; }, 1, 1),
      confirm: B(([t]) => window.confirm(S(t)), 1, 1),
      settext: B(([x, t]) => { if (x && x.kind === 'secret') throw new KError('settext(): password fields are private'); const e = el(x, 'settext()'); if (x.kind === 'textbox') e.value = S(t); else e.textContent = S(t); return null; }, 2, 2),
      gettext: B(([x]) => { if (x && x.kind === 'secret') throw new KError('gettext(): password fields are private'); const e = el(x, 'gettext()'); return x.kind === 'textbox' ? e.value : e.textContent; }, 1, 1),
      settip: B(([x, t]) => { el(x, 'settip()').title = S(t); return null; }, 2, 2),
      setimage: B(([x, url]) => { const e = el(x, 'setimage()'); const u = url ? S(url) : ''; e.style.visibility = ''; if (/^(https?:|data:image\/)/.test(u)) e.src = u; else e.removeAttribute('src'); return null; }, 2, 2),
      clear: B(([x]) => { R.clear(el(x, 'clear()')); return null; }, 1, 1),
      destroy: B(([x]) => { el(x, 'destroy()').remove(); return null; }, 1, 1),
      addstyle: B(([x, s]) => { addCls(el(x, 'addstyle()'), S(s)); return null; }, 2, 2),
      removestyle: B(([x, s]) => { el(x, 'removestyle()').classList.remove(styleOk(S(s))); return null; }, 2, 2),
      togglestyle: B(([x, s, on]) => { el(x, 'togglestyle()').classList.toggle(styleOk(S(s)), on === undefined ? undefined : K.truthy(on)); return null; }, 2, 3),
      show: B(([x, on]) => { el(x, 'show()').hidden = on === undefined ? false : !K.truthy(on); return null; }, 1, 2),
      enable: B(([x, on]) => { el(x, 'enable()').disabled = !K.truthy(on); return null; }, 2, 2),
      focus: B(([x]) => { const e = el(x, 'focus()'); setTimeout(() => { e.focus(); if (e.select) e.select(); }, 20); return null; }, 1, 1),
      on_click: B(([x, f]) => { const e0 = el(x, 'on_click()'); e0.addEventListener('click', (e) => { e.stopPropagation(); cb(f, 'click: ' + x.kind + ' ' + (e0.textContent || '').trim().slice(0, 18))(); }); return null; }, 2, 2),
      on_middle_click: B(([x, f]) => { el(x, 'on_middle_click()').addEventListener('auxclick', (e) => { if (e.button === 1) { e.preventDefault(); cb(f, 'middle-click')(); } }); return null; }, 2, 2),
      on_key: B(([combo, f]) => { keyHandlers.set(S(combo).toLowerCase(), f); return null; }, 2, 2),
      set_window_title: B(([t]) => { document.title = S(t); return null; }, 1, 1),
      after: B(([ms, f]) => { setTimeout(() => cb(f, 'after(' + (+ms || 0) + ')')(), Math.max(0, +ms || 0)); return null; }, 2, 2),
      every: B(([ms, f]) => { setInterval(() => cb(f, 'every(' + (+ms || 0) + ')')(), Math.max(100, +ms || 1000)); return null; }, 2, 2),
      // ---- styling built-ins (safe: whitelisted CSS properties, no url()/image loading through CSS)
      setstyle: B(([x, p, v]) => { const e = el(x, 'setstyle()'); const [prop, val] = cssOk(S(p), v, 'setstyle()'); e.style.setProperty(prop, val); return null; }, 3, 3),
      setfont: B(([x, fam, size, weight]) => {
        const e = el(x, 'setfont()'); const f = fam === undefined || fam === null ? '' : S(fam);
        if (f) { if (!/^[a-zA-Z0-9 ,"'-]{1,80}$/.test(f)) throw new KError('setfont(): bad font name'); e.style.fontFamily = f; }
        if (size !== undefined && size !== null) e.style.fontSize = cssLen(size, 'setfont()');
        if (weight !== undefined && weight !== null) { const w = S(weight); if (!/^(normal|bold|[1-9]00)$/.test(w)) throw new KError('setfont(): weight is normal, bold or 100..900'); e.style.fontWeight = w; }
        return null;
      }, 2, 4),
      setsize: B(([x, w, h]) => { const e = el(x, 'setsize()'); if (w !== undefined && w !== null) e.style.width = cssLen(w, 'setsize()'); if (h !== undefined && h !== null) e.style.height = cssLen(h, 'setsize()'); return null; }, 2, 3),
      gradient: B(([x, a, b, deg]) => { const e = el(x, 'gradient()'); const c1 = S(a), c2 = S(b); if (!HEX.test(c1) || !HEX.test(c2)) throw new KError('gradient(): use hex colors like #4285f4'); e.style.background = 'linear-gradient(' + (deg === undefined ? 180 : (+deg || 0)) + 'deg, ' + c1 + ', ' + c2 + ')'; return null; }, 3, 4),
      colorletters: B(([p, t, colors, s]) => {
        const h = make('row', 'div', 'ks-letters', p, 'colorletters()'); if (s) addCls(h.el, S(s));
        const cs = Array.isArray(colors) ? colors.map(S) : [];
        for (const c of cs) if (!HEX.test(c)) throw new KError('colorletters(): colors must be hex like #ea4335');
        [...S(t)].forEach((ch, i) => { const sp = document.createElement('span'); sp.textContent = ch; if (cs.length) sp.style.color = cs[i % cs.length]; h.el.appendChild(sp); });
        return h;
      }, 2, 4),
      spacer: B(([p, px]) => { const h = make('box', 'div', 'ks-spacer', p, 'spacer()'); h.el.style.height = cssLen(px === undefined ? 16 : px, 'spacer()'); return h; }, 1, 2),
      on_input: B(([x, f, ms]) => { const e = el(x, 'on_input()'); let t = null; const wait = Math.max(0, Math.min(5000, ms === undefined ? 400 : +ms || 0)); e.addEventListener('input', () => { clearTimeout(t); t = setTimeout(() => cb(f, 'input')(x.kind === 'textbox' ? e.value : e.textContent), wait); }); return null; }, 2, 3),
      fonts: B(() => FONTS.slice(), 0, 0),
      popup: B(([x, y, s]) => {
        closePopups(); const e = document.createElement('div'); e.className = 'ks-col ks-popup'; if (s) addCls(e, S(s));
        document.body.appendChild(e); const px = +x || 0, py = +y || 0;
        requestAnimationFrame(() => { const r = e.getBoundingClientRect(); e.style.left = Math.max(4, Math.min(px - r.width / 2, innerWidth - r.width - 4)) + 'px'; e.style.top = Math.max(4, Math.min(py - r.height / 2, innerHeight - r.height - 4)) + 'px'; });
        e.style.left = px + 'px'; e.style.top = py + 'px';
        e.addEventListener('click', (ev) => { if (ev.target.closest('.ks-button,.ks-link')) setTimeout(closePopups, 0); });
        return new KHandle('box', e);
      }, 2, 3),
      close_popups: B(() => { closePopups(); return null; }, 0, 0),
      css_props: B(() => CSS_PROPS.slice(), 0, 0),
      // ---- v1.3 canvas drawing (2D). Coordinates are CSS pixels, (0,0) = top-left, angles in radians.
      canvas: B(([p, w, h, s]) => {
        const k = make('canvas', 'canvas', 'ks-canvas', p, 'canvas()'); if (s) addCls(k.el, S(s));
        R.setupCanvas(k); k.fixedW = typeof w === 'number' ? w : 0; k.fixedH = typeof h === 'number' ? h : 0;
        if (k.fixedW) k.el.style.width = k.fixedW + 'px'; if (k.fixedH) k.el.style.height = k.fixedH + 'px';
        if (!k.fixedW || !k.fixedH) k.el.classList.add('fill');
        k.el.addEventListener('contextmenu', (e) => e.preventDefault());
        fitCanvas(k); R.touched(k); requestAnimationFrame(() => { const b = k.back.width + 'x' + k.back.height; fitCanvas(k); if (b !== k.back.width + 'x' + k.back.height) R.touched(k); });
        return k;
      }, 1, 4),
      canvas_size: B(([c]) => { const h = cv(c, 'canvas_size()'); return toK({ w: h.w, h: h.h }); }, 1, 1),
      draw_clear: B(([c, color]) => { const h = cv(c, 'draw_clear()'); while (h.depth > 0) { h.g.restore(); h.depth--; } fitCanvas(h); const g = h.g; g.globalAlpha = 1; if (color === undefined || color === null) g.clearRect(0, 0, h.w, h.h); else { g.fillStyle = col(color, 'draw_clear()'); g.fillRect(0, 0, h.w, h.h); } return null; }, 1, 2),
      draw_rect: B(([c, x, y, w, hh, color, lw]) => { const g = cv(c, 'draw_rect()').g; g.beginPath(); g.rect(N(x, 'draw_rect()'), N(y, 'draw_rect()'), N(w, 'draw_rect()'), N(hh, 'draw_rect()')); paint(g, color, lw, 'draw_rect()', [x, y, w, hh]); return null; }, 6, 7),
      draw_round_rect: B(([c, x, y, w, hh, r, color, lw]) => { const g = cv(c, 'draw_round_rect()').g; g.beginPath(); g.roundRect(N(x, 'x'), N(y, 'y'), Math.max(0, N(w, 'w')), Math.max(0, N(hh, 'h')), Math.max(0, N(r, 'r'))); paint(g, color, lw, 'draw_round_rect()', [x, y, w, hh]); return null; }, 7, 8),
      draw_circle: B(([c, x, y, r, color, lw]) => { const g = cv(c, 'draw_circle()').g; g.beginPath(); g.arc(N(x, 'draw_circle()'), N(y, 'draw_circle()'), Math.max(0, N(r, 'draw_circle()')), 0, Math.PI * 2); paint(g, color, lw, 'draw_circle()', [x - r, y - r, 2 * r, 2 * r]); return null; }, 5, 6),
      draw_arc: B(([c, x, y, r, a0, a1, color, lw]) => { const g = cv(c, 'draw_arc()').g; g.beginPath(); g.arc(N(x, 'x'), N(y, 'y'), Math.max(0, N(r, 'r')), N(a0, 'a0'), N(a1, 'a1')); g.strokeStyle = col(color, 'draw_arc()'); g.lineWidth = N(lw, 'draw_arc()', 1); g.stroke(); return null; }, 7, 8),
      draw_ellipse: B(([c, x, y, rx, ry, rot, color, lw]) => { const g = cv(c, 'draw_ellipse()').g; g.beginPath(); g.ellipse(N(x, 'x'), N(y, 'y'), Math.max(0, N(rx, 'rx')), Math.max(0, N(ry, 'ry')), N(rot, 'rot', 0), 0, Math.PI * 2); paint(g, color, lw, 'draw_ellipse()'); return null; }, 7, 8),
      draw_line: B(([c, x1, y1, x2, y2, color, lw]) => { const g = cv(c, 'draw_line()').g; g.beginPath(); g.moveTo(N(x1, 'draw_line()'), N(y1, 'draw_line()')); g.lineTo(N(x2, 'draw_line()'), N(y2, 'draw_line()')); g.strokeStyle = col(color, 'draw_line()'); g.lineWidth = N(lw, 'draw_line()', 1); g.stroke(); return null; }, 6, 7),
      draw_lines: B(([c, l, color, lw]) => { const g = cv(c, 'draw_lines()').g; const P = pts(l, 'draw_lines()'); if (P.length < 2) return null; g.beginPath(); g.moveTo(P[0][0], P[0][1]); for (const q of P) g.lineTo(q[0], q[1]); g.strokeStyle = col(color, 'draw_lines()'); g.lineWidth = N(lw, 'draw_lines()', 1); g.stroke(); return null; }, 3, 4),
      draw_poly: B(([c, l, color, lw]) => { const g = cv(c, 'draw_poly()').g; const P = pts(l, 'draw_poly()'); if (P.length < 2) return null; g.beginPath(); g.moveTo(P[0][0], P[0][1]); for (const q of P) g.lineTo(q[0], q[1]); g.closePath(); paint(g, color, lw, 'draw_poly()', bboxOf(P)); return null; }, 3, 4),
      draw_points: B(([c, l, color, size]) => { const g = cv(c, 'draw_points()').g; const P = pts(l, 'draw_points()'); const z = N(size, 'draw_points()', 1); g.fillStyle = col(color, 'draw_points()'); for (const q of P) g.fillRect(q[0] - z / 2, q[1] - z / 2, z, z); return null; }, 3, 4),
      draw_text: B(([c, x, y, t, color, size, align, font]) => {
        const g = cv(c, 'draw_text()').g; const f = font ? S(font) : 'Segoe UI, system-ui, sans-serif';
        if (!/^[a-zA-Z0-9 ,"'-]{1,80}$/.test(f)) throw new KError('draw_text(): bad font name');
        g.font = (size && typeof size === 'number' ? size : 14) + 'px ' + f; const a = align ? S(align) : 'left';
        if (!['left', 'center', 'right'].includes(a)) throw new KError('draw_text(): align is "left", "center" or "right"');
        g.textAlign = a; g.textBaseline = 'middle'; g.fillStyle = col(color === undefined || color === null ? '#000' : color, 'draw_text()'); g.fillText(S(t), N(x, 'draw_text()'), N(y, 'draw_text()'));
        return null;
      }, 4, 8),
      draw_glow: B(([c, x, y, r, inner, outer]) => { const g = cv(c, 'draw_glow()').g; const X = N(x, 'x'), Y = N(y, 'y'), Rr = Math.max(0.001, N(r, 'r')); const gr = g.createRadialGradient(X, Y, 0, X, Y, Rr); gr.addColorStop(0, col(inner, 'draw_glow()')); gr.addColorStop(1, col(outer === undefined ? 'transparent' : outer, 'draw_glow()')); g.fillStyle = gr; g.beginPath(); g.arc(X, Y, Rr, 0, Math.PI * 2); g.fill(); return null; }, 5, 6),
      draw_gradient: B(([c, x, y, w, hh, c1, c2]) => { const g = cv(c, 'draw_gradient()').g; const X = N(x, 'x'), Y = N(y, 'y'), W = N(w, 'w'), H = N(hh, 'h'); const gr = g.createLinearGradient(X, Y, X, Y + H); gr.addColorStop(0, col(c1, 'draw_gradient()')); gr.addColorStop(1, col(c2, 'draw_gradient()')); g.fillStyle = gr; g.fillRect(X, Y, W, H); return null; }, 7, 7),
      draw_alpha: B(([c, a]) => { cv(c, 'draw_alpha()').g.globalAlpha = Math.max(0, Math.min(1, N(a, 'draw_alpha()'))); return null; }, 2, 2),
      draw_save: B(([c]) => { const h = cv(c, 'draw_save()'); if (h.depth > 200) throw new KError('draw_save(): too many saves without draw_restore()'); h.g.save(); h.depth++; return null; }, 1, 1),
      draw_restore: B(([c]) => { const h = cv(c, 'draw_restore()'); if (h.depth > 0) { h.g.restore(); h.depth--; } return null; }, 1, 1),
      draw_translate: B(([c, x, y]) => { cv(c, 'draw_translate()').g.translate(N(x, 'x'), N(y, 'y')); return null; }, 3, 3),
      draw_rotate: B(([c, a]) => { cv(c, 'draw_rotate()').g.rotate(N(a, 'draw_rotate()')); return null; }, 2, 2),
      draw_scale: B(([c, x, y]) => { const sx = N(x, 'draw_scale()'); cv(c, 'draw_scale()').g.scale(sx, y === undefined ? sx : N(y, 'draw_scale()')); return null; }, 2, 3),
      // ---- v1.3 game loop, input, timers
      on_frame: B(([f]) => {
        if (!isFn(f)) throw new KError('on_frame() needs a function like fn(dt) { ... }');
        const id = frameIds++; let last = 0, busy = false;
        const loop = (now) => {
          if (!frames.has(id)) return;
          if (!alive()) { frames.delete(id); return; }
          requestAnimationFrame(loop);
          const dt = last ? Math.min(0.1, (now - last) / 1000) : 1 / 60; last = now;
          if (busy || !visible()) return; busy = true;
          Promise.resolve(R.run(() => interp.invoke(f, [dt], 'frame'))).finally(() => { busy = false; });
        };
        frames.set(id, true); requestAnimationFrame(loop); return id;
      }, 1, 1),
      stop_frame: B(([id]) => { if (id === undefined || id === null) frames.clear(); else frames.delete(id); return null; }, 0, 1),
      key_down: B(([k]) => KEYS.has(normKey(S(k))), 1, 1),
      on_keypress: B(([f]) => { if (!isFn(f)) throw new KError('on_keypress() needs a function like fn(key) { ... }'); keyRuntimes.add({ alive, visible, press: (k) => cb(f, 'key: ' + k)(k) }); return null; }, 1, 1),
      on_mouse: B(([x, f]) => {
        const e0 = el(x, 'on_mouse()'); if (!isFn(f)) throw new KError('on_mouse() needs a function like fn(e) { ... }');
        const btn = (b) => b === 2 ? 'right' : b === 1 ? 'middle' : 'left'; let moveQ = null;
        const send = (type, ev, extra) => { const r = e0.getBoundingClientRect(); cb(f, 'mouse ' + type)(Object.assign({ type, x: ev.clientX - r.left, y: ev.clientY - r.top, button: btn(ev.button), shift: ev.shiftKey }, extra || {})); };
        e0.addEventListener('mousedown', (ev) => { ev.stopPropagation(); send('down', ev); });
        window.addEventListener('mouseup', (ev) => { if (alive() && e0.isConnected) send('up', ev); });
        e0.addEventListener('mousemove', (ev) => { if (!moveQ) requestAnimationFrame(() => { const q = moveQ; moveQ = null; if (q) send('move', q); }); moveQ = ev; });
        e0.addEventListener('wheel', (ev) => { ev.preventDefault(); send('wheel', ev, { dy: ev.deltaY > 0 ? 1 : ev.deltaY < 0 ? -1 : 0 }); }, { passive: false });
        return null;
      }, 2, 2),
      every_ms: B(([ms, f]) => { const t = setInterval(() => { if (!alive()) { clearInterval(t); return; } cb(f, 'every_ms(' + (+ms || 0) + ')')(); }, Math.max(16, +ms || 1000)); return t; }, 2, 2),
      cancel_timer: B(([t]) => { clearInterval(+t); clearTimeout(+t); return null; }, 1, 1),
      // ---- v1.3 form controls
      slider: B(([p, lo, hi, v, f, s]) => {
        const h = make('slider', 'input', 'ks-slider', p, 'slider()'); h.el.type = 'range'; h.el.min = N(lo, 'slider()'); h.el.max = N(hi, 'slider()'); h.el.step = 'any'; h.el.value = N(v, 'slider()', +lo);
        if (s) addCls(h.el, S(s)); if (isFn(f)) h.el.addEventListener('input', () => cb(f, 'slider')(+h.el.value)); h.el.addEventListener('keydown', (e) => e.stopPropagation()); return h;
      }, 3, 6),
      checkbox: B(([p, t, on, f, s]) => {
        const h = make('checkbox', 'label', 'ks-check', p, 'checkbox()'); const i = document.createElement('input'); i.type = 'checkbox'; i.checked = K.truthy(on);
        const sp = document.createElement('span'); sp.textContent = S(t); h.el.append(i, sp); h.input = i; if (s) addCls(h.el, S(s));
        if (isFn(f)) i.addEventListener('change', () => cb(f, 'checkbox: ' + S(t).slice(0, 20))(i.checked)); return h;
      }, 2, 5),
      dropdown: B(([p, items, f, s]) => {
        const h = make('dropdown', 'select', 'ks-dropdown', p, 'dropdown()'); if (!Array.isArray(items)) throw new KError('dropdown() needs a list of choices');
        for (const it of items) { const o = document.createElement('option'); o.value = o.textContent = S(it); h.el.appendChild(o); }
        if (s) addCls(h.el, S(s)); if (isFn(f)) h.el.addEventListener('change', () => cb(f, 'dropdown')(h.el.value)); return h;
      }, 2, 4),
      getvalue: B(([x]) => { const e = el(x, 'getvalue()'); if (x.kind === 'secret') throw new KError('getvalue(): password fields are private'); if (x.kind === 'checkbox') return x.input.checked; if (x.kind === 'slider') return +e.value; if (x.kind === 'textbox' || x.kind === 'dropdown') return e.value; return e.textContent; }, 1, 1),
      setvalue: B(([x, v]) => { const e = el(x, 'setvalue()'); if (x.kind === 'secret') throw new KError('setvalue(): password fields are private'); if (x.kind === 'checkbox') x.input.checked = K.truthy(v); else if (x.kind === 'slider' || x.kind === 'textbox' || x.kind === 'dropdown') e.value = S(v); else e.textContent = S(v); return null; }, 2, 2),
      // ---- v1.3 small key/value storage that survives restarts (per Kompass profile, JSON values, 200 KB each)
      store_get: B(([k, d]) => { try { const v = localStorage.getItem('ks-store:' + (opts.storeNs || '') + S(k)); return v === null ? (d === undefined ? null : d) : toK(JSON.parse(v)); } catch (e) { return d === undefined ? null : d; } }, 1, 2),
      store_set: B(([k, v]) => { const j = JSON.stringify(toJS(v)); if (j.length > 200000) throw new KError('store_set(): value too big (max 200 KB)'); localStorage.setItem('ks-store:' + (opts.storeNs || '') + S(k), j); return true; }, 2, 2),
      print: B((a) => { opts.onPrint(a.map(S).join(' ')); return null; }, 0),
    };

    // ---------- tabs (real Chromium pages via sandboxed <webview>, or KampfScript-drawn internal pages)
    const tabs = new Map(); let nextId = 1; let viewArea = null; let tabHandler = null; let dblRight = null;
    if (opts.withBrowser && window.native.onDoubleRight) window.native.onDoubleRight((p) => {
      if (!dblRight) return; let x = p.x, y = p.y;
      if (p.web && viewArea) { const r = viewArea.getBoundingClientRect(); x += r.left; y += r.top; }
      cb(dblRight, 'double right-click')(x, y, !!p.web, p.link || '');
    });
    const fire = (ev, id, val) => { if (window.KompassDevtools) window.KompassDevtools.event(ev, id, val); if (tabHandler) cb(tabHandler, 'on_tab_event: ' + ev)(ev, id, val === undefined ? null : val); };
    const tab = (id, who) => { const t = tabs.get(id); if (!t) throw new KError(who + ': no tab with id ' + S(id)); return t; };
    function showWeb(t) { t.mode = 'web'; t.page.hidden = true; t.wv.hidden = false; }
    function showInternal(t, url) { t.mode = 'internal'; t.internalUrl = url; t.wv.hidden = true; t.page.hidden = false; t.page.replaceChildren(); t.page.scrollTop = 0; fire('url', t.id, url); fire('internal', t.id, url); fire('state', t.id); }
    function webview(t) {
      const wv = document.createElement('webview');
      wv.setAttribute('partition', 'persist:kompass');
      wv.setAttribute('allowpopups', '');
      wv.className = 'ks-webview'; wv.hidden = true;
      wv.addEventListener('page-title-updated', (e) => { t.title = e.title; fire('title', t.id, e.title); });
      wv.addEventListener('did-navigate', (e) => { if (e.url === 'about:blank') { if (t.mode === 'web' && t.lastInternal) showInternal(t, t.lastInternal); return; } if (t.mode === 'web') { t.url = e.url; fire('url', t.id, e.url); fire('state', t.id); fire('visit', t.id, e.url); } });
      wv.addEventListener('did-navigate-in-page', (e) => { if (e.isMainFrame && t.mode === 'web') { t.url = e.url; fire('url', t.id, e.url); fire('state', t.id); } });
      wv.addEventListener('did-start-loading', () => fire('loading', t.id, true));
      wv.addEventListener('did-stop-loading', () => { fire('loading', t.id, false); fire('state', t.id); });
      wv.addEventListener('page-favicon-updated', (e) => fire('favicon', t.id, e.favicons && e.favicons[0] || ''));
      wv.addEventListener('did-fail-load', (e) => { if (e.isMainFrame && e.errorCode !== -3) fire('error', t.id, e.errorDescription + ' (' + e.errorCode + ')'); });
      wv.addEventListener('dom-ready', () => { t.ready = true; if (t.pending) { const u = t.pending; t.pending = null; wv.loadURL(u); } });
      return wv;
    }
    const browser = {
      view_area: B(([p]) => { viewArea = el(p, 'view_area()'); viewArea.classList.add('ks-viewarea'); return null; }, 1, 1),
      on_tab_event: B(([f]) => { tabHandler = f; return null; }, 1, 1),
      on_double_right_click: B(([f]) => { dblRight = f; return null; }, 1, 1),
      tab_new: B(([url]) => {
        if (!viewArea) throw new KError('call view_area(container) before tab_new()');
        const id = nextId++;
        const t = { id, url: '', title: 'New tab', mode: 'internal', ready: false, pending: null, everWeb: false };
        t.wv = webview(t); t.page = document.createElement('div'); t.page.className = 'ks-page'; t.page.hidden = true;
        t.wv.src = 'about:blank';
        const wrap = document.createElement('div'); wrap.className = 'ks-tabview'; wrap.hidden = true; wrap.append(t.wv, t.page); t.wrap = wrap;
        viewArea.appendChild(wrap); tabs.set(id, t);
        if (url) setTimeout(() => browser.tab_navigate.fn([id, url]), 0);
        return id;
      }, 0, 1),
      tab_navigate: B(([id, url]) => {
        const t = tab(id, 'tab_navigate()'); const u = S(url);
        if (/^(kampf|kompass):/.test(u)) { showInternal(t, u); return null; }
        if (!/^(https?:|about:blank)/.test(u)) throw new KError('tab_navigate(): only http(s), kompass: or kampf: URLs');
        if (t.mode === 'internal' && t.internalUrl) t.lastInternal = t.internalUrl;
        showWeb(t); t.everWeb = true; t.url = u; fire('url', t.id, u);
        if (t.ready) t.wv.loadURL(u); else t.pending = u;
        return null;
      }, 2, 2),
      tab_page: B(([id]) => new KHandle('box', tab(id, 'tab_page()').page), 1, 1),
      tab_select: B(([id]) => { for (const t of tabs.values()) t.wrap.hidden = t.id !== id; tab(id, 'tab_select()'); return null; }, 1, 1),
      tab_close: B(([id]) => { const t = tab(id, 'tab_close()'); t.wrap.remove(); tabs.delete(id); return null; }, 1, 1),
      tab_back: B(([id]) => {
        const t = tab(id, 'tab_back()');
        if (t.mode === 'internal') { if (t.everWeb && t.url) { showWeb(t); fire('url', t.id, t.url); fire('state', t.id); } return null; }
        if (t.ready && t.wv.canGoBack()) t.wv.goBack(); else if (t.lastInternal) showInternal(t, t.lastInternal);
        return null;
      }, 1, 1),
      tab_forward: B(([id]) => { const t = tab(id, 'tab_forward()'); if (t.mode === 'web' && t.ready && t.wv.canGoForward()) t.wv.goForward(); else if (t.mode === 'internal' && t.everWeb) { showWeb(t); fire('url', t.id, t.url); } return null; }, 1, 1),
      tab_reload: B(([id]) => { const t = tab(id, 'tab_reload()'); if (t.mode === 'web') { if (t.ready) t.wv.reload(); } else showInternal(t, t.internalUrl); return null; }, 1, 1),
      tab_stop: B(([id]) => { const t = tab(id, 'tab_stop()'); if (t.ready) t.wv.stop(); return null; }, 1, 1),
      tab_url: B(([id]) => { const t = tab(id, 'tab_url()'); return t.mode === 'internal' ? t.internalUrl : t.url; }, 1, 1),
      tab_title: B(([id]) => tab(id, 'tab_title()').title, 1, 1),
      tab_can_back: B(([id]) => { const t = tab(id, 'tab_can_back()'); return t.mode === 'internal' ? !!(t.everWeb && t.url) : !!((t.ready && t.wv.canGoBack()) || t.lastInternal); }, 1, 1),
      tab_can_forward: B(([id]) => { const t = tab(id, 'tab_can_forward()'); return t.mode === 'web' && t.ready ? t.wv.canGoForward() : false; }, 1, 1),
      tab_remember_internal: B(([id]) => { const t = tab(id, 'x'); if (t.mode === 'internal') { t.lastInternal = t.internalUrl; } return null; }, 1, 1),
      tab_zoom: B(([id, f]) => { const t = tab(id, 'tab_zoom()'); if (t.ready) t.wv.setZoomFactor(Math.min(3, Math.max(0.3, +f || 1))); return null; }, 2, 2),
      tab_find: B(([id, q]) => { const t = tab(id, 'tab_find()'); if (t.ready && t.mode === 'web') { if (q) t.wv.findInPage(S(q)); else t.wv.stopFindInPage('clearSelection'); } return null; }, 2, 2),
      tab_mute: B(([id, on]) => { const t = tab(id, 'tab_mute()'); if (t.ready) t.wv.setAudioMuted(K.truthy(on)); return null; }, 2, 2),
      tab_devtools: B(([id]) => { const t = tab(id, 'x'); if (t.ready && t.mode === 'web') t.wv.openDevTools(); return null; }, 1, 1),
    };

    // ---------- native services: files, search, settings
    const services = {
      load_data: B(([name, dflt]) => { const s = window.native.load(S(name)); if (s === null) return dflt === undefined ? null : dflt; try { return toK(JSON.parse(s)); } catch (e) { return dflt === undefined ? null : dflt; } }, 1, 2),
      save_data: B(([name, v]) => { window.native.save(S(name), JSON.stringify(toJS(v), null, 2)); return true; }, 2, 2),
      kugel_search: B(async ([q]) => {
        const query = S(q).trim();
        try { const r = await fetch(PROXY + '/search?q=' + encodeURIComponent(query)); const d = await r.json(); if (!d.results) d.results = []; if (d.error === undefined) d.error = ''; return toK(d); }
        catch (e) { return toK({ ok: false, error: 'Network error: ' + e.message, results: [] }); }
      }, 1, 1),
      url_encode: B(([s]) => encodeURIComponent(S(s)), 1, 1),
      url_decode: B(([s]) => { try { return decodeURIComponent(S(s)); } catch (e) { return S(s); } }, 1, 1),
      now_text: B(() => new Date().toLocaleString(), 0, 0),
      adblock: B(([on]) => toK(window.native.adblock(on === undefined ? undefined : K.truthy(on))), 0, 1),
      open_external: B(([u]) => { window.native.openExternal(S(u)); return null; }, 1, 1),
      open_data_folder: B(() => { window.native.openFolder(); return null; }, 0, 0),
      open_editor: B(([f]) => { window.KompassEditor.open(f ? S(f) : null); return null; }, 0, 1),
      reload_app: B(() => { window.native.reloadApp(); return null; }, 0, 0),
      app_devtools: B(() => { window.native.devtools(); return null; }, 0, 0),
      quit: B(() => { window.native.quit(); return null; }, 0, 0),
      app_version: B(() => window.native.version(), 0, 0),
      update_state: B(() => toK(window.native.update.state()), 0, 0),
      update_check: B(async () => toK(await window.native.update.check()), 0, 0),
      update_auto: B(([on]) => toK(window.native.update.auto(K.truthy(on))), 1, 1),
      update_install: B(() => window.native.update.install(), 0, 0),
      on_update: B(([f]) => { window.native.update.onState((st) => cb(f, 'update state')(st)); return null; }, 1, 1),
      clear_browsing_data: B(async () => { await window.native.clearBrowsingData(); return true; }, 0, 0),
      reset_browser: B(() => { window.native.saveBrowserSource(window.native.defaultSource()); window.native.reloadApp(); return null; }, 0, 0),
      ks_devtools: B(([on]) => { if (window.KompassDevtools) window.KompassDevtools.toggle(on === undefined ? undefined : K.truthy(on)); return null; }, 0, 1),
      video_file: B(([n]) => window.native.videoFile(S(n)) || '', 1, 1),
      videos_folder: B(() => window.native.videosFolder(), 0, 0),
      open_videos_folder: B(() => { window.native.openVideosFolder(); return null; }, 0, 0),
      read_script: B(([n]) => { const f = S(n).replace(/\.ks$/, ''); if (!/^[A-Za-z0-9_-]{1,40}$/.test(f)) return ''; return window.native.readScript(f + '.ks') || ''; }, 1, 1),
      // 1.5 Kugel Store (catalog = public GitHub repo; code always runs through run_page = sandbox)
      store_index: B(async () => toK(await window.native.store.index()), 0, 0),
      store_code: B(async ([id]) => toK(await window.native.store.code(S(id))), 1, 1),
      store_publish: B(async ([t, d, a, code]) => toK(await window.native.store.publish({ title: S(t), description: S(d), author: S(a), code: S(code) })), 4, 4),
      publish_draft: B(() => { const d = window.__ksPublishDraft || null; window.__ksPublishDraft = null; return toK(d); }, 0, 0),
      read_resource: B(([n]) => window.native.readResource(S(n)), 1, 1),
      copy_text: B(([t]) => { window.native.copyText(S(t)); return true; }, 1, 1),
      save_text_file: B(async ([name, t]) => (await window.native.saveTextFile(S(name), S(t))) || '', 2, 2),
      // Run a user's KampfScript page (kompass://builder, custom home page) in an isolated interpreter that can
      // draw into `stage` and use the page API (search / lucky / open_url / engine) wired to browser.ks handlers.
      run_page: B(async ([code, stage, handlers, ns]) => {
        const out = []; const hs = handlers instanceof KMap ? handlers : new KMap();
        const call = (k, args) => { const f = hs.m.get(k); if (isFn(f)) R.run(() => interp.invoke(f, args, 'page: ' + k)); return null; };
        const extra = {
          search: B(([q]) => call('search', [S(q)]), 1, 1),
          lucky: B(([q]) => call('lucky', [S(q)]), 1, 1),
          open_url: B(([u]) => call('open', [S(u)]), 1, 1),
          engine: B(() => { const e = hs.m.get('engine'); return e === undefined || e === null ? 'kugel' : S(e); }, 0, 0),
          sleep: B(() => null, 1, 1), input: B(() => '', 0, 1),
        };
        el(stage, 'run_page()').replaceChildren();
        const sb = makeRuntime({ sandbox: true, rootHandle: stage, maxSteps: 5000000, storeNs: ns ? String(S(ns)).replace(/[^a-z0-9_-]/gi, '').slice(0, 48) + '/' : '', onPrint: (x) => { if (out.length < 500) out.push(x); call('print', [x]); }, onError: (e) => { out.push('✖ ' + e.message); console.warn('[page error] ' + e.message); call('error', [e.message]); }, extra });
        try { const r = await R.run(() => sb.run(S(code))); return toK({ ok: true, output: out, error: '', line: 0, steps: r.steps }); }
        catch (e) { return toK({ ok: false, output: out, error: e.message, line: e.line || 0, steps: sb.totalSteps }); }
      }, 2, 4),
      // ---- password manager. Passwords stay in the main process / host DOM: KampfScript only ever gets
      // site, username and opaque 'secret' handles (gettext/settext refuse them).
      pw_status: B(() => toK(window.native.pw.status()), 0, 0),
      pw_input: B(([p, ph]) => { const h = make('secret', 'input', 'ks-textbox ks-secret', p, 'pw_input()'); h.el.type = 'password'; h.el.placeholder = ph ? S(ph) : 'password'; h.el.autocomplete = 'off'; h.el.spellcheck = false; return h; }, 1, 2),
      pw_unlock: B(([x]) => { const e = secretEl(x, 'pw_unlock()'); const r = window.native.pw.unlock(e.value); e.value = ''; return toK(r); }, 1, 1),
      pw_lock: B(() => { window.native.pw.lock(); return null; }, 0, 0),
      pw_list: B(([q]) => { const r = window.native.pw.list(q ? S(q) : ''); return toK(r.ok ? r.items : []); }, 0, 1),
      pw_save: B(([id, origin, user, x]) => { const pw = x ? secretEl(x, 'pw_save()').value : null; if (!id && !pw) return toK({ ok: false, error: 'Enter a password' }); const r = window.native.pw.save(id ? S(id) : null, S(origin), user ? S(user) : '', pw === '' ? null : pw); if (x) secretEl(x, 'x').value = ''; return toK(r); }, 3, 4),
      pw_generate_into: B(([x, n]) => { const e = secretEl(x, 'pw_generate_into()'); e.value = window.native.pw.generate(+n || 20); e.type = 'text'; return null; }, 1, 2),
      pw_reveal: B(([p, id]) => {
        const h = make('secret', 'span', 'ks-label ks-secret-text', p, 'pw_reveal()'); const pid = S(id); h.el.textContent = '••••••••••'; h.el.title = 'Click to reveal / hide';
        let shown = false; h.el.addEventListener('click', (ev) => { ev.stopPropagation(); shown = !shown; if (shown) { const r = window.native.pw.reveal(pid); h.el.textContent = r.ok ? r.password : '(locked)'; setTimeout(() => { if (shown) { shown = false; h.el.textContent = '••••••••••'; } }, 20000); } else h.el.textContent = '••••••••••'; });
        return h;
      }, 2, 2),
      pw_copy: B(([id]) => !!window.native.pw.copy(S(id)).ok, 1, 1),
      pw_delete: B(([id]) => toK(window.native.pw.remove(S(id))), 1, 1),
      pw_offer: B(([id, a]) => toK(window.native.pw.offer(+id, S(a))), 2, 2),
      on_password_offer: B(([f]) => { window.native.pw.onOffer((o) => cb(f, 'password offer')(o)); return null; }, 1, 1),
      on_vault_lock: B(([f]) => { window.native.pw.onLocked(() => cb(f, 'vault locked')()); return null; }, 1, 1),
      pw_export: B(async ([kind, x]) => { const k = S(kind); const pass = x ? secretEl(x, 'pw_export()').value : ''; if (k === 'encrypted' && pass.length < 8) return toK({ ok: false, error: 'Choose an export password (8+ characters)' }); const r = await window.native.pw.exportTo(k, pass); if (x) secretEl(x, 'x').value = ''; return toK(r); }, 1, 2),
      pw_import: B(async ([x]) => { const pass = x ? secretEl(x, 'pw_import()').value : ''; const r = await window.native.pw.importFrom(pass); return toK(r); }, 0, 1),
      // Run untrusted lesson code in a fresh, isolated interpreter: core built-ins only (no UI, tabs or files).
      run_sandbox: B(async ([code, stage]) => {
        const out = [];
        const extra = { sleep: B(() => null, 1, 1), input: B(() => '', 0, 1),
          open_tab: B(([u]) => { out.push('[sandbox] would open tab: ' + S(u)); return null; }, 1, 1) };
        let sb;
        if (stage instanceof KHandle) { el(stage, 'run_sandbox()').replaceChildren(); sb = makeRuntime({ sandbox: true, rootHandle: stage, maxSteps: 200000, onPrint: (x) => { if (out.length < 500) out.push(x); }, onError: (e) => out.push('✖ ' + e.message), extra }); }
        else sb = new K.Interpreter({ maxSteps: 200000, onPrint: (x) => { if (out.length < 500) out.push(x); }, builtins: extra });
        try { const r = await R.run(() => sb.run(S(code))); return toK({ ok: true, output: out, error: '', line: 0, steps: r.steps }); }
        catch (e) { return toK({ ok: false, output: out, error: e.message, line: e.line || 0, steps: sb.totalSteps }); }
      }, 1, 2),
    };

    const sandboxUi = () => { const o = Object.assign({}, ui); for (const k of ['on_key', 'set_window_title', 'set_theme', 'set_accent', 'confirm', 'every']) delete o[k]; return o; };  // every_ms/on_frame stay: they stop with the page
    const keyHandlers = new Map();
    interp = new K.Interpreter({
      maxSteps: opts.maxSteps || 2000000, yieldEvery: 3000, atomicMs: 50, hooks: opts.hooks || null,
      onPrint: opts.onPrint, onError: opts.onError,
      builtins: opts.sandbox ? Object.assign(sandboxUi(), opts.extra || {}) : Object.assign({}, ui, opts.withBrowser ? browser : {}, services, opts.extra || {}),
    });
    interp.keyHandlers = keyHandlers;
    interp.openTabFromPage = (u) => { if (tabHandler) cb(tabHandler, 'on_tab_event: popup')('popup', 0, u); };
    interp.nativeNames = new Set(Object.keys(Object.assign({}, ui, browser, services, opts.extra || {})));
    return interp;
  }

  function keyName(e) { return (e.ctrlKey ? 'ctrl+' : '') + (e.shiftKey ? 'shift+' : '') + (e.altKey ? 'alt+' : '') + e.key.toLowerCase(); }

  // ---------- boot browser.ks
  const app = document.getElementById('app');
  const errBox = document.getElementById('boot-error');
  errBox.onclick = () => { errBox.hidden = true; if (window.KompassDevtools) { window.KompassDevtools.toggle(true); window.KompassDevtools.show('errors'); } };
  function showError(msg) { errBox.hidden = false; errBox.textContent = '⚠ KampfScript error in browser.ks: ' + msg + '   (click: DevTools errors · Ctrl+Shift+K: editor)'; console.error(msg); }
  // DevTools hooks: forwarded to window.KompassDevtools (devtools.js) when it is loaded.
  const hooks = {
    builtin: (name, args, line) => { const d = window.KompassDevtools; if (d) d.builtin(name, args, line); },
    invoke: (label, steps, ms, err) => { const d = window.KompassDevtools; if (d) d.invoked(label, steps, ms, err); },
    statement: null,  // set by DevTools only while breakpoints/stepping are active
  };
  const main = makeRuntime({
    withBrowser: true, rootHandle: new KHandle('box', app), hooks,
    onPrint: (s) => { console.log('[ks]', s); if (window.KompassEditor) window.KompassEditor.log(s); if (window.KompassDevtools) window.KompassDevtools.print(s); },
    onError: (e) => { showError(e.message); if (window.KompassDevtools) window.KompassDevtools.error(e); },
  });
  window.KompassMain = main;
  window.KompassRuntime = { makeRuntime, toK, toJS };
  function handleKey(k, ev) {
    if (k === 'ctrl+shift+k') { if (ev) ev.preventDefault(); window.KompassEditor.toggle(); return; }
    const f = main.keyHandlers.get(k); if (f) { if (ev) ev.preventDefault(); R.run(() => main.invoke(f, [], 'key: ' + k)); }
  }
  window.addEventListener('keydown', (e) => handleKey(keyName(e), e));
  window.native.onKey((k) => handleKey(k));
  window.native.onOpenTab((u) => main.openTabFromPage(u));
  R.run(() => main.run(window.native.browserSource())).catch((e) => { showError(e.message); if (window.KompassDevtools) window.KompassDevtools.error(e); });
})();
