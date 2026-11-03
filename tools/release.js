// Build + publish a Kompass release that the auto-updater (src/updater.js) can install.
//   node tools/release.js                 test, build portable exe + zip, write manifest, create GitHub release
//   node tools/release.js --manifest-only only (re)write dist/kompass-update.json + SHA512SUMS.txt
//   node tools/release.js --no-publish    everything except `gh release create`
//   --notes <file>                        release notes (markdown); default: a short generic note
// Bump "version" in package.json (and VERSION in resources/browser.ks) first. See docs/RELEASING.md.
const fs = require('fs'), path = require('path'), crypto = require('crypto'), cp = require('child_process');
const ROOT = path.join(__dirname, '..'), DIST = path.join(ROOT, 'dist');
const args = process.argv.slice(2), has = (f) => args.includes(f);
const pkg = require(path.join(ROOT, 'package.json')); const v = pkg.version;
const run = (c, a) => { console.log('$ ' + c + ' ' + a.join(' ')); const r = cp.spawnSync(c, a, { cwd: ROOT, stdio: 'inherit' }); if (r.status !== 0) process.exit(r.status || 1); };
const sha = (f) => crypto.createHash('sha512').update(fs.readFileSync(f)).digest('base64');

const ks = fs.readFileSync(path.join(ROOT, 'resources', 'browser.ks'), 'utf8');
if (!ks.includes('let VERSION = "' + v + '"')) { console.error('resources/browser.ks VERSION does not match package.json ' + v); process.exit(1); }
if (!has('--manifest-only')) {
  run('npm', ['test']);
  for (const f of fs.existsSync(DIST) ? fs.readdirSync(DIST) : []) if (/^Kompass-.*\.(exe|zip|blockmap)$|^kompass-update\.json$|^SHA512SUMS\.txt$/.test(f)) fs.unlinkSync(path.join(DIST, f));
  run('npx', ['electron-builder', '--win', 'portable', 'zip', '--x64']);
}
const exe = 'Kompass-' + v + '-portable.exe', zip = 'Kompass-' + v + '-win-x64.zip';
const files = [{ kind: 'portable', name: exe }, { kind: 'zip', name: zip }].map(f => {
  const p = path.join(DIST, f.name); if (!fs.existsSync(p)) { console.error('missing ' + p); process.exit(1); }
  return Object.assign(f, { size: fs.statSync(p).size, sha512: sha(p) });
});
const manifest = { version: v, releaseDate: new Date().toISOString(), files };
fs.writeFileSync(path.join(DIST, 'kompass-update.json'), JSON.stringify(manifest, null, 2) + '\n');
fs.writeFileSync(path.join(DIST, 'SHA512SUMS.txt'), files.map(f => Buffer.from(f.sha512, 'base64').toString('hex') + '  ' + f.name).join('\n') + '\n');
console.log('wrote dist/kompass-update.json + dist/SHA512SUMS.txt for ' + v);
if (has('--manifest-only') || has('--no-publish')) process.exit(0);

const ni = args.indexOf('--notes');
const notesFile = ni >= 0 ? args[ni + 1] : path.join(DIST, 'release-notes.md');
if (ni < 0) fs.writeFileSync(notesFile, 'Kompass ' + v + '\n\nDownload **' + exe + '** and run it. Kompass 1.4.0+ updates itself automatically.\n');
run('gh', ['release', 'create', 'v' + v, '--repo', 'KampfGuy/kompass', '--title', 'Kompass ' + v, '--notes-file', notesFile,
  path.join(DIST, exe), path.join(DIST, zip), path.join(DIST, 'kompass-update.json'), path.join(DIST, 'SHA512SUMS.txt'), path.join(ROOT, 'resources', 'KAMPFSCRIPT_FOR_AI.md')]);
