# Kugel Pong — you (left, W/S or ↑ ↓ or mouse) vs the AI. First to 7 wins. Space to serve.
let c = canvas(body())
let g = {}
fn new_game() { g = {py: 0.5, ay: 0.5, b: vec(0.5, 0.5), v: vec(0, 0), you: 0, ai: 0, serve: true, dir: 1, trail: [], flash: 0, winner: ""} }
new_game()
fn serve() {
  if g.winner != "" { new_game(); return }
  if g.serve { g.serve = false; g.v = vec(0.45 * g.dir, random_float(-0.3, 0.3)) }
}
on_keypress(fn(k) { if k == "space" { serve() } })
on_mouse(c, fn(e) { let s = canvas_size(c); if e.type == "move" { g.py = clamp(e.y / s.h, 0.1, 0.9) }; if e.type == "down" { serve() } })
fn point(who) {
  if who == "you" { g.you += 1; g.dir = 1 } else { g.ai += 1; g.dir = -1 }
  g.serve = true
  g.flash = 0.3
  g.b = vec(0.5, 0.5)
  g.v = vec(0, 0)
  if g.you >= 7 { g.winner = "YOU WIN!" }
  if g.ai >= 7 { g.winner = "AI WINS" }
}
on_frame(fn(dt) {
  let s = canvas_size(c)
  let W = s.w
  let H = s.h
  let ph = 0.18
  let asp = W / H
  if key_down("up") or key_down("w") { g.py -= 0.9 * dt }
  if key_down("down") or key_down("s") { g.py += 0.9 * dt }
  g.py = clamp(g.py, ph / 2, 1 - ph / 2)
  let target = g.v.x > 0 and g.b.y or 0.5
  g.ay += clamp(target - g.ay, -0.62 * dt, 0.62 * dt)
  g.ay = clamp(g.ay, ph / 2, 1 - ph / 2)
  if not g.serve and g.winner == "" {
    g.b = vadd(g.b, vec(g.v.x * dt, g.v.y * dt * asp))
    if g.b.y < 0.02 or g.b.y > 0.98 { g.v = vec(g.v.x, -g.v.y); g.b = vec(g.b.x, clamp(g.b.y, 0.02, 0.98)) }
    if g.v.x < 0 and g.b.x < 0.045 and g.b.x > 0.02 and abs(g.b.y - g.py) < ph / 2 + 0.02 {
      g.v = vec(min(1.1, abs(g.v.x) * 1.07), (g.b.y - g.py) / (ph / 2) * 0.45)
    }
    if g.v.x > 0 and g.b.x > 0.955 and g.b.x < 0.98 and abs(g.b.y - g.ay) < ph / 2 + 0.02 {
      g.v = vec(-min(1.1, abs(g.v.x) * 1.07), (g.b.y - g.ay) / (ph / 2) * 0.45)
    }
    if g.b.x < -0.02 { point("ai") }
    if g.b.x > 1.02 { point("you") }
  }
  push(g.trail, [g.b.x * W, g.b.y * H])
  if len(g.trail) > 14 { remove(g.trail, 0) }
  g.flash = max(0, g.flash - dt)
  draw_clear(c, g.flash > 0 and "#1a1030" or "#0a0a14")
  for i in range(20) { draw_rect(c, W / 2 - 2, i * H / 20 + 6, 4, H / 40, "rgba(255,255,255,0.15)") }
  draw_text(c, W / 2 - 80, 60, str(g.you), "#4dd0e1", 56, "center")
  draw_text(c, W / 2 + 80, 60, str(g.ai), "#ff4081", 56, "center")
  draw_glow(c, 0.03 * W, g.py * H, ph * H, "rgba(77,208,225,0.15)")
  draw_round_rect(c, 0.025 * W, (g.py - ph / 2) * H, 12, ph * H, 6, "#4dd0e1")
  draw_glow(c, 0.97 * W, g.ay * H, ph * H, "rgba(255,64,129,0.15)")
  draw_round_rect(c, 0.975 * W - 12, (g.ay - ph / 2) * H, 12, ph * H, 6, "#ff4081")
  if len(g.trail) > 1 { draw_lines(c, g.trail, "rgba(255,255,255,0.25)", 6) }
  draw_glow(c, g.b.x * W, g.b.y * H, 30, "rgba(255,255,255,0.4)")
  draw_circle(c, g.b.x * W, g.b.y * H, 9, "white")
  draw_text(c, 0.03 * W, H - 20, "YOU · W/S, ↑↓ or mouse", "#4dd0e1", 13)
  draw_text(c, 0.97 * W, H - 20, "AI", "#ff4081", 13, "right")
  if g.winner != "" {
    draw_rect(c, 0, 0, W, H, "rgba(0,0,0,0.6)")
    draw_text(c, W / 2, H / 2 - 10, g.winner, "white", 56, "center")
    draw_text(c, W / 2, H / 2 + 40, "Space / click for a rematch", "#b0bec5", 18, "center")
  } else if g.serve { draw_text(c, W / 2, H / 2 + 60, "Space / click to serve", "#b0bec5", 18, "center") }
})
