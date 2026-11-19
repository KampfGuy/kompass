# KUGEL TENNIS VR - swing your controller like a racket (Kompass VR, KampfScript 3D + VR API)
# Wii-Tennis style: you run to the ball automatically, you only swing. Swing harder = deeper and faster,
# swing across (left/right) to aim, swing upwards for a lob. Real tennis scoring: 15, 30, 40, deuce,
# advantage. First to 3 games wins the match. Matches won and your longest rally are saved.
# VR: the racket is in your right hand, pull a trigger to start / to serve.
# Screen: the mouse moves the racket - flick it across the ball - or press Space when the ball is close.

let s = scene3d(body())
sky3d(s, "#5fb4ff", "#e8f6ff")
shadows3d(s, true)
vr_setup(s, {hands: false, pitch: -8})
camera_fov(s, 70)

let HW = 4.115         # singles half width
let HL = 11.885        # half length (baseline)
let NET_H = 0.914
let R = 0.07           # ball radius (bigger than real: easier to see)
let G = 7.5            # gravity (a bit floaty, like the Wii)

# ---------------------------------------------------------------- the court
let grass = plane(s, 60, 70, "#3d8b4f")
look3d(grass, {texture: "noise", repeat: 12})
let court = cube(s, 2 * HW + 3, 0.02, 2 * HL + 6, "#2f6fb5")
move3d(court, 0, 0.0, 0)
fn line_(x, z, w, d) {
  let l = cube(s, w, 0.025, d, "#ffffff")
  move3d(l, x, 0.012, z)
}
line_(-HW, 0, 0.06, 2 * HL)
line_(HW, 0, 0.06, 2 * HL)
line_(0, -HL, 2 * HW, 0.06)
line_(0, HL, 2 * HW, 0.06)
line_(0, -6.4, 2 * HW, 0.05)
line_(0, 6.4, 2 * HW, 0.05)
line_(0, 0, 0.05, 12.8)
let net = cube(s, 2 * HW + 1.6, NET_H, 0.03, "#222831")
look3d(net, {opacity: 0.75, texture: "grid", repeat: 18})
move3d(net, 0, NET_H / 2, 0)
let tape = cube(s, 2 * HW + 1.6, 0.06, 0.05, "#ffffff")
move3d(tape, 0, NET_H, 0)
for side in [-1, 1] {
  let post = cylinder(s, 0.05, NET_H + 0.1, "#cfd8dc")
  move3d(post, side * (HW + 0.8), (NET_H + 0.1) / 2, 0)
  # stands with a crowd of little Kugeln
  let stand = cube(s, 3, 1.6, 30, "#455a64")
  move3d(stand, side * (HW + 6), 0.8, 0)
  for k in range(10) {
    let fan = sphere(s, 0.28, ["#ff7043", "#ffca28", "#ab47bc", "#26c6da", "#ec407a"][k % 5])
    move3d(fan, side * (HW + 5.6), 1.9, -13 + k * 2.9)
  }
}

# ---------------------------------------------------------------- the ball + its shadow
let ball = sphere(s, R, "#d4ff3a")
look3d(ball, {glow: "#4a6600"})
let shadow = cylinder(s, R * 1.2, 0.005, "#14301c")
look3d(shadow, {opacity: 0.6})

# ---------------------------------------------------------------- your racket (right hand; head along -z)
fn make_racket(parent_color) {
  let g = group3d(s)
  let grip = cylinder(s, 0.016, 0.26, "#263238")
  turn3d(grip, 90, 0, 0)
  move3d(grip, 0, 0, -0.05)
  let ring = torus(s, 0.15, 0.013, parent_color)
  turn3d(ring, 0, 90, 0)
  move3d(ring, 0, 0, -0.38)
  let strings = sphere(s, 0.14, "#f5f5f5")
  scale3d(strings, 0.02, 1, 1.25)
  look3d(strings, {opacity: 0.5, wire: true})
  move3d(strings, 0, 0, -0.38)
  attach3d(g, grip)
  attach3d(g, ring)
  attach3d(g, strings)
  return {g: g, head: strings}
}
let racket = make_racket("#ff3d6e")
vr_attach(s, racket.g, "right")

# ---------------------------------------------------------------- the CPU player (a Kugel with a racket)
let cpu_g = group3d(s)
let cpu_body = sphere(s, 0.42, "#ffb300")
look3d(cpu_body, {shiny: 0.5})
move3d(cpu_body, 0, 0.9, 0)
let band = torus(s, 0.3, 0.05, "#e53935")
turn3d(band, 90, 0, 0)
move3d(band, 0, 1.22, 0)
let eye1 = sphere(s, 0.07, "#212121")
move3d(eye1, -0.14, 1.0, 0.36)
let eye2 = sphere(s, 0.07, "#212121")
move3d(eye2, 0.14, 1.0, 0.36)
let cr = make_racket("#1e88e5")
move3d(cr.g, 0.5, 1.0, 0)
turn3d(cr.g, -60, 0, 0)
for o in [cpu_body, band, eye1, eye2, cr.g] { attach3d(cpu_g, o) }

# ---------------------------------------------------------------- scoreboard above the net (inside the world)
let board_c = canvas(s, 512, 200)
setstyle(board_c, "display", "none")
let board = panel3d(s, board_c, 4.2)
move3d(board, 0, 3.6, -0.3)

let menu = col(s)
setstyle(menu, "position", "absolute")
setstyle(menu, "left", "50%")
setstyle(menu, "bottom", 24)
setstyle(menu, "transform", "translateX(-50%)")
setstyle(menu, "background", "rgba(10, 30, 60, 0.86)")
setstyle(menu, "color", "white")
setstyle(menu, "padding", "14px 22px")
setstyle(menu, "border-radius", 14)
setstyle(menu, "align-items", "center")
setstyle(menu, "gap", "8px")
setstyle(menu, "text-align", "center")

# ---------------------------------------------------------------- state
let state = "title"     # title, serve, rally, point, over
let me = {x: 0.5, z: HL + 0.7}
let cpu = {x: 0, z: -HL - 0.7, tx: 0, tz: -HL - 0.7, speed: 5.2}
let b = {x: 0, y: 1, z: 0, vx: 0, vy: 0, vz: 0}
let last = "cpu"        # who hit last: "you" or "cpu"
let bounces = 0
let server = "you"
let pts = [0, 0]        # points in this game (you, cpu)
let games = [0, 0]
let rally = 0
let wait = 0
let msg = ""
let msg_t = 0
let wins = store_get("wins", 0)
let best_rally = store_get("best_rally", 0)
let target = {x: 0.5, z: HL + 0.7, ok: false}
let swing_cd = 0
let trig_was = false
let space_was = false
let cpu_hit_cd = 0

fn say(t) {
  msg = t
  msg_t = 1.8
}
fn call_score() {
  let names = ["0", "15", "30", "40"]
  if pts[0] >= 3 and pts[1] >= 3 {
    if pts[0] == pts[1] { return "Deuce" }
    if pts[0] > pts[1] { return "Advantage you" }
    return "Advantage CPU"
  }
  return names[min(3, pts[0])] + " - " + names[min(3, pts[1])]
}
fn draw_board() {
  draw_clear(board_c)
  draw_round_rect(board_c, 0, 0, 512, 200, 16, "rgba(12, 30, 58, 0.9)")
  draw_rect(board_c, 0, 0, 512, 5, "#d4ff3a")
  if state == "title" {
    draw_text(board_c, 256, 52, "KUGEL TENNIS", "white", 42, "center")
    draw_text(board_c, 256, 98, "Swing like a racket · first to 3 games", "#cfe8ff", 20, "center")
    draw_text(board_c, 256, 140, "Pull a trigger to start", "#d4ff3a", 26, "center")
    draw_text(board_c, 256, 180, `Matches won {wins} · longest rally {best_rally}`, "#9fb8d6", 17, "center")
    return
  }
  draw_text(board_c, 30, 50, "YOU", "#ff8aa8", 30, "left")
  draw_text(board_c, 30, 100, "CPU", "#8ac4ff", 30, "left")
  draw_text(board_c, 200, 50, `{games[0]}`, "white", 32, "center")
  draw_text(board_c, 200, 100, `{games[1]}`, "white", 32, "center")
  if server == "you" { draw_circle(board_c, 120, 40, 7, "#d4ff3a") } else { draw_circle(board_c, 120, 90, 7, "#d4ff3a") }
  draw_text(board_c, 380, 75, call_score(), "#d4ff3a", 30, "center")
  draw_text(board_c, 256, 145, `rally {rally} · best {best_rally}`, "#9fb8d6", 18, "center")
  if state == "over" {
    draw_text(board_c, 256, 183, "Pull a trigger for a new match", "white", 20, "center")
  } else if msg_t > 0 { draw_text(board_c, 256, 183, msg, "white", 24, "center") }
}

fn show_menu(title) {
  clear(menu)
  setstyle(menu, "display", "flex")
  heading(menu, title)
  let av = vr_available()
  if av == "vr" { button(menu, "🥽 Enter VR", fn() { enter_vr() }) }
  if av == "browser" { button(menu, "🥽 Play in VR (opens the Quest Browser)", fn() { enter_vr() }) }
  button(menu, "▶ Play on screen (Enter)", fn() { start() })
  label(menu, "Screen: the mouse moves the racket - flick it across the ball, or press Space when the ball is close")
}
fn enter_vr() {
  if vr_start(s) == "flat" { start() }
}
fn start() {
  pts = [0, 0]
  games = [0, 0]
  server = "you"
  rally = 0
  setstyle(menu, "display", "none")
  new_point()
}
fn new_point() {
  rally = 0
  bounces = 0
  me.x = 0.6
  me.z = HL + 0.7
  if server == "cpu" { me.x = 0.9 }
  cpu.x = 0
  cpu.tx = 0
  cpu.z = -HL - 0.7
  state = "serve"
  wait = 1.2
  b.vx = 0
  b.vy = 0
  b.vz = 0
}

# a shot from where the ball is to (tx, tz): flies t seconds, always clears the net
fn shot(tx, tz, t) {
  let tt = t
  let tries = 0
  while tries < 12 {
    let vz = (tz - b.z) / tt
    let vy = (R - b.y + 0.5 * G * tt * tt) / tt
    let tn = (0 - b.z) / vz
    let yn = b.y + vy * tn - 0.5 * G * tn * tn
    if yn > NET_H + 0.25 or tn < 0 or tn > tt {
      b.vx = (tx - b.x) / tt
      b.vy = vy
      b.vz = vz
      return
    }
    tt += 0.1
    tries += 1
  }
  b.vx = (tx - b.x) / tt
  b.vz = (tz - b.z) / tt
  b.vy = (R - b.y + 0.5 * G * tt * tt) / tt
}
# where will the ball be when it comes up waist high after its first bounce, on the side "sign"?
fn predict(sign) {
  let p = {x: b.x, y: b.y, z: b.z, vx: b.vx, vy: b.vy, vz: b.vz}
  let bn = bounces
  let dt = 1 / 30
  let i = 0
  while i < 150 {
    p.vy -= G * dt
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.z += p.vz * dt
    if p.y < R {
      p.y = R
      p.vy = -p.vy * 0.72
      p.vx *= 0.86
      p.vz *= 0.86
      bn += 1
    }
    if bn >= 1 and p.y > 0.8 and p.z * sign > 2 { return {x: p.x, z: p.z, ok: true} }
    if bn >= 2 { return {x: p.x, z: p.z, ok: true} }
    i += 1
  }
  return {x: p.x, z: p.z, ok: true}
}
fn point_to(who, why) {
  if state != "rally" and state != "serve" { return }
  if who == "you" { pts[0] += 1 } else { pts[1] += 1 }
  say(why)
  if rally > best_rally {
    best_rally = rally
    store_set("best_rally", best_rally)
  }
  state = "point"
  wait = 1.8
  let i = 0
  if who == "cpu" { i = 1 }
  if pts[i] >= 4 and pts[i] - pts[1 - i] >= 2 {
    games[i] += 1
    pts = [0, 0]
    if who == "you" { say("Game, you! " + why) } else { say("Game, CPU. " + why) }
    if server == "you" { server = "cpu" } else { server = "you" }
    if games[i] >= 3 {
      state = "over"
      if who == "you" {
        wins += 1
        store_set("wins", wins)
        show_menu("🏆 You win the match " + games[0] + " - " + games[1] + "!")
      } else { show_menu("CPU wins " + games[1] + " - " + games[0] + ". Again?") }
    }
  }
}
fn you_hit(h) {
  # aim: swing across = left/right, harder = deeper + faster, upwards = lob
  let sp = clamp(h.speed, 2, 12)
  let tx = clamp(b.x * 0.25 + h.vx * 0.45, -HW + 0.5, HW - 0.5)
  let tz = -clamp(5.5 + sp * 0.55, 5.5, HL - 0.8)
  let t = clamp(1.75 - sp * 0.07, 0.95, 1.6)
  if h.vy > 3.5 { t += 0.5 }
  shot(tx, tz, t)
  last = "you"
  bounces = 0
  rally += 1
  swing_cd = 0.4
  vr_haptic(s, "right", 0.9, 45)
  state = "rally"
  target.ok = false
}
fn cpu_hit() {
  let tx = random_float(-HW + 0.6, HW - 0.6)
  let tz = random_float(5, HL - 1)
  let t = random_float(1.15, 1.55) - games[1] * 0.03
  # the CPU is good, not perfect
  let r = random(1, 100)
  if r <= 7 { tz = HL + random_float(0.6, 1.6) }
  else if r <= 11 { tx = (HW + random_float(0.4, 1.2)) * sign(random_float(-1, 1)) }
  shot(tx, tz, t)
  last = "cpu"
  bounces = 0
  rally += 1
  cpu_hit_cd = 0.5
  target = predict(1)
}

on_keypress(fn(k) {
  if k == "enter" and (state == "title" or state == "over") { start() }
})

on_frame(fn(dt) {
  let vr = vr_mode(s) == "vr"
  let h = vr_hand(s, "right")
  let l = vr_hand(s, "left")
  let trig = h.trigger > 0.7 or l.trigger > 0.7
  let trig_press = trig and not trig_was
  trig_was = trig
  let sp_press = key_down("space") and not space_was
  space_was = key_down("space")
  if trig_press and vr and (state == "title" or state == "over") { start() }
  msg_t -= dt
  swing_cd -= dt
  cpu_hit_cd -= dt

  # ------------------------------------------------ you: run to the ball automatically (or use the left stick)
  if state == "rally" and last == "cpu" and target.ok {
    let gx = target.x - 0.5
    let gz = clamp(target.z + 0.45, 3, HL + 3)
    me.x += clamp(gx - me.x, -5 * dt, 5 * dt)
    me.z += clamp(gz - me.z, -4 * dt, 4 * dt)
  }
  me.x = clamp(me.x + l.stick_x * 4 * dt, -HW - 2, HW + 2)
  me.z = clamp(me.z + l.stick_y * 4 * dt, 1.5, HL + 4)
  vr_rig(s, me.x, 0, me.z, 0)

  if state == "point" {
    wait -= dt
    if wait <= 0 { new_point() }
  }
  # ------------------------------------------------ serving
  if state == "serve" {
    wait -= dt
    if server == "you" {
      b.x = me.x + 0.4
      b.y = 1.25 + sin(time() * 3) * 0.05
      b.z = me.z - 0.6
      if wait <= 0 and sp_press { you_hit({speed: 6, vx: (h.x - me.x - 0.3) * 4, vy: 0}) }
    } else {
      b.x = cpu.x + 0.4
      b.y = 2.3
      b.z = cpu.z
      if wait <= 0 {
        shot(random_float(-HW + 0.8, HW - 0.8), random_float(5, 9), 1.45)
        last = "cpu"
        bounces = 0
        rally = 1
        state = "rally"
        target = predict(1)
      }
    }
  }

  # ------------------------------------------------ ball flight, bounces, net, lines
  if state == "rally" or state == "point" {
    let oz = b.z
    b.vy -= G * dt
    b.x += b.vx * dt
    b.y += b.vy * dt
    b.z += b.vz * dt
    # the net
    if state == "rally" and sign(oz) != sign(b.z) and b.y < NET_H + R and abs(b.x) < HW + 0.8 {
      b.z = oz
      b.vz = -b.vz * 0.15
      b.vx *= 0.3
      if last == "you" { point_to("cpu", "Into the net") } else { point_to("you", "CPU hit the net") }
    }
    if b.y < R {
      b.y = R
      b.vy = -b.vy * 0.72
      b.vx *= 0.86
      b.vz *= 0.86
      if state == "rally" {
        let side = "you"
        if b.z < 0 { side = "cpu" }
        if side == last {
          if last == "you" { point_to("cpu", "Didn't get over") } else { point_to("you", "CPU didn't get over") }
        } else if bounces == 0 {
          bounces = 1
          let out_ = abs(b.x) > HW + 0.05 or abs(b.z) > HL + 0.05
          if out_ {
            if last == "you" { point_to("cpu", "Out!") } else { point_to("you", "CPU hit it out") }
          }
        } else {
          if last == "you" { point_to("you", "Winner!") } else { point_to("cpu", "Too late…") }
        }
      }
    }
    if state == "rally" and (abs(b.z) > HL + 8 or abs(b.x) > HW + 9) {
      if bounces == 0 {
        if last == "you" { point_to("cpu", "Out!") } else { point_to("you", "CPU hit it out") }
      } else if last == "you" { point_to("you", "Winner!") } else { point_to("cpu", "Missed it") }
    }
  }

  # ------------------------------------------------ your racket hits the ball (also your serve)
  let my_serve = state == "serve" and server == "you" and wait <= 0
  if my_serve or (state == "rally" and last == "cpu" and b.z > 0 and b.vz > 0 and swing_cd <= 0) {
    let head = world3d(racket.head)
    let d = dist3d(head, [b.x, b.y, b.z])
    let mid = [(head.x + h.x) / 2, (head.y + h.y) / 2, (head.z + h.z) / 2]
    let close_ = d < 0.36 or dist3d(mid, [b.x, b.y, b.z]) < 0.24
    if close_ and h.speed > 1.6 { you_hit(h) }
    else if not vr and sp_press and dist3d([me.x + 0.4, 1.0, me.z - 0.5], [b.x, b.y, b.z]) < 1.9 {
      # screen helper: Space = a good swing, aimed by where the racket is
      you_hit({speed: 7, vx: (h.x - me.x - 0.3) * 6, vy: 0})
    }
  }

  # ------------------------------------------------ CPU: run and hit
  if state == "rally" and last == "you" {
    let p = predict(-1)
    cpu.tx = p.x - 0.4
    cpu.tz = clamp(p.z - 0.3, -HL - 3, -4)
  } else if state != "rally" {
    cpu.tx = 0
    cpu.tz = -HL - 0.7
  }
  cpu.x += clamp(cpu.tx - cpu.x, -cpu.speed * dt, cpu.speed * dt)
  cpu.z += clamp(cpu.tz - cpu.z, -cpu.speed * 0.8 * dt, cpu.speed * 0.8 * dt)
  move3d(cpu_g, cpu.x, abs(sin(time() * 9)) * 0.06, cpu.z)
  turn3d(cpu_g, 0, 180, 0)
  if state == "rally" and last == "you" and b.z < -2 and b.y < 2.2 and cpu_hit_cd <= 0 and (bounces == 1 or b.y < 1.5) {
    if abs(b.x - (cpu.x + 0.4)) < 1.2 and abs(b.z - cpu.z) < 1.1 { cpu_hit() }
  }

  move3d(ball, b.x, b.y, b.z)
  move3d(shadow, b.x, 0.02, b.z)
  draw_board()
})

new_point()
state = "title"
draw_board()
show_menu("🎾 Kugel Tennis VR")
