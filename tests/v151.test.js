// Run: node tests/v151.test.js — Kompass 1.5.1: big programs in the Kugel Store (publish 300 KB+ without pasting, load, run).
const fs = require('fs'), path = require('path'), assert = require('assert'), http = require('http'), crypto = require('crypto');
const K = require('../src/lang.js');
const store = require('../src/store.js');
const { stubRuntime } = require('./stub-runtime.js');
const { bigProgram } = require('./big-program.js');
const ROOT = path.join(__dirname, '..');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };

(async () => {
  const big = bigProgram(); const bytes = Buffer.byteLength(big);
  assert(bytes >= 300 * 1024, 'test program is 300 KB+ (' + bytes + ')');

  // mock relay that behaves like the Cloudflare Worker
  const saved = new Map();
  const srv = http.createServer((q, r) => {
    let b = ''; q.on('data', d => b += d); q.on('end', () => {
      if (q.method === 'POST' && q.url === '/submit') {
        const j = JSON.parse(b); if (Buffer.byteLength(j.code) > store.MAX_CODE) { r.statusCode = 413; return r.end('{"ok":false,"error":"too big"}'); }
        const id = 'abcdefabcdef'; saved.set(id, j.code);
        return r.end(JSON.stringify({ ok: true, id, url: 'https://relay.test/s/' + id + '.ks', sha256: crypto.createHash('sha256').update(j.code).digest('hex') }));
      }
      const m = q.url.split('?')[0]; if (m === '/entries/bigpack.ks') return r.end(big); if (m === '/index.json') return r.end(JSON.stringify({ entries: [{ id: 'bigpack', title: 'Big Level Pack' }] }));
      r.statusCode = 404; r.end();
    });
  });
  await new Promise(r => srv.listen(0, r)); const base = 'http://127.0.0.1:' + srv.address().port;

  // ---------------------------------------------------------------- publishing
  const small = await store.publish({ title: 'Tiny', code: 'print(1)' }, { relay: base });
  assert(small.ok && small.mode === 'inline' && /print\(1\)/.test(decodeURIComponent(small.url)) && saved.size === 0);
  ok('small programs: code goes inline in the prefilled issue (no upload)');

  const r = await store.publish({ title: 'Big Level Pack', author: 'Kai', description: 'lots of levels', code: big, version: '1.5.1' }, { relay: base });
  assert(r.ok && r.mode === 'link' && !r.copied, 'big program uploaded, nothing to paste');
  assert.strictEqual(saved.get('abcdefabcdef'), big, 'relay got the exact code');
  assert(r.url.length < store.MAX_URL, 'issue URL is short: ' + r.url.length);
  const body = decodeURIComponent(new URL(r.url).searchParams.get('body'));
  assert(body.includes('https://relay.test/s/abcdefabcdef.ks') && body.includes('sha256: ' + crypto.createHash('sha256').update(big).digest('hex')) && /KB, \d+ lines/.test(body));
  ok('300 KB+ program: uploaded to the relay, issue links to it with size + sha256 — no clipboard, no pasting');

  const sf = await store.publish({ title: 'Spaceflight', code: fs.readFileSync(path.join(ROOT, 'resources/spaceflight.ks'), 'utf8') }, { relay: base });
  assert(sf.mode === 'link'); ok('Spaceflight Sim (80 KB, 1,900+ lines) publishes the same way');

  const down = await store.publish({ title: 'Big', code: big }, { relay: 'http://127.0.0.1:1', timeoutMs: 2000 });
  assert(down.ok && down.mode === 'clipboard' && down.copied && /Upload failed/.test(down.warn));
  ok('relay unreachable: falls back to the clipboard flow instead of failing');

  const huge = await store.publish({ title: 'Huge', code: 'x'.repeat(store.MAX_CODE + 1) }, { relay: base });
  assert(!huge.ok && /2 MB/.test(huge.error)); ok('limit: up to 2 MB per program, clear message above that');

  // ---------------------------------------------------------------- loading
  assert(store.MAX_BYTES >= 4 * 1024 * 1024);
  const g = await store.get('entries/bigpack.ks', { base }); assert(g.ok && g.text === big);
  assert(/name\.endsWith\('\.ks'\) \? 45000/.test(fs.readFileSync(path.join(ROOT, 'src/store.js'), 'utf8')), 'program download timeout 45 s');
  ok('loader: 4 MB download cap, 45 s timeout for programs (15 s for the index), 300 KB+ entry downloads intact');
  srv.close();

  // ---------------------------------------------------------------- running (limits + 50 ms atomic budget)
  let t = Date.now(); K.parse(big); const parseMs = Date.now() - t;
  const host = fs.readFileSync(path.join(ROOT, 'src/host.js'), 'utf8');
  assert(/storeNs: ns \?/.test(host) && /sandbox: true, rootHandle: stage, maxSteps: 5000000/.test(host), 'run_page step limit raised to 5M');
  const old = new K.Interpreter({ maxSteps: 200000, builtins: {} });
  await assert.rejects(old.run(big.split('let c = canvas')[0]), /Step limit/, 'the old 200k limit would have killed this start-up');
  const rt = stubRuntime(); t = Date.now(); await rt.run(big); const runMs = Date.now() - t;
  assert(/levels 460 walls \d+ stars \d+/.test(rt.out[0]) && rt.it.totalSteps > 200000);
  await rt.frame(); await rt.press('right'); await rt.frame(); assert(rt.calls.draw_rect > 100);
  ok(`300 KB+ program parses in ${parseMs} ms, starts up in ${runMs} ms (${rt.it.totalSteps} steps) and runs its game loop`);

  // atomic budget: a start-up far longer than 50 ms still completes (it just yields after the budget) with the sandbox's real settings
  const at = new K.Interpreter({ maxSteps: 5000000, yieldEvery: 3000, atomicMs: 50, builtins: {} });
  let yields = 0; const iv = setInterval(() => yields++, 0);
  t = Date.now(); await at.run(big.split('let c = canvas')[0]); clearInterval(iv);
  assert(Date.now() - t > 50 && yields > 0, 'long start-up yields after the 50 ms budget instead of freezing');
  assert.strictEqual(at.globals.get('LEVELS').length, 460);
  ok('the 50 ms atomic budget never breaks heavy start-up: it finishes, and lets the UI breathe after 50 ms');

  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('  FAIL ' + (e && e.stack || e)); process.exit(1); });
