# KUGEL GORILLAS VR - arm-locomotion tag (Kompass VR, KampfScript 3D + VR API)
# You are a gorilla with no legs: put your hands on the ground (or a rock, a tree, the wall) and PUSH to move.
# Push down to jump, swing your arms back to run, let go mid-swing to fly. Grab tree trunks to climb.
# You are IT (lava hands 🔥): tag all 4 gorillas before the timer runs out. Best time is saved.
# Screen: W A S D run, ← → turn, Space jump, bump into a gorilla (or touch it with the mouse hand) to tag it.

let s = scene3d(body())
sky3d(s, "#7ec8ff", "#f4fbff")
fog3d(s, "#cfeaff", 18, 60)
shadows3d(s, true)
vr_setup(s, {hands: false, pitch: -10, height: 1.6})

let FEET = -0.5          # the rig floor is 0.5 m BELOW the grass: you are a short gorilla (eyes ~1.1 m)
let ARENA = 21
let TIME = 120

# ---------------------------------------------------------------- the forest (boxes you can push off and climb)
let ground = plane(s, 70, 70, "#4caf50")
look3d(ground, {texture: "noise", repeat: 14})
let boxes = []
fn solid(x, y, z, w, h, d, c, tex) {
  let o = cube(s, w, h, d, c)
  if tex != "" { look3d(o, {texture: tex, repeat: 2}) }
  move3d(o, x, y, z)
  push(boxes, {x: x, y: y, z: z, w: w, h: h, d: d})
  return o
}
# trees: trunk + a platform + leaves
let TREES = [[-7, -6], [8, -9], [-11, 7], [6, 8], [0, -15], [14, 1], [-15, -4]]
for tr in TREES {
  solid(tr[0], 3.5, tr[1], 0.8, 7, 0.8, "#795548", "noise")
  solid(tr[0], 4.2, tr[1], 3.2, 0.3, 3.2, "#8d6e63", "")
  let leaves = sphere(s, 2.4, "#2e7d32")
  look3d(leaves, {texture: "noise", repeat: 3})
  move3d(leaves, tr[0], 7.4, tr[1])
}
# rocks
let ROCKS = [[-3, 3, 2.6, 1.2, 2.2], [4, -3, 2.2, 0.9, 2.8], [10, -2, 3.4, 2.2, 3], [-8, -12, 3, 1.6, 2.4], [-13, 13, 4, 2.6, 3], [12, 12, 2.6, 1.4, 2.6], [1, 12, 2, 0.8, 2]]
for r in ROCKS { solid(r[0], r[3] / 2, r[1], r[2], r[3], r[4], "#90a4ae", "noise") }
# the arena wall (climb it, push off it)
for k in range(28) {
  let a = k * 360 / 28 * PI / 180
  # (the wall is round, so it is not one of the boxes: touch() and the movers handle it by distance from the centre)
  let w = cube(s, 4.9, 3.2, 0.6, "#6d4c41")
  look3d(w, {texture: "bricks", repeat: 2})
  move3d(w, cos(a) * (ARENA + 0.6), 1.6, sin(a) * (ARENA + 0.6))
  turn3d(w, 0, 90 - k * 360 / 28, 0)
}

# ---------------------------------------------------------------- you: lava gorilla hands
fn make_hand(c) {
  let g = group3d(s)
  let palm = sphere(s, 0.075, "#3e2723")
  scale3d(palm, 1, 0.8, 1.2)
  let lava = sphere(s, 0.05, c)
  look3d(lava, {glow: c})
  move3d(lava, 0, -0.045, -0.02)
  attach3d(g, palm)
  attach3d(g, lava)
  return g
}
vr_attach(s, make_hand("#ff5722"), "left")
vr_attach(s, make_hand("#ff5722"), "right")
# a watch on your left wrist (visible in VR)
let watch_c = canvas(s, 256, 128)
setstyle(watch_c, "display", "none")
let watch = panel3d(s, watch_c, 0.2)
vr_attach(s, watch, "left")
move3d(watch, 0, 0.07, 0.07)
turn3d(watch, -50, 0, 0)

# ---------------------------------------------------------------- the big board on a pole near the start
let board_c = canvas(s, 512, 256)
setstyle(board_c, "display", "none")
let board = panel3d(s, board_c, 3.2)
move3d(board, 0, 3.2, -6)
let pole = cylinder(s, 0.08, 1.8, "#5d4037")
move3d(pole, 0, 0.9, -6.05)

let menu = col(s)
setstyle(menu, "position", "absolute")
setstyle(menu, "left", "50%")
setstyle(menu, "bottom", 24)
setstyle(menu, "transform", "translateX(-50%)")
setstyle(menu, "background", "rgba(30, 20, 10, 0.86)")
setstyle(menu, "color", "white")
setstyle(menu, "padding", "14px 22px")
setstyle(menu, "border-radius", 14)
setstyle(menu, "align-items", "center")
setstyle(menu, "gap", "8px")
setstyle(menu, "text-align", "center")

# ---------------------------------------------------------------- AI gorillas
let COLORS = ["#5d4037", "#424242", "#6d4c41", "#37474f"]
let gorillas = []
fn make_gorilla(i) {
  let g = group3d(s)
  let bod = sphere(s, 0.45, COLORS[i])
  look3d(bod, {texture: "noise", repeat: 2})
  scale3d(bod, 1, 0.9, 1.1)
  move3d(bod, 0, 0.5, 0)
  let face = sphere(s, 0.22, "#a1887f")
  move3d(face, 0, 0.62, -0.36)
  let e1 = sphere(s, 0.05, "#111111")
  move3d(e1, -0.09, 0.72, -0.5)
  let e2 = sphere(s, 0.05, "#111111")
  move3d(e2, 0.09, 0.72, -0.5)
  let a1 = cylinder(s, 0.09, 0.7, COLORS[i])
  move3d(a1, -0.48, 0.3, -0.15)
  turn3d(a1, 20, 0, 15)
  let a2 = cylinder(s, 0.09, 0.7, COLORS[i])
  move3d(a2, 0.48, 0.3, -0.15)
  turn3d(a2, 20, 0, -15)
  for o in [bod, face, e1, e2, a1, a2] { attach3d(g, o) }
  return {g: g, bod: bod, x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, tagged: false, wander: random_float(0, 6.28), hop: random_float(0, 6), jump_cd: 0}
}
for i in range(4) { push(gorillas, make_gorilla(i)) }

# ---------------------------------------------------------------- state
let state = "title"     # title, play, won, lost
let t = 0
let tagged = 0
let best = store_get("best_time", 0)
let P = {x: 0, y: FEET, z: 4, vx: 0, vy: 0, vz: 0}
let yaw = 0
let anchors = [nil, nil]       # per hand: {x, y, z, nx, ny, nz} where the hand is stuck
let last_local = [nil, nil]
let trig_was = false
let msg = ""
let msg_t = 0
let on_ground = true

fn say(m) {
  msg = m
  msg_t = 2
}
fn top_at(x, z, below) {
  # highest box top under (x, z) that is not above "below"
  let top = 0
  for b in boxes {
    if abs(x - b.x) < b.w / 2 and abs(z - b.z) < b.d / 2 {
      let tp = b.y + b.h / 2
      if tp > top and tp <= below + 0.35 { top = tp }
    }
  }
  return top
}
# is there a too-tall obstacle (a trunk, a big rock) at (x, z) for someone standing at height y? (platforms overhead are fine)
fn wall_at(x, z, y) {
  for b in boxes {
    if abs(x - b.x) < b.w / 2 and abs(z - b.z) < b.d / 2 and b.y - b.h / 2 < y + 1.0 and b.y + b.h / 2 > y + 2.4 { return true }
  }
  return false
}
# which surface does a point touch? returns a normal or nil
fn touch(x, y, z) {
  if y < 0.03 { return {nx: 0, ny: 1, nz: 0} }
  let r = sqrt(x * x + z * z)
  if r > ARENA + 0.26 and y < 3.24 {
    if y > 3.12 { return {nx: 0, ny: 1, nz: 0} }
    return {nx: -x / r, ny: 0, nz: -z / r}
  }
  for b in boxes {
    let dx = x - b.x
    let dy = y - b.y
    let dz = z - b.z
    let ex = b.w / 2 + 0.04
    let ey = b.h / 2 + 0.04
    let ez = b.d / 2 + 0.04
    if abs(dx) < ex and abs(dy) < ey and abs(dz) < ez {
      # the face we are closest to
      let px = ex - abs(dx)
      let py = ey - abs(dy)
      let pz = ez - abs(dz)
      if py <= px and py <= pz { return {nx: 0, ny: sign(dy), nz: 0} }
      if px <= pz { return {nx: sign(dx), ny: 0, nz: 0} }
      return {nx: 0, ny: 0, nz: sign(dz)}
    }
  }
  return nil
}

fn draw_boards() {
  draw_clear(board_c)
  draw_round_rect(board_c, 0, 0, 512, 256, 18, "rgba(40, 26, 12, 0.88)")
  draw_rect(board_c, 0, 0, 512, 6, "#ff5722")
  if state == "title" {
    draw_text(board_c, 256, 56, "KUGEL GORILLAS", "white", 42, "center")
    draw_text(board_c, 256, 104, "Hands on the ground and PUSH to move", "#ffe0b2", 21, "center")
    draw_text(board_c, 256, 134, "You're IT: tag all 4 gorillas!", "#ffe0b2", 21, "center")
    draw_text(board_c, 256, 186, "Pull a trigger to start", "#ffab40", 26, "center")
    let bt = "-"
    if best > 0 { bt = fmt(best, 1) + " s" }
    draw_text(board_c, 256, 228, "Best time " + bt, "#bcaaa4", 18, "center")
  } else {
    let title = `Tagged {tagged} / 4`
    if state == "won" { title = "ALL TAGGED! 🦍" }
    if state == "lost" { title = "TIME'S UP" }
    draw_text(board_c, 256, 60, title, "white", 38, "center")
    draw_text(board_c, 256, 120, fmt(t, 1) + " s", "#ffab40", 40, "center")
    let bt = "-"
    if best > 0 { bt = fmt(best, 1) + " s" }
    draw_text(board_c, 256, 170, "Best " + bt, "#bcaaa4", 20, "center")
    if state != "play" { draw_text(board_c, 256, 222, "Pull a trigger to play again", "#ffe0b2", 22, "center") }
    else if msg_t > 0 { draw_text(board_c, 256, 222, msg, "#ffe0b2", 24, "center") }
  }
  draw_clear(watch_c)
  draw_round_rect(watch_c, 0, 0, 256, 128, 20, "rgba(20, 12, 6, 0.9)")
  draw_text(watch_c, 128, 46, `🦍 {tagged}/4`, "white", 34, "center")
  draw_text(watch_c, 128, 98, fmt(max(0, TIME - t), 0) + " s", "#ffab40", 32, "center")
}

fn show_menu(title) {
  clear(menu)
  setstyle(menu, "display", "flex")
  heading(menu, title)
  let av = vr_available()
  if av == "vr" { button(menu, "🥽 Enter VR", fn() { enter_vr() }) }
  if av == "browser" { button(menu, "🥽 Play in VR (opens the Quest Browser)", fn() { enter_vr() }) }
  button(menu, "▶ Play on screen (Enter)", fn() { start() })
  label(menu, "Screen: W A S D run · ← → turn · Space jump · bump into a gorilla to tag it")
}
fn enter_vr() {
  if vr_start(s) == "flat" { start() }
}
fn start() {
  t = 0
  tagged = 0
  P = {x: 0, y: FEET, z: 4, vx: 0, vy: 0, vz: 0}
  yaw = 0
  anchors = [nil, nil]
  let spots = [[-6, -3], [7, -5], [-9, 10], [9, 9]]
  for i, g in gorillas {
    g.x = spots[i][0]
    g.z = spots[i][1]
    g.y = top_at(g.x, g.z, 10)
    g.vx = 0
    g.vy = 0
    g.vz = 0
    g.tagged = false
    color3d(g.bod, COLORS[i])
    look3d(g.bod, {glow: "#000000"})
  }
  state = "play"
  setstyle(menu, "display", "none")
  say("GO! Tag them all!")
}
fn finish(won) {
  if won {
    state = "won"
    if best == 0 or t < best {
      best = t
      store_set("best_time", best)
    }
    show_menu("🦍 All tagged in " + fmt(t, 1) + " s!")
  } else {
    state = "lost"
    show_menu("⏰ Time's up - " + tagged + " of 4 tagged")
  }
}
fn tag(g) {
  g.tagged = true
  tagged += 1
  color3d(g.bod, "#ff5722")
  look3d(g.bod, {glow: "#7a1d00"})
  say("Tagged! " + (4 - tagged) + " to go")
  vr_haptic(s, "left", 0.8, 80)
  vr_haptic(s, "right", 0.8, 80)
  if tagged >= 4 { finish(true) }
}

# ---------------------------------------------------------------- arm locomotion (VR) / keyboard (screen)
fn move_player(dt, vr) {
  let hands = vr_hands(s)
  let anchored = 0
  let sx = 0
  let sy = 0
  let sz = 0
  # on a screen the mouse hand only tags; it never grabs (no accidental tree-hugging)
  let grab_hands = []
  if vr { grab_hands = [0, 1] } else { anchors = [nil, nil] }
  for i in grab_hands {
    let h = hands[i]
    let lx = h.x - P.x
    let ly = h.y - P.y
    let lz = h.z - P.z
    let a = anchors[i]
    if a != nil and last_local[i] != nil {
      # pulling the hand away from the surface lets go; pushing into / along it moves YOU
      let dl = (lx - last_local[i][0]) * a.nx + (ly - last_local[i][1]) * a.ny + (lz - last_local[i][2]) * a.nz
      if dl > 0.004 or not h.connected { anchors[i] = nil }
    }
    # a hand more than 1.4 m from your head is a tracking glitch, not a long arm
    let hd = vr_head(s)
    let reach_ok = dist3d([h.x, h.y, h.z], [hd.x, hd.y, hd.z]) < 1.4
    if not reach_ok { anchors[i] = nil }
    if anchors[i] == nil and h.connected and reach_ok {
      let n = touch(h.x, h.y, h.z)
      if n != nil {
        anchors[i] = {x: h.x, y: max(h.y, 0.0), z: h.z, nx: n.nx, ny: n.ny, nz: n.nz}
        if n.ny > 0 { anchors[i].y = max(h.y, 0) }
        vr_haptic(s, i, 0.25, 25)
      }
    }
    if anchors[i] != nil {
      anchored += 1
      sx += anchors[i].x - lx
      sy += anchors[i].y - ly
      sz += anchors[i].z - lz
    }
    last_local[i] = [lx, ly, lz]
  }
  if anchored > 0 {
    let nx = sx / anchored
    let ny = sy / anchored
    let nz = sz / anchored
    # never more than 0.3 m per frame (no teleporting)
    let dx = clamp(nx - P.x, -0.3, 0.3)
    let dy = clamp(ny - P.y, -0.3, 0.3)
    let dz = clamp(nz - P.z, -0.3, 0.3)
    P.vx = P.vx * 0.5 + dx / dt * 0.5
    P.vy = P.vy * 0.5 + dy / dt * 0.5
    P.vz = P.vz * 0.5 + dz / dt * 0.5
    P.x += dx
    P.y += dy
    P.z += dz
  } else {
    let sp = sqrt(P.vx * P.vx + P.vy * P.vy + P.vz * P.vz)
    if sp > 8 {
      P.vx = P.vx * 8 / sp
      P.vy = P.vy * 8 / sp
      P.vz = P.vz * 8 / sp
    }
    P.vy -= 11 * dt
    P.x += P.vx * dt
    P.y += P.vy * dt
    P.z += P.vz * dt
  }
  # keyboard / gamepad stick (also works in VR: left stick)
  let l = hands[0]
  let fwd = 0
  let side = 0
  if not vr {
    if key_down("w") { fwd += 1 }
    if key_down("s") { fwd -= 1 }
    if key_down("a") { side -= 1 }
    if key_down("d") { side += 1 }
    if key_down("left") { yaw += 100 * dt }
    if key_down("right") { yaw -= 100 * dt }
  }
  let ya = yaw * PI / 180
  if fwd != 0 or side != 0 {
    let sp = 5.4
    P.x += (-sin(ya) * fwd + cos(ya) * side) * sp * dt
    P.z += (-cos(ya) * fwd - sin(ya) * side) * sp * dt
  }
  if not vr and key_down("space") and on_ground { P.vy = 6 }
  # land on the grass / box tops; slide out of trees, rocks and the wall
  let floor_ = top_at(P.x, P.z, P.y - FEET) + FEET
  on_ground = false
  if P.y <= floor_ {
    P.y = floor_
    if P.vy < 0 { P.vy = 0 }
    P.vx *= 0.8
    P.vz *= 0.8
    on_ground = true
  }
  let head_y = P.y + 1.6
  for b in boxes {
    let dx = P.x - b.x
    let dz = P.z - b.z
    let ex = b.w / 2 + 0.3
    let ez = b.d / 2 + 0.3
    let top = b.y + b.h / 2
    if abs(dx) < ex and abs(dz) < ez and P.y - FEET < top - 0.05 and head_y > b.y - b.h / 2 {
      if ex - abs(dx) < ez - abs(dz) {
        P.x = b.x + sign(dx) * ex
        P.vx = 0
      } else {
        P.z = b.z + sign(dz) * ez
        P.vz = 0
      }
    }
  }
  let r = sqrt(P.x * P.x + P.z * P.z)
  if r > ARENA - 0.4 {
    P.x = P.x * (ARENA - 0.4) / r
    P.z = P.z * (ARENA - 0.4) / r
  }
  vr_rig(s, P.x, P.y, P.z, yaw)
}

fn move_gorillas(dt) {
  let me = vr_head(s)
  for g in gorillas {
    if g.tagged {
      g.vx *= 0.9
      g.vz *= 0.9
      g.hop += dt * 3
      move3d(g.g, g.x, g.y + abs(sin(g.hop)) * 0.1, g.z)
      continue
    }
    let dx = g.x - me.x
    let dz = g.z - me.z
    let d = max(0.01, sqrt(dx * dx + dz * dz))
    g.wander += random_float(-1.2, 1.2) * dt
    let ax = cos(g.wander) * 0.6
    let az = sin(g.wander) * 0.6
    let sp = 2.4
    if d < 9 {
      ax += dx / d * 1.6
      az += dz / d * 1.6
      sp = 3.0 + (9 - d) * 0.1
    }
    let r = sqrt(g.x * g.x + g.z * g.z)
    if r > ARENA - 4 {
      ax -= g.x / r * 1.8
      az -= g.z / r * 1.8
    }
    let al = max(0.01, sqrt(ax * ax + az * az))
    g.vx += (ax / al * sp - g.vx) * min(1, dt * 3)
    g.vz += (az / al * sp - g.vz) * min(1, dt * 3)
    let nx = g.x + g.vx * dt
    let nz = g.z + g.vz * dt
    # obstacles: jump onto low ones, go around trunks and the wall
    let floor_here = top_at(g.x, g.z, g.y)
    let ahead = top_at(nx, nz, g.y + 2.4)
    g.jump_cd -= dt
    if ahead > g.y + 0.3 {
      if ahead - g.y < 2.4 and g.y <= floor_here + 0.01 and g.jump_cd <= 0 {
        g.vy = 7.5
        g.jump_cd = 0.6
      } else if ahead - g.y >= 2.4 {
        nx = g.x
        nz = g.z
        g.wander += 1.6
      }
    }
    if wall_at(nx, nz, g.y) and g.vy <= 0 {
      nx = g.x
      nz = g.z
      g.wander += 1.6
    }
    let nr = sqrt(nx * nx + nz * nz)
    if nr > ARENA - 0.6 {
      nx = nx * (ARENA - 0.6) / nr
      nz = nz * (ARENA - 0.6) / nr
    }
    g.x = nx
    g.z = nz
    g.vy -= 14 * dt
    g.y += g.vy * dt
    let fl = top_at(g.x, g.z, g.y)
    if g.y <= fl {
      g.y = fl
      g.vy = 0
    }
    if d < 4 and g.y <= fl + 0.01 and random(1, 90) == 1 { g.vy = 6 }
    g.hop += dt * (4 + sp * 2)
    move3d(g.g, g.x, g.y + abs(sin(g.hop)) * 0.22, g.z)
    turn3d(g.g, 0, atan2(-g.vx, -g.vz) * 180 / PI, 0)
    # tag: your hand touches it, or you crash into it
    if state == "play" {
      let gb = [g.x, g.y + 0.5, g.z]
      let hands = vr_hands(s)
      let hit = dist3d([hands[0].x, hands[0].y, hands[0].z], gb) < 0.6 or dist3d([hands[1].x, hands[1].y, hands[1].z], gb) < 0.6
      if hit or dist3d([me.x, me.y - 0.6, me.z], gb) < 1.0 { tag(g) }
    }
  }
}

on_keypress(fn(k) {
  if k == "enter" and state != "play" { start() }
})

on_frame(fn(dt) {
  let vr = vr_mode(s) == "vr"
  let hands = vr_hands(s)
  let trig = hands[0].trigger > 0.7 or hands[1].trigger > 0.7
  if trig and not trig_was and vr and state != "play" { start() }
  trig_was = trig
  msg_t -= dt
  if state == "play" {
    t += dt
    if t >= TIME {
      t = TIME
      finish(false)
    }
  }
  move_player(dt, vr)
  move_gorillas(dt)
  draw_boards()
})

for i, g in gorillas {
  g.x = -4 + i * 2.6
  g.z = -2
  move3d(g.g, g.x, 0, g.z)
}
vr_rig(s, P.x, P.y, P.z, 0)
draw_boards()
show_menu("🦍 Kugel Gorillas VR")
