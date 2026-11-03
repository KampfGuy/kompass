// Run: node tests/v14.test.js — Kompass 1.4 auto-updater: semver, GitHub check, download+verify, swap helper,
// full simulated update against a local mock GitHub (API + asset server), and the KampfScript update UI.
const fs = require('fs'), path = require('path'), os = require('os'), http = require('http'), crypto = require('crypto'), assert = require('assert');
const U = require('../src/updater.js');
const K = require('../src/lang.js');
let passed = 0;
const ok = (m) => { passed++; console.log('  ok   ' + m); };
const wait = (ms) => new Promise(r => setTimeout(r, ms));
const sha = (b) => crypto.createHash('sha512').update(b).digest('base64');

function mockGitHub({ version, exe, manifest = true, badSha = false, prerelease = false, slow = 0 }) {
  const hits = [];
  const srv = http.createServer(async (req, res) => {
    hits.push(req.url);
    const base = 'http://127.0.0.1:' + srv.address().port;
    const name = 'Kompass-' + version + '-portable.exe';
    if (req.url === '/repos/KampfGuy/kompass/releases/latest') {
      const assets = [{ name, browser_download_url: base + '/dl/' + name }, { name: 'Kompass-' + version + '-win-x64.zip', browser_download_url: base + '/dl/zip' }];
      if (manifest) assets.push({ name: 'kompass-update.json', browser_download_url: base + '/redirect/manifest' });
      res.setHeader('content-type', 'application/json');
      return res.end(JSON.stringify({ tag_name: 'v' + version, html_url: base + '/release', body: 'notes', draft: false, prerelease, assets }));
    }
    if (req.url === '/redirect/manifest') { res.statusCode = 302; res.setHeader('location', '/dl/manifest'); return res.end(); }  // like GitHub -> objects.githubusercontent
    if (req.url === '/dl/manifest') return res.end(JSON.stringify({ version, files: [{ kind: 'portable', name, size: exe.length, sha512: badSha ? sha(Buffer.from('x')) : sha(exe) }] }));
    if (req.url === '/dl/' + name) {
      res.setHeader('content-length', exe.length);
      for (let i = 0; i < exe.length; i += 65536) { res.write(exe.subarray(i, i + 65536)); if (slow) await wait(slow); }
      return res.end();
    }
    res.statusCode = 404; res.end();
  });
  return new Promise(r => srv.listen(0, '127.0.0.1', () => r({ srv, hits, api: 'http://127.0.0.1:' + srv.address().port + '/repos/KampfGuy/kompass/releases/latest' })));
}
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'kompass-upd-'));

(async () => {
  // ---------------------------------------------------------------- semver
  const C = U.compareVersions;
  assert.strictEqual(C('1.4.0', '1.3.0'), 1); assert.strictEqual(C('1.3.0', '1.4.0'), -1); assert.strictEqual(C('v1.4.0', '1.4.0'), 0);
  assert.strictEqual(C('1.10.0', '1.9.9'), 1); assert.strictEqual(C('2.0.0', '1.99.99'), 1); assert.strictEqual(C('1.4.1', '1.4.0'), 1);
  assert.strictEqual(C('1.4.0-beta.1', '1.4.0'), -1); assert.strictEqual(C('1.4.0-beta.2', '1.4.0-beta.10'), -1); assert.strictEqual(C('1.4.0-alpha', '1.4.0-beta'), -1);
  assert.strictEqual(C('garbage', '1.0.0'), -1); assert.strictEqual(C('1.0.0', ''), 1);
  ok('compareVersions: numeric parts, v-prefix, prerelease ordering, invalid input');

  // ---------------------------------------------------------------- check
  const exe = crypto.randomBytes(300 * 1024 + 7);
  let g = await mockGitHub({ version: '1.4.1', exe });
  let info = await U.checkLatest({ current: '1.4.0', apiUrl: g.api });
  assert.strictEqual(info.version, '1.4.1'); assert.strictEqual(info.asset.size, exe.length); assert.strictEqual(info.asset.sha512, sha(exe));
  assert.strictEqual(await U.checkLatest({ current: '1.4.1', apiUrl: g.api }), null);
  assert.strictEqual(await U.checkLatest({ current: '1.5.0', apiUrl: g.api }), null);
  g.srv.close();
  g = await mockGitHub({ version: '1.4.1', exe, prerelease: true });
  assert.strictEqual(await U.checkLatest({ current: '1.4.0', apiUrl: g.api }), null); g.srv.close();
  g = await mockGitHub({ version: '1.4.1', exe, manifest: false });
  info = await U.checkLatest({ current: '1.4.0', apiUrl: g.api }); assert.strictEqual(info.asset, null); assert(info.url.endsWith('/release')); g.srv.close();
  ok('checkLatest: newer/equal/older, skips prereleases, follows manifest redirect, no-manifest -> download page only');

  // ---------------------------------------------------------------- download
  g = await mockGitHub({ version: '1.4.1', exe });
  info = await U.checkLatest({ current: '1.4.0', apiUrl: g.api });
  let d = tmp(), prog = [];
  const dest = path.join(d, 'new.exe');
  await U.download(Object.assign({ dest, onProgress: (a, b) => prog.push([a, b]) }, info.asset));
  assert(fs.readFileSync(dest).equals(exe)); assert(prog.length > 1 && prog[prog.length - 1][0] === exe.length && prog[0][1] === exe.length);
  const before = g.hits.length; await U.download(Object.assign({ dest }, info.asset)); assert.strictEqual(g.hits.length, before, 'verified existing file is reused');
  await assert.rejects(U.download(Object.assign({}, info.asset, { dest: path.join(d, 'b.exe'), sha512: sha(Buffer.from('nope')) })), /sha512 mismatch/);
  await assert.rejects(U.download(Object.assign({}, info.asset, { dest: path.join(d, 'c.exe'), size: 5 })), /size mismatch/);
  assert(!fs.existsSync(path.join(d, 'b.exe')) && !fs.existsSync(path.join(d, 'b.exe.part')) && !fs.existsSync(path.join(d, 'c.exe')));
  g.srv.close();
  ok('download: streams with progress, verifies size + sha512, reuses verified file, cleans up on failure');

  // ---------------------------------------------------------------- helper script (Windows text)
  const w = U.helperScript({ platform: 'win32', newFile: 'C:\\Users\\k\\AppData\\Roaming\\Kompass\\kompass\\updates\\Kompass-1.4.1-portable.exe.update', target: 'D:\\Apps\\Kompass 100%.exe', relaunch: true, log: 'C:\\x\\update.log' });
  assert(w.includes('\r\n') && w.includes('set "TARGET=D:\\Apps\\Kompass 100%%.exe"') && /copy \/Y \/B "%NEW%" "%TARGET%"/.test(w) && w.includes('start "" "%TARGET%"') && w.includes('if %N% LSS 180 goto retry'));
  assert(!U.helperScript({ platform: 'win32', newFile: 'a', target: 'b', relaunch: false, log: 'l' }).includes('start ""'));
  ok('Windows helper .cmd: CRLF, quoted paths, % escaped, retries while exe is locked, relaunch optional');

  // ---------------------------------------------------------------- Updater: silent when offline
  d = tmp();
  let states = [];
  let up = new U.Updater({ current: '1.4.0', workDir: d, settingsFile: path.join(d, 's.json'), env: { KOMPASS_UPDATE_API: 'http://127.0.0.1:9/nothing', PORTABLE_EXECUTABLE_FILE: path.join(d, 'K.exe') }, onState: s => states.push(s.status) });
  await up.check(false); assert.deepStrictEqual(states, [], 'automatic check offline: no UI noise');
  await up.check(true); assert.deepStrictEqual(states, ['checking', 'error']);
  up.setAuto(false); assert.strictEqual(JSON.parse(fs.readFileSync(path.join(d, 's.json'))).autoUpdate, false);
  up = new U.Updater({ current: '1.4.0', workDir: d, settingsFile: path.join(d, 's.json'), env: {} });
  assert.strictEqual(up.state.autoUpdate, false); up.start(1); await wait(30); assert.strictEqual(up.state.checkedAt, 0, 'auto off -> never checks'); up.stop();
  ok('Updater: offline/automatic errors are silent, manual check reports, Auto-update toggle persists and stops checks');

  // non-portable (zip build) -> "available" + download page, no self-install
  g = await mockGitHub({ version: '1.4.1', exe });
  up = new U.Updater({ current: '1.4.0', workDir: d, settingsFile: path.join(d, 's2.json'), env: { KOMPASS_UPDATE_API: g.api } });
  await up.check(false); assert.strictEqual(up.state.status, 'available'); assert.strictEqual(up.install(), false);
  g.srv.close();
  ok('zip / unpacked build: shows "available" and links the release page instead of self-installing');

  // ---------------------------------------------------------------- full simulated update (POSIX helper, real processes)
  d = tmp();
  const target = path.join(d, 'Kompass-portable');      // stands in for the running portable exe
  const marker = path.join(d, 'launched.txt');
  fs.writeFileSync(target, '#!/bin/sh\necho old >> ' + marker + '\n', { mode: 0o755 });
  const newExe = Buffer.from('#!/bin/sh\necho "new 1.4.1" >> ' + marker + '\n' + '#'.repeat(200000) + '\n');
  g = await mockGitHub({ version: '1.4.1', exe: newExe, slow: 2 });
  states = [];
  const fake = require('child_process').spawn('/bin/sh', ['-c', 'sleep 1.2']);  // the "running app" the helper waits for
  up = new U.Updater({ current: '1.4.0', workDir: path.join(d, 'updates'), settingsFile: path.join(d, 's.json'), env: { KOMPASS_UPDATE_API: g.api, PORTABLE_EXECUTABLE_FILE: target }, onState: s => states.push(s.status + (s.status === 'downloading' ? ':' + s.progress : '')) });
  up.start(5); await wait(50); while (up.busy) await wait(20);
  assert.strictEqual(up.state.status, 'ready'); assert.strictEqual(up.state.latest, '1.4.1');
  assert(states[0] === 'downloading:0' && states.some(s => /^downloading:([1-9]|[1-9][0-9])$/.test(s)) && states[states.length - 1] === 'ready', states.join(','));
  assert.strictEqual(await up.check(true).then(s => s.status), 'ready', 'no re-download once ready');
  up.stop();
  const t0 = Date.now();
  // pid = the fake app; helper must wait for it to exit before swapping
  U.applyUpdate({ newFile: up.ready.file, target, relaunch: true, workDir: up.workDir, platform: 'linux', pid: fake.pid });
  await wait(400); assert(fs.readFileSync(target, 'utf8').includes('echo old'), 'not swapped while app still running');
  while (!fs.existsSync(marker) && Date.now() - t0 < 8000) await wait(100);
  await wait(200);
  assert(fs.readFileSync(target).equals(newExe), 'exe replaced by the verified download');
  assert.strictEqual(fs.readFileSync(marker, 'utf8').trim(), 'new 1.4.1', 'new version relaunched');
  assert(Date.now() - t0 >= 1000, 'waited for the old process to exit');
  assert(!fs.existsSync(up.ready.file) && /updated/.test(fs.readFileSync(path.join(up.workDir, 'update.log'), 'utf8')));
  g.srv.close();
  ok('end-to-end: mock GitHub -> check -> download (progress) -> ready -> helper waits for exit -> swaps exe -> relaunches new version');

  // install() spawns the platform helper with the right arguments
  const spawned = [];
  up = new U.Updater({ current: '1.4.0', workDir: d, settingsFile: path.join(d, 's3.json'), platform: 'win32', env: { PORTABLE_EXECUTABLE_FILE: 'C:\\K.exe' }, spawn: (c, a, o) => { spawned.push([c, a, o]); return { unref() {} }; } });
  up.ready = { file: path.join(d, 'x.update'), version: '1.4.1' };
  assert.strictEqual(up.install(true), true);
  assert.strictEqual(spawned[0][0], 'cmd.exe'); assert(spawned[0][1][2].endsWith('kompass-update.cmd') && spawned[0][2].detached && spawned[0][2].windowsHide);
  assert(fs.readFileSync(path.join(d, 'kompass-update.cmd'), 'utf8').includes('set "TARGET=C:\\K.exe"'));
  ok('install() on Windows writes kompass-update.cmd and spawns it detached + hidden');

  // ---------------------------------------------------------------- KampfScript UI (banner + settings card)
  const src = fs.readFileSync(path.join(__dirname, '..', 'resources', 'browser.ks'), 'utf8');
  const host = fs.readFileSync(path.join(__dirname, '..', 'src', 'host.js'), 'utf8');
  const names = [...host.matchAll(/^\s{6}([a-z_]+): B\(/gm)].map(m => m[1]);
  const B = {}, texts = [], buttons = []; let onUpd = null, installs = 0, autoCalls = [], st = { status: 'idle', current: '1.4.0', latest: '', progress: 0, error: '', url: '', kind: 'portable', autoUpdate: true };
  const H = () => new K.KHandle('box', {});
  for (const n of names) B[n] = { fn: () => H(), min: 0, max: 9 };
  let nextTab = 1;
  Object.assign(B, {
    load_data: { fn: ([n, d]) => d === undefined ? null : d, min: 1, max: 2 }, tab_new: { fn: () => nextTab++, min: 0, max: 1 }, tab_url: { fn: () => 'kompass://home', min: 1, max: 1 },
    tab_can_back: { fn: () => false, min: 1, max: 1 }, tab_can_forward: { fn: () => false, min: 1, max: 1 }, adblock: { fn: () => new K.KMap({ on: true, blocked: 0 }), min: 0, max: 1 },
    read_resource: { fn: () => '', min: 1, max: 1 }, pw_status: { fn: () => new K.KMap({ exists: false, unlocked: false, count: 0 }), min: 0, max: 0 },
    app_version: { fn: () => '1.4.0', min: 0, max: 0 }, now_text: { fn: () => 'now', min: 0, max: 0 },
    label: { fn: ([p, t]) => { const h = H(); texts.push(K.show(t)); h.el.t = K.show(t); return h; }, min: 1, max: 3 },
    settext: { fn: ([h, t]) => { texts.push(K.show(t)); return null; }, min: 2, max: 2 },
    button: { fn: ([p, t, f]) => { const h = H(); buttons.push({ t: K.show(t), f }); return h; }, min: 2, max: 4 },
    update_state: { fn: () => K.KMap ? new K.KMap(st) : st, min: 0, max: 0 },
    update_install: { fn: () => { installs++; return true; }, min: 0, max: 0 },
    update_auto: { fn: ([on]) => { autoCalls.push(on); st.autoUpdate = on; return new K.KMap(st); }, min: 1, max: 1 },
    update_check: { fn: () => new K.KMap(Object.assign({}, st, { status: 'uptodate' })), min: 0, max: 0 },
    on_update: { fn: ([f]) => { onUpd = f; return null; }, min: 1, max: 1 },
  });
  const it = new K.Interpreter({ builtins: B, maxSteps: 2e6, onError: (e) => { throw e; } });
  await it.run(src);
  assert(onUpd, 'browser.ks subscribes with on_update');
  await it.invoke(onUpd, [new K.KMap(Object.assign({}, st, { status: 'ready', latest: '1.4.1', progress: 100 }))]);
  assert(texts.includes('Update ready — Kompass 1.4.1 installs when you restart'));
  const rb = buttons.filter(b => b.t === 'Restart to update').pop(); await it.invoke(rb.f, []); assert.strictEqual(installs, 1);
  // settings page: Updates card with Auto-update switch + Check for updates
  buttons.length = 0; texts.length = 0;
  await it.invoke(it.globals.get('page_settings'), [1, H()]);
  assert(texts.includes('Updates') && texts.includes('Auto-update') && texts.includes('Kompass 1.4.0'));
  await it.invoke(buttons.find(b => b.t === 'Check for updates').f, []); assert(texts.includes("You're up to date"));
  const sw = buttons.filter(b => b.t === '');  // switches have no text; the Auto-update one is the last switch on the page before About
  assert(sw.length >= 2);
  ok('KampfScript UI: on_update -> "Update ready — restart" banner calls update_install(); Settings has Updates card, Auto-update switch, Check for updates');

  console.log('\n' + passed + ' passed, 0 failed');
  process.exit(0);
})().catch(e => { console.log('  FAIL ' + (e && e.stack || e)); process.exit(1); });
