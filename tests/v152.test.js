// Run: node tests/v152.test.js — Kompass 1.5.2: fullscreen (F11 + HTML5 fullscreen from pages) and the KampfScript 3D API.
// The 3D tests run the REAL src/kompass3d.js + the bundled three.js in Node; only the WebGL renderer is faked.
const fs = require('fs'), path = require('path'), assert = require('assert');
const K = require('../src/lang.js');
const { stubRuntime } = require('./stub-runtime.js');
const { realBuiltins } = require('../tools/gen-ai-doc.js');
const DOCS = require('../tools/builtin-docs.js');
const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };

// ---------------------------------------------------------------- a tiny browser-ish world for kompass3d.js
let rafQ = []; let now = 0; let renders = 0; let pads = [];
const fakeEl = (extra) => Object.assign({ style: {}, children: [], classList: { add() {}, remove() {}, toggle() {} }, appendChild(c) { this.children.push(c); }, addEventListener() {},
  getBoundingClientRect: () => ({ width: 800, height: 450, left: 0, top: 0 }), isConnected: true, textContent: '' }, extra || {});
const ctx2d = new Proxy({}, { get: (t, k) => (k in t ? t[k] : () => ({ addColorStop() {} })), set: (t, k, v) => { t[k] = v; return true; } });
global.window = global; global.devicePixelRatio = 1; global.addEventListener = () => {};
global.document = { createElement: (tag) => fakeEl({ tagName: String(tag).toUpperCase(), width: 0, height: 0, getContext: () => ctx2d }), pointerLockElement: null, exitPointerLock() {} };
global.requestAnimationFrame = (f) => { rafQ.push(f); return rafQ.length; };
Object.defineProperty(global, 'navigator', { value: { getGamepads: () => pads }, configurable: true });
const THREE = Object.assign({}, new Function(read('src/vendor/three.min.js') + '\n;return THREE;')());   // module namespace is read-only: copy it
THREE.WebGLRenderer = class { constructor() { this.domElement = fakeEl({ tagName: 'CANVAS' }); this.shadowMap = { enabled: false }; this.disposed = false; }
  setPixelRatio() {} setSize(w, h) { this.size = [w, h]; } render(scene, cam) { renders++; scene.updateMatrixWorld(); cam.updateMatrixWorld(); } dispose() { this.disposed = true; } forceContextLoss() {} };
global.THREE = THREE;
require('../src/kompass3d.js');
const tick = (n) => { for (let i = 0; i < (n || 1); i++) { now += 16; const q = rafQ; rafQ = []; for (const f of q) f(now); } };

function world(opts) {
  opts = opts || {};
  const down = new Set(); let stopped = false;
  const B = (fn, min, max) => ({ fn, min: min || 0, max: max === undefined ? 99 : max });
  const toK = (v) => { if (v === undefined || v === null) return null; if (Array.isArray(v)) return v.map(toK); if (typeof v === 'object') { const m = new K.KMap(); for (const k of Object.keys(v)) m.m.set(k, toK(v[k])); return m; } return v; };
  const N = (v, who, d) => { if (v === undefined || v === null) { if (d !== undefined) return d; throw new K.KError(who + ': missing a number'); } if (typeof v !== 'number') throw new K.KError(who + ': expected a number, got ' + K.typeOf(v)); return v; };
  const make = (kind, tag, cls) => new K.KHandle(kind, fakeEl({ tagName: tag.toUpperCase(), className: cls }));
  const api = window.Kompass3D.builtins({ B, K, KError: K.KError, KMap: K.KMap, KHandle: K.KHandle, toK, S: (v) => K.show(v), N, make, cb: () => () => null, isFn: () => true,
    alive: () => !stopped, visible: () => true, keyDown: (k) => down.has(k) });
  const rt = stubRuntime({ extra: api, down, store: opts.store });
  return { rt, down, api, stop: () => { stopped = true; } };
}
const step = async (w, n, dt) => { for (let i = 0; i < n; i++) { tick(1); await w.rt.frame(dt || 1 / 60); } };

(async () => {
  // ---------------------------------------------------------------- fullscreen wiring
  const host = read('src/host.js'), main = read('src/main.js'), pre = read('src/preload.js'), ks = read('resources/browser.ks'), css = read('src/style.css');
  assert(/addEventListener\('enter-html-full-screen'/.test(host) && /addEventListener\('leave-html-full-screen'/.test(host), 'host listens for page fullscreen on every <webview>');
  assert(/classList\.toggle\('ks-fullscreen'/.test(host) && /body\.ks-fullscreen \.ks-viewarea \{ position:fixed !important; inset:0 !important;/.test(css), 'chrome hidden: the view area covers the whole window');
  assert(/window\.native\.setFullscreen\(on\)/.test(host) && /setFullscreen: \(on\) => ipcRenderer\.send\('kompass:set-fullscreen'/.test(pre) && /ipcMain\.on\('kompass:set-fullscreen'[^\n]*e\.sender === win\.webContents[^\n]*win\.setFullScreen/.test(main), 'window really goes fullscreen (IPC only from the Kompass UI itself)');
  assert(/k === 'escape' && htmlFs\) \{ ev\.preventDefault\(\); contents\.executeJavaScript\('document\.fullscreenElement && document\.exitFullscreen\(\)'/.test(main), 'Esc inside a fullscreen page leaves it (like Chrome)');
  assert(/k === 'f11'\) \{ ev\.preventDefault\(\); if \(win\) win\.webContents\.send\('kompass:key', k\)/.test(main) && /win\.on\('leave-full-screen'/.test(main) && /onFullscreen: \(f\) =>/.test(pre), 'F11 from inside pages reaches the chrome; OS leaving fullscreen restores the layout');
  assert(/\(k === 'escape' \|\| k === 'f11'\) && main\.fsKey\(k\)/.test(host) && /k === 'f11' && !keyHandlers\.has\('f11'\)/.test(host), 'Esc / F11 handled by the host even with an older customised browser.ks');
  assert(/on_key\("f11", fn\(\) \{ toggle_fullscreen\(\) \}\)/.test(ks) && /\["⛶", "Fullscreen", fn\(\) \{ toggle_fullscreen\(\) \}\]/.test(ks) && /fn toggle_fullscreen\(\) \{ fullscreen\(not fullscreen\(\)\) \}/.test(ks), 'browser.ks: F11 and a quick-menu "Fullscreen" button');
  assert(/permission === 'fullscreen'|'fullscreen'/.test(main), 'the fullscreen permission is granted to pages');
  ok('fullscreen: page fullscreen (YouTube / Google Slides / Maps) hides the chrome + fullscreens the window, Esc / F11 / quick menu work');

  // ---------------------------------------------------------------- 3D: bundling + docs
  const html = read('src/index.html');
  assert(html.indexOf('vendor/three.min.js') > 0 && html.indexOf('vendor/three.min.js') < html.indexOf('kompass3d.js') && html.indexOf('kompass3d.js') < html.indexOf('host.js'), 'three.js + kompass3d.js load before host.js');
  assert(/script-src 'self';/.test(html) && !/cdn|unpkg|jsdelivr/i.test(html), 'no CDN: CSP still only allows local scripts');
  assert(fs.existsSync(path.join(ROOT, 'src/vendor/three-LICENSE.txt')) && /^\/\*! three\.js 0\.\d+\.\d+ \(r\d+\) — MIT License/.test(read('src/vendor/three.min.js')), 'three.js is vendored with its MIT license');
  const k3 = read('src/kompass3d.js'); assert(!/fetch\(|XMLHttpRequest|import\(|new Image|\.load\(|TextureLoader|https?:\/\//.test(k3.replace(/^\s*(\/\/|\*|\/\*).*$/gm, '')), 'kompass3d.js never touches the network (procedural / canvas textures only)');
  assert(/if \(window\.Kompass3D\) Object\.assign\(ui, window\.Kompass3D\.builtins\(/.test(host) && host.indexOf('window.Kompass3D.builtins') < host.indexOf('const sandboxUi'), '3D built-ins are part of ui, so pages + Store sandboxes get them');
  const real = realBuiltins(); assert(real.three.length >= 40, '3D built-ins found: ' + real.three.length);
  for (const n of real.three) assert(DOCS.three[n], 'documented: ' + n);
  for (const n of ['fullscreen', 'on_fullscreen']) assert(real.tabs.includes(n) && DOCS.tabs[n], 'documented: ' + n);
  const doc = read('docs/KAMPFSCRIPT_FOR_AI.md'); assert(/### 7\.8 3D games/.test(doc) && doc.includes('`fps_controls(scene,') && doc.includes('`fullscreen(on?) -> bool`') && doc === read('resources/KAMPFSCRIPT_FOR_AI.md'), 'AI doc has the 3D section + fullscreen');
  ok('3D: three.js bundled locally (' + Math.round(fs.statSync(path.join(ROOT, 'src/vendor/three.min.js')).size / 1024) + ' KB), ' + real.three.length + ' built-ins wired into the shared runtime and documented');

  // ---------------------------------------------------------------- 3D: the API itself (real three.js scene graph)
  {
    const w = world(); const r = w.rt;
    await r.run(`let s = scene3d(body())
let a = cube(s, 1, 1, 1, "#ff0000")
let b = sphere(s, 0.5, "gold")
move3d(b, 3, 0, 0)
let wall = cube(s, 4, 2, 0.5)
move3d(wall, 0, 1, -5)
tag3d(wall, "wall")
let hit = ray3d(s, vec3(0, 1, 0), vec3(0, 0, -1))
print(hit.tag, round(hit.dist, 2), hits3d(a, b))
move3d(b, 0.6, 0, 0)
print(hits3d(a, b), hits3d(a, "nothing"), type(hits3d(b, [a])))
spin3d(a, 0, 90, 0)
print(round(rot3d(a).y), pos3d(b).x, round(dist3d(a, b), 2), dist3d(vec3(0, 0, 0), [3, 4, 0]))
let g = group3d(s)
attach3d(g, a)
move3d(g, 10, 0, 0)
print(round(dist3d(a, vec3(10, 0, 0)), 3), len(find3d(s, "wall")), count3d(s))
look3d(a, {texture: "checker", glow: "#110000", opacity: 0.5, repeat: 2})
camera3d(s, 0, 2, 6, 0, 0, 0)
camera_fov(s, 80)
let c = camera_get(s)
print(c.fov, round(c.pitch), c.dir.z < 0)
camera_angles(s, 90, 0)
print(round(camera_get(s).dir.x, 3))
remove3d(b)
print(count3d(s), gamepad().connected)`);
    tick(2);
    assert.deepStrictEqual(r.out, ['wall 4.75 false', 'true nil object3d', '90 0.6 0.6 5', '0 1 4', '80 -18 true', '-1', '3 false'], JSON.stringify(r.out));
    assert(renders > 0, 'the scene renders in its own frame loop');
    // errors are friendly KampfScript errors
    for (const [code, msg] of [['cube(1)', 'needs a 3D scene from scene3d(parent)'], ['let s = scene3d(body())\nmove3d(s, 1, 2, 3)', 'needs a 3D object'], ['let s = scene3d(body())\nlook3d(cube(s), {sparkle: 1})', 'unknown setting "sparkle"'],
      ['let s = scene3d(body())\ncube(s, 1, 1, 1, "not a colour!")', 'color must be like'], ['let s = scene3d(body())\nfps_controls(s, {sped: 3})', 'unknown setting "sped"'], ['let s = scene3d(body())\nlook3d(cube(s), {texture: "https://x/y.png"})', 'texture must be']]) {
      let err = ''; try { await world().rt.run(code); } catch (e) { err = e.message; } assert(err.includes(msg), code + ' -> ' + err);
    }
    // gamepad (standard mapping)
    pads = [null, { connected: true, id: 'Xbox Wireless Controller', axes: [0.05, -0.9, 0.5, 0], buttons: Array.from({ length: 17 }, (_, i) => ({ pressed: i === 0 || i === 9, value: i === 7 ? 0.75 : (i === 0 || i === 9 ? 1 : 0) })) }];
    const w2 = world(); await w2.rt.run('let p = gamepad()\nprint(p.connected, p.lx, p.ly, p.rx, p.a, p.b, p.start, p.rt, len(p.buttons))'); pads = [];
    assert.deepStrictEqual(w2.rt.out, ['true 0 -0.9 0.5 true false true 0.75 17']);
    ok('3D API on a real three.js scene graph: shapes, groups, transforms in degrees, ray3d / hits3d / dist3d, camera, materials, gamepad, friendly errors');
  }
  {
    // first-person controls + solid walls; scene is disposed when the page stops
    const w = world(); const r = w.rt;
    await r.run('let s = scene3d(body())\nlet wall = cube(s, 6, 3, 1)\nmove3d(wall, 0, 1.5, -3)\nsolid3d(wall)\ncamera3d(s, 0, 1.6, 0)\ncamera_angles(s, 0, 0)\nfps_controls(s, {speed: 4})\nlet st = s');
    w.down.add('w'); await step(w, 120); w.down.clear();
    let c = await r.run('let c = camera_get(s)\nprint(round(c.z, 2))'); const z = +r.out.pop();
    assert(z < -1 && z > -2.6, 'walked forward but stopped at the wall: z=' + z);
    w.down.add('d'); await step(w, 30); w.down.clear(); await r.run('print(round(camera_get(s).x, 1))'); assert(+r.out.pop() > 1.5, 'strafes right (A/D) and slides along the wall');
    w.down.add('left'); await step(w, 30); w.down.clear(); await r.run('print(round(camera_get(s).yaw))'); assert(+r.out.pop() > 45, 'arrows turn');
    const st = r.get('st').st; w.stop(); tick(2); assert(st.gone && st.renderer.disposed, 'renderer disposed when the page closes');
    ok('fps_controls: W A S D / arrows walk + turn, solid3d walls block and you slide along them; WebGL is released when the page closes');
  }

  // ---------------------------------------------------------------- the two example games, played
  {
    const store = {}; const w = world({ store }); const r = w.rt;
    await r.run(read('resources/maze3d.ks'));
    await step(w, 5);
    const coins0 = r.get('coins').length; assert.strictEqual(coins0, 9);
    w.down.add('w'); await step(w, 90); w.down.clear();
    await r.run('let me = camera_get(s)\nprint(me.x > 5 and me.x < 6.7, me.z > 1.3 and me.z < 2.7, me.x)'); assert(r.out.pop().startsWith('true true'), 'walked down the corridor and stopped at its end wall');
    // teleport onto each coin: they get collected, then the game is won and the best time saved
    for (let i = 0; i < 9; i++) { await r.run('if len(coins) > 0 {\n  let p = pos3d(coins[0])\n  camera3d(s, p.x, 1.6, p.z)\n}'); await step(w, 2); }
    assert.strictEqual(r.get('got'), 9); assert.strictEqual(r.get('done'), true); assert(r.store.maze3d_best > 0, 'best time saved');
    await r.click('Play again'); await step(w, 2); assert.strictEqual(r.get('coins').length, 9); assert.strictEqual(r.get('done'), false);
    assert(w.rt.calls.canvas && w.rt.calls.draw_rect > 50, 'minimap drawn on a canvas on top of the 3D scene');
    ok('Coin Maze 3D (resources/maze3d.ks): walls, walking, coins, win screen, best time, Play again');
  }
  {
    const store = {}; const w = world({ store }); const r = w.rt;
    await r.run(read('resources/runner3d.ks'));
    await step(w, 20, 1 / 30); await r.run('print(started, z)'); assert.strictEqual(r.out.pop(), 'false 0', 'waits on the start screen');
    await r.press('space'); await step(w, 30, 1 / 30); await r.run('print(started, z < -5)'); assert.strictEqual(r.out.pop(), 'true true', 'Space starts');
    await r.press('left'); await step(w, 10, 1 / 30); await r.run('print(lane, round(pos3d(ball).x, 1))'); assert.strictEqual(r.out.pop(), '0 -2.2');
    await r.press('space'); await step(w, 4, 1 / 30); await r.run('print(pos3d(ball).y > 1)'); assert.strictEqual(r.out.pop(), 'true', 'jumps');
    let crashed = false; for (let i = 0; i < 1500 && !crashed; i++) { await step(w, 1, 1 / 30); crashed = r.get('over'); }
    assert(crashed, 'runs until it hits something'); await r.run('print(round(-z) >= 25, len(tiles))'); assert.strictEqual(r.out.pop(), 'true 9');
    assert(r.store.runner3d_best > 0, 'best score saved'); await r.press('enter'); assert.strictEqual(r.get('over'), false);
    await r.run('print(count3d(s) < 400)'); assert.strictEqual(r.out.pop(), 'true', 'objects behind the player are removed');
    ok('Kugel Runner 3D (resources/runner3d.ks): lanes, jumping, endless track, obstacles + coins, crash, best score, restart');
  }

  // ---------------------------------------------------------------- browser.ks routes
  assert(/where == "maze3d" \{ page_example\(id, page, "maze3d"/.test(ks) && /where == "runner3d"/.test(ks) && /where == "games3d" or where == "3d" \{ page_games3d/.test(ks), 'routes');
  assert(/"🧊 New: 3D games in KampfScript"/.test(ks), 'Learn links to them');
  const ver = JSON.parse(read('package.json')).version; assert(/^1\.5\.([2-9]|\d\d)$|^1\.([6-9]|\d\d)\.|^[2-9]\./.test(ver) && ks.includes('let VERSION = "' + ver + '"'), 'version is 1.5.2 or later');
  ok('kompass://games3d, kompass://maze3d and kompass://runner3d run the games sandboxed with run_page (same as Store games); Learn + quick menu link them');

  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('FAIL', e && e.stack || e); process.exit(1); });
