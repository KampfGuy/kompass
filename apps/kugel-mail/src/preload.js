// Kugel Mail preload: a tiny, fixed API. The window cannot reach Node, files or the network itself.
const { contextBridge, ipcRenderer } = require('electron');
const call = (name) => (...a) => ipcRenderer.invoke(name, ...a);
contextBridge.exposeInMainWorld('mail', Object.fromEntries(['presets', 'accounts', 'account-save', 'account-remove', 'folders', 'messages', 'search', 'open', 'flag', 'delete', 'send', 'pick-files', 'save-attachment', 'open-link'].map((n) => [n.replace(/-(\w)/g, (m, c) => c.toUpperCase()), call(n)])));
