// Run: node tests/v13.test.js — KampfScript 1.3 language features + the KampfScript Spaceflight Sim (headless).
const fs = require('fs'), path = require('path'), assert = require('assert');
const K = require('../src/lang.js');
const { stubRuntime } = require('./stub-runtime.js');
const ROOT = path.join(__dirname, '..');
let passed = 0;
const ok = (m) => { passed++; console.log('  ok   ' + m); };
async function out(src) { const o = []; await new K.Interpreter({ onPrint: (x) => o.push(x), maxSteps: 500000 }).run(src); return o.join('\n'); }
async function err(src) { try { await out(src); } catch (e) { return e.message; } throw new Error('expected an error for: ' + src); }
const toK = (v) => Array.isArray(v) ? v.map(toK) : (v && typeof v === 'object') ? new K.KMap(Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toK(x)]))) : v;

(async () => {
  // ---------------------------------------------------------------- language
  assert.strictEqual(await out('let name = "Kai"\nlet age = 16\nprint(`Hi {name}, next year {age + 1}!`)'), 'Hi Kai, next year 17!');
  assert.strictEqual(await out('let m = {a: [1, 2]}\nprint(`{m.a[1] * 10} {len(`x{1}`)} \\{literal} {str({k: 1})}`)'), '20 2 {literal} {k: 1}');
  assert.strictEqual(await out('print(`two\nlines`)'), 'two\nlines');
  assert.strictEqual(await out('print("plain {not} interpolated")'), 'plain {not} interpolated');
  assert(/Unterminated template/.test(await err('print(`abc')));
  assert(/empty \{\}/.test(await err('print(`a {} b`)')));
  ok('template strings: `{expr}`, nesting, \\{ escape, multi-line, plain strings unchanged, clear errors');

  assert.strictEqual(await out('for i, x in ["a", "b"] { print(i, x) }\nfor k, v in {p: 1, q: 2} { print(k, v) }\nfor i, ch in "hi" { print(i, ch) }\nfor i, n in 2 { print(i, n) }'), '0 a\n1 b\np 1\nq 2\n0 h\n1 i\n0 0\n1 1');
  assert.strictEqual(await out('for x in ["a", "b"] { print(x) }\nfor k in {p: 1} { print(k) }'), 'a\nb\np');
  ok('for i, item in list / for key, value in map (single-name for unchanged)');

  assert.strictEqual(await out('let n = 17\nn %= 5\nlet l = [10]\nl[0] %= 3\nprint(n, l[0], 1e3, 2.5e-3, 3E+2, 1.5e6 / 1e6)'), '2 1 1000 0.0025 300 1.5');
  assert.strictEqual(await out('print(round(PI, 4), round(TAU, 4), E > 2.7, INFINITY > 1e300)'), '3.1416 6.2832 true true');
  ok('%= operator, exponent numbers, PI / TAU / E / INFINITY');

  assert(/did you mean 'print'/.test(await err('pirnt("x")')));
  assert(/did you mean 'speed'/.test(await err('let speed = 3\nprint(sped)')));
  assert(/did you forget 'let zzqq/.test(await err('print(zzqq)')) && !/did you mean/.test(await err('print(zzqq)')));
  assert(/use len\(x\) instead/.test(await err('let s = "abc"\nprint(s.length)')));
  assert(/use push\(list, item\)/.test(await err('let l = []\nl.push(1)')));
  assert(/write x \+= 1/.test(await err('let x = 1\nx++')));
  assert(/use 'and'/.test(await err('print(true && false)')) && /use 'or'/.test(await err('print(true || false)')));
  ok('friendlier errors: did-you-mean names, .length/.push hints, ++ and && / || hints');

  assert.strictEqual(await out('print(round(atan2(1, 1) * 180 / PI), round(hypot(3, 4)), clamp(5, 0, 3), lerp(0, 10, 0.25), sign(-4), round(log(100, 10)), round(exp(0)))'), '45 5 3 2.5 -1 2 1');
  assert.strictEqual(await out('let v = vec(3, 4)\nprint(vlen(v), vadd(v, vec(1, 1)), vsub(v, v), vmul(v, 2), vdot(v, v), vdist(vec(0, 0), v))\nlet r = vrot(vec(1, 0), PI / 2)\nprint(round(r.x, 6), round(r.y, 6), round(vlen(vnorm(v)), 6), round(vangle(vec(0, 1)) * 2 / PI))'),
    '5 {x: 4, y: 5} {x: 0, y: 0} {x: 6, y: 8} 25 5\n0 1 1 1');
  assert.strictEqual(await out('print(fmt(1234567.891, 2), fmt(12), sum([1, 2, 3.5]), shade("#808080", 0.5), shade("#808080", -0.5), mix("#000", "#fff", 0.5), rgb(255, 69, 0), rgb(0, 0, 0, 0.5))'),
    '1,234,567.89 12 6.5 #c0c0c0 #404040 #808080 rgb(255,69,0) rgba(0,0,0,0.5)');
  const f = await out('let r = random_float(2, 3)\nprint(r >= 2 and r < 3)'); assert.strictEqual(f, 'true');
  assert(/needs a vector/.test(await err('vlen(5)')) && /needs a color/.test(await err('shade("red", 1)')));
  ok('maths (atan2, hypot, clamp, lerp, log, exp, sign), vectors (vec, vadd, vrot, vnorm…), fmt, sum, colours (shade, mix, rgb)');

  // backward compatibility: every shipped .ks still parses and old programs behave the same
  for (const f of fs.readdirSync(path.join(ROOT, 'resources')).filter(f => f.endsWith('.ks'))) K.parse(fs.readFileSync(path.join(ROOT, 'resources', f), 'utf8'));
  assert.strictEqual(await out('let a = 5 - -3\nlet b = 10 - 2\nprint(a, b, "x" + 1 + 2, -7 % 3)'), '8 8 x12 2');
  ok('backward compatible: all resources/*.ks parse, old arithmetic/strings unchanged');

  // ---------------------------------------------------------------- the lesson
  const browser = fs.readFileSync(path.join(ROOT, 'resources', 'browser.ks'), 'utf8');
  assert(browser.includes('New in 1.3: games & apps') && browser.includes('kompass://spaceflight'));
  {
    const it = new K.Interpreter(); await it.run(browser.slice(browser.indexOf('let LESSONS = ['), browser.indexOf('let learn = load_data')));
    const lessons = it.globals.get('LESSONS'); const l = lessons[lessons.length - 1];
    const r = stubRuntime(); await r.run(l.m.get('code')); for (let i = 0; i < 30; i++) await r.frame();
    assert(r.calls.draw_circle >= 30 && r.calls.on_frame === 1, 'lesson example animates');
    assert.strictEqual(await out(l.m.get('starter') + 'print(`next year: {age + 1}`)'), l.m.get('expect'));
  }
  ok('Learn lesson ⑪ "New in 1.3": example animates a canvas, the exercise is solvable');

  // ---------------------------------------------------------------- the Spaceflight Sim, played headless
  const src = fs.readFileSync(path.join(ROOT, 'resources', 'spaceflight.ks'), 'utf8');
  assert(src.includes('Original by Rough_Capital1339/CatPrinceHQ2 · Mod by KampfGuy'));
  const r = stubRuntime();
  await r.run(src);
  assert.strictEqual(r.get('mode'), 'menu'); assert.strictEqual(r.calls.on_frame, 1);
  await r.click('New World'); await r.click('Create & Play');
  assert.strictEqual(r.get('mode'), 'build');
  ok('sim boots to the menu, New World → build screen');

  // build a rocket with the mouse on the grid: origin = (1280/2 - 24*20/2, 60) = (400, 60)
  const grid = r.mice[0][1];
  const clickCell = async (c, row, button) => { const x = 400 + c * 20 + 5, y = 60 + row * 20 + 5; for (const type of ['down', 'up']) await r.it.invoke(grid, [toK({ type, x, y, button: button || 'left', shift: false })]); };
  const pick = async (id) => r.it.invoke(r.get('select_part'), [id]);
  await pick('pod'); await clickCell(11, 0);
  await pick('chute'); await clickCell(11, 2);
  await pick('sepS'); await clickCell(11, 3);
  await pick('tankS'); await clickCell(11, 4);
  await pick('engB'); await clickCell(11, 8);
  await pick('engB'); await clickCell(3, 30);              // floating part: refused
  assert.strictEqual(r.get('placed').length, 5, 'placed 5 touching parts, refused a floating one');
  await pick('tankS'); await clickCell(11, 4);             // overlapping: refused
  assert.strictEqual(r.get('placed').length, 5);
  await clickCell(3, 30, 'right'); await clickCell(11, 8, 'right'); assert.strictEqual(r.get('placed').length, 4, 'right-click removes');
  await pick('engB'); await clickCell(11, 8);
  const st = await r.it.invoke(r.get('stats_of'), [r.get('placed')]);
  assert.strictEqual(st.m.get('dry'), 320 + 55 + 45 + 400 + 450); assert.strictEqual(st.m.get('fuel'), 1600); assert(st.m.get('twr') > 2 && st.m.get('dv') > 1000);
  await r.click('Save Rocket'); assert.strictEqual(r.store.sfs_rockets.length, 1);
  ok('builder: click to place (touch + overlap rules), right-click remove, stats (mass, TWR, Δv), save rocket');

  await r.click('Launch ▲');
  assert.strictEqual(r.get('mode'), 'flight');
  const ship = () => r.get('ships')[r.get('active')];
  const alt = (s) => Math.hypot(s.m.get('rx'), s.m.get('ry')) - r.get('BY').m.get(s.m.get('dom')).m.get('radius');
  assert.strictEqual(ship().m.get('status'), 'landed');
  for (let i = 0; i < 20; i++) await r.frame();
  assert.strictEqual(ship().m.get('status'), 'landed', 'stays on the pad with engines off');
  await r.press('space');                                   // space on the pad = engine on
  for (let i = 0; i < 120; i++) await r.frame();
  assert.strictEqual(ship().m.get('status'), 'flying'); assert(alt(ship()) > 200, 'climbing: ' + alt(ship()));
  assert(ship().m.get('fuel') < 1600, 'engines burn fuel');
  ok('flight: launch pad, Space → engine, rocket climbs and burns fuel (' + Math.round(alt(ship())) + ' u after 2 s)');

  r.down.add('left'); for (let i = 0; i < 30; i++) await r.frame(); r.down.delete('left');
  assert(ship().m.get('angle') < 0, 'A/left turns the rocket');
  await r.press('space');                                   // stage
  assert.strictEqual(ship().m.get('parts').length, 2, 'staged: pod + chute stay');
  assert(r.get('ships').some(s => s.m.get('debris')), 'jettisoned stage flies on as debris');
  await r.click('CHUTE: STOWED'); assert.strictEqual(ship().m.get('chute'), true);
  for (let i = 0; i < 1500 && ship().m.get('status') === 'flying'; i++) await r.frame(1 / 20);
  assert.strictEqual(ship().m.get('status'), 'landed', 'parachute landing: ' + K.show(ship().m.get('msg')));
  ok('steering, staging (separator splits the rocket, debris), parachute → ' + K.show(ship().m.get('msg')));

  // orbit: teleport cheat, time warp, patched-conic SOI
  await r.it.invoke(r.get('teleport'), ['moon']);
  assert.strictEqual(ship().m.get('dom'), 'moon');
  const r0 = Math.hypot(ship().m.get('rx'), ship().m.get('ry'));
  await r.frame(); await r.click('100×'); assert.strictEqual(r.get('warp'), 100, 'cap ' + K.show(await r.it.invoke(r.get('max_warp'), [])) + ' ' + K.show(ship().m.get('inAtmo')) + ship().m.get('status'));
  await r.click('1k×'); assert.strictEqual(r.get('warp'), 100, 'warp capped at 100× inside a moon SOI');
  for (let i = 0; i < 300; i++) await r.frame();
  const r1 = Math.hypot(ship().m.get('rx'), ship().m.get('ry'));
  assert(Math.abs(r1 - r0) / r0 < 0.03 && ship().m.get('status') === 'flying', 'circular orbit is stable: ' + r0 + ' → ' + r1);
  ok('orbits: teleport to the Moon, 100× warp cap in moon SOI, orbit radius stable over ' + Math.round(r.get('sim_time')) + ' sim-seconds');

  // crash into the ground
  await r.it.invoke(r.get('teleport'), ['mars']);
  const s = ship(); s.m.set('vx', 0); s.m.set('vy', -2000); await r.click('1×');
  for (let i = 0; i < 2000 && ship().m.get('status') === 'flying'; i++) await r.frame(1 / 10);
  assert.strictEqual(ship().m.get('status'), 'crashed'); assert(/destroyed on impact with Mars/.test(K.show(ship().m.get('msg'))));
  ok('impact faster than 300 m/s destroys the ship: ' + K.show(ship().m.get('msg')));

  // views, dark mode, save + resume
  await r.press('2'); assert.strictEqual(r.get('cam').m.get('mpp'), 3000000); await r.press('3'); assert.strictEqual(r.get('cam').m.get('mpp'), 200000000);
  await r.press('f'); assert.strictEqual(r.get('cam').m.get('free'), true); await r.frame();
  await r.click('🌙 Dark Mode'); assert.strictEqual(r.store.sfs_prefs.m.get('dark'), true);
  await r.click('☰ Menu'); const w = r.store.sfs_worlds[0]; assert(r.store.sfs_worlds.length === 1 && w.m.get('placed').length === 5 && w.m.get('simTime') > 100, 'world saved (crashed ships are dropped)');
  const r2 = stubRuntime({ store: r.store }); await r2.run(src);
  await r2.click('Resume World'); await r2.click('Play');
  assert(['flight', 'build'].includes(r2.get('mode'))); assert.strictEqual(r2.get('placed').length, 5); assert(r2.get('sim_time') > 100); for (let i = 0; i < 10; i++) await r2.frame();
  ok('zoom views 1/2/3 + free cam, dark mode saved, worlds saved with store_set and resumed in a fresh run');

  const used = Object.keys(r.calls).filter(n => n.startsWith('draw_') || ['canvas', 'on_frame', 'on_mouse', 'on_keypress', 'key_down', 'slider', 'checkbox', 'dropdown', 'store_get', 'store_set'].includes(n));
  ok('sim uses ' + used.length + ' of the new built-ins; ' + src.split('\n').length + ' lines of KampfScript');
  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('  FAIL ' + (e && e.stack || e)); process.exit(1); });
