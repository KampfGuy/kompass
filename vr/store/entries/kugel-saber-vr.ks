# KUGEL SABER VR - slice the beat (Kompass VR, KampfScript 3D + VR API)
# Blocks fly at you. Cut RED blocks with the LEFT saber and BLUE blocks with the RIGHT saber,
# in the direction of the white arrow (a dot = any direction). Don't touch the black bombs.
# Combos raise the multiplier (2x, 4x, 8x). Misses drain your energy. Best score is saved.
# VR: swing the controllers, pull a trigger to start.  Screen: the mouse is the right saber
# (hold Shift for the left one), flick it the arrow's way; colors don't matter on a screen.

let s = scene3d(body())
sky3d(s, "#05010f", "#2a0b3d")
fog3d(s, "#12051f", 8, 34)
vr_setup(s, {hands: false, pitch: -6})
vr_rig(s, 0, 0, 0, 0)

# ---------------------------------------------------------------- stage
let floor_ = plane(s, 8, 60, "#140a24")
look3d(floor_, {texture: "grid", repeat: 12, glow: "#120626"})
move3d(floor_, 0, 0, -22)
for side in [-1, 1] {
  let rail = cube(s, 0.06, 0.06, 60, "#ff2bd6")
  look3d(rail, {glow: "#ff2bd6"})
  move3d(rail, side * 1.1, 0.03, -22)
  for k in range(6) {
    let ring = torus(s, 2.6, 0.05, "#3bd6ff")
    look3d(ring, {glow: "#1b8fbf"})
    move3d(ring, 0, 1.5, -8 - k * 6)
  }
}
let glowl = light3d(s, "point", "#ff6ad5", 2, 0, 3, -4)

# ---------------------------------------------------------------- sabers (blade along -z out of the fist)
fn make_saber(colr, hand) {
  let g = group3d(s)
  let hilt = cylinder(s, 0.022, 0.24, "#c0c4cc")
  look3d(hilt, {metal: 0.8, shiny: 0.7})
  turn3d(hilt, 90, 0, 0)
  let blade = cylinder(s, 0.016, 1.0, colr)
  look3d(blade, {glow: colr, opacity: 0.92})
  turn3d(blade, 90, 0, 0)
  move3d(blade, 0, 0, -0.6)
  attach3d(g, hilt)
  attach3d(g, blade)
  vr_attach(s, g, hand)
  return g
}
let RED = "#ff3b5c"
let BLUE = "#3b8bff"
let sabers = [make_saber(RED, "left"), make_saber(BLUE, "right")]

# ---------------------------------------------------------------- scoreboard inside the world (visible in the headset)
let board_c = canvas(s, 512, 256)
setstyle(board_c, "display", "none")
let board = panel3d(s, board_c, 2.4)
move3d(board, 0, 2.75, -5)

# ---------------------------------------------------------------- screen overlay (desktop / before entering VR)
let menu = col(s)
setstyle(menu, "position", "absolute")
setstyle(menu, "left", "50%")
setstyle(menu, "bottom", 24)
setstyle(menu, "transform", "translateX(-50%)")
setstyle(menu, "background", "rgba(20, 6, 34, 0.86)")
setstyle(menu, "color", "white")
setstyle(menu, "padding", "14px 22px")
setstyle(menu, "border-radius", 14)
setstyle(menu, "align-items", "center")
setstyle(menu, "gap", "8px")
setstyle(menu, "text-align", "center")
let hint = label(s, "")
setstyle(hint, "position", "absolute")
setstyle(hint, "left", 12)
setstyle(hint, "top", 10)
setstyle(hint, "color", "#e8dcff")
setstyle(hint, "text-shadow", "0 1px 3px #000")

# ---------------------------------------------------------------- state
let SONG = 60
let state = "title"     # title, play, over
let t = 0
let spawn_t = 0
let beat = 0
let BPM = 116
let speed = 7
let blocks = []
let debris = []
let score = 0
let combo = 0
let max_combo = 0
let mult = 1
let mult_hits = 0
let energy = 50
let cuts = 0
let total = 0
let best = store_get("best", 0)
let best_combo = store_get("best_combo", 0)
let last_dir = ["up", "up"]
let prev_tips = [nil, nil]
let trig_was = false
let flash_t = 0
let flash_txt = ""
let DIRS = {up: [0, 1], down: [0, -1], left: [-1, 0], right: [1, 0]}

fn draw_board() {
  draw_clear(board_c)
  draw_round_rect(board_c, 0, 0, 512, 256, 18, "rgba(18, 4, 34, 0.82)")
  draw_rect(board_c, 0, 0, 512, 6, ["#ff3b5c", "#3b8bff"])
  if state == "title" {
    draw_text(board_c, 256, 60, "KUGEL SABER", "white", 44, "center")
    draw_text(board_c, 256, 110, "Red = left saber · Blue = right saber", "#ffd6f5", 20, "center")
    draw_text(board_c, 256, 140, "Cut the way the arrow points · avoid bombs", "#ffd6f5", 20, "center")
    draw_text(board_c, 256, 190, "Pull a trigger to start", "#7cf7ff", 26, "center")
    draw_text(board_c, 256, 230, `Best {best} · best combo {best_combo}`, "#b9a7d6", 18, "center")
    return
  }
  if state == "over" {
    let title = "SONG CLEARED!"
    if energy <= 0 { title = "FAILED" }
    draw_text(board_c, 256, 50, title, "white", 40, "center")
    draw_text(board_c, 256, 100, `Score {score}`, "#7cf7ff", 32, "center")
    let acc = 0
    if total > 0 { acc = round(cuts * 100 / total) }
    draw_text(board_c, 256, 140, `Max combo {max_combo} · accuracy {acc}%`, "#ffd6f5", 20, "center")
    draw_text(board_c, 256, 175, `Best {best} · best combo {best_combo}`, "#b9a7d6", 18, "center")
    draw_text(board_c, 256, 222, "Pull a trigger to play again", "#7cf7ff", 22, "center")
    return
  }
  draw_text(board_c, 20, 44, `{score}`, "white", 40, "left")
  draw_text(board_c, 492, 44, `x{mult}`, "#ffe066", 40, "right")
  draw_text(board_c, 20, 92, `Combo {combo}`, "#7cf7ff", 24, "left")
  draw_text(board_c, 492, 92, `{max(0, ceil(SONG - t))} s`, "#ffd6f5", 24, "right")
  draw_rect(board_c, 20, 120, 472, 22, "rgba(255, 255, 255, 0.15)")
  let ec = "#2ecc71"
  if energy < 30 { ec = "#e74c3c" }
  draw_rect(board_c, 20, 120, 472 * energy / 100, 22, ec)
  if flash_t > 0 { draw_text(board_c, 256, 200, flash_txt, "#ffe066", 34, "center") }
}

fn show_menu() {
  clear(menu)
  setstyle(menu, "display", "flex")
  let av = vr_available()
  if av == "vr" { button(menu, "🥽 Enter VR", fn() { enter_vr() }) }
  if av == "browser" { button(menu, "🥽 Play in VR (opens the Quest Browser)", fn() { enter_vr() }) }
  button(menu, "▶ Play on screen (Enter)", fn() { start() })
  label(menu, "Screen: the mouse is the right saber · hold Shift for the left · flick the way the arrow points")
}
fn enter_vr() {
  let r = vr_start(s)
  if r == "flat" { start() }
}
fn start() {
  for b in blocks { remove3d(b.g) }
  for d in debris { remove3d(d.o) }
  blocks = []
  debris = []
  t = 0
  spawn_t = 0
  beat = 0
  speed = 7
  score = 0
  combo = 0
  max_combo = 0
  mult = 1
  mult_hits = 0
  energy = 50
  cuts = 0
  total = 0
  state = "play"
  setstyle(menu, "display", "none")
}
fn finish() {
  state = "over"
  if score > best {
    best = score
    store_set("best", best)
  }
  if max_combo > best_combo {
    best_combo = max_combo
    store_set("best_combo", best_combo)
  }
  show_menu()
}
fn flash(txt) {
  flash_txt = txt
  flash_t = 0.7
}

# ---------------------------------------------------------------- blocks
fn make_block(col_, row_, colr, dir) {
  let g = group3d(s)
  let c = "#ff3b5c"
  if colr == 1 { c = "#3b8bff" }
  let cube_ = cube(s, 0.36, 0.36, 0.36, c)
  look3d(cube_, {shiny: 0.6, glow: shade(c, -0.6)})
  attach3d(g, cube_)
  if dir == "any" {
    let dot = sphere(s, 0.06, "#ffffff")
    look3d(dot, {glow: "#ffffff"})
    move3d(dot, 0, 0, 0.19)
    attach3d(g, dot)
  } else {
    let arrow = cone(s, 0.09, 0.14, "#ffffff")
    look3d(arrow, {glow: "#ffffff"})
    move3d(arrow, 0, 0, 0.19)
    let rz = 0
    if dir == "down" { rz = 180 }
    if dir == "left" { rz = 90 }
    if dir == "right" { rz = -90 }
    turn3d(arrow, 0, 0, rz)
    attach3d(g, arrow)
  }
  let b = {g: g, kind: "block", col: colr, dir: dir, x: (col_ - 1.5) * 0.36, y: 0.85 + row_ * 0.36, z: -26, done: false}
  move3d(g, b.x, b.y, b.z)
  push(blocks, b)
  total += 1
  return b
}
fn make_bomb(col_, row_) {
  let g = group3d(s)
  let core = sphere(s, 0.17, "#111111")
  look3d(core, {shiny: 0.9, metal: 0.6})
  attach3d(g, core)
  for k in range(4) {
    let spike = cone(s, 0.04, 0.12, "#333333")
    turn3d(spike, 0, 0, k * 90)
    move3d(spike, sin(k * 90 * PI / 180) * -0.17, cos(k * 90 * PI / 180) * 0.17, 0)
    attach3d(g, spike)
  }
  let b = {g: g, kind: "bomb", col: -1, dir: "any", x: (col_ - 1.5) * 0.36, y: 0.85 + row_ * 0.36, z: -26, done: false}
  move3d(g, b.x, b.y, b.z)
  push(blocks, b)
  return b
}
fn next_dir(hand) {
  let r = random(1, 10)
  let d = "down"
  if last_dir[hand] == "down" { d = "up" }
  if r == 9 { d = "any" }
  if r == 10 {
    if hand == 0 { d = "left" } else { d = "right" }
  }
  last_dir[hand] = d
  return d
}
fn spawn() {
  beat += 1
  let p = random(1, 12)
  if t > SONG - 3 { return }
  if p <= 4 { make_block(random(0, 1), random(0, 1), 0, next_dir(0)) }
  else if p <= 8 { make_block(random(2, 3), random(0, 1), 1, next_dir(1)) }
  else if p <= 10 {
    let row_ = random(0, 1)
    make_block(1, row_, 0, next_dir(0))
    make_block(2, row_, 1, next_dir(1))
  } else if p == 11 and t > 12 {
    make_bomb(random(0, 3), 2)
  } else {
    make_block(random(0, 3), 2, random(0, 1), "any")
  }
}

fn break_block(b, good, vx, vy) {
  b.done = true
  remove3d(b.g)
  let c = "#888888"
  if good {
    c = "#ff3b5c"
    if b.col == 1 { c = "#3b8bff" }
  }
  # two halves fly apart across the cut
  let nx = -vy
  let ny = vx
  let l = max(0.001, sqrt(nx * nx + ny * ny))
  nx = nx / l
  ny = ny / l
  for side in [-1, 1] {
    let o = cube(s, 0.36, 0.18, 0.36, c)
    look3d(o, {glow: shade(c, -0.5), opacity: 0.9})
    turn3d(o, 0, 0, atan2(ny, nx) * 180 / PI - 90)
    move3d(o, b.x + nx * side * 0.1, b.y + ny * side * 0.1, b.z)
    push(debris, {o: o, vx: nx * side * 2 + vx * 0.3, vy: ny * side * 2 + vy * 0.3, vz: speed * 0.5, life: 0.6})
  }
}
fn good_cut(b, hand, h) {
  cuts += 1
  combo += 1
  max_combo = max(max_combo, combo)
  mult_hits += 1
  if mult < 8 and mult_hits >= mult * 2 {
    mult = mult * 2
    mult_hits = 0
    flash(`x{mult}!`)
  }
  score += round((100 + min(15, h.speed * 3)) * mult)
  energy = min(100, energy + 2)
  vr_haptic(s, hand, 0.7, 40)
  break_block(b, true, h.vx, h.vy)
}
fn bad(b, why) {
  combo = 0
  mult_hits = 0
  if mult > 1 { mult = mult / 2 }
  energy -= 12
  flash(why)
  if energy <= 0 {
    energy = 0
    finish()
  }
}

# does the blade (hand + dir * 0.2 .. 1.1, now and last frame) touch block b?
fn touches(hand, h, b) {
  let ks = [0.25, 0.45, 0.65, 0.85, 1.05]
  let pts = []
  for k in ks { push(pts, [h.x + h.dir.x * k, h.y + h.dir.y * k, h.z + h.dir.z * k]) }
  let prev = prev_tips[hand]
  if prev != nil {
    for i, q in prev { push(pts, [(q[0] + pts[i][0]) / 2, (q[1] + pts[i][1]) / 2, (q[2] + pts[i][2]) / 2]) }
  }
  let r = 0.26
  if b.kind == "bomb" { r = 0.2 }
  for q in pts {
    if abs(q[0] - b.x) < r and abs(q[1] - b.y) < r and abs(q[2] - b.z) < r { return true }
  }
  return false
}
fn tips(h) {
  let out = []
  for k in [0.25, 0.45, 0.65, 0.85, 1.05] { push(out, [h.x + h.dir.x * k, h.y + h.dir.y * k, h.z + h.dir.z * k]) }
  return out
}

on_keypress(fn(k) {
  if k == "enter" and state != "play" { start() }
})

on_frame(fn(dt) {
  let hands = vr_hands(s)
  let vr = vr_mode(s) == "vr"
  # trigger (either hand) starts from the title / results
  let trig = hands[0].trigger > 0.7 or hands[1].trigger > 0.7
  if trig and not trig_was and state != "play" and vr { start() }
  trig_was = trig
  flash_t -= dt
  if vr { settext(hint, "") } else if state == "play" { settext(hint, "🖱 mouse = right saber · Shift = left saber · flick the arrow's way") } else { settext(hint, "") }

  if state == "play" {
    t += dt
    speed = 7 + t / SONG * 3
    spawn_t -= dt
    if spawn_t <= 0 and t < SONG - 3 {
      spawn()
      spawn_t += 60 / BPM
    }
    let keep = []
    for b in blocks {
      if b.done { continue }
      b.z += speed * dt
      move3d(b.g, b.x, b.y, b.z)
      # cut window in front of the player
      if b.z > -1.9 and b.z < 0.2 {
        for hand in [0, 1] {
          let h = hands[hand]
          if not b.done and h.connected and touches(hand, h, b) {
            if b.kind == "bomb" {
              b.done = true
              remove3d(b.g)
              vr_haptic(s, hand, 1, 150)
              bad(b, "💣 BOMB")
            } else {
              let ok_col = b.col == hand or not vr
              let ok_dir = h.speed > 1.0
              if b.dir != "any" {
                let d = DIRS[b.dir]
                let sp = sqrt(h.vx * h.vx + h.vy * h.vy)
                ok_dir = sp > 1.2 and (h.vx * d[0] + h.vy * d[1]) / max(sp, 0.001) > 0.5
              }
              if ok_col and ok_dir { good_cut(b, hand, h) }
              else if h.speed > 1.0 {
                break_block(b, false, h.vx, h.vy)
                if not ok_col { bad(b, "WRONG SABER") } else { bad(b, "WRONG WAY") }
              }
            }
          }
        }
      }
      if not b.done and b.z > 0.6 {
        b.done = true
        remove3d(b.g)
        if b.kind == "block" { bad(b, "MISS") }
      }
      if not b.done { push(keep, b) }
    }
    blocks = keep
    if state == "play" and t >= SONG and len(blocks) == 0 { finish() }
  }
  prev_tips = [tips(hands[0]), tips(hands[1])]
  let dk = []
  for d in debris {
    d.life -= dt
    d.vy -= 6 * dt
    shift3d(d.o, d.vx * dt, d.vy * dt, d.vz * dt)
    spin3d(d.o, 200 * dt, 0, 120 * dt)
    scale3d(d.o, max(0.05, d.life / 0.6))
    if d.life > 0 { push(dk, d) } else { remove3d(d.o) }
  }
  debris = dk
  draw_board()
})

draw_board()
show_menu()
