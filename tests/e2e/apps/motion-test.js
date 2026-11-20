module.exports = async (h) => {
  const { wait, go, shot, js, key, mouse } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-motion'); await wait(3500);
  console.log('[mo] errors', await L.errors(), '| status', await L.q('.kapp-status'), '| frames', await L.count('.kd-frame:not(.add)'));
  await shot(O + 'motion-1-sample.png');
  const r = await js(`(()=>{const r=${L.T}.querySelector('.kd-viewwrap canvas').getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height}})()`);
  const drag = async (pts) => { mouse('mouseDown', pts[0][0], pts[0][1]); await wait(40); for (const p of pts.slice(1)) { mouse('mouseMove', p[0], p[1]); await wait(40); } const e = pts[pts.length - 1]; mouse('mouseUp', e[0], e[1]); await wait(250); };
  const cx = r.l + r.w / 2, cy = r.t + r.h / 2;
  // new frame after the last, draw a star-ish line
  await L.btn('⏭', '.kapp-btn'); await L.btn('⧉', '.kapp-btn'); await wait(200);
  console.log('[mo] after dup', await L.q('.kd-frlabel'));
  await L.btn('', '.kd-pal .kd-swatch', 14);
  await drag([[cx - 100, cy - 60], [cx - 50, cy - 90], [cx, cy - 60], [cx + 50, cy - 90], [cx + 100, cy - 60]]);
  await L.btn('▭', '.kd-tool'); await drag([[cx + 60, cy + 20], [cx + 100, cy + 50], [cx + 140, cy + 80]]);
  await shot(O + 'motion-2-onion.png');
  // undo the rect
  await L.btn('↶', '.kapp-btn'); await wait(200);
  // tween from frame 1 → 2 (go to frame 1 first)
  await L.btn('⏮', '.kapp-btn'); await L.btn('Tween', '.kapp-btn'); await wait(200);
  await L.btn('Add frames', '.kd-dialog button'); await wait(400);
  console.log('[mo] after tween', await L.q('.kd-frlabel'));
  // play for a second
  await L.btn('▶ Play', '.kapp-btn'); await wait(1200); console.log('[mo] playing', await L.q('.kd-frlabel')); await shot(O + 'motion-3-playing.png'); await L.btn('⏸', '.kapp-btn');
  // exports
  for (const b of ['Animated GIF (.gif)', 'Sprite sheet', 'Video (.webm)']) { await L.btn('Export…', '.kapp-btn'); await wait(200); await L.btn(b, '.kd-dialog button'); await wait(b.startsWith('Video') ? 4500 : 1500); }
  await L.btn('Save', '.kapp-btn', 0, true); await wait(600);
  console.log('[mo] saved', require('fs').readdirSync(process.env.KOMPASS_SAVE_DIR).map(f => f + ':' + require('fs').statSync(process.env.KOMPASS_SAVE_DIR + '/' + f).size).join(', '), '| err', await L.errors());
};
