module.exports = async (h) => {
  const { wait, go, shot, js } = h; const L = require('./lib.js')(h);
  await go('kompass://store/kugel-lattice'); await wait(3000);
  await L.btn('Open', 'button'); await wait(2500);
  console.log('[imp] tabs', await L.q('.kl-tabs'), '| name', await js(`${L.T}.querySelector('.kl-name').value`), '| status', await L.q('.kw-status'), '| err', await L.errors());
  await shot('shots/lattice-5-import.png');
};