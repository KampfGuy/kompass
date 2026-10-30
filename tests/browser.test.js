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
  print: { fn: (a) => { calls.push('print:' + a.join(' ')); return null; }, min: 0, max: 9 },
});
(async () => {
  const it = new K.Interpreter({ builtins, maxSteps: 1e6 });
  await it.run(src);
  assert(calls.includes('view_area'), 'view_area called');
  assert(calls.includes('tab_navigate'), 'first tab navigated');
  assert(handler, 'tab event handler registered');
  await it.invoke(handler, ['internal', 1, 'kampf://home']);
  await it.invoke(handler, ['title', 1, 'Example']);
  assert(calls.some(c => c.startsWith('print:Kompass')));
  console.log('  ok   browser.ks boots (' + calls.length + ' native calls)');
})().catch(e => { console.log('  FAIL', e.message); process.exit(1); });
