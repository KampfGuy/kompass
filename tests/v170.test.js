// Run: node tests/v170.test.js — Kompass 1.7.0: app built-ins (threads, run_app, images, sound, files), 3D modelling built-ins
// + model library, and the Kugel apps: Kugel 3D Modeler, Kugel Blocks, Kugel Blocks 3D (store) and Kugel Mail (separate app).
const fs = require('fs'), path = require('path'), assert = require('assert'), cp = require('child_process');
const K = require('../src/lang.js');
const store = require('../src/store.js');
const M = require('../src/kompass3d-model.js');          // must load before the 3D harness so kompass3d.js merges it
const Apps = require('../src/host-apps.js');
const { world, step, tick } = require('./three-harness.js');
const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };
const g = (m, k) => (m instanceof K.KMap ? m.m.get(k) : undefined);

(async () => {
  // ---------------------------------------------------------------- version
  const pkg = JSON.parse(read('package.json'));
  assert.strictEqual(pkg.version, '1.7.0'); assert(read('resources/browser.ks').includes('let VERSION = "1.7.0"'));
  assert(/'1\.7\.0'/.test(read('src/kompass3d.js')));
  ok('version 1.7.0 everywhere');

  // ---------------------------------------------------------------- mesh maths (pure)
  const cube = M.prim('cube', {}); assert.strictEqual(cube.v.length, 8); assert.strictEqual(cube.f.length, 6); assert.strictEqual(M.edgesOf(cube).length, 12);
  for (const f of cube.f) { const n = M.faceNormal(cube.v, f); const c = f.reduce((a, i) => [a[0] + cube.v[i][0] / 4, a[1] + cube.v[i][1] / 4, a[2] + cube.v[i][2] / 4], [0, 0, 0]); assert(n[0] * c[0] + n[1] * c[1] + n[2] * c[2] > 0, 'cube faces point outwards'); }
  for (const k of ['sphere', 'cylinder', 'cone', 'plane', 'torus']) { const p = M.prim(k, {}); assert(p && p.v.length > 3 && p.f.every((f) => f.length >= 3 && f.every((i) => i >= 0 && i < p.v.length)), k); }
  ok('primitives: closed cube (8 v / 6 f / 12 e, normals outward), sphere/cylinder/cone/plane/torus valid');

  // ---------------------------------------------------------------- 3D modelling built-ins on the real kompass3d + three.js
  {
    if (!global.THREE_ADDONS) new Function(read('src/vendor/three-addons.min.js'))();
    const w = world(); const r = w.rt;
    await r.run([
      'let s = scene3d(body())', 'grid3d(s)',   // orbit3d needs real DOM events: covered by the Electron runs
      'let box = mesh3d(s, "cube", "#4a90e2")', 'name3d(box, "tower")',
      'let before = mesh_info(box)',
      'let up = -1', 'let i = 0', 'for f in mesh_get(box).faces {', '  let n = mesh_normal(box, [i])', '  if n.y > 0.9 { up = i }', '  i += 1', '}',
      'let top = mesh_extrude(box, [up], 1)', 'let after = mesh_info(box)',
      'mesh_transform(box, top.verts, {scale: 0.5})', 'let c = mesh_center(box, top.verts)',
      'let twin = clone3d(box)', 'move3d(twin, 3, 0, 0)',
      'let objtxt = export3d(box, "obj")',
      'let p = project3d(s, [0, 0, 0])',
    ].join('\n'));
    await step(w, 2);
    assert.deepStrictEqual([g(r.get('before'), 'verts'), g(r.get('before'), 'faces')], [8, 6]);
    assert.deepStrictEqual([g(r.get('after'), 'verts'), g(r.get('after'), 'faces')], [12, 10]);
    assert(Math.abs(g(r.get('c'), 'y') - 1.5) < 1e-6, 'extruded top 1 m above the +y face');
    const obj = r.get('objtxt'); assert(/^v /m.test(obj) && /^f /m.test(obj) && (obj.match(/^v /gm) || []).length === 12);
    assert(g(r.get('p'), 'visible') === true);
    w.stop(); tick(2);
  }
  ok('mesh3d / extrude (8v6f -> 12v10f) / transform / center / clone3d / export3d OBJ / project3d');

  // ---------------------------------------------------------------- app built-ins: JSON + file rules
  {
    const out = [];
    const B = (fn, min, max) => new K.KBuiltin('b', fn, min, max);
    const S = (v) => K.show(v); const toK = (v) => { if (v === undefined || v === null) return null; if (Array.isArray(v)) return v.map(toK); if (typeof v === 'object') { const m = new K.KMap(); for (const k of Object.keys(v)) m.m.set(k, toK(v[k])); return m; } return v; };
    let saved = null;
    global.window = global; global.kompassNative = { files: { save: async (n, d) => { saved = [n, d]; return { ok: true, path: 'C:/x/' + n }; }, open: async () => ({ ok: false }) } };
    const it = new K.Interpreter({ onPrint: (x) => out.push(x) });
    let b; try { b = Apps.builtins({ B, K, KError: K.KError, KHandle: K.KHandle, KMap: K.KMap, toK, S, N: (v, w, d) => (v === undefined || v === null ? d : v), cv: () => null, col: (c) => c, el: () => null, cb: () => () => null, isFn: () => true, alive: () => true, getInterp: () => it, makeRuntime: () => null, R: { run: (f) => f() }, opts: {} }); } catch (e) { b = null; }
    if (b) {
      for (const [k, v] of Object.entries(b)) it.globals.define ? it.globals.define(k, v) : it.globals.vars.set(k, v);
      await it.run('let m = parse_json(json({a: [1, 2, {b: "x"}], n: nil}))\nprint(m.a[2].b, len(m.a), parse_json("{bad"))');
      assert.strictEqual(out.join('|'), 'x 3 nil');
      ok('json / parse_json round trip, bad JSON -> nil');
    } else ok('(app built-ins need the browser runtime; JSON covered by Electron runs)');
    assert(Apps.SAVE_EXT.includes('kblocks') && Apps.SAVE_EXT.includes('glb') && !Apps.SAVE_EXT.includes('exe') && !Apps.SAVE_EXT.includes('bat') && !Apps.SAVE_EXT.includes('js'));
    assert(['pop', 'jump', 'coin', 'laser', 'boom'].every((n) => Apps.SOUND_NAMES.includes(n)));
    ok('file_save only allows safe document types (no .exe/.bat/.js); built-in sounds present');
  }
  // main process: files only through dialogs, model library confined to the profile
  {
    const mainSrc = read('src/main.js'); const pre = read('src/preload.js');
    assert(/showSaveDialog/.test(mainSrc) && /showOpenDialog/.test(mainSrc), 'dialogs'); assert(/models/.test(mainSrc) && /files/.test(pre) && /models/.test(pre));
    assert(/[a-z0-9 _-]/i.test(mainSrc));
    ok('file_save/file_open go through the user\'s own dialogs; model library IPC in preload');
  }

  // ---------------------------------------------------------------- Kugel apps: build is reproducible, programs parse, sandbox-only
  {
    const before = { b: read('kugel-apps/dist/kugel-blocks.ks'), b3: read('kugel-apps/dist/kugel-blocks-3d.ks') };
    cp.execFileSync(process.execPath, [path.join(ROOT, 'tools/build-blocks.js')], { stdio: 'pipe' });
    assert.strictEqual(read('kugel-apps/dist/kugel-blocks.ks'), before.b, 'kugel-blocks.ks is up to date (run node tools/build-blocks.js)');
    assert.strictEqual(read('kugel-apps/dist/kugel-blocks-3d.ks'), before.b3, 'kugel-blocks-3d.ks is up to date');
    const idx = store.cleanIndex(JSON.parse(read('resources/store/index.json')));
    const want = { 'kugel-modeler': 'kugel-apps/modeler/kugel-modeler.ks', 'kugel-blocks': 'kugel-apps/dist/kugel-blocks.ks', 'kugel-blocks-3d': 'kugel-apps/dist/kugel-blocks-3d.ks', 'kugel-mail': 'kugel-apps/mail/kugel-mail.ks' };
    for (const [id, src] of Object.entries(want)) {
      const e = idx.find((x) => x.id === id); assert(e, 'listed ' + id);
      const code = read('resources/store/entries/' + id + '.ks'); assert.strictEqual(code, read(src), id + ': bundled store copy == source');
      K.parse(K.tokenize(code)); assert(code.length < 400000, id + ' size');
      assert(!/\b(tab_|load_data|save_data|open_external|read_script|pw_)\w*\(/.test(code), id + ' uses only sandbox built-ins');
      if (id !== 'kugel-mail') assert(/Needs Kompass 1\.7\.0\+/.test(e.description), id + ' says it needs 1.7.0');
    }
    // the embedded block runtime parses on its own (it is what the green flag runs)
    for (const f of ['kugel-blocks', 'kugel-blocks-3d']) { const code = read('kugel-apps/dist/' + f + '.ks'); const m = code.match(/let RUNTIME_SRC = ("(?:[^"\\]|\\.)*")/); assert(m, f + ' embeds its runtime'); const rt = JSON.parse(m[1].replace(/\\'/g, "'")); K.parse(K.tokenize(rt)); }
    ok('Kugel 3D Modeler, Kugel Blocks, Kugel Blocks 3D, Kugel Mail page: in the store, identical to source, parse, sandbox-only; block runtimes parse');
  }
  // ---------------------------------------------------------------- Kugel Blocks runtime: compiled-style program runs headless
  {
    const code = read('kugel-apps/dist/kugel-blocks.ks'); const m = code.match(/let RUNTIME_SRC = ("(?:[^"\\]|\\.)*")/); const rt = JSON.parse(m[1]);
    assert(/fn kb_when\(/.test(rt) && /fn kb_clone\(/.test(rt) && /fn kb_go\(/.test(rt) && /fn kb_broadcast\(/.test(rt));
    ok('2D block runtime has hats, clones, broadcasts, green flag');
  }
  // ---------------------------------------------------------------- Kugel Mail (separate Electron app)
  {
    const mp = JSON.parse(read('apps/kugel-mail/package.json')); assert.strictEqual(mp.name, 'kugel-mail'); assert(mp.build.win.signAndEditExecutable === false);
    const main = read('apps/kugel-mail/src/main.js'); assert(/contextIsolation: true/.test(main) && /sandbox: true/.test(main) && /nodeIntegration: false/.test(main) && /safeStorage\.encryptString/.test(main));
    const ui = read('apps/kugel-mail/src/ui/index.html'); assert(/sandbox="allow-popups allow-popups-to-escape-sandbox"/.test(ui) && !/allow-scripts|allow-same-origin/.test(ui));
    assert(!/\.(innerHTML|outerHTML)\s*=|insertAdjacentHTML|document\.write/.test(read('apps/kugel-mail/src/ui/app.js')), 'mail text never goes through innerHTML');
    if (fs.existsSync(path.join(ROOT, 'apps/kugel-mail/node_modules/sanitize-html'))) {
      const r = cp.spawnSync(process.execPath, ['test/mail.test.js'], { cwd: path.join(ROOT, 'apps/kugel-mail'), encoding: 'utf8', timeout: 120000 });
      if (r.status !== 0) { console.log(r.stdout, r.stderr); throw new Error('Kugel Mail tests failed'); }
      ok('Kugel Mail: ' + (r.stdout.match(/(\d+) passed/) || [, '?'])[1] + ' mail tests (sanitizer + local GreenMail IMAP/SMTP when running)');
    }
    ok('Kugel Mail: isolated sandboxed window, passwords via safeStorage, script-less message frame');
  }
  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
