module.exports = (h) => {
  const { js, wait, click } = h;
  const T = `document.querySelector('.ks-tabview:not([hidden])')`;
  h.rectOf = (sel) => js(`(()=>{const e=${T}.querySelector(${JSON.stringify(sel)});if(!e)return null;const r=e.getBoundingClientRect();return {x:r.left,y:r.top,w:r.width,h:r.height}})()`);
  h.btn = async (text, nth) => { const r = await js(`(()=>{const l=[...document.querySelectorAll('.ks-popup button'),...${T}.querySelectorAll('button,.kapp-item,.ks-link')].filter(b=>b.offsetParent&&b.textContent.trim().startsWith(${JSON.stringify(text)}));const b=l[${nth || 0}];if(!b)return null;const r=b.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`); if (!r) throw new Error('no button ' + text); await click(r.x, r.y); await wait(250); };
  h.text = (sel) => js(`(${T}.querySelector(${JSON.stringify(sel)})||{innerText:''}).innerText`);
  h.errors = () => js(`[...document.querySelectorAll('.custom-error')].map(e=>e.innerText).join(';')`);
  return h;
};
