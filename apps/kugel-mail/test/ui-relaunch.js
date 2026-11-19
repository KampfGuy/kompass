const assert = require('assert');
module.exports = async (h) => { const { js, wait } = h;
  for (let i = 0; i < 50 && !(await js(`!document.getElementById('main').hidden && document.querySelectorAll('.msg').length>0`)); i++) await wait(200);
  assert(await js(`document.getElementById('setup').hidden`)); console.log('[t] relaunch: account remembered, inbox has', await js(`document.querySelectorAll('.msg').length`)); };
