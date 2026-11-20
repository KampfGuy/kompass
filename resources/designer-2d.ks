# 2D game: steer the Kugel with the arrow keys / WASD, collect stars, dodge the red blocks.
# Change the numbers, add enemies, make it yours. ⛶ plays it fullscreen.
let c = canvas(body())
let p = vec(200, 200)
let speed = 260
let star = vec(400, 150)
let foes = []
let score = 0
let best = store_get("best", 0)
let alive = true
fn reset() { p = vec(200, 200); foes = []; score = 0; alive = true }
fn new_star(s) { star = vec(40 + random() * (s.w - 80), 40 + random() * (s.h - 80)) }
on_mouse(c, fn(e) { if e.type == "down" and not alive { reset() } })
on_frame(fn(dt) {
  let s = canvas_size(c)
  draw_clear(c, "#0f1724")
  draw_gradient(c, 0, 0, s.w, s.h, "#0f1724", "#1f2f4a")
  if alive {
    let dx = 0
    let dy = 0
    if key_down("arrowleft") or key_down("a") { dx -= 1 }
    if key_down("arrowright") or key_down("d") { dx += 1 }
    if key_down("arrowup") or key_down("w") { dy -= 1 }
    if key_down("arrowdown") or key_down("s") { dy += 1 }
    p = vec(clamp(p.x + dx * speed * dt, 16, s.w - 16), clamp(p.y + dy * speed * dt, 16, s.h - 16))
    if vdist(p, star) < 30 { score += 1; new_star(s); push(foes, {x: random() * s.w, y: -20, v: 80 + score * 12}) }
    for f in foes {
      f.y += f.v * dt
      if f.y > s.h + 20 { f.y = -20; f.x = random() * s.w }
      if abs(f.x - p.x) < 28 and abs(f.y - p.y) < 28 { alive = false; if score > best { best = score; store_set("best", best) } }
    }
  }
  draw_glow(c, star.x, star.y, 40, "rgba(255,220,80,0.4)")
  draw_circle(c, star.x, star.y, 12, "#ffd84a")
  for f in foes { draw_rect(c, f.x - 14, f.y - 14, 28, 28, "#e4572e") }
  draw_circle(c, p.x, p.y, 16, "#4fc3f7")
  draw_text(c, 16, 28, "Stars: " + str(score) + "   Best: " + str(best), "white", 18)
  if not alive { draw_text(c, s.w / 2 - 120, s.h / 2, "Game over — click to play again", "white", 20) }
})
