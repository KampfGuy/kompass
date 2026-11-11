# SKY HOPPER 3D - a 3D platformer in KampfScript (Kompass 1.5.2+ 3D API)
# Hop the Kugel across floating islands to the golden goal. Moving platforms,
# checkpoints, gems, 3 lives and a saved best time.
# W A S D / arrows move · Space jumps · Enter starts / restarts · gamepad: stick + A

let s = scene3d(body())
sky3d(s, "#5ab0ff", "#fde7c8")
fog3d(s, "#cfe6ff", 30, 95)
shadows3d(s, true)
camera_fov(s, 62)

# ---------------------------------------------------------------- the course: [x, y, z, width, depth, kind]
# kinds: "" plain, "move" slides left/right, "check" checkpoint, "goal" finish, "small" a tiny stepping stone
let COURSE = [
  [0, 0, 0, 5, 5, "check"],
  [0, 0.6, -6, 2.6, 2.6, ""],
  [2.6, 1.4, -10.5, 2.2, 2.2, ""],
  [0, 2.2, -15, 3, 2, "move"],
  [-2.8, 2.8, -19.5, 2.2, 2.2, ""],
  [-2.8, 3.4, -24, 1.6, 1.6, "small"],
  [-0.8, 4, -27.5, 1.6, 1.6, "small"],
  [1.6, 4.6, -31, 1.6, 1.6, "small"],
  [2.8, 4.6, -37, 4, 4, "check"],
  [0, 5.2, -43, 3, 2, "move"],
  [-3, 5.8, -48.5, 3, 2, "move"],
  [0, 6.6, -54, 2, 2, ""],
  [0, 7.6, -58.5, 1.6, 1.6, "small"],
  [0, 8.6, -63, 1.6, 1.6, "small"],
  [0, 8.6, -68.5, 4, 4, "check"],
  [3, 9.4, -74, 2.4, 2.4, "move"],
  [1, 10.2, -79, 1.6, 1.6, "small"],
  [-2, 11, -83, 1.6, 1.6, "small"],
  [0, 11.6, -89, 5, 5, "goal"]
]
let GEMS = [[2.6, 2.4, -10.5], [-2.8, 4.4, -24], [0, 6.2, -43], [0, 8.6, -58.5], [3, 10.4, -74], [-2, 12, -83]]

let plats = []
for i, c in COURSE {
  let kind = c[5]
  let col_ = "#7bc96f"
  if kind == "move" { col_ = "#ff9f43" }
  if kind == "small" { col_ = "#a29bfe" }
  if kind == "check" { col_ = "#55efc4" }
  if kind == "goal" { col_ = "#ffd23f" }
  let top = cube(s, c[3], 0.5, c[4], col_)
  look3d(top, {texture: "grid", repeat: max(1, round(c[3] / 1.2))})
  move3d(top, c[0], c[1] - 0.25, c[2])
  let rock = cone(s, min(c[3], c[4]) * 0.45, 1.6, "#8d6e63")
  turn3d(rock, 180, 0, 0)
  look3d(rock, {texture: "noise", flat: true})
  move3d(rock, c[0], c[1] - 1.3, c[2])
  push(plats, {x: c[0], bx: c[0], y: c[1], z: c[2], w: c[3], d: c[4], kind: kind, top: top, rock: rock, phase: i * 1.7, dx: 0})
  if kind == "check" {
    let pole = cylinder(s, 0.06, 1.6, "#ffffff")
    move3d(pole, c[0] + c[3] / 2 - 0.4, c[1] + 0.8, c[2] - c[4] / 2 + 0.4)
    let flag = cube(s, 0.6, 0.35, 0.04, "#00b894")
    look3d(flag, {glow: "#004d3a"})
    move3d(flag, c[0] + c[3] / 2 - 0.1, c[1] + 1.4, c[2] - c[4] / 2 + 0.4)
  }
  if kind == "goal" {
    let arch = torus(s, 1.6, 0.18, "#ffd23f")
    look3d(arch, {glow: "#a37400", metal: 0.6, shiny: 0.8})
    move3d(arch, c[0], c[1] + 1.6, c[2])
    tag3d(arch, "goal-arch")
  }
}
# a few clouds far below for depth
for i in range(14) {
  let cl = sphere(s, random(15, 30) / 10, "#ffffff")
  look3d(cl, {opacity: 0.85})
  scale3d(cl, 2.2, 0.6, 1.3)
  move3d(cl, random(-30, 30), random(-14, -6), -random(0, 95))
}

let ball = sphere(s, 0.4, "#ff4500")
look3d(ball, {texture: "stripes", shiny: 0.6})
camera_follow(s, ball, 0, 4.5, 8, 6)

# ---------------------------------------------------------------- HUD + panel
let hud = row(s)
setstyle(hud, "padding", "10px 16px")
setstyle(hud, "gap", "22px")
setstyle(hud, "color", "white")
setstyle(hud, "font-size", 19)
setstyle(hud, "font-weight", "bold")
setstyle(hud, "text-shadow", "0 1px 4px #0009")
let lives_l = label(hud, "")
let gems_l = label(hud, "")
let time_l = label(hud, "")
let best_l = label(hud, "")
let panel = col(s)
setstyle(panel, "position", "absolute")
setstyle(panel, "left", "50%")
setstyle(panel, "top", "45%")
setstyle(panel, "transform", "translate(-50%, -50%)")
setstyle(panel, "background", "rgba(20, 30, 60, 0.82)")
setstyle(panel, "color", "white")
setstyle(panel, "padding", "22px 32px")
setstyle(panel, "border-radius", 16)
setstyle(panel, "align-items", "center")
setstyle(panel, "gap", "10px")
setstyle(panel, "text-align", "center")

# ---------------------------------------------------------------- state
let state = "title"
let p = {x: 0, y: 0.4, z: 0, vy: 0}
let ground = nil
let checkpoint = 0
let lives = 3
let t = 0
let clock = 0
let got = 0
let gems = []
let best = store_get("best_time", 0)
let jump_was = false

fn show_panel(title, lines, btn) {
  clear(panel)
  heading(panel, title)
  for l in lines { label(panel, l) }
  button(panel, btn, fn() { start() })
  setstyle(panel, "display", "flex")
}

fn respawn() {
  let c = plats[checkpoint]
  p.x = c.x
  p.y = c.y + 0.4
  p.z = c.z
  p.vy = 0
  ground = c
}

fn start() {
  for g in gems { remove3d(g) }
  gems = []
  for g in GEMS {
    let gem = cone(s, 0.28, 0.5, "#e84393")
    look3d(gem, {glow: "#6c0f3f", shiny: 0.9, flat: true})
    move3d(gem, g[0], g[1], g[2])
    push(gems, gem)
  }
  got = 0
  lives = 3
  t = 0
  checkpoint = 0
  respawn()
  state = "play"
  setstyle(panel, "display", "none")
}

fn finish() {
  state = "won"
  let score_t = t - got * 2
  if best == 0 or score_t < best {
    best = score_t
    store_set("best_time", best)
  }
  show_panel("🏁 You made it!", [`Time {fmt(t, 1)} s − {got} gems × 2 s = {fmt(score_t, 1)} s`, `Best: {fmt(best, 1)} s`], "Play again (Enter)")
}

fn lose_life() {
  lives -= 1
  if lives <= 0 {
    state = "lost"
    show_panel("💥 Out of lives", [`You reached island {checkpoint + 1} of {len(plats)}.`, "Checkpoints are the green islands."], "Try again (Enter)")
  } else {
    respawn()
  }
}

on_keypress(fn(k) {
  if k == "enter" and state != "play" { start() }
})

on_frame(fn(dt) {
  clock += dt
  # moving platforms (always, so the title screen is alive too)
  for q in plats {
    if q.kind == "move" {
      let nx = q.bx + sin(clock * 1.1 + q.phase) * 2.4
      q.dx = nx - q.x
      q.x = nx
      move3d(q.top, q.x, q.y - 0.25, q.z)
      move3d(q.rock, q.x, q.y - 1.3, q.z)
    }
  }
  for g in gems { spin3d(g, 0, 150 * dt, 0) }
  for a in find3d(s, "goal-arch") { spin3d(a, 0, 40 * dt, 0) }
  if state == "play" {
    t += dt
    let gp = gamepad()
    let mx = 0
    let mz = 0
    if key_down("a") or key_down("left") { mx -= 1 }
    if key_down("d") or key_down("right") { mx += 1 }
    if key_down("w") or key_down("up") { mz -= 1 }
    if key_down("s") or key_down("down") { mz += 1 }
    let jump_now = key_down("space")
    if gp.connected {
      mx += gp.lx
      mz += gp.ly
      jump_now = jump_now or gp.a
    }
    let len_ = sqrt(mx * mx + mz * mz)
    if len_ > 1 {
      mx /= len_
      mz /= len_
    }
    p.x += mx * 5.5 * dt
    p.z += mz * 5.5 * dt
    if ground != nil { p.x += ground.dx }
    if jump_now and not jump_was and ground != nil { p.vy = 10 }
    jump_was = jump_now
    let old_y = p.y
    p.vy -= 24 * dt
    p.y += p.vy * dt
    ground = nil
    for i, q in plats {
      if abs(p.x - q.x) <= q.w / 2 + 0.15 and abs(p.z - q.z) <= q.d / 2 + 0.15 and p.vy <= 0 and old_y - 0.4 >= q.y - 0.12 and p.y - 0.4 <= q.y {
        p.y = q.y + 0.4
        p.vy = 0
        ground = q
        if q.kind == "check" and i > checkpoint { checkpoint = i }
        if q.kind == "goal" { finish() }
      }
    }
    if p.y < -10 { lose_life() }
    move3d(ball, p.x, p.y, p.z)
    spin3d(ball, mz * 400 * dt, 0, -mx * 400 * dt)
    let keep = []
    for g in gems {
      if dist3d(g, ball) < 0.8 {
        remove3d(g)
        got += 1
      } else { push(keep, g) }
    }
    gems = keep
  } else {
    move3d(ball, p.x, p.y + 0.1 * sin(clock * 3), p.z)
  }
  settext(lives_l, "❤ " + lives)
  settext(gems_l, `💎 {got} / {len(GEMS)}`)
  settext(time_l, `⏱ {fmt(t, 1)} s`)
  if best > 0 { settext(best_l, `★ {fmt(best, 1)} s`) } else { settext(best_l, "★ —") }
})

show_panel("☁ Sky Hopper 3D", ["Hop to the golden ring at the top.", "W A S D / arrows move · Space jumps", "Gems take 2 s off your time. Green islands are checkpoints."], "▶ Start (Enter)")
