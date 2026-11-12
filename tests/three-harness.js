// Runs the REAL src/kompass3d.js + bundled three.js in Node (only the WebGL renderer is faked) together with the
// stub page runtime, so tests can play 3D KampfScript games frame by frame. Used by tests/v153.test.js.
const fs = require('fs'), path = require('path');
const K = require('../src/lang.js');
const { stubRuntime } = require('./stub-runtime.js');
const ROOT = path.join(__dirname, '..');
let rafQ = []; let now = 0; const stats = { renders: 0 }; let pads = [];
const fakeEl = (extra) => Object.assign({ style: {}, children: [], classList: { add() {}, remove() {}, toggle() {} }, appendChild(c) { this.children.push(c); }, addEventListener() {},
  getBoundingClientRect: () => ({ width: 800, height: 450, left: 0, top: 0 }), isConnected: true, textContent: '' }, extra || {});
const ctx2d = new Proxy({}, { get: (t, k) => (k in t ? t[k] : () => ({ addColorStop() {} })), set: (t, k, v) => { t[k] = v; return true; } });
if (!global.Kompass3D) {
  global.window = global; global.devicePixelRatio = 1; global.addEventListener = () => {};
  global.document = { createElement: (tag) => fakeEl({ tagName: String(tag).toUpperCase(), width: 0, height: 0, getContext: () => ctx2d }), pointerLockElement: null, exitPointerLock() {} };
  global.requestAnimationFrame = (f) => { rafQ.push(f); return rafQ.length; };
  Object.defineProperty(global, 'navigator', { value: { getGamepads: () => pads }, configurable: true });
  const THREE = Object.assign({}, new Function(fs.readFileSync(path.join(ROOT, 'src/vendor/three.min.js'), 'utf8') + '\n;return THREE;')());
  THREE.WebGLRenderer = class { constructor() { this.domElement = fakeEl({ tagName: 'CANVAS' }); this.shadowMap = { enabled: false }; }
    setPixelRatio() {} setSize() {} render(scene, cam) { stats.renders++; scene.updateMatrixWorld(); cam.updateMatrixWorld(); } dispose() { this.disposed = true; } forceContextLoss() {} };
  global.THREE = THREE;
  require('../src/kompass3d.js');
}
const tick = (n) => { for (let i = 0; i < (n || 1); i++) { now += 16; const q = rafQ; rafQ = []; for (const f of q) f(now); } };
function world(opts) {
  opts = opts || {};
  const down = new Set(); let stopped = false;
  const B = (fn, min, max) => ({ fn, min: min || 0, max: max === undefined ? 99 : max });
  const toK = (v) => { if (v === undefined || v === null) return null; if (Array.isArray(v)) return v.map(toK); if (typeof v === 'object') { const m = new K.KMap(); for (const k of Object.keys(v)) m.m.set(k, toK(v[k])); return m; } return v; };
  const N = (v, who, d) => { if (v === undefined || v === null) { if (d !== undefined) return d; throw new K.KError(who + ': missing a number'); } if (typeof v !== 'number') throw new K.KError(who + ': expected a number, got ' + K.typeOf(v)); return v; };
  const make = (kind, tag, cls) => new K.KHandle(kind, fakeEl({ tagName: tag.toUpperCase(), className: cls }));
  const api = global.Kompass3D.builtins({ B, K, KError: K.KError, KMap: K.KMap, KHandle: K.KHandle, toK, S: (v) => K.show(v), N, make, cb: () => () => null, isFn: () => true,
    alive: () => !stopped, visible: () => true, keyDown: (k) => down.has(k) });
  const rt = stubRuntime({ extra: api, down, store: opts.store });
  return { rt, down, api, stop: () => { stopped = true; } };
}
const step = async (w, n, dt) => { for (let i = 0; i < n; i++) { tick(1); await w.rt.frame(dt || 1 / 60); } };
module.exports = { world, step, tick, stats, setPads: (p) => { pads = p; } };
