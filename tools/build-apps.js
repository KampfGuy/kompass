#!/usr/bin/env node
// Builds the Kompass 1.8 Kugel Store apps from kugel-apps/<dir>/*.ks (shared parts are concatenated in order) into
// kugel-apps/dist/<id>.ks and resources/store/entries/<id>.ks (the offline store copy), and adds/updates their cards in
// resources/store/index.json.  Usage: node tools/build-apps.js [--store /path/to/kugel-store]  (also copies there)
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..'), SRC = path.join(ROOT, 'kugel-apps');
const NEED = ' Needs Kompass 1.8.0+.';
const APPS = [
  { id: 'kugel-arithmetricks', icon: '🧮', title: 'Kugel Arithmetricks', tags: ['app', 'work', 'calculator'], files: ['calc/calc-core.ks', 'calc/arithmetricks.ks'],
    description: 'A real calculator in the Windows 11 style: Standard, Scientific, Programmer (HEX/DEC/OCT/BIN), date calculation and 10 unit converters. History, memory, keyboard, light and dark theme.' },
  { id: 'arithmetricks-premium', icon: '💸', title: 'Arithmetricks Premium', tags: ['game', 'satire', 'simulation'], files: ['calc/calc-core.ks', 'calc/premium.ks'],
    description: 'Satirical pay-to-win calculator game: buy the digits, the equals sign is extra, CalcBank debt tiers, a $100/min Premium subscription, the Employee Portal and Chapter 7. Fake money only, fully offline.' },
  { id: 'kugel-notes', icon: '🗒', title: 'Kugel Notes', tags: ['app', 'work', 'notes'], files: ['work/kit.ks', 'work/notes.ks'],
    description: 'Notes with folders, Markdown formatting, checklists, pins and search. Import and export .md / .txt. Everything stays on this PC.' },
  { id: 'kugel-lattice', icon: '▦', title: 'Kugel Lattice', tags: ['app', 'work', 'spreadsheet'], files: ['calc/calc-core.ks', 'work/kit.ks', 'work/lattice.ks'],
    description: 'Spreadsheets: formulas (SUM, AVERAGE, IF, VLOOKUP and more), several sheets, formatting, charts, CSV and .xlsx import / export.' },
  { id: 'kugel-prism', icon: '🔷', title: 'Kugel Prism', tags: ['app', 'work', 'slides'], files: ['work/kit.ks', 'work/prism.ks'],
    description: 'Slides and presentations: themes, layouts, text with bullets, shapes and pictures, speaker notes, fullscreen presenting, .pptx import / export and PNG export.' },
  { id: 'kugel-paint', icon: '🖌', title: 'Kugel Paint', tags: ['app', 'design', 'art'], files: ['design/kit.ks', 'design/paint.ks'],
    description: 'Painting like a small Photoshop / Fresco: layers, brush, pencil, eraser, fill, shapes, text, colour picker, selections, filters, flip / rotate / resize, undo, PNG / JPG import and PNG export.' },
  { id: 'kugel-motion', icon: '🎞', title: 'Kugel Motion', tags: ['app', 'design', 'animation'], files: ['design/kit.ks', 'design/motion.ks'],
    description: 'Animation like a small Adobe Animate: frame-by-frame drawing on a timeline, a background layer, onion skin, in-between (tween) frames, playback, GIF / WebM / sprite sheet export for your games.' },
  { id: 'kugel-vector', icon: '✒', title: 'Kugel Vector', tags: ['app', 'design', 'vector'], files: ['design/kit.ks', 'design/vector.ks'],
    description: 'Vector graphics like a small Illustrator: rectangles, ellipses, lines, stars, pen and freehand paths, text, fill / stroke, resize / rotate handles, arrange and align, SVG import, SVG and PNG export.' },
];
const args = process.argv.slice(2); const storeDir = args.includes('--store') ? args[args.indexOf('--store') + 1] : null;
const idxFile = path.join(ROOT, 'resources/store/index.json'); const idx = JSON.parse(fs.readFileSync(idxFile, 'utf8'));
let built = 0;
for (const a of APPS) {
  const missing = a.files.filter((f) => !fs.existsSync(path.join(SRC, f)));
  if (missing.length) { console.log('skip ' + a.id + ' (missing ' + missing.join(', ') + ')'); continue; }
  const src = ['# ============================================================================', '#  ' + a.icon + ' ' + a.title + ' — Kugel Store app for Kompass 1.8+ (written in KampfScript)',
    '#  ' + a.description, '#  Built by tools/build-apps.js from kugel-apps/' + a.files.join(', kugel-apps/'), '# ============================================================================', '']
    .concat(a.files.map((f) => fs.readFileSync(path.join(SRC, f), 'utf8'))).join('\n');
  fs.mkdirSync(path.join(SRC, 'dist'), { recursive: true });
  fs.writeFileSync(path.join(SRC, 'dist', a.id + '.ks'), src);
  fs.writeFileSync(path.join(ROOT, 'resources/store/entries', a.id + '.ks'), src);
  const card = { id: a.id, icon: a.icon, title: a.title, author: 'KampfGuy', description: a.description + NEED, tags: a.tags };
  const i = idx.entries.findIndex((e) => e.id === a.id); if (i >= 0) idx.entries[i] = card; else idx.entries.push(card);
  if (storeDir) {
    fs.writeFileSync(path.join(storeDir, 'entries', a.id + '.ks'), src);
  }
  built++; console.log('built ' + a.id + ' (' + src.split('\n').length + ' lines)');
}
fs.writeFileSync(idxFile, JSON.stringify(idx, null, 2) + '\n');
if (storeDir) {
  const sf = path.join(storeDir, 'index.json'); const si = JSON.parse(fs.readFileSync(sf, 'utf8'));
  for (const a of APPS) { const c = idx.entries.find((e) => e.id === a.id); if (!c) continue; const i = si.entries.findIndex((e) => e.id === a.id); if (i >= 0) si.entries[i] = c; else si.entries.push(c); }
  fs.writeFileSync(sf, JSON.stringify(si, null, 2) + '\n');
}
console.log(built + ' apps built');
