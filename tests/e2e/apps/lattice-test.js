module.exports = async (h) => {
  const { wait, go, shot, js, click, key, mouse } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-lattice'); await wait(3000);
  console.log('[lat] errors', await L.errors());
  const cr = await js(`(()=>{const r=${L.T}.querySelector('.kl-grid canvas').getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height}})()`);
  const widths = [130, 96, 96, 96, 96, 96, 96];
  const cell = (c, r) => { let x = cr.l + 46; for (let i = 0; i < c; i++) x += widths[i]; return { x: x + widths[c] / 2, y: cr.t + 24 + r * 24 + 12 }; };
  const clickCell = async (c, r, mods) => { const p = cell(c, r); mouse('mouseDown', p.x, p.y, 'left', mods); mouse('mouseUp', p.x, p.y, 'left', mods); await wait(200); };
  const typeKeys = async (s) => { for (const ch of s) { await key(ch); } };
  await clickCell(4, 1);
  console.log('[lat] canvas', JSON.stringify(cr)); console.log('[lat] E2 raw', await js(`${L.T}.querySelector('.kl-fxin').value`), '| name', await L.q('.kl-namebox'));
  // select E2:E5 with shift-click -> status sum
  await clickCell(4, 4, ['shift']);
  console.log('[lat] status E2:E5', await L.q('.kw-status'));
  await shot(O + 'lattice-1-budget.png');
  // type a formula into F2
  await clickCell(5, 1);
  await typeKeys('=E6*2'); await key('Return'); await wait(400);
  await clickCell(5, 1);
  console.log('[lat] F2 raw', await js(`${L.T}.querySelector('.kl-fxin').value`));
  await clickCell(5, 1); await clickCell(5, 2, ['shift']);
  console.log('[lat] status F2:F3', await L.q('.kw-status'));
  // regression: click a cell and type straight away keeps the first character
  await clickCell(1, 9); await typeKeys('Month'); await key('Return'); await clickCell(1, 9);
  console.log('[lat] REG first-char', JSON.stringify(await js(`${L.T}.querySelector('.kl-fxin').value`)));
  await clickCell(2, 9); await typeKeys('=1+2'); await key('Return'); await clickCell(2, 9);
  console.log('[lat] REG first-char formula', JSON.stringify(await js(`${L.T}.querySelector('.kl-fxin').value`)));
  // text with capital letters + undo
  await clickCell(5, 3); await typeKeys('Hello World'); await key('Return'); await wait(300);
  await clickCell(5, 3); console.log('[lat] F4 raw', await js(`${L.T}.querySelector('.kl-fxin').value`));
  await key('Z', ['control']); await wait(300); await clickCell(5, 3);
  console.log('[lat] F4 after undo', JSON.stringify(await js(`${L.T}.querySelector('.kl-fxin').value`)));
  // functions: VLOOKUP / IF / errors
  await clickCell(5, 5); await typeKeys('=VLOOKUP("Food",A2:E5,5,FALSE)'); await key('Return');
  await typeKeys('=IF(E6>2000,"over","ok")'); await key('Return');
  await typeKeys('=1/0'); await key('Return');
  await clickCell(5, 5); await clickCell(5, 7, ['shift']);
  console.log('[lat] status F6:F8', await L.q('.kw-status'));
  // sort rows 2..5 by column E descending
  await clickCell(4, 1); await clickCell(4, 4, ['shift']);
  await clickCell(0, 1); await clickCell(4, 4, ['shift']);
  // move active to column E: select A2:E5 with active E5
  await L.btn('Z→A', '.kw-tool'); await wait(400);
  await clickCell(0, 1); console.log('[lat] after sort A2 =', await js(`${L.T}.querySelector('.kl-fxin').value`));
  await shot(O + 'lattice-2-formulas.png');
  // chart dialog
  await clickCell(0, 0); await clickCell(1, 4, ['shift']);
  await L.btn('📊 Chart', '.kw-tool'); await wait(300);
  await js(`(()=>{const s=${L.T}.querySelector('.kw-dialog select');s.value='Line chart';s.dispatchEvent(new Event('change'))})()`);
  await L.btn('Insert', '.kw-dialog button'); await wait(800);
  console.log('[lat] charts', await L.count('.kl-chart'));
  await shot(O + 'lattice-3-charts.png');
  // regression: a REAL mouse click on a sheet tab switches sheets
  const tp = await L.pos('.kl-tab', 'Sheet2'); mouse('mouseDown', tp.x, tp.y); await wait(60); mouse('mouseUp', tp.x, tp.y); await wait(400);
  console.log('[lat] REG tab click ->', await L.q('.kl-tab.on'));
  const tb = await L.pos('.kl-tab', 'Budget'); mouse('mouseDown', tb.x, tb.y); await wait(60); mouse('mouseUp', tb.x, tb.y); await wait(400);
  console.log('[lat] REG tab back ->', await L.q('.kl-tab.on'));
  await L.btn('Export', 'button'); await wait(300); await L.btn('Excel workbook (.xlsx) — all sheets', '.kw-dialog button'); await wait(1500);
  await L.btn('Export', 'button'); await wait(300); await L.btn('CSV (.csv) — this sheet', '.kw-dialog button'); await wait(800);
  await L.btn('Save', 'button'); await wait(800);
  console.log('[lat] saved', require('fs').readdirSync(process.env.KOMPASS_SAVE_DIR).join(','), '| err', await L.errors());
  // function list dialog
  await L.btn('ƒ', '.kw-tool'); await wait(400); await shot(O + 'lattice-4-functions.png');
};
