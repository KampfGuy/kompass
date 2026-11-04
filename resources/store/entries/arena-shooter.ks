# Arena Shooter — top-down survival (fixed)
# WASD / arrows move, mouse aim, left-click or space to shoot, R restart

let W = 800
let H = 500
let c = canvas(body(), W, H)

let player = {
  x: 400,
  y: 250,
  r: 14,
  speed: 220,
  hp: 100,
  maxHp: 100,
  cooldown: 0,
  angle: 0
}

let bullets = []
let enemies = []
let particles = []
let score = 0
let wave = 1
let spawnTimer = 1.2
let alive = true
let mouseX = 400
let mouseY = 250

fn spawn_enemy() {
  let side = random(0, 3)
  let x = 0
  let y = 0
  if side == 0 {
    x = -20
    y = random_float(0, H)
  } else if side == 1 {
    x = W + 20
    y = random_float(0, H)
  } else if side == 2 {
    x = random_float(0, W)
    y = -20
  } else {
    x = random_float(0, W)
    y = H + 20
  }
  let spd = 45 + wave * 7
  let hp = 22 + wave * 4
  push(enemies, {
    x: x,
    y: y,
    r: 12 + random_float(0, 5),
    speed: spd,
    hp: hp,
    maxHp: hp,
    color: mix("#ff4444", "#ff8800", random_float(0, 1))
  })
}

fn shoot() {
  if not alive { return }
  if player.cooldown > 0 { return }
  let dx = mouseX - player.x
  let dy = mouseY - player.y
  let dist = hypot(dx, dy)
  if dist < 1 { dist = 1 }
  push(bullets, {
    x: player.x,
    y: player.y,
    vx: (dx / dist) * 460,
    vy: (dy / dist) * 460,
    life: 1.15
  })
  player.cooldown = 0.16
}

fn explode(x, y, col, n) {
  for i in range(n) {
    let a = random_float(0, TAU)
    let s = random_float(50, 160)
    push(particles, {
      x: x,
      y: y,
      vx: cos(a) * s,
      vy: sin(a) * s,
      life: random_float(0.25, 0.6),
      color: col
    })
  }
}

fn reset() {
  player.x = 400
  player.y = 250
  player.hp = player.maxHp
  player.cooldown = 0
  bullets = []
  enemies = []
  particles = []
  score = 0
  wave = 1
  spawnTimer = 1.2
  alive = true
}

on_mouse(c, fn(e) {
  mouseX = e.x
  mouseY = e.y
  if e.type == "down" and e.button == "left" {
    shoot()
  }
})

on_keypress(fn(k) {
  if k == "r" { reset() }
})

on_frame(fn(dt) {
  if not alive {
    draw_clear(c, "#0a0a12")
    draw_text(c, W / 2, H / 2 - 24, "YOU DIED", "#ff4444", 40, "center")
    draw_text(c, W / 2, H / 2 + 16, "Score: " + str(score) + "   Wave " + str(wave), "white", 18, "center")
    draw_text(c, W / 2, H / 2 + 48, "Press R to restart", "#999999", 14, "center")
    return
  }

  # movement
  let vx = 0
  let vy = 0
  if key_down("w") or key_down("up") { vy -= 1 }
  if key_down("s") or key_down("down") { vy += 1 }
  if key_down("a") or key_down("left") { vx -= 1 }
  if key_down("d") or key_down("right") { vx += 1 }
  let ml = hypot(vx, vy)
  if ml > 0 {
    player.x += (vx / ml) * player.speed * dt
    player.y += (vy / ml) * player.speed * dt
  }
  if player.x < player.r { player.x = player.r }
  if player.x > W - player.r { player.x = W - player.r }
  if player.y < player.r { player.y = player.r }
  if player.y > H - player.r { player.y = H - player.r }

  # aim
  let adx = mouseX - player.x
  let ady = mouseY - player.y
  player.angle = atan2(ady, adx)

  if player.cooldown > 0 { player.cooldown -= dt }
  if key_down("space") { shoot() }

  # spawn
  spawnTimer -= dt
  if spawnTimer <= 0 {
    spawn_enemy()
    spawnTimer = 1.4 - wave * 0.1
    if spawnTimer < 0.4 { spawnTimer = 0.4 }
  }
  if len(enemies) == 0 and score >= wave * 10 {
    wave += 1
  }

  # bullets update
  let newBullets = []
  for b in bullets {
    b.x += b.vx * dt
    b.y += b.vy * dt
    b.life -= dt
    if b.life > 0 and b.x > -20 and b.x < W + 20 and b.y > -20 and b.y < H + 20 {
      push(newBullets, b)
    }
  }
  bullets = newBullets

  # enemies update + collisions
  let newEnemies = []
  for e in enemies {
    let dx = player.x - e.x
    let dy = player.y - e.y
    let d = hypot(dx, dy)
    if d < 1 { d = 1 }
    e.x += (dx / d) * e.speed * dt
    e.y += (dy / d) * e.speed * dt

    # bullet hits
    for b in bullets {
      let bd = hypot(b.x - e.x, b.y - e.y)
      if bd < e.r + 4 {
        e.hp -= 16
        b.life = 0
      }
    }

    if e.hp <= 0 {
      score += 10 + wave * 2
      explode(e.x, e.y, e.color, 7)
      continue
    }

    # player damage
    let pd = hypot(player.x - e.x, player.y - e.y)
    if pd < player.r + e.r - 1 {
      player.hp -= 30 * dt
      if player.hp <= 0 {
        player.hp = 0
        alive = false
        explode(player.x, player.y, "#ff4444", 18)
      }
    }
    push(newEnemies, e)
  }
  enemies = newEnemies

  # particles
  let newParts = []
  for p in particles {
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.life -= dt
    p.vx *= 0.95
    p.vy *= 0.95
    if p.life > 0 { push(newParts, p) }
  }
  particles = newParts

  # draw
  draw_clear(c, "#0d0d16")

  # faint grid
  draw_alpha(c, 0.07)
  let gx = 0
  while gx < W {
    draw_line(c, gx, 0, gx, H, "#445566", 1)
    gx += 40
  }
  let gy = 0
  while gy < H {
    draw_line(c, 0, gy, W, gy, "#445566", 1)
    gy += 40
  }
  draw_alpha(c, 1)

  # particles
  for p in particles {
    let a = p.life * 2
    if a > 1 { a = 1 }
    draw_alpha(c, a)
    draw_circle(c, p.x, p.y, 2.4, p.color)
  }
  draw_alpha(c, 1)

  # bullets
  for b in bullets {
    draw_circle(c, b.x, b.y, 3.4, "#ffe066")
    draw_glow(c, b.x, b.y, 9, "#ffe066", "rgba(255,224,102,0)")
  }

  # enemies
  for e in enemies {
    draw_circle(c, e.x, e.y, e.r, e.color)
    draw_circle(c, e.x, e.y, e.r - 3, shade(e.color, -0.35))
    let hw = e.r * 1.5
    draw_rect(c, e.x - hw / 2, e.y - e.r - 7, hw, 3, "#333333")
    let frac = e.hp / e.maxHp
    if frac < 0 { frac = 0 }
    if frac > 1 { frac = 1 }
    draw_rect(c, e.x - hw / 2, e.y - e.r - 7, hw * frac, 3, "#ff5555")
  }

  # player
  draw_save(c)
  draw_translate(c, player.x, player.y)
  draw_rotate(c, player.angle)
  draw_round_rect(c, -12, -10, 24, 20, 4, "#4cc9f0")
  draw_rect(c, 6, -3, 14, 6, "#90e0ef")
  draw_restore(c)
  draw_circle(c, player.x, player.y, 5, "#caf0f8")

  # aim line
  draw_alpha(c, 0.3)
  draw_line(c, player.x, player.y, mouseX, mouseY, "#90e0ef", 1)
  draw_alpha(c, 1)

  # HUD
  draw_rect(c, 14, 14, 150, 9, "#222222")
  let hpFrac = player.hp / player.maxHp
  if hpFrac < 0 { hpFrac = 0 }
  if hpFrac > 1 { hpFrac = 1 }
  draw_rect(c, 14, 14, 150 * hpFrac, 9, mix("#ff4444", "#44ff88", hpFrac))
  draw_text(c, 14, 38, "HP " + str(round(player.hp)), "white", 13)
  draw_text(c, 14, 56, "Score " + str(score), "#ffe066", 14)
  draw_text(c, 14, 74, "Wave " + str(wave), "#90e0ef", 14)
  draw_text(c, W - 12, 22, "WASD move · Click/Space shoot · R restart", "#888888", 12, "right")
})
