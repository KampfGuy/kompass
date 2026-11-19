#!/usr/bin/env node
/* Headless screenshots of the Kompass VR web bundle (no Android bridge, no WebXR => the desktop VR simulator):
 * the VR-only Kugel Store, each VR game's title screen and a moment of play, the VR lesson, and the Quest Browser
 * hand-off page (index.html#play=<id>).
 *   NODE_PATH=<dir with puppeteer-core> node vr/tests/screenshot-games.js <url of www/index.html> <outDir> */
'use strict';
const puppeteer = require('puppeteer-core');
const path = require('path');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const url = process.argv[2] || 'http://127.0.0.1:18978/index.html';
  const out = process.argv[3] || '/workspace/kompass-vr-dist/vr153';
  const browser = await puppeteer.launch({ executablePath: process.env.CHROME || '/opt/google/chrome/chrome', headless: true,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--disable-extensions', '--hide-scrollbars'] });
  const errors = [];
  const open = async () => {
    const page = await browser.newPage(); await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1.5 });
    page.on('console', (m) => { const t = m.text(); if (m.type() === 'error' && !/favicon|ERR_|Failed to load resource/.test(t)) { errors.push(t); console.log('[console.error] ' + t); } });
    page.on('pageerror', (e) => { console.log('[pageerror] ' + e.message); errors.push(e.message); });
    return page;
  };
  const repl = (page, code) => page.evaluate((c) => window.KompassMain.repl(c), code);
  const clickText = async (page, txt) => {
    for (const f of page.frames()) {
      const ok = await f.evaluate((t) => { const b = [...document.querySelectorAll('button, .ks-button')].find((x) => x.textContent.includes(t) && x.getClientRects().length); if (b) { b.click(); return true; } return false; }, txt).catch(() => false);
      if (ok) return true;
    }
    return false;
  };
  const page = await open();
  await page.goto(url, { waitUntil: 'networkidle0' }); await sleep(2000);
  await repl(page, 'open_page("kompass://store")'); await sleep(2500);
  await page.screenshot({ path: path.join(out, 'vr153-store.png') });
  const cards = await page.evaluate(() => [...document.querySelectorAll('.store-play')].length);
  console.log('store play buttons:', cards); if (cards !== 3) errors.push('store shows ' + cards + ' games, expected 3');
  const games = [['kugel-tennis-vr', [], 'Space'], ['kugel-gorillas-vr', ['w', 'ArrowLeft'], 'Space'], ['kugel-saber-vr', [], null]];
  for (const [id, hold, tap] of games) {
    await repl(page, 'go("kompass://store/' + id + '")'); await sleep(3500);
    await page.screenshot({ path: path.join(out, 'vr153-' + id + '-title.png') });
    if (!(await clickText(page, 'Play on screen'))) errors.push(id + ': no "Play on screen" button');
    await sleep(600);
    await page.mouse.move(760, 330);
    for (const k of hold) await page.keyboard.down(k);
    for (let i = 0; i < 6; i++) { if (tap) await page.keyboard.press(tap); await page.mouse.move(700 + i * 30, 360 - i * 12); await sleep(450); }
    for (const k of hold) await page.keyboard.up(k);
    await page.screenshot({ path: path.join(out, 'vr153-' + id + '-play.png') });
  }
  await repl(page, 'learn.last = 15\nsave_learn()\ngo("kompass://learn")'); await sleep(2000);
  await page.screenshot({ path: path.join(out, 'vr153-lesson-16.png') });
  const lessonOk = await page.evaluate(() => document.body.innerText.includes('VR games: hands, swings'));
  if (!lessonOk) errors.push('lesson 16 not shown');
  // Quest Browser hand-off: index.html#play=<id> opens that game
  const p2 = await open();
  await p2.goto(url + '#play=kugel-saber-vr', { waitUntil: 'networkidle0' }); await sleep(4500);
  const addr = await p2.evaluate(() => (document.querySelector('.address') || {}).value || '');
  console.log('#play= address:', addr); if (addr !== 'kompass://store/kugel-saber-vr') errors.push('#play= did not open the game (' + addr + ')');
  await p2.screenshot({ path: path.join(out, 'vr153-handoff-play-saber.png') });
  await browser.close();
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'screenshots OK');
  process.exit(errors.length ? 1 : 0);
})();
