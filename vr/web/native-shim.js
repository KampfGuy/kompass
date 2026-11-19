/* Kompass VR — window.native for Android (Meta Quest / Horizon OS).
 *
 * On Windows, src/preload.js + src/main.js (Electron) provide window.native and <webview>. Electron does not run on
 * Android, so in the VR APK this file provides the SAME window.native contract on top of the Java bridge
 * `KompassAndroid` (android/app/src/main/java/com/kampfguy/kompass/vr/Bridge.java), and replaces Electron's <webview>
 * with <kompass-webview>: a placeholder element whose on-screen rectangle is mirrored by a real native Android WebView
 * layered on top of the UI. src/host.js, src/lang.js, src/render.js, editor.js, devtools.js run unchanged.
 *
 * Without KompassAndroid (a desktop browser opening vr/www for preview/screenshots) a small localStorage + iframe
 * fallback is used so the VR UI can be looked at and tested headlessly. */
(function () {
  'use strict';
  const A = window.KompassAndroid || null;
  const ANDROID = !!A;
  const KS = new URL('ks/', location.href).href;       // bundled resources (browser.ks, store, videos, ...)
  const PROXY = 'https://kampfos-proxy.kampfguy.workers.dev';
  const listeners = {};
  const on = (ev, f) => { (listeners[ev] = listeners[ev] || []).push(f); };
  const emit = (ev, p) => { for (const f of listeners[ev] || []) { try { f(p); } catch (e) { console.error('[vr shim] ' + ev, e); } } };

  function syncText(url) {
    try { const x = new XMLHttpRequest(); x.open('GET', url, false); x.send(null); return (x.status === 200 || x.status === 0) && x.responseText !== '' ? x.responseText : null; }
    catch (e) { return null; }
  }
  const manifest = (() => { try { return JSON.parse(syncText(KS + 'manifest.json') || '{}'); } catch (e) { return {}; } })();
  const shippedFiles = new Set(manifest.files || []);
  const VERSION = manifest.version || '0.0.0';

  // ------------------------------------------------------------------ bridge: sync + async calls
  let seq = 1; const pending = new Map();
  const call = ANDROID
    ? (m, ...args) => { const r = JSON.parse(A.call(m, JSON.stringify(args)) || '{"r":null}'); if (r.e) throw new Error(r.e); return r.r === undefined ? null : r.r; }
    : (m, ...args) => web[m] ? web[m](...args) : null;
  const callAsync = ANDROID
    ? (m, ...args) => new Promise((res) => { const id = seq++; pending.set(id, res); A.callAsync(id, m, JSON.stringify(args)); })
    : async (m, ...args) => (webAsync[m] ? webAsync[m](...args) : null);
  // Java -> JS entry points (evaluateJavascript)
  window.__kvr = {
    done(id, json) { const f = pending.get(id); pending.delete(id); if (f) f(JSON.parse(json).r); },
    emit(ev, json) { emit(ev, json === undefined ? null : JSON.parse(json)); },
    tab(vid, ev, json) { const w = views.get(vid); if (w) w._event(ev, JSON.parse(json || '{}')); },
  };

  // network without CORS/Origin (the Kugel proxy only answers Kompass, not arbitrary web origins)
  async function nativeFetch(url, opts) {
    opts = opts || {};
    const req = { url: String(url), method: opts.method || 'GET', headers: opts.headers || {}, body: opts.body === undefined ? null : String(opts.body), noRedirect: opts.redirect === 'error' };
    const r = ANDROID ? await callAsync('http', req) : await (async () => {
      const x = await window.__origFetch(req.url, { method: req.method, headers: req.headers, body: req.body || undefined, redirect: opts.redirect });
      return { status: x.status, body: await x.text() };
    })();
    if (!r || r.error) throw new Error((r && r.error) || 'network error');
    return { ok: r.status >= 200 && r.status < 300, status: r.status, text: async () => r.body, json: async () => JSON.parse(r.body) };
  }
  window.__origFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    const u = typeof input === 'string' ? input : (input && input.url) || '';
    if (ANDROID && u.startsWith(PROXY)) return nativeFetch(u, init);
    return window.__origFetch(input, init);
  };

  // ------------------------------------------------------------------ web preview fallback (no Android)
  const LS = 'kompass-vr:';
  const web = {
    load: (n) => localStorage.getItem(LS + 'data/' + n),
    save: (n, j) => { localStorage.setItem(LS + 'data/' + n, j); return true; },
    listScripts: () => Object.keys(localStorage).filter(k => k.startsWith(LS + 'scripts/')).map(k => k.slice((LS + 'scripts/').length)),
    readScript: (n) => localStorage.getItem(LS + 'scripts/' + n),
    writeScript: (n, s) => { if (!/\.ks$/.test(n)) n += '.ks'; localStorage.setItem(LS + 'scripts/' + n, s); return n; },
    browserSource: () => { const u = localStorage.getItem(LS + 'browser.ks'); return u || syncText(KS + 'browser.ks') || ''; },
    saveBrowserSource: (s) => { localStorage.setItem(LS + 'browser.ks', s); return true; },
    paths: () => ({ data: 'localStorage', scripts: 'localStorage', browserKs: 'localStorage' }),
    adblock: (o) => ({ on: o === null || o === undefined ? true : !!o, blocked: 0 }),
    openExternal: (u) => { window.open(u, '_blank'); },
    copyText: (t) => { try { navigator.clipboard.writeText(t); } catch (e) {} return true; },
    toast: (t) => console.log('[toast] ' + t),
    pwStatus: () => ({ exists: false, unlocked: false, count: 0 }),
    tabCreate: () => null, tabRect: () => null, tabDestroy: () => null,
  };
  const webAsync = {};
  ['pwUnlock', 'pwList', 'pwSave', 'pwDelete', 'pwReveal', 'pwCopy'].forEach(m => { web[m] = () => ({ ok: false, error: 'Passwords need the Kompass VR app' }); });

  // ------------------------------------------------------------------ the user's browser.ks (edit + upgrade rule like main.js)
  const defaultSource = () => syncText(KS + 'browser.ks') || '';
  const toast = (t) => call('toast', String(t));

  // ------------------------------------------------------------------ Kugel Store: reuse src/store.js (bundled as ks-store.js)
  const store = () => window.KugelStore;
  const storeOpts = () => ({ bundled: KS + 'store', fetch: nativeFetch });

  // ------------------------------------------------------------------ updater: GitHub releases with a Kompass-VR-*.apk asset
  const upd = { status: 'idle', current: VERSION, latest: '', progress: 0, error: '', url: '', kind: 'android-apk', autoUpdate: (localStorage.getItem(LS + 'autoUpdate') || '1') === '1' };
  const updL = [];
  const setUpd = (o) => { Object.assign(upd, o); for (const f of updL) f(Object.assign({}, upd)); };
  const cmpVer = (a, b) => { const p = (s) => String(s).replace(/^v/, '').split(/[.-]/).map(x => parseInt(x, 10) || 0); const x = p(a), y = p(b); for (let i = 0; i < Math.max(x.length, y.length); i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) - (y[i] || 0); } return 0; };   // 1.5.1-vr.2 > 1.5.1-vr.1
  async function updCheck() {
    setUpd({ status: 'checking', error: '' });
    try {
      const r = await nativeFetch('https://api.github.com/repos/KampfGuy/kompass/releases?per_page=20', { headers: { accept: 'application/vnd.github+json', 'user-agent': 'Kompass-VR' } });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const rel = (await r.json()).find(x => !x.draft && (x.assets || []).some(a => /^Kompass-VR-.*\.apk$/i.test(a.name)));
      if (!rel) { setUpd({ status: 'uptodate', latest: VERSION }); return Object.assign({}, upd); }
      const asset = rel.assets.find(a => /^Kompass-VR-.*\.apk$/i.test(a.name));
      const latest = String(rel.tag_name || '').replace(/^v/, '');
      if (cmpVer(latest, VERSION) > 0) setUpd({ status: 'available', latest, url: asset.browser_download_url });
      else setUpd({ status: 'uptodate', latest });
    } catch (e) { setUpd({ status: 'error', error: e.message }); }
    return Object.assign({}, upd);
  }

  // ------------------------------------------------------------------ window.native (same shape as src/preload.js)
  window.native = {
    browserSource: () => call('browserSource') || defaultSource(),
    defaultSource,
    saveBrowserSource: (s) => call('saveBrowserSource', String(s)),
    paths: () => call('paths'),
    load: (n) => call('load', String(n)),
    save: (n, j) => call('save', String(n), String(j)),
    listScripts: () => call('listScripts') || [],
    readScript: (n) => call('readScript', String(n)),
    writeScript: (n, s) => call('writeScript', String(n), String(s)),
    adblock: (o) => call('adblock', o === undefined ? null : o),
    openExternal: (u) => { if (/^https?:\/\//.test(u)) call('openExternal', String(u)); },
    openFolder: () => { const p = call('paths'); toast('Kompass VR data: ' + (p ? p.data : '?') + ' (use adb / SideQuest to browse it)'); },
    reloadApp: () => location.reload(),
    devtools: () => { call('webDebugging', true); toast('Debugging on: connect over adb and open chrome://inspect on your PC'); },
    capture: async () => false,
    argv: () => [],
    quit: () => call('quit'),
    version: () => VERSION,
    clearBrowsingData: () => callAsync('clearBrowsingData'),
    videoFile: (n) => { n = String(n); return /^[a-zA-Z0-9_-]+\.(mp4|webm)$/.test(n) && shippedFiles.has('videos/' + n) ? KS + 'videos/' + n : null; },
    videosFolder: () => 'built into the Kompass VR app',
    openVideosFolder: () => toast('The tutorial videos are built into Kompass VR'),
    readResource: (n) => { n = String(n); if (!/^[A-Za-z0-9_-]+\.(md|txt|ks)$/.test(n)) return ''; return syncText(KS + n) || ''; },
    copyText: (t) => call('copyText', String(t)),
    saveTextFile: async (n, t) => (ANDROID ? callAsync('saveTextFile', String(n || 'kompass.txt'), String(t)) : ''),
    store: {
      index: async () => store().indexVR(storeOpts()),   // Kompass VR lists only the VR games (index-vr.json, tag "vr")
      code: async (id) => { const r = await store().get('entries/' + String(id) + '.ks', storeOpts()); return r.ok ? { ok: true, code: r.text, source: r.source } : r; },
      publish: async (p) => {
        const r = await store().publish(Object.assign({}, p || {}, { version: VERSION }), { fetch: nativeFetch });
        if (!r.ok) return r;
        if (r.copied) window.native.copyText(String((p && p.code) || ''));
        window.native.openExternal(r.url);
        return r;
      },
    },
    pw: {
      status: () => call('pwStatus'),
      unlock: (m) => call('pwUnlock', String(m || '')),
      lock: () => call('pwLock'),
      list: (q) => call('pwList', String(q || '')),
      save: (id, o, u, p) => call('pwSave', id, String(o), String(u || ''), p === null || p === undefined ? null : String(p)),
      remove: (id) => call('pwDelete', String(id)),
      reveal: (id) => call('pwReveal', String(id)),
      copy: (id) => call('pwCopy', String(id)),
      generate: (n) => call('pwGenerate', n | 0) || '',
      offer: () => ({ ok: true }),                      // Kompass VR does not watch web logins (no autofill yet)
      exportTo: async () => ({ ok: false, error: 'Export is not available in Kompass VR yet' }),
      importFrom: async () => ({ ok: false, error: 'Import is not available in Kompass VR yet' }),
      onOffer: () => {},
      onLocked: (f) => on('pw-locked', f),
    },
    update: {
      state: () => Object.assign({}, upd),
      check: updCheck,
      auto: (o) => { localStorage.setItem(LS + 'autoUpdate', o ? '1' : '0'); setUpd({ autoUpdate: !!o }); return Object.assign({}, upd); },
      install: () => { window.native.openExternal(upd.url || 'https://github.com/KampfGuy/kompass/releases'); return true; },
      onState: (f) => updL.push(f),
    },
    // fullscreen (Kompass 1.5.2): a Quest panel is already "the whole window"; host.js hides the browser chrome itself
    setFullscreen: (o) => { fsOn = !!o; if (ANDROID) call('setFullscreen', fsOn); },
    onFullscreen: (f) => on('fullscreen', f),
    onDoubleRight: (f) => on('double-right', f),
    onOpenTab: (f) => on('open-tab', f),
    onKey: (f) => on('key', f),
  };
  window.KompassVR = { android: ANDROID, version: VERSION, emit, on, call, callAsync, nativeFetch, toast, currentStoreGame: () => currentStoreGame(), pad: () => vpad };

  // ------------------------------------------------------------------ 3D + VR (Kompass 1.5.3-vr)
  // Quest: render 3D scenes at pixel ratio 1 (a big panel on a mobile GPU).
  if (ANDROID) window.KOMPASS_MAX_PIXEL_RATIO = 1;
  // Controller / Bluetooth gamepad buttons and sticks that Android delivers to the app (MainActivity forwards them)
  // become a standard-mapping gamepad for gamepad() in KampfScript, next to any real Gamepad API pads.
  const vpad = { id: 'Kompass VR controller', index: 0, connected: false, mapping: 'standard', timestamp: 0, axes: [0, 0, 0, 0], buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })) };
  on('pad', (p) => {
    if (!p) return; vpad.connected = true; vpad.timestamp = performance.now();
    if (Array.isArray(p.axes)) for (let i = 0; i < 4; i++) vpad.axes[i] = +p.axes[i] || 0;
    if (p.button !== undefined) { const b = vpad.buttons[p.button | 0]; if (b) { b.pressed = !!p.down; b.value = p.down ? 1 : 0; } }
    if (p.lt !== undefined) { const b = vpad.buttons[6]; b.value = +p.lt || 0; b.pressed = b.value > 0.3; }
    if (p.rt !== undefined) { const b = vpad.buttons[7]; b.value = +p.rt || 0; b.pressed = b.value > 0.3; }
  });
  const realPads = navigator.getGamepads ? navigator.getGamepads.bind(navigator) : () => [];
  try { navigator.getGamepads = () => { const l = Array.from(realPads() || []); if (vpad.connected && !l.some(g => g && g.connected)) return [vpad]; return l; }; } catch (e) { /* read-only */ }
  // Immersive VR: Android's System WebView has no WebXR, so vr_start() in the APK hands the Kugel Store game that is open
  // to the Quest Browser (which has WebXR): the app serves its own web bundle on http://127.0.0.1 (a secure context)
  // and opens index.html#play=<game id> there. In a browser with WebXR this is not used (vr_start() goes immersive).
  let fsOn = false;
  const currentStoreGame = () => { const a = document.querySelector('.address'); const m = a && /^kompass:\/\/store\/([a-z0-9][a-z0-9_-]{0,47})$/.exec(String(a.value).trim()); return m ? m[1] : null; };
  if (ANDROID) window.KompassVRHandoff = () => {
    const id = currentStoreGame();
    if (!id) { toast('Immersive VR runs in the Quest Browser: start a VR game from the Kugel Store to play it in the headset'); return false; }
    toast('Opening ' + id + ' in the Quest Browser for immersive VR…'); return !!call('vrLaunch', id);
  };
  // play mode (the Quest Browser side): open the game as soon as the Kompass UI is up
  const play = /[#&]play=([a-z0-9][a-z0-9_-]{0,47})/.exec(location.hash);
  if (!ANDROID && play) { window.KompassVRPlay = play[1]; addEventListener('load', () => setTimeout(() => emit('open-tab', 'kompass://store/' + play[1]), 900)); }
  if (upd.autoUpdate && ANDROID) setTimeout(updCheck, 8000);

  // ------------------------------------------------------------------ <webview> replacement
  // host.js does document.createElement('webview') and uses: src, loadURL, canGoBack/Forward, goBack/Forward, reload,
  // stop, setZoomFactor, findInPage, stopFindInPage, setAudioMuted, openDevTools + Electron events.
  const views = new Map(); let vseq = 1;
  class KompassWebview extends HTMLElement {
    constructor() { super(); this.vid = vseq++; this.st = { canBack: false, canFwd: false, url: '' }; this.created = false; this.last = ''; this._src = ''; }
    set src(u) { this._src = String(u); if (this.created && this._src && this._src !== 'about:blank') this.loadURL(this._src); }
    get src() { return this.st.url || this._src; }
    connectedCallback() {
      if (this.created) return; this.created = true; views.set(this.vid, this);
      if (ANDROID) call('tabCreate', this.vid);
      else { this.frame = document.createElement('iframe'); this.frame.className = 'kvr-frame'; this.frame.setAttribute('sandbox', 'allow-scripts allow-forms allow-popups'); this.appendChild(this.frame);
        this.frame.addEventListener('load', () => { this._event('stop', {}); }); }
      setTimeout(() => { this.dispatch('dom-ready'); if (this._src && this._src !== 'about:blank') this.loadURL(this._src); }, 0);
      scheduleLayout();
    }
    disconnectedCallback() { setTimeout(() => { if (!this.isConnected && views.has(this.vid)) { views.delete(this.vid); if (ANDROID) call('tabDestroy', this.vid); } }, 0); }
    dispatch(type, props) { const e = new Event(type); Object.assign(e, props || {}); this.dispatchEvent(e); }
    _event(ev, d) {
      if ('canBack' in d) this.st.canBack = !!d.canBack; if ('canFwd' in d) this.st.canFwd = !!d.canFwd; if (d.url) this.st.url = d.url;
      if (ev === 'start') this.dispatch('did-start-loading');
      else if (ev === 'stop') this.dispatch('did-stop-loading');
      else if (ev === 'navigate') this.dispatch('did-navigate', { url: d.url });
      else if (ev === 'navigate-in-page') this.dispatch('did-navigate-in-page', { url: d.url, isMainFrame: true });
      else if (ev === 'title') this.dispatch('page-title-updated', { title: d.title });
      else if (ev === 'favicon') this.dispatch('page-favicon-updated', { favicons: [d.favicon] });
      else if (ev === 'fail') this.dispatch('did-fail-load', { isMainFrame: true, errorCode: d.code, errorDescription: d.description });
      else if (ev === 'longpress') { const r = this.getBoundingClientRect(); const va = this.closest('.ks-viewarea'); const o = va ? va.getBoundingClientRect() : r;
        longPressFired(); emit('double-right', { x: d.x + r.left - o.left, y: d.y + r.top - o.top, web: true, link: d.link || '' }); }
    }
    loadURL(u) {
      u = String(u); this.st.url = u;
      if (ANDROID) call('tabLoad', this.vid, u);
      else { this.dispatch('did-start-loading'); this.frame.src = u; this.dispatch('did-navigate', { url: u }); }
    }
    canGoBack() { return this.st.canBack; }
    canGoForward() { return this.st.canFwd; }
    goBack() { if (ANDROID) call('tabBack', this.vid); else try { this.frame.contentWindow.history.back(); } catch (e) {} }
    goForward() { if (ANDROID) call('tabForward', this.vid); else try { this.frame.contentWindow.history.forward(); } catch (e) {} }
    reload() { if (ANDROID) call('tabReload', this.vid); else if (this.frame.src) this.frame.src = this.frame.src; }
    stop() { if (ANDROID) call('tabStop', this.vid); }
    setZoomFactor(f) { if (ANDROID) call('tabZoom', this.vid, +f || 1); }
    findInPage(q) { if (ANDROID) call('tabFind', this.vid, String(q)); }
    stopFindInPage() { if (ANDROID) call('tabFind', this.vid, ''); }
    setAudioMuted(m) { if (ANDROID) call('tabMute', this.vid, !!m); }
    openDevTools() { window.native.devtools(); }
  }
  customElements.define('kompass-webview', KompassWebview);
  const createEl = Document.prototype.createElement;
  document.createElement = function (tag, o) { return createEl.call(this, String(tag).toLowerCase() === 'webview' ? 'kompass-webview' : tag, o); };

  // Keep every native WebView exactly over its placeholder. A native view always draws ABOVE the HTML UI, so when
  // something of the UI covers the page (quick menu, popup, editor, DevTools) the native view is hidden meanwhile.
  function covered(el, r) {
    for (const p of document.querySelectorAll('.ks-popup, .kvr-overlay')) { const q = p.getBoundingClientRect(); if (q.right > r.left && q.left < r.right && q.bottom > r.top && q.top < r.bottom) return true; }
    const pts = [[0.5, 0.5], [0.06, 0.06], [0.94, 0.06], [0.06, 0.94], [0.94, 0.94]];
    for (const [fx, fy] of pts) { const h = document.elementFromPoint(r.left + r.width * fx, r.top + r.height * fy); if (h && h !== el && !el.contains(h)) return true; }
    return false;
  }
  let layoutQueued = false;
  function scheduleLayout() { if (!layoutQueued) { layoutQueued = true; requestAnimationFrame(layout); } }
  function layout() {
    layoutQueued = false;
    const dpr = window.devicePixelRatio || 1;
    for (const w of views.values()) {
      const r = w.getBoundingClientRect();
      const vis = w.isConnected && w.getClientRects().length > 0 && r.width > 2 && r.height > 2 && !document.hidden && !covered(w, r);
      const key = vis ? [r.left, r.top, r.width, r.height].map(v => Math.round(v * dpr)).join(',') : 'hidden';
      if (key !== w.last) { w.last = key; if (ANDROID) { if (vis) { const k = key.split(',').map(Number); call('tabRect', w.vid, k[0], k[1], k[2], k[3], true); } else call('tabRect', w.vid, 0, 0, 0, 0, false); } }
    }
  }
  setInterval(scheduleLayout, 120);
  addEventListener('resize', scheduleLayout);
  new MutationObserver(scheduleLayout).observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ['hidden', 'class', 'style'] });

  // ------------------------------------------------------------------ VR input: long-press replaces double-right-click
  // Quest controllers (trigger = click) and hand tracking (pinch = tap) have no right mouse button. Holding the
  // trigger / pinch for ~0.6 s anywhere opens the Kompass quick menu (browser.ks on_double_right_click handler);
  // on web pages the Java side reports the long-press (with the link under the ray, if any).
  let lp = null, suppressClickUntil = 0, lastFire = 0;
  function longPressFired() { lastFire = Date.now(); suppressClickUntil = Date.now() + 700; }
  const noLong = (t) => !t || !t.closest || t.closest('input, textarea, select, canvas, video, .ks-codebox, kompass-webview, .ks-popup, .ed-root, .dt-root');
  addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || noLong(e.target)) return;
    const x = e.clientX, y = e.clientY;
    lp = { x, y, t: setTimeout(() => { lp = null; if (Date.now() - lastFire < 800) return; longPressFired(); emit('double-right', { x, y, web: false, link: '' }); }, 600) };
  }, true);
  addEventListener('pointermove', (e) => { if (lp && Math.hypot(e.clientX - lp.x, e.clientY - lp.y) > 14) { clearTimeout(lp.t); lp = null; } }, true);
  for (const ev of ['pointerup', 'pointercancel']) addEventListener(ev, () => { if (lp) { clearTimeout(lp.t); lp = null; } }, true);
  addEventListener('click', (e) => { if (Date.now() < suppressClickUntil) { e.preventDefault(); e.stopPropagation(); suppressClickUntil = 0; } }, true);
  addEventListener('contextmenu', (e) => {
    if (noLong(e.target)) return; e.preventDefault();
    if (Date.now() - lastFire < 800) return; longPressFired(); emit('double-right', { x: e.clientX, y: e.clientY, web: false, link: '' });
  }, true);

  // ------------------------------------------------------------------ on-screen keyboard friendly text fields
  function tuneInput(i) {
    if (i.dataset.kvr) return; i.dataset.kvr = '1';
    i.setAttribute('autocapitalize', 'off'); i.setAttribute('autocomplete', 'off');
    if (i.classList.contains('address')) { i.setAttribute('enterkeyhint', 'go'); i.setAttribute('spellcheck', 'false'); i.setAttribute('autocorrect', 'off'); }
    else if (i.tagName === 'INPUT' && i.type !== 'password' && i.type !== 'range' && i.type !== 'checkbox') i.setAttribute('enterkeyhint', 'enter');
    i.addEventListener('focus', () => setTimeout(() => { try { i.scrollIntoView({ block: 'center', behavior: 'smooth' }); } catch (e) {} }, 350));
    // Enter / "Go" on the system keyboard: let host.js run on_enter first, then close the keyboard so the result is visible
    if (i.tagName === 'INPUT') i.addEventListener('keydown', (e) => { if (e.key === 'Enter') setTimeout(() => i.blur(), 0); });
  }
  // browser.ks focuses text boxes by itself (home page search, address bar). In a headset that would pop up the
  // system keyboard over the page every time a page opens, so in the APK programmatic focus of a text field is only
  // honoured right after a physical-keyboard key press (e.g. Ctrl+L); pointing at a field and clicking still works.
  if (ANDROID) {
    let lastKey = 0; addEventListener('keydown', () => { lastKey = Date.now(); }, true);
    for (const P of [HTMLInputElement.prototype, HTMLTextAreaElement.prototype]) {
      const f = P.focus, sel = P.select;
      const allowed = (el) => el.type === 'range' || el.type === 'checkbox' || Date.now() - lastKey < 1500 || document.activeElement === el;
      P.focus = function (o) { if (allowed(this)) return f.call(this, o); };
      P.select = function () { if (allowed(this)) return sel.call(this); };   // select() would focus (and open the keyboard) too
    }
  }
  new MutationObserver((ms) => { for (const m of ms) for (const n of m.addedNodes) if (n.nodeType === 1) { if (n.matches('input, textarea')) tuneInput(n); n.querySelectorAll && n.querySelectorAll('input, textarea').forEach(tuneInput); } })
    .observe(document.documentElement, { subtree: true, childList: true });

  document.documentElement.classList.add('kompass-vr', ANDROID ? 'kvr-android' : 'kvr-preview');
})();
