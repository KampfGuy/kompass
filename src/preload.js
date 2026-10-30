// Narrow, safe bridge between the KampfScript runtime (renderer) and the main process.
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('native', {
  browserSource: () => ipcRenderer.sendSync('kompass:browser-source'),
  defaultSource: () => ipcRenderer.sendSync('kompass:default-source'),
  saveBrowserSource: (s) => ipcRenderer.sendSync('kompass:save-browser-source', s),
  paths: () => ipcRenderer.sendSync('kompass:paths'),
  load: (n) => ipcRenderer.sendSync('kompass:load', n),
  save: (n, j) => ipcRenderer.sendSync('kompass:save', n, j),
  listScripts: () => ipcRenderer.sendSync('kompass:list-scripts'),
  readScript: (n) => ipcRenderer.sendSync('kompass:read-script', n),
  writeScript: (n, s) => ipcRenderer.sendSync('kompass:write-script', n, s),
  adblock: (on) => ipcRenderer.sendSync('kompass:adblock', on === undefined ? null : on),
  openExternal: (u) => ipcRenderer.send('kompass:open-external', u),
  openFolder: () => ipcRenderer.send('kompass:open-folder'),
  reloadApp: () => ipcRenderer.send('kompass:reload-app'),
  devtools: () => ipcRenderer.send('kompass:devtools'),
  capture: (f) => ipcRenderer.invoke('kompass:capture', f),
  argv: () => ipcRenderer.sendSync('kompass:argv'),
  quit: () => ipcRenderer.send('kompass:quit'),
  onOpenTab: (f) => ipcRenderer.on('kompass:open-tab', (_e, u) => f(u)),
  onKey: (f) => ipcRenderer.on('kompass:key', (_e, k) => f(k)),
});
