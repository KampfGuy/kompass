// Run: node vr/tests/vr.test.js — Kompass VR (Quest APK) checks that need no device:
// the web bundle builds, the VR browser.ks (browser.ks + vr/browser-vr-addon.ks) boots against stub built-ins,
// the shim implements the whole Electron preload contract, and the Android manifest is a Quest 2D-panel app.
'use strict';
const fs = require('fs'), path = require('path'), os = require('os'), assert = require('assert'), cp = require('child_process');
const ROOT = path.join(__dirname, '..', '..');
const K = require(path.join(ROOT, 'src/lang.js'));
let pass = 0, fail = 0;
const test = async (name, f) => { try { await f(); pass++; console.log('  ok   ' + name); } catch (e) { fail++; console.log('  FAIL ' + name + '\n       ' + e.message); } };

(async () => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'kvr-'));
  await test('web bundle builds (shared runtime unchanged + VR layer + resources)', () => {
    cp.execFileSync('node', [path.join(ROOT, 'vr/build-web.js'), out], { stdio: 'pipe' });
    for (const f of ['index.html', 'native-shim.js', 'vr.css', 'vr-xr.js', 'ks-store.js', 'lang.js', 'host.js', 'render.js', 'editor.js', 'devtools.js', 'style.css', 'ks/browser.ks', 'ks/manifest.json', 'ks/store/index.json'])
      assert(fs.existsSync(path.join(out, f)), 'missing ' + f);
    for (const f of ['lang.js', 'host.js', 'render.js', 'editor.js', 'devtools.js', 'style.css'])
      assert.strictEqual(fs.readFileSync(path.join(out, f), 'utf8'), fs.readFileSync(path.join(ROOT, 'src', f), 'utf8'), f + ' must be the unchanged shared file');
    const html = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
    assert(html.indexOf('native-shim.js') < html.indexOf('host.js'), 'shim loads before host.js');
    const m = JSON.parse(fs.readFileSync(path.join(out, 'ks/manifest.json'), 'utf8'));
    assert(m.version === require(path.join(ROOT, 'vr/version.json')).versionName && m.files.includes('videos/lesson1.mp4'));
  });

  await test('Windows browser.ks is untouched; the VR one = browser.ks + addon', () => {
    const win = fs.readFileSync(path.join(ROOT, 'resources/browser.ks'), 'utf8');
    const vr = fs.readFileSync(path.join(out, 'ks/browser.ks'), 'utf8');
    assert(vr.startsWith(win.replace(/\s*$/, '')) && vr.includes('Kompass VR additions'));
    assert(!win.includes('Kompass VR additions'));
  });

  await test('native-shim implements every window.native call of src/preload.js', () => {
    const pre = fs.readFileSync(path.join(ROOT, 'src/preload.js'), 'utf8');
    const shim = fs.readFileSync(path.join(ROOT, 'vr/web/native-shim.js'), 'utf8');
    const names = [...pre.matchAll(/^\s+([a-zA-Z]+): (?:\(|\{)/gm)].map(x => x[1]);
    assert(names.length > 40, 'parsed preload names');
    const missing = names.filter(n => !new RegExp('\\b' + n + '(: |,\\n)').test(shim));
    assert.deepStrictEqual(missing, []);
    for (const m of ['loadURL', 'canGoBack', 'canGoForward', 'goBack', 'goForward', 'reload', 'stop', 'setZoomFactor', 'findInPage', 'stopFindInPage', 'setAudioMuted', 'openDevTools'])
      assert(new RegExp('\\b' + m + '\\(').test(shim), 'webview method ' + m);
  });

  await test('VR browser.ks boots: midnight theme on first run, ☰ menu button, 18 quick-menu entries, the VR lesson, all internal pages draw', async () => {
    const src = fs.readFileSync(path.join(out, 'ks/browser.ks'), 'utf8');
    const host = fs.readFileSync(path.join(ROOT, 'src/host.js'), 'utf8');
    const names = [...host.matchAll(/^\s{6}([a-z_]+): B\(/gm)].map(m => m[1]);
    const calls = [], saved = {}, buttons = [], themes = []; let nextTab = 1, handler = null, dbl = null, popups = 0;
    const b = {};
    for (const n of names) b[n] = { fn: () => { calls.push(n); return new K.KHandle('box', {}); }, min: 0, max: 9 };
    Object.assign(b, {
      load_data: { fn: ([n, d]) => d === undefined ? null : d, min: 1, max: 2 },
      save_data: { fn: ([n, v]) => { saved[n] = v; return true; }, min: 2, max: 2 },
      set_theme: { fn: ([t]) => { themes.push(t); return null; }, min: 1, max: 1 },
      button: { fn: ([p, t, f, s]) => { buttons.push([t, s]); return new K.KHandle('button', {}); }, min: 2, max: 4 },
      popup: { fn: () => { popups++; return new K.KHandle('box', {}); }, min: 2, max: 3 },
      tab_new: { fn: () => nextTab++, min: 0, max: 1 },
      tab_url: { fn: () => 'kompass://home', min: 1, max: 1 },
      tab_can_back: { fn: () => false, min: 1, max: 1 }, tab_can_forward: { fn: () => false, min: 1, max: 1 },
      adblock: { fn: () => new K.KMap({ on: true, blocked: 0 }), min: 0, max: 1 },
      on_tab_event: { fn: ([f]) => { handler = f; return null; }, min: 1, max: 1 },
      on_double_right_click: { fn: ([f]) => { dbl = f; return null; }, min: 1, max: 1 },
      now_text: { fn: () => 'now', min: 0, max: 0 }, url_encode: { fn: ([s]) => encodeURIComponent(s), min: 1, max: 1 },
      read_script: { fn: () => '', min: 1, max: 1 },
      read_resource: { fn: ([n]) => { try { return fs.readFileSync(path.join(out, 'ks', n), 'utf8'); } catch (e) { return ''; } }, min: 1, max: 1 },
      run_page: { fn: () => new K.KMap({ ok: true, output: [], error: '', line: 0, steps: 1 }), min: 2, max: 4 },
      pw_status: { fn: () => new K.KMap({ exists: false, unlocked: false, count: 0 }), min: 0, max: 0 },
      pw_list: { fn: () => [], min: 0, max: 1 },
      store_index: { fn: () => new K.KMap({ ok: true, entries: [], source: 'offline copy', error: '' }), min: 0, max: 0 },
      update_state: { fn: () => new K.KMap({ status: 'idle', current: '1.5.1-vr.1', latest: '', progress: 0, error: '', url: '', kind: 'android-apk', autoUpdate: true }), min: 0, max: 0 },
      app_version: { fn: () => '1.5.1-vr.1', min: 0, max: 0 },
      print: { fn: (a) => { calls.push('print:' + a.join(' ')); return null; }, min: 0, max: 9 },
    });
    const errs = [];
    const it = new K.Interpreter({ builtins: b, maxSteps: 2e6, onError: (e) => errs.push(e.message) });
    await it.run(src);
    assert.deepStrictEqual(errs, []);
    assert(calls.includes('print:Kompass VR additions loaded'));
    assert.strictEqual(themes[themes.length - 1], 'midnight', 'VR default theme');
    assert(saved.settings && saved.settings.m.get('vr_setup') === 1, 'first-run flag saved');
    assert(buttons.some(([t, s]) => t === '☰' && /vr-menu/.test(s)), 'VR menu button');
    assert.strictEqual(await it.repl('len(QUICK)'), 18);   // Windows 14 (1.5.2 added fullscreen) + 4 VR entries
    assert.strictEqual(await it.repl('len(LESSONS)'), 16);
    assert.strictEqual(await it.repl('LESSONS[15].title'), 'VR games: hands, swings & immersive mode');
    assert.strictEqual(await it.repl('VERSION'), require(path.join(ROOT, 'package.json')).version + ' VR');
    await it.invoke(dbl, [100, 100, true, 'https://example.com/']);
    assert(popups >= 1, 'long-press/☰ opens the quick menu');
    for (const page of ['kompass://home', 'kompass://settings', 'kompass://learn', 'kompass://builder', 'kompass://passwords', 'kompass://store', 'kompass://about']) {
      await it.invoke(handler, ['internal', 1, page]);
    }
    assert.deepStrictEqual(errs, []);
  });

  await test('Android manifest: Quest 2D panel app, landscape, no phone-only hardware required', () => {
    const m = fs.readFileSync(path.join(ROOT, 'android/app/src/main/AndroidManifest.xml'), 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    assert(m.includes('com.oculus.supportedDevices') && /quest3/.test(m));
    assert(!m.includes('com.oculus.intent.category.VR'), 'not an immersive-only app');
    assert(m.includes('android:screenOrientation="landscape"') && m.includes('<layout android:defaultWidth='));
    for (const f of ['touchscreen', 'telephony', 'camera', 'vr.headtracking']) assert(new RegExp('hardware\\.' + f.replace('.', '\\.') + '" android:required="false"').test(m), f + ' not required');
    assert(!/CAMERA|RECORD_AUDIO|LOCATION|READ_PHONE/.test(m.match(/uses-permission[^>]*/g).join(' ')), 'no phone permissions');
  });

  fs.rmSync(out, { recursive: true, force: true });
  console.log('\n' + pass + ' passed, ' + fail + ' failed');
  process.exit(fail ? 1 : 0);
})();
