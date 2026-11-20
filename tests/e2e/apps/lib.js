module.exports = (h) => {
  const { js, wait, click } = h;
  const T = `document.querySelector('.ks-tabview:not([hidden])')`;
  const L = {};
  L.T = T;
  L.pos = (sel, text, nth, exact) => js(`(()=>{const l=[...${T}.querySelectorAll(${JSON.stringify(sel)})].filter(b=>b.offsetParent&&!b.disabled&&(${JSON.stringify(text)}===null||(${!!exact}?b.textContent.trim()===${JSON.stringify(text)}:b.textContent.trim().startsWith(${JSON.stringify(text)}))));const b=l[${nth || 0}];if(!b)return null;let r=b.getBoundingClientRect();if(r.bottom>innerHeight-24||r.top<0){b.scrollIntoView({block:'nearest'});r=b.getBoundingClientRect();}return {x:r.left+r.width/2,y:r.top+r.height/2,w:r.width,h:r.height,l:r.left,t:r.top}})()`);
  L.btn = async (text, sel, nth, exact) => { const r = await L.pos(sel || 'button', text, nth, exact); if (!r) throw new Error('no element ' + (sel || 'button') + ' ' + text); await click(r.x, r.y); await wait(150); return r; };
  L.q = (sel) => js(`(()=>{const e=${T}.querySelector(${JSON.stringify(sel)});return e?e.innerText.replace(/\\n+/g,' | '):null})()`);
  L.count = (sel) => js(`${T}.querySelectorAll(${JSON.stringify(sel)}).length`);
  L.type = async (sel, text, nth) => { const r = await L.pos(sel, null, nth); if (!r) throw new Error('no field ' + sel); await click(r.l + 12, r.y); await wait(60); await js(`document.execCommand('insertText',false,${JSON.stringify(text)})`); await wait(120); };
  L.selectAll = () => js(`document.execCommand('selectAll')`);
  L.check = async (text) => { const r = await js(`(()=>{const l=[...${T}.querySelectorAll('input[type=checkbox]')].filter(e=>e.parentElement.textContent.trim().startsWith(${JSON.stringify(text)}));const e=l[0];if(!e)return null;e.scrollIntoView({block:'nearest'});const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`); if (!r) throw new Error('no check ' + text); await click(r.x, r.y); await wait(120); };
  L.errors = () => js(`[...document.querySelectorAll('.custom-error,.ks-error,.ks-err')].map(e=>e.innerText).join(';')`);
  return L;
};
