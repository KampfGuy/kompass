module.exports = async (h) => {
  const { js, wait, go, shot, key, click } = h; const O = 'shots/';
  const T = `document.querySelector('.ks-tabview:not([hidden])')`;
  const btn = async (text, nth) => { const r = await js(`(()=>{const l=[...${T}.querySelectorAll('button')].filter(b=>b.offsetParent&&(b.textContent.trim()===${JSON.stringify(text)}||(b.className.includes('navitem')&&b.textContent.trim().endsWith(${JSON.stringify(text)}))));const b=l[${nth || 0}];if(!b)return null;const r=b.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`); if (!r) throw new Error('no button ' + text); await click(r.x, r.y); await wait(120); };
  const disp = () => js(`(()=>{const d=${T}.querySelector('.kcalc-disp');const e=${T}.querySelector('.kcalc-expr');return (e?e.textContent:'')+' | '+(d?d.textContent:'')})()`);
  await go('kompass://store/kugel-arithmetricks'); await wait(2500);
  console.log('[calc] errors', await js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`));
  for (const k of ['7', '+', '8', '×', '2', '=']) await btn(k);
  console.log('[calc] std 7+8×2= ->', await disp());
  await btn('C'); for (const k of ['1', '÷', '0', '=']) await btn(k); console.log('[calc] 1÷0 ->', await disp());
  await btn('C'); for (const k of ['2', '5', '6']) await btn(k); await btn('²√x'); console.log('[calc] sqrt256 ->', await disp());
  await btn('MS'); await btn('C');
  // keyboard: 12*12 Enter
  await js(`document.activeElement&&document.activeElement.blur()`); { const r = await js(`(()=>{const r=${T}.querySelector('.kcalc-disp').getBoundingClientRect();return {x:r.left+20,y:r.top+5}})()`); await click(r.x, r.y); }
  for (const k of ['1', '2']) await key(k); await key('*'); for (const k of ['1', '2']) await key(k); await key('Return');
  console.log('[calc] kb 12*12 ->', await disp());
  await shot(O + 'calc-1-standard.png');
  // scientific
  await btn('☰'); await wait(300); await btn('Scientific'); await wait(500);
  for (const k of ['sin']) await btn(k); for (const k of ['3', '0', ')', '+', '2']) await btn(k); await btn('xʸ'); await btn('1'); await btn('0'); await btn('=');
  console.log('[calc] sci sin(30)+2^10 ->', await disp());
  await btn('C'); await btn('5'); await btn('n!'); await btn('÷'); await btn('('); await btn('2'); await btn('+'); await btn('3'); await btn(')'); await btn('=');
  console.log('[calc] 5!/(2+3) ->', await disp());
  await shot(O + 'calc-2-scientific.png');
  await btn('☰'); await wait(300); await btn('Programmer'); await wait(500);
  await btn('2'); await btn('5'); await btn('5'); await btn('AND'); await btn('1'); await btn('5'); await btn('=');
  console.log('[calc] prog 255 AND 15 ->', await disp(), await js(`[...${T}.querySelectorAll('.kcalc-base')].map(e=>e.textContent).join(' / ')`));
  await shot(O + 'calc-3-programmer.png');
  await btn('☰'); await wait(300); await btn('Temperature'); await wait(500);
  console.log('[calc] temp', await js(`${T}.querySelector('.kcalc-form').innerText.replace(/\\n/g,' | ')`));
  await btn('☰'); await wait(300); await btn('Date calculation'); await wait(500);
  console.log('[calc] date', await js(`${T}.querySelector('.kcalc-form').innerText.replace(/\\n/g,' | ')`));
  await shot(O + 'calc-4-date.png');
  await btn('☰'); await wait(300); await btn('Standard'); await wait(300); await btn('🌙'); await wait(300);
  await shot(O + 'calc-5-dark.png');
  console.log('[calc] history', await js(`[...${T}.querySelectorAll('.kcalc-hitem')].length`)); await btn('Memory');
  await wait(300); console.log('[calc] memtab', await js(`${T}.querySelector('.kcalc-list').innerText.replace(/\\n/g,' ')`));
};
