# Kugel Breakout — mouse or ← → to move the paddle, Space / click to launch. Clear all bricks!
let c = canvas(body())
let COLORS = ["#ff5252", "#ff9800", "#ffeb3b", "#66bb6a", "#29b6f6", "#ab47bc"]
let best = store_get("best", 0)
let g = {}
fn build(level) {
  let bricks = []
  for row in range(6) { for col in range(12) { if level == 1 or (row + col) % 4 != 0 { push(bricks, {x: col, y: row, hp: row < level - 1 and 2 or 1}) } } }
  return bricks
}
fn reset_ball() { g.ball = {x: g.px, y: 0, vx: 0, vy: 0, stuck: true} }
fn new_game() { g = {px: 0.5, lives: 3, score: 0, level: 1, bricks: build(1), parts: [], shake: 0, state: "play", mouse: false}; reset_ball() }
new_game()
fn launch() {
  if g.state != "play" { new_game(); return }
  if g.ball.stuck { g.ball.stuck = false; g.ball.vx = random_float(-150, 150); g.ball.vy = -480 }
}
on_keypress(fn(k) { if k == "space" { launch() } })
on_mouse(c, fn(e) {
  let s = canvas_size(c)
  if e.type == "move" { g.px = clamp(e.x / s.w, 0.06, 0.94) }
  if e.type == "down" { launch() }
})
on_frame(fn(dt) {
  let s = canvas_size(c)
  let W = s.w
  let H = s.h
  let pw = 0.13
  let top = 70
  let bw = W / 12
  let bh = 24
  if key_down("left") or key_down("a") { g.px = clamp(g.px - 1.1 * dt, 0.06, 0.94) }
  if key_down("right") or key_down("d") { g.px = clamp(g.px + 1.1 * dt, 0.06, 0.94) }
  let b = g.ball
  let pyy = H - 40
  let px = g.px * W
  let half = pw * W / 2
  if g.state == "play" {
    if b.stuck { b.x = px; b.y = pyy - 10 }
    else {
      let steps = 4
      for i in range(steps) {
        b.x += b.vx * dt / steps
        b.y += b.vy * dt / steps
        if b.x < 8 { b.vx = abs(b.vx); b.x = 8 }
        if b.x > W - 8 { b.vx = -abs(b.vx); b.x = W - 8 }
        if b.y < 50 { b.vy = abs(b.vy) }
        if b.vy > 0 and b.y > pyy - 8 and b.y < pyy + 8 and abs(b.x - px) < half + 8 {
          let sp = min(900, vlen(vec(b.vx, b.vy)) * 1.01)
          let a = (b.x - px) / half * 1.05
          b.vx = sin(a) * sp
          b.vy = -cos(a) * sp
        }
        let keep = []
        let hit = false
        for k in g.bricks {
          let kx = k.x * bw
          let ky = top + k.y * (bh + 6)
          if not hit and b.x > kx - 6 and b.x < kx + bw + 6 and b.y > ky - 6 and b.y < ky + bh + 6 {
            hit = true
            b.vy = -b.vy
            k.hp -= 1
            g.score += 10
            g.shake = 0.12
            for j in range(8) { push(g.parts, {x: kx + bw / 2, y: ky + bh / 2, vx: random_float(-200, 200), vy: random_float(-200, 100), life: 0.5, col: COLORS[k.y % 6]}) }
          }
          if k.hp > 0 { push(keep, k) }
        }
        g.bricks = keep
      }
      if b.y > H + 20 {
        g.lives -= 1
        if g.lives <= 0 { g.state = "over"; if g.score > best { best = g.score; store_set("best", best) } } else { reset_ball() }
      }
      if len(g.bricks) == 0 { g.level += 1; g.bricks = build(g.level); reset_ball() }
    }
  }
  g.shake = max(0, g.shake - dt)
  draw_clear(c, "#0d0b1e")
  draw_save(c)
  if g.shake > 0 { draw_translate(c, random_float(-3, 3), random_float(-3, 3)) }
  for k in g.bricks {
    let col = COLORS[k.y % 6]
    if k.hp > 1 { col = shade(col, -0.35) }
    draw_round_rect(c, k.x * bw + 3, top + k.y * (bh + 6), bw - 6, bh, 6, [col, shade(col, -0.25)])
  }
  draw_round_rect(c, px - half, pyy, pw * W, 12, 6, ["#e0e0e0", "#90a4ae"])
  draw_glow(c, b.x, b.y, 26, "rgba(255,255,255,0.35)")
  draw_circle(c, b.x, b.y, 8, "white")
  let keep = []
  for p in g.parts {
    p.life -= dt
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.vy += 500 * dt
    if p.life > 0 { push(keep, p); draw_alpha(c, p.life * 2); draw_rect(c, p.x, p.y, 5, 5, p.col); draw_alpha(c, 1) }
  }
  g.parts = keep
  draw_restore(c)
  draw_text(c, 20, 30, `Score {g.score}`, "white", 18)
  draw_text(c, W / 2, 30, `Level {g.level}`, "#b39ddb", 18, "center")
  draw_text(c, W - 20, 30, "♥ " + str(g.lives) + "   Best " + str(best), "#ff8a80", 18, "right")
  if g.state == "play" and b.stuck { draw_text(c, W / 2, H * 0.6, "Space / click to launch · mouse or ← → to move", "#9fa8da", 16, "center") }
  if g.state == "over" {
    draw_rect(c, 0, 0, W, H, "rgba(0,0,0,0.6)")
    draw_text(c, W / 2, H / 2 - 20, "GAME OVER", "white", 48, "center")
    draw_text(c, W / 2, H / 2 + 26, "Space / click for a new game", "#9fa8da", 18, "center")
  }
})
