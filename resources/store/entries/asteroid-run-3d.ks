# ASTEROID RUN 3D - a 3D space shooter in KampfScript (Kompass 1.5.2+ 3D API)
# Fly through an asteroid field, blast rocks, grab green shield rings.
# Waves get faster every 25 seconds. 3 lives, saved high score.
# W A S D / arrows fly · Space shoots · Enter starts · gamepad: stick + A

let s = scene3d(body())
sky3d(s, "#02030a", "#101a3a")
fog3d(s, "#050817", 40, 110)
light3d(s, "none")
light3d(s, "ambient", "#8899ff", 0.6)
light3d(s, "sun", "#ffffff", 2.4, 4, 6, 8)
camera3d(s, 0, 1.6, 9, 0, 0, -12)
camera_fov(s, 70)

# ---------------------------------------------------------------- stars streaming past
let stars = []
for i in range(90) {
  let st = cube(s, 0.06, 0.06, 0.9, "#ffffff")
  look3d(st, {glow: "#ffffff"})
  move3d(st, random(-40, 40), random(-25, 25), -random(0, 110))
  push(stars, st)
}

# ---------------------------------------------------------------- the ship
let ship = group3d(s)
let hull = cone(s, 0.45, 1.8, "#dfe6e9")
turn3d(hull, -90, 0, 0)
look3d(hull, {metal: 0.6, shiny: 0.7})
attach3d(ship, hull)
let wing = cube(s, 2.4, 0.08, 0.7, "#0984e3")
move3d(wing, 0, 0, 0.35)
look3d(wing, {glow: "#06305a"})
attach3d(ship, wing)
let engine = sphere(s, 0.22, "#ff7675")
move3d(engine, 0, 0, 0.95)
look3d(engine, {glow: "#ff3b2f"})
attach3d(ship, engine)

# ---------------------------------------------------------------- HUD
let hud = row(s)
setstyle(hud, "padding", "10px 16px")
setstyle(hud, "gap", "22px")
setstyle(hud, "color", "#e0f2ff")
setstyle(hud, "font-size", 19)
setstyle(hud, "font-weight", "bold")
setstyle(hud, "font-family", "Kompass Mono")
let score_l = label(hud, "")
let lives_l = label(hud, "")
let wave_l = label(hud, "")
let best_l = label(hud, "")
let heat_c = canvas(s, 160, 14)
setstyle(heat_c, "position", "absolute")
setstyle(heat_c, "left", "50%")
setstyle(heat_c, "bottom", 16)
setstyle(heat_c, "transform", "translateX(-50%)")
let panel = col(s)
setstyle(panel, "position", "absolute")
setstyle(panel, "left", "50%")
setstyle(panel, "top", "45%")
setstyle(panel, "transform", "translate(-50%, -50%)")
setstyle(panel, "background", "rgba(5, 10, 30, 0.85)")
setstyle(panel, "border", "1px solid #3d7bff")
setstyle(panel, "color", "white")
setstyle(panel, "padding", "22px 32px")
setstyle(panel, "border-radius", 14)
setstyle(panel, "align-items", "center")
setstyle(panel, "gap", "10px")
setstyle(panel, "text-align", "center")

# ---------------------------------------------------------------- state
let state = "title"
let x = 0
let y = 0
let lives = 3
let score = 0
let t = 0
let wave = 1
let inv = 0
let cool = 0
let heat = 0
let locked = false
let spawn_t = 0
let rocks = []
let shots = []
let bits = []
let rings = []
let best = store_get("best", 0)

fn show_panel(title, lines, btn) {
  clear(panel)
  heading(panel, title)
  for l in lines { label(panel, l) }
  button(panel, btn, fn() { start() })
  setstyle(panel, "display", "flex")
}

fn clear_all() {
  for r in rocks { remove3d(r.o) }
  for b in shots { remove3d(b) }
  for b in bits { remove3d(b.o) }
  for r in rings { remove3d(r) }
  rocks = []
  shots = []
  bits = []
  rings = []
}

fn start() {
  clear_all()
  x = 0
  y = 0
  lives = 3
  score = 0
  t = 0
  wave = 1
  inv = 1.5
  heat = 0
  locked = false
  spawn_t = 0
  show3d(ship, true)
  state = "play"
  setstyle(panel, "display", "none")
}

fn speed() { return 22 + wave * 5 }

fn spawn_rock() {
  let r = random(5, 16) / 10
  let o = sphere(s, r, "#8d7b68")
  look3d(o, {texture: "noise", flat: true, shiny: 0.1})
  scale3d(o, 1, random(7, 12) / 10, random(8, 13) / 10)
  move3d(o, random(-70, 70) / 10, random(-40, 40) / 10, -100)
  # most rocks fly at where the ship is now (plus a little miss), so sitting still is not safe
  let tx = random(-70, 70) / 10
  let ty = random(-40, 40) / 10
  if random(1, 3) > 1 {
    tx = x + random(-15, 15) / 10
    ty = y + random(-10, 10) / 10
  }
  let p0 = pos3d(o)
  let secs = 100 / speed()
  push(rocks, {o: o, r: r, sx: random(-90, 90), sy: random(-90, 90), dx: (tx - p0.x) / secs, dy: (ty - p0.y) / secs})
}

fn burst(at, colr, n) {
  for i in range(n) {
    let b = cube(s, 0.18, 0.18, 0.18, colr)
    look3d(b, {glow: colr})
    move3d(b, at.x, at.y, at.z)
    push(bits, {o: b, vx: random(-80, 80) / 10, vy: random(-80, 80) / 10, vz: random(-80, 80) / 10, life: 0.7})
  }
}

fn hit_ship() {
  burst(pos3d(ship), "#ff7675", 14)
  lives -= 1
  inv = 2
  if lives <= 0 {
    state = "over"
    show3d(ship, false)
    if score > best {
      best = score
      store_set("best", best)
    }
    show_panel("💥 Ship destroyed", [`Score {score}  ·  wave {wave}`, `High score {best}`], "Fly again (Enter)")
  }
}

on_keypress(fn(k) {
  if k == "enter" and state != "play" { start() }
})

on_frame(fn(dt) {
  let sp = speed()
  if state != "play" { sp = 18 }
  for st in stars {
    shift3d(st, 0, 0, sp * 1.6 * dt)
    if pos3d(st).z > 10 { shift3d(st, 0, 0, -120) }
  }
  let keep_bits = []
  for b in bits {
    b.life -= dt
    shift3d(b.o, b.vx * dt, b.vy * dt, b.vz * dt)
    spin3d(b.o, 300 * dt, 200 * dt, 0)
    if b.life <= 0 { remove3d(b.o) } else { push(keep_bits, b) }
  }
  bits = keep_bits
  if state != "play" {
    spin3d(ship, 0, 0, 40 * dt)
    settext(score_l, `SCORE {score}`)
    settext(best_l, `HI {best}`)
    return
  }
  t += dt
  wave = 1 + floor(t / 25)
  inv = max(0, inv - dt)
  cool = max(0, cool - dt)
  # ---- fly
  let gp = gamepad()
  let mx = 0
  let my = 0
  if key_down("a") or key_down("left") { mx -= 1 }
  if key_down("d") or key_down("right") { mx += 1 }
  if key_down("w") or key_down("up") { my += 1 }
  if key_down("s") or key_down("down") { my -= 1 }
  let fire = key_down("space")
  if gp.connected {
    mx += gp.lx
    my -= gp.ly
    fire = fire or gp.a or gp.rt > 0.5
  }
  x = clamp(x + mx * 9 * dt, -7, 7)
  y = clamp(y + my * 7 * dt, -3.8, 4)
  move3d(ship, x, y, 0)
  turn3d(ship, my * 12, 0, -mx * 30)
  show3d(ship, inv == 0 or floor(t * 12) % 2 == 0)
  # ---- shoot
  heat = max(0, heat - 0.35 * dt)
  if locked and heat < 0.4 { locked = false }
  if fire and cool == 0 and not locked {
    heat += 0.08
    if heat >= 1 { locked = true }
    for side in [-1, 1] {
      let b = cylinder(s, 0.05, 1.2, "#74f7ff")
      look3d(b, {glow: "#00d2ff"})
      turn3d(b, 90, 0, 0)
      move3d(b, x + side * 0.9, y, -0.6)
      push(shots, b)
    }
    cool = 0.16
  }
  # ---- spawn
  spawn_t -= dt
  if spawn_t <= 0 {
    spawn_rock()
    spawn_t = max(0.18, 0.75 - wave * 0.07)
    if random(1, 14) == 1 {
      let ring = torus(s, 0.6, 0.12, "#2ecc71")
      look3d(ring, {glow: "#0b6b35"})
      move3d(ring, random(-60, 60) / 10, random(-30, 30) / 10, -100)
      push(rings, ring)
    }
  }
  # ---- move shots, rocks, rings
  let keep_shots = []
  for b in shots {
    shift3d(b, 0, 0, -70 * dt)
    if pos3d(b).z < -105 { remove3d(b) } else { push(keep_shots, b) }
  }
  shots = keep_shots
  let keep_rocks = []
  for r in rocks {
    shift3d(r.o, r.dx * dt, r.dy * dt, sp * dt)
    spin3d(r.o, r.sx * dt, r.sy * dt, 0)
    let dead = false
    let keep2 = []
    for b in shots {
      if not dead and dist3d(b, r.o) < r.r + 0.5 {
        dead = true
        remove3d(b)
      } else { push(keep2, b) }
    }
    shots = keep2
    if dead {
      score += round(30 / r.r)
      burst(pos3d(r.o), "#ffb86b", 8)
      remove3d(r.o)
    } else if inv == 0 and dist3d(r.o, ship) < r.r + 0.55 {
      remove3d(r.o)
      hit_ship()
    } else if pos3d(r.o).z > 12 {
      remove3d(r.o)
    } else { push(keep_rocks, r) }
  }
  rocks = keep_rocks
  if state != "play" { return }
  let keep_rings = []
  for ring in rings {
    shift3d(ring, 0, 0, sp * dt)
    spin3d(ring, 0, 120 * dt, 0)
    if dist3d(ring, ship) < 1.1 {
      lives = min(5, lives + 1)
      score += 50
      burst(pos3d(ring), "#2ecc71", 10)
      remove3d(ring)
    } else if pos3d(ring).z > 12 { remove3d(ring) } else { push(keep_rings, ring) }
  }
  rings = keep_rings
  score += round(dt * 10 * wave)
  settext(score_l, `SCORE {score}`)
  settext(lives_l, "♥ " + lives)
  settext(wave_l, `WAVE {wave}`)
  settext(best_l, `HI {best}`)
  draw_clear(heat_c)
  draw_rect(heat_c, 0, 0, 160, 14, "rgba(0, 0, 0, 0.5)")
  let hc = "#74f7ff"
  if locked { hc = "#ff5252" }
  draw_rect(heat_c, 1, 1, 158 * min(1, heat), 12, hc)
  if locked { draw_text(heat_c, 80, 7, "OVERHEAT", "white", 10, "center") }
})

show_panel("☄ Asteroid Run 3D", ["Fly with W A S D / arrows, shoot with Space.", "Don't hold Space forever: the guns overheat.", "Green rings give an extra life.", "Every 25 s a faster wave arrives."], "▶ Launch (Enter)")
