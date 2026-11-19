// Run: node tests/v160.test.js — Kompass 1.6.0: Google recognises Kompass (up-to-date engine, clean UA + client hints,
// Firefox UA on Google's sign-in pages), VR app source in main (vr/), README.
const fs = require('fs'), path = require('path'), assert = require('assert');
const UA = require('../src/useragent.js');
const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };
const pkg = JSON.parse(read('package.json'));

// ---------------------------------------------------------------- the engine is current
{
  const want = String(pkg.devDependencies.electron).replace(/^[^\d]*/, '').split('.')[0];
  assert(+want >= 45, 'Electron 45+ (Chromium 156+), was 33 = Chromium 130');
  let installed = null; try { installed = require('electron/package.json').version; } catch (e) { /* not installed */ }
  if (installed) assert(+installed.split('.')[0] >= 45, 'installed Electron ' + installed);
  ok('engine: Electron ' + pkg.devDependencies.electron + (installed ? ' (installed ' + installed + ')' : '') + ' — Chromium 156, not the 2-year-old Chromium 130');
}
// ---------------------------------------------------------------- the Chrome UA every site sees
{
  const win = UA.chromeUA('156.0.8078.100', 'win32');
  assert.strictEqual(win, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36');
  assert(!/Electron|Kompass|kompass/.test(win), 'no Electron/Kompass token');
  assert(/X11; Linux x86_64/.test(UA.chromeUA('156.0.1', 'linux')) && /Macintosh/.test(UA.chromeUA('156', 'darwin')), 'OS token matches navigator.platform');
  assert(/Chrome\/156\.0\.0\.0/.test(UA.make({ chrome: '156.0.8078.100' }, 'win32').chrome), 'real major version');
  ok('Chrome UA: ' + win);
}
// ---------------------------------------------------------------- Firefox UA for Google sign-in
{
  assert.strictEqual(UA.firefoxVersion(new Date('2024-07-09T12:00:00Z')), 128);
  assert.strictEqual(UA.firefoxVersion(new Date('2026-11-18T12:00:00Z')), 158);
  assert(UA.firefoxVersion(new Date('2020-01-01')) === 128, 'never below 128');
  const ff = UA.firefoxUA(new Date('2026-11-18'), 'win32');
  assert.strictEqual(ff, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:158.0) Gecko/20100101 Firefox/158.0');
  for (const u of ['https://accounts.google.com/', 'https://accounts.google.com/v3/signin/identifier?continue=x', 'https://accounts.youtube.com/accounts/SetSID']) assert(UA.isGoogleSignIn(u), u);
  for (const u of ['http://accounts.google.com/', 'https://accounts.google.com.evil.example/', 'https://evil.example/accounts.google.com', 'https://www.google.com/search?q=accounts.google.com', 'https://mail.google.com/', 'kompass://learn', 'not a url', null])
    assert(!UA.isGoogleSignIn(u), 'not sign-in: ' + u);
  const set = UA.make({ chrome: '156.0.1' }, 'win32', new Date('2026-11-18'));
  assert.strictEqual(UA.uaFor('https://accounts.google.com/x', set), set.signin);
  assert.strictEqual(UA.uaFor('https://www.youtube.com/', set), set.chrome);
  ok('Google sign-in pages get ' + ff + '; every other site the Chrome UA');
}
// ---------------------------------------------------------------- request headers (UA + client hints agree with the page)
{
  const set = UA.make({ chrome: '156.0.1' }, 'win32', new Date('2026-11-18'));
  set.ch = UA.chHeaders({ brands: [{ brand: 'Not:A-Brand', version: '8' }, { brand: 'Chromium', version: '156' }], mobile: false, platform: 'Windows' });
  assert.deepStrictEqual(set.ch, { 'sec-ch-ua': '"Not:A-Brand";v="8", "Chromium";v="156"', 'sec-ch-ua-mobile': '?0', 'sec-ch-ua-platform': '"Windows"' });
  assert.strictEqual(UA.chHeaders(null), null); assert.strictEqual(UA.chHeaders({ brands: [] }), null);
  let h = UA.fixHeaders({ 'user-agent': 'Mozilla/5.0 ... Electron/45.4.1 kompass/1.6.0', Accept: 'text/html' }, set.chrome, set, 'https://www.google.com/');
  assert.strictEqual(h['User-Agent'], set.chrome); assert(!('user-agent' in h)); assert.strictEqual(h['sec-ch-ua'], set.ch['sec-ch-ua']); assert.strictEqual(h.Accept, 'text/html');
  h = UA.fixHeaders({ 'sec-ch-ua': '"X";v="1"' }, set.chrome, set, 'https://example.com/'); assert.strictEqual(h['sec-ch-ua'], '"X";v="1"', 'hints already there are kept');
  h = UA.fixHeaders({}, set.chrome, set, 'http://example.com/'); assert(!('sec-ch-ua' in h), 'no hints on plain http (like Chrome)');
  h = UA.fixHeaders({ 'sec-ch-ua': 'x', 'Sec-CH-UA-Platform': 'y', 'sec-ch-ua-full-version-list': 'z', Cookie: 'c' }, set.signin, set, 'https://accounts.google.com/');
  assert.deepStrictEqual(h, { Cookie: 'c', 'User-Agent': set.signin }, 'Firefox UA: no Chromium client hints');
  // subresources follow the tab: a sign-in page's scripts go out with the Firefox UA, a normal tab's with Chrome
  const tab = (ua) => ({ isDestroyed: () => false, getUserAgent: () => ua });
  assert.strictEqual(UA.requestUA({ resourceType: 'mainFrame', url: 'https://accounts.google.com/' }, set), set.signin);
  assert.strictEqual(UA.requestUA({ resourceType: 'script', url: 'https://ssl.gstatic.com/x.js', webContents: tab(set.signin) }, set), set.signin);
  assert.strictEqual(UA.requestUA({ resourceType: 'xhr', url: 'https://accounts.google.com/x', webContents: tab(set.chrome) }, set), set.chrome, 'a Google iframe/XHR inside another site keeps the Chrome UA');
  assert.strictEqual(UA.requestUA({ resourceType: 'image', url: 'https://accounts.google.com/x' }, set), set.signin);
  assert.strictEqual(UA.requestUA({ resourceType: 'image', url: 'https://a.example/', webContents: { isDestroyed: () => true } }, set), set.chrome);
  ok('request headers: UA rewritten, Sec-CH-UA added on https (Electron drops them), stripped for the Firefox UA, subresources follow their tab');
}
// ---------------------------------------------------------------- wired into the app
{
  const main = read('src/main.js');
  assert(/require\('\.\/useragent'\)/.test(main) && /app\.userAgentFallback = CHROME_UA/.test(main), 'fallback UA');
  assert(/contents\.setUserAgent\(CHROME_UA\)/.test(main) && /did-start-navigation[\s\S]{0,300}UA\.uaFor\(d\.url, UAS\)/.test(main), 'tabs switch UA before a navigation commits');
  assert(/persist:kompass'\)\.webRequest\.onBeforeSendHeaders\(\(d, cb\) => cb\(\{ requestHeaders: UA\.fixHeaders\(d\.requestHeaders, UA\.requestUA\(d, UAS\), UAS, d\.url\) \}\)\)/.test(main), 'headers fixed for the tab session');
  assert(/UAS\.ch = UA\.chHeaders\(/.test(main), 'client hints from the engine');
  assert(!/'Electron\/|Kompass\/' \+/.test(main), 'no Electron/Kompass UA tokens added');
  assert(/Promise\.resolve\(clipboard\.readText\(\)\)\.then/.test(main), 'password clipboard auto-clear works with the async clipboard of Electron 45');
  const upd = read('src/updater.js'); assert(/'User-Agent': 'Kompass-Updater'/.test(upd), 'the updater still identifies itself (GitHub API wants a UA)');
  const ks = read('resources/browser.ks');
  assert(/fn google_note\(on\)[\s\S]{0,900}Open in my browser[\s\S]{0,80}open_external\(tab_url\(current\)\)/.test(ks), 'Google refusal note offers the default browser');
  ok('wired: fallback + per-tab UA switch + header rewrite + engine client hints; updater keeps "Kompass-Updater"; Google note');
}
// ---------------------------------------------------------------- the VR app lives in main (vr/ + android/), not in the Windows build
{
  for (const f of ['vr/build-web.js', 'vr/build-apk.sh', 'vr/version.json', 'vr/web/native-shim.js', 'vr/store/index-vr.json', 'vr/tests/vr.test.js', 'vr/tests/vr-games.test.js',
    'android/app/build.gradle', 'android/app/src/main/AndroidManifest.xml', 'android/app/src/main/java/com/kampfguy/kompass/vr/WebTabs.java']) assert(fs.existsSync(path.join(ROOT, f)), 'in main: ' + f);
  const files = pkg.build.files; assert(files.every(f => !/^(vr|android)\b/.test(f)) && files.includes('src/**') && files.includes('resources/**'), 'electron-builder packs only src/ + resources/');
  assert(pkg.build.extraResources.every(r => r.from === 'resources'), 'extra resources: resources/ only');
  assert(/vr\/tests\/vr\.test\.js/.test(pkg.scripts['test:vr']) && !/vr\//.test(pkg.scripts.test), 'npm run test:vr runs the VR tests; npm test stays Windows-only');
  const vv = JSON.parse(read('vr/version.json')); assert.strictEqual(vv.versionName, '1.6.0-vr.1'); assert(vv.versionCode >= 3);
  const tabs = read('android/app/src/main/java/com/kampfguy/kompass/vr/WebTabs.java');
  assert(/setUserAgentString\(cleanUA\(s\.getUserAgentString\(\)\)\)/.test(tabs) && /replace\("; wv\)", "\)"\)/.test(tabs) && !/" KompassVR\/" \+/.test(tabs), 'VR web view UA: no "; wv" / Version/4.0 / KompassVR tokens');
  ok('VR app in main: vr/ + android/, kept out of the Windows exe, npm run test:vr, 1.6.0-vr.1 with a clean WebView UA');
}
// ---------------------------------------------------------------- README: one page, Windows + VR sections, download first
{
  const md = read('README.md');
  const win = md.indexOf('## 🧭 Kompass for Windows'), vr = md.indexOf('## 🥽 Kompass VR');
  assert(win > 0 && vr > win, 'two sections, Windows first');
  const dl = (from) => md.slice(from).split('\n').slice(1).find(l => l.trim() && !/^#{3} ⬇/.test(l));
  assert(/releases\/latest/.test(dl(win)), 'Windows section starts with the latest-release download');
  assert(/Kompass-VR-[\d.]+-vr\.\d+\.apk/.test(dl(vr)), 'VR section starts with the APK download');
  for (const t of ['How it updates', 'SHA512', 'Prereleases', 'Kugel Store', 'Fullscreen', 'Learn KampfScript', 'DevTools', 'Kugel Tennis VR', 'Kugel Gorillas VR', 'Kugel Saber VR', 'Quest Browser', 'sideload', 'Unknown Sources'])
    assert(md.includes(t), 'README mentions ' + t);
  ok('README: one page, Windows section + VR section, each opening with its download');
}
// ---------------------------------------------------------------- version
{
  const ks = read('resources/browser.ks');
  assert.strictEqual(pkg.version, '1.6.0'); assert(ks.includes('let VERSION = "1.6.0"'));
  ok('version 1.6.0');
}
console.log('\n' + passed + ' passed, 0 failed');
