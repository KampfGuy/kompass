module.exports = async (h) => {
  const { wait, go, shot, js } = h; const L = require('./lib.js')(h); const O = 'shots/';
  await go('kompass://store/kugel-notes'); await wait(2500);
  console.log('[notes] errors', await L.errors(), '| list', await L.q('.kw-list'));
  await shot(O + 'notes-1-welcome.png');
  await L.check(''); // first checklist box
  console.log('[notes] checked count', await js(`${L.T}.querySelectorAll('.kw-preview input:checked').length`), 'body has [x] Make', await js(`${L.T}.querySelector('.kw-body').value.includes('- [x] Make a folder')`));
  await L.btn('+ Folder'); await L.type('.kw-dialog .ks-textbox', 'Recipes'); await L.btn('Create', '.kw-dialog button'); await wait(300);
  console.log('[notes] nav', await L.q('.kw-nav'));
  console.log('[notes] at', await js(`(()=>{const e=document.elementFromPoint(993,145);return e.className+' '+e.textContent.slice(0,40)})()`), await js(`innerWidth`));
  const nb = await L.btn('+ New note'); await wait(300);
  console.log('[notes] after new', JSON.stringify(nb), await L.errors(), await L.q('.kw-list'), await js(`[...document.querySelectorAll('[class*=err]')].map(e=>e.className+':'+e.innerText.slice(0,200)).join(' ## ')`));
  await L.type('.kw-ntitlebox', 'Pancakes');
  await L.type('.kw-body', 'Mix ');
  await L.btn('B', '.kw-tool', 0, true);
  await js(`document.execCommand('insertText',false,'flour')`);
  await js(`(()=>{const e=${L.T}.querySelector('.kw-body');e.selectionStart=e.selectionEnd=e.value.length})()`);
  await L.btn('☑', '.kw-tool'); await js(`document.execCommand('insertText',false,'eggs')`);
  await L.btn('☑', '.kw-tool'); await js(`document.execCommand('insertText',false,'milk')`);
  await wait(800);
  console.log('[notes] body', JSON.stringify(await js(`${L.T}.querySelector('.kw-body').value`)), '| preview', await L.q('.kw-preview'));
  console.log('[notes] list', await L.q('.kw-list'));
  await shot(O + 'notes-2-recipe.png');
  await L.type('.kw-search', 'welcome'); await wait(500);
  console.log('[notes] search', await L.q('.kw-list'));
  await L.btn('Preview', '.kw-tool'); await wait(300);
  await shot(O + 'notes-3-preview.png');
};
