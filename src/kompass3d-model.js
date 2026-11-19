/* Kompass 1.7 modelling built-ins for KampfScript, on top of src/kompass3d.js and the locally bundled three.js add-ons
 * (src/vendor/three-addons.min.js: GLTFExporter, GLTFLoader, OBJExporter, OBJLoader, OrbitControls).
 * They are generic (any page or Kugel Store app can use them) and power the Kugel 3D Modeler and Kugel Blocks 3D:
 *   - editable polygon meshes: mesh3d / mesh_get / mesh_set, vertex + face selection overlays, picking, box select,
 *     move / rotate / scale of a vertex set, extrude, delete, subdivide, flip, smooth shading
 *   - an orbit / pan / zoom camera (orbit3d), standard views, a ground grid with axes (grid3d)
 *   - project3d (3D point -> screen), snapshot3d (render to a PNG data URL), pixel_ratio3d (weak-PC mode)
 *   - export3d (OBJ text with quads + colours, glTF JSON, GLB data URL), import3d (OBJ / glTF / GLB -> editable meshes)
 *   - a shared model library (model_save / model_list / load_model / model_delete) kept in the Kompass profile, so a model
 *     made in the modeler can be used by any KampfScript 3D game with load_model(scene, "name").
 * Heavy work (geometry building, picking, extrude) happens here in JavaScript; apps keep their UI and logic in KampfScript. */
(function (root) {
  'use strict';
  const D2R = Math.PI / 180;
  const MAX_VERTS = 200000, MAX_FACES = 200000;

  // ---------- primitive polygon meshes (quads where possible, so extrude / OBJ export stay clean)
  function prim(kind, o) {
    const v = [], f = [];
    const seg = Math.max(3, Math.min(128, Math.round(o.segments || 0) || 0));
    if (kind === 'cube') {
      const s = (o.size || 1) / 2;
      for (const z of [-s, s]) for (const y of [-s, s]) for (const x of [-s, s]) v.push([x, y, z]);
      // index = x + 2y + 4z
      f.push([0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]);
    } else if (kind === 'plane') {
      const s = (o.size || 2) / 2, n = Math.max(1, Math.min(64, Math.round(o.divisions || 1)));
      for (let j = 0; j <= n; j++) for (let i = 0; i <= n; i++) v.push([-s + (2 * s * i) / n, 0, -s + (2 * s * j) / n]);
      for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) { const a = j * (n + 1) + i; f.push([a, a + n + 1, a + n + 2, a + 1]); }
    } else if (kind === 'sphere') {
      const r = o.radius || 0.5, w = o.segments ? seg : 24, h = Math.max(3, Math.round(w / 2));
      v.push([0, r, 0]);
      for (let j = 1; j < h; j++) { const t = (j / h) * Math.PI; for (let i = 0; i < w; i++) { const p = (i / w) * Math.PI * 2; v.push([r * Math.sin(t) * Math.cos(p), r * Math.cos(t), -r * Math.sin(t) * Math.sin(p)]); } }
      v.push([0, -r, 0]); const bot = v.length - 1, ring = (j, i) => 1 + (j - 1) * w + ((i + w) % w);
      for (let i = 0; i < w; i++) f.push([0, ring(1, i), ring(1, i + 1)]);
      for (let j = 1; j < h - 1; j++) for (let i = 0; i < w; i++) f.push([ring(j, i), ring(j + 1, i), ring(j + 1, i + 1), ring(j, i + 1)]);
      for (let i = 0; i < w; i++) f.push([ring(h - 1, i), bot, ring(h - 1, i + 1)]);
    } else if (kind === 'cylinder' || kind === 'cone') {
      const r = o.radius || 0.5, hh = (o.height || 1) / 2, n = o.segments ? seg : 24, cone = kind === 'cone';
      for (let i = 0; i < n; i++) { const p = (i / n) * Math.PI * 2; v.push([r * Math.cos(p), -hh, -r * Math.sin(p)]); }
      if (cone) { v.push([0, hh, 0]); const top = n; for (let i = 0; i < n; i++) f.push([i, (i + 1) % n, top]); }
      else { for (let i = 0; i < n; i++) { const p = (i / n) * Math.PI * 2; v.push([r * Math.cos(p), hh, -r * Math.sin(p)]); } for (let i = 0; i < n; i++) f.push([i, (i + 1) % n, n + (i + 1) % n, n + i]); const cap = []; for (let i = 0; i < n; i++) cap.push(n + i); f.push(cap); }
      const bottom = []; for (let i = n - 1; i >= 0; i--) bottom.push(i); f.push(bottom);
    } else if (kind === 'torus') {
      const R = o.radius || 0.5, tr = o.tube || 0.15, n = o.segments ? seg : 32, m = Math.max(3, Math.round(n / 2.5));
      for (let i = 0; i < n; i++) { const u = (i / n) * Math.PI * 2; for (let j = 0; j < m; j++) { const w2 = (j / m) * Math.PI * 2; const d = R + tr * Math.cos(w2); v.push([d * Math.cos(u), tr * Math.sin(w2), -d * Math.sin(u)]); } }
      const id = (i, j) => ((i + n) % n) * m + ((j + m) % m);
      for (let i = 0; i < n; i++) for (let j = 0; j < m; j++) f.push([id(i, j), id(i + 1, j), id(i + 1, j + 1), id(i, j + 1)]);
    } else return null;
    return { v, f };
  }

  // ---------- small vector helpers
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
  function faceNormal(v, face) {   // Newell's method: works for any planar-ish polygon
    let x = 0, y = 0, z = 0;
    for (let i = 0; i < face.length; i++) { const a = v[face[i]], b = v[face[(i + 1) % face.length]]; x += (a[1] - b[1]) * (a[2] + b[2]); y += (a[2] - b[2]) * (a[0] + b[0]); z += (a[0] - b[0]) * (a[1] + b[1]); }
    return norm([x, y, z]);
  }
  function compact(m) {   // drop unused vertices; returns old -> new index map
    const used = new Int32Array(m.v.length).fill(-1); const nv = [];
    for (const f of m.f) for (const i of f) if (used[i] < 0) { used[i] = nv.length; nv.push(m.v[i]); }
    m.v = nv; m.f = m.f.map((f) => f.map((i) => used[i])); return used;
  }
  function edgesOf(m) {
    const seen = new Set(), out = [];
    for (const f of m.f) for (let i = 0; i < f.length; i++) { const a = f[i], b = f[(i + 1) % f.length]; const k = a < b ? a + ',' + b : b + ',' + a; if (!seen.has(k)) { seen.add(k); out.push([a, b]); } }
    return out;
  }
  function weld(v, f, eps) {   // merge vertices at the same position (imports arrive as separate triangles)
    const map = new Map(), idx = new Int32Array(v.length), nv = []; const q = (x) => Math.round(x / eps);
    for (let i = 0; i < v.length; i++) { const k = q(v[i][0]) + ',' + q(v[i][1]) + ',' + q(v[i][2]); let j = map.get(k); if (j === undefined) { j = nv.length; nv.push(v[i]); map.set(k, j); } idx[i] = j; }
    const nf = []; for (const face of f) { const g = face.map((i) => idx[i]).filter((x, i, a) => x !== a[(i + 1) % a.length]); if (g.length >= 3 && new Set(g).size === g.length) nf.push(g); }
    return { v: nv, f: nf };
  }
  function trisToQuads(m) {   // pair up coplanar triangles that share an edge into quads (cleaner meshes after a GLB import)
    const tri = m.f.map((f, i) => f.length === 3 ? i : -1).filter((i) => i >= 0); const edge = new Map(); const used = new Set(); const out = [];
    for (const i of tri) { const f = m.f[i]; for (let k = 0; k < 3; k++) { const a = f[k], b = f[(k + 1) % 3]; const key = a < b ? a + ',' + b : b + ',' + a; if (!edge.has(key)) edge.set(key, []); edge.get(key).push([i, k]); } }
    for (const i of tri) {
      if (used.has(i)) continue; const f = m.f[i], n1 = faceNormal(m.v, f); let best = null, bestDot = 0.9999;
      for (let k = 0; k < 3; k++) { const a = f[k], b = f[(k + 1) % 3]; const key = a < b ? a + ',' + b : b + ',' + a; for (const [j] of edge.get(key)) { if (j === i || used.has(j)) continue; const g = m.f[j], n2 = faceNormal(m.v, g); const d = n1[0] * n2[0] + n1[1] * n2[1] + n1[2] * n2[2]; if (d > bestDot) { bestDot = d; best = [j, k]; } } }
      if (!best) continue; const [j, k] = best; const g = m.f[j]; const a = f[k], b = f[(k + 1) % 3], c = f[(k + 2) % 3]; const d = g.find((x) => x !== a && x !== b);
      if (d === undefined) continue; used.add(i); used.add(j); out.push([i, [c, a, d, b]]);
    }
    const keep = m.f.filter((_, i) => !used.has(i)); for (const [, q] of out) keep.push(q); m.f = keep; return m;
  }

  function builtins(c) {
    const { B, K, KError, KMap, KHandle, toK, S, N, T, sc, ob, addObj, color, vec, readCam, isMap, opt, size } = c;
    const A = () => { if (!root.THREE_ADDONS) throw new KError('3D model tools are not available (three.js add-ons did not load)'); return root.THREE_ADDONS; };
    const r4 = (x) => +(+x).toFixed(5);
    const noRay = (o) => { o.raycast = () => {}; return o; };
    const isEditable = (h) => h && h.mesh;
    const ed = (x, who) => { const h = ob(x, who); if (!h.mesh) throw new KError(who + ' needs an editable mesh from mesh3d()'); return h; };
    const idxList = (l, n, who) => { if (l === undefined || l === null) return []; if (!Array.isArray(l)) throw new KError(who + ': expected a list of numbers'); const out = []; for (const x of l) { const i = Math.floor(+x); if (i >= 0 && i < n) out.push(i); } return [...new Set(out)]; };

    // ---- build / rebuild the three.js geometry from the polygon mesh
    function rebuild(h) {
      const TH = T(), m = h.mesh, pos = [], nor = [], triFace = [];
      let vn = null;
      if (h.smooth) { vn = m.v.map(() => [0, 0, 0]); for (const f of m.f) { const n = faceNormal(m.v, f); for (const i of f) { vn[i][0] += n[0]; vn[i][1] += n[1]; vn[i][2] += n[2]; } } vn = vn.map(norm); }
      for (let fi = 0; fi < m.f.length; fi++) {
        const f = m.f[fi]; const n = faceNormal(m.v, f);
        for (let k = 1; k < f.length - 1; k++) {
          for (const i of [f[0], f[k], f[k + 1]]) { const p = m.v[i]; pos.push(p[0], p[1], p[2]); const q = vn ? vn[i] : n; nor.push(q[0], q[1], q[2]); }
          triFace.push(fi);
        }
      }
      const g = new TH.BufferGeometry(); g.setAttribute('position', new TH.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new TH.Float32BufferAttribute(nor, 3));
      g.computeBoundingBox(); g.computeBoundingSphere();
      if (h.o.geometry) h.o.geometry.dispose(); h.o.geometry = g; h.triFace = triFace;
      if (h.edit) buildOverlay(h);
    }
    function buildOverlay(h) {
      const TH = T(), m = h.mesh;
      if (h.overlay) { h.o.remove(h.overlay); h.overlay.traverse((x) => { if (x.geometry) x.geometry.dispose(); if (x.material) x.material.dispose(); }); h.overlay = null; }
      if (!h.edit) return;
      const grp = noRay(new TH.Group());
      const ep = []; for (const [a, b] of edgesOf(m)) { const p = m.v[a], q = m.v[b]; ep.push(p[0], p[1], p[2], q[0], q[1], q[2]); }
      const eg = new TH.BufferGeometry(); eg.setAttribute('position', new TH.Float32BufferAttribute(ep, 3));
      grp.add(noRay(new TH.LineSegments(eg, new TH.LineBasicMaterial({ color: h.edgeColor || 0x111111, transparent: true, opacity: 0.85 }))));
      const sv = h.selV || new Set(), sf = h.selF || new Set();
      if (h.showVerts !== false) {
        const vp = [], vc = []; for (let i = 0; i < m.v.length; i++) { const p = m.v[i]; vp.push(p[0], p[1], p[2]); if (sv.has(i)) vc.push(1, 0.55, 0.1); else vc.push(0.05, 0.05, 0.05); }
        const vg = new TH.BufferGeometry(); vg.setAttribute('position', new TH.Float32BufferAttribute(vp, 3)); vg.setAttribute('color', new TH.Float32BufferAttribute(vc, 3));
        grp.add(noRay(new TH.Points(vg, new TH.PointsMaterial({ size: 7, sizeAttenuation: false, vertexColors: true, depthTest: true }))));
      }
      if (sf.size) {
        const fp = []; for (const fi of sf) { const f = m.f[fi]; if (!f) continue; for (let k = 1; k < f.length - 1; k++) for (const i of [f[0], f[k], f[k + 1]]) { const p = m.v[i]; fp.push(p[0], p[1], p[2]); } }
        const fg = new TH.BufferGeometry(); fg.setAttribute('position', new TH.Float32BufferAttribute(fp, 3));
        grp.add(noRay(new TH.Mesh(fg, new TH.MeshBasicMaterial({ color: 0xff8c1a, transparent: true, opacity: 0.38, side: TH.DoubleSide, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }))));
      }
      h.overlay = grp; h.o.add(grp);
    }
    function makeEditable(st, data, colr, who) {
      const TH = T();
      const mat = new TH.MeshStandardMaterial({ color: colr === undefined || colr === null ? 0xb8bcc4 : color(colr, who), roughness: 0.7, metalness: 0.05, side: TH.DoubleSide, polygonOffset: true, polygonOffsetFactor: 1, polygonOffsetUnits: 1 });
      const o = new TH.Mesh(new TH.BufferGeometry(), mat);
      const h = addObj(st, o, who, { mesh: { v: data.v, f: data.f }, smooth: false, edit: false, selV: new Set(), selF: new Set(), name: '' });
      rebuild(h); return h;
    }
    const readData = (d, who) => {
      if (!isMap(d)) throw new KError(who + ': mesh data must be a map {verts: [[x, y, z], ...], faces: [[0, 1, 2, 3], ...]}');
      const vs = d.m.get('verts'), fs = d.m.get('faces'); if (!Array.isArray(vs) || !Array.isArray(fs)) throw new KError(who + ': mesh data needs verts and faces lists');
      if (vs.length > MAX_VERTS || fs.length > MAX_FACES) throw new KError(who + ': mesh too big (max ' + MAX_VERTS + ' vertices)');
      const v = vs.map((p) => vec(p, who)); const f = [];
      for (const face of fs) { if (!Array.isArray(face) || face.length < 3) continue; const g = face.map((x) => Math.floor(+x)); if (g.every((i) => i >= 0 && i < v.length)) f.push(g); }
      return { v, f };
    };
    const centerOf = (h, verts) => { const TH = T(); h.o.updateWorldMatrix(true, false); const p = new TH.Vector3(); let n = 0, x = 0, y = 0, z = 0; for (const i of verts) { const q = h.mesh.v[i]; p.set(q[0], q[1], q[2]).applyMatrix4(h.o.matrixWorld); x += p.x; y += p.y; z += p.z; n++; } return n ? [x / n, y / n, z / n] : null; };
    const camOf = (st) => { st.scene.updateMatrixWorld(); st.camera.updateMatrixWorld(); return st.camera; };
    const rectOf = (st) => st.el.getBoundingClientRect();
    function screen(st, p) {   // world point -> pixels inside the scene element
      const TH = T(), r = rectOf(st), q = new TH.Vector3(p[0], p[1], p[2]).project(camOf(st));
      return { x: (q.x + 1) / 2 * r.width, y: (1 - q.y) / 2 * r.height, z: q.z, ok: q.z > -1 && q.z < 1 };
    }
    const meshesOf = (st, x) => {
      if (x === undefined || x === null) return [...st.objects].filter((h) => h.mesh && h.o.visible && !h.gone);
      const l = Array.isArray(x) ? x : [x]; return l.filter((h) => h instanceof KHandle && h.mesh && !h.gone);
    };
    // ---- export helpers
    function exportScene(list) {   // a clean three.js scene with copies of the chosen objects (no overlays, helpers or lights)
      const TH = T(), sc2 = new TH.Scene();
      for (const h of list) {
        if (!(h instanceof KHandle) || h.kind !== 'object3d' || h.gone) continue; h.o.updateWorldMatrix(true, true);
        const add = (o, name) => { if (!o.isMesh || !o.geometry) return; const m = new TH.Mesh(o.geometry, o.material); m.name = name || o.name || 'object'; o.matrixWorld.decompose(m.position, m.quaternion, m.scale); sc2.add(m); };
        let k = 0; h.o.traverse((o) => { if (o.userData.noExport) return; if (o.parent && o.parent.userData && o.parent.userData.noExport) return; if (o === h.overlay || (h.overlay && isChild(o, h.overlay))) return; if (o.isMesh) add(o, (h.name || 'object') + (k++ ? '_' + k : '')); });
      }
      return sc2;
    }
    const isChild = (o, p) => { while (o) { if (o === p) return true; o = o.parent; } return false; };
    function objText(list) {   // OBJ with polygons (quads stay quads) and vertex colours (Blender reads them)
      const TH = T(); let out = '# Kugel 3D Modeler / Kompass OBJ export\n', base = 1;
      for (const h of list) {
        if (!(h instanceof KHandle) || h.gone) continue; h.o.updateWorldMatrix(true, true);
        if (!h.mesh) { const ex = new (A().OBJExporter)(); out += ex.parse(exportScene([h])).replace(/^# .*\n/, ''); continue; }
        const hex = h.o.material && h.o.material.color ? h.o.material.color.getHexString() : 'cccccc'; const col = { r: parseInt(hex.slice(0, 2), 16) / 255, g: parseInt(hex.slice(2, 4), 16) / 255, b: parseInt(hex.slice(4, 6), 16) / 255 };   // sRGB, as OBJ viewers expect
        out += 'o ' + String(h.name || 'object').replace(/\s+/g, '_') + '\n'; const p = new TH.Vector3();
        for (const v of h.mesh.v) { p.set(v[0], v[1], v[2]).applyMatrix4(h.o.matrixWorld); out += 'v ' + r4(p.x) + ' ' + r4(p.y) + ' ' + r4(p.z) + ' ' + r4(col.r) + ' ' + r4(col.g) + ' ' + r4(col.b) + '\n'; }
        for (const f of h.mesh.f) out += 'f ' + f.map((i) => i + base).join(' ') + '\n';
        base += h.mesh.v.length;
      }
      return out;
    }
    const b64 = (buf) => { const u = new Uint8Array(buf); let s = ''; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
    const unb64 = (s) => { const bin = atob(s); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u.buffer; };
    async function exportAs(list, fmt) {
      const f = String(fmt || 'glb').toLowerCase();
      if (f === 'obj') return objText(list);
      if (f !== 'gltf' && f !== 'glb') throw new KError('export3d(): format is "obj", "gltf" or "glb"');
      const ex = new (A().GLTFExporter)(); const sc2 = exportScene(list);
      const res = await ex.parseAsync(sc2, { binary: f === 'glb' });
      return f === 'glb' ? 'data:model/gltf-binary;base64,' + b64(res) : JSON.stringify(res);
    }
    function dataKind(d) {
      if (d.startsWith('data:model/gltf-binary') || d.startsWith('data:application/octet-stream')) return 'glb';
      if (/^\s*\{/.test(d)) return 'gltf'; if (/^\s*(#|o |v |g |mtllib|usemtl|vn |vt |s )/m.test(d)) return 'obj'; return '';
    }
    async function loadThree(data, kind) {   // -> three.js Object3D
      const d = String(data); const k = (kind ? String(kind).toLowerCase() : '') || dataKind(d);
      if (k === 'obj') return new (A().OBJLoader)().parse(d);
      if (k !== 'gltf' && k !== 'glb') throw new KError('import3d(): could not tell the format (OBJ text, glTF JSON or a GLB data URL)');
      const buf = k === 'glb' ? unb64(d.slice(d.indexOf(',') + 1)) : d;
      const gl = await new Promise((ok, bad) => new (A().GLTFLoader)().parse(buf, '', ok, bad)).catch((e) => { throw new KError('import3d(): could not read the model: ' + (e && e.message || e)); });
      return gl.scene || (gl.scenes && gl.scenes[0]);
    }
    function toEditable(st, o3, who) {   // every mesh inside -> one editable mesh3d (welded, triangle pairs -> quads)
      const TH = T(), out = []; o3.updateMatrixWorld(true); let n = 0;
      o3.traverse((m) => {
        if (!m.isMesh || !m.geometry) return; const g = m.geometry; const pa = g.getAttribute('position'); if (!pa) return;
        if (++n > 200) return;
        const v = [], f = [], p = new TH.Vector3(); for (let i = 0; i < pa.count; i++) { p.fromBufferAttribute(pa, i).applyMatrix4(m.matrixWorld); v.push([p.x, p.y, p.z]); }
        const ix = g.getIndex(); const cnt = ix ? ix.count : pa.count; for (let i = 0; i + 2 < cnt; i += 3) f.push(ix ? [ix.getX(i), ix.getX(i + 1), ix.getX(i + 2)] : [i, i + 1, i + 2]);
        const mesh = trisToQuads(weld(v, f, 1e-5)); compact(mesh);
        const mat = Array.isArray(m.material) ? m.material[0] : m.material; let col = mat && mat.color ? '#' + mat.color.getHexString() : null;
        const ca = g.getAttribute('color'); if (ca && ca.count && mat && mat.vertexColors && ca.getX(0) !== undefined) col = '#' + new TH.Color().setRGB(ca.getX(0), ca.getY(0), ca.getZ(0)).getHexString();   // OBJ vertex colours
        const h = makeEditable(st, mesh, col, who); h.name = m.name || ('object' + n); out.push(h);
      });
      return out;
    }
    const nameOk = (n, who) => { const s = String(S(n)).trim(); if (!/^[A-Za-z0-9 _-]{1,40}$/.test(s)) throw new KError(who + ': a model name uses letters, digits, spaces, _ or - (max 40)'); return s; };
    const lib = () => { const nat = root.native && root.native.models; if (!nat) throw new KError('the model library needs Kompass 1.7 for Windows'); return nat; };

    return {
      // ---------- editable meshes
      mesh3d: B(([s, what, c1, o]) => {
        const st = sc(s, 'mesh3d()'); let data;
        if (isMap(what)) data = readData(what, 'mesh3d()');
        else {
          const k = S(what); const opts = {}; if (isMap(o)) for (const key of ['size', 'radius', 'height', 'tube', 'segments', 'divisions']) if (o.m.has(key)) opts[key] = N(o.m.get(key), 'mesh3d()');
          data = prim(k, opts); if (!data) throw new KError('mesh3d(): shape is "cube", "sphere", "cylinder", "cone", "plane", "torus" or a map {verts, faces}');
        }
        return makeEditable(st, data, c1, 'mesh3d()');
      }, 2, 4),
      mesh_get: B(([o]) => { const h = ed(o, 'mesh_get()'); return toK({ verts: h.mesh.v.map((p) => [r4(p[0]), r4(p[1]), r4(p[2])]), faces: h.mesh.f.map((f) => f.slice()) }); }, 1, 1),
      mesh_set: B(([o, d]) => { const h = ed(o, 'mesh_set()'); const m = readData(d, 'mesh_set()'); h.mesh = m; h.selV = new Set([...h.selV].filter((i) => i < m.v.length)); h.selF = new Set([...h.selF].filter((i) => i < m.f.length)); rebuild(h); return null; }, 2, 2),
      mesh_info: B(([o]) => { const h = ed(o, 'mesh_info()'); return toK({ verts: h.mesh.v.length, faces: h.mesh.f.length, edges: edgesOf(h.mesh).length, tris: h.triFace.length, smooth: !!h.smooth }); }, 1, 1),
      mesh_edit: B(([o, on, opts]) => { const h = ed(o, 'mesh_edit()'); h.edit = on === undefined ? true : !!on && on !== null; h.showVerts = !(isMap(opts) && opts.m.get('verts') === false); h.edgeColor = isMap(opts) && opts.m.get('edges') ? color(opts.m.get('edges'), 'mesh_edit()') : null; buildOverlay(h); return null; }, 1, 3),
      mesh_select: B(([o, vs, fs]) => {
        const h = ed(o, 'mesh_select()'); h.selV = new Set(idxList(vs, h.mesh.v.length, 'mesh_select()')); h.selF = new Set(idxList(fs, h.mesh.f.length, 'mesh_select()'));
        if (h.edit) buildOverlay(h); return null;
      }, 2, 3),
      mesh_face_verts: B(([o, fs]) => { const h = ed(o, 'mesh_face_verts()'); const out = new Set(); for (const fi of idxList(fs, h.mesh.f.length, 'mesh_face_verts()')) for (const i of h.mesh.f[fi]) out.add(i); return [...out].sort((a, b) => a - b); }, 2, 2),
      mesh_faces_of: B(([o, vs]) => { const h = ed(o, 'mesh_faces_of()'); const S2 = new Set(idxList(vs, h.mesh.v.length, 'mesh_faces_of()')); const out = []; h.mesh.f.forEach((f, i) => { if (f.every((x) => S2.has(x))) out.push(i); }); return out; }, 2, 2),
      mesh_pick: B(([s, x, y, objs]) => {
        const st = sc(s, 'mesh_pick()'), TH = T(); const r = rectOf(st); if (!r.width || !r.height) return null;
        const list = meshesOf(st, objs).map((h) => h.o); camOf(st);
        const rc = new TH.Raycaster(); rc.setFromCamera(new TH.Vector2((N(x, 'mesh_pick()') / r.width) * 2 - 1, -(N(y, 'mesh_pick()') / r.height) * 2 + 1), st.camera);
        const hit = rc.intersectObjects(list, false)[0]; if (!hit) return null;
        const h = hit.object.userData.h; const fi = h.triFace[hit.faceIndex] ?? -1; let vi = -1, best = Infinity;
        if (fi >= 0) for (const i of h.mesh.f[fi]) { const p = h.mesh.v[i]; const w = new TH.Vector3(p[0], p[1], p[2]).applyMatrix4(h.o.matrixWorld); const sp = screen(st, [w.x, w.y, w.z]); const d = Math.hypot(sp.x - x, sp.y - y); if (d < best) { best = d; vi = i; } }
        const res = toK({ obj: null, face: fi, vertex: vi, vertex_px: Math.round(best), dist: r4(hit.distance), x: r4(hit.point.x), y: r4(hit.point.y), z: r4(hit.point.z) }); res.m.set('obj', h); return res;
      }, 3, 4),
      mesh_vertex_at: B(([s, o, x, y, px]) => {   // nearest vertex on screen within px (front-most wins)
        const st = sc(s, 'mesh_vertex_at()'), h = ed(o, 'mesh_vertex_at()'), TH = T(); const R = N(px, 'mesh_vertex_at()', 12); camOf(st); h.o.updateWorldMatrix(true, false);
        let best = -1, bd = Infinity; const w = new TH.Vector3();
        for (let i = 0; i < h.mesh.v.length; i++) { const p = h.mesh.v[i]; w.set(p[0], p[1], p[2]).applyMatrix4(h.o.matrixWorld); const sp = screen(st, [w.x, w.y, w.z]); if (!sp.ok) continue; const d = Math.hypot(sp.x - x, sp.y - y); if (d <= R && d + sp.z * 2 < bd) { bd = d + sp.z * 2; best = i; } }
        return best;
      }, 4, 5),
      mesh_box_select: B(([s, o, x1, y1, x2, y2]) => {
        const st = sc(s, 'mesh_box_select()'), h = ed(o, 'mesh_box_select()'), TH = T(); camOf(st); h.o.updateWorldMatrix(true, false);
        const ax = Math.min(x1, x2), bx = Math.max(x1, x2), ay = Math.min(y1, y2), by = Math.max(y1, y2), out = [], w = new TH.Vector3();
        for (let i = 0; i < h.mesh.v.length; i++) { const p = h.mesh.v[i]; w.set(p[0], p[1], p[2]).applyMatrix4(h.o.matrixWorld); const sp = screen(st, [w.x, w.y, w.z]); if (sp.ok && sp.x >= ax && sp.x <= bx && sp.y >= ay && sp.y <= by) out.push(i); }
        return out;
      }, 6, 6),
      mesh_center: B(([o, vs]) => { const h = ed(o, 'mesh_center()'); const l = vs === undefined || vs === null ? h.mesh.v.map((_, i) => i) : idxList(vs, h.mesh.v.length, 'mesh_center()'); const c2 = centerOf(h, l); return c2 ? toK({ x: r4(c2[0]), y: r4(c2[1]), z: r4(c2[2]) }) : null; }, 1, 2),
      mesh_normal: B(([o, fs]) => {   // average world-space normal of some faces
        const h = ed(o, 'mesh_normal()'), TH = T(); const l = idxList(fs, h.mesh.f.length, 'mesh_normal()'); let n = [0, 0, 0];
        for (const fi of l) { const q = faceNormal(h.mesh.v, h.mesh.f[fi]); n = [n[0] + q[0], n[1] + q[1], n[2] + q[2]]; }
        h.o.updateWorldMatrix(true, false); const v = new TH.Vector3(n[0], n[1], n[2]).transformDirection(h.o.matrixWorld); return toK({ x: r4(v.x), y: r4(v.y), z: r4(v.z) });
      }, 2, 2),
      mesh_snapshot: B(([o]) => { const h = ed(o, 'mesh_snapshot()'); h.snap = h.mesh.v.map((p) => p.slice()); return null; }, 1, 1),
      // move / rotate / scale some vertices in WORLD space; {move: [x,y,z], rotate: [rx,ry,rz] (degrees), scale: [sx,sy,sz] or k, center: point, from_snapshot: true}
      mesh_transform: B(([o, vs, t]) => {
        const h = ed(o, 'mesh_transform()'), TH = T(); if (!isMap(t)) throw new KError('mesh_transform() needs a map like {move: [0, 1, 0]} / {rotate: [0, 45, 0]} / {scale: 2}');
        const l = vs === undefined || vs === null ? h.mesh.v.map((_, i) => i) : idxList(vs, h.mesh.v.length, 'mesh_transform()');
        const base = opt(t, 'from_snapshot', false) && h.snap && h.snap.length === h.mesh.v.length ? h.snap : h.mesh.v;
        h.o.updateWorldMatrix(true, false); const W = h.o.matrixWorld, inv = W.clone().invert();
        const cen = t.m.has('center') ? vec(t.m.get('center'), 'mesh_transform()') : (() => { const sv = h.mesh.v; h.mesh.v = base; const c2 = centerOf(h, l); h.mesh.v = sv; return c2 || [0, 0, 0]; })();
        const mv = t.m.has('move') ? vec(t.m.get('move'), 'mesh_transform()') : [0, 0, 0];
        const rt = t.m.has('rotate') ? vec(t.m.get('rotate'), 'mesh_transform()') : [0, 0, 0];
        const scv = t.m.get('scale'); const scl = scv === undefined || scv === null ? [1, 1, 1] : typeof scv === 'number' ? [scv, scv, scv] : vec(scv, 'mesh_transform()');
        const q = new TH.Quaternion().setFromEuler(new TH.Euler(rt[0] * D2R, rt[1] * D2R, rt[2] * D2R, 'XYZ')); const C = new TH.Vector3(cen[0], cen[1], cen[2]); const p = new TH.Vector3();
        const nv = h.mesh.v.map((x) => x.slice());
        for (const i of l) { const b = base[i]; p.set(b[0], b[1], b[2]).applyMatrix4(W).sub(C); p.set(p.x * scl[0], p.y * scl[1], p.z * scl[2]).applyQuaternion(q).add(C); p.x += mv[0]; p.y += mv[1]; p.z += mv[2]; p.applyMatrix4(inv); nv[i] = [p.x, p.y, p.z]; }
        h.mesh.v = nv; rebuild(h); return null;
      }, 3, 3),
      // extrude faces as one region; returns {faces, verts} = the moved (top) faces and their vertices
      mesh_extrude: B(([o, fs, dist]) => {
        const h = ed(o, 'mesh_extrude()'); const m = h.mesh; const sel = idxList(fs, m.f.length, 'mesh_extrude()'); if (!sel.length) return toK({ faces: [], verts: [] });
        const S2 = new Set(sel); const cnt = new Map(); const key = (a, b) => a < b ? a + ',' + b : b + ',' + a;
        for (const fi of sel) { const f = m.f[fi]; for (let i = 0; i < f.length; i++) { const k = key(f[i], f[(i + 1) % f.length]); cnt.set(k, (cnt.get(k) || 0) + 1); } }
        const dup = new Map(); const nid = (i) => { if (!dup.has(i)) { dup.set(i, m.v.length); m.v.push(m.v[i].slice()); } return dup.get(i); };
        let n = [0, 0, 0]; for (const fi of sel) { const q = faceNormal(m.v, m.f[fi]); n = [n[0] + q[0], n[1] + q[1], n[2] + q[2]]; } n = norm(n);
        const sides = [];
        for (const fi of sel) { const f = m.f[fi]; for (let i = 0; i < f.length; i++) { const a = f[i], b = f[(i + 1) % f.length]; if (cnt.get(key(a, b)) === 1) sides.push([a, b, nid(b), nid(a)]); } }
        for (const fi of sel) m.f[fi] = m.f[fi].map(nid);
        const d = N(dist, 'mesh_extrude()', 0); for (const [, j] of dup) { m.v[j] = [m.v[j][0] + n[0] * d, m.v[j][1] + n[1] * d, m.v[j][2] + n[2] * d]; }
        for (const sd of sides) m.f.push(sd);
        const map = compact(m); const topV = [...dup.values()].map((j) => map[j]).filter((x) => x >= 0);
        h.selV = new Set(topV); h.selF = new Set(sel); rebuild(h);
        return toK({ faces: sel, verts: topV.sort((a, b) => a - b) });
      }, 2, 3),
      mesh_delete: B(([o, fs, vs]) => {
        const h = ed(o, 'mesh_delete()'); const m = h.mesh; const F = new Set(idxList(fs, m.f.length, 'mesh_delete()')); const V = new Set(idxList(vs, m.v.length, 'mesh_delete()'));
        m.f = m.f.filter((f, i) => !F.has(i) && !f.some((x) => V.has(x))); compact(m); h.selV = new Set(); h.selF = new Set(); rebuild(h); return toK({ verts: m.v.length, faces: m.f.length });
      }, 2, 3),
      mesh_flip: B(([o, fs]) => { const h = ed(o, 'mesh_flip()'); const l = fs === undefined || fs === null ? h.mesh.f.map((_, i) => i) : idxList(fs, h.mesh.f.length, 'mesh_flip()'); for (const i of l) h.mesh.f[i] = h.mesh.f[i].slice().reverse(); rebuild(h); return null; }, 1, 2),
      mesh_subdivide: B(([o]) => {   // every n-gon -> n quads (edge midpoints + face centre); smooth it with mesh_smooth for rounder shapes
        const h = ed(o, 'mesh_subdivide()'); const m = h.mesh; if (m.f.length * 4 > MAX_FACES) throw new KError('mesh_subdivide(): the mesh would get too big');
        const v = m.v.map((p) => p.slice()), f = [], mid = new Map();
        const em = (a, b) => { const k = a < b ? a + ',' + b : b + ',' + a; if (!mid.has(k)) { mid.set(k, v.length); v.push([(v[a][0] + v[b][0]) / 2, (v[a][1] + v[b][1]) / 2, (v[a][2] + v[b][2]) / 2]); } return mid.get(k); };
        for (const face of m.f) { const c2 = [0, 0, 0]; for (const i of face) { c2[0] += m.v[i][0] / face.length; c2[1] += m.v[i][1] / face.length; c2[2] += m.v[i][2] / face.length; } const ci = v.length; v.push(c2);
          for (let i = 0; i < face.length; i++) { const a = face[i], prev = face[(i + face.length - 1) % face.length], next = face[(i + 1) % face.length]; f.push([a, em(a, next), ci, em(prev, a)]); } }
        h.mesh = { v, f }; h.selV = new Set(); h.selF = new Set(); rebuild(h); return toK({ verts: v.length, faces: f.length });
      }, 1, 1),
      mesh_smooth: B(([o, on]) => { const h = ed(o, 'mesh_smooth()'); h.smooth = on === undefined ? true : !!on && on !== null; rebuild(h); return null; }, 1, 2),
      mesh_merge: B(([o, vs]) => {   // merge vertices into their centre (Blender: M -> At Center)
        const h = ed(o, 'mesh_merge()'); const m = h.mesh; const l = idxList(vs, m.v.length, 'mesh_merge()'); if (l.length < 2) return null;
        const c2 = [0, 0, 0]; for (const i of l) { c2[0] += m.v[i][0] / l.length; c2[1] += m.v[i][1] / l.length; c2[2] += m.v[i][2] / l.length; }
        const keep = l[0]; m.v[keep] = c2; const S2 = new Set(l);
        m.f = m.f.map((f) => f.map((i) => S2.has(i) ? keep : i).filter((x, i, a) => x !== a[(i + 1) % a.length])).filter((f) => f.length >= 3 && new Set(f).size === f.length);
        compact(m); h.selV = new Set(); h.selF = new Set(); rebuild(h); return null;
      }, 2, 2),
      mesh_join: B(([a, b]) => {   // put b's polygons into a (world positions kept) and remove b
        const A1 = ed(a, 'mesh_join()'), B1 = ed(b, 'mesh_join()'), TH = T(); if (A1 === B1) return null;
        A1.o.updateWorldMatrix(true, false); B1.o.updateWorldMatrix(true, false); const inv = A1.o.matrixWorld.clone().invert(); const p = new TH.Vector3(); const base = A1.mesh.v.length;
        for (const q of B1.mesh.v) { p.set(q[0], q[1], q[2]).applyMatrix4(B1.o.matrixWorld).applyMatrix4(inv); A1.mesh.v.push([p.x, p.y, p.z]); }
        for (const f of B1.mesh.f) A1.mesh.f.push(f.map((i) => i + base));
        rebuild(A1); return null;
      }, 2, 2),
      name3d: B(([o, n]) => { const h = ob(o, 'name3d()'); if (n !== undefined) h.name = n === null ? '' : String(S(n)).slice(0, 60); return h.name || ''; }, 1, 2),
      material3d: B(([o]) => { const h = ob(o, 'material3d()'); const m = h.o.material; if (!m || !m.color) return null; return toK({ color: '#' + m.color.getHexString(), glow: m.emissive ? '#' + m.emissive.getHexString() : '#000000', shiny: r4(1 - (m.roughness ?? 1)), metal: r4(m.metalness || 0), opacity: r4(m.opacity ?? 1), wire: !!m.wireframe }); }, 1, 1),
      clone3d: B(([o]) => {
        const h = ob(o, 'clone3d()'); if (h.gone) throw new KError('clone3d(): that object was removed');
        if (h.mesh) { const n = makeEditable(h.st, { v: h.mesh.v.map((p) => p.slice()), f: h.mesh.f.map((f) => f.slice()) }, null, 'clone3d()'); n.o.material.dispose(); n.o.material = h.o.material.clone(); n.smooth = h.smooth; rebuild(n); n.o.position.copy(h.o.position); n.o.rotation.copy(h.o.rotation); n.o.scale.copy(h.o.scale); n.name = h.name; return n; }
        const c2 = h.o.clone(true); c2.traverse((x) => { if (x.material) x.material = x.material.clone(); delete x.userData.h; }); return addObj(h.st, c2, 'clone3d()', { name: h.name, tag: h.tag, model: !!h.model });
      }, 1, 1),

      // ---------- viewport helpers
      orbit3d: B(([s, o]) => {
        const st = sc(s, 'orbit3d()'), TH = T();
        if (o === false) { if (st.orbit) { st.orbit.dispose(); st.orbit = null; } return null; }
        if (!st.orbit) {
          const oc = new (A().OrbitControls)(st.camera, st.renderer.domElement);
          oc.mouseButtons = { LEFT: null, MIDDLE: TH.MOUSE.ROTATE, RIGHT: TH.MOUSE.ROTATE }; oc.enableDamping = false; oc.zoomToCursor = true; oc.screenSpacePanning = true;
          oc.keys = {}; oc.addEventListener('change', () => readCam(st)); st.orbit = oc; st.fps = null; st.follow = null;
        }
        const oc = st.orbit;
        if (isMap(o)) {
          if (o.m.has('target')) { const t = vec(o.m.get('target'), 'orbit3d()'); oc.target.set(t[0], t[1], t[2]); }
          if (o.m.has('left')) oc.mouseButtons.LEFT = o.m.get('left') ? TH.MOUSE.ROTATE : null;
          if (o.m.has('min')) oc.minDistance = N(o.m.get('min'), 'orbit3d()'); if (o.m.has('max')) oc.maxDistance = N(o.m.get('max'), 'orbit3d()');
          if (o.m.has('enabled')) oc.enabled = !!o.m.get('enabled');
        }
        oc.update(); readCam(st); return null;
      }, 1, 2),
      orbit3d_view: B(([s, view, dist]) => {
        const st = sc(s, 'orbit3d_view()'); const oc = st.orbit; const t = oc ? oc.target : new (T().Vector3)(0, 0, 0);
        const d = N(dist, 'orbit3d_view()', st.camera.position.distanceTo(t) || 8); const v = S(view);
        const dirs = { front: [0, 0, 1], back: [0, 0, -1], right: [1, 0, 0], left: [-1, 0, 0], top: [0, 1, 0.0001], bottom: [0, -1, 0.0001], persp: [0.6, 0.45, 0.66] };
        const dd = dirs[v]; if (!dd) throw new KError('orbit3d_view(): view is front, back, left, right, top, bottom or persp');
        const n = norm(dd); st.camera.position.set(t.x + n[0] * d, t.y + n[1] * d, t.z + n[2] * d); st.camera.lookAt(t); if (oc) oc.update(); readCam(st); return null;
      }, 2, 3),
      orbit3d_get: B(([s]) => { const st = sc(s, 'orbit3d_get()'); const t = st.orbit ? st.orbit.target : { x: 0, y: 0, z: 0 }; return toK({ x: r4(t.x), y: r4(t.y), z: r4(t.z), dist: r4(st.camera.position.distanceTo(new (T().Vector3)(t.x, t.y, t.z))) }); }, 1, 1),
      grid3d: B(([s, sz, div, c1]) => {
        const st = sc(s, 'grid3d()'), TH = T(); const S1 = size(sz, 'grid3d()', 20), dv = Math.max(1, Math.min(400, Math.round(N(div, 'grid3d()', 20))));
        const g = new TH.Group(); const grid = new TH.GridHelper(S1, dv, 0x666666, c1 === undefined || c1 === null ? 0x3a3a3a : color(c1, 'grid3d()'));
        grid.material.transparent = true; grid.material.opacity = 0.75; g.add(grid);
        const ax = (a, b, col) => { const geo = new TH.BufferGeometry().setFromPoints([new TH.Vector3(...a), new TH.Vector3(...b)]); g.add(new TH.Line(geo, new TH.LineBasicMaterial({ color: col }))); };
        ax([-S1 / 2, 0.001, 0], [S1 / 2, 0.001, 0], 0xd94a4a); ax([0, 0.001, -S1 / 2], [0, 0.001, S1 / 2], 0x4a7bd9);
        g.traverse(noRay); g.userData.noExport = true; const h = addObj(st, g, 'grid3d()'); h.tag = 'grid'; return h;
      }, 1, 4),
      project3d: B(([s, p]) => { const st = sc(s, 'project3d()'); const q = screen(st, vec(p, 'project3d()')); return toK({ x: r4(q.x), y: r4(q.y), depth: r4(q.z), visible: q.ok }); }, 2, 2),
      pixel_ratio3d: B(([s, r]) => { const st = sc(s, 'pixel_ratio3d()'); const v = Math.max(0.25, Math.min(2, N(r, 'pixel_ratio3d()', 1))); st.renderer.setPixelRatio(v); st.w = 0; return v; }, 2, 2),
      snapshot3d: B(([s, w, hh, bg]) => {   // render the scene to a PNG (data URL), optionally at another size; bg false = transparent
        const st = sc(s, 'snapshot3d()'), TH = T(); const R = st.renderer; const W = Math.round(N(w, 'snapshot3d()', st.w || 640)), H = Math.round(N(hh, 'snapshot3d()', st.h || 480));
        if (W < 16 || H < 16 || W > 4096 || H > 4096) throw new KError('snapshot3d(): size must be 16..4096 pixels');
        const old = new TH.Vector2(); R.getSize(old); const pr = R.getPixelRatio(), asp = st.camera.aspect, oldBg = st.scene.background;
        if (bg === false) st.scene.background = null;
        R.setPixelRatio(1); R.setSize(W, H, false); st.camera.aspect = W / H; st.camera.updateProjectionMatrix(); R.render(st.scene, st.camera);
        const url = R.domElement.toDataURL('image/png');
        st.scene.background = oldBg; R.setPixelRatio(pr); R.setSize(old.x, old.y, false); st.camera.aspect = asp; st.camera.updateProjectionMatrix(); R.render(st.scene, st.camera); return url;
      }, 1, 4),
      // ---------- import / export
      export3d: B(async ([what, fmt]) => {
        let list; if (what instanceof KHandle && what.kind === 'scene3d') list = [...sc(what, 'export3d()').objects].filter((h) => h.o.isMesh && !h.o.userData.noExport && h.o.visible);
        else list = (Array.isArray(what) ? what : [what]).filter((h) => h instanceof KHandle && h.kind === 'object3d' && !h.gone);
        if (!list.length) throw new KError('export3d(): nothing to export (give a scene, an object or a list of objects)');
        return exportAs(list, fmt);
      }, 1, 2),
      import3d: B(async ([s, data, kind]) => { const st = sc(s, 'import3d()'); const o3 = await loadThree(S(data), kind ? S(kind) : ''); if (!o3) return []; return toEditable(st, o3, 'import3d()'); }, 2, 3),
      // ---------- shared model library (Kompass profile / models): made in the modeler, used by any 3D game
      model_save: B(([n, data]) => { const name = nameOk(n, 'model_save()'); const d = S(data); if (!dataKind(d)) throw new KError('model_save(): give a GLB data URL, glTF JSON or OBJ text (export3d makes them)'); const r = lib().save(name, d); if (!r || !r.ok) throw new KError('model_save(): ' + ((r && r.error) || 'could not save')); return true; }, 2, 2),
      model_list: B(() => toK(lib().list() || []), 0, 0),
      model_delete: B(([n]) => !!lib().remove(nameOk(n, 'model_delete()')), 1, 1),
      model_data: B(([n]) => lib().read(nameOk(n, 'model_data()')) || '', 1, 1),
      load_model: B(async ([s, n, kind]) => {   // a library name, or model data (GLB data URL / glTF JSON / OBJ text) -> one object (a group) you can move3d, turn3d, hits3d ...
        const st = sc(s, 'load_model()'); let d = S(n);
        if (!dataKind(d)) { const name = nameOk(d, 'load_model()'); d = lib().read(name) || ''; if (!d) throw new KError('load_model(): no model called "' + name + '" (make one in the Kugel 3D Modeler, or see model_list())'); }
        const o3 = await loadThree(d, kind ? S(kind) : ''); if (!o3) throw new KError('load_model(): empty model');
        o3.traverse((x) => { if (x.isMesh) { x.castShadow = true; x.receiveShadow = true; } });
        const h = addObj(st, o3, 'load_model()', { name: dataKind(S(n)) ? 'model' : S(n), model: true }); return h;
      }, 2, 3),
    };
  }
  root.Kompass3DModel = { builtins, prim, faceNormal, compact, weld, trisToQuads, edgesOf };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.Kompass3DModel;
})(typeof window !== 'undefined' ? window : globalThis);
