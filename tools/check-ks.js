#!/usr/bin/env node
// Parse-check KampfScript files (syntax only): node tools/check-ks.js file.ks ...
const K = require('../src/lang.js'); const fs = require('fs'); let bad = 0;
for (const f of process.argv.slice(2)) { try { K.parse(fs.readFileSync(f, 'utf8')); console.log('ok  ' + f); } catch (e) { bad++; console.log('ERR ' + f + ': ' + e.message); } }
process.exit(bad ? 1 : 0);
