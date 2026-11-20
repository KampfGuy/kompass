module.exports = async (h) => {
  const { wait, go, shot, js, key, mouse } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-vector'); await wait(3500);
  console.log('[vec] errors', await L.errors(), '| status', await L.q('.kapp-status'), '| objects', await L.count('.kd-layer'));
  await shot(O + 'vector-1-sample.png');
  const r = await js(`(()=>{const r=${L.T}.querySelector('.kd-viewwrap canvas').getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height}})()`);
  const drag = async (pts, mods) => { mouse('mouseDown', pts[0][0], pts[0][1], 'left', mods); await wait(40); for (const p of pts.slice(1)) { mouse('mouseMove', p[0], p[1], 'left', mods); await wait(40); } const e = pts[pts.length - 1]; mouse('mouseUp', e[0], e[1], 'left', mods); await wait(250); };
  const cx = r.l + r.w / 2, cy = r.t + r.h / 2;
  // draw a rectangle
  await L.btn('▭', '.kd-tool'); await drag([[cx - 60, cy - 40], [cx, cy], [cx + 60, cy + 40]]);
  console.log('[vec] after rect', await L.q('.kapp-status'), '| sel', await L.q('.kd-props .kapp-sec'));
  // change fill via hex field
  await js(`(()=>{const t=${L.T}.querySelector('.kd-props .kd-hex');t.value='#22b14c';t.dispatchEvent(new Event('input',{bubbles:true}))})()`); await wait(500);
  // move it by dragging
  await drag([[cx, cy], [cx + 40, cy + 20], [cx + 80, cy + 40]]);
  const x1 = await js(`${L.T}.querySelectorAll('.kd-xywh .kd-fin')[0].value`);
  console.log('[vec] moved X =', x1);
  // rotate handle: above top center
  // duplicate + align left
  await L.btn('Duplicate', '.kd-opts .kapp-btn'); await wait(200);
  console.log('[vec] after dup', await L.q('.kapp-status'));
  // star
  await L.btn('★', '.kd-tool'); await drag([[cx - 250, cy + 100], [cx - 200, cy + 150], [cx - 150, cy + 200]]);
  // pen: 3 points + close
  await L.btn('✒', '.kd-tool');
  for (const p of [[cx + 150, cy + 120], [cx + 250, cy + 120], [cx + 200, cy + 200]]) { mouse('mouseDown', p[0], p[1]); mouse('mouseUp', p[0], p[1]); await wait(400); }
  mouse('mouseDown', cx + 150, cy + 120); mouse('mouseUp', cx + 150, cy + 120); await wait(300);
  console.log('[vec] after pen', await L.q('.kapp-status'), '| sel', await L.q('.kd-props .kapp-sec'));
  // text
  await L.btn('T', '.kd-tool'); mouse('mouseDown', cx - 280, cy - 200); mouse('mouseUp', cx - 280, cy - 200); await wait(300);
  await js(`${L.T}.querySelector('.kd-dialog .kd-fin').value='Poster!'`); await L.btn('OK', '.kd-dialog button'); await wait(300);
  await shot(O + 'vector-2-edit.png');
  // undo twice, redo once
  await L.btn('↶', '.kapp-btn'); await L.btn('↶', '.kapp-btn'); await L.btn('↷', '.kapp-btn'); await wait(200);
  console.log('[vec] undo/redo', await L.q('.kapp-status'));
  await L.btn('Export SVG', '.kapp-btn'); await wait(600);
  await L.btn('Export PNG', '.kapp-btn'); await wait(600);
  await L.btn('Save', '.kapp-btn', 0, true); await wait(600);
  console.log('[vec] saved', require('fs').readdirSync(process.env.KOMPASS_SAVE_DIR).join(','), '| err', await L.errors());
  // import SVG
  await L.btn('New', '.kapp-btn'); await wait(200); await L.btn('Create', '.kd-dialog button'); await wait(300);
  await L.btn('Open', '.kapp-btn'); await wait(1500);
  console.log('[vec] imported', await L.q('.kapp-status'), '| err', await L.errors());
  await shot(O + 'vector-3-import.png');
};
