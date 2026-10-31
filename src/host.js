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


  const CSS_PROPS = ['color', 'background', 'background-color', 'font-family', 'font-size', 'font-weight', 'font-style', 'letter-spacing', 'line-height', 'text-align', 'text-transform', 'text-shadow',
    'padding', 'margin', 'width', 'height', 'max-width', 'min-width', 'min-height', 'border', 'border-radius', 'box-shadow', 'gap', 'opacity', 'justify-content', 'align-items', 'flex-wrap', 'flex', 'cursor'];
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
    const val = typeof v === 'number' ? (['opacity', 'font-weight', 'line-height', 'flex'].includes(p) ? String(v) : v + 'px') : S(v);
    if (val.length > 160 || !/^[#a-zA-Z0-9 .,%()\-"'\/]*$/.test(val) || /url|image|expression|@import|\\/i.test(val)) throw new KError(who + ': value not allowed: ' + val);
    return [p, val];
  }

  function makeRuntime(opts) {
    let interp;
    const cb = (f, label) => (...args) => interp.invoke(f, args.map(toK), label);
    const HEX = /^#[0-9a-fA-F]{3,8}$/;
    const THEMES = ['brass', 'midnight', 'neon', 'paper'];
    const isFn = (f) => f && (f instanceof K.KFunc || f instanceof K.KBuiltin);
    const secretEl = (x, who) => { if (!(x instanceof KHandle) || x.kind !== 'secret') throw new KError(who + ' needs a pw_input() field'); return x.el; };
    const el = (x, who) => { if (!(x instanceof KHandle) || !x.el) throw new KError(who + ' needs a UI element, got ' + K.typeOf(x)); return x.el; };
    const make = (kind, tag, cls, parent, who) => {
      const e = document.createElement(tag); if (cls) e.className = cls;
      el(parent, who).appendChild(e); return new KHandle(kind, e);
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
      clear: B(([x]) => { el(x, 'clear()').replaceChildren(); return null; }, 1, 1),
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
      clear_browsing_data: B(async () => { await window.native.clearBrowsingData(); return true; }, 0, 0),
      reset_browser: B(() => { window.native.saveBrowserSource(window.native.defaultSource()); window.native.reloadApp(); return null; }, 0, 0),
      ks_devtools: B(([on]) => { if (window.KompassDevtools) window.KompassDevtools.toggle(on === undefined ? undefined : K.truthy(on)); return null; }, 0, 1),
      video_file: B(([n]) => window.native.videoFile(S(n)) || '', 1, 1),
      videos_folder: B(() => window.native.videosFolder(), 0, 0),
      open_videos_folder: B(() => { window.native.openVideosFolder(); return null; }, 0, 0),
      read_script: B(([n]) => { const f = S(n).replace(/\.ks$/, ''); if (!/^[A-Za-z0-9_-]{1,40}$/.test(f)) return ''; return window.native.readScript(f + '.ks') || ''; }, 1, 1),
      read_resource: B(([n]) => window.native.readResource(S(n)), 1, 1),
      copy_text: B(([t]) => { window.native.copyText(S(t)); return true; }, 1, 1),
      save_text_file: B(async ([name, t]) => (await window.native.saveTextFile(S(name), S(t))) || '', 2, 2),
      // Run a user's KampfScript page (kompass://builder, custom home page) in an isolated interpreter that can
      // draw into `stage` and use the page API (search / lucky / open_url / engine) wired to browser.ks handlers.
      run_page: B(async ([code, stage, handlers]) => {
        const out = []; const hs = handlers instanceof KMap ? handlers : new KMap();
        const call = (k, args) => { const f = hs.m.get(k); if (isFn(f)) interp.invoke(f, args, 'page: ' + k); return null; };
        const extra = {
          search: B(([q]) => call('search', [S(q)]), 1, 1),
          lucky: B(([q]) => call('lucky', [S(q)]), 1, 1),
          open_url: B(([u]) => call('open', [S(u)]), 1, 1),
          engine: B(() => { const e = hs.m.get('engine'); return e === undefined || e === null ? 'kugel' : S(e); }, 0, 0),
          sleep: B(() => null, 1, 1), input: B(() => '', 0, 1),
        };
        el(stage, 'run_page()').replaceChildren();
        const sb = makeRuntime({ sandbox: true, rootHandle: stage, maxSteps: 200000, onPrint: (x) => { if (out.length < 500) out.push(x); call('print', [x]); }, onError: (e) => { out.push('✖ ' + e.message); call('error', [e.message]); }, extra });
        try { const r = await sb.run(S(code)); return toK({ ok: true, output: out, error: '', line: 0, steps: r.steps }); }
        catch (e) { return toK({ ok: false, output: out, error: e.message, line: e.line || 0, steps: sb.totalSteps }); }
      }, 2, 3),
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
        try { const r = await sb.run(S(code)); return toK({ ok: true, output: out, error: '', line: 0, steps: r.steps }); }
        catch (e) { return toK({ ok: false, output: out, error: e.message, line: e.line || 0, steps: sb.totalSteps }); }
      }, 1, 2),
    };

    const sandboxUi = () => { const o = Object.assign({}, ui); for (const k of ['on_key', 'set_window_title', 'set_theme', 'set_accent', 'confirm', 'every']) delete o[k]; return o; };
    const keyHandlers = new Map();
    interp = new K.Interpreter({
      maxSteps: opts.maxSteps || 2000000, yieldEvery: 3000, hooks: opts.hooks || null,
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
    const f = main.keyHandlers.get(k); if (f) { if (ev) ev.preventDefault(); main.invoke(f, [], 'key: ' + k); }
  }
  window.addEventListener('keydown', (e) => handleKey(keyName(e), e));
  window.native.onKey((k) => handleKey(k));
  window.native.onOpenTab((u) => main.openTabFromPage(u));
  main.run(window.native.browserSource()).catch((e) => { showError(e.message); if (window.KompassDevtools) window.KompassDevtools.error(e); });
})();
