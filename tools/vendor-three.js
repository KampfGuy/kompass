// Re-bundle three.js into src/vendor/three.min.js (a classic script that sets window.THREE; Kompass loads no CDN code).
// Usage: node tools/vendor-three.js [version]   (needs network + npx; installs three + esbuild in a temp folder)
const cp = require('child_process'), fs = require('fs'), os = require('os'), path = require('path');
const ver = process.argv[2] || 'latest';
const d = fs.mkdtempSync(path.join(os.tmpdir(), 'three-vendor-'));
const run = (c) => cp.execSync(c, { cwd: d, stdio: 'inherit' });
run('npm init -y >/dev/null && npm i three@' + ver + ' esbuild --silent');
fs.writeFileSync(path.join(d, 'entry.js'), "export * from 'three';\n");
run('npx esbuild entry.js --bundle --format=iife --global-name=THREE --minify --legal-comments=none --outfile=three.min.js');
const v = require(path.join(d, 'node_modules/three/package.json')).version;
const out = path.join(__dirname, '..', 'src', 'vendor');
fs.writeFileSync(path.join(out, 'three.min.js'), '/*! three.js ' + v + ' (r' + v.replace(/^0\./, '') + ') — MIT License, Copyright © 2010-2026 three.js authors (see three-LICENSE.txt). Bundled locally by tools/vendor-three.js: window.THREE, no CDN. */\n' + fs.readFileSync(path.join(d, 'three.min.js'), 'utf8'));
fs.copyFileSync(path.join(d, 'node_modules/three/LICENSE'), path.join(out, 'three-LICENSE.txt'));
console.log('three.js ' + v + ' -> src/vendor/three.min.js');
