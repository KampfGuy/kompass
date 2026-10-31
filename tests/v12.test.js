// Run: node tests/v12.test.js — builder templates, AI reference completeness, password vault.
const fs = require('fs'), path = require('path'), assert = require('assert'), os = require('os');
const K = require('../src/lang.js');
const { build, realBuiltins } = require('../tools/gen-ai-doc.js');
const ROOT = path.join(__dirname, '..');
const ok = (m) => console.log('  ok   ' + m);
(async () => {
  // 1. every builder template runs with the real UI built-in NAMES (stubbed DOM) + page API
  const real = realBuiltins();
  const page = [];
  for (const f of fs.readdirSync(path.join(ROOT, 'resources')).filter(f => /^builder-.*\.ks$/.test(f))) {
    const b = {}; const used = new Set();
    for (const n of real.ui) b[n] = { fn: () => { used.add(n); return n === 'gettext' ? 'cats' : new K.KHandle('box', {}); }, min: 0, max: 9 };
    b.gettext = { fn: () => 'cats', min: 1, max: 1 };
    for (const n of real.page) b[n] = { fn: ([x]) => { page.push(n + ':' + x); return n === 'engine' ? 'kugel' : null; }, min: 0, max: 1 };
    const it = new K.Interpreter({ builtins: b, maxSteps: 200000 });
    await it.run(fs.readFileSync(path.join(ROOT, 'resources', f), 'utf8'));
    assert(used.has('colorletters') && used.has('textbox'), f + ' draws a logo and a search box');
    ok('builder template ' + f + ' runs (' + used.size + ' UI built-ins)');
  }
  // the classic template's search box / buttons call search() and lucky()
  {
    const clicks = []; const b = {};
    for (const n of real.ui) b[n] = { fn: (a) => { if (n === 'button' && a[2]) clicks.push([a[2], []]); if (n === 'textbox' && a[2]) clicks.push([a[2], ['cats']]); return new K.KHandle('box', {}); }, min: 0, max: 9 };
    b.gettext = { fn: () => 'cats', min: 1, max: 1 };
    const got = []; for (const n of real.page) b[n] = { fn: ([x]) => { got.push(n + ':' + x); return 'google'; }, min: 0, max: 1 };
    const it = new K.Interpreter({ builtins: b }); await it.run(fs.readFileSync(path.join(ROOT, 'resources', 'builder-classic.ks'), 'utf8'));
    for (const [f, args] of clicks) await it.invoke(f, args);
    assert(got.includes('search:cats') && got.includes('lucky:cats'), 'search + lucky wired: ' + got);
    ok('classic template: Enter/Search/Lucky call search() and lucky()');
  }
  // 2. the AI reference documents every real built-in and is up to date
  const md = await build();
  const all = [...real.core, ...real.ui, ...real.tabs, ...real.services, ...real.editor, ...real.page];
  assert(real.editor.includes('page_new'), 'page_new found in editor.js');
  for (const n of all) assert(md.includes('`' + n + '('), 'AI doc lists ' + n);
  for (const k of K.KEYWORDS) assert(md.includes('`' + k + '`'), 'AI doc lists keyword ' + k);
  for (const f of ['docs/KAMPFSCRIPT_FOR_AI.md', 'resources/KAMPFSCRIPT_FOR_AI.md']) assert.strictEqual(fs.readFileSync(path.join(ROOT, f), 'utf8'), md, f + ' is up to date (node tools/gen-ai-doc.js)');
  ok('AI reference lists all ' + all.length + ' built-ins and ' + K.KEYWORDS.size + ' keywords, files up to date');
  // 3. password vault: create / wrong password / encrypt at rest / export+import / no plaintext on disk
  const { Vault, generate } = require('../src/vault.js');
  const f = path.join(os.tmpdir(), 'kompass-vault-' + process.pid + '.kpv');
  const v = new Vault(f);
  assert(!v.unlock('short').ok, 'short master rejected');
  assert(v.unlock('correct horse battery').ok);
  v.save(null, 'https://accounts.example.com/login?x=1', 'bob', 'S3cret-Pa55');
  assert(!fs.readFileSync(f, 'utf8').includes('S3cret'), 'vault file is encrypted');
  assert(!JSON.stringify(v.list()).includes('S3cret'), 'list() has no passwords');
  v.lock(); assert(!v.unlock('wrong password').ok); assert(v.unlock('correct horse battery').ok);
  assert.strictEqual(v.forOrigin('https://accounts.example.com')[0].password, 'S3cret-Pa55');
  assert.deepStrictEqual(v.forOrigin('https://evil.com'), []);
  const enc = v.exportEncrypted('export-pass'); assert(!enc.includes('S3cret'));
  const csv = v.exportCsv(); v.remove(v.list()[0].id); assert.strictEqual(v.list().length, 0);
  assert.strictEqual(v.importText(enc, 'export-pass'), 1);
  assert.throws(() => v.importText(enc, 'nope'));
  v.remove(v.list()[0].id); assert.strictEqual(v.importText(csv), 1);
  const g = generate(24); assert(g.length === 24 && /[A-Z]/.test(g) && /[a-z]/.test(g) && /[0-9]/.test(g));
  const al = new Vault(f, { lockMs: 50 }); al.unlock('correct horse battery'); await new Promise(r => setTimeout(r, 120)); assert(!al.unlocked(), 'auto-lock');
  fs.unlinkSync(f);
  ok('password vault: scrypt + AES-256-GCM, origin matching, export/import, auto-lock');
})().catch(e => { console.log('  FAIL', e.message); process.exit(1); });
