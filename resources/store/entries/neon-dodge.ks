# NEON DODGE
# A tiny arcade survival game for KampfScript / Kompass 1.5.1
# Controls: WASD or arrow keys. Survive as long as possible.
# Press R after a crash to play again.

let root = col(body())
let title = heading(root, "NEON DODGE")
label(root, "Move with WASD / arrow keys. Dodge the red drones. Press R to restart.")
let status = label(root, "Score: 0   Best: 0")
let c = canvas(root, 800, 520)
let W = 800
let H = 520
let best = store_get("neon_dodge_best", 0)

let game = {
  x: 400,
  y: 430,
  r: 12,
  enemies: [],
  stars: [],
  score: 0,
  spawn: 0,
  alive: true,
  flash: 0
}

for i in range(90) {
  push(game.stars, {
    x: random(0, W),
    y: random(0, H),
    s: random(1, 3),
    a: random(0.25, 0.9)
  })
}

fn reset_game() {
  game.x = 400
  game.y = 430
  game.enemies = []
  game.score = 0
  game.spawn = 0
  game.alive = true
  game.flash = 0
}

on_keypress(fn(key) {
  if key == "r" and not game.alive {
    reset_game()
  }
})

on_frame(fn(dt) {
  dt = min(dt, 0.04)

  if game.alive {
    let dx = 0
    let dy = 0
    if key_down("left") or key_down("a") { dx -= 1 }
    if key_down("right") or key_down("d") { dx += 1 }
    if key_down("up") or key_down("w") { dy -= 1 }
    if key_down("down") or key_down("s") { dy += 1 }

    if dx != 0 and dy != 0 {
      dx *= 0.7071
      dy *= 0.7071
    }

    game.x = clamp(game.x + dx * 300 * dt, 14, W - 14)
    game.y = clamp(game.y + dy * 300 * dt, 14, H - 14)
    game.score += dt
    game.spawn += dt

    if game.spawn > max(0.24, 0.88 - game.score * 0.008) {
      game.spawn = 0
      let ex = random(20, W - 20)
      let speed = random(125, 205) + min(game.score * 1.5, 100)
      push(game.enemies, {
        x: ex,
        y: -18,
        r: random(9, 17),
        vy: speed,
        vx: random(-35, 35)
      })
    }

    for i in range(len(game.enemies) - 1, -1, -1) {
      let e = game.enemies[i]
      e.x += e.vx * dt
      e.y += e.vy * dt

      if e.x < e.r or e.x > W - e.r {
        e.vx = -e.vx
      }

      if e.y > H + 25 {
        remove(game.enemies, i)
      } else if vdist(vec(game.x, game.y), vec(e.x, e.y)) < game.r + e.r - 2 {
        game.alive = false
        game.flash = 0.25
        let final_score = floor(game.score * 10)

        if final_score > best {
          best = final_score
          store_set("neon_dodge_best", best)
        }
      }
    }
  }

  draw_clear(c, "#080d1b")
  draw_gradient(c, 0, 0, W, H, "#101b38", "#070914")

  for star in game.stars {
    draw_alpha(c, star.a)
    draw_circle(c, star.x, star.y, star.s, "#b8d9ff")
  }

  draw_alpha(c, 1)

  for x in range(0, W + 1, 50) {
    draw_line(c, x, 0, x, H, "#172342", 1)
  }

  for y in range(0, H + 1, 50) {
    draw_line(c, 0, y, W, y, "#172342", 1)
  }

  draw_rect(c, 5, 5, W - 10, H - 10, "#263c67", 2)

  for e in game.enemies {
    draw_glow(c, e.x, e.y, e.r * 2, "#ff435c", "#38152d")
    draw_circle(c, e.x, e.y, e.r, "#ff435c")
    draw_circle(c, e.x - e.r * 0.25, e.y - e.r * 0.25, max(2, e.r * 0.22), "#ffd1d8")
  }

  if game.alive {
    draw_glow(c, game.x, game.y, 28, "#2be7ff", "#10234a")
    draw_poly(c, [
      [game.x, game.y - 17],
      [game.x + 13, game.y + 12],
      [game.x, game.y + 7],
      [game.x - 13, game.y + 12]
    ], "#48eaff")
    draw_circle(c, game.x, game.y, 4, "#ffffff")
  }

  draw_text(c, 18, 25, "NEON DODGE", "#d7f8ff", 17, "left", "Arial")
  draw_text(c, W - 18, 25, "SCORE " + str(floor(game.score * 10)), "#d7f8ff", 15, "right", "Arial")

  if not game.alive {
    draw_rect(c, 0, 0, W, H, "rgba(3,5,15,0.72)")
    draw_text(c, W / 2, H / 2 - 48, "SHIP DESTROYED", "#ff647c", 34, "center", "Arial")
    draw_text(c, W / 2, H / 2, "FINAL SCORE: " + str(floor(game.score * 10)), "#ffffff", 20, "center", "Arial")
    draw_text(c, W / 2, H / 2 + 42, "PRESS R TO TRY AGAIN", "#61eaff", 16, "center", "Arial")
  }

  settext(status, "Score: " + str(floor(game.score * 10)) + "   Best: " + str(best))
})