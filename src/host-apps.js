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
  const SAVE_EXT = ['ks', 'txt', 'json', 'csv', 'md', 'obj', 'gltf', 'glb', 'png', 'jpg', 'svg', 'html', 'kmodel', 'kblocks', 'kblocks3d', 'wav',
    // v1.8 Kugel Design / Kugel Work apps
    'gif', 'webm', 'pptx', 'xlsx', 'kpaint', 'kmotion', 'kvector', 'kprism', 'knotes', 'klattice'];
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

  // ---------- v1.8 helpers: CRC32 + ZIP (store/deflate via CompressionStream), GIF encoder, data URL bytes
  const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  const crc32 = (b) => { let c = 0xffffffff; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const b64ToBytes = (s) => { const bin = atob(s); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; };
  const bytesToB64 = (u) => { let s = ''; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
  const dataBytes = (d) => { const m = /^data:[^,]*?(;base64)?,(.*)$/s.exec(d); if (!m) return null; return m[1] ? b64ToBytes(m[2]) : new TextEncoder().encode(decodeURIComponent(m[2])); };
  async function streamBytes(u8, Stream, mode) { const s = new Blob([u8]).stream().pipeThrough(new Stream(mode)); return new Uint8Array(await new Response(s).arrayBuffer()); }
  async function zipCreate(files, compress) {
    const parts = [], central = []; let off = 0; const enc = new TextEncoder();
    for (const [name, raw] of files) {
      const nm = enc.encode(name); const data = typeof raw === 'string' && /^data:[^,]*;base64,/.test(raw) ? dataBytes(raw) : enc.encode(String(raw));
      const crc = crc32(data); let body = data, method = 0;
      if (compress && data.length > 64 && root.CompressionStream) { const z = await streamBytes(data, root.CompressionStream, 'deflate-raw'); if (z.length < data.length) { body = z; method = 8; } }
      const h = new DataView(new ArrayBuffer(30)); h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x0800, true); h.setUint16(8, method, true); h.setUint16(10, 0, true); h.setUint16(12, 0x21, true);
      h.setUint32(14, crc, true); h.setUint32(18, body.length, true); h.setUint32(22, data.length, true); h.setUint16(26, nm.length, true); h.setUint16(28, 0, true);
      parts.push(new Uint8Array(h.buffer), nm, body);
      const c = new DataView(new ArrayBuffer(46)); c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint16(8, 0x0800, true); c.setUint16(10, method, true); c.setUint16(12, 0, true); c.setUint16(14, 0x21, true);
      c.setUint32(16, crc, true); c.setUint32(20, body.length, true); c.setUint32(24, data.length, true); c.setUint16(28, nm.length, true); c.setUint32(42, off, true);
      central.push(new Uint8Array(c.buffer), nm); off += 30 + nm.length + body.length;
    }
    const csize = central.reduce((a, x) => a + x.length, 0); const e = new DataView(new ArrayBuffer(22)); e.setUint32(0, 0x06054b50, true); e.setUint16(8, files.length, true); e.setUint16(10, files.length, true); e.setUint32(12, csize, true); e.setUint32(16, off, true);
    const all = [...parts, ...central, new Uint8Array(e.buffer)]; const out = new Uint8Array(all.reduce((a, x) => a + x.length, 0)); let p = 0; for (const x of all) { out.set(x, p); p += x.length; }
    return out;
  }
  const TEXTY = /\.(xml|rels|txt|json|csv|md|html|svg|ks|vml)$/i;
  async function zipRead(u8, maxFiles) {
    const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength); let e = -1;
    for (let i = u8.length - 22; i >= Math.max(0, u8.length - 66000); i--) if (dv.getUint32(i, true) === 0x06054b50) { e = i; break; }
    if (e < 0) throw new Error('not a zip file');
    const n = dv.getUint16(e + 10, true); let p = dv.getUint32(e + 16, true); const out = []; const dec = new TextDecoder();
    for (let k = 0; k < n && k < maxFiles; k++) {
      if (dv.getUint32(p, true) !== 0x02014b50) break;
      const method = dv.getUint16(p + 10, true), csz = dv.getUint32(p + 20, true), nl = dv.getUint16(p + 28, true), xl = dv.getUint16(p + 30, true), cl = dv.getUint16(p + 32, true), lo = dv.getUint32(p + 42, true);
      const name = dec.decode(u8.subarray(p + 46, p + 46 + nl)); p += 46 + nl + xl + cl;
      if (name.endsWith('/')) continue;
      const lnl = dv.getUint16(lo + 26, true), lxl = dv.getUint16(lo + 28, true); const raw = u8.subarray(lo + 30 + lnl + lxl, lo + 30 + lnl + lxl + csz);
      let data; if (method === 0) data = raw; else if (method === 8 && root.DecompressionStream) data = await streamBytes(raw, root.DecompressionStream, 'deflate-raw'); else continue;
      if (data.length > 20 * 1024 * 1024) continue;
      const ext = (name.split('.').pop() || '').toLowerCase(); const mime = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', svg: 'image/svg+xml' }[ext] || 'application/octet-stream';
      out.push([name, TEXTY.test(name) ? dec.decode(data) : 'data:' + mime + ';base64,' + bytesToB64(data)]);
    }
    return out;
  }
  // GIF89a: one global palette (popular 5-bit colours of all frames, 255 + transparent), LZW per frame
  function gifEncode(frames, w, h, delayCs, loop) {
    const counts = new Map();
    for (const f of frames) for (let i = 0; i < f.length; i += 16) { if (f[i + 3] < 128) continue; const k = ((f[i] >> 3) << 10) | ((f[i + 1] >> 3) << 5) | (f[i + 2] >> 3); counts.set(k, (counts.get(k) || 0) + 1); }
    let pal = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 255).map(([k]) => [((k >> 10) & 31) << 3 | 4, ((k >> 5) & 31) << 3 | 4, (k & 31) << 3 | 4]);
    if (!pal.length) pal = [[0, 0, 0]];
    const TR = pal.length; pal.push([0, 0, 0]); while (pal.length < 256) pal.push([0, 0, 0]);
    const cache = new Map(); const nearest = (r, g, b) => { const k = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3); let v = cache.get(k); if (v !== undefined) return v; let bd = 1e9; v = 0; for (let i = 0; i < TR; i++) { const p = pal[i]; const d = (p[0] - r) ** 2 + (p[1] - g) ** 2 + (p[2] - b) ** 2; if (d < bd) { bd = d; v = i; } } cache.set(k, v); return v; };
    const out = []; const b = (x) => out.push(x & 255); const w16 = (x) => { b(x); b(x >> 8); }; const str = (s) => { for (const c of s) b(c.charCodeAt(0)); };
    str('GIF89a'); w16(w); w16(h); b(0xf7); b(0); b(0); for (const p of pal) { b(p[0]); b(p[1]); b(p[2]); }
    if (loop) { b(0x21); b(0xff); b(11); str('NETSCAPE2.0'); b(3); b(1); w16(0); b(0); }
    for (const f of frames) {
      b(0x21); b(0xf9); b(4); b(0x09); w16(delayCs); b(TR); b(0);
      b(0x2c); w16(0); w16(0); w16(w); w16(h); b(0);
      const idx = new Uint8Array(w * h); for (let i = 0, j = 0; j < idx.length; i += 4, j++) idx[j] = f[i + 3] < 128 ? TR : nearest(f[i], f[i + 1], f[i + 2]);
      // LZW, min code size 8
      b(8); const bytes = []; let cur = 0, nb = 0; const emit = (code, size) => { cur |= code << nb; nb += size; while (nb >= 8) { bytes.push(cur & 255); cur >>= 8; nb -= 8; } };
      let size = 9, next = 258; let dict = new Map(); emit(256, size); let prefix = idx[0];
      for (let i = 1; i < idx.length; i++) { const c = idx[i]; const key = prefix * 256 + c; const v = dict.get(key); if (v !== undefined) { prefix = v; continue; }
        emit(prefix, size); if (next < 4096) { dict.set(key, next++); if (next > (1 << size) && size < 12) size++; } else { emit(256, size); dict = new Map(); next = 258; size = 9; } prefix = c; }
      emit(prefix, size); emit(257, size); if (nb > 0) bytes.push(cur & 255);
      for (let i = 0; i < bytes.length; i += 255) { const n = Math.min(255, bytes.length - i); b(n); for (let j = 0; j < n; j++) b(bytes[i + j]); }
      b(0);
    }
    b(0x3b); return new Uint8Array(out);
  }
  // XML -> {tag, attrs, children, text} (namespaces kept in the tag name, e.g. "a:t")
  function xmlToK(text, toK, KError) {
    if (text.length > 8 * 1024 * 1024) throw new KError('xml_parse(): too big');
    const doc = new DOMParser().parseFromString(text, 'application/xml'); if (doc.getElementsByTagName('parsererror').length) return null;
    let n = 0; const conv = (e, d) => { if (++n > 200000 || d > 200) return null; const attrs = {}; for (const a of e.attributes) attrs[a.name] = a.value; const kids = []; let txt = '';
      for (const c of e.childNodes) { if (c.nodeType === 1) { const k = conv(c, d + 1); if (k) kids.push(k); } else if (c.nodeType === 3 || c.nodeType === 4) txt += c.nodeValue; }
      return { tag: e.tagName, attrs, children: kids, text: txt }; };
    return toK(conv(doc.documentElement, 0));
  }

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
      text_width: B(([t, size, font]) => { const g = (root.__ksMeasure = root.__ksMeasure || document.createElement('canvas').getContext('2d')); const f = font ? S(font) : 'Segoe UI, system-ui, sans-serif'; if (!/^[a-zA-Z0-9 ,"'-]{1,80}$/.test(f)) throw new KError('text_width(): bad font name'); const st = (f.match(/^(?:(?:bold|italic|[1-9]00)\s+)+/) || [''])[0]; g.font = st + (typeof size === 'number' ? size : 14) + 'px ' + (f.slice(st.length) || 'Segoe UI, system-ui, sans-serif'); return +g.measureText(S(t)).width.toFixed(2); }, 1, 3),

      // ---------- sound (synthesised, nothing downloaded)
      beep: B(([f, s, wave, vol]) => { const a = audio(); if (!a) return false; const w = wave ? S(wave) : 'square'; if (!['sine', 'square', 'sawtooth', 'triangle'].includes(w)) throw new KError('beep(): wave is sine, square, sawtooth or triangle'); tone(a, a.currentTime, Math.max(20, Math.min(20000, N(f, 'beep()'))), Math.max(0.01, Math.min(10, N(s, 'beep()', 0.2))), w, Math.max(0, Math.min(1, N(vol, 'beep()', 0.3)))); return true; }, 1, 4),
      sound: B(([n, vol]) => { const a = audio(); if (!a) return false; const k = S(n); const f = SOUNDS[k]; if (!f) throw new KError('sound(): unknown sound "' + k + '" — try ' + Object.keys(SOUNDS).join(', ')); f(a, a.currentTime, Math.max(0, Math.min(1, N(vol, 'sound()', 0.4)))); return true; }, 1, 2),
      sound_names: B(() => Object.keys(SOUNDS), 0, 0),


      // ---------- v1.8: image filters, regions, GIF / WebM export, ZIP (pptx / xlsx), XML
      canvas_filter: B(([c, name, amount]) => {   // grayscale, sepia, invert, blur, brightness, contrast, saturate, hue
        const hc = cv(c, 'canvas_filter()'); const k = S(name); const a = amount === undefined || amount === null ? null : N(amount, 'canvas_filter()');
        const f = { grayscale: `grayscale(${a ?? 100}%)`, sepia: `sepia(${a ?? 100}%)`, invert: `invert(${a ?? 100}%)`, blur: `blur(${Math.max(0, Math.min(40, a ?? 2))}px)`, brightness: `brightness(${a ?? 120}%)`,
          contrast: `contrast(${a ?? 130}%)`, saturate: `saturate(${a ?? 160}%)`, hue: `hue-rotate(${a ?? 90}deg)` }[k];
        if (!f) throw new KError('canvas_filter(): filter is grayscale, sepia, invert, blur, brightness, contrast, saturate or hue');
        const back = hc.back; const t = document.createElement('canvas'); t.width = back.width; t.height = back.height; t.getContext('2d').drawImage(back, 0, 0);
        const g = back.getContext('2d'); g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, back.width, back.height); g.filter = f; g.drawImage(t, 0, 0); g.restore(); R.touched(hc); return true;
      }, 2, 3),
      canvas_copy: B(([c, x, y, w, h]) => {   // a region of a canvas as a PNG data URL (selections, sprites, thumbnails)
        const hc = cv(c, 'canvas_copy()'); const back = hc.back; const s = back.width / (hc.w || back.width);
        const X = Math.round(N(x, 'canvas_copy()') * s), Y = Math.round(N(y, 'canvas_copy()') * s), W = Math.max(1, Math.round(N(w, 'canvas_copy()') * s)), H = Math.max(1, Math.round(N(h, 'canvas_copy()') * s));
        if (W > 8192 || H > 8192) throw new KError('canvas_copy(): too big');
        const t = document.createElement('canvas'); t.width = W; t.height = H; t.getContext('2d').drawImage(back, X, Y, W, H, 0, 0, W, H); return t.toDataURL('image/png');
      }, 5, 5),
      gif_encode: B(async ([frames, w, h, delay, loop]) => {   // frames: list of canvases or data:image URLs -> animated GIF data URL
        if (!Array.isArray(frames) || !frames.length) throw new KError('gif_encode(): give a list of frames'); if (frames.length > 600) throw new KError('gif_encode(): at most 600 frames');
        const W = Math.round(N(w, 'gif_encode()')), H = Math.round(N(h, 'gif_encode()')); if (W < 1 || H < 1 || W > 1024 || H > 1024) throw new KError('gif_encode(): size must be 1..1024');
        const t = document.createElement('canvas'); t.width = W; t.height = H; const g = t.getContext('2d', { willReadFrequently: true }); const px = [];
        for (const f of frames) { g.clearRect(0, 0, W, H); let im; if (f instanceof KHandle && f.kind === 'canvas') im = f.back || f.el; else { const u = S(f); if (!/^data:image\//.test(u)) throw new KError('gif_encode(): frames are canvases or data:image URLs'); im = imageFor(u); if (!im.complete) await new Promise((r) => { im.onload = im.onerror = () => r(); }); }
          g.drawImage(im, 0, 0, W, H); px.push(g.getImageData(0, 0, W, H).data); await after(Promise.resolve()); }
        const bytes = gifEncode(px, W, H, Math.max(2, Math.round(N(delay, 'gif_encode()', 100) / 10)), loop === undefined || loop === null ? true : !!loop);
        return 'data:image/gif;base64,' + bytesToB64(bytes);
      }, 3, 5),
      canvas_record: B(async ([c, secs, fps]) => {   // record what a canvas shows for some seconds -> WebM video data URL
        const hc = cv(c, 'canvas_record()'); const T = Math.max(0.2, Math.min(60, N(secs, 'canvas_record()'))); const el2 = hc.el;
        if (!el2.captureStream || !root.MediaRecorder) throw new KError('canvas_record(): video recording is not available here');
        const st = el2.captureStream(Math.max(1, Math.min(60, N(fps, 'canvas_record()', 30)))); const rec = new MediaRecorder(st, { mimeType: 'video/webm' }); const chunks = [];
        rec.ondataavailable = (e) => { if (e.data && e.data.size) chunks.push(e.data); };
        const done = new Promise((r) => { rec.onstop = r; }); rec.start(250); await after(new Promise((r) => setTimeout(r, T * 1000))); rec.stop(); await done; st.getTracks().forEach((t) => t.stop());
        const u8 = new Uint8Array(await new Blob(chunks, { type: 'video/webm' }).arrayBuffer()); return 'data:video/webm;base64,' + bytesToB64(u8);
      }, 2, 3),
      zip_create: B(async ([files, compress]) => {   // {"name": text or data URL, ...} -> ZIP data URL (pptx / xlsx are zips)
        if (!(files instanceof KMap)) throw new KError('zip_create(): give a map of file name -> text or data URL');
        const list = [...files.m.entries()].map(([k, v]) => [String(k), S(v)]); if (list.length > 2000) throw new KError('zip_create(): too many files');
        for (const [n] of list) if (!/^[A-Za-z0-9_\-./\[\]]{1,200}$/.test(n) || n.includes('..')) throw new KError('zip_create(): bad file name ' + n);
        const u8 = await zipCreate(list, compress === undefined || compress === null ? true : !!compress); return 'data:application/zip;base64,' + bytesToB64(u8);
      }, 1, 2),
      zip_read: B(async ([d]) => {   // ZIP data URL -> {"name": text (xml, json, txt...) or data URL}
        const u8 = dataBytes(S(d)); if (!u8) throw new KError('zip_read(): needs a data URL (file_open gives one for .pptx / .xlsx)');
        try { const out = new KMap(); for (const [k, v] of await zipRead(u8, 3000)) out.m.set(k, v); return out; } catch (e) { throw new KError('zip_read(): ' + e.message); }
      }, 1, 1),
      xml_parse: B(([t]) => xmlToK(S(t), toK, KError), 1, 1),

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
