/* Kompass 1.5 render commit layer (fixes the "HUD/buttons/canvas blink for a few ms on every change" bug).
 * Root cause: the KampfScript interpreter yields to the event loop (a macrotask) every N steps. In the middle of a
 * callback that did clear(list) or draw_clear(canvas) the browser could paint the half-built state: an empty list or
 * a blank canvas, then the rebuilt one a few ms later.
 * Fix: every KampfScript callback runs inside a batch. During a batch
 *   - clear(parent) does NOT remove anything: new children go to a detached staging holder;
 *   - draw_* paint into an offscreen back buffer;
 * and when the outermost batch ends everything is committed synchronously in one go: unchanged children are kept
 * (same DOM nodes, patched in place), only real differences are inserted/removed, back buffers are blitted to the
 * visible canvases, and a visible canvas is only resized when its size actually changed. */
(function (root) {
  'use strict';
  const FRESH = new Set(['CANVAS', 'INPUT', 'TEXTAREA', 'SELECT', 'VIDEO', 'IFRAME']);
  function createRenderer(env) {
    env = env || {};
    const doc = env.document || root.document;
    const raf = env.raf || ((f) => root.requestAnimationFrame(f));
    const now = env.now || (() => Date.now());
    const handleOf = new WeakMap();      // DOM node -> KHandle (so a reused node can be re-targeted)
    const staged = new Map();            // parent el -> { old: [nodes], holder: detached el }
    const dirtyCanvas = new Set();
    let depth = 0, openedAt = 0, watchdog = false;
    const stats = { commits: 0, reused: 0, inserted: 0, removed: 0, blits: 0, resizes: 0 };

    function hasListeners(n) {
      if (n.__ksL) return true;
      const k = n.children || []; for (let i = 0; i < k.length; i++) if (hasListeners(k[i])) return true; return false;
    }
    function hasFresh(n) {
      if (FRESH.has(n.tagName)) return true;
      const k = n.children || []; for (let i = 0; i < k.length; i++) if (hasFresh(k[i])) return true; return false;
    }
    const canReuse = (o, n) => o && n && o !== n && o.tagName === n.tagName && !hasListeners(o) && !hasListeners(n) && !hasFresh(n) && o.isEqualNode(n);
    function retarget(from, to) {
      const h = handleOf.get(from); if (h) { h.el = to; handleOf.set(to, h); }
      const a = from.children || [], b = to.children || [];
      for (let i = 0; i < a.length && i < b.length; i++) retarget(a[i], b[i]);
    }
    function patch(parent, desired) {      // make parent.children === desired with minimal moves
      for (let i = 0; i < desired.length; i++) {
        const cur = parent.childNodes[i];
        if (cur !== desired[i]) { parent.insertBefore(desired[i], cur || null); stats.inserted++; }
      }
      while (parent.childNodes.length > desired.length) { parent.removeChild(parent.childNodes[desired.length]); stats.removed++; }
    }
    function commitParent(parent, st) {
      const fresh = Array.from(st.holder.childNodes), out = [];
      for (let i = 0; i < fresh.length; i++) {
        const o = st.old[i], n = fresh[i];
        if (canReuse(o, n)) { retarget(n, o); out.push(o); stats.reused++; } else out.push(n);
      }
      patch(parent, out);
    }
    function commit() {
      for (const [p, st] of staged) commitParent(p, st);
      staged.clear();
      for (const h of dirtyCanvas) blit(h);
      dirtyCanvas.clear();
      stats.commits++;
    }
    function blit(h) {
      const f = h.front, b = h.back; if (!f || !b) return;
      if (f.width !== b.width || f.height !== b.height) { f.width = b.width; f.height = b.height; stats.resizes++; }  // resize + redraw in the same task
      const g = h.frontCtx || (h.frontCtx = f.getContext('2d'));
      g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'copy';
      g.drawImage(b, 0, 0); g.globalCompositeOperation = 'source-over'; stats.blits++;
    }
    function armWatchdog() {             // a batch that stays open (e.g. paused in the debugger) still shows up eventually
      if (watchdog) return; watchdog = true;
      const tickW = () => { if (!depth) { watchdog = false; return; } if (now() - openedAt > 250 && (staged.size || dirtyCanvas.size)) commit(); raf(tickW); };
      raf(tickW);
    }
    const api = {
      stats, staged, handleOf,
      get depth() { return depth; },
      begin() { if (!depth++) openedAt = now(); armWatchdog(); },
      end() { if (depth > 0 && --depth === 0) commit(); },
      run(fn) { api.begin(); let r; try { r = fn(); } catch (e) { api.end(); throw e; } if (r && typeof r.then === 'function') return r.finally(() => api.end()); api.end(); return r; },
      flush: commit,
      track(node, h) { handleOf.set(node, h); const add = node.addEventListener; node.addEventListener = function () { node.__ksL = 1; return add.apply(node, arguments); }; },
      // where should a new child of `parent` go?
      target(parent) { const st = staged.get(parent); return st ? st.holder : parent; },
      clear(parent) {
        if (!depth) { parent.replaceChildren(); return; }
        const st = staged.get(parent);
        if (st) { st.holder.replaceChildren(); return; }
        staged.set(parent, { old: Array.from(parent.childNodes), holder: doc.createElement(parent.tagName || 'div') });
      },
      // canvas: h.front = visible <canvas>, h.back = offscreen buffer that draw_* paint into
      setupCanvas(h) { h.front = h.el; h.back = doc.createElement('canvas'); h.back.width = h.front.width; h.back.height = h.front.height; h.g = h.back.getContext('2d'); },
      sizeBack(h, w, hh) { if (h.back.width !== w || h.back.height !== hh) { h.back.width = w; h.back.height = hh; return true; } return false; },
      touched(h) { if (depth) dirtyCanvas.add(h); else blit(h); },
    };
    return api;
  }
  const M = { createRenderer };
  if (typeof module !== 'undefined' && module.exports) module.exports = M; else root.KompassRender = M;
})(typeof window !== 'undefined' ? window : globalThis);
