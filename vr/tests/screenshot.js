#!/usr/bin/env node
/* Headless preview of the Kompass VR UI at a Quest 2D-panel size (1280x800 CSS px, 1.5x pixels).
 *   NODE_PATH=<dir with puppeteer-core> node vr/tests/screenshot.js <url of www/index.html> <outDir>
 * Uses the shim's web fallback (no Android bridge): localStorage data, iframe pages. Fails on boot errors. */
'use strict';
const puppeteer = require('puppeteer-core');
const path = require('path');
(async () => {
  const url = process.argv[2] || 'http://127.0.0.1:18977/www/index.html';
  const out = process.argv[3] || '/workspace/kompass-vr-dist';
  const browser = await puppeteer.launch({ executablePath: process.env.CHROME || '/opt/google/chrome/chrome', headless: true,
    args: ['--no-sandbox', '--disable-gpu', '--disable-extensions', '--hide-scrollbars'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1.5 });
  const errors = [];
  page.on('console', (m) => { const t = m.text(); console.log('[console] ' + t); if (m.type() === 'error' && !/favicon|ERR_|Failed to load resource/.test(t)) errors.push(t); });
  page.on('pageerror', (e) => { console.log('[pageerror] ' + e.message); errors.push(e.message); });
  await page.goto(url, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 2500));
  const boot = await page.$eval('#boot-error', (e) => e.hidden ? '' : e.textContent);
  if (boot) errors.push(boot);
  await page.screenshot({ path: path.join(out, 'screenshot.png') });
  // the VR quick menu (☰ button; also opened by holding the trigger / pinch)
  await page.click('.vr-menu'); await new Promise(r => setTimeout(r, 500));
  const menu = await page.$('.ks-popup.quick-menu');
  if (!menu) errors.push('quick menu did not open');
  await page.screenshot({ path: path.join(out, 'screenshot-quickmenu.png') });
  await page.keyboard.press('Escape');
  // long-press (pointer held 0.8 s) on the home page opens the quick menu too
  await page.mouse.move(640, 700); await page.mouse.down(); await new Promise(r => setTimeout(r, 850)); await page.mouse.up();
  await new Promise(r => setTimeout(r, 300));
  if (!(await page.$('.ks-popup.quick-menu'))) errors.push('long-press did not open the quick menu');
  await page.keyboard.press('Escape');
  // Kugel Store page (offline copy is bundled)
  await page.evaluate(() => window.KompassMain.repl('open_page("kompass://store")'));
  await new Promise(r => setTimeout(r, 2500));
  await page.screenshot({ path: path.join(out, 'screenshot-store.png') });
  const sizes = await page.evaluate(() => [...document.querySelectorAll('.toolbar .ks-button, .tabstrip .ks-button')].filter(b => b.getClientRects().length).map(b => { const r = b.getBoundingClientRect(); return [b.textContent.trim().slice(0, 6), Math.round(r.width), Math.round(r.height)]; }));
  console.log('toolbar hit targets (label, w, h):', JSON.stringify(sizes));
  const small = sizes.filter(s => s[2] < 40);
  if (small.length) errors.push('small hit targets: ' + JSON.stringify(small));
  await browser.close();
  if (errors.length) { console.error('FAIL\n' + errors.join('\n')); process.exit(1); }
  console.log('OK: screenshots in ' + out);
})().catch((e) => { console.error(e); process.exit(1); });
