// End-to-end simulated update with the REAL Electron app (Linux + xvfb):
//   mock GitHub API + asset server on localhost serves "1.9.9"; Kompass (current version) finds it, downloads,
//   verifies, shows the banner; we click "Restart to update"; the helper swaps the fake target exe and relaunches it.
// Run: xvfb-run -a node tools/e2e-update.js /workspace
const fs = require('fs'), path = require('path'), os = require('os'), http = require('http'), crypto = require('crypto'), cp = require('child_process');
const out = process.argv[2] || '/workspace';
const d = fs.mkdtempSync(path.join(os.tmpdir(), 'kompass-e2e-'));
const target = path.join(d, 'Kompass-portable.exe'), marker = path.join(d, 'relaunched.txt');
fs.writeFileSync(target, '#!/bin/sh\necho old\n', { mode: 0o755 });
const exe = Buffer.concat([Buffer.from('#!/bin/sh\necho "relaunched new 1.9.9" > ' + marker + '\nexit 0\n'), crypto.randomBytes(3 * 1024 * 1024)]);
const sha = crypto.createHash('sha512').update(exe).digest('base64');
const srv = http.createServer((q, r) => {
  const base = 'http://127.0.0.1:' + srv.address().port;
  if (q.url.endsWith('/releases/latest')) return r.end(JSON.stringify({ tag_name: 'v1.9.9', html_url: base + '/rel', assets: [{ name: 'Kompass-1.9.9-portable.exe', browser_download_url: base + '/exe' }, { name: 'kompass-update.json', browser_download_url: base + '/man' }] }));
  if (q.url === '/man') return r.end(JSON.stringify({ version: '1.9.9', files: [{ kind: 'portable', name: 'Kompass-1.9.9-portable.exe', size: exe.length, sha512: sha }] }));
  if (q.url === '/exe') { r.setHeader('content-length', exe.length); return r.end(exe); }
  r.statusCode = 404; r.end();
});
srv.listen(0, '127.0.0.1', () => {
  const env = Object.assign({}, process.env, { KOMPASS_UPDATE_API: 'http://127.0.0.1:' + srv.address().port + '/repos/KampfGuy/kompass/releases/latest', KOMPASS_UPDATE_TARGET: target, KOMPASS_UPDATE_DELAY_MS: '500', KOMPASS_SHOTS14: out, KOMPASS_SHOTS14_INSTALL: '1' });
  const electron = require('electron');
  const p = cp.spawn(electron, ['.', '--no-sandbox'], { cwd: path.join(__dirname, '..'), env, stdio: ['ignore', 'pipe', 'pipe'] });
  p.stdout.on('data', b => process.stdout.write(String(b).split('\n').filter(l => /shots14|updater/.test(l)).map(l => l + '\n').join('')));
  p.on('exit', async (code) => {
    for (let i = 0; i < 40 && !fs.existsSync(marker); i++) await new Promise(r => setTimeout(r, 250));
    const swapped = fs.readFileSync(target).equals(exe);
    console.log('app exit', code, '| target swapped:', swapped, '| relaunched:', fs.existsSync(marker) ? fs.readFileSync(marker, 'utf8').trim() : 'NO');
    srv.close(); process.exit(swapped && fs.existsSync(marker) ? 0 : 1);
  });
});
