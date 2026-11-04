# Kugel Snake — arrows / WASD to steer, eat the glowing orbs, don't bite yourself. Space = pause, R = restart.
let c = canvas(body())
let COLS = 28
let ROWS = 18
let best = store_get("best", 0)
let g = {}
fn reset() {
  g = {snake: [vec(8, 9), vec(7, 9), vec(6, 9)], dir: vec(1, 0), next: vec(1, 0), food: vec(18, 9), score: 0, step: 0.12, acc: 0, over: false, paused: false, pulse: 0, parts: []}
}
fn free_cell() {
  while true {
    let p = vec(random(0, COLS - 1), random(0, ROWS - 1))
    let hit = false
    for s in g.snake { if s.x == p.x and s.y == p.y { hit = true } }
    if not hit { return p }
  }
}
fn turn(dx, dy) { if g.dir.x != -dx or g.dir.y != -dy { g.next = vec(dx, dy) } }
on_keypress(fn(k) {
  if k == "up" or k == "w" { turn(0, -1) }
  else if k == "down" or k == "s" { turn(0, 1) }
  else if k == "left" or k == "a" { turn(-1, 0) }
  else if k == "right" or k == "d" { turn(1, 0) }
  else if k == "space" { if g.over { reset() } else { g.paused = not g.paused } }
  else if k == "r" { reset() }
})
fn tick() {
  g.dir = g.next
  let h = g.snake[0]
  let n = vec((h.x + g.dir.x + COLS) % COLS, (h.y + g.dir.y + ROWS) % ROWS)
  for s in g.snake { if s.x == n.x and s.y == n.y { g.over = true } }
  if g.over {
    if g.score > best { best = g.score; store_set("best", best) }
    return
  }
  insert(g.snake, 0, n)
  if n.x == g.food.x and n.y == g.food.y {
    g.score += 10
    g.step = max(0.055, g.step - 0.003)
    for i in range(12) { push(g.parts, {p: vec(n.x, n.y), v: vrot(vec(random_float(2, 6), 0), random_float(0, TAU)), life: 0.6}) }
    g.food = free_cell()
  } else { pop(g.snake) }
}
reset()
on_frame(fn(dt) {
  let s = canvas_size(c)
  let cell = floor(min((s.w - 40) / COLS, (s.h - 90) / ROWS))
  let ox = (s.w - cell * COLS) / 2
  let oy = 70 + (s.h - 90 - cell * ROWS) / 2
  if not g.over and not g.paused {
    g.acc += dt
    while g.acc >= g.step { g.acc -= g.step; tick() }
  }
  g.pulse += dt
  draw_clear(c, "#0b0f14")
  draw_text(c, s.w / 2, 30, "K U G E L   S N A K E", "#7CFFB2", 26, "center")
  draw_text(c, ox, 55, `Score {g.score}`, "white", 16)
  draw_text(c, ox + cell * COLS, 55, `Best {best}`, "#9aa4b2", 16, "right")
  draw_round_rect(c, ox - 4, oy - 4, cell * COLS + 8, cell * ROWS + 8, 10, "#121a24")
  for y in range(ROWS) { for x in range(COLS) { if (x + y) % 2 == 0 { draw_rect(c, ox + x * cell, oy + y * cell, cell, cell, "#141e2a") } } }
  let f = g.food
  draw_glow(c, ox + f.x * cell + cell / 2, oy + f.y * cell + cell / 2, cell * (1.4 + 0.3 * sin(g.pulse * 6)), "rgba(255,90,140,0.55)")
  draw_circle(c, ox + f.x * cell + cell / 2, oy + f.y * cell + cell / 2, cell * 0.35, "#ff5a8c")
  let n = len(g.snake)
  for i, p in g.snake {
    let col = mix("#7CFFB2", "#1f8a5b", i / max(1, n))
    draw_round_rect(c, ox + p.x * cell + 1, oy + p.y * cell + 1, cell - 2, cell - 2, cell / 3, col)
  }
  let h = g.snake[0]
  draw_circle(c, ox + h.x * cell + cell / 2 + g.dir.x * cell * 0.15, oy + h.y * cell + cell / 2 + g.dir.y * cell * 0.15, cell * 0.12, "#0b0f14")
  let keep = []
  for q in g.parts {
    q.life -= dt
    q.p = vadd(q.p, vmul(q.v, dt))
    if q.life > 0 {
      push(keep, q)
      draw_alpha(c, q.life / 0.6)
      draw_circle(c, ox + q.p.x * cell + cell / 2, oy + q.p.y * cell + cell / 2, 3, "#ffd166")
      draw_alpha(c, 1)
    }
  }
  g.parts = keep
  if g.over or g.paused {
    draw_rect(c, 0, 0, s.w, s.h, "rgba(0,0,0,0.55)")
    draw_text(c, s.w / 2, s.h / 2 - 20, g.over and "GAME OVER" or "PAUSED", "white", 44, "center")
    draw_text(c, s.w / 2, s.h / 2 + 25, g.over and "Space or R to play again" or "Space to continue", "#9aa4b2", 18, "center")
  } else {
    draw_text(c, s.w / 2, s.h - 14, "Arrows / WASD steer · Space pause · R restart", "#5b6675", 13, "center")
  }
})
