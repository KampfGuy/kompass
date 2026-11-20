module.exports = async (h) => {
  const { wait, go, shot, js, key, mouse } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-paint'); await wait(3500);
  console.log('[pt] errors', await L.errors(), '| status', await L.q('.kapp-status'), '| layers', await L.count('.kd-layer'));
  const r = await js(`(()=>{const r=${L.T}.querySelector('.kd-viewwrap canvas').getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height}})()`);
  console.log('[pt] view', JSON.stringify(r));
  const drag = async (pts, btn) => { mouse('mouseDown', pts[0][0], pts[0][1], btn || 'left'); await wait(40); for (const p of pts.slice(1)) { mouse('mouseMove', p[0], p[1], btn || 'left'); await wait(40); } const e = pts[pts.length - 1]; mouse('mouseUp', e[0], e[1], btn || 'left'); await wait(200); };
  const cx = r.l + r.w / 2, cy = r.t + r.h / 2;
  // brush stroke in red
  await L.btn('', '.kd-pal .kd-swatch', 6); await wait(100);
  const wave = []; for (let i = 0; i <= 20; i++) wave.push([cx - 200 + i * 20, cy + 60 + Math.sin(i / 2) * 30]);
  await drag(wave);
  // filled blue rectangle on a new layer
  await L.btn('+', '.kd-laytools .kapp-btn'); await wait(200);
  console.log('[pt] layers after +', await L.count('.kd-layer'));
  await L.btn('▭', '.kd-tool'); await wait(150);
  await js(`${L.T}.querySelector('.kd-opts .ks-check input').click()`); await wait(100);
  await L.btn('', '.kd-pal .kd-swatch', 16); await wait(100);
  await drag([[cx + 60, cy - 120], [cx + 120, cy - 60], [cx + 180, cy - 20]]);
  // ellipse outline orange
  await L.btn('◯', '.kd-tool'); await L.btn('', '.kd-pal .kd-swatch', 8);
  await drag([[cx - 260, cy - 150], [cx - 180, cy - 90], [cx - 120, cy - 60]]);
  // text
  await L.btn('T', '.kd-tool'); await wait(100);
  mouse('mouseDown', cx - 60, cy + 120); mouse('mouseUp', cx - 60, cy + 120); await wait(300);
  await js(`(()=>{const t=${L.T}.querySelector('.kd-dialog .kd-fin');t.value='Kugel!';})()`);
  await L.btn('Add', '.kd-dialog button'); await wait(300);
  console.log('[pt] after drawing', await L.q('.kapp-status'), '| err', await L.errors());
  await shot(O + 'paint-1-drawing.png');
  // picker reads the blue rect
  await L.btn('💧', '.kd-tool'); mouse('mouseDown', cx + 120, cy - 60); mouse('mouseUp', cx + 120, cy - 60); await wait(200);
  console.log('[pt] picked', await js(`${L.T}.querySelector('.kd-hex').value`));
  // undo the text, check pixel count via layer thumbs
  await L.btn('↶', '.kapp-btn'); await wait(300);
  // select + crop  -> size changes
  await L.btn('⬚', '.kd-tool'); await drag([[cx - 150, cy - 100], [cx + 50, cy], [cx + 150, cy + 100]]);
  console.log('[pt] sel', await L.q('.kapp-status'));
  await L.btn('Crop', '.kd-opts .kapp-btn'); await wait(400);
  console.log('[pt] cropped', await L.q('.kapp-status'));
  await L.btn('↶', '.kapp-btn'); await wait(400);
  console.log('[pt] undo crop', await L.q('.kapp-status'));
  // filter + flip
  await js(`(()=>{const s=${L.T}.querySelectorAll('.kapp-bar select')[1];s.value='Sepia';s.dispatchEvent(new Event('change'))})()`); await wait(300);
  await js(`(()=>{const s=${L.T}.querySelectorAll('.kapp-bar select')[0];s.value='Flip horizontal';s.dispatchEvent(new Event('change'))})()`); await wait(400);
  // fill bucket on the background sky
  await L.btn('Background', '.kd-layname'); await wait(100);
  await L.btn('🪣', '.kd-tool'); await L.btn('', '.kd-pal .kd-swatch', 9);
  mouse('mouseDown', cx - 50, cy - 140); mouse('mouseUp', cx - 50, cy - 140); await wait(300);
  await shot(O + 'paint-2-edits.png');
  await L.btn('Export PNG', '.kapp-btn'); await wait(800);
  await L.btn('Save', '.kapp-btn'); await wait(800);
  console.log('[pt] saved', require('fs').readdirSync(process.env.KOMPASS_SAVE_DIR).filter(f => /png|kpaint/.test(f)).join(','), '| err', await L.errors());
  await L.btn('New', '.kapp-btn'); await wait(300); await shot(O + 'paint-3-new.png');
  await wait(4500); console.log('[pt] autosave', await L.q('.kapp-status'));
};
