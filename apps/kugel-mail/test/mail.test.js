// Unit tests (no network) + integration tests against a LOCAL GreenMail server (skipped if it is not running).
'use strict';
const assert = require('assert');
const net = require('net');
const { MailAccount, testAccount, cleanHtml, checkServer, PRESETS } = require('../src/mailcore');
let n = 0; const ok = (name) => { n++; console.log('  ok', name); };

(async () => {
  // --- sanitizer
  const r = cleanHtml('<p onclick="x()">Hi<script>alert(1)</script><img src="https://track.example/p.gif"><img src="cid:logo"><a href="javascript:alert(1)">j</a><a href="https://x.org">x</a><form><input></form><iframe src="https://e.vil"></iframe></p>', { remote: false, cid: { logo: 'data:image/png;base64,AA==' } });
  assert(!/script|onclick|javascript:|<form|<input|<iframe/i.test(r.html), r.html);
  assert.strictEqual(r.blocked, 1); assert(!/track\.example\/p\.gif"(?! )/.test(r.html.replace(/data-remote-src="[^"]*"/, ''))); assert(/data:image\/png/.test(r.html));
  assert(/target="_blank"/.test(r.html) && /rel="noopener noreferrer"/.test(r.html)); ok('sanitizer strips scripts/handlers/forms, blocks remote images, inlines cid images');
  const r2 = cleanHtml('<img src="https://ex.org/a.png">', { remote: true, cid: {} }); assert.strictEqual(r2.blocked, 0); assert(/src="https:\/\/ex.org\/a.png"/.test(r2.html)); ok('remote images allowed on request');
  // --- server rules
  assert.throws(() => checkServer({ host: 'imap.example.com', port: 143, security: 'none' }, 'IMAP'), /only allowed/); checkServer({ host: '127.0.0.1', port: 3143, security: 'none' }, 'IMAP');
  assert.throws(() => checkServer({ host: 'bad host;', port: 1, security: 'tls' }, 'IMAP')); ok('plain-text connections only to localhost');
  for (const k of ['gmail', 'outlook', 'yahoo']) assert(PRESETS[k].imap.security === 'tls' && PRESETS[k].note); ok('presets present and encrypted');

  // --- integration with local GreenMail
  const up = await new Promise((res) => { const s = net.connect(3143, '127.0.0.1', () => { s.end(); res(true); }); s.on('error', () => res(false)); });
  if (!up) { console.log('  (GreenMail not running on 127.0.0.1:3143 — integration tests skipped)'); console.log(n + ' passed'); return; }
  const srv = { imap: { host: '127.0.0.1', port: 3143, security: 'none' }, smtp: { host: '127.0.0.1', port: 3025, security: 'none' } };
  const kampf = Object.assign({ email: 'kampf@test.local', user: 'kampf', pass: 'secret123', name: 'Kampf' }, srv);
  const friend = Object.assign({ email: 'friend@test.local', user: 'friend', pass: 'pw456', name: 'Friend' }, srv);
  await assert.rejects(testAccount(Object.assign({}, kampf, { pass: 'wrong' })), /refused/); ok('wrong password gives a friendly error');
  assert.deepStrictEqual(await testAccount(kampf), { imap: true, smtp: true }); ok('account test (IMAP + SMTP)');
  const A = new MailAccount(kampf), B = new MailAccount(friend);
  const tag = 'T' + Date.now();
  await B.send({ to: 'kampf@test.local', subject: 'Hello ' + tag, text: 'Plain body ' + tag, attachments: [{ filename: 'note.txt', content: Buffer.from('attached ' + tag) }] }); ok('send with attachment');
  let list; for (let i = 0; i < 20; i++) { list = await A.messages('INBOX', 0, 50); if (list.items.some((m) => m.subject === 'Hello ' + tag)) break; await new Promise((r) => setTimeout(r, 200)); }
  const m = list.items.find((x) => x.subject === 'Hello ' + tag); assert(m && !m.seen && m.attachments && m.from === 'Friend'); ok('message list (unread, attachment flag, sender)');
  const f1 = await A.folders(); const inbox = f1.find((f) => f.special === '\\Inbox'); assert(inbox && inbox.unseen >= 1); ok('folders with unread counts');
  const v = await A.open('INBOX', m.uid); assert(v.text.includes('Plain body ' + tag) && v.attachments.length === 1 && v.attachments[0].filename === 'note.txt');
  assert.strictEqual(A.attachment('INBOX', m.uid, 0).content.toString(), 'attached ' + tag); ok('open message + attachment bytes');
  const after = (await A.messages('INBOX', 0, 50)).items.find((x) => x.uid === m.uid); assert(after.seen); ok('opening marks as read');
  await A.flag('INBOX', m.uid, '\\Seen', false); assert(!(await A.messages('INBOX', 0, 50)).items.find((x) => x.uid === m.uid).seen); ok('mark unread');
  await B.send({ to: 'kampf@test.local', subject: 'Newsletter ' + tag, text: 'x', html: undefined });
  let s2; for (let i = 0; i < 20; i++) { s2 = await A.search('INBOX', 'Newsletter ' + tag); if (s2.items.length) break; await new Promise((r) => setTimeout(r, 200)); } const s = await A.search('INBOX', tag); assert(s.items.length >= 2); assert.strictEqual(s2.items.length, 1); ok('search');
  await A.send({ to: 'friend@test.local', subject: 'Re: Hello ' + tag, text: 'reply', inReplyTo: v.messageId, references: [v.messageId] });
  let got; for (let i = 0; i < 20 && !got; i++) { got = (await B.messages('INBOX', 0, 50)).items.find((x) => x.subject === 'Re: Hello ' + tag); if (!got) await new Promise((r) => setTimeout(r, 200)); }
  assert(got); const gv = await B.open('INBOX', got.uid); assert.strictEqual(gv.references[0], v.messageId); ok('reply threads (In-Reply-To / References)');
  await A.remove('INBOX', m.uid); assert(!(await A.messages('INBOX', 0, 50)).items.find((x) => x.uid === m.uid)); ok('delete');
  await A.close(); await B.close();
  console.log(n + ' passed');
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
