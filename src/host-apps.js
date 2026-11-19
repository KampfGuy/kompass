/* Kompass 1.7 app built-ins for KampfScript: what Kugel Store apps (Kugel 3D Modeler, Kugel Blocks, Kugel Blocks 3D) need,
 * kept generic so every page and store game can use them. host.js merges them into the UI built-ins (sandboxes included).
 *   threads   spawn(fn, ...args), wait(seconds), next_frame(), exit_thread(), thread_alive(id)
 *             Scratch-style scripts: many loops "at once", each one pausing with wait/next_frame. Threads stop with the page.
 *   apps      run_app(code, stage, {on_print, on_error, name}) / stop_app(app) / app_status(app): run KampfScript (e.g. a game the
 *             user built from blocks) in its OWN fresh sandbox inside a box, and stop it again (the green flag / stop sign).
 *   images    draw_image, canvas_data, canvas_load, draw_fill, pixel_at, text_width, image_ready / load_image
 *   sound     beep(freq, seconds, wave, volume), sound(name, volume), sound_names()  (synthesised with WebAudio, no files)
 *   files     file_save(name, content) / file_open(extensions): the user picks the place in a normal Save / Open dialog.
 * Nothing here gives a page access to the network, other files, tabs, passwords or settings. */
(function (root) {
  'use strict';
  const SAVE_EXT = ['ks', 'txt', 'json', 'csv', 'md', 'obj', 'gltf', 'glb', 'png', 'jpg', 'svg', 'html', 'kmodel', 'kblocks', 'kblocks3d', 'wav'];
  const imgCache = new Map();   // data: URL -> HTMLImageElement
  function imageFor(url) {
    let im = imgCache.get(url); if (im) return im;
    if (imgCache.size > 400) imgCache.clear();
    im = new Image(); im.decoding = 'async'; im.src = url; imgCache.set(url, im); return im;
  }
  let actx = null;
  const audio = () => { if (!actx) { const AC = root.AudioContext || root.webkitAudioContext; if (!AC) return null; actx = new AC(); } if (actx.state === 'suspended') actx.resume().catch(() => {}); return actx; };
  function tone(a, t0, freq, dur, wave, vol, slideTo) {
    const o = a.createOscillator(), g = a.createGain(); o.type = wave; o.frequency.setValueAtTime(freq, t0);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t0 + dur);
    g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t0 + 0.008); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(a.destination); o.start(t0); o.stop(t0 + dur + 0.02);
  }
  function noise(a, t0, dur, vol, lowpass) {
    const n = Math.floor(a.sampleRate * dur), b = a.createBuffer(1, n, a.sampleRate), d = b.getChannelData(0); for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const s = a.createBufferSource(); s.buffer = b; const g = a.createGain(); g.gain.value = vol; const f = a.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = lowpass || 1200;
    s.connect(f).connect(g).connect(a.destination); s.start(t0);
  }
  const SOUNDS = {
    pop: (a, t, v) => tone(a, t, 600, 0.09, 'sine', v, 1200),
    click: (a, t, v) => tone(a, t, 1400, 0.03, 'square', v * 0.5),
    jump: (a, t, v) => tone(a, t, 300, 0.22, 'square', v * 0.6, 900),
    coin: (a, t, v) => { tone(a, t, 988, 0.08, 'square', v * 0.5); tone(a, t + 0.08, 1319, 0.25, 'square', v * 0.5); },
    hit: (a, t, v) => { noise(a, t, 0.15, v, 900); tone(a, t, 200, 0.15, 'triangle', v * 0.6, 60); },
    laser: (a, t, v) => tone(a, t, 1500, 0.25, 'sawtooth', v * 0.4, 120),
    boom: (a, t, v) => noise(a, t, 0.8, v * 1.2, 500),
    win: (a, t, v) => [523, 659, 784, 1047].forEach((f, i) => tone(a, t + i * 0.11, f, 0.2, 'triangle', v)),
    lose: (a, t, v) => [392, 330, 262].forEach((f, i) => tone(a, t + i * 0.16, f, 0.25, 'triangle', v)),
    meow: (a, t, v) => { tone(a, t, 700, 0.12, 'sawtooth', v * 0.35, 1100); tone(a, t + 0.12, 1100, 0.25, 'sawtooth', v * 0.35, 500); },
    drum: (a, t, v) => tone(a, t, 160, 0.25, 'sine', v * 1.2, 45),
    bell: (a, t, v) => { tone(a, t, 1320, 0.9, 'sine', v * 0.6); tone(a, t, 2640, 0.5, 'sine', v * 0.2); },
  };

  function builtins(c) {
    const { B, K, KError, KHandle, KMap, toK, S, N, cv, col, el, cb, isFn, alive, getInterp, makeRuntime, R, opts } = c;
    const threads = new Map(); let tid = 0;
    const EXIT = () => { const e = new KError('thread finished'); e.code = 'THREAD_EXIT'; return e; };
    const after = async (p) => { await p; const it = getInterp(); it.steps = 0; if (it.stopped || !alive()) throw EXIT(); };
    const mapOpt = (o, k, d) => (o instanceof KMap && o.m.has(k) && o.m.get(k) !== null ? o.m.get(k) : d);
    const native = () => root.native || {};

    return {
      // ---------- JSON (project files)
      json: B(([v, pretty]) => { const toJSv = (x) => Array.isArray(x) ? x.map(toJSv) : x instanceof KMap ? Object.fromEntries([...x.m].map(([k, y]) => [k, toJSv(y)])) : (x instanceof KHandle || (x && x.call)) ? null : x; return JSON.stringify(toJSv(v), null, pretty ? 2 : 0); }, 1, 2),
      parse_json: B(([t]) => { try { return toK(JSON.parse(S(t))); } catch (e) { return null; } }, 1, 1),
      // ---------- threads
      spawn: B((a) => {
        const [f, ...args] = a; if (!isFn(f)) throw new KError('spawn() needs a function: spawn(fn() { ... })');
        const it = getInterp(); const id = ++tid; threads.set(id, true); it.extraDepth = (it.extraDepth || 0) + 12;
        Promise.resolve().then(() => it.invoke(f, args, 'thread')).finally(() => { threads.delete(id); it.extraDepth -= 12; });
        return id;
      }, 1),
      thread_alive: B(([id]) => threads.has(+id), 1, 1),
      threads: B(() => threads.size, 0, 0),
      wait: B(async ([s]) => { const ms = Math.max(0, Math.min(60, N(s, 'wait()', 0))) * 1000; await after(new Promise((r) => setTimeout(r, ms))); return null; }, 1, 1),
      next_frame: B(async () => { const t0 = performance.now(); await after(new Promise((r) => requestAnimationFrame(() => r()))); return Math.min(0.1, (performance.now() - t0) / 1000); }, 0, 0),
      exit_thread: B(() => { throw EXIT(); }, 0, 0),

      // ---------- run another KampfScript program in its own sandbox inside a box (green flag / stop)
      run_app: B(([code, stage, o]) => {
        const st = el(stage, 'run_app()'); st.replaceChildren();
        const onPrint = mapOpt(o, 'on_print', null), onError = mapOpt(o, 'on_error', null), name = String(S(mapOpt(o, 'name', 'app'))).replace(/[^a-z0-9_-]/gi, '').slice(0, 32) || 'app';
        const app = new KHandle('app', st); app.output = []; app.error = ''; app.running = true;
        const sb = makeRuntime({
          sandbox: true, rootHandle: stage, maxSteps: 5000000, storeNs: (opts.storeNs || '') + 'app-' + name + '/',
          onPrint: (x) => { if (app.output.length < 500) app.output.push(x); if (isFn(onPrint)) cb(onPrint, 'app print')(x); },
          onError: (e) => { if (sb.stopped || (e && e.code === 'THREAD_EXIT')) return; app.error = e.message; if (isFn(onError)) cb(onError, 'app error')(e.message, e.line || 0); },
          extra: { sleep: B(() => null, 1, 1), input: B(() => '', 0, 1) },
        });
        app.rt = sb;
        Promise.resolve(R.run(() => sb.run(S(code)))).catch((e) => { if (!sb.stopped && !(e && e.code === 'THREAD_EXIT')) { app.error = e.message; if (isFn(onError)) cb(onError, 'app error')(e.message, e.line || 0); } });
        return app;
      }, 2, 3),
      stop_app: B(([a, wipe]) => { if (!(a instanceof KHandle) || a.kind !== 'app') throw new KError('stop_app() needs an app from run_app()'); a.running = false; if (a.rt) a.rt.stop(); if (wipe) a.el.replaceChildren(); return null; }, 1, 2),
      app_status: B(([a]) => { if (!(a instanceof KHandle) || a.kind !== 'app') throw new KError('app_status() needs an app from run_app()'); return toK({ running: a.running && !a.rt.stopped, error: a.error, output: a.output.slice(-50), steps: a.rt.totalSteps }); }, 1, 1),

      // ---------- images
      draw_image: B(([c, src, x, y, w, h, rot, alpha]) => {   // src = a canvas() or a data:image URL; x, y = top-left; negative w flips
        const hc = cv(c, 'draw_image()'), g = hc.g; let im;
        let nw = 0, nh = 0;
        if (src instanceof KHandle && src.kind === 'canvas') { im = src.back || src.el; nw = src.w || im.width; nh = src.h || im.height; } else { const u = S(src); if (!/^data:image\/(png|jpeg|gif|webp|svg\+xml);/.test(u)) throw new KError('draw_image(): source is a canvas() or a data:image/... URL'); im = imageFor(u); if (!im.complete || !im.naturalWidth) return false; nw = im.naturalWidth; nh = im.naturalHeight; }
        const W = w === undefined || w === null ? nw : N(w, 'draw_image()'), H = h === undefined || h === null ? nh : N(h, 'draw_image()');
        const X = N(x, 'draw_image()'), Y = N(y, 'draw_image()');
        g.save(); if (alpha !== undefined && alpha !== null) g.globalAlpha = Math.max(0, Math.min(1, N(alpha, 'draw_image()')));
        g.translate(X + Math.abs(W) / 2, Y + Math.abs(H) / 2); if (rot) g.rotate(N(rot, 'draw_image()')); g.scale(W < 0 ? -1 : 1, H < 0 ? -1 : 1);
        g.drawImage(im, -Math.abs(W) / 2, -Math.abs(H) / 2, Math.abs(W), Math.abs(H)); g.restore(); return true;
      }, 4, 8),
      draw_blend: B(([c, m]) => { const g = cv(c, 'draw_blend()').g; const k = S(m || 'normal'); const map = { normal: 'source-over', erase: 'destination-out', add: 'lighter', multiply: 'multiply', screen: 'screen', behind: 'destination-over' }; if (!map[k]) throw new KError('draw_blend(): mode is ' + Object.keys(map).join(', ')); g.globalCompositeOperation = map[k]; return null; }, 2, 2),
      draw_smooth: B(([c, on]) => { const g = cv(c, 'draw_smooth()').g; g.imageSmoothingEnabled = on === undefined ? true : !!on && on !== null; return null; }, 1, 2),
      image_ready: B(([u]) => { const im = imageFor(S(u)); return !!(im.complete && im.naturalWidth); }, 1, 1),
      load_image: B(async ([u]) => { const s = S(u); if (!/^data:image\//.test(s)) throw new KError('load_image(): needs a data:image/... URL'); const im = imageFor(s); if (!im.complete) await new Promise((r) => { im.onload = im.onerror = () => r(); }); return toK({ ok: !!im.naturalWidth, w: im.naturalWidth, h: im.naturalHeight }); }, 1, 1),
      canvas_data: B(([c]) => { const hc = cv(c, 'canvas_data()'); return (hc.back || hc.el).toDataURL('image/png'); }, 1, 1),
      canvas_load: B(async ([c, u]) => {
        const hc = cv(c, 'canvas_load()'); const s = S(u); if (!/^data:image\//.test(s)) throw new KError('canvas_load(): needs a data:image/... URL');
        const im = imageFor(s); if (!im.complete) await new Promise((r) => { im.onload = im.onerror = () => r(); });
        const g = hc.g; g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, hc.back.width, hc.back.height); if (im.naturalWidth) g.drawImage(im, 0, 0, hc.back.width, hc.back.height); g.restore(); R.touched(hc); return !!im.naturalWidth;
      }, 2, 2),
      draw_fill: B(([c, x, y, colr, tol]) => {   // bucket fill (paint editors)
        const hc = cv(c, 'draw_fill()'); const cvs = hc.back; const W = cvs.width, H = cvs.height; const s = W / (hc.w || W);
        const px = Math.floor(N(x, 'draw_fill()') * s), py = Math.floor(N(y, 'draw_fill()') * s); if (px < 0 || py < 0 || px >= W || py >= H) return 0;
        const g = cvs.getContext('2d'); const img = g.getImageData(0, 0, W, H), d = img.data;
        const t = document.createElement('canvas').getContext('2d'); t.fillStyle = col(colr, 'draw_fill()'); t.fillRect(0, 0, 1, 1); const fc = t.getImageData(0, 0, 1, 1).data;
        const i0 = (py * W + px) * 4, r0 = d[i0], g0 = d[i0 + 1], b0 = d[i0 + 2], a0 = d[i0 + 3]; const T = Math.max(0, Math.min(255, N(tol, 'draw_fill()', 24)));
        if (Math.abs(r0 - fc[0]) + Math.abs(g0 - fc[1]) + Math.abs(b0 - fc[2]) + Math.abs(a0 - fc[3]) === 0) return 0;
        const same = (i) => Math.abs(d[i] - r0) <= T && Math.abs(d[i + 1] - g0) <= T && Math.abs(d[i + 2] - b0) <= T && Math.abs(d[i + 3] - a0) <= T;
        const seen = new Uint8Array(W * H), stack = [px + py * W]; let n = 0;
        while (stack.length) { const p = stack.pop(); if (seen[p]) continue; seen[p] = 1; const i = p * 4; if (!same(i)) continue; d[i] = fc[0]; d[i + 1] = fc[1]; d[i + 2] = fc[2]; d[i + 3] = fc[3]; n++; const qx = p % W, qy = (p / W) | 0;
          if (qx > 0) stack.push(p - 1); if (qx < W - 1) stack.push(p + 1); if (qy > 0) stack.push(p - W); if (qy < H - 1) stack.push(p + W); }
        g.putImageData(img, 0, 0); R.touched(hc); return n;
      }, 4, 5),
      pixel_at: B(([c, x, y]) => {
        const hc = cv(c, 'pixel_at()'); const cvs = hc.back; const s = cvs.width / (hc.w || cvs.width); const px = Math.floor(N(x, 'pixel_at()') * s), py = Math.floor(N(y, 'pixel_at()') * s);
        if (px < 0 || py < 0 || px >= cvs.width || py >= cvs.height) return '#00000000';
        const d = cvs.getContext('2d').getImageData(px, py, 1, 1).data; return '#' + [d[0], d[1], d[2], d[3]].map((v) => v.toString(16).padStart(2, '0')).join('');
      }, 3, 3),
      text_width: B(([t, size, font]) => { const g = (root.__ksMeasure = root.__ksMeasure || document.createElement('canvas').getContext('2d')); const f = font ? S(font) : 'Segoe UI, system-ui, sans-serif'; if (!/^[a-zA-Z0-9 ,"'-]{1,80}$/.test(f)) throw new KError('text_width(): bad font name'); g.font = (typeof size === 'number' ? size : 14) + 'px ' + f; return +g.measureText(S(t)).width.toFixed(2); }, 1, 3),

      // ---------- sound (synthesised, nothing downloaded)
      beep: B(([f, s, wave, vol]) => { const a = audio(); if (!a) return false; const w = wave ? S(wave) : 'square'; if (!['sine', 'square', 'sawtooth', 'triangle'].includes(w)) throw new KError('beep(): wave is sine, square, sawtooth or triangle'); tone(a, a.currentTime, Math.max(20, Math.min(20000, N(f, 'beep()'))), Math.max(0.01, Math.min(10, N(s, 'beep()', 0.2))), w, Math.max(0, Math.min(1, N(vol, 'beep()', 0.3)))); return true; }, 1, 4),
      sound: B(([n, vol]) => { const a = audio(); if (!a) return false; const k = S(n); const f = SOUNDS[k]; if (!f) throw new KError('sound(): unknown sound "' + k + '" — try ' + Object.keys(SOUNDS).join(', ')); f(a, a.currentTime, Math.max(0, Math.min(1, N(vol, 'sound()', 0.4)))); return true; }, 1, 2),
      sound_names: B(() => Object.keys(SOUNDS), 0, 0),

      // ---------- files: always through the user's own Save / Open dialog
      file_save: B(async ([name, content]) => {
        const n = String(S(name)).replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 80) || 'file.txt'; const ext = (n.split('.').pop() || '').toLowerCase();
        if (!SAVE_EXT.includes(ext)) throw new KError('file_save(): the file name must end in ' + SAVE_EXT.map((e) => '.' + e).join(' '));
        const data = S(content); if (data.length > 60 * 1024 * 1024) throw new KError('file_save(): too big (max 60 MB)');
        if (!native().files) throw new KError('file_save() needs Kompass 1.7 for Windows');
        const r = await native().files.save(n, data); return toK(r || { ok: false });
      }, 2, 2),
      file_open: B(async ([exts]) => {
        const l = (Array.isArray(exts) ? exts : exts ? [exts] : ['txt']).map((e) => String(S(e)).replace(/^\./, '').toLowerCase()).filter((e) => /^[a-z0-9]{1,10}$/.test(e));
        if (!native().files) throw new KError('file_open() needs Kompass 1.7 for Windows');
        const r = await native().files.open(l); return r && r.ok ? toK(r) : null;
      }, 0, 1),
    };
  }
  root.KompassApps = { builtins, SAVE_EXT, SOUND_NAMES: Object.keys(SOUNDS) };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.KompassApps;
})(typeof window !== 'undefined' ? window : globalThis);
