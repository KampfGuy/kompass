module.exports = async (h) => {
  const { wait, go, shot, js, key, mouse } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-prism'); await wait(3500);
  console.log('[pr] errors', await L.errors(), '| status', await L.q('.kw-status'), '| thumbs', await L.count('.kp-thumb'));
  await L.btn('2', '.kp-thumb'); await wait(300);
  await shot(O + 'prism-1-editor.png');
  const r = await js(`(()=>{const r=${L.T}.querySelector('.kp-stage canvas').getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height}})()`);
  const z = Math.min((r.w - 30) / 960, (r.h - 30) / 540), x0 = r.l + (r.w - 960 * z) / 2, y0 = r.t + (r.h - 540 * z) / 2;
  const P = (x, y) => [x0 + x * z, y0 + y * z];
  // click the title, edit its text in the panel
  let p = P(200, 80); mouse('mouseDown', ...p); mouse('mouseUp', ...p); await wait(300);
  console.log('[pr] selected', await L.q('.kp-props .kw-h3'));
  await js(`(()=>{const t=${L.T}.querySelector('.kp-text');t.value='Edited title';t.dispatchEvent(new Event('input',{bubbles:true}))})()`); await wait(500);
  // drag the title down a bit
  mouse('mouseDown', ...P(200, 80)); await wait(40); mouse('mouseMove', ...P(220, 100)); await wait(40); mouse('mouseMove', ...P(240, 110)); await wait(40); mouse('mouseUp', ...P(240, 110)); await wait(300);
  console.log('[pr] moved', await L.q('.kp-props .kw-dim:last-child'));
  // add shape, theme change, new slide from layout
  await L.btn('◯', '.kw-tool'); await wait(200);
  await js(`(()=>{const s=[...${L.T}.querySelectorAll('.kp-tools select')][1];s.value='Theme: Ocean';s.dispatchEvent(new Event('change'))})()`); await wait(400);
  await js(`(()=>{const s=[...${L.T}.querySelectorAll('.kp-tools select')][0];s.value='Section header';s.dispatchEvent(new Event('change'))})()`); await wait(400);
  console.log('[pr] after add', await L.q('.kw-status'));
  await js(`(()=>{const t=${L.T}.querySelector('.kp-notes');t.value='My notes';t.dispatchEvent(new Event('input',{bubbles:true}))})()`); await wait(400);
  await shot(O + 'prism-2-theme.png');
  // undo the new slide
  await L.btn('↶', '.kw-tool'); await wait(300); console.log('[pr] undo', await L.q('.kw-status'));
  // present
  await L.btn('▶ Present', '.kw-btn'); await wait(800); await shot(O + 'prism-3-present.png');
  console.log('[pr] present', await L.q('.kp-pcount'));
  await key('Right'); await wait(300); console.log('[pr] present next', await L.q('.kp-pcount'));
  await key('Escape'); await wait(800); console.log('[pr] after esc present?', await L.count('.kp-present'));
  // export pptx + save
  await L.btn('Export', '.kw-btn'); await wait(200); await L.btn('PowerPoint', '.kw-dialog button'); await wait(1500);
  await L.btn('Export', '.kw-btn'); await wait(200); await L.btn('This slide', '.kw-dialog button'); await wait(800);
  await L.btn('Save', '.kw-btn', 0, true); await wait(600);
  console.log('[pr] saved', require('fs').readdirSync(process.env.KOMPASS_SAVE_DIR).join(','), '| err', await L.errors());
  // open pptx
  await L.btn('Open', '.kw-btn'); await wait(2500);
  console.log('[pr] imported', await L.q('.kw-status'), '| thumbs', await L.count('.kp-thumb'), '| err', await L.errors());
  await L.btn('2', '.kp-thumb'); await wait(500);
  await shot(O + 'prism-4-import.png');
};
