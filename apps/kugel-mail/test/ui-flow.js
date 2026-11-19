const assert = require('assert');
module.exports = async (h) => {
  const { js, wait, shot, click } = h;
  const rect = (sel) => js(`(()=>{const e=document.querySelector(${JSON.stringify(sel)});if(!e||!e.offsetParent)return null;const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2}})()`);
  const tap = async (sel) => { const r = await rect(sel); if (!r) throw new Error('not visible: ' + sel); await click(r.x, r.y); };
  const set = (sel, v) => js(`(()=>{const e=document.querySelector(${JSON.stringify(sel)});e.value=${JSON.stringify(v)};e.dispatchEvent(new Event('input'));e.dispatchEvent(new Event('change'))})()`);
  const txt = (sel) => js(`(document.querySelector(${JSON.stringify(sel)})||{innerText:''}).innerText`);
  const until = async (fn, what, ms) => { for (let i = 0; i < (ms || 15000) / 200; i++) { if (await fn()) return; await wait(200); } throw new Error('timeout: ' + what); };
  h.win.setSize(1200, 780); await wait(300);
  // 1. setup screen
  assert(!(await js(`document.getElementById('setup').hidden`)));
  await tap('#presets button[data-k=gmail]'); assert((await txt('#preset-note')).includes('App Password'));
  await shot('mail-1-setup-gmail.png');
  await tap('#presets button[data-k=custom]');
  await set('#s-name', 'Kampf'); await set('#s-email', 'kampf@test.local'); await set('#s-user', 'kampf');
  await set('#s-ihost', '127.0.0.1'); await set('#s-iport', '3143'); await set('#s-isec', 'none');
  await set('#s-shost', '127.0.0.1'); await set('#s-sport', '3025'); await set('#s-ssec', 'none');
  await set('#s-pass', 'wrong-password'); await tap('#s-save');
  await until(async () => (await txt('#setup-err')).length > 0, 'error'); const err = await txt('#setup-err'); console.log('[t] wrong pw ->', err); assert(/refused/.test(err));
  await set('#s-ihost', 'imap.example.com'); await tap('#s-save'); await until(async () => /plain text/.test(await txt('#setup-err')), 'plain err'); console.log('[t] remote plain ->', await txt('#setup-err'));
  await set('#s-ihost', '127.0.0.1'); await set('#s-pass', 'secret123'); await tap('#s-save');
  await until(() => js(`!document.getElementById('main').hidden && document.querySelectorAll('.msg').length>=4`), 'inbox');
  const fs = require('fs'); const stored = fs.readFileSync(h.dataDir + '/accounts.json', 'utf8'); assert(!stored.includes('secret123') && /"pass": "/.test(stored)); console.log('[t] password stored encrypted, not plain');
  const folders = await txt('#folders'); console.log('[t] folders:', folders.replace(/\n/g, ' | ')); assert(/Inbox/.test(folders) && /4/.test(folders));
  await shot('mail-2-inbox.png');
  // 2. open newsletter (remote images + script)
  await js(`[...document.querySelectorAll('.msg')].find(m=>m.innerText.includes('50% off')).click()`);
  await until(() => js(`!document.getElementById('r-blocked').hidden`), 'blocked banner');
  const doc = await js(`document.getElementById('r-frame').srcdoc`);
  assert(!/<script|onmouseover|<form|<input/i.test(doc) && !/ src="https:\/\/(tracker|cdn)/.test(doc)); console.log('[t] blocked =', await txt('#r-blocked-n'));
  assert.strictEqual(await txt('#r-blocked-n'), '2');
  await shot('mail-3-newsletter-blocked.png');
  await tap('#r-load'); await until(() => js(`/ src="https:\\/\\/cdn/.test(document.getElementById('r-frame').srcdoc)`), 'remote allowed');
  // 3. coach email: cid image + attachment save
  await js(`[...document.querySelectorAll('.msg')].find(m=>m.innerText.includes('Team photo')).click()`);
  await until(() => js(`document.querySelectorAll('#r-att .att').length===1`), 'attachments');
  assert(/data:image\/png/.test(await js(`document.getElementById('r-frame').srcdoc`)));
  await tap('#r-att .att'); await until(() => fs.existsSync('/tmp/kmail/save/schedule.csv'), 'saved'); assert(fs.readFileSync('/tmp/kmail/save/schedule.csv', 'utf8').includes('Mon,4pm'));
  console.log('[t] attachment saved'); await shot('mail-4-attachment.png');
  // 4. reply all with attachment
  await tap('#r-all'); assert(!(await js(`document.getElementById('composer').hidden`)));
  assert.strictEqual(await js(`document.getElementById('c-subject').value`), 'Re: Team photo + schedule');
  assert(/lee@school/.test(await js(`document.getElementById('c-to').value`)) && /friend@test.local/.test(await js(`document.getElementById('c-cc').value`)));
  await js(`(()=>{const t=document.getElementById('c-text');t.value='Thanks coach! Homework attached.'+t.value})()`);
  await tap('#c-attach'); await until(() => js(`document.querySelectorAll('#c-files .chip').length===1`), 'chip');
  await shot('mail-5-compose-reply.png');
  await tap('#c-send'); await until(() => js(`document.getElementById('composer').hidden`), 'sent'); console.log('[t] reply-all sent');
  // 5. forward with original attachment
  await tap('#r-fwd'); assert.strictEqual(await js(`document.querySelectorAll('#c-files .chip').length`), 1);
  await set('#c-to', 'friend@test.local'); await tap('#c-send'); await until(() => js(`document.getElementById('composer').hidden`), 'fwd sent'); console.log('[t] forward sent');
  // 6. compose new, to self
  await tap('#compose'); await set('#c-to', 'kampf@test.local'); await set('#c-subject', 'Note to self'); await set('#c-text', 'Buy milk'); await tap('#c-send');
  await until(() => js(`document.getElementById('composer').hidden`), 'self sent');
  await wait(800); await tap('#refresh'); await until(() => js(`[...document.querySelectorAll('.msg')].some(m=>m.innerText.includes('Note to self'))`), 'self arrived'); console.log('[t] new mail arrived');
  // 7. search
  await set('#search', 'Grandma'); await until(() => js(`document.querySelectorAll('.msg').length===1`), 'search', 8000); console.log('[t] search ok');
  await shot('mail-6-search.png'); await set('#search', ''); await until(() => js(`document.querySelectorAll('.msg').length===5`), 'unsearch');
  // 8. delete
  await js(`[...document.querySelectorAll('.msg')].find(m=>m.innerText.includes('50% off')).click()`); await wait(800);
  await tap('#r-del'); await until(() => js(`document.querySelectorAll('.msg').length===4`), 'deleted'); console.log('[t] deleted');
  await tap('#b-help'); await shot('mail-7-help.png'); await tap('#h-close');
  assert.strictEqual(h.errs.length, 0);
};
