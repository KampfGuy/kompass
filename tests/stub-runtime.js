// Headless stand-in for the Kompass page runtime: every UI built-in exists (from src/host.js) and returns a
// fake element, canvas draws are counted, on_frame / on_mouse / on_keypress handlers are captured so tests
// can drive a page like a user would. Used by tests/v13.test.js.
const K = require('../src/lang.js');
const { realBuiltins } = require('../tools/gen-ai-doc.js');
function stubRuntime(opts) {
  opts = opts || {};
  const real = realBuiltins();
  const calls = {}, frames = [], mice = [], keys = [], store = Object.assign({}, opts.store || {}), down = new Set();
  const out = [];
  const b = {};
  const H = (kind) => new K.KHandle(kind, { text: '', value: '' });
  for (const n of [...real.ui, ...real.page]) b[n] = { fn: () => { calls[n] = (calls[n] || 0) + 1; return H('box'); }, min: 0, max: 9 };
  const count = (n, f) => ({ fn: (a, c) => { calls[n] = (calls[n] || 0) + 1; return f(a, c); }, min: 0, max: 9 });
  const hostSrc = require('fs').readFileSync(require('path').join(__dirname, '..', 'src', 'host.js'), 'utf8');
  const cssBlock = hostSrc.slice(hostSrc.indexOf('const CSS_PROPS = ['), hostSrc.indexOf('];', hostSrc.indexOf('const CSS_PROPS = [')));
  const CSS = new Set([...cssBlock.matchAll(/'([a-z-]+)'/g)].map(m => m[1]));
  const checkCss = (st, who) => { if (st instanceof K.KMap) for (const k of st.m.keys()) if (!CSS.has(k) && !k.startsWith('--')) throw new Error(who + ': property not allowed: ' + k); };
  for (const n of ['setstyle', 'style']) if (b[n]) b[n] = count(n, (a) => { for (const x of a) checkCss(x, n + '()'); if (typeof a[1] === 'string' && !CSS.has(a[1])) throw new Error(n + '(): property not allowed: ' + a[1]); return null; });
  b.canvas = count('canvas', () => H('canvas'));
  b.canvas_size = count('canvas_size', () => new K.KMap({ w: 1280, h: 720 }));
  b.slider = count('slider', ([p, lo, hi, v]) => { const h = H('slider'); h.el.value = v; return h; });
  b.checkbox = count('checkbox', ([p, t, on]) => { const h = H('checkbox'); h.el.value = !!on; return h; });
  b.dropdown = count('dropdown', () => H('dropdown'));
  b.textbox = count('textbox', () => H('textbox'));
  b.settext = count('settext', ([h, t]) => { if (h && h.el) h.el.text = K.show(t); return null; });
  b.gettext = count('gettext', ([h]) => h && h.el ? h.el.text : '');
  b.setvalue = count('setvalue', ([h, v]) => { if (h && h.el) h.el.value = v; return null; });
  b.getvalue = count('getvalue', ([h]) => h && h.el ? h.el.value : '');
  b.on_frame = count('on_frame', ([f]) => { frames.push(f); return frames.length; });
  b.on_mouse = count('on_mouse', ([h, f]) => { mice.push([h, f]); return null; });
  b.on_keypress = count('on_keypress', ([f]) => { keys.push(f); return null; });
  b.on_click = count('on_click', ([h, f]) => { h.el.click = f; return null; });
  b.button = count('button', ([p, t, f]) => { const h = H('button'); h.el.text = K.show(t); h.el.click = f; (b.button.all = b.button.all || []).push(h); return h; });
  b.link = count('link', ([p, t, f]) => { const h = H('link'); h.el.text = K.show(t); h.el.click = f; (b.button.all = b.button.all || []).push(h); return h; });
  b.key_down = count('key_down', ([k]) => down.has(K.show(k)));
  b.store_get = count('store_get', ([k, d]) => (K.show(k) in store) ? store[K.show(k)] : (d === undefined ? null : d));
  b.store_set = count('store_set', ([k, v]) => { store[K.show(k)] = v; return true; });
  b.after = count('after', () => null);
  const it = new K.Interpreter({ builtins: b, maxSteps: 2000000, onPrint: (x) => out.push(x), onError: (e) => { throw e; } });
  const api = {
    it, calls, frames, mice, keys, store, down, out,
    run: (src) => it.run(src),
    frame: async (dt) => { for (const f of frames) await it.invoke(f, [dt === undefined ? 1 / 60 : dt]); },
    press: async (k) => { for (const f of keys) await it.invoke(f, [k]); },
    click: async (text) => { const h = (b.button.all || []).filter(h => h.el.text === text).pop(); if (!h) throw new Error('no button "' + text + '"'); if (h.el.click) await it.invoke(h.el.click, []); },
    get: (name) => it.globals.get(name),
  };
  return api;
}
module.exports = { stubRuntime };
