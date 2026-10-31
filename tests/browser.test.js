// Run: node tests/browser.test.js — parses browser.ks and boots it against stub native built-ins.
const fs = require('fs'), path = require('path'), assert = require('assert');
const K = require('../src/lang.js');
const src = fs.readFileSync(path.join(__dirname, '..', 'resources', 'browser.ks'), 'utf8');
K.parse(src);
const host = fs.readFileSync(path.join(__dirname, '..', 'src', 'host.js'), 'utf8');
const names = [...host.matchAll(/^\s{6}([a-z_]+): B\(/gm)].map(m => m[1]);
const calls = []; let nextTab = 1; let handler = null;
const builtins = {};
for (const n of names) builtins[n] = { fn: (a) => { calls.push(n); return new K.KHandle('box', {}); }, min: 0, max: 9 };
Object.assign(builtins, {
  load_data: { fn: ([n, d]) => d === undefined ? null : d, min: 1, max: 2 },
  tab_new: { fn: () => nextTab++, min: 0, max: 1 },
  tab_url: { fn: () => 'kampf://home', min: 1, max: 1 },
  tab_can_back: { fn: () => false, min: 1, max: 1 }, tab_can_forward: { fn: () => false, min: 1, max: 1 },
  adblock: { fn: () => new K.KMap({ on: true, blocked: 0 }), min: 0, max: 1 },
  on_tab_event: { fn: ([f]) => { handler = f; return null; }, min: 1, max: 1 },
  now_text: { fn: () => 'now', min: 0, max: 0 }, url_encode: { fn: ([s]) => encodeURIComponent(s), min: 1, max: 1 },
  read_script: { fn: ([n]) => n === 'demo' ? 'label(body(), "hi")' : '', min: 1, max: 1 },
  read_resource: { fn: ([n]) => { try { return fs.readFileSync(path.join(__dirname, '..', 'resources', n), 'utf8'); } catch (e) { return ''; } }, min: 1, max: 1 },
  run_page: { fn: () => new K.KMap({ ok: true, output: [], error: '', line: 0, steps: 1 }), min: 2, max: 3 },
  pw_status: { fn: () => new K.KMap({ exists: true, unlocked: true, count: 1 }), min: 0, max: 0 },
  pw_list: { fn: () => [new K.KMap({ id: 'x', origin: 'https://a.com', username: 'bob', updated: 1 })], min: 0, max: 1 },
  print: { fn: (a) => { calls.push('print:' + a.join(' ')); return null; }, min: 0, max: 9 },
});
(async () => {
  const errs = [];
  const it = new K.Interpreter({ builtins, maxSteps: 1e6, onError: (e) => { errs.push(e.message); } });
  await it.run(src);
  assert(calls.includes('view_area'), 'view_area called');
  assert(calls.includes('tab_navigate'), 'first tab navigated');
  assert(handler, 'tab event handler registered');
  await it.invoke(handler, ['internal', 1, 'kampf://home']);
  await it.invoke(handler, ['title', 1, 'Example']);
  assert(calls.some(c => c.startsWith('print:Kompass')));
  assert(calls.includes('set_theme'), 'theme applied');
  for (const page of ['kompass://settings', 'kompass://learn', 'kompass://learn/ai', 'kompass://builder', 'kompass://passwords', 'kompass://page/nothere', 'kompass://page/demo', 'kompass://about', 'kampf://home', 'kompass://nope']) {
    const before = calls.length;
    await it.invoke(handler, ['internal', 1, page]);
    assert(calls.length > before + 5, page + ' drew something');
  }
  assert(calls.includes('codebox') && calls.includes('video'), 'learn page has code boxes and video slots');
  assert.strictEqual(K.show(await it.repl('fix_url("example.com")')), 'https://example.com');
  assert.strictEqual(K.show(await it.repl('fix_url("kompass://learn")')), 'kompass://learn');
  assert.strictEqual(K.show(await it.repl('len(LESSONS)')), '10');
  console.log('  ok   settings / learn / about pages render');
  // every Learn lesson example runs cleanly, and every exercise has a working solution
  const SOLUTIONS = [
    'print("KampfScript rocks")',
    'let score = 40\nscore += 2\nprint(score)',
    'let n = 7\nif n % 2 == 1 { print("odd") } else { print("even") }',
    'for i in range(1, 6) {\n  print(i)\n}',
    'fn greet(who) {\n  return "Hello, " + who + "!"\n}\nprint(greet("Kampf"))',
    'let nums = [3, 9, 4]\nlet total = 0\npush(nums, 10)\nfor x in nums { total += x }\nprint(total)',
    null,
    'fn domain(url) {\n  return split(url, "://")[1]\n}\nprint(domain("https://kompass.app"))',
    'let colors = ["#4285f4", "#ea4335", "#fbbc05"]\nprint(colors[4 % len(colors)])',
    'let name = "todo"\nprint("kompass://page/" + name)',
  ];
  // custom home page: page_home runs the saved builder page via run_page
  await it.repl('settings.home_ks = "My Google page"');
  const before = calls.length; await it.invoke(handler, ['internal', 1, 'kompass://home']);
  assert(calls.slice(before).includes('colorletters') === false, 'custom home does not draw default page directly');
  assert.strictEqual(K.show(await it.repl('home_desc()')), '"My Google page" (KampfScript)');
  await it.repl('restore_default_home()');
  assert.strictEqual(K.show(await it.repl('settings.home_ks')), '');
  assert.strictEqual(K.show(await it.repl('len(TEMPLATES)')), '4');
  await it.repl('quick_menu(10, 10, false, "https://x.com")');
  assert(calls.includes('popup'), 'quick menu draws a popup');
  const lessons = await it.repl('LESSONS');
  const sandbox = async (code) => { const out = []; const sb = new K.Interpreter({ maxSteps: 200000, onPrint: (x) => out.push(x), builtins: { open_tab: { fn: ([u]) => { out.push('[sandbox] would open tab: ' + u); return null; }, min: 1, max: 1 } } }); await sb.run(code); return out; };
  for (let i = 0; i < lessons.length; i++) {
    const L = lessons[i].m;
    if (!L.get('ui')) await sandbox(L.get('code'));
    if (SOLUTIONS[i]) assert.strictEqual((await sandbox(SOLUTIONS[i])).join('\n').trim(), L.get('expect'), 'lesson ' + (i + 1) + ' solution');
  }
  console.log('  ok   ' + lessons.length + ' Learn lessons: examples run, exercises solvable');
  assert.deepStrictEqual(errs, []);
  console.log('  ok   browser.ks boots (' + calls.length + ' native calls)');
})().catch(e => { console.log('  FAIL', e.message); process.exit(1); });
