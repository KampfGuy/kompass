// Run: node tests/v15.test.js — Kompass 1.5: flicker-free rendering (render commit layer + atomic callbacks) and the Kugel Store.
const fs = require('fs'), path = require('path'), assert = require('assert'), http = require('http');
const K = require('../src/lang.js');
const { createRenderer } = require('../src/render.js');
const store = require('../src/store.js');
const ROOT = path.join(__dirname, '..');
let passed = 0;
const ok = (m) => { passed++; console.log('  ok   ' + m); };

// ---- tiny fake DOM: enough for the renderer; records every removal/insert and what a "paint" would show
const removedLog = [];
class El {
  constructor(tag) { this.tagName = tag.toUpperCase(); this.childNodes = []; this.parentNode = null; this.className = ''; this.textContent = ''; this._w = 300; this._h = 150; this.resets = 0; }
  get children() { return this.childNodes; }
  appendChild(c) { return this.insertBefore(c, null); }
  insertBefore(c, ref) { if (c.parentNode) c.parentNode._detach(c); const i = ref ? this.childNodes.indexOf(ref) : -1; if (i < 0) this.childNodes.push(c); else this.childNodes.splice(i, 0, c); c.parentNode = this; return c; }
  _detach(c) { const i = this.childNodes.indexOf(c); if (i >= 0) this.childNodes.splice(i, 1); c.parentNode = null; }
  removeChild(c) { this._detach(c); removedLog.push(c); return c; }
  replaceChildren(...n) { for (const c of [...this.childNodes]) this.removeChild(c); for (const c of n) this.appendChild(c); }
  addEventListener() {}
  isEqualNode(o) { return o.tagName === this.tagName && o.className === this.className && o.textContent === this.textContent && o.childNodes.length === this.childNodes.length && this.childNodes.every((c, i) => c.isEqualNode(o.childNodes[i])); }
  get width() { return this._w; } set width(v) { this._w = v; this.resets++; this.pixels = []; }
  get height() { return this._h; } set height(v) { this._h = v; this.resets++; this.pixels = []; }
  getContext() { const el = this; return this.ctx || (this.ctx = { setTransform() {}, drawImage(src) { el.pixels = [...(src.pixels || [])]; }, clearRect() { el.pixels = []; }, fillRect(...a) { el.pixels.push(a.join(',')); }, set globalAlpha(v) {}, set globalCompositeOperation(v) {} }); }
}
const document = { createElement: (t) => new El(t) };
const rafQ = []; const raf = (f) => rafQ.push(f);
const text = (e) => e.childNodes.map(c => c.textContent).join('|');

(async () => {
  // -------------------------------------------------------------- 1. root cause: the interpreter yielded mid-callback
  {
    const src = 'let n = 0\nfn work() { for i in range(5000) { n += 1 } }';
    const run = async (atomicMs) => {
      const it = new K.Interpreter({ maxSteps: 1e7, yieldEvery: 100, atomicMs }); await it.run(src);
      let macrotaskRanDuringCallback = false; const done = it.invoke(it.globals.get('work'), []);
      setTimeout(() => { macrotaskRanDuringCallback = !finished; }, 0); let finished = false;
      await done; finished = true; await new Promise(r => setTimeout(r, 5)); return macrotaskRanDuringCallback;
    };
    assert.strictEqual(await run(0), true, 'old behaviour: a timer (and so a paint) could run in the middle of a callback');
    assert.strictEqual(await run(50), false, 'atomic: no paint opportunity inside a callback');
    // a runaway callback still yields once the budget is used up (the app never freezes)
    const it = new K.Interpreter({ maxSteps: 1e8, yieldEvery: 100, atomicMs: 5 }); await it.run('fn spin() { let t = 0\nwhile t < 400000 { t += 1 } }');
    let ticks = 0; const iv = setInterval(() => ticks++, 0); await it.invoke(it.globals.get('spin'), []); clearInterval(iv);
    assert(ticks > 0, 'long callbacks still let the UI breathe after the budget');
    ok('root cause reproduced: interpreter yielded to the event loop mid-callback (paint of half-updated UI); atomicMs fixes it, with a budget');
  }

  // -------------------------------------------------------------- 2. DOM: clear()+rebuild keeps the same nodes, no blank state
  {
    const R = createRenderer({ document, raf, now: () => 0 });
    const hud = new El('div');
    const H = (e) => { const h = { el: e }; R.track(e, h); return h; };
    const label = (p, t) => { const e = new El('span'); e.className = 'ks-label'; e.textContent = t; R.target(p).appendChild(e); return H(e); };
    const render = (fuel, speed) => R.run(() => { R.clear(hud); label(hud, 'HUD'); label(hud, 'Fuel ' + fuel); label(hud, 'Speed ' + speed); });
    render(100, 0);
    const before = [...hud.childNodes]; removedLog.length = 0;
    // state change: during the callback the visible HUD must never be empty
    R.begin(); R.clear(hud); assert.strictEqual(text(hud), 'HUD|Fuel 100|Speed 0', 'clear() inside a batch does not blank the screen');
    const l1 = label(hud, 'HUD'); label(hud, 'Fuel 100'); const sp = label(hud, 'Speed 12');
    assert.strictEqual(text(hud), 'HUD|Fuel 100|Speed 0', 'half-built state is invisible'); R.end();
    assert.strictEqual(text(hud), 'HUD|Fuel 100|Speed 12');
    assert.strictEqual(hud.childNodes[0], before[0], 'unchanged "HUD" label is the SAME node');
    assert.strictEqual(hud.childNodes[1], before[1], 'unchanged "Fuel" label is the SAME node');
    assert.strictEqual(l1.el, before[0], 'the script handle is re-targeted to the kept node (settext etc. still work)');
    assert.strictEqual(removedLog.length, 1, 'only the one changed node was replaced'); assert.strictEqual(sp.el, hud.childNodes[2]);
    // identical re-render: nothing removed or recreated at all
    const keep = [...hud.childNodes]; removedLog.length = 0; render(100, 12);
    assert.deepStrictEqual(hud.childNodes, keep); assert.strictEqual(removedLog.length, 0);
    // buttons (listeners) and canvases are never swapped for stale ones
    const b = new El('button'); b.textContent = 'ON'; const hb = H(b); hb.el.addEventListener('click', () => {}); hud.appendChild(b);
    assert(b.__ksL, 'listener marked');
    // outside a batch clear() is immediate (old behaviour)
    R.clear(hud); assert.strictEqual(hud.childNodes.length, 0);
    ok('clear()+rebuild in a callback: no empty frame, unchanged elements are NOT removed or recreated, only real changes patched, handles re-targeted');
  }

  // -------------------------------------------------------------- 3. canvas: double buffer, resize only when the size changes
  {
    const R = createRenderer({ document, raf, now: () => 0 });
    const front = new El('canvas'); const h = { el: front }; R.setupCanvas(h);
    const frame = (n) => R.run(() => { R.sizeBack(h, 800, 600); h.back.pixels = []; R.touched(h); for (let i = 0; i < n; i++) { h.back.pixels.push('obj' + i); R.touched(h); } });
    frame(3); assert.deepStrictEqual(front.pixels, ['obj0', 'obj1', 'obj2']);
    const resets = front.resets;
    R.begin(); h.back.pixels = []; h.back.pixels.push('x'); R.touched(h);
    assert.deepStrictEqual(front.pixels, ['obj0', 'obj1', 'obj2'], 'visible canvas keeps the last full frame while the next is drawn'); R.end();
    assert.deepStrictEqual(front.pixels, ['x']);
    for (let i = 0; i < 30; i++) frame(2);
    assert.strictEqual(front.resets, resets, 'same size every frame -> the visible canvas is never resized (resizing clears it)');
    R.run(() => { R.sizeBack(h, 1024, 600); h.back.pixels = ['big']; R.touched(h); });
    assert.strictEqual(front.width, 1024); assert.deepStrictEqual(front.pixels, ['big'], 'real resize + redraw happen in the same commit');
    ok('canvas: draws go to a back buffer and are blitted in one commit; the visible canvas is only resized when its size really changes');
  }

  // -------------------------------------------------------------- 4. watchdog: a batch stuck open (debugger pause) still commits
  {
    let t = 0; const R = createRenderer({ document, raf, now: () => t });
    const p = new El('div'); p.appendChild(new El('i')); R.begin(); R.clear(p); R.target(p).appendChild(new El('b'));
    t = 1000; rafQ.splice(0).forEach(f => f());
    assert.strictEqual(p.childNodes[0].tagName, 'B'); R.end();
    ok('a batch that stays open (breakpoint) is committed after 250 ms so the screen still updates');
  }

  // -------------------------------------------------------------- 5. host.js / spaceflight wiring
  {
    const host = fs.readFileSync(path.join(ROOT, 'src/host.js'), 'utf8');
    assert(/atomicMs: 50/.test(host) && /clear: B\(\(\[x\]\) => \{ R\.clear\(/.test(host) && /R\.target\(el\(parent/.test(host));
    assert(/R\.run\(\(\) => interp\.invoke\(f, \[dt\], 'frame'\)\)/.test(host), 'on_frame commits once per frame');
    assert(!/c\.width = w; c\.height = hh/.test(host), 'fitCanvas no longer touches the visible canvas size');
    assert(/render\.js/.test(fs.readFileSync(path.join(ROOT, 'src/index.html'), 'utf8')));
    ok('host.js: every callback / frame / page run is one batch; clear(), new elements and draw_* go through the commit layer');
  }

  // -------------------------------------------------------------- 6. Kugel Store
  {
    const idx = JSON.parse(fs.readFileSync(path.join(ROOT, 'resources/store/index.json'), 'utf8'));
    const ents = store.cleanIndex(idx); assert(ents.length >= 3 && ents.some(e => e.id === 'spaceflight'));
    for (const e of ents) { const code = fs.readFileSync(path.join(ROOT, 'resources/store', e.file), 'utf8'); K.parse(code); }
    assert.deepStrictEqual(store.cleanIndex({ entries: [{ id: '../../etc/passwd' }, { id: 'ok-1', title: 'x'.repeat(500) }] }).map(e => [e.id, e.title.length]), [['ok-1', 60]]);
    assert(!store.fileOk('../main.js') && !store.fileOk('entries/../x.ks') && !store.fileOk('entries/a.js') && store.fileOk('entries/a-b.ks'));
    ok('store index is validated (ids, lengths, paths); bundled seed entries (Spaceflight Sim + demos) all parse');

    const srv = http.createServer((q, r) => { const u = q.url.split('?')[0]; if (u === '/index.json') { r.end(JSON.stringify(idx)); } else if (u === '/entries/clicker.ks') r.end('print("hi")'); else { r.statusCode = 404; r.end(); } });
    await new Promise(r => srv.listen(0, r)); const base = 'http://127.0.0.1:' + srv.address().port;
    const on = await store.index({ base }); assert(on.ok && on.source === 'online' && on.entries.length === ents.length);
    assert.strictEqual((await store.get('entries/clicker.ks', { base })).text, 'print("hi")');
    const off = await store.get('entries/clicker.ks', { base: 'http://127.0.0.1:1', bundled: path.join(ROOT, 'resources/store'), timeoutMs: 1000 });
    assert(off.ok && off.source === 'offline copy' && /Kugel Clicker/.test(off.text));
    assert(!(await store.get('entries/nope.ks', { base })).ok); srv.close();
    ok('store fetch: online from the repo, falls back to the bundled offline copy, 404 handled');

    const small = store.publishUrl({ title: 'Pong', description: 'a game', author: 'Kai', code: 'print("hi")\n```evil```', version: '1.5.0' });
    assert(small.url.startsWith('https://github.com/KampfGuy/kugel-store/issues/new?') && !small.copied);
    const body = decodeURIComponent(new URL(small.url).searchParams.get('body'));
    assert(/### Title\nPong/.test(body) && /print\("hi"\)/.test(body) && !/```evil```/.test(body), 'code fenced safely');
    const big = store.publishUrl({ title: 'Big', code: fs.readFileSync(path.join(ROOT, 'resources/spaceflight.ks'), 'utf8') });
    assert(big.copied && big.url.length <= store.MAX_URL && /Ctrl\+V/.test(decodeURIComponent(big.url)));
    ok('publish = prefilled GitHub issue URL (no token); code too big for a URL goes to the clipboard instead');

    const all = ['src/store.js', 'src/main.js', 'src/preload.js', 'src/host.js', 'src/editor.js', 'resources/browser.ks'].map(f => fs.readFileSync(path.join(ROOT, f), 'utf8')).join('\n');
    assert(!/gh[pousr]_[A-Za-z0-9]{20,}|github_pat_|Authorization:|Bearer /.test(all), 'no token in the app');
    const bks = fs.readFileSync(path.join(ROOT, 'resources/browser.ks'), 'utf8');
    assert(/run_page\(r\.code, stage, page_handlers\(id, false\), "store-" \+ sid\)/.test(bks), 'store code runs only through run_page (sandbox)');
    const hostSrc = fs.readFileSync(path.join(ROOT, 'src/host.js'), 'utf8');
    const sb = hostSrc.slice(hostSrc.indexOf('const sandboxUi'), hostSrc.indexOf('const keyHandlers'));
    assert(/opts\.sandbox \? Object\.assign\(sandboxUi\(\), opts\.extra/.test(hostSrc) && !/store_publish|read_script|open_external/.test(sb), 'sandbox gets only UI built-ins');
    assert(/storeNs/.test(hostSrc), 'each store program has its own storage namespace');
    ok('no secrets embedded; store programs run sandboxed (UI built-ins only, no native / file access, own storage)');
  }

  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('  FAIL ' + (e && e.stack || e)); process.exit(1); });
