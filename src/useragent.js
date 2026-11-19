// Kompass 1.6.0 — which User-Agent a web page sees (pure functions, unit-tested in tests/v160.test.js).
//
// Why: Google refused Kompass ("Couldn't sign you in — This browser or app may not be secure") and treated it as an
// unknown/outdated browser. Two causes, found with the KOMPASS_SHOTS160 self-test:
//  1. Kompass 1.5.x ran Electron 33 = Chromium 130 (Oct 2024) while Chrome was at 159: Google saw a Chrome two years
//     out of date. 1.6.0 moves to Electron 45 (Chromium 156) and reports that real version.
//  2. Google's sign-in page (accounts.google.com) fingerprints embedded Chromium (Electron) and rejects it whenever it
//     claims to be Chrome, even with a clean UA and "Google Chrome" client-hint brands. With a Firefox User-Agent on the
//     sign-in pages only, Google takes the normal password step. Every other site keeps the honest Chrome UA.
'use strict';

// the OS part of the UA must match navigator.platform, or sites see an inconsistent (= suspicious) browser
function osToken(platform) {
  if (platform === 'win32') return 'Windows NT 10.0; Win64; x64';
  if (platform === 'darwin') return 'Macintosh; Intel Mac OS X 10_15_7';
  return 'X11; Linux x86_64';
}

// a clean Chrome UA (no "Electron/x", no "Kompass/x") with the real Chromium major version, reduced like Chrome's own
function chromeUA(chromeVersion, platform) {
  const major = String(chromeVersion || '').split('.')[0] || '156';
  return 'Mozilla/5.0 (' + osToken(platform) + ') AppleWebKit/537.36 (KHTML, like Gecko) Chrome/' + major + '.0.0.0 Safari/537.36';
}

// Firefox ships every 4 weeks: 128 came out on 2024-07-09. Using the current release keeps the sign-in UA from aging.
function firefoxVersion(now) {
  const t = (now instanceof Date ? now : new Date(now || Date.now())).getTime();
  return Math.max(128, 128 + Math.floor((t - Date.UTC(2024, 6, 9)) / (28 * 86400000)));
}
function firefoxUA(now, platform) {
  const v = firefoxVersion(now) + '.0';
  const os = platform === 'win32' ? 'Windows NT 10.0; Win64; x64' : platform === 'darwin' ? 'Macintosh; Intel Mac OS X 10.15' : 'X11; Linux x86_64';
  return 'Mozilla/5.0 (' + os + '; rv:' + v + ') Gecko/20100101 Firefox/' + v;
}

// Google's account sign-in pages (also reached from "Sign in with Google" on other sites)
const SIGNIN_HOSTS = new Set(['accounts.google.com', 'accounts.youtube.com']);
function isGoogleSignIn(url) {
  try { const u = new URL(String(url)); return u.protocol === 'https:' && SIGNIN_HOSTS.has(u.hostname); } catch (e) { return false; }
}
function uaFor(url, ua) { return isGoogleSignIn(url) ? ua.signin : ua.chrome; }

// which UA a request goes out with: a top-level page load by its URL; everything else (images, scripts, XHR, iframes)
// with the UA of the tab that asked for it, so a page and its requests always agree
function requestUA(d, ua) {
  if (!d || d.resourceType === 'mainFrame') return uaFor(d && d.url, ua);
  const wc = d.webContents;
  try { if (wc && !wc.isDestroyed()) return wc.getUserAgent() === ua.signin ? ua.signin : ua.chrome; } catch (e) { /* gone */ }
  return uaFor(d.url, ua);
}
// the low-entropy client hints Chrome sends on every https request (Electron's network stack leaves them out, which
// marks it as "not a real browser"); built from the engine's own navigator.userAgentData so header and JS agree
function chHeaders(uad) {
  if (!uad || !Array.isArray(uad.brands) || !uad.brands.length) return null;
  const q = (x) => '"' + String(x).replace(/["\\]/g, '') + '"';
  return { 'sec-ch-ua': uad.brands.map(b => q(b.brand) + ';v=' + q(b.version)).join(', '), 'sec-ch-ua-mobile': uad.mobile ? '?1' : '?0', 'sec-ch-ua-platform': q(uad.platform || 'Windows') };
}
// request headers with that UA. Chrome UA: add the client hints if the stack did not (https only, like Chrome).
// Firefox UA (Google sign-in): Firefox sends no Chromium client hints, so any Sec-CH-UA* goes.
function fixHeaders(headers, uaString, ua, url) {
  const h = Object.assign({}, headers);
  for (const k of Object.keys(h)) if (/^user-agent$/i.test(k)) delete h[k];
  if (uaString === ua.signin) { for (const k of Object.keys(h)) if (/^sec-ch-ua/i.test(k)) delete h[k]; }
  else if (ua.ch && /^https:/.test(String(url || '')) && !Object.keys(h).some(k => /^sec-ch-ua$/i.test(k))) Object.assign(h, ua.ch);
  h['User-Agent'] = uaString;
  return h;
}

function make(versions, platform, now) {
  return { chrome: chromeUA(versions && versions.chrome, platform), signin: firefoxUA(now, platform) };
}

module.exports = { osToken, chromeUA, firefoxVersion, firefoxUA, isGoogleSignIn, uaFor, requestUA, chHeaders, fixHeaders, make };
