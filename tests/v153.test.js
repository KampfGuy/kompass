// Run: node tests/v153.test.js — Kompass 1.5.3: three 3D Kugel Store games (played by bots on the REAL 3D API) + the 3D Learn lessons.
const fs = require('fs'), path = require('path'), assert = require('assert');
const K = require('../src/lang.js');
const store = require('../src/store.js');
const { world, step, tick } = require('./three-harness.js');
const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };
const g = (m, k) => m.m.get(k);
const GAMES = ['sky-hopper-3d', 'asteroid-run-3d', 'kugel-bowling-3d'];
const done = (w) => { w.stop(); tick(2); };   // closing the page frees its WebGL scene

(async () => {
  // ---------------------------------------------------------------- catalog (bundled offline copy == what goes to KampfGuy/kugel-store)
  const idx = JSON.parse(read('resources/store/index.json')); const clean = store.cleanIndex(idx);
  for (const id of GAMES) {
    const e = clean.find(x => x.id === id); assert(e, 'listed: ' + id);
    assert(e.tags.includes('3d') && /Needs Kompass 1\.5\.2\+/.test(e.description), id + ' tagged 3d and says which Kompass it needs');
    const code = read('resources/store/entries/' + id + '.ks'); K.parse(K.tokenize(code));
    assert(code.length < 20000, id + ' is a small program'); assert(!/tab_|load_data|save_data|open_external|read_script|pw_/.test(code), id + ' uses only sandbox built-ins');
  }
  assert.strictEqual(new Set(clean.map(e => e.id)).size, clean.length, 'ids unique');
  ok('3 new 3D games in the store catalog (' + clean.length + ' programs), parse, sandbox-only built-ins');

  // ---------------------------------------------------------------- Sky Hopper 3D: an autopilot plays the whole course
  {
    const w = world(); const r = w.rt;
    await r.run(read('resources/store/entries/sky-hopper-3d.ks'));
    await step(w, 5); assert.strictEqual(r.get('state'), 'title');
    await r.press('enter'); await step(w, 5); assert.strictEqual(r.get('state'), 'play');
    // walking off the start island costs a life and respawns at the checkpoint
    w.down.add('a'); await step(w, 90); w.down.clear(); await step(w, 30);
    assert.strictEqual(r.get('lives'), 2, 'fell off -> lost a life'); assert(g(r.get('p'), 'y') > 0, 'respawned');
    await r.press('enter'); await r.run('start()'); await step(w, 2);
    const plats = r.get('plats'); let target = 1, frames = 0;
    while (r.get('state') === 'play' && frames < 60 * 120) {
      const p = r.get('p'), ground = r.get('ground'), cur = ground ? plats.indexOf(ground) : -1;
      if (cur >= 0) target = cur + 1;
      const T = plats[Math.min(target, plats.length - 1)];
      let tx = g(T, 'x'); if (g(T, 'kind') === 'move') tx = g(T, 'bx') + Math.sin((r.get('clock') + (cur >= 0 ? 0.75 : 0.25)) * 1.1 + g(T, 'phase')) * 2.4;
      const dx = tx - g(p, 'x'), dz = g(T, 'z') - g(p, 'z');
      w.down.clear(); if (dx < -0.08) w.down.add('a'); if (dx > 0.08) w.down.add('d'); if (dz < -0.08) w.down.add('w'); if (dz > 0.08) w.down.add('s');
      if (cur >= 0) {
        const C = plats[cur];
        if (g(C, 'kind') === 'move' && Math.abs(g(C, 'x') - g(T, 'x')) > 1.2) { w.down.clear(); if (g(C, 'x') - g(p, 'x') > 0.2) w.down.add('d'); if (g(C, 'x') - g(p, 'x') < -0.2) w.down.add('a'); }
        else if (g(T, 'kind') === 'move' && Math.abs(dx) > 0.5) {
          w.down.delete('w'); w.down.delete('s');
          if (g(p, 'x') > g(C, 'x') + g(C, 'w') / 2 - 0.4) w.down.delete('d'); if (g(p, 'x') < g(C, 'x') - g(C, 'w') / 2 + 0.4) w.down.delete('a');
          const edge = g(C, 'z') - g(C, 'd') / 2 + 0.5; if (Math.abs(g(p, 'z') - edge) > 0.2) w.down.add(g(p, 'z') > edge ? 'w' : 's');
        } else {
          const near = Math.abs(g(p, 'x') - g(C, 'x')) > g(C, 'w') / 2 - 0.3 || Math.abs(g(p, 'z') - g(C, 'z')) > g(C, 'd') / 2 - 0.3;
          const gap = Math.hypot(dx, dz) - Math.min(g(T, 'w'), g(T, 'd')) / 2;
          if (gap < 2.9 || (near && gap < 3.6)) w.down.add('space');
        }
      }
      await step(w, 1); frames++;
    }
    assert.strictEqual(r.get('state'), 'won', 'autopilot reached the goal (checkpoint ' + r.get('checkpoint') + ')');
    assert(r.get('got') >= 3 && r.store.best_time > 0, 'gems collected (' + r.get('got') + ') and best time saved (' + r.store.best_time.toFixed(1) + ' s)');
    const runT = r.get('t'), runLives = r.get('lives');
    await r.press('enter'); assert.strictEqual(r.get('state'), 'play'); assert.strictEqual(r.get('lives'), 3);
    ok(`Sky Hopper 3D: title -> play, falling costs a life + respawn, autopilot finishes all ${plats.length} islands in ${runT.toFixed(1)} s with ${runLives} lives, best time saved, restart`);
    done(w);
  }

  // ---------------------------------------------------------------- Asteroid Run 3D
  {
    const w = world(); const r = w.rt;
    await r.run(read('resources/store/entries/asteroid-run-3d.ks'));
    await step(w, 5); assert.strictEqual(r.get('state'), 'title');
    await r.press('enter'); await step(w, 2);
    w.down.add('d'); await step(w, 30); w.down.clear(); assert(r.get('x') > 2, 'ship flies right');
    await r.run('let ring = torus(s, 0.6, 0.12, "#2ecc71")\nmove3d(ring, x, y, -1)\npush(rings, ring)\nlives = 2'); await step(w, 2);
    assert.strictEqual(r.get('lives'), 3, 'shield ring = extra life');
    w.down.add('space'); let f = 0, maxScore = 0, sawLock = false;
    while (r.get('state') === 'play' && f < 30 * 240) { await step(w, 1, 1 / 30); f++; sawLock = sawLock || r.get('locked'); }
    assert.strictEqual(r.get('state'), 'over', 'standing still and holding fire eventually loses (rocks aim at you)');
    assert(sawLock, 'guns overheat when you never let go of Space');
    assert(r.get('score') > 100 && r.store.best === r.get('score'), 'score ' + r.get('score') + ' saved as high score');
    await r.press('enter'); await step(w, 2); assert.strictEqual(r.get('state'), 'play'); assert.strictEqual(r.get('rocks').length <= 1, true, 'restart clears the field');
    ok(`Asteroid Run 3D: flying, shooting, overheat, shield rings, aimed asteroids, game over after ${(f / 30).toFixed(0)} s with ${r.store.best} points, high score, restart`);
    done(w);
  }

  // ---------------------------------------------------------------- Kugel Bowling 3D: a whole game
  {
    const w = world(); const r = w.rt;
    await r.run(read('resources/store/entries/kugel-bowling-3d.ks'));
    await step(w, 3); assert.strictEqual(r.get('state'), 'title');
    await r.press('enter'); await step(w, 2); assert.strictEqual(r.get('state'), 'aim');
    let balls = 0; const downs = [];
    while (r.get('state') !== 'over' && balls < 12) {
      while (r.get('state') !== 'aim') await step(w, 1, 1 / 30);
      if (balls === 0) { w.down.add('right'); await step(w, 40, 1 / 30); w.down.clear(); }   // first ball: way off to the right
      else await r.run('bx = 0.08\nangle = 0');
      w.down.add('space'); await step(w, 18, 1 / 30); w.down.clear(); await step(w, 1, 1 / 30);
      assert.strictEqual(r.get('state'), 'roll', 'releasing Space throws'); balls++;
      while (r.get('state') === 'roll' || r.get('state') === 'settle') await step(w, 1, 1 / 30);
      downs.push(r.get('last_down'));
    }
    assert.strictEqual(r.get('state'), 'over', 'game ends after 5 frames');
    assert(downs.reduce((a, b) => a + b, 0) >= 25, 'pins fall: ' + downs.join(','));
    assert(r.get('score') > 0 && r.store.best === r.get('score'), 'score saved');
    ok(`Kugel Bowling 3D: aim, charge + release, pins chain-react, 5 frames with strike/spare bonuses (pins per ball ${downs.join(' ')}, score ${r.get('score')}), best saved`);
    done(w);
  }

  // ---------------------------------------------------------------- the 3D lessons in Learn KampfScript
  const browser = read('resources/browser.ks');
  const it = new K.Interpreter(); await it.run(browser.slice(browser.indexOf('let LESSONS = ['), browser.indexOf('let learn = load_data')));
  const lessons = it.globals.get('LESSONS').filter(l => /^3D games/.test(g(l, 'title')));
  assert.strictEqual(lessons.length, 4); assert(browser.includes('Fifteen short lessons'));
  const SOL = [
    'let s = scene3d(body(), nil, 200)\nlet ball = sphere(s)\nmove3d(ball, 2, 1, 0)\nprint(pos3d(ball).x, pos3d(ball).y)',
    'let s = scene3d(body(), nil, 200)\nlet c = cube(s)\nspin3d(c, 0, 45, 0)\nspin3d(c, 0, 45, 0)\nprint(rot3d(c).y)',
    'let s = scene3d(body(), nil, 200)\nlet a = cube(s)\nlet b = cube(s)\nmove3d(b, 0.5, 0, 0)\nprint(hits3d(a, b))',
    'fn caught(d) {\n  return d < 1.2\n}\nprint(caught(dist3d(vec3(0, 0, 0), vec3(1, 0, 0))))',
  ];
  for (let i = 0; i < 4; i++) {
    const L = lessons[i]; assert.strictEqual(g(L, 'ui'), true);
    const w = world(); await w.rt.run(g(L, 'code')); w.down.add('w'); await step(w, 60); w.down.clear(); done(w);
    const w2 = world(); await w2.rt.run(SOL[i]); assert.strictEqual(w2.rt.out.join('\n').trim(), g(L, 'expect'), g(L, 'title') + ' exercise'); done(w2);
  }
  { // lesson ③: walk to the coin; lesson ④: the mini-game can be won
    const w = world(); const r = w.rt; await r.run(g(lessons[2], 'code'));
    await r.run('camera3d(s, 2, 1.6, -1.5)'); await step(w, 3); assert.strictEqual(K.show(await r.it.repl('exists3d(coin)')), 'false', 'coin picked up');
    w.down.add('w'); await step(w, 200); w.down.clear(); const z = g(await r.it.repl('camera_get(s)'), 'z'); assert(z > -3.9, 'walls stop the player: z=' + z); done(w);
    const w2 = world(); const r2 = w2.rt; await r2.run(g(lessons[3], 'code'));
    for (let k = 0; k < 6; k++) { await r2.run('if len(gems) > 0 {\n  let p = pos3d(gems[0])\n  camera3d(s, p.x, 1.6, p.z)\n}'); await step(w2, 2); }
    assert.strictEqual(r2.get('over'), true); assert.strictEqual(r2.get('score'), 6); assert.strictEqual(r2.store.gem_best, 6); done(w2);
  }
  ok('Learn: 4 lessons "3D games ①-④" (scene/shapes/light, moving in on_frame, fps_controls + collisions + HUD, a finished mini-game): examples run, exercises solvable, Gem Grab winnable');

  assert(JSON.parse(read('package.json')).version === '1.5.3' && /let VERSION = "1.5.3"/.test(browser), 'version 1.5.3');
  ok('version 1.5.3');
  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('FAIL', e && e.stack || e); process.exit(1); });
