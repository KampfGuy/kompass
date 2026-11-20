// Run: node tests/v180.test.js — Kompass 1.8.0: Kugel Game Designer sidebar apps. The eight new Kugel Store apps
// (Arithmetricks, Arithmetricks Premium, Notes, Lattice, Prism, Paint, Motion, Vector) start headless, and their
// engines are checked: calculator maths, spreadsheet formulas / sorting / .xlsx parts, SVG output and SVG path
// parsing, .pptx parts, colour maths. Clicking / typing through the real UI is covered by tests/e2e (Electron).
const fs = require('fs'), path = require('path'), assert = require('assert');
const K = require('../src/lang.js');
const store = require('../src/store.js');
const { stubRuntime } = require('./stub-runtime.js');
const { realBuiltins } = require('../tools/gen-ai-doc.js');
const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let passed = 0; const ok = (m) => { passed++; console.log('  ok   ' + m); };
const g = (m, k) => (m instanceof K.KMap ? m.m.get(k) : undefined);
const APPS = ['kugel-arithmetricks', 'arithmetricks-premium', 'kugel-notes', 'kugel-lattice', 'kugel-prism', 'kugel-paint', 'kugel-motion', 'kugel-vector'];
const toJS = (x) => Array.isArray(x) ? x.map(toJS) : x instanceof K.KMap ? Object.fromEntries([...x.m].map(([k, v]) => [k, toJS(v)])) : x;
const toK = (v) => { if (v === undefined || v === null) return null; if (Array.isArray(v)) return v.map(toK); if (typeof v === 'object') { const m = new K.KMap(); for (const k of Object.keys(v)) m.m.set(k, toK(v[k])); return m; } return v; };

// every app built-in exists; the ones whose results the apps read behave like the real thing
function appRuntime(storeInit) {
  const zips = [];
  const H = (kind) => new K.KHandle(kind, { text: '', value: '' });
  const extra = {};
  for (const n of realBuiltins().apps) extra[n] = { fn: () => H('box'), min: 0, max: 9 };
  Object.assign(extra, {
    json: { fn: ([v]) => JSON.stringify(toJS(v)), min: 1, max: 2 },
    parse_json: { fn: ([t]) => { try { return toK(JSON.parse(K.show(t))); } catch (e) { return null; } }, min: 1, max: 1 },
    text_width: { fn: ([t, s]) => K.show(t).length * (typeof s === 'number' ? s : 14) * 0.55, min: 1, max: 3 },
    zip_create: { fn: ([files]) => { zips.push(toJS(files)); return 'data:application/zip;base64,'; }, min: 1, max: 2 },
    canvas_data: { fn: () => 'data:image/png;base64,iVBORw0KGgo=', min: 1, max: 1 },
    canvas_copy: { fn: () => 'data:image/png;base64,iVBORw0KGgo=', min: 1, max: 5 },
    draw_image: { fn: () => true, min: 4, max: 8 },
    draw_fill: { fn: () => 10, min: 4, max: 5 },
    pixel_at: { fn: () => '#ff0000ff', min: 3, max: 3 },
    load_image: { fn: () => toK({ ok: true, w: 10, h: 10 }), min: 1, max: 1 },
    file_save: { fn: () => toK({ ok: true, name: 'x', bytes: 1 }), min: 2, max: 2 },
    file_open: { fn: () => null, min: 0, max: 1 },
  });
  const r = stubRuntime({ extra, store: storeInit });
  r.zips = zips;
  r.val = async (src) => toJS(await r.it.repl(src));
  return r;
}

(async () => {
  // ---------------------------------------------------------------- catalog + entries
  const idx = JSON.parse(read('resources/store/index.json')); const clean = store.cleanIndex(idx);
  for (const id of APPS) {
    const e = clean.find(x => x.id === id); assert(e, 'listed: ' + id);
    assert(/Needs Kompass 1\.8\.0\+/.test(e.description), id + ' says it needs 1.8.0');
    const code = read('resources/store/entries/' + id + '.ks'); K.parse(K.tokenize(code));
    assert.strictEqual(code, read('kugel-apps/dist/' + id + '.ks'), id + ' entry == built dist file');
    assert(!/\b(tab_\w+|load_data|save_data|open_external|read_script|pw_\w+|run_app)\(/.test(code), id + ' uses only sandbox built-ins');
  }
  assert(clean.find(x => x.id === 'arithmetricks-premium').tags.includes('game'), 'Premium is a game (Game Designer list)');
  for (const id of ['kugel-paint', 'kugel-motion', 'kugel-vector', 'kugel-prism', 'kugel-notes', 'kugel-lattice', 'kugel-arithmetricks']) assert(read('resources/browser.ks').includes('["' + id + '"'), id + ' is in the sidebar');
  ok('8 apps listed (' + clean.length + ' programs), parse, dist == store entry, sandbox-only, all in the sidebar');

  // ---------------------------------------------------------------- every app starts headless without an error
  const rts = {};
  for (const id of APPS) { const r = appRuntime({}); await r.run(read('resources/store/entries/' + id + '.ks')); rts[id] = r; }
  ok('all 8 apps start headless (stub UI) without errors');

  // ---------------------------------------------------------------- calculator core
  {
    const r = rts['kugel-arithmetricks'];
    const ev = async (e, o) => { const v = await r.val(`calc_eval(${JSON.stringify(e)}, ${o || '{}'})`); return v; };
    for (const [e, want, o] of [['2+3*4', 14], ['(2+3)*4', 20], ['2^3^2', 512], ['-2^2', -4], ['5!', 120], ['sqrt(16)+√9', 7], ['sin(30)', 0.5, '{angle: "deg"}'], ['log(1000)', 3], ['7 mod 3', 1], ['3(4+1)', 15], ['12 × 3 − 6 ÷ 2', 33]]) {
      const v = await ev(e, o); assert(v.ok && Math.abs(v.value - want) < 1e-9, e + ' = ' + want + ' (got ' + v.value + ')');
    }
    for (const [e, err] of [['1/0', 'Cannot divide by zero'], ['2++', 'Incomplete expression'], ['sqrt(-1)', 'Invalid input']]) { const v = await ev(e); assert(!v.ok && v.error === err, e); }
    assert.strictEqual(await r.val('calc_fmt(1234567.891)'), '1,234,567.891'); assert.strictEqual(await r.val('calc_fmt(0.1 + 0.2)'), '0.3');
  }
  ok('calculator: precedence, powers, factorial, roots, degrees, implicit ×, errors, number formatting');

  // ---------------------------------------------------------------- Lattice formulas, refs, sorting, xlsx
  {
    const r = rts['kugel-lattice'];
    const cell = async (k) => r.val(`value_of("${k}")`);
    await r.run(['set_raw("H1", "10")', 'set_raw("H2", "20")', 'set_raw("H3", "x")', 'set_raw("I1", "=SUM(H1:H3)")', 'set_raw("I2", "=AVERAGE(H1:H2)*2")', 'set_raw("I3", "=IF(I1>25,\\"big\\",\\"small\\")")',
      'set_raw("I4", "=VLOOKUP(\\"Food\\",A2:E5,5,FALSE)")', 'set_raw("I5", "=1/0")', 'set_raw("I6", "=CONCAT(\\"a\\",UPPER(\\"b\\"),ROUND(2.345,2))")', 'set_raw("I7", "=COUNTIF(H1:H3,\\">15\\")")', 'set_raw("I8", "=I1+I9")', 'set_raw("I9", "=I8")', 'recalc()'].join('\n'));
    assert.strictEqual(await cell('I1'), 30); assert.strictEqual(await cell('I2'), 30); assert.strictEqual(await cell('I3'), 'big');
    assert.strictEqual(await cell('I4'), 906.5, 'VLOOKUP into the demo budget');
    assert.deepStrictEqual(await cell('I5'), { e: '#DIV/0!' }); assert.strictEqual(await cell('I6'), 'aB2.35'); assert.strictEqual(await cell('I7'), 1);
    assert(/#(CIRC|REF)/.test(JSON.stringify(await cell('I8'))), 'circular reference is an error, not a hang');
    assert.strictEqual(await r.val('move_formula("=SUM(B2:D2)+$A$1", 1, 2)'), '=SUM(D3:F3)+$A$1', 'relative refs move, absolute stay');
    // sorting rows keeps each row's formulas pointing at its own row (the Fun / Transport bug)
    await r.run('anc = {c: 0, r: 1}\nact = {c: 4, r: 4}\nsort_sel(false)');
    const rows = []; for (let i = 2; i <= 5; i++) rows.push([await r.val(`cell_raw("A${i}")`), await r.val(`cell_raw("E${i}")`), await cell('E' + i)]);
    assert.deepStrictEqual(rows.map(x => x[0]), ['Rent', 'Food', 'Fun', 'Transport']);
    rows.forEach((x, i) => assert.strictEqual(x[1], '=SUM(B' + (i + 2) + ':D' + (i + 2) + ')'));
    assert.deepStrictEqual(rows.map(x => x[2]), [2850, 906.5, 325, 221]);
    // undo restores the old order
    await r.run('undo()'); assert.strictEqual(await r.val('cell_raw("A4")'), 'Transport');
    // .xlsx parts: workbook, sheets with shared formulas as <f>, bold style, cellStyles
    await r.run('let xl = to_xlsx()');
    const z = r.zips[r.zips.length - 1];
    for (const f of ['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/_rels/workbook.xml.rels', 'xl/styles.xml', 'xl/worksheets/sheet1.xml']) assert(z[f], 'xlsx has ' + f);
    assert(z['xl/worksheets/sheet1.xml'].includes('<c r="E2"><f>SUM(B2:D2)</f><v>2850</v></c>'));
    assert(/<cellStyles count="1">/.test(z['xl/styles.xml']));
    assert(r.get('to_csv') && /^Item,Jan,Feb,Mar,Total/.test(await r.val('to_csv()')));
  }
  ok('Lattice: SUM/AVERAGE/IF/VLOOKUP/COUNTIF/CONCAT, #DIV/0!, circular refs, $ refs, sort keeps row formulas, undo, .xlsx + CSV');

  // ---------------------------------------------------------------- Vector: SVG out, SVG path parsing, geometry
  {
    const r = rts['kugel-vector'];
    const svg = await r.val('to_svg()');
    assert(/^<svg xmlns="http:\/\/www.w3.org\/2000\/svg" width="800" height="600"/.test(svg));
    for (const t of ['<rect ', '<ellipse ', '<path d="M', '<text ', 'transform="rotate(12 ']) assert(svg.includes(t), 'svg has ' + t);
    assert.strictEqual((svg.match(/<(rect|ellipse|path|text|line)\b/g) || []).length, 6, 'background + 5 sample shapes');
    const sub = await r.val('path_points("M10 10 h20 v20 H10 Z m5 5 l1 1")');
    assert.strictEqual(sub.length, 2); assert.deepStrictEqual(sub[0].pts, [[10, 10], [30, 10], [30, 30], [10, 30]]); assert(sub[0].closed);
    const curve = await r.val('path_points("M0 0 C 0 10, 10 10, 10 0")'); assert.strictEqual(curve[0].pts.length, 9); assert.deepStrictEqual(curve[0].pts[8], [10, 0]);
    assert.strictEqual((await r.val('star_pts(0, 0, 10, 5, 5)')).length, 10);
    await r.run('let s1 = mk("rect")\ns1.x = 0\ns1.y = 0\ns1.w = 100\ns1.h = 50\nset_bbox(s1, {x: 10, y: 20, w: 30, h: 40})');
    assert.deepStrictEqual(await r.val('bbox(s1)'), { x: 10, y: 20, w: 30, h: 40 });
    await r.run('let p1 = mk("path")\np1.pts = [[0, 0], [10, 0], [10, 10]]\nset_bbox(p1, {x: 0, y: 0, w: 20, h: 40})');
    assert.deepStrictEqual(await r.val('p1.pts'), [[0, 0], [20, 0], [20, 40]], 'paths scale with their box');
    await r.run('selected = [shapes[1].id]\nduplicate()\nundo()'); assert.strictEqual(await r.val('len(shapes)'), 5, 'duplicate + undo');
  }
  ok('Vector: SVG export (shapes, rotation), SVG path parser (M/h/v/H/Z, relative, cubic curves), stars, resize, duplicate + undo');

  // ---------------------------------------------------------------- Prism: .pptx parts, layouts, bullets
  {
    const r = rts['kugel-prism'];
    assert.strictEqual(await r.val('len(deck.slides)'), 3);
    await r.run('let px = to_pptx()');
    const z = r.zips[r.zips.length - 1];
    for (const f of ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml', 'ppt/_rels/presentation.xml.rels', 'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml', 'ppt/theme/theme1.xml', 'ppt/slides/slide1.xml', 'ppt/slides/slide3.xml', 'ppt/slides/_rels/slide3.xml.rels']) assert(z[f], 'pptx has ' + f);
    assert.strictEqual((z['ppt/presentation.xml'].match(/<p:sldId /g) || []).length, 3);
    assert(z['ppt/slides/slide2.xml'].includes('<a:buChar char="•"/>') && z['ppt/slides/slide2.xml'].includes('<a:t>Pick a theme and a layout</a:t>'), 'bullets become real PowerPoint bullets');
    assert(z['ppt/slides/slide3.xml'].includes('prst="ellipse"'));
    for (const [f, x] of Object.entries(z)) { const opens = (x.match(/<[a-zA-Z]/g) || []).length; const closes = (x.match(/<\/|\/>/g) || []).length; assert(opens <= closes + 1 && opens > 0, f + ' looks balanced'); }
    for (const L of ['Title slide', 'Title and content', 'Section header', 'Two columns', 'Title only', 'Big picture', 'Blank']) await r.run('add_slide("' + L + '")');
    assert.strictEqual(await r.val('len(deck.slides)'), 10);
    const lines = await r.val('wrap_lines("- one two three four five six\\nplain", 120, 20, "Segoe UI")');
    assert(lines[0].bullet && lines.length >= 3 && lines[lines.length - 1].t === 'plain' && !lines[lines.length - 1].bullet, 'wrapping keeps bullets on the first line only');
  }
  ok('Prism: .pptx package (presentation, master, layout, theme, slides, bullets, shapes), 7 layouts, text wrapping');

  // ---------------------------------------------------------------- Design kit colour maths
  {
    const r = rts['kugel-paint'];
    assert.strictEqual(await r.val('kd_hsl_hex(0, 100, 50)'), '#ff0000'); assert.strictEqual(await r.val('kd_hsl_hex(120, 100, 25)'), '#008000');
    assert.strictEqual(await r.val('kd_parse_hex("#ABC")'), '#aabbcc'); assert.strictEqual(await r.val('kd_parse_hex("zzz")'), null);
    const hsl = await r.val('kd_hex_hsl("#3f48cc")'); assert.strictEqual(await r.val(`kd_hsl_hex(${hsl.h}, ${hsl.s}, ${hsl.l})`), '#3f48cc', 'hex → hsl → hex round trip');
    assert.strictEqual(await r.val('len(layers)'), 2, 'welcome picture has 2 layers');
    await r.run('add_layer()\ndup_layer()\nmerge_down()\ndelete_layer()'); assert.strictEqual(await r.val('len(layers)'), 2);
    await r.run('undo()'); assert.strictEqual(await r.val('len(layers)'), 3, 'layer changes undo');
    const m = rts['kugel-motion']; assert.strictEqual(await m.val('len(frames)'), 8, 'bouncing ball sample');
    await m.run('add_frame(true)\nmove_frame(-1)\ndelete_frame()'); assert.strictEqual(await m.val('len(frames)'), 8);
    await m.run('undo()'); assert.strictEqual(await m.val('len(frames)'), 9);
  }
  ok('Design kit colours (HSL ↔ hex), Paint layer add/duplicate/merge/delete + undo, Motion frames + undo');

  // ---------------------------------------------------------------- Notes + new built-ins documented
  {
    const r = rts['kugel-notes'];
    assert(await r.val('len(notes)') >= 1); assert.strictEqual(await r.val('snippet({body: "# **Hi** `there`\\nmore"})'), 'Hi there');
    const docs = read('tools/builtin-docs.js');
    for (const b of ['text_insert', 'text_selection', 'on_keydown', 'key_prevent', 'canvas_filter', 'gif_encode', 'canvas_record', 'zip_create', 'zip_read', 'xml_parse']) assert(new RegExp('\\b' + b + ': \\[').test(docs), b + ' documented');
    assert.strictEqual((docs.match(/\bon_keydown: \[/g) || []).length, 1, 'documented once');
    for (const e of ['kpaint', 'kmotion', 'kvector', 'kprism', 'knotes', 'klattice', 'pptx', 'xlsx', 'gif', 'webm']) assert(read('src/main.js').includes("'" + e + "'"), e + ' allowed by the Save dialog');
  }
  ok('Notes snippets, new built-ins documented once, new file types allowed');

  console.log('\n' + passed + ' passed, 0 failed');
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
