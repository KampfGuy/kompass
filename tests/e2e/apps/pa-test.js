module.exports = async (h) => {
  const { js, wait, go, shot, click } = h; const O = 'shots/';
  const T = `document.querySelector('.ks-tabview:not([hidden])')`;
  const find = (sel, text, nth) => js(`(()=>{const l=[...${T}.querySelectorAll(${JSON.stringify(sel)})].filter(b=>b.offsetParent&&!b.disabled&&(${JSON.stringify(sel)}==='.kcalc-k'?b.textContent.trim()===${JSON.stringify(text)}:b.textContent.trim().startsWith(${JSON.stringify(text)})));const b=l[${nth || 0}];if(!b)return null;b.scrollIntoView({block:'nearest'});const r=b.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`);
  const btn = async (text, sel, nth) => { const r = await find(sel || 'button', text, nth); if (!r) throw new Error('no button ' + text); await click(r.x, r.y); await wait(150); };
  const q = (sel) => js(`(()=>{const e=${T}.querySelector(${JSON.stringify(sel)});return e?e.innerText.replace(/\\n+/g,' | '):null})()`);
  const typeIn = async (sel, text, nth) => { const r = await js(`(()=>{const e=[...${T}.querySelectorAll(${JSON.stringify(sel)})].filter(x=>x.offsetParent)[${nth || 0}];const r=e.getBoundingClientRect();return {x:r.left+20,y:r.top+r.height/2}})()`); await click(r.x, r.y); await js(`document.execCommand('insertText',false,${JSON.stringify(text)})`); await wait(100); };
  const check = async (text) => { const r = await js(`(()=>{const l=[...${T}.querySelectorAll('input[type=checkbox]')].filter(e=>e.offsetParent!==null||e.parentElement.offsetParent).filter(e=>e.parentElement.textContent.trim().startsWith(${JSON.stringify(text)}));const e=l[0];if(!e)return null;e.scrollIntoView({block:'nearest'});const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`); if (!r) throw new Error('no check ' + text); await click(r.x, r.y); await wait(100); };
  const disp = async () => (await q('.kcalc-expr')) + ' | ' + (await q('.kcalc-disp')) + ' | ' + (await q('.pa-status')) + ' | offer:' + (await js(`!!${T}.querySelector('.pa-offer:not([hidden])')`));
  await go('kompass://store/arithmetricks-premium'); await wait(2500);
  console.log('[pa] errors', await js(`[...document.querySelectorAll('.custom-error,.ks-error')].map(e=>e.innerText).join(';')`));
  await shot(O + 'pa-0-start.png');
  await btn('7', '.kcalc-k'); await wait(300);
  console.log('[pa] purchase dialog', await q('.pa-dialog'));
  await shot(O + 'pa-1-purchase.png');
  await btn('Open CalcBank'); await wait(300);
  await typeIn('.pa-in', 'Kampf Kaiser'); await check('I agree'); await btn('Submit application'); await wait(400);
  console.log('[pa] card', await q('.pa-ccard'));
  for (const id of ['Store']) await btn(id, '.pa-tab');
  for (const name of ['$9.99', '$19.99', '$4.99']) { await btn(name, '.pa-buy'); await wait(200); }
  console.log('[pa] store status', await q('.pa-storestatus'));
  for (const k of ['7', '+', '8', '=']) await btn(k, '.kcalc-k');
  console.log('[pa] 7+8 wrong =', await disp());
  await btn('Get the correct answer', '.pa-offer'); await wait(200);
  console.log('[pa] premium answer =', await disp());
  await shot(O + 'pa-2-wrong-then-premium-answer.png');
  // buy lots to get into debt
  await js(`${T}.querySelectorAll('.pa-toast').forEach(e=>e.remove())`); await btn('Store', '.pa-tab');
  for (const name of ['$0.99', '$2.99', '$3.49', '$24.99', '$29.99', '$3.99', '$100.00/min', '$6.99', '$1.99/min']) { await js(`${T}.querySelectorAll('.pa-toast').forEach(e=>e.remove())`); const r = await find('.pa-buy', name); if (r) { await click(r.x, r.y); await wait(250); } console.log('[pa] buy', name, !!r, await q('.pa-storestatus')); if (!(await q('.pa-grid'))) await btn('Store', '.pa-tab'); }
  await btn('CalcBank', '.pa-tab'); await wait(300);
  console.log('[pa] bank', (await q('.pa-sum')), '|', await q('.pa-chip'));
  await shot(O + 'pa-3-calcbank.png');
  // premium: correct answers
  await btn('C', '.kcalc-k'); for (const k of ['1', '2', '×', '1', '2', '=']) await btn(k, '.kcalc-k');
  console.log('[pa] premium 12×12 =', await disp(), 'modal', await q('.pa-modal:not([hidden])'), 'el at C', await js(`(()=>{const k=[...${T}.querySelectorAll('.kcalc-k')].find(b=>b.textContent.trim()==='C');const r=k.getBoundingClientRect();const e=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return e.className+' '+e.textContent.slice(0,30)+' '+JSON.stringify(r)})()`)); await shot(O + 'pa-dbg.png');
  // scientific via menu
  await btn('☰', '.kcalc-ham'); await btn('Scientific', '.kcalc-navitem'); await wait(300);
  await btn('C', '.kcalc-k'); await btn('sin', '.kcalc-k'); await btn('0', '.kcalc-k'); await btn(')', '.kcalc-k'); await btn('=', '.kcalc-k');
  console.log('[pa] sci sin(0) =', await disp(), 'mode', await q('.kcalc-title'));
  console.log('[pa] trig modal', await q('.pa-dialog')); await btn('Buy', '.pa-dbuy'); await wait(200);
  await btn('C', '.kcalc-k'); await btn('sin', '.kcalc-k'); await btn('0', '.kcalc-k'); await btn(')', '.kcalc-k'); await btn('=', '.kcalc-k');
  console.log('[pa] sci sin(0) after tokens =', await disp());
  // careers
  await btn('Careers', '.pa-tab'); await wait(300);
  await check('I understand'); await btn('Submit application'); await wait(300);
  console.log('[pa] job home', await q('.pa-card'));
  await btn('Start shift'); await wait(300);
  for (let i = 0; i < 3; i++) { await btn('Push Premium', '.pa-pitch'); await wait(200); const n = await find('button', 'Next customer'); if (n) { await click(n.x, n.y); await wait(200); } else break; }
  await btn('Honest', '.pa-pitch'); await wait(200);
  console.log('[pa] shift', await q('.pa-counter'), '| mgr', await q('.pa-mgr'));
  await shot(O + 'pa-4-shift.png');
  // graphing
  await btn('Graphing', '.pa-tab'); await wait(800);
  await shot(O + 'pa-5-graphing.png');
  // let interest run up into garnishment
  await btn('CalcBank', '.pa-tab');
  for (let i = 0; i < 30; i++) { await wait(3000); const c = await q('.pa-chip'); if (c && /Garnish/.test(c)) break; }
  console.log('[pa] after interest', await q('.pa-sum'), '|', await q('.pa-chip'), '| alert', await q('.pa-alert'));
  console.log('[pa] toasts', await js(`${T}.querySelectorAll('.pa-toast').length`), 'call', await q('.pa-call'));
  console.log('[pa] dbg classes', await js(`(()=>{const r=${T}.querySelector('.pa');return r.className+' | calc bg '+getComputedStyle(${T}.querySelector('.pa-calc')).backgroundColor+' | root bg '+getComputedStyle(r).backgroundColor+' | right '+getComputedStyle(${T}.querySelector('.pa-right')).backgroundColor+' | key '+getComputedStyle(${T}.querySelector('.kcalc-k')).backgroundColor})()`));
  await shot(O + 'pa-6-garnishment.png');
  const f = await find('button', 'File for Chapter 7') || await find('button', 'Explore debt relief');
  await click(f.x, f.y); await wait(400);
  await check('Purchases of calculator'); await typeIn('.pa-sig', 'Kampf Kaiser'); 
  await shot(O + 'pa-7-court.png');
  await js(`${T}.querySelectorAll('.pa-toast,.pa-call').forEach(e=>e.remove())`);
  await btn('Submit petition'); await wait(500);
  console.log('[pa] bankrupt', await q('.pa-dialog'));
  await shot(O + 'pa-8-bankrupt.png');
  await btn('New game'); await wait(400);
  console.log('[pa] new game', await q('.kcalc-expr'), await q('.pa-problem'));
};
