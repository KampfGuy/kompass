/* Kompass VR — optional immersive mode (WebXR) for KampfScript games/programs drawn on a canvas.
 * When the runtime supports `immersive-vr` and the open page shows a big canvas, a "🥽 Immersive" button appears.
 * In immersive mode the canvas is shown as a large floating screen ~2 m in front of you; controller input is mapped
 * to the keys KampfScript games read with key_down()/on_keypress(): trigger = space, grip = enter,
 * thumbstick = arrow keys, A/X = "z", B/Y = escape (leaves immersive mode).
 * NOTE: Android System WebView does not implement WebXR today, so inside the APK the button stays hidden unless a
 * future Horizon OS WebView adds it; the same file works in browsers that do (e.g. the web preview in Quest Browser). */
(function () {
  'use strict';
  if (!navigator.xr || !navigator.xr.isSessionSupported) return;
  let supported = false;
  navigator.xr.isSessionSupported('immersive-vr').then((ok) => { supported = !!ok; }).catch(() => {});
  const btn = document.createElement('button'); btn.className = 'kvr-xr-btn'; btn.textContent = '🥽 Immersive'; btn.hidden = true;
  btn.title = 'Show this KampfScript canvas in immersive VR';
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(btn));
  const bigCanvas = () => { let best = null, area = 0; for (const c of document.querySelectorAll('.ks-page canvas')) { const r = c.getBoundingClientRect(); const a = r.width * r.height; if (c.getClientRects().length && r.width >= 200 && r.height >= 150 && a > area) { best = c; area = a; } } return best; };
  // VR games made with vr_setup() have their own immersive mode (vr_start), so the canvas mirror hides for them
  setInterval(() => { btn.hidden = !(supported && !session && bigCanvas() && !document.querySelector('canvas[data-kvr]')); }, 700);
  let session = null;
  const key = (k, down) => window.dispatchEvent(new KeyboardEvent(down ? 'keydown' : 'keyup', { key: k, bubbles: true }));
  btn.addEventListener('click', async () => {
    const src = bigCanvas(); if (!src || session) return;
    const gl = document.createElement('canvas').getContext('webgl', { xrCompatible: true });
    try { session = await navigator.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor'] }); } catch (e) { window.KompassVR && window.KompassVR.toast('Immersive mode failed: ' + e.message); return; }
    await gl.makeXRCompatible();
    session.updateRenderState({ baseLayer: new XRWebGLLayer(session, gl) });
    let space; try { space = await session.requestReferenceSpace('local-floor'); } catch (e) { space = await session.requestReferenceSpace('local'); }
    const vs = 'attribute vec2 p; uniform mat4 P, V, M; varying vec2 uv; void main(){ uv = vec2(p.x*0.5+0.5, 0.5-p.y*0.5); gl_Position = P*V*M*vec4(p,0.,1.); }';
    const fs = 'precision mediump float; varying vec2 uv; uniform sampler2D t; void main(){ gl_FragColor = texture2D(t, uv); }';
    const sh = (type, s) => { const o = gl.createShader(type); gl.shaderSource(o, s); gl.compileShader(o); return o; };
    const prog = gl.createProgram(); gl.attachShader(prog, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, fs)); gl.linkProgram(prog);
    const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const tex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, tex);
    for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.LINEAR], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
    const U = (n) => gl.getUniformLocation(prog, n);
    const held = new Set();
    const setKey = (k, d) => { if (d && !held.has(k)) { held.add(k); key(k, true); } else if (!d && held.has(k)) { held.delete(k); key(k, false); } };
    session.addEventListener('end', () => { for (const k of held) key(k, false); held.clear(); session = null; });
    function frame(t, f) {
      if (!session) return; session.requestAnimationFrame(frame);
      const pose = f.getViewerPose(space); if (!pose) return;
      for (const s of session.inputSources) {
        const g = s.gamepad; if (!g) continue; const b = (i) => !!(g.buttons[i] && g.buttons[i].pressed);
        setKey(' ', b(0)); setKey('Enter', b(1)); setKey('z', b(4));
        if (b(5)) { session.end(); return; }
        const ax = g.axes[2] || 0, ay = g.axes[3] || 0;
        setKey(s.handedness === 'left' ? 'a' : 'ArrowLeft', ax < -0.5); setKey(s.handedness === 'left' ? 'd' : 'ArrowRight', ax > 0.5);
        setKey(s.handedness === 'left' ? 'w' : 'ArrowUp', ay < -0.5); setKey(s.handedness === 'left' ? 's' : 'ArrowDown', ay > 0.5);
      }
      const layer = session.renderState.baseLayer; gl.bindFramebuffer(gl.FRAMEBUFFER, layer.framebuffer);
      gl.clearColor(0.06, 0.08, 0.12, 1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      gl.bindTexture(gl.TEXTURE_2D, tex); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
      gl.useProgram(prog); gl.bindBuffer(gl.ARRAY_BUFFER, buf); const loc = gl.getAttribLocation(prog, 'p'); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      const w = 1.6, h = w * (src.height / Math.max(1, src.width));
      gl.uniformMatrix4fv(U('M'), false, new Float32Array([w, 0, 0, 0, 0, h, 0, 0, 0, 0, 1, 0, 0, 1.5, -2.2, 1]));
      for (const v of pose.views) {
        const vp = layer.getViewport(v); gl.viewport(vp.x, vp.y, vp.width, vp.height);
        gl.uniformMatrix4fv(U('P'), false, v.projectionMatrix); gl.uniformMatrix4fv(U('V'), false, v.transform.inverse.matrix);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      }
    }
    session.requestAnimationFrame(frame);
  });
})();
