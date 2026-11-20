module.exports = async (h) => {
  const { wait, go, shot, js } = h; const L = require('./lib.js')(h);
  await go('kompass://store/kugel-paint'); await wait(3500);
  await L.btn('Open', '.kapp-btn'); await wait(2500);
  console.log('[po] after open', await L.q('.kapp-status'), '| layers', await L.count('.kd-layer'), '| name', await js(`${L.T}.querySelector('.kd-name').value`), '| err', await L.errors());
  await shot('shots/paint-4-open.png');
};
