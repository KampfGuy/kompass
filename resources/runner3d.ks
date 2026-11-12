# ============================================================================
#  Kugel Runner 3D — a 3D lane runner written in KampfScript (Kompass 1.5.2)
#  Open kompass://runner3d.  ← → (or A D) switch lanes · Space / ↑ / W jump ·
#  Enter restarts.  Gamepad: left stick switches lanes, A jumps, Start restarts.
#  Dodge the purple blocks, jump the red bars, grab the coins.
# ============================================================================
let LANES = [-2.2, 0, 2.2]
let TILE = 20
let TILES = 9

let s = scene3d(body())
sky3d(s, "#3d8bff", "#d9f1ff")
fog3d(s, "#cfe8ff", 30, 110)
shadows3d(s, true)
camera_fov(s, 65)

# ---------------------------------------------------------------- track: tiles that wrap around forever
let tiles = []
for i in range(TILES) {
  let g = group3d(s)
  let floor_ = cube(s, 7.6, 0.4, TILE, "#e6e9f0")
  if i % 2 == 1 { color3d(floor_, "#d3d8e4") }
  look3d(floor_, {texture: "grid", repeat: 3})
  move3d(floor_, 0, -0.2, 0)
  attach3d(g, floor_)
  for side in [-1, 1] {
    let rail = cube(s, 0.3, 0.5, TILE, "#22d3ee")
    look3d(rail, {glow: "#0e7490"})
    move3d(rail, side * 3.95, 0.05, 0)
    attach3d(g, rail)
  }
  move3d(g, 0, 0, -i * TILE)
  push(tiles, g)
}

let ball = sphere(s, 0.5, "#ff4500")
look3d(ball, {texture: "stripes", shiny: 0.7})
camera_follow(s, ball, 0, 3.4, 7, 9)

# ---------------------------------------------------------------- HUD
let hud = row(s)
setstyle(hud, "padding", "10px 16px")
setstyle(hud, "gap", "24px")
setstyle(hud, "color", "white")
setstyle(hud, "font-size", 20)
setstyle(hud, "font-weight", "bold")
setstyle(hud, "text-shadow", "0 1px 4px #0008")
let dist_l = label(hud, "")
let coin_l = label(hud, "")
let best_l = label(hud, "")
let panel = col(s)
setstyle(panel, "position", "absolute")
setstyle(panel, "left", "50%")
setstyle(panel, "top", "42%")
setstyle(panel, "transform", "translate(-50%, -50%)")
setstyle(panel, "background", "rgba(15, 23, 42, 0.8)")
setstyle(panel, "color", "white")
setstyle(panel, "padding", "22px 30px")
setstyle(panel, "border-radius", 14)
setstyle(panel, "align-items", "center")
setstyle(panel, "gap", "10px")
heading(panel, "Kugel Runner 3D")
label(panel, "← → or A D switch lanes · Space / ↑ jumps")
button(panel, "▶ Start (Space)", fn() { start() })

fn start() {
  started = true
  setstyle(panel, "display", "none")
}

# ---------------------------------------------------------------- state
let lane = 1
let x = 0
let y = 0.5
let vy = 0
let z = 0
let speed = 12
let coins = 0
let things = []
let next_spawn = -30
let over = false
let started = false
let best = store_get("runner3d_best", 0)
let pad_lane = 0
let pad_jump = false

fn jump() { if y <= 0.501 and not over and started { vy = 11 } }
fn steer(d) { if not over and started { lane = clamp(lane + d, 0, 2) } }

fn spawn(at) {
  let r = random(1, 10)
  if r <= 2 {
    let bar = cube(s, 7.2, 0.45, 0.5, "#ef4444")
    look3d(bar, {glow: "#450a0a"})
    move3d(bar, 0, 0.25, at)
    tag3d(bar, "block")
    push(things, bar)
  } else {
    let free = random(0, 2)
    for i in range(3) {
      if i != free and random(1, 10) <= 7 {
        let b = cube(s, 1.6, 1.3, 1.2, "#7c3aed")
        look3d(b, {texture: "checker", shiny: 0.3})
        move3d(b, LANES[i], 0.65, at)
        tag3d(b, "block")
        push(things, b)
      }
    }
    for k in range(3) {
      let c = torus(s, 0.35, 0.11, "#facc15")
      look3d(c, {glow: "#713f12", metal: 0.6, shiny: 0.8})
      move3d(c, LANES[free], 0.9, at + 2.5 + k * 2.2)
      tag3d(c, "coin")
      push(things, c)
    }
  }
}

fn restart() {
  for t in things { remove3d(t) }
  things = []
  lane = 1
  x = 0
  y = 0.5
  vy = 0
  z = 0
  speed = 12
  coins = 0
  next_spawn = -30
  over = false
  for i, g in tiles { move3d(g, 0, 0, -i * TILE) }
  setstyle(panel, "display", "none")
}

fn crash() {
  over = true
  let score = round(-z) + coins * 10
  if score > best {
    best = score
    store_set("runner3d_best", best)
  }
  clear(panel)
  heading(panel, "Crash!")
  label(panel, `Score {score}  ·  {round(-z)} m  ·  {coins} coins`)
  button(panel, "Run again (Enter)", fn() { restart() })
  setstyle(panel, "display", "flex")
}

on_keypress(fn(k) {
  if not started {
    if k == "space" or k == "enter" { start() }
    return
  }
  if k == "left" or k == "a" { steer(-1) }
  if k == "right" or k == "d" { steer(1) }
  if k == "space" or k == "up" or k == "w" { jump() }
  if k == "enter" and over { restart() }
})

on_frame(fn(dt) {
  let gp = gamepad()
  if gp.connected {
    let want = 0
    if gp.lx < -0.5 or gp.left { want = -1 }
    if gp.lx > 0.5 or gp.right { want = 1 }
    if want != pad_lane and want != 0 { steer(want) }
    pad_lane = want
    if gp.a and not pad_jump { jump() }
    pad_jump = gp.a
    if gp.start and over { restart() }
    if (gp.start or gp.a) and not started { start() }
  }
  if not over and started {
    speed = min(30, 12 + (-z) / 60)
    z -= speed * dt
    x += (LANES[lane] - x) * min(1, dt * 12)
    vy -= 32 * dt
    y = max(0.5, y + vy * dt)
    if y == 0.5 { vy = 0 }
    move3d(ball, x, y, z)
    spin3d(ball, -speed * dt * 115, 0, 0)
    # recycle the track tiles that are behind the ball
    for g in tiles {
      let p = pos3d(g)
      if p.z > z + TILE * 1.5 { move3d(g, 0, 0, p.z - TILES * TILE) }
    }
    while next_spawn > z - 90 {
      spawn(next_spawn)
      next_spawn -= random(14, 20)
    }
    let c = hits3d(ball, "coin")
    if c != nil {
      remove3d(c)
      coins += 1
    }
    if hits3d(ball, "block") != nil { crash() }
    let keep = []
    for t in things {
      if tag3d(t) == "coin" { spin3d(t, 0, 180 * dt, 0) }
      if pos3d(t).z > z + 8 { remove3d(t) } else { push(keep, t) }
    }
    things = keep
  }
  settext(dist_l, `🏁 {round(-z)} m`)
  settext(coin_l, `🪙 {coins}`)
  settext(best_l, `★ best {best}`)
})
