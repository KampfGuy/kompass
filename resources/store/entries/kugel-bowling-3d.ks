# KUGEL BOWLING 3D - 3D bowling in KampfScript (Kompass 1.5.2+ 3D API)
# 5 frames, 2 balls each. Strikes and spares earn bonus pins. Best game is saved.
# ← → move the ball · ↑ ↓ (or A D) aim · hold Space to charge, release to throw
# Enter starts / restarts · gamepad: stick, A to charge + release

let s = scene3d(body())
sky3d(s, "#1d1b2f", "#3b2f4a")
shadows3d(s, true)
camera_fov(s, 55)
let LANE_LEN = 18
let HALF = 0.62
let PIN_Z = -16

# ---------------------------------------------------------------- the alley
let floor_ = cube(s, 6, 0.2, 26, "#2d2440")
move3d(floor_, 0, -0.2, -8)
let lane = cube(s, HALF * 2, 0.06, LANE_LEN + 2, "#d9a066")
look3d(lane, {texture: "stripes", repeat: 2, shiny: 0.8})
move3d(lane, 0, -0.03, -LANE_LEN / 2 + 1)
for side in [-1, 1] {
  let gutter = cube(s, 0.22, 0.04, LANE_LEN + 2, "#4b4b5c")
  move3d(gutter, side * (HALF + 0.11), -0.07, -LANE_LEN / 2 + 1)
  let rail = cube(s, 0.08, 0.16, LANE_LEN + 2, "#ff4fa3")
  look3d(rail, {glow: "#7a1048"})
  move3d(rail, side * (HALF + 0.27), 0.02, -LANE_LEN / 2 + 1)
  for k in range(4) {
    let lamp = light3d(s, "point", "#ffd1f0", 3, side * 1.4, 1.6, -k * 5)
  }
}
let back = cube(s, 3, 1.6, 0.2, "#120f1d")
move3d(back, 0, 0.6, PIN_Z - 1.6)
for i in range(7) {
  let arrow = cone(s, 0.05, 0.16, "#ffffff")
  turn3d(arrow, -90, 0, 0)
  look3d(arrow, {glow: "#666666"})
  move3d(arrow, (i - 3) * 0.16, 0.005, -4.5 - abs(i - 3) * 0.25)
}

# ---------------------------------------------------------------- pins (standard triangle)
let pins = []
fn rack(only_standing) {
  let old = pins
  pins = []
  let i = 0
  for row in range(4) {
    for k in range(row + 1) {
      let keep_it = true
      if only_standing { keep_it = not old[i].down }
      if len(old) > i { remove3d(old[i].g) }
      let px = (k - row / 2) * 0.3
      let pz = PIN_Z - row * 0.26
      let g = group3d(s)
      let body_ = cylinder(s, 0.08, 0.42, "#f5f5f5")
      move3d(body_, 0, 0.21, 0)
      let stripe = torus(s, 0.075, 0.02, "#e74c3c")
      turn3d(stripe, 90, 0, 0)
      move3d(stripe, 0, 0.33, 0)
      let head = sphere(s, 0.07, "#f5f5f5")
      move3d(head, 0, 0.46, 0)
      attach3d(g, body_)
      attach3d(g, stripe)
      attach3d(g, head)
      move3d(g, px, 0, pz)
      let p = {g: g, x: px, z: pz, down: not keep_it, vx: 0, vz: 0, tilt: 0, counted: not keep_it}
      if not keep_it { show3d(g, false) }
      push(pins, p)
      i += 1
    }
  }
}

let ball = sphere(s, 0.18, "#6c5ce7")
look3d(ball, {texture: "noise", shiny: 0.9, metal: 0.3})
let aim_line = cube(s, 0.02, 0.01, 2.5, "#ffffff")
look3d(aim_line, {glow: "#ffffff", opacity: 0.6})

# ---------------------------------------------------------------- HUD
let hud = row(s)
setstyle(hud, "padding", "10px 16px")
setstyle(hud, "gap", "20px")
setstyle(hud, "color", "white")
setstyle(hud, "font-size", 18)
setstyle(hud, "font-weight", "bold")
setstyle(hud, "text-shadow", "0 1px 3px #000")
let frame_l = label(hud, "")
let score_l = label(hud, "")
let best_l = label(hud, "")
let msg_l = label(hud, "")
let meter = canvas(s, 200, 22)
setstyle(meter, "position", "absolute")
setstyle(meter, "left", "50%")
setstyle(meter, "bottom", 18)
setstyle(meter, "transform", "translateX(-50%)")
let panel = col(s)
setstyle(panel, "position", "absolute")
setstyle(panel, "left", "50%")
setstyle(panel, "top", "45%")
setstyle(panel, "transform", "translate(-50%, -50%)")
setstyle(panel, "background", "rgba(25, 15, 40, 0.86)")
setstyle(panel, "color", "white")
setstyle(panel, "padding", "22px 32px")
setstyle(panel, "border-radius", 16)
setstyle(panel, "align-items", "center")
setstyle(panel, "gap", "10px")
setstyle(panel, "text-align", "center")

# ---------------------------------------------------------------- state
let FRAMES = 5
let state = "title"     # title, aim, roll, settle, over
let frame = 1
let roll = 1
let score = 0
let first = 0
let bonus = 0           # extra balls that count double (after strike / spare)
let bx = 0
let angle = 0
let power = 0
let charging = false
let charge_dir = 1
let b = {x: 0, z: -0.3, vx: 0, vz: 0, gutter: false, hook: 0}
let wait = 0
let best = store_get("best", 0)
let msg_t = 0
let last_down = 0

fn say(t) {
  settext(msg_l, t)
  msg_t = 2.2
}
fn show_panel(title, lines, btn) {
  clear(panel)
  heading(panel, title)
  for l in lines { label(panel, l) }
  button(panel, btn, fn() { start() })
  setstyle(panel, "display", "flex")
}
fn start() {
  frame = 1
  roll = 1
  score = 0
  bonus = 0
  rack(false)
  new_ball()
  setstyle(panel, "display", "none")
}
fn new_ball() {
  b = {x: bx, z: -0.3, vx: 0, vz: 0, gutter: false, hook: 0}
  power = 0
  charging = false
  state = "aim"
  show3d(aim_line, true)
  camera3d(s, 0, 1.15, 2.2, 0, 0, PIN_Z)
  camera_follow(s, nil)
}
fn standing() {
  let n = 0
  for p in pins { if not p.down { n += 1 } }
  return n
}
fn throw_ball() {
  let sp = 7 + power * 9
  let a = angle * PI / 180
  b.vx = sin(a) * sp
  b.vz = -cos(a) * sp
  # fast balls hook a bit (random way): aim for the pocket, not just the head pin
  b.hook = random(-10, 10) / 10 * (0.15 + power * 0.35)
  state = "roll"
  show3d(aim_line, false)
  camera_follow(s, ball, 0, 0.9, 2.2, 5)
}
fn knock(p, vx, vz) {
  if p.down { return }
  p.down = true
  p.vx = vx
  p.vz = vz
}
fn end_roll() {
  let downed = 0
  for p in pins {
    if p.down and not p.counted {
      p.counted = true
      downed += 1
    }
  }
  let pts = downed
  if bonus > 0 {
    pts = downed * 2
    bonus -= 1
  }
  score += pts
  last_down = downed
  if roll == 1 {
    first = downed
    if downed == 10 {
      say("STRIKE! ⚡")
      bonus = 2
      next_frame()
      return
    }
    say(`{downed} pins`)
    roll = 2
    new_ball()
    return
  }
  if first + downed == 10 {
    say("SPARE! ✨")
    bonus = 1
  } else { say(`{first + downed} pins this frame`) }
  next_frame()
}
fn next_frame() {
  if frame >= FRAMES {
    state = "over"
    if score > best {
      best = score
      store_set("best", best)
    }
    show_panel("🎳 Game over", [`Score {score}`, `Best {best}`, "Strike = next 2 balls count double · spare = next ball"], "Bowl again (Enter)")
    return
  }
  frame += 1
  roll = 1
  rack(false)
  new_ball()
}

on_keypress(fn(k) {
  if k == "enter" and (state == "title" or state == "over") { start() }
})

on_frame(fn(dt) {
  msg_t -= dt
  if msg_t <= 0 { settext(msg_l, "") }
  let gp = gamepad()
  if state == "aim" {
    let mv = 0
    let tn = 0
    if key_down("left") { mv -= 1 }
    if key_down("right") { mv += 1 }
    if key_down("up") or key_down("a") { tn -= 1 }
    if key_down("down") or key_down("d") { tn += 1 }
    if gp.connected {
      mv += gp.lx
      tn += gp.rx
    }
    bx = clamp(bx + mv * 1.2 * dt, -HALF + 0.2, HALF - 0.2)
    angle = clamp(angle + tn * 12 * dt, -6, 6)
    b.x = bx
    move3d(ball, b.x, 0.18, b.z)
    move3d(aim_line, b.x + sin(angle * PI / 180) * 1.4, 0.01, b.z - cos(angle * PI / 180) * 1.4)
    turn3d(aim_line, 0, -angle, 0)
    let hold = key_down("space") or (gp.connected and gp.a)
    if hold {
      charging = true
      power += charge_dir * dt * 1.1
      if power >= 1 { charge_dir = -1 }
      if power <= 0 { charge_dir = 1 }
      power = clamp(power, 0, 1)
    } else if charging { throw_ball() }
  } else if state == "roll" {
    b.vx += b.hook * dt
    b.x += b.vx * dt
    b.z += b.vz * dt
    if not b.gutter and abs(b.x) > HALF {
      b.gutter = true
      say("Gutter ball…")
    }
    if b.gutter {
      if b.x > 0 { b.x = HALF + 0.11 } else { b.x = -HALF - 0.11 }
      b.vx = 0
    }
    move3d(ball, b.x, 0.18, b.z)
    spin3d(ball, -b.vz * 300 * dt, 0, 0)
    if not b.gutter {
      for p in pins {
        let dx = p.x - b.x
        let dz = p.z - b.z
        let d = sqrt(dx * dx + dz * dz)
        if not p.down and d < 0.26 {
          knock(p, b.vx * 0.35 + dx / d * 2.2, b.vz * 0.3 + dz / d * 1.6)
          b.vx = b.vx * 0.85 - dx / d * 0.9
          b.vz *= 0.88
        }
      }
    }
    if b.z < PIN_Z - 1.4 {
      state = "settle"
      wait = 1.6
    }
  } else if state == "settle" {
    wait -= dt
    if wait <= 0 { end_roll() }
  }
  # falling pins slide, tip over and knock their neighbours
  for p in pins {
    if p.down and p.tilt < 90 {
      p.x += p.vx * dt
      p.z += p.vz * dt
      p.vx *= 0.96
      p.vz *= 0.96
      p.tilt = min(90, p.tilt + 300 * dt)
      move3d(p.g, p.x, 0.07 * p.tilt / 90, p.z)
      turn3d(p.g, -p.tilt * (p.vz / (abs(p.vz) + abs(p.vx) + 0.01)), 0, p.tilt * (p.vx / (abs(p.vz) + abs(p.vx) + 0.01)))
      for q in pins {
        if not q.down {
          let dx = q.x - p.x
          let dz = q.z - p.z
          let d = sqrt(dx * dx + dz * dz)
          if d < 0.24 and (abs(p.vx) + abs(p.vz)) > 1.4 { knock(q, p.vx * 0.5 + dx / d * 0.5, p.vz * 0.5 + dz / d * 0.5) }
        }
      }
    }
  }
  # HUD
  draw_clear(meter)
  draw_rect(meter, 0, 0, 200, 22, "rgba(0, 0, 0, 0.5)")
  if state == "aim" {
    draw_rect(meter, 2, 2, 196 * power, 18, ["#2ecc71", "#f1c40f", "#e74c3c"])
    draw_text(meter, 100, 11, "hold Space · power", "white", 11, "center")
  }
  settext(frame_l, `Frame {frame}/{FRAMES} · ball {roll}`)
  settext(score_l, `Score {score}`)
  settext(best_l, `★ {best}`)
})

rack(false)
new_ball()
state = "title"
show_panel("🎳 Kugel Bowling 3D", ["← → move · ↑ ↓ aim · hold Space for power, release to bowl", "5 frames · strikes and spares give bonus points"], "▶ Start (Enter)")
