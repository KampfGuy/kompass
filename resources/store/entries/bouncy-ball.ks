# Bouncy Ball — click to throw the ball, gravity does the rest. A tiny on_frame + canvas demo.
let c = canvas(body())
let p = vec(200, 100)
let v = vec(180, 0)
let trail = []
on_mouse(c, fn(e) { if e.type == "down" { p = vec(e.x, e.y); v = vec(random() * 600 - 300, -400) } })
on_frame(fn(dt) {
  let s = canvas_size(c)
  v = vadd(v, vec(0, 900 * dt))
  p = vadd(p, vmul(v, dt))
  if p.y > s.h - 20 { p = vec(p.x, s.h - 20); v = vec(v.x * 0.99, -v.y * 0.82) }
  if p.x < 20 or p.x > s.w - 20 { v = vec(-v.x, v.y); p = vec(clamp(p.x, 20, s.w - 20), p.y) }
  push(trail, p)
  if len(trail) > 30 { remove(trail, 0) }
  draw_clear(c, "#101828")
  draw_gradient(c, 0, 0, s.w, s.h, "#101828", "#1e3a5f")
  draw_lines(c, trail, "rgba(255,180,80,0.5)", 3)
  draw_glow(c, p.x, p.y, 60, "rgba(255,160,40,0.35)")
  draw_circle(c, p.x, p.y, 20, "#ffb347")
  draw_text(c, 20, 30, "Click anywhere to throw the ball", "white", 16)
})
