# STAR DODGER - a KampfScript arcade game (about 4 KB)
# Arrows/WASD move, SPACE shoots. Survive, smash rocks, beat your best.
# Run as a Kompass page (kompass://page/star_dodger) or in the editor.

let W = 480
let H = 640
let c = canvas(body(), W, H)
let best = store_get("star_dodger_best", 0)
let state = "title"
let t = 0
let score = 0
let lives = 3
let spawn = 0
let ship = {x: 240, y: 560, cd: 0, inv: 0}
let rocks = []
let shots = []
let sparks = []
let stars = []

for i in range(70) {
  push(stars, {x: random(0, W), y: random(0, H), s: random(20, 110)})
}

fn reset() {
  score = 0
  lives = 3
  spawn = 0
  ship.x = 240
  ship.y = 560
  ship.cd = 0
  ship.inv = 1.5
  rocks = []
  shots = []
  sparks = []
}

fn boom(x, y, n, col) {
  for i in range(n) {
    let a = random_float(0, TAU)
    let sp = random_float(40, 220)
    push(sparks, {x: x, y: y, vx: cos(a) * sp, vy: sin(a) * sp, life: random_float(0.3, 0.8), col: col})
  }
}

fn level() {
  return 1 + floor(score / 300)
}

fn key_pressed(k) {
  if k == "space" and state != "play" {
    reset()
    state = "play"
  }
}
on_keypress(key_pressed)

fn update(dt) {
  # parallax stars always scroll
  for s in stars {
    s.y += s.s * dt
    if s.y > H {
      s.y = 0
      s.x = random(0, W)
    }
  }
  if state != "play" { return }

  # movement
  let dx = 0
  let dy = 0
  if key_down("left") or key_down("a") { dx -= 1 }
  if key_down("right") or key_down("d") { dx += 1 }
  if key_down("up") or key_down("w") { dy -= 1 }
  if key_down("down") or key_down("s") { dy += 1 }
  ship.x = clamp(ship.x + dx * 280 * dt, 16, W - 16)
  ship.y = clamp(ship.y + dy * 240 * dt, 40, H - 24)
  ship.cd -= dt
  if ship.inv > 0 { ship.inv -= dt }

  # shooting
  if key_down("space") and ship.cd <= 0 {
    push(shots, {x: ship.x, y: ship.y - 18, alive: true})
    ship.cd = 0.18
  }
  for b in shots {
    b.y -= 520 * dt
    if b.y < -10 { b.alive = false }
  }

  # spawn rocks, faster each level
  spawn -= dt
  if spawn <= 0 {
    let r = random(14, 34)
    push(rocks, {x: random(r, W - r), y: -r, r: r, vy: random(70, 130) + level() * 18, vx: random_float(-40, 40), hp: floor(r / 14), alive: true, rot: 0})
    spawn = max(0.25, 0.9 - level() * 0.07)
  }

  for r in rocks {
    r.y += r.vy * dt
    r.x += r.vx * dt
    r.rot += dt
    if r.x < r.r or r.x > W - r.r { r.vx = -r.vx }
    if r.y > H + r.r { r.alive = false }

    # bullets vs rock
    for b in shots {
      if b.alive and r.alive and hypot(b.x - r.x, b.y - r.y) < r.r + 4 {
        b.alive = false
        r.hp -= 1
        boom(b.x, b.y, 4, "#ffd27f")
        if r.hp <= 0 {
          r.alive = false
          score += floor(r.r)
          boom(r.x, r.y, 14, "#c9b79c")
        }
      }
    }

    # rock vs ship
    if r.alive and ship.inv <= 0 and hypot(ship.x - r.x, ship.y - r.y) < r.r + 10 {
      r.alive = false
      lives -= 1
      ship.inv = 2
      boom(ship.x, ship.y, 30, "#ff6a4d")
      if lives <= 0 {
        state = "over"
        if score > best {
          best = score
          store_set("star_dodger_best", best)
        }
      }
    }
  }
  rocks = filter(rocks, fn(r) { return r.alive })
  shots = filter(shots, fn(b) { return b.alive })

  for p in sparks {
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.life -= dt
  }
  sparks = filter(sparks, fn(p) { return p.life > 0 })
}

fn draw() {
  draw_gradient(c, 0, 0, W, H, "#05061a", "#141238")
  for s in stars {
    let g = floor(100 + s.s)
    draw_rect(c, s.x, s.y, 2, 2 + s.s / 50, rgb(g, g, 255))
  }

  for r in rocks {
    draw_save(c)
    draw_translate(c, r.x, r.y)
    draw_rotate(c, r.rot)
    draw_circle(c, 0, 0, r.r, "#7a6f62")
    draw_circle(c, -r.r * 0.3, -r.r * 0.2, r.r * 0.28, "#5d544a")
    draw_circle(c, r.r * 0.3, r.r * 0.3, r.r * 0.18, "#5d544a")
    draw_restore(c)
  }

  for b in shots {
    draw_glow(c, b.x, b.y, 10, "#ffe9a8", "rgba(255,200,80,0)")
    draw_rect(c, b.x - 1.5, b.y - 8, 3, 14, "#fff6d6")
  }

  for p in sparks {
    draw_alpha(c, clamp(p.life * 2, 0, 1))
    draw_rect(c, p.x, p.y, 3, 3, p.col)
  }
  draw_alpha(c, 1)

  if state == "play" or state == "over" {
    let show = ship.inv <= 0 or floor(t * 12) % 2 == 0
    if state == "over" { show = false }
    if show {
      draw_glow(c, ship.x, ship.y + 16, 14, "#7fd4ff", "rgba(127,212,255,0)")
      draw_poly(c, [[ship.x, ship.y - 18], [ship.x + 13, ship.y + 12], [ship.x, ship.y + 6], [ship.x - 13, ship.y + 12]], "#d8f1ff")
      draw_poly(c, [[ship.x, ship.y - 8], [ship.x + 4, ship.y + 4], [ship.x - 4, ship.y + 4]], "#3a86c8")
    }
  }

  draw_text(c, 12, 16, `Score {score}`, "white", 16, "left")
  draw_text(c, W / 2, 16, `Level {level()}`, "#9ad", 14, "center")
  draw_text(c, W - 12, 16, `Best {best}`, "#ffd27f", 16, "right")
  for i in range(lives) {
    draw_poly(c, [[20 + i * 22, H - 28], [27 + i * 22, H - 12], [13 + i * 22, H - 12]], "#7fd4ff")
  }

  if state == "title" {
    draw_text(c, W / 2, 230, "STAR DODGER", "#ffd27f", 44, "center")
    draw_text(c, W / 2, 290, "Arrows / WASD to fly", "white", 18, "center")
    draw_text(c, W / 2, 316, "SPACE to shoot", "white", 18, "center")
    draw_text(c, W / 2, 380, "Press SPACE to start", "#7fd4ff", 22, "center")
  }
  if state == "over" {
    draw_text(c, W / 2, 250, "GAME OVER", "#ff6a4d", 44, "center")
    draw_text(c, W / 2, 305, `Score {score}   Best {best}`, "white", 20, "center")
    draw_text(c, W / 2, 360, "Press SPACE to retry", "#7fd4ff", 22, "center")
  }
}

on_frame(fn(dt) {
  let d = min(dt, 0.05)
  t += d
  update(d)
  draw()
})