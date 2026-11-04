# Kugel Asteroids — ← → rotate, ↑ thrust, Space fire. Break every rock; big ones split.
let c = canvas(body())
let best = store_get("best", 0)
let g = {}
fn rock(p, size) {
  let pts = []
  let n = 11
  for i in range(n) { push(pts, random_float(0.72, 1.12)) }
  return {p: p, v: vrot(vec(random_float(30, 90) * (4 - size) / 2, 0), random_float(0, TAU)), size: size, r: size * 18, spin: random_float(-1, 1), a: 0, pts: pts}
}
fn wave(n) { let rs = []; for i in range(n) { push(rs, rock(vec(random(0, 1) * 900, random(0, 600)), 3)) }; return rs }
fn new_game() {
  g = {ship: {p: vec(450, 300), v: vec(0, 0), a: -PI / 2, inv: 2}, bullets: [], rocks: wave(4), parts: [], score: 0, lives: 3, level: 1, cool: 0, over: false, stars: []}
  for i in range(120) { push(g.stars, vec(random(0, 2000), random(0, 1200))) }
}
new_game()
on_keypress(fn(k) { if g.over and (k == "space" or k == "r") { new_game() } })
fn wrap(p, s) { return vec((p.x % s.w + s.w) % s.w, (p.y % s.h + s.h) % s.h) }
fn burst(p, n, col) { for i in range(n) { push(g.parts, {p: p, v: vrot(vec(random_float(40, 220), 0), random_float(0, TAU)), life: random_float(0.3, 0.8), col: col}) } }
on_frame(fn(dt) {
  let s = canvas_size(c)
  let sh = g.ship
  if not g.over {
    if key_down("left") or key_down("a") { sh.a -= 4 * dt }
    if key_down("right") or key_down("d") { sh.a += 4 * dt }
    let thrust = key_down("up") or key_down("w")
    if thrust { sh.v = vadd(sh.v, vmul(vec(cos(sh.a), sin(sh.a)), 320 * dt)) }
    sh.v = vmul(sh.v, 1 - 0.6 * dt)
    sh.p = wrap(vadd(sh.p, vmul(sh.v, dt)), s)
    sh.inv = max(0, sh.inv - dt)
    g.cool -= dt
    if key_down("space") and g.cool <= 0 {
      g.cool = 0.18
      let d = vec(cos(sh.a), sin(sh.a))
      push(g.bullets, {p: vadd(sh.p, vmul(d, 16)), v: vadd(sh.v, vmul(d, 560)), life: 1.1})
    }
    if thrust { push(g.parts, {p: vsub(sh.p, vmul(vec(cos(sh.a), sin(sh.a)), 12)), v: vadd(vmul(vec(cos(sh.a), sin(sh.a)), -160), vec(random_float(-30, 30), random_float(-30, 30))), life: 0.25, col: "#ffab40"}) }
  }
  let bl = []
  for b in g.bullets { b.life -= dt; b.p = wrap(vadd(b.p, vmul(b.v, dt)), s); if b.life > 0 { push(bl, b) } }
  g.bullets = bl
  let rs = []
  for r in g.rocks {
    r.p = wrap(vadd(r.p, vmul(r.v, dt)), s)
    r.a += r.spin * dt
    let dead = false
    for b in g.bullets {
      if not dead and b.life > 0 and vdist(b.p, r.p) < r.r {
        dead = true
        b.life = 0
        g.score += (4 - r.size) * 20
        burst(r.p, 10, "#b0bec5")
        if r.size > 1 { push(rs, rock(r.p, r.size - 1)); push(rs, rock(r.p, r.size - 1)) }
      }
    }
    if not dead {
      push(rs, r)
      if not g.over and sh.inv <= 0 and vdist(sh.p, r.p) < r.r + 10 {
        burst(sh.p, 30, "#ff5252")
        g.lives -= 1
        sh.p = vec(s.w / 2, s.h / 2)
        sh.v = vec(0, 0)
        sh.inv = 2.5
        if g.lives <= 0 { g.over = true; if g.score > best { best = g.score; store_set("best", best) } }
      }
    }
  }
  g.rocks = rs
  g.bullets = filter(g.bullets, fn(b) { return b.life > 0 })
  if len(g.rocks) == 0 { g.level += 1; g.rocks = wave(3 + g.level) }
  draw_clear(c, "#05060a")
  draw_points(c, map(g.stars, fn(st) { return [st.x % s.w, st.y % s.h] }), "rgba(255,255,255,0.5)", 1.5)
  for r in g.rocks {
    let pts = []
    for i, k in r.pts { let an = r.a + i / len(r.pts) * TAU; push(pts, [r.p.x + cos(an) * r.r * k, r.p.y + sin(an) * r.r * k]) }
    draw_poly(c, pts, "#1c2230")
    draw_poly(c, pts, "#cfd8dc", 2)
  }
  for b in g.bullets { draw_glow(c, b.p.x, b.p.y, 8, "rgba(140,255,255,0.8)"); draw_circle(c, b.p.x, b.p.y, 2, "white") }
  let keep = []
  for p in g.parts { p.life -= dt; p.p = vadd(p.p, vmul(p.v, dt)); if p.life > 0 { push(keep, p); draw_alpha(c, min(1, p.life * 2)); draw_circle(c, p.p.x, p.p.y, 2, p.col); draw_alpha(c, 1) } }
  g.parts = keep
  if not g.over and (sh.inv <= 0 or floor(sh.inv * 8) % 2 == 0) {
    draw_save(c)
    draw_translate(c, sh.p.x, sh.p.y)
    draw_rotate(c, sh.a)
    draw_poly(c, [[16, 0], [-10, -10], [-5, 0], [-10, 10]], "#0a0f1a")
    draw_poly(c, [[16, 0], [-10, -10], [-5, 0], [-10, 10]], "#80deea", 2)
    draw_restore(c)
  }
  draw_text(c, 20, 28, `Score {g.score}`, "white", 18)
  draw_text(c, s.w / 2, 28, `Wave {g.level}`, "#80deea", 18, "center")
  draw_text(c, s.w - 20, 28, "▲ " + str(max(0, g.lives)) + "   Best " + str(best), "#ffab40", 18, "right")
  if g.over {
    draw_text(c, s.w / 2, s.h / 2 - 20, "GAME OVER", "white", 52, "center")
    draw_text(c, s.w / 2, s.h / 2 + 28, "Space to play again", "#80deea", 18, "center")
  } else if g.score == 0 { draw_text(c, s.w / 2, s.h - 24, "← → rotate · ↑ thrust · Space fire", "#607d8b", 15, "center") }
})
