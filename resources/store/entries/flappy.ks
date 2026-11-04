# Flappy Kugel — Space / click / Up to flap through the pipes.
let c = canvas(body())
let best = store_get("best", 0)
let g = {}
fn reset() { g = {y: 0.45, vy: 0, pipes: [], t: 0, spawn: 0, score: 0, state: "ready", hills: 0, flapT: 0} }
reset()
fn flap() {
  if g.state == "dead" { if g.t > 0.6 { reset() }; return }
  g.state = "play"
  g.vy = -0.62
  g.flapT = 0.15
}
on_keypress(fn(k) { if k == "space" or k == "up" or k == "w" { flap() } })
on_mouse(c, fn(e) { if e.type == "down" { flap() } })
on_frame(fn(dt) {
  let s = canvas_size(c)
  let H = s.h
  let W = s.w
  let bx = W * 0.3
  let r = H * 0.03
  g.t += dt
  g.flapT = max(0, g.flapT - dt)
  if g.state == "play" {
    g.vy += 1.7 * dt
    g.y += g.vy * dt
    g.hills += dt * 60
    g.spawn -= dt
    if g.spawn <= 0 {
      g.spawn = 1.45
      push(g.pipes, {x: W + 40, gap: random_float(0.25, 0.7), done: false})
    }
    let keep = []
    for p in g.pipes {
      p.x -= 0.32 * W * dt
      let gh = 0.24 * H
      let gy = p.gap * H
      if abs(p.x - bx) < r + 34 and (g.y * H - r < gy - gh / 2 or g.y * H + r > gy + gh / 2) { g.state = "dead"; g.t = 0 }
      if not p.done and p.x < bx { p.done = true; g.score += 1 }
      if p.x > -80 { push(keep, p) }
    }
    g.pipes = keep
    if g.y * H > H - 40 - r or g.y < 0 { g.state = "dead"; g.t = 0 }
    if g.state == "dead" and g.score > best { best = g.score; store_set("best", best) }
  } else if g.state == "ready" { g.y = 0.45 + 0.02 * sin(g.t * 4) }
  else if g.state == "dead" and g.y * H < H - 40 - r { g.vy += 2.5 * dt; g.y += g.vy * dt }
  draw_gradient(c, 0, 0, W, H, "#4fc3f7", "#e1f5fe")
  draw_circle(c, W * 0.82, H * 0.18, H * 0.07, "#fff59d")
  for i in range(8) {
    let hx = ((i * 260 - g.hills * 0.5) % (W + 260) + W + 260) % (W + 260) - 130
    draw_ellipse(c, hx, H - 40, 170, 90, 0, "#81c784")
  }
  for p in g.pipes {
    let gh = 0.24 * H
    let gy = p.gap * H
    draw_rect(c, p.x - 34, 0, 68, gy - gh / 2, ["#2e7d32", "#66bb6a", "#2e7d32"])
    draw_rect(c, p.x - 40, gy - gh / 2 - 26, 80, 26, ["#1b5e20", "#4caf50", "#1b5e20"])
    draw_rect(c, p.x - 34, gy + gh / 2, 68, H - gy - gh / 2 - 40, ["#2e7d32", "#66bb6a", "#2e7d32"])
    draw_rect(c, p.x - 40, gy + gh / 2, 80, 26, ["#1b5e20", "#4caf50", "#1b5e20"])
  }
  draw_rect(c, 0, H - 40, W, 40, "#8d6e63")
  draw_rect(c, 0, H - 40, W, 8, "#66bb6a")
  draw_save(c)
  draw_translate(c, bx, g.y * H)
  draw_rotate(c, clamp(g.vy * 0.9, -0.5, 1.2))
  draw_circle(c, 0, 0, r, "#ff7043")
  draw_ellipse(c, -r * 0.2, r * 0.15, r * 0.55, r * (g.flapT > 0 and 0.15 or 0.35), 0, "#ffab91")
  draw_circle(c, r * 0.4, -r * 0.3, r * 0.28, "white")
  draw_circle(c, r * 0.5, -r * 0.3, r * 0.13, "#222")
  draw_poly(c, [[r * 0.8, -r * 0.05], [r * 1.35, r * 0.12], [r * 0.8, r * 0.3]], "#ffca28")
  draw_restore(c)
  draw_text(c, W / 2, 60, str(g.score), "white", 54, "center")
  if g.state == "ready" {
    draw_text(c, W / 2, H * 0.3, "FLAPPY KUGEL", "#ffffff", 48, "center")
    draw_text(c, W / 2, H * 0.3 + 44, "Space / click to flap", "#0d47a1", 20, "center")
  }
  if g.state == "dead" {
    draw_round_rect(c, W / 2 - 170, H * 0.32, 340, 150, 18, "rgba(0,0,0,0.55)")
    draw_text(c, W / 2, H * 0.32 + 40, "GAME OVER", "white", 36, "center")
    draw_text(c, W / 2, H * 0.32 + 85, `Score {g.score}   ·   Best {best}`, "#ffe082", 20, "center")
    draw_text(c, W / 2, H * 0.32 + 120, "Space / click to retry", "#cfd8dc", 15, "center")
  }
})
