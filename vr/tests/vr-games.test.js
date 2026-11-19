// Run: node vr/tests/vr-games.test.js — Kompass VR 1.5.3-vr: the VR API (immersive WebXR + desktop simulator) on the REAL
// src/kompass3d.js with a fake WebXR runtime, the VR-only Kugel Store catalog, the 3 VR games played by bots, the VR lesson.
const fs = require('fs'), path = require('path'), os = require('os'), assert = require('assert');
const { execFileSync } = require('child_process');
const K = require('../../src/lang.js');
const store = require('../../src/store.js');
const X = require('./xr-harness.js');
const ROOT = path.join(__dirname, '..', '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
const g = (m, k) => m.m.get(k);
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };
const GAMES = ['kugel-tennis-vr', 'kugel-gorillas-vr', 'kugel-saber-vr'];
// deterministic randomness (the games use random_float / random): KVR_SEED=n to try another run
let seed = +(process.env.KVR_SEED || 7) * 9973; Math.random = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const done = (w) => { w.stop(); X.xrTick(2); X.tick(3); assert(!X.xr.session || X.xr.session.ended, 'closing the page ends the VR session'); };
const ratios = []; const SR = THREE.WebGLRenderer.prototype.setPixelRatio; THREE.WebGLRenderer.prototype.setPixelRatio = function (r) { ratios.push(r); };
async function enterVR(w) {
  const n = X.xr.sessions; await w.rt.run('enter_vr()'); await new Promise((q) => setTimeout(q, 5)); await X.xrStep(w, 2);
  assert.strictEqual(X.xr.sessions, n + 1, 'an immersive-vr session was requested'); return X.xr.session;
}
async function pull(w, S, hand) { S.inputSources[hand].gamepad.buttons[0] = { pressed: true, value: 1 }; await X.xrStep(w, 2); S.inputSources[hand].gamepad.buttons[0] = { pressed: false, value: 0 }; await X.xrStep(w, 1); }

(async () => {
  // ---------------------------------------------------------------- catalog: VR games only in the VR app, Windows store untouched
  {
    const vr = JSON.parse(read('vr/store/index-vr.json')); const clean = store.cleanIndex(vr);
    assert.deepStrictEqual(clean.map(e => e.id).sort(), [...GAMES].sort());
    for (const e of clean) {
      assert(e.tags.includes('vr') && e.description.length <= 240, e.id + ' tagged vr');
      const code = read('vr/store/entries/' + e.id + '.ks'); K.parse(K.tokenize(code));
      assert(code.length < 40000, e.id + ' is a small program');
      assert(!/tab_|load_data|save_data|open_external|read_script|pw_/.test(code), e.id + ' uses only sandbox built-ins');
      for (const f of ['vr_setup', 'vr_start', 'vr_available', 'panel3d', 'store_set']) assert(code.includes(f + '('), e.id + ' uses ' + f);
    }
    const win = store.cleanIndex(JSON.parse(read('resources/store/index.json')));
    assert(win.length >= 15 && !win.some(e => e.tags.includes('vr') || GAMES.includes(e.id)), 'the Windows catalog keeps its normal games and has no VR games');
    const files = { 'index-vr.json': JSON.stringify({ entries: [...vr.entries, { id: 'kugel-snake', title: 'Snake', tags: ['game'] }] }) };
    const fake = async (u) => { const n = u.replace(/^.*\/main\//, '').replace(/\?.*$/, ''); return { ok: !!files[n], status: files[n] ? 200 : 404, text: async () => files[n] || '' }; };
    const r = await store.indexVR({ fetch: fake, base: 'https://raw.githubusercontent.com/KampfGuy/kugel-store/main' });
    assert(r.ok && r.entries.length === 3 && !r.entries.some(e => e.id === 'kugel-snake'), 'indexVR shows only entries tagged "vr"');
    assert(store.fileOk('index-vr.json') && !store.fileOk('../index-vr.json'));
    const shim = read('vr/web/native-shim.js'); assert(/index: async \(\) => store\(\)\.indexVR\(/.test(shim), 'the VR app lists index-vr.json');
    ok('Kugel Store: VR app lists only the 3 VR games (index-vr.json, tag "vr"); Windows catalog unchanged (' + win.length + ' games)');
  }

  // ---------------------------------------------------------------- web bundle: 3D runtime + only the VR store games
  {
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'kvr-'));
    execFileSync('node', [path.join(ROOT, 'vr/build-web.js'), out], { stdio: 'pipe' });
    for (const f of ['kompass3d.js', 'vendor/three.min.js', 'ks/store/index-vr.json', 'ks/store/index.json', ...GAMES.map(id => 'ks/store/entries/' + id + '.ks')]) assert(fs.existsSync(path.join(out, f)), 'bundle has ' + f);
    assert(!fs.existsSync(path.join(out, 'ks/store/entries/kugel-snake.ks')), 'normal games are not in the VR bundle');
    const html = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
    assert(html.indexOf('vendor/three.min.js') > html.indexOf('render.js') && html.indexOf('kompass3d.js') < html.indexOf('host.js'), 'three + kompass3d load before host.js');
    const lessonsKs = fs.readFileSync(path.join(out, 'ks/browser.ks'), 'utf8'); assert(lessonsKs.includes('VR games: hands, swings & immersive mode'));
    fs.rmSync(out, { recursive: true, force: true });
    ok('web bundle: three.js + kompass3d.js, VR store offline copy only, VR lesson in browser.ks');
  }

  // ---------------------------------------------------------------- the VR API itself
  {
    X.xr.supported = false; await X.probe();
    let w = X.world(); let r = w.rt;
    await r.run('let s = scene3d(body())\nvr_setup(s)\nprint(vr_supported(), vr_available(), vr_start(s), vr_mode(s))');
    assert.strictEqual(r.out.pop(), 'false none flat flat', 'no WebXR: flat');
    global.KompassVRHandoff = () => true; await r.run('print(vr_available(), vr_start(s))'); assert.strictEqual(r.out.pop(), 'browser browser', 'Kompass VR app: hands off to the Quest Browser'); delete global.KompassVRHandoff;
    // desktop simulator: hand follows the "mouse", Shift swaps hands, head at eye height
    await X.step(w, 3); await r.run('let h = vr_hand(s, "right")\nprint(h.connected, h.mode, round(vr_head(s).y * 10) / 10, h.z < 0, vr_hand(s, "left").x < 0)');
    assert.strictEqual(r.out.pop(), 'true flat 1.6 true true', 'simulator: right hand in front, left hand resting at the side');
    done(w);

    global.KOMPASS_MAX_PIXEL_RATIO = 1; global.devicePixelRatio = 2; ratios.length = 0;
    X.xr.supported = true; await X.probe();
    w = X.world(); r = w.rt;
    assert.deepStrictEqual(ratios.slice(-1), [], 'no scene yet');
    await r.run(`let s = scene3d(body())
vr_setup(s)
vr_rig(s, 10, 0, 5, 90)
let sword = cube(s, 0.05, 0.05, 1, "#0ff")
vr_attach(s, sword, "right")
move3d(sword, 0, 0, -0.5)
let frames = 0
on_frame(fn(dt) { frames += 1 })
let r = vr_start(s)`);
    assert.strictEqual(ratios.pop(), 1, 'Quest pixel ratio cap'); delete global.KOMPASS_MAX_PIXEL_RATIO; global.devicePixelRatio = 1;
    assert.strictEqual(r.get('r'), 'vr'); await new Promise((q) => setTimeout(q, 5)); await X.xrStep(w, 3);
    const S = X.xr.session; assert(S && !S.ended);
    await r.run('print(vr_supported(), vr_available(), vr_mode(s))'); assert.strictEqual(r.out.pop(), 'true vr vr');
    // controller 0.4 m in front of the player (rig yaw 90 => facing -x), moving up at 2 m/s, trigger + A pressed, stick right
    const rs = S.inputSources[1].gamepad; rs.buttons[0] = { pressed: true, value: 0.9 }; rs.buttons[1] = { pressed: false, value: 0.3 }; rs.buttons[4] = { pressed: true, value: 1 }; rs.axes[2] = 0.8;
    const before = X.rendered.vr;
    await X.xrStep(w, 10, 1 / 60, (i) => { S.hands.right.p = [0.2, 1.0 + i * 0.032, -0.4]; S.hands.right.q = X.lookQ([0, 0, -1]); S.head.p = [0, 1.7, 0]; });
    assert(X.rendered.vr - before >= 10, 'the headset frame loop renders the scene');
    await r.run('let h = vr_hand(s, "right")\nlet hd = vr_head(s)\nprint(h.x, h.z, h.trigger, h.grip, h.a, h.b, h.stick_x, round(h.vy), h.dir.x, hd.y, hd.yaw)');
    const [hx, hz, trig, grip, a, b, sx, vy, dx, hy, hyaw] = r.out.pop().split(' ');
    assert(Math.abs(+hx - 9.6) < 0.01 && Math.abs(+hz - 4.8) < 0.01, 'controller pose is in world space (rig + yaw): ' + hx + ',' + hz);
    assert.deepStrictEqual([trig, grip, a, b, sx, vy], ['0.9', '0.3', 'true', 'false', '0.8', '2'], 'buttons, stick and velocity');
    assert(Math.abs(+dx + 1) < 0.01 && hy === '1.7' && hyaw === '90', 'pointing direction and head');
    await r.run('let wp = world3d(sword)\nprint(round(wp.x * 100) / 100)'); assert.strictEqual(r.out.pop(), String(Math.round((9.6 - 0.5) * 100) / 100), 'vr_attach: the sword follows the hand');
    const f0 = r.get('frames'); await r.run('print(vr_haptic(s, "right", 0.6, 30))'); assert.strictEqual(r.out.pop(), 'true'); assert.deepStrictEqual(X.xr.haptics.pop(), ['right', 0.6, 30]);
    await r.run('vr_stop(s)'); X.tick(2); await r.run('print(vr_mode(s))'); assert.strictEqual(r.out.pop(), 'flat', 'vr_stop leaves immersive mode');
    assert.strictEqual(typeof global.requestAnimationFrame, 'function'); X.tick(3);
    done(w);
    ok('VR API: vr_available none/browser/vr, simulator, immersive session (local-floor rig, world-space controllers, buttons, stick, velocity, head), vr_attach, haptics, Quest pixel ratio, vr_stop');
  }

  // ---------------------------------------------------------------- Kugel Saber VR: a bot slices the whole song
  {
    const w = X.world(); const r = w.rt; X.xr.haptics.length = 0;
    await r.run(read('vr/store/entries/kugel-saber-vr.ks')); await X.step(w, 3); assert.strictEqual(r.get('state'), 'title');
    const S = await enterVR(w); await pull(w, S, 1); assert.strictEqual(r.get('state'), 'play');
    const swings = [null, null]; let frames = 0;
    const VEC = { up: [0, 1], down: [0, -1], left: [-1, 0], right: [1, 0], any: [0, -1] };
    while (r.get('state') === 'play' && frames < 60 * 80) {
      for (const hand of [0, 1]) {
        const name = hand ? 'right' : 'left'; let sw = swings[hand];
        if (!sw) { const bs = r.get('blocks').filter(b => !g(b, 'done') && g(b, 'kind') === 'block' && g(b, 'col') === hand && g(b, 'z') > -2.6 && g(b, 'z') < -1.6); if (bs.length) sw = swings[hand] = { b: bs[0], d: VEC[g(bs[0], 'dir')], k: 0 }; }
        if (sw) { const off = -0.45 + sw.k / 12 * 0.9; S.hands[name].p = [g(sw.b, 'x') + sw.d[0] * off, g(sw.b, 'y') + sw.d[1] * off, g(sw.b, 'z') + 0.75]; S.hands[name].q = X.lookQ([0, 0, -1]); sw.k++; if (sw.k > 12 || g(sw.b, 'done')) swings[hand] = null; }
        else { S.hands[name].p = [hand ? 0.3 : -0.3, 0.6, 0.2]; S.hands[name].q = X.lookQ([0, -1, 0]); }
      }
      await X.xrStep(w, 1); frames++;
    }
    assert.strictEqual(r.get('state'), 'over'); assert(r.get('energy') > 0, 'song cleared');
    assert(r.get('cuts') >= r.get('total') * 0.9 && r.get('max_combo') >= 30, 'cuts ' + r.get('cuts') + '/' + r.get('total') + ', x' + r.get('mult'));
    assert(r.store.best === r.get('score') && r.store.best_combo === r.get('max_combo') && X.xr.haptics.length >= r.get('cuts'), 'best saved, haptics on cuts');
    const best = r.store.best, total = r.get('total');
    // wrong saber + standing still: blocks are missed and energy runs out
    await pull(w, S, 0); assert.strictEqual(r.get('state'), 'play');
    S.hands.left.p = [-0.3, 0.6, 0.2]; S.hands.right.p = [0.3, 0.6, 0.2]; frames = 0;
    while (r.get('state') === 'play' && frames < 60 * 70) { await X.xrStep(w, 1); frames++; }
    assert.strictEqual(r.get('state'), 'over'); assert.strictEqual(r.get('energy'), 0, 'idle player fails'); assert.strictEqual(r.store.best, best, 'best kept');
    done(w);
    ok(`Kugel Saber VR: bot clears the song (score ${best}, ${total} blocks, max combo ${r.store.best_combo}), haptics, best saved; idle player fails`);
  }

  // ---------------------------------------------------------------- Kugel Tennis VR: a bot plays a full match
  {
    const w = X.world(); const r = w.rt;
    await r.run(read('vr/store/entries/kugel-tennis-vr.ks')); await X.step(w, 3);
    const S = await enterVR(w); await pull(w, S, 1); assert.strictEqual(r.get('state'), 'serve');
    let frames = 0, swing = 0; const reasons = {};
    let lastSt = '';
    while (r.get('state') !== 'over' && frames < 60 * 600) {
      const b = r.get('b'), me = r.get('me'), st = r.get('state');
      const lx = g(b, 'x') - g(me, 'x'), lz = g(b, 'z') - g(me, 'z'), by = g(b, 'y');
      let hand = [0.35, 1.0, -0.3];
      if ((st === 'serve' && r.get('server') === 'you' && r.get('wait') <= 0) || (st === 'rally' && r.get('last') === 'cpu' && lz > -1.4 && lz < 0.6 && g(b, 'vz') > 0)) { swing++; hand = [lx + 0.3 - swing * 0.09, by, lz + 0.38]; if (st === 'serve' && swing > 8) swing = 0; }
      else swing = 0;
      S.hands.right.p = hand; S.hands.right.q = X.lookQ([0, 0, -1]);
      if (st === 'point' && lastSt !== 'point') reasons[r.get('msg')] = (reasons[r.get('msg')] || 0) + 1;
      lastSt = st; await X.xrStep(w, 1); frames++;
    }
    assert.strictEqual(r.get('state'), 'over'); const games = r.get('games');
    assert(games[0] === 3, 'bot wins the match ' + games.join('-')); assert(r.store.wins === 1 && r.store.best_rally >= 3, 'wins + best rally saved (' + r.store.best_rally + ')');
    // a player who never swings: the CPU serves and wins points
    await pull(w, S, 1); assert.strictEqual(r.get('state'), 'serve');
    S.hands.right.p = [0.35, 1.0, 0.4]; await r.run('server = "cpu"\nnew_point()'); frames = 0;
    while (r.get('pts')[1] < 2 && frames < 60 * 30) { await X.xrStep(w, 1); frames++; }
    assert(r.get('pts')[1] >= 2, 'CPU wins the points you do not play');
    done(w);
    ok(`Kugel Tennis VR: racket swings return the ball, auto-run, CPU rallies, tennis scoring (${Object.entries(reasons).map(([k, v]) => k + ' ×' + v).join(', ')}), match ${games.join('-')}, saved; idle player loses points`);
  }

  // ---------------------------------------------------------------- Kugel Gorillas VR: arm locomotion + tag
  {
    let w = X.world(); let r = w.rt;
    await r.run(read('vr/store/entries/kugel-gorillas-vr.ks')); await X.step(w, 3);
    let S = await enterVR(w); await pull(w, S, 1); assert.strictEqual(r.get('state'), 'play');
    const y0 = g(r.get('P'), 'y');
    for (let i = 0; i < 12; i++) { const y = 0.48 - i * 0.03; S.hands.left.p = [-0.3, y, -0.3]; S.hands.right.p = [0.3, y, -0.3]; await X.xrStep(w, 1); }
    const y1 = g(r.get('P'), 'y'); assert(y1 - y0 > 0.25, 'pushing both hands down on the grass lifts you (' + y0.toFixed(2) + ' -> ' + y1.toFixed(2) + ')');
    // release while moving up = a jump
    S.hands.left.p = [-0.3, 1.3, -0.3]; S.hands.right.p = [0.3, 1.3, -0.3]; await X.xrStep(w, 40);
    assert(Math.abs(g(r.get('P'), 'y') - -0.5) < 0.05, 'gravity brings you back down');
    // a hand glitching 3 m away is ignored
    S.hands.right.p = [0, -3, 0]; await X.xrStep(w, 3); assert(r.get('anchors')[1] === null, 'far-away hand does not grab');
    let f = 0, chk = null, unstick = 0, detour = 0; const start = { x: g(r.get('P'), 'x'), z: g(r.get('P'), 'z') }; let walked = 0, prev = { ...start };
    while (r.get('state') === 'play' && r.get('tagged') < 2 && f < 60 * 90) {
      const P = r.get('P'); const px = g(P, 'x'), py = g(P, 'y'), pz = g(P, 'z');
      const gs = r.get('gorillas').filter(x => !g(x, 'tagged')); gs.sort((a, b) => Math.hypot(g(a, 'x') - px, g(a, 'z') - pz) - Math.hypot(g(b, 'x') - px, g(b, 'z') - pz));
      const T = gs[0]; let dx = g(T, 'x') - px, dz = g(T, 'z') - pz; const d = Math.hypot(dx, dz); dx /= d; dz /= d;
      if (f % 48 === 0) { if (chk && Math.hypot(px - chk[0], pz - chk[1]) < 0.6) { unstick = 96; detour = detour > 0 ? -1.2 : 1.2; } chk = [px, pz]; }
      if (unstick > 0) { unstick--; const c = Math.cos(detour), sn = Math.sin(detour); [dx, dz] = [dx * c - dz * sn, dx * sn + dz * c]; }
      const gy = -py, k = f % 24;
      const hand = (side) => { const s = k < 12 ? -0.4 + k * 0.07 : 0.44 - (k - 12) * 0.07; return [dx * -s + side * dz * 0.3, k < 12 ? gy - 0.01 : gy + 0.35, dz * -s - side * dx * 0.3]; };
      if (d < 1.4) { S.hands.right.p = [g(T, 'x') - px, g(T, 'y') + 0.5 - py, g(T, 'z') - pz]; S.hands.left.p = [-0.3, 1.2, 0]; }
      else { S.hands.left.p = hand(-1); S.hands.right.p = hand(1); }
      await X.xrStep(w, 1); f++;
      const Q = r.get('P'); walked += Math.hypot(g(Q, 'x') - prev.x, g(Q, 'z') - prev.z); prev = { x: g(Q, 'x'), z: g(Q, 'z') };
    }
    const moved = walked;
    assert(r.get('tagged') >= 2, 'arm-locomotion bot tagged ' + r.get('tagged') + ' gorillas'); assert(moved > 3, 'moved by pushing off the ground');
    const vrTagged = r.get('tagged'), vrT = r.get('t');
    done(w);
    // screen fallback: keyboard bot tags all 4, best time saved
    w = X.world(); r = w.rt; X.xr.supported = false; await X.probe();
    await r.run(read('vr/store/entries/kugel-gorillas-vr.ks')); await X.step(w, 3); await r.press('enter'); f = 0;
    while (r.get('state') === 'play' && f < 60 * 125) {
      const P = r.get('P'), yaw = r.get('yaw'); const gs = r.get('gorillas').filter(x => !g(x, 'tagged')); w.down.clear();
      if (gs.length) {
        gs.sort((a, b) => Math.hypot(g(a, 'x') - g(P, 'x'), g(a, 'z') - g(P, 'z')) - Math.hypot(g(b, 'x') - g(P, 'x'), g(b, 'z') - g(P, 'z')));
        const T = gs[0]; const want = Math.atan2(-(g(T, 'x') - g(P, 'x')), -(g(T, 'z') - g(P, 'z'))) * 180 / Math.PI; const dy = ((want - yaw + 540) % 360) - 180;
        if (dy > 8) w.down.add('left'); else if (dy < -8) w.down.add('right'); if (Math.abs(dy) < 50) w.down.add('w'); if (f % 50 === 0) w.down.add('space');
      }
      await X.step(w, 1); f++;
    }
    assert.strictEqual(r.get('state'), 'won'); assert(r.store.best_time > 0 && r.store.best_time === r.get('t'), 'best time saved');
    done(w); X.xr.supported = true; await X.probe();
    ok(`Kugel Gorillas VR: push-down lift, jump + gravity, glitch-proof hands, arm-locomotion bot tags ${vrTagged} in ${vrT.toFixed(0)} s; screen bot tags all 4 in ${r.store.best_time.toFixed(1)} s (saved)`);
  }

  // ---------------------------------------------------------------- the VR lesson (added by vr/browser-vr-addon.ks)
  {
    const addon = read('vr/browser-vr-addon.ks'); const it = new K.Interpreter({ builtins: { push: { fn: ([l, v]) => { l.push(v); return l; }, min: 2, max: 2 }, status_text: { fn: () => null, min: 0, max: 9 } } });
    const lessonSrc = addon.slice(addon.indexOf('push(LESSONS'), addon.indexOf('status_text('));
    await it.run('let LESSONS = []\n' + lessonSrc); const L = it.globals.get('LESSONS')[0];
    const w = X.world(); const r = w.rt; X.xr.supported = false; await X.probe();
    await r.run(g(L, 'code')); await X.step(w, 20); assert.strictEqual(r.get('hits'), 0);
    const w2 = X.world(); await w2.rt.run(g(L, 'starter') + 'print(vr_mode(s), vr_hand(s, "right").hand, vr_head(s).y)');
    assert.strictEqual(w2.rt.out.pop(), g(L, 'expect'), 'the exercise has a solution');
    done(w); done(w2); X.xr.supported = true;
    ok('VR lesson ⑯ "' + g(L, 'title') + '": example runs, exercise solvable ("' + g(L, 'expect') + '")');
  }

  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.log('  FAIL ' + (e && e.stack || e)); console.log('\n' + passed + ' passed, 1 failed'); process.exit(1); });
