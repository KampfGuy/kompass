// A fake WebXR runtime (navigator.xr + an immersive-vr session + XRFrame poses + controller gamepads) on top of
// tests/three-harness.js, so VR KampfScript games run on the REAL src/kompass3d.js immersive code path in Node and a
// test "player" can put the headset and both controllers anywhere, press triggers and swing.
const H = require('../../tests/three-harness.js');
const THREE = global.THREE;
const listen = (o) => { o._l = {}; o.addEventListener = (t, f) => { (o._l[t] = o._l[t] || []).push(f); }; o.fire = (t, e) => { for (const f of o._l[t] || []) f(e || {}); }; return o; };
const xr = { supported: true, session: null, sessions: 0, haptics: [] };
const pose = (p, q) => ({ transform: { matrix: new THREE.Matrix4().compose(new THREE.Vector3(...p), q || new THREE.Quaternion(), new THREE.Vector3(1, 1, 1)).toArray() } });
function makeSession() {
  const btn = () => ({ pressed: false, touched: false, value: 0 });
  const src = (hand) => ({ handedness: hand, gripSpace: { hand }, targetRaySpace: { hand },
    gamepad: { buttons: Array.from({ length: 6 }, btn), axes: [0, 0, 0, 0], hapticActuators: [{ pulse: (a, ms) => { xr.haptics.push([hand, a, ms]); return Promise.resolve(true); } }] } });
  const s = listen({ inputSources: [src('left'), src('right')], ended: false,
    head: { p: [0, 1.6, 0], q: new THREE.Quaternion() }, hands: { left: { p: [-0.25, 1.1, -0.3], q: new THREE.Quaternion() }, right: { p: [0.25, 1.1, -0.3], q: new THREE.Quaternion() } },
    end() { if (!this.ended) { this.ended = true; this.fire('end'); } return Promise.resolve(); } });
  s.frame = { getViewerPose: () => pose(s.head.p, s.head.q), getPose: (space) => pose(s.hands[space.hand].p, s.hands[space.hand].q) };
  return s;
}
// the browser side: navigator.xr
navigator.xr = { isSessionSupported: async (m) => m === 'immersive-vr' && xr.supported, requestSession: async (m) => { if (!xr.supported) throw new Error('NotSupportedError'); xr.sessions++; xr.session = makeSession(); return xr.session; } };
// the three.js side: renderer.xr (WebXRManager) + setAnimationLoop, as far as kompass3d.js uses them
const R = THREE.WebGLRenderer.prototype;
Object.defineProperty(R, 'xr', { get() { if (!this._xr) { const r = this; this._xr = { enabled: false, isPresenting: false, refType: '', setReferenceSpaceType(t) { this.refType = t; }, setFoveation() {}, getReferenceSpace: () => ({ ref: true }),
  async setSession(s) { this.session = s; this.isPresenting = true; r._xrRenderer = true; s.addEventListener('end', () => { this.isPresenting = false; }); } }; } return this._xr; } });
R.setAnimationLoop = function (f) { this._loop = f; xr.loops = xr.loops || new Set(); if (f) xr.loops.add(this); else xr.loops.delete(this); };
const rendered = { vr: 0 };
const origRender = R.render; R.render = function (scene, cam) { if (this._xr && this._xr.isPresenting) rendered.vr++; return origRender.call(this, scene, cam); };
// one headset frame: run every XR animation loop (that is where kompass3d drains its rAF queue), then plain rAF
let now = 100000;
function xrTick(n) { for (let i = 0; i < (n || 1); i++) { now += 16; for (const r of [...(xr.loops || [])]) if (r._loop && xr.session && !xr.session.ended) r._loop(now, xr.session.frame); H.tick(1); } }
async function xrStep(w, n, dt, each) { for (let i = 0; i < n; i++) { if (each) each(i); xrTick(1); await w.rt.frame(dt || 1 / 60); } }
const yawQ = (deg) => new THREE.Quaternion().setFromEuler(new THREE.Euler(0, deg * Math.PI / 180, 0));
const lookQ = (dir) => new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, -1), new THREE.Vector3(...dir).normalize());
module.exports = Object.assign({}, H, { xr, xrTick, xrStep, rendered, yawQ, lookQ, probe: () => global.Kompass3D.probeXR() });
