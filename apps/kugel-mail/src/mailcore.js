// Kugel Mail core: IMAP (imapflow) + SMTP (nodemailer) + parsing (mailparser) + HTML cleaning (sanitize-html).
// Runs only in the Electron main process; the window never sees passwords or raw sockets.
'use strict';
const { ImapFlow } = require('imapflow');
const nodemailer = require('nodemailer');
const { simpleParser } = require('mailparser');
const sanitizeHtml = require('sanitize-html');

const PRESETS = {
  gmail: { label: 'Gmail', imap: { host: 'imap.gmail.com', port: 993, security: 'tls' }, smtp: { host: 'smtp.gmail.com', port: 465, security: 'tls' },
    note: 'Gmail needs an App Password (not your normal password): turn on 2-Step Verification, then open myaccount.google.com/apppasswords, create one called "Kugel Mail" and paste the 16 letters here.' },
  outlook: { label: 'Outlook / Hotmail', imap: { host: 'outlook.office365.com', port: 993, security: 'tls' }, smtp: { host: 'smtp-mail.outlook.com', port: 587, security: 'starttls' },
    note: 'Microsoft has switched personal Outlook.com / Hotmail accounts to "modern" (OAuth) sign-in, which Kugel Mail 1.0 does not have yet, so a password may be refused. Work or school accounts work only if the admin allows IMAP with passwords.' },
  yahoo: { label: 'Yahoo', imap: { host: 'imap.mail.yahoo.com', port: 993, security: 'tls' }, smtp: { host: 'smtp.mail.yahoo.com', port: 465, security: 'tls' },
    note: 'Yahoo needs an app password: Yahoo Account Security → "Generate app password", then paste it here.' },
  custom: { label: 'Other', imap: { host: '', port: 993, security: 'tls' }, smtp: { host: '', port: 465, security: 'tls' }, note: 'Enter the IMAP and SMTP servers from your mail provider.' },
};
const LOCAL = /^(localhost|127\.0\.0\.1|::1)$/i;

const userErr = (m) => Object.assign(new Error(m), { plain: true });
function checkServer(s, what) {
  if (!s || !s.host || !/^[a-z0-9.-]+$/i.test(s.host)) throw userErr(what + ' server name is missing or invalid');
  const port = +s.port; if (!(port > 0 && port < 65536)) throw userErr(what + ' port is invalid');
  if (!['tls', 'starttls', 'none'].includes(s.security)) throw userErr(what + ' security must be SSL/TLS or STARTTLS');
  if (s.security === 'none' && !LOCAL.test(s.host)) throw userErr(what + ': unencrypted connections are only allowed to this computer (localhost) — your password would travel in plain text');
}
function imapOptions(acc) {
  const s = acc.imap; checkServer(s, 'IMAP');
  return { host: s.host, port: +s.port, secure: s.security === 'tls', doSTARTTLS: s.security === 'starttls' ? true : s.security === 'none' ? false : undefined,
    auth: { user: acc.user || acc.email, pass: acc.pass }, logger: false, emitLogs: false, connectionTimeout: 20000, greetingTimeout: 15000, socketTimeout: 120000,
    tls: { rejectUnauthorized: true } };
}
function smtpOptions(acc) {
  const s = acc.smtp; checkServer(s, 'SMTP');
  return { host: s.host, port: +s.port, secure: s.security === 'tls', requireTLS: s.security === 'starttls', ignoreTLS: s.security === 'none',
    auth: { user: acc.user || acc.email, pass: acc.pass }, connectionTimeout: 20000, greetingTimeout: 15000, socketTimeout: 60000, tls: { rejectUnauthorized: true } };
}
const friendly = (e) => {
  if (e && e.plain) return e.message;
  const m = String((e && (e.responseText || e.response || e.message)) || e);
  if (e && (e.authenticationFailed || /auth|credentials|login|535|534|password/i.test(m))) return 'The server refused the email / password. ' + (/gmail/i.test(m) ? 'Gmail needs an App Password.' : 'Check them (and use an app password if your provider needs one).');
  if (/ENOTFOUND|EAI_AGAIN/.test(m)) return 'Could not find that server — check the server name and your internet connection.';
  if (/ECONNREFUSED|ETIMEDOUT|timeout/i.test(m)) return 'Could not connect to the server (port / security setting, or a firewall).';
  if (/certificate|self.signed|CERT_/i.test(m)) return 'The server certificate is not trusted, so Kugel Mail did not send your password.';
  return m.slice(0, 300);
};

class MailAccount {
  constructor(cfg) { this.cfg = cfg; this.client = null; this.busy = Promise.resolve(); this.parsed = new Map(); }
  async imap() {
    if (this.client && this.client.usable) return this.client;
    if (this.client) { try { this.client.close(); } catch (e) {} }
    const c = new ImapFlow(imapOptions(this.cfg)); c.on('error', () => {});
    await c.connect(); this.client = c; return c;
  }
  // one IMAP command sequence at a time per account
  run(fn) { const p = this.busy.then(() => fn(), () => fn()); this.busy = p.catch(() => {}); return p; }
  async close() { if (this.client) { try { await this.client.logout(); } catch (e) {} this.client = null; } }

  folders() {
    return this.run(async () => {
      const c = await this.imap();
      const list = await c.list({ statusQuery: { messages: true, unseen: true } });
      const order = { '\\Inbox': 0, '\\Drafts': 2, '\\Sent': 3, '\\Junk': 4, '\\Trash': 5, '\\Archive': 6 };
      return list.filter((f) => !(f.flags && f.flags.has('\\Noselect'))).map((f) => ({ path: f.path, name: f.path.toUpperCase() === 'INBOX' ? 'Inbox' : f.name, special: f.specialUse || (f.path.toUpperCase() === 'INBOX' ? '\\Inbox' : ''),
        total: f.status ? f.status.messages : 0, unseen: f.status ? f.status.unseen : 0 }))
        .sort((a, b) => (order[a.special] ?? 9) - (order[b.special] ?? 9) || a.name.localeCompare(b.name));
    });
  }
  static summary(m) {
    const e = m.envelope || {}; const f = (e.from && e.from[0]) || {};
    let att = false; const walk = (n) => { if (!n) return; if (n.disposition === 'attachment') att = true; (n.childNodes || []).forEach(walk); }; walk(m.bodyStructure);
    return { uid: m.uid, from: f.name || f.address || '(unknown)', fromAddr: f.address || '', subject: e.subject || '(no subject)', date: e.date ? new Date(e.date).toISOString() : '',
      seen: m.flags ? m.flags.has('\\Seen') : false, flagged: m.flags ? m.flags.has('\\Flagged') : false, attachments: att, size: m.size || 0 };
  }
  messages(folder, page, pageSize) {
    page = Math.max(0, page | 0); pageSize = Math.min(200, Math.max(10, pageSize | 0 || 50));
    return this.run(async () => {
      const c = await this.imap(); const lock = await c.getMailboxLock(folder);
      try {
        const total = c.mailbox.exists; const hi = total - page * pageSize; if (hi < 1) return { total, items: [] };
        const lo = Math.max(1, hi - pageSize + 1); const items = [];
        for await (const m of c.fetch(lo + ':' + hi, { uid: true, envelope: true, flags: true, bodyStructure: true, size: true })) items.push(MailAccount.summary(m));
        items.sort((a, b) => b.uid - a.uid); return { total, items };
      } finally { lock.release(); }
    });
  }
  search(folder, q) {
    q = String(q || '').slice(0, 200); if (!q.trim()) return this.messages(folder, 0, 50);
    return this.run(async () => {
      const c = await this.imap(); const lock = await c.getMailboxLock(folder);
      try {
        let uids = null; const parts = [{ subject: q }, { from: q }, { to: q }, { body: q }];
        try { uids = await c.search({ or: parts }, { uid: true }); } catch (e) { uids = null; }
        if (!Array.isArray(uids)) { // some servers choke on OR with quoted text: ask one field at a time
          const all = new Set(); for (const p of parts) { try { ((await c.search(p, { uid: true })) || []).forEach((u) => all.add(u)); } catch (e) {} } uids = [...all];
        }
        const pick = uids.sort((a, b) => b - a).slice(0, 100); const items = [];
        if (pick.length) for await (const m of c.fetch(pick.join(','), { uid: true, envelope: true, flags: true, bodyStructure: true, size: true }, { uid: true })) items.push(MailAccount.summary(m));
        items.sort((a, b) => b.uid - a.uid); return { total: uids.length, items };
      } finally { lock.release(); }
    });
  }
  open(folder, uid, opts) {
    opts = opts || {};
    return this.run(async () => {
      const c = await this.imap(); const lock = await c.getMailboxLock(folder);
      let p;
      try {
        const m = await c.fetchOne(String(uid), { source: true, flags: true }, { uid: true });
        if (!m) throw new Error('That message is gone');
        p = await simpleParser(m.source);
        if (!(m.flags && m.flags.has('\\Seen'))) await c.messageFlagsAdd(String(uid), ['\\Seen'], { uid: true });
      } finally { lock.release(); }
      this.parsed.set(folder + '#' + uid, p); if (this.parsed.size > 30) this.parsed.delete(this.parsed.keys().next().value);
      return MailAccount.view(p, opts.remote);
    });
  }
  static view(p, remote) {
    const cid = {}; (p.attachments || []).forEach((a) => { if (a.cid && /^image\//.test(a.contentType)) cid[a.cid] = 'data:' + a.contentType + ';base64,' + a.content.toString('base64'); });
    const addr = (x) => (x && x.value ? x.value.map((v) => (v.name ? v.name + ' <' + v.address + '>' : v.address)).join(', ') : '');
    const clean = p.html ? cleanHtml(p.html, { remote: !!remote, cid }) : null;
    return { subject: p.subject || '(no subject)', from: addr(p.from), fromAddr: p.from && p.from.value[0] ? p.from.value[0].address : '', to: addr(p.to), cc: addr(p.cc),
      replyTo: addr(p.replyTo), date: p.date ? p.date.toISOString() : '', messageId: p.messageId || '', references: [].concat(p.references || []),
      text: p.text || '', html: clean ? clean.html : null, blocked: clean ? clean.blocked : 0,
      attachments: (p.attachments || []).map((a, i) => ({ i, filename: a.filename || 'attachment-' + (i + 1), type: a.contentType, size: a.size, inline: !!(a.cid && a.related) })).filter((a) => !a.inline) };
  }
  attachment(folder, uid, i) { const p = this.parsed.get(folder + '#' + uid); const a = p && p.attachments && p.attachments[i]; if (!a) throw new Error('Open the message again'); return { filename: a.filename || 'attachment', content: a.content }; }
  flag(folder, uid, flag, on) {
    if (!['\\Seen', '\\Flagged'].includes(flag)) throw new Error('bad flag');
    return this.run(async () => { const c = await this.imap(); const lock = await c.getMailboxLock(folder); try { if (on) await c.messageFlagsAdd(String(uid), [flag], { uid: true }); else await c.messageFlagsRemove(String(uid), [flag], { uid: true }); } finally { lock.release(); } return true; });
  }
  remove(folder, uid) {
    return this.run(async () => {
      const c = await this.imap(); const list = await c.list(); const trash = list.find((f) => f.specialUse === '\\Trash') || list.find((f) => /^(trash|deleted items|bin)$/i.test(f.name));
      const lock = await c.getMailboxLock(folder);
      try {
        if (trash && trash.path !== folder) await c.messageMove(String(uid), trash.path, { uid: true });
        else await c.messageDelete(String(uid), { uid: true });
      } finally { lock.release(); }
      return true;
    });
  }
  async send(msg) {
    const t = nodemailer.createTransport(smtpOptions(this.cfg));
    const mail = { from: this.cfg.name ? { name: this.cfg.name, address: this.cfg.email } : this.cfg.email, to: msg.to, cc: msg.cc || undefined, subject: msg.subject || '', text: msg.text || '',
      inReplyTo: msg.inReplyTo || undefined, references: msg.references && msg.references.length ? msg.references : undefined,
      attachments: (msg.attachments || []).map((a) => (a.path ? { path: a.path, filename: a.filename } : { filename: a.filename, content: a.content })) };
    const info = await t.sendMail(mail); t.close();
    // most servers (not Gmail) do not keep a copy: put one in Sent
    if (!/gmail\.com$/i.test(this.cfg.imap.host)) {
      try {
        const raw = await new Promise((res, rej) => { const mc = new (require('nodemailer/lib/mail-composer'))(Object.assign({}, mail, { messageId: info.messageId })); mc.compile().build((e, b) => (e ? rej(e) : res(b))); });
        await this.run(async () => { const c = await this.imap(); const sent = (await c.list()).find((f) => f.specialUse === '\\Sent'); if (sent) await c.append(sent.path, raw, ['\\Seen']); });
      } catch (e) {}
    }
    return { ok: true, id: info.messageId, accepted: info.accepted };
  }
}
async function testAccount(cfg) {
  const out = { imap: false, smtp: false }; checkServer(cfg.imap, 'IMAP'); checkServer(cfg.smtp, 'SMTP');
  const c = new ImapFlow(imapOptions(cfg)); c.on('error', () => {});
  try { await c.connect(); out.imap = true; await c.logout(); } catch (e) { throw new Error('IMAP (receiving): ' + friendly(e)); }
  const t = nodemailer.createTransport(smtpOptions(cfg));
  try { await t.verify(); out.smtp = true; } catch (e) { throw new Error('SMTP (sending): ' + friendly(e)); } finally { t.close(); }
  return out;
}

// ---- HTML cleaning: no scripts, no forms, no event handlers; remote images only when asked; links open in the real browser
function cleanHtml(html, o) {
  let blocked = 0;
  const out = sanitizeHtml(html, {
    allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img', 'style', 'center', 'font', 'span', 'div', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'colgroup', 'col', 'hr', 'br', 'u', 's', 'small', 'big', 'sup', 'sub']),
    disallowedTagsMode: 'discard',
    allowedAttributes: { '*': ['style', 'align', 'valign', 'width', 'height', 'bgcolor', 'color', 'border', 'cellpadding', 'cellspacing', 'dir', 'class', 'title', 'colspan', 'rowspan', 'face', 'size'],
      a: ['href', 'name', 'target', 'rel'], img: ['src', 'alt', 'data-remote-src'] },
    allowedSchemes: ['http', 'https', 'mailto', 'data', 'cid'], allowedSchemesByTag: { img: ['http', 'https', 'data', 'cid'] },
    allowVulnerableTags: true,   // <style> is kept (newsletters need it); the viewer is a sandboxed frame without scripts and with a strict CSP
    transformTags: {
      a: (tag, at) => ({ tagName: 'a', attribs: Object.assign({}, at, { target: '_blank', rel: 'noopener noreferrer' }) }),
      img: (tag, at) => {
        const src = at.src || '';
        if (/^cid:/i.test(src)) { const d = o.cid[src.slice(4).replace(/^<|>$/g, '')]; return { tagName: 'img', attribs: { src: d || '', alt: at.alt || '' } }; }
        if (/^https?:/i.test(src) && !o.remote) { blocked++; return { tagName: 'img', attribs: { alt: at.alt ? '[' + at.alt + ']' : '', 'data-remote-src': src } }; }
        return { tagName: 'img', attribs: { src, alt: at.alt || '' } };
      },
    },
  });
  // remote CSS images (background:url(http...)) are stopped by the viewer's CSP unless remote images are allowed
  return { html: out, blocked };
}
module.exports = { PRESETS, MailAccount, testAccount, cleanHtml, friendly, checkServer };
