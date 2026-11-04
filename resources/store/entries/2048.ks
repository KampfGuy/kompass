# Kugel 2048 — arrows / WASD slide the tiles; equal tiles merge. Reach 2048! R = new game.
let c = canvas(body())
let best = store_get("best", 0)
let COL = {"2": "#eee4da", "4": "#ede0c8", "8": "#f2b179", "16": "#f59563", "32": "#f67c5f", "64": "#f65e3b", "128": "#edcf72", "256": "#edcc61", "512": "#edc850", "1024": "#edc53f", "2048": "#edc22e"}
let g = {}
fn empty_cells() { let out = []; for i in range(16) { if g.b[i] == 0 { push(out, i) } }; return out }
fn add_tile() { let e = empty_cells(); if len(e) > 0 { let i = e[random(0, len(e) - 1)]; g.b[i] = random() < 0.9 and 2 or 4; g.pop[i] = 0 } }
fn new_game() { g = {b: [], pop: [], score: 0, won: false, over: false, bump: 0}; for i in range(16) { push(g.b, 0); push(g.pop, 1) }; add_tile(); add_tile() }
new_game()
# slide one line of 4 values toward index 0
fn slide(line) {
  let vals = filter(line, fn(v) { return v != 0 })
  let out = []
  let merged = []
  let i = 0
  while i < len(vals) {
    if i + 1 < len(vals) and vals[i] == vals[i + 1] { push(out, vals[i] * 2); push(merged, len(out) - 1); g.score += vals[i] * 2; if vals[i] * 2 == 2048 { g.won = true }; i += 2 }
    else { push(out, vals[i]); i += 1 }
  }
  while len(out) < 4 { push(out, 0) }
  return {line: out, merged: merged}
}
fn move(dx, dy) {
  if g.over { return }
  let moved = false
  for k in range(4) {
    let idx = []
    for j in range(4) {
      let t = j
      if dx == 1 or dy == 1 { t = 3 - j }
      if dx != 0 { push(idx, k * 4 + t) } else { push(idx, t * 4 + k) }
    }
    let r = slide(map(idx, fn(i) { return g.b[i] }))
    for j, i in idx {
      if g.b[i] != r.line[j] { moved = true }
      g.b[i] = r.line[j]
    }
    for m in r.merged { g.pop[idx[m]] = 0 }
  }
  if moved {
    add_tile()
    if g.score > best { best = g.score; store_set("best", best) }
    if len(empty_cells()) == 0 {
      let can = false
      for i in range(16) {
        if i % 4 < 3 and g.b[i] == g.b[i + 1] { can = true }
        if i < 12 and g.b[i] == g.b[i + 4] { can = true }
      }
      g.over = not can
    }
  } else { g.bump = 0.15 }
}
on_keypress(fn(k) {
  if k == "left" or k == "a" { move(-1, 0) }
  else if k == "right" or k == "d" { move(1, 0) }
  else if k == "up" or k == "w" { move(0, -1) }
  else if k == "down" or k == "s" { move(0, 1) }
  else if k == "r" { new_game() }
})
on_frame(fn(dt) {
  let s = canvas_size(c)
  let size = min(s.w - 40, s.h - 150)
  let ox = (s.w - size) / 2
  let oy = 120
  let gap = size * 0.03
  let cell = (size - gap * 5) / 4
  g.bump = max(0, g.bump - dt)
  draw_clear(c, "#faf8ef")
  draw_text(c, ox, 50, "2048", "#776e65", 52, "left", "Arial")
  draw_round_rect(c, ox + size - 230, 22, 110, 58, 8, "#bbada0")
  draw_text(c, ox + size - 175, 40, "SCORE", "#eee4da", 12, "center")
  draw_text(c, ox + size - 175, 62, str(g.score), "white", 22, "center")
  draw_round_rect(c, ox + size - 110, 22, 110, 58, 8, "#bbada0")
  draw_text(c, ox + size - 55, 40, "BEST", "#eee4da", 12, "center")
  draw_text(c, ox + size - 55, 62, str(best), "white", 22, "center")
  draw_text(c, ox, 100, "Arrows / WASD to slide · R new game", "#776e65", 14)
  let jig = g.bump > 0 and sin(g.bump * 80) * 4 or 0
  draw_round_rect(c, ox + jig, oy, size, size, 12, "#bbada0")
  for i in range(16) {
    let x = ox + jig + gap + (i % 4) * (cell + gap)
    let y = oy + gap + floor(i / 4) * (cell + gap)
    draw_round_rect(c, x, y, cell, cell, 8, "rgba(238,228,218,0.35)")
    let v = g.b[i]
    if v > 0 {
      g.pop[i] = min(1, g.pop[i] + dt * 7)
      let sc = 0.6 + 0.4 * g.pop[i]
      let w = cell * sc
      let col = COL[str(v)] or "#3c3a32"
      draw_round_rect(c, x + (cell - w) / 2, y + (cell - w) / 2, w, w, 8, col)
      let fs = v < 100 and cell * 0.45 or (v < 1000 and cell * 0.38 or cell * 0.3)
      draw_text(c, x + cell / 2, y + cell / 2 + 2, str(v), v <= 4 and "#776e65" or "#f9f6f2", fs * sc, "center", "Arial")
    }
  }
  if g.over or g.won {
    draw_round_rect(c, ox, oy, size, size, 12, g.over and "rgba(238,228,218,0.75)" or "rgba(237,194,46,0.5)")
    draw_text(c, ox + size / 2, oy + size / 2 - 10, g.over and "Game over!" or "You win!", "#776e65", 48, "center", "Arial")
    draw_text(c, ox + size / 2, oy + size / 2 + 36, "R for a new game", "#776e65", 18, "center")
  }
})
