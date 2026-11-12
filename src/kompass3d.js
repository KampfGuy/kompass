/* Kompass 3D (v1.5.2): KampfScript built-ins for 3D games, drawn with the locally bundled three.js (src/vendor/three.min.js).
 * host.js merges these into the UI built-ins, so they work in browser.ks, editor scripts, builder pages, kompass://page/<name>
 * and sandboxed Kugel Store games. Nothing here touches the network, files or the browser: textures are procedural or come
 * from a KampfScript canvas(). Scenes render in their own frame loop and are disposed when their page closes.
 * Conventions: y is up, the camera looks down -z at yaw 0, all angles are in DEGREES, sizes are in "metres". */
(function (root) {
  'use strict';
  const MAX_OBJECTS = 5000, MAX_SCENES = 4, MAX_LIVE = 8;
  let live = 0;   // WebGL contexts open in this window (Chromium allows ~16)
  const allScenes = new Set();   // every live scene in this window, so a new scene can free ones whose page is already gone
  const D2R = Math.PI / 180;

  function builtins(c) {
    const { B, K, KError, KMap, KHandle, toK, S, N, make, cb, isFn, alive, visible, keyDown } = c;
    const T = () => { if (!root.THREE) throw new KError('3D is not available (three.js did not load)'); return root.THREE; };
    const scenes = new Set();
    const isMap = (v) => v instanceof KMap;
    const opt = (o, k, d) => (isMap(o) && o.m.has(k) && o.m.get(k) !== null ? o.m.get(k) : d);
    const sc = (x, who) => {
      if (x instanceof KHandle && x.kind === 'object3d' && x.st) x = x.st.h;
      if (!(x instanceof KHandle) || x.kind !== 'scene3d' || !x.st) throw new KError(who + ' needs a 3D scene from scene3d(parent), got ' + K.typeOf(x));
      if (x.st.gone) throw new KError(who + ': this 3D scene was closed'); return x.st;
    };
    const ob = (x, who) => {
      if (!(x instanceof KHandle) || x.kind !== 'object3d' || !x.o) throw new KError(who + ' needs a 3D object (cube, sphere, plane, ...), got ' + K.typeOf(x));
      return x;   // a removed object can still be read / moved (it is just not in the scene any more): games often keep old references
    };
    const color = (v, who) => {
      const s = S(v); if (!/^(#[0-9a-fA-F]{3,8}|(rgb|rgba|hsl|hsla)\([0-9., %]+\)|[a-zA-Z]{3,20})$/.test(s)) throw new KError(who + ': color must be like "#ff4500", "rgb(255,69,0)" or a name like "white"');
      const C = new (T().Color)(); const hex = /^#([0-9a-f]{6})[0-9a-f]{2}$/i.exec(s);
      try { C.setStyle(hex ? '#' + hex[1] : s.replace(/^rgba\(([^,]+,[^,]+,[^,]+),[^)]*\)$/i, 'rgb($1)').replace(/^hsla\(([^,]+,[^,]+,[^,]+),[^)]*\)$/i, 'hsl($1)')); } catch (e) { throw new KError(who + ': unknown color ' + s); }
      return C;
    };
    const vec = (v, who) => {
      if (Array.isArray(v)) return [N(v[0], who, 0), N(v[1], who, 0), N(v[2], who, 0)];
      if (isMap(v)) return [N(v.m.get('x'), who, 0), N(v.m.get('y'), who, 0), N(v.m.get('z'), who, 0)];
      if (v instanceof KHandle && v.kind === 'object3d' && v.o) { const p = v.o.getWorldPosition(new (T().Vector3)()); return [p.x, p.y, p.z]; }
      throw new KError(who + ': expected a point like vec3(x, y, z), [x, y, z] or a 3D object, got ' + K.typeOf(v));
    };
    const xyz = (a, b, c2) => toK({ x: +a.toFixed(4), y: +b.toFixed(4), z: +c2.toFixed(4) });

    // ---- procedural textures (no image URLs)
    function proc(name, base) {
      const TH = T(), cv = document.createElement('canvas'); cv.width = cv.height = 128; const g = cv.getContext('2d');
      const b = '#' + base.getHexString(), dark = '#' + base.clone().multiplyScalar(0.62).getHexString(), lite = '#' + base.clone().lerp(new TH.Color(1, 1, 1), 0.35).getHexString();
      g.fillStyle = b; g.fillRect(0, 0, 128, 128);
      if (name === 'checker') { g.fillStyle = dark; for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) if ((x + y) % 2) g.fillRect(x * 16, y * 16, 16, 16); }
      else if (name === 'grid') { g.strokeStyle = dark; g.lineWidth = 3; for (let i = 0; i <= 128; i += 32) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 128); g.moveTo(0, i); g.lineTo(128, i); g.stroke(); } }
      else if (name === 'bricks') { g.fillStyle = dark; for (let y = 0; y < 128; y += 32) { g.fillRect(0, y, 128, 3); for (let x = (y / 32) % 2 ? 0 : 32; x < 128; x += 64) g.fillRect(x, y, 3, 32); } }
      else if (name === 'stripes') { g.fillStyle = lite; for (let x = 0; x < 128; x += 32) g.fillRect(x, 0, 16, 128); }
      else if (name === 'noise') { let s = 7; for (let i = 0; i < 2600; i++) { s = (s * 16807) % 2147483647; const x = s % 128; s = (s * 16807) % 2147483647; const y = s % 128; g.fillStyle = i % 2 ? dark : lite; g.fillRect(x, y, 2, 2); } }
      else throw new KError('texture must be "checker", "grid", "bricks", "stripes", "noise" or a canvas()');
      const t = new TH.CanvasTexture(cv); t.wrapS = t.wrapT = TH.RepeatWrapping; t.colorSpace = TH.SRGBColorSpace; t.anisotropy = 4; return t;
    }

    // ---- scenes
    function render(st, now) {
      if (st.gone) return;
      if (!alive()) return dispose(st);
      if (!st.el.isConnected) { if (++st.off > 90) return dispose(st); requestAnimationFrame((t) => render(st, t)); return; }
      st.off = 0; requestAnimationFrame((t) => render(st, t));
      const dt = st.last ? Math.min(0.1, (now - st.last) / 1000) : 1 / 60; st.last = now;
      if (!visible()) return;
      const r = st.el.getBoundingClientRect(); const w = Math.max(1, Math.round(st.fixedW || r.width)), h = Math.max(1, Math.round(st.fixedH || r.height));
      if (r.width < 1 || r.height < 1) return;
      if (w !== st.w || h !== st.h) { st.w = w; st.h = h; st.renderer.setSize(w, h, false); st.camera.aspect = w / h; st.camera.updateProjectionMatrix(); }
      if (st.fps) stepFps(st, dt);
      if (st.follow) stepFollow(st, dt);
      for (const t of st.liveTex) t.needsUpdate = true;
      st.renderer.render(st.scene, st.camera); st.frames++;
    }
    function dispose(st) {
      if (st.gone) return; st.gone = true; scenes.delete(st); allScenes.delete(st); live--;
      st.scene.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) { if (o.material.map) o.material.map.dispose(); o.material.dispose(); } });
      for (const t of Object.values(st.texCache)) t.dispose();
      try { st.renderer.dispose(); st.renderer.forceContextLoss(); } catch (e) { /* already lost */ }
      if (document.pointerLockElement === st.el) document.exitPointerLock();
    }
    const applyCam = (st) => { st.camera.rotation.set(st.pitch, st.yaw, 0, 'YXZ'); };
    const readCam = (st) => { const e = new (T().Euler)().setFromQuaternion(st.camera.quaternion, 'YXZ'); st.yaw = e.y; st.pitch = e.x; };

    // ---- first-person controls: WASD / arrows / mouse look (click = pointer lock) / gamepad, sliding along solid3d() objects
    function stepFps(st, dt) {
      const f = st.fps, cam = st.camera; const gp = pad(-1);
      let turn = 0, look = 0, fwd = 0, side = 0;
      if (keyDown('w') || keyDown('up')) fwd += 1; if (keyDown('s') || keyDown('down')) fwd -= 1;
      if (keyDown('d')) side += 1; if (keyDown('a')) side -= 1;
      if (f.arrowsTurn) { if (keyDown('left')) turn += 1; if (keyDown('right')) turn -= 1; } else { if (keyDown('right')) side += 1; if (keyDown('left')) side -= 1; }
      if (gp) { fwd -= gp.ly; side += gp.lx; turn -= gp.rx * 1.4; look -= gp.ry * 1.2; }
      st.yaw += (turn * f.turn * dt) + (-st.mdx * f.look * D2R); st.pitch += (look * f.turn * dt) + (-st.mdy * f.look * D2R); st.mdx = st.mdy = 0;
      st.pitch = Math.max(-1.45, Math.min(1.45, st.pitch)); applyCam(st);
      const run = keyDown('shift') || (gp && gp.lb) ? 1.8 : 1; const len = Math.hypot(fwd, side); if (len > 1) { fwd /= len; side /= len; }
      const sp = f.speed * run * dt, sy = Math.sin(st.yaw), cy = Math.cos(st.yaw);
      const dx = (-sy * fwd + cy * side) * sp, dz = (-cy * fwd - sy * side) * sp;
      if (f.fly) { cam.position.y += (keyDown('space') ? 1 : 0) * sp - (keyDown('c') ? 1 : 0) * sp; }
      else if (f.gravity) {
        f.vy -= f.gravity * dt; if (f.onGround && (keyDown('space') || (gp && gp.a)) && f.jump > 0) { f.vy = f.jump; f.onGround = false; }
        cam.position.y += f.vy * dt; if (cam.position.y <= f.height) { cam.position.y = f.height; f.vy = 0; f.onGround = true; }
      }
      if (!dx && !dz) return;
      const boxes = solidBoxes(st), r = f.radius, p = cam.position, foot = p.y - f.height + 0.05;
      const blocked = (x, z) => boxes.some((b) => x + r > b.min.x && x - r < b.max.x && z + r > b.min.z && z - r < b.max.z && p.y > b.min.y && foot < b.max.y);
      if (!blocked(p.x + dx, p.z)) p.x += dx; if (!blocked(p.x, p.z + dz)) p.z += dz;
    }
    function solidBoxes(st) {
      const TH = T(); const out = []; st.scene.updateMatrixWorld();
      for (const h of st.objects) if (h.solid && h.o.visible) out.push(new TH.Box3().setFromObject(h.o));
      return out;
    }
    function stepFollow(st, dt) {
      const f = st.follow; if (f.h.gone) { st.follow = null; return; }
      const TH = T(); const p = f.h.o.getWorldPosition(new TH.Vector3()); const want = new TH.Vector3(p.x + f.dx, p.y + f.dy, p.z + f.dz);
      st.camera.position.lerp(want, f.smooth ? Math.min(1, dt * f.smooth) : 1); st.camera.lookAt(p.x, p.y + f.ly, p.z); readCam(st);
    }
    // ---- gamepad (standard mapping); i = -1 means "first connected"
    function pad(i) {
      const list = (navigator.getGamepads && navigator.getGamepads()) || []; let g = null;
      if (i >= 0) g = list[i] || null; else for (const x of list) if (x && x.connected) { g = x; break; }
      if (!g || !g.connected) return null;
      const ax = (n) => { const v = g.axes[n] || 0; return Math.abs(v) < 0.12 ? 0 : +v.toFixed(3); };
      const bt = (n) => !!(g.buttons[n] && g.buttons[n].pressed); const bv = (n) => +((g.buttons[n] && g.buttons[n].value) || 0).toFixed(3);
      return { connected: true, id: String(g.id).slice(0, 80), lx: ax(0), ly: ax(1), rx: ax(2), ry: ax(3), a: bt(0), b: bt(1), x: bt(2), y: bt(3), lb: bt(4), rb: bt(5), lt: bv(6), rt: bv(7),
        select: bt(8), start: bt(9), up: bt(12), down: bt(13), left: bt(14), right: bt(15), buttons: g.buttons.map((b) => !!b.pressed) };
    }

    function addObj(st, o, who, extra) {
      if (st.objects.size >= MAX_OBJECTS) throw new KError(who + ': too many 3D objects in one scene (max ' + MAX_OBJECTS + ')');
      const h = new KHandle('object3d', null, Object.assign({ o, st, tag: '', solid: false }, extra || {})); o.userData.h = h;
      if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; }
      st.scene.add(o); st.objects.add(h); return h;
    }
    function mesh(st, geo, colr, who) {
      const TH = T(); const m = new TH.MeshStandardMaterial({ color: colr === undefined || colr === null ? 0xcccccc : color(colr, who), roughness: 0.8, metalness: 0.05 });
      return addObj(st, new TH.Mesh(geo, m), who);
    }
    const size = (v, who, d) => { const n = N(v, who, d); if (n <= 0 || n > 100000) throw new KError(who + ': sizes must be between 0 and 100000'); return n; };
    const pickable = (st) => { st.scene.updateMatrixWorld(); st.camera.updateMatrixWorld(); return pickList(st); };
    const pickList = (st) => [...st.objects].filter((h) => h.o.isMesh && h.o.visible).map((h) => h.o);
    const hitOf = (x) => { if (!x) return null; let o = x.object; while (o && !o.userData.h) o = o.parent; return o ? toK({ obj: null, dist: +x.distance.toFixed(4), x: +x.point.x.toFixed(4), y: +x.point.y.toFixed(4), z: +x.point.z.toFixed(4) }) : null; };
    const withObj = (x, hit) => { if (!hit) return null; let o = x.object; while (o && !o.userData.h) o = o.parent; hit.m.set('obj', o.userData.h); hit.m.set('tag', o.userData.h.tag); return hit; };

    const api = {
      scene3d: B(([p, w, h, s]) => {
        const TH = T();
        if (scenes.size >= MAX_SCENES) throw new KError('scene3d(): at most ' + MAX_SCENES + ' 3D scenes per page');
        if (live >= MAX_LIVE) for (const o of [...allScenes]) if (o.off > 0 || !o.el.isConnected) o.dispose();   // e.g. Learn's ▶ Try it pressed again quickly
        if (live >= MAX_LIVE) throw new KError('scene3d(): too many 3D scenes are open in Kompass — close a 3D tab first');
        const k = make('scene3d', 'div', 'ks-scene3d', p, 'scene3d()'); if (s) { const c2 = S(s); if (!/^[a-zA-Z0-9_ -]+$/.test(c2)) throw new KError('bad style name: ' + c2); for (const x of c2.split(/\s+/).filter(Boolean)) k.el.classList.add(x); }
        const fixedW = typeof w === 'number' ? w : 0, fixedH = typeof h === 'number' ? h : 0;
        if (fixedW) k.el.style.width = fixedW + 'px'; if (fixedH) k.el.style.height = fixedH + 'px'; if (!fixedW || !fixedH) k.el.classList.add('fill');
        let renderer; try { renderer = new TH.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true }); } catch (e) { k.el.textContent = '3D is not available on this computer (WebGL is off).'; throw new KError('scene3d(): this computer could not start 3D (WebGL is off)'); }
        live++;
        renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1)); renderer.outputColorSpace = TH.SRGBColorSpace; renderer.shadowMap.type = TH.PCFSoftShadowMap;
        renderer.domElement.className = 'ks-scene3d-gl'; k.el.appendChild(renderer.domElement);
        renderer.domElement.addEventListener('contextmenu', (e) => e.preventDefault());
        const scene = new TH.Scene(); scene.background = new TH.Color('#87ceeb');
        const camera = new TH.PerspectiveCamera(70, 16 / 9, 0.05, 2000); camera.position.set(0, 2, 6); camera.lookAt(0, 0, 0);
        const st = { h: k, el: k.el, renderer, scene, camera, objects: new Set(), texCache: {}, liveTex: new Set(), fixedW, fixedH, w: 0, h: 0, off: 0, last: 0, frames: 0, yaw: 0, pitch: 0, mdx: 0, mdy: 0, fps: null, follow: null, gone: false };
        readCam(st); k.st = st; scenes.add(st); allScenes.add(st); st.dispose = () => dispose(st);
        const amb = new TH.HemisphereLight(0xffffff, 0x445566, 1.4); scene.add(amb);
        const sun = new TH.DirectionalLight(0xffffff, 2.2); sun.position.set(8, 14, 6); sun.shadow.mapSize.set(1024, 1024);
        Object.assign(sun.shadow.camera, { left: -30, right: 30, top: 30, bottom: -30, near: 0.5, far: 80 }); scene.add(sun); st.defaultLights = [amb, sun];
        // mouse look for fps_controls: drag, or click to lock the pointer (Esc releases it)
        let drag = false;
        k.el.addEventListener('mousedown', (e) => { if (!st.fps) return; drag = true; if (st.fps.lock && k.el.requestPointerLock && document.pointerLockElement !== k.el) { try { const r = k.el.requestPointerLock(); if (r && r.catch) r.catch(() => {}); } catch (x) { /* not allowed */ } } });
        window.addEventListener('mouseup', () => { drag = false; });
        k.el.addEventListener('mousemove', (e) => { if (st.fps && (drag || document.pointerLockElement === k.el)) { st.mdx += e.movementX || 0; st.mdy += e.movementY || 0; } });
        requestAnimationFrame((t) => render(st, t));
        return k;
      }, 1, 4),
      sky3d: B(([s, c1, c2]) => {
        const st = sc(s, 'sky3d()'), TH = T();
        if (c2 === undefined || c2 === null) { st.scene.background = color(c1, 'sky3d()'); return null; }
        const cv = document.createElement('canvas'); cv.width = 2; cv.height = 256; const g = cv.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 256);
        gr.addColorStop(0, '#' + color(c1, 'sky3d()').getHexString()); gr.addColorStop(1, '#' + color(c2, 'sky3d()').getHexString()); g.fillStyle = gr; g.fillRect(0, 0, 2, 256);
        const t = new TH.CanvasTexture(cv); t.colorSpace = TH.SRGBColorSpace; st.scene.background = t; return null;
      }, 2, 3),
      fog3d: B(([s, c1, near, far]) => {
        const st = sc(s, 'fog3d()'); if (c1 === false || c1 === null) { st.scene.fog = null; return null; }
        st.scene.fog = new (T().Fog)(color(c1, 'fog3d()'), N(near, 'fog3d()', 10), N(far, 'fog3d()', 60)); return null;
      }, 2, 4),
      light3d: B(([s, kind, c1, inten, x, y, z]) => {
        const st = sc(s, 'light3d()'), TH = T(), k = S(kind);
        if (k === 'none') { for (const l of st.defaultLights) st.scene.remove(l); st.defaultLights = []; return null; }
        const C = c1 === undefined || c1 === null ? new TH.Color(0xffffff) : color(c1, 'light3d()'); const I = N(inten, 'light3d()', k === 'point' ? 20 : 1.5);
        let L; if (k === 'ambient') L = new TH.AmbientLight(C, I); else if (k === 'sun') { L = new TH.DirectionalLight(C, I); L.position.set(5, 10, 7); } else if (k === 'point') { L = new TH.PointLight(C, I, 0, 2); }
        else throw new KError('light3d(): kind is "ambient", "sun", "point" or "none" (removes the default lights)');
        if (x !== undefined && x !== null) L.position.set(N(x, 'light3d()'), N(y, 'light3d()', 0), N(z, 'light3d()', 0));
        return addObj(st, L, 'light3d()');
      }, 2, 7),
      shadows3d: B(([s, on]) => { const st = sc(s, 'shadows3d()'); const v = on === undefined || !!on && on !== null; st.renderer.shadowMap.enabled = v; for (const l of st.scene.children) if (l.isDirectionalLight || l.isPointLight) l.castShadow = v; st.scene.traverse((o) => { if (o.material) o.material.needsUpdate = true; }); return null; }, 1, 2),
      cube: B(([s, w, h, d, c1]) => { const st = sc(s, 'cube()'); const W = size(w, 'cube()', 1); return mesh(st, new (T().BoxGeometry)(W, size(h, 'cube()', W), size(d, 'cube()', W)), c1, 'cube()'); }, 1, 5),
      sphere: B(([s, r, c1]) => mesh(sc(s, 'sphere()'), new (T().SphereGeometry)(size(r, 'sphere()', 0.5), 32, 18), c1, 'sphere()'), 1, 3),
      cylinder: B(([s, r, h, c1]) => mesh(sc(s, 'cylinder()'), new (T().CylinderGeometry)(size(r, 'cylinder()', 0.5), size(r, 'cylinder()', 0.5), size(h, 'cylinder()', 1), 32), c1, 'cylinder()'), 1, 4),
      cone: B(([s, r, h, c1]) => mesh(sc(s, 'cone()'), new (T().ConeGeometry)(size(r, 'cone()', 0.5), size(h, 'cone()', 1), 32), c1, 'cone()'), 1, 4),
      torus: B(([s, r, tube, c1]) => mesh(sc(s, 'torus()'), new (T().TorusGeometry)(size(r, 'torus()', 0.5), size(tube, 'torus()', 0.15), 16, 48), c1, 'torus()'), 1, 4),
      plane: B(([s, w, d, c1]) => { const st = sc(s, 'plane()'); const W = size(w, 'plane()', 10); const h = mesh(st, new (T().PlaneGeometry)(W, size(d, 'plane()', W)), c1, 'plane()'); h.o.rotation.x = -Math.PI / 2; h.o.castShadow = false; return h; }, 1, 4),
      group3d: B(([s]) => { const st = sc(s, 'group3d()'); return addObj(st, new (T().Group)(), 'group3d()'); }, 1, 1),
      attach3d: B(([g, o]) => { const G = ob(g, 'attach3d()'), O = ob(o, 'attach3d()'); if (G.gone || O.gone) throw new KError('attach3d(): that 3D object was removed'); if (G.st !== O.st) throw new KError('attach3d(): both objects must be in the same scene'); if (G === O) throw new KError('attach3d(): cannot attach an object to itself'); G.o.add(O.o); return null; }, 2, 2),
      move3d: B(([o, x, y, z]) => { const h = ob(o, 'move3d()'); if (z === undefined) { const v = vec(x, 'move3d()'); h.o.position.set(v[0], v[1], v[2]); } else h.o.position.set(N(x, 'move3d()'), N(y, 'move3d()'), N(z, 'move3d()')); return null; }, 2, 4),
      shift3d: B(([o, x, y, z]) => { const h = ob(o, 'shift3d()'); h.o.position.x += N(x, 'shift3d()'); h.o.position.y += N(y, 'shift3d()', 0); h.o.position.z += N(z, 'shift3d()', 0); return null; }, 2, 4),
      turn3d: B(([o, x, y, z]) => { const h = ob(o, 'turn3d()'); h.o.rotation.set(N(x, 'turn3d()') * D2R, N(y, 'turn3d()', 0) * D2R, N(z, 'turn3d()', 0) * D2R); return null; }, 2, 4),
      spin3d: B(([o, x, y, z]) => { const h = ob(o, 'spin3d()'); h.o.rotation.x += N(x, 'spin3d()') * D2R; h.o.rotation.y += N(y, 'spin3d()', 0) * D2R; h.o.rotation.z += N(z, 'spin3d()', 0) * D2R; return null; }, 2, 4),
      scale3d: B(([o, x, y, z]) => { const h = ob(o, 'scale3d()'); const X = N(x, 'scale3d()'); h.o.scale.set(X, N(y, 'scale3d()', X), N(z, 'scale3d()', X)); return null; }, 2, 4),
      point3d: B(([o, x, y, z]) => { const h = ob(o, 'point3d()'); const v = z === undefined ? vec(x, 'point3d()') : [N(x, 'point3d()'), N(y, 'point3d()'), N(z, 'point3d()')]; h.o.lookAt(v[0], v[1], v[2]); return null; }, 2, 4),
      pos3d: B(([o]) => { const h = ob(o, 'pos3d()'); const p = h.o.position; return xyz(p.x, p.y, p.z); }, 1, 1),
      rot3d: B(([o]) => { const h = ob(o, 'rot3d()'); const r = h.o.rotation; return xyz(r.x / D2R, r.y / D2R, r.z / D2R); }, 1, 1),
      color3d: B(([o, c1]) => { const h = ob(o, 'color3d()'); if (!h.o.material || !h.o.material.color) { if (h.o.color) { h.o.color = color(c1, 'color3d()'); return null; } throw new KError('color3d(): that object has no color'); } h.o.material.color = color(c1, 'color3d()'); return null; }, 2, 2),
      look3d: B(([o, m]) => {
        const h = ob(o, 'look3d()'); if (!isMap(m)) throw new KError('look3d() needs a map like {color: "#f00", glow: "#300", shiny: 0.5, metal: 0, opacity: 1, wire: false, texture: "checker", repeat: 4}');
        const mat = h.o.material; if (!mat || !mat.isMeshStandardMaterial) throw new KError('look3d(): only works on shapes');
        for (const k of m.m.keys()) if (!['color', 'glow', 'shiny', 'metal', 'opacity', 'wire', 'texture', 'repeat', 'flat'].includes(k)) throw new KError('look3d(): unknown setting "' + k + '"');
        const v = (k) => m.m.get(k);
        if (m.m.has('color')) mat.color = color(v('color'), 'look3d()');
        if (m.m.has('glow')) mat.emissive = v('glow') ? color(v('glow'), 'look3d()') : new (T().Color)(0);
        if (m.m.has('shiny')) mat.roughness = 1 - Math.max(0, Math.min(1, N(v('shiny'), 'look3d()')));
        if (m.m.has('metal')) mat.metalness = Math.max(0, Math.min(1, N(v('metal'), 'look3d()')));
        if (m.m.has('opacity')) { const a = Math.max(0, Math.min(1, N(v('opacity'), 'look3d()'))); mat.opacity = a; mat.transparent = a < 1; }
        if (m.m.has('wire')) mat.wireframe = !!v('wire');
        if (m.m.has('flat')) mat.flatShading = !!v('flat');
        if (m.m.has('texture')) {
          const t = v('texture'); if (mat.map && mat.map.src) h.st.liveTex.delete(mat.map);
          if (!t) mat.map = null;
          else if (t instanceof KHandle && t.kind === 'canvas') { const TH = T(); const ct = new TH.CanvasTexture(t.front || t.el); ct.src = t; ct.colorSpace = TH.SRGBColorSpace; h.st.liveTex.add(ct); mat.map = ct; }
          else { const name = S(t), key = name + '|' + mat.color.getHexString(); const st = h.st; mat.map = (st.texCache[key] = st.texCache[key] || proc(name, mat.color.clone())).clone(); mat.map.needsUpdate = true; mat.color = new (T().Color)(0xffffff); }
        }
        if (m.m.has('repeat') && mat.map) { const r = Math.max(0.01, N(v('repeat'), 'look3d()')); mat.map.repeat.set(r, r); }
        mat.needsUpdate = true; return null;
      }, 2, 2),
      show3d: B(([o, on]) => { ob(o, 'show3d()').o.visible = on === undefined ? true : !!on && on !== null; return null; }, 1, 2),
      remove3d: B(([o]) => {
        if (!(o instanceof KHandle) || o.kind !== 'object3d') throw new KError('remove3d() needs a 3D object'); if (o.gone) return null;
        const st = o.st; o.o.traverse((x) => { if (x.userData.h) { x.userData.h.gone = true; st.objects.delete(x.userData.h); } if (x.geometry) x.geometry.dispose(); if (x.material) { if (x.material.map) { st.liveTex.delete(x.material.map); x.material.map.dispose(); } x.material.dispose(); } });
        if (o.o.parent) o.o.parent.remove(o.o); if (st.follow && st.follow.h === o) st.follow = null; return null;
      }, 1, 1),
      exists3d: B(([o]) => o instanceof KHandle && o.kind === 'object3d' && !o.gone && !o.st.gone, 1, 1),
      tag3d: B(([o, t]) => { const h = ob(o, 'tag3d()'); if (t !== undefined) h.tag = t === null ? '' : S(t); return h.tag; }, 1, 2),
      find3d: B(([s, t]) => { const st = sc(s, 'find3d()'); const k = S(t); return [...st.objects].filter((h) => h.tag === k); }, 2, 2),
      solid3d: B(([o, on]) => { const h = ob(o, 'solid3d()'); h.solid = on === undefined ? true : !!on && on !== null; return null; }, 1, 2),
      count3d: B(([s]) => sc(s, 'count3d()').objects.size, 1, 1),
      size3d: B(([s]) => { const st = sc(s, 'size3d()'); const r = st.el.getBoundingClientRect(); return toK({ w: Math.round(st.fixedW || r.width), h: Math.round(st.fixedH || r.height) }); }, 1, 1),
      vec3: B(([x, y, z]) => toK({ x: N(x, 'vec3()', 0), y: N(y, 'vec3()', 0), z: N(z, 'vec3()', 0) }), 0, 3),
      dist3d: B(([a, b]) => { const p = vec(a, 'dist3d()'), q = vec(b, 'dist3d()'); return Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]); }, 2, 2),
      hits3d: B(([a, b]) => {
        const A = ob(a, 'hits3d()'), TH = T(); A.st.scene.updateMatrixWorld(); const ba = new TH.Box3().setFromObject(A.o);
        if (b instanceof KHandle) { const Bh = ob(b, 'hits3d()'); return Bh.o.visible && A.o.visible && ba.intersectsBox(new TH.Box3().setFromObject(Bh.o)); }
        const list = Array.isArray(b) ? b : (() => { const k = S(b); return [...A.st.objects].filter((h) => h.tag === k); })();
        for (const h of list) { if (!(h instanceof KHandle) || h.kind !== 'object3d' || h.gone || h === A || !h.o.visible) continue; if (ba.intersectsBox(new TH.Box3().setFromObject(h.o))) return h; }
        return null;
      }, 2, 2),
      ray3d: B(([s, from, dir, max]) => {
        const st = sc(s, 'ray3d()'), TH = T(); const f = vec(from, 'ray3d()'), d = vec(dir, 'ray3d()'); const D = new TH.Vector3(d[0], d[1], d[2]); if (D.lengthSq() === 0) throw new KError('ray3d(): direction cannot be (0, 0, 0)');
        const rc = new TH.Raycaster(new TH.Vector3(f[0], f[1], f[2]), D.normalize(), 0, N(max, 'ray3d()', 1000)); const x = rc.intersectObjects(pickable(st), true)[0]; return x ? withObj(x, hitOf(x)) : null;
      }, 3, 4),
      pick3d: B(([s, x, y]) => {
        const st = sc(s, 'pick3d()'), TH = T(); const r = st.el.getBoundingClientRect(); if (!r.width || !r.height) return null;
        const rc = new TH.Raycaster(); rc.setFromCamera(new TH.Vector2((N(x, 'pick3d()') / r.width) * 2 - 1, -(N(y, 'pick3d()') / r.height) * 2 + 1), st.camera); const hit = rc.intersectObjects(pickable(st), true)[0];
        return hit ? withObj(hit, hitOf(hit)) : null;
      }, 3, 3),
      camera3d: B(([s, x, y, z, lx, ly, lz]) => { const st = sc(s, 'camera3d()'); st.camera.position.set(N(x, 'camera3d()'), N(y, 'camera3d()'), N(z, 'camera3d()')); if (lx !== undefined && lx !== null) { st.camera.lookAt(N(lx, 'camera3d()'), N(ly, 'camera3d()'), N(lz, 'camera3d()')); readCam(st); } return null; }, 4, 7),
      camera_look: B(([s, x, y, z]) => { const st = sc(s, 'camera_look()'); const v = y === undefined ? vec(x, 'camera_look()') : [N(x, 'camera_look()'), N(y, 'camera_look()'), N(z, 'camera_look()')]; st.camera.lookAt(v[0], v[1], v[2]); readCam(st); return null; }, 2, 4),
      camera_angles: B(([s, yaw, pitch]) => { const st = sc(s, 'camera_angles()'); st.yaw = N(yaw, 'camera_angles()') * D2R; st.pitch = Math.max(-89, Math.min(89, N(pitch, 'camera_angles()', 0))) * D2R; applyCam(st); return null; }, 2, 3),
      camera_fov: B(([s, f]) => { const st = sc(s, 'camera_fov()'); st.camera.fov = Math.max(10, Math.min(150, N(f, 'camera_fov()'))); st.camera.updateProjectionMatrix(); return null; }, 2, 2),
      camera_get: B(([s]) => { const st = sc(s, 'camera_get()'); const p = st.camera.position, TH = T(); const d = new TH.Vector3(); st.camera.getWorldDirection(d);
        return toK({ x: +p.x.toFixed(4), y: +p.y.toFixed(4), z: +p.z.toFixed(4), yaw: +(st.yaw / D2R).toFixed(3), pitch: +(st.pitch / D2R).toFixed(3), fov: st.camera.fov, dir: { x: +d.x.toFixed(4), y: +d.y.toFixed(4), z: +d.z.toFixed(4) } }); }, 1, 1),
      camera_follow: B(([s, o, dx, dy, dz, smooth]) => {
        const st = sc(s, 'camera_follow()'); if (o === null || o === false || o === undefined) { st.follow = null; return null; }
        st.follow = { h: ob(o, 'camera_follow()'), dx: N(dx, 'camera_follow()', 0), dy: N(dy, 'camera_follow()', 3), dz: N(dz, 'camera_follow()', 6), ly: 0.5, smooth: N(smooth, 'camera_follow()', 8) }; st.fps = null; return null;
      }, 2, 6),
      fps_controls: B(([s, o]) => {
        const st = sc(s, 'fps_controls()'); if (o === false || o === null) { st.fps = null; if (document.pointerLockElement === st.el) document.exitPointerLock(); return null; }
        if (o !== undefined && !isMap(o) && o !== true) throw new KError('fps_controls() needs a map like {speed: 4, height: 1.6} (or false to turn off)');
        for (const k of (isMap(o) ? o.m.keys() : [])) if (!['speed', 'turn', 'look', 'height', 'radius', 'lock', 'fly', 'gravity', 'jump', 'arrows'].includes(k)) throw new KError('fps_controls(): unknown setting "' + k + '"');
        const height = N(opt(o, 'height', 1.6), 'fps_controls()');
        st.fps = { speed: N(opt(o, 'speed', 4), 'fps_controls()'), turn: N(opt(o, 'turn', 120), 'fps_controls()') * D2R, look: N(opt(o, 'look', 0.15), 'fps_controls()'), height, radius: N(opt(o, 'radius', 0.3), 'fps_controls()'),
          lock: !!opt(o, 'lock', true), fly: !!opt(o, 'fly', false), gravity: N(opt(o, 'gravity', 0), 'fps_controls()'), jump: N(opt(o, 'jump', 5), 'fps_controls()'), arrowsTurn: S(opt(o, 'arrows', 'turn')) === 'turn', vy: 0, onGround: true };
        st.follow = null; if (!st.fps.fly) st.camera.position.y = Math.max(st.camera.position.y, height); return null;
      }, 1, 2),
      gamepad: B(([i]) => toK(pad(i === undefined || i === null ? -1 : Math.max(0, Math.floor(N(i, 'gamepad()'))))) || toK({ connected: false }), 0, 1),
    };
    return api;
  }
  root.Kompass3D = { builtins, version: '1.5.2' };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.Kompass3D;
})(typeof window !== 'undefined' ? window : globalThis);
