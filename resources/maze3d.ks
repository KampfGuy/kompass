# ============================================================================
#  Coin Maze 3D — a first-person 3D game written in KampfScript (Kompass 1.5.2)
#  Open kompass://maze3d.  Walk: W A S D or the arrow keys · Look: drag the
#  mouse (or click to lock it, Esc frees it) · Run: Shift · Gamepad: left stick
#  walks, right stick looks.  Collect every coin as fast as you can!
# ============================================================================
let MAZE = [
  "###############",
  "#S..#....c#..c#",
  "#.#.#.###.#.#.#",
  "#.#...#...#.#.#",
  "#.#####.###.#.#",
  "#c....#.#...#.#",
  "###.#.#.#.###.#",
  "#...#..c#.#...#",
  "#.#######.#.###",
  "#.#....c#.#..c#",
  "#.#.###.#.###.#",
  "#..c#...#...#.#",
  "#####.#####.#.#",
  "#c...........c#",
  "###############"
]
let CELL = 2
let W = len(MAZE[0])
let H = len(MAZE)

# ---------------------------------------------------------------- the world
let s = scene3d(body())
sky3d(s, "#0b1d3a", "#f6a96b")
fog3d(s, "#2a2440", 5, 30)
shadows3d(s, true)
camera_fov(s, 75)

let ground = plane(s, W * CELL, H * CELL, "#5d7f52")
move3d(ground, (W - 1) * CELL / 2, 0, (H - 1) * CELL / 2)
look3d(ground, {texture: "grid", repeat: W})

let start = vec3(CELL, 1.6, CELL)
let coin_spots = []
for row, line in MAZE {
  for col in range(len(line)) {
    let ch = line[col]
    if ch == "#" {
      let wall = cube(s, CELL, 2.4, CELL, "#b5653f")
      move3d(wall, col * CELL, 1.2, row * CELL)
      look3d(wall, {texture: "bricks"})
      solid3d(wall)
    } else if ch == "c" {
      push(coin_spots, [col, row])
    } else if ch == "S" {
      start = vec3(col * CELL, 1.6, row * CELL)
    }
  }
}
# a warm lamp that follows the player
let lamp = light3d(s, "point", "#ffd9a0", 2.5)

# ---------------------------------------------------------------- HUD (UI on top of the 3D scene)
let hud = row(s)
setstyle(hud, "padding", "10px 14px")
setstyle(hud, "gap", "22px")
setstyle(hud, "color", "white")
setstyle(hud, "font-size", 18)
setstyle(hud, "font-weight", "bold")
setstyle(hud, "text-shadow", "0 1px 3px #000")
let score_l = label(hud, "")
let time_l = label(hud, "")
let help = label(s, "W A S D / arrows walk · drag or click to look · Shift runs")
setstyle(help, "position", "absolute")
setstyle(help, "left", 14)
setstyle(help, "bottom", 12)
setstyle(help, "color", "#ffffffcc")
setstyle(help, "text-shadow", "0 1px 3px #000")

let mini = canvas(s, 150, 150)
setstyle(mini, "position", "absolute")
setstyle(mini, "right", 12)
setstyle(mini, "top", 12)
setstyle(mini, "border-radius", 8)

let panel = col(s)
setstyle(panel, "position", "absolute")
setstyle(panel, "left", "50%")
setstyle(panel, "top", "45%")
setstyle(panel, "transform", "translate(-50%, -50%)")
setstyle(panel, "background", "rgba(10, 10, 30, 0.78)")
setstyle(panel, "color", "white")
setstyle(panel, "padding", "22px 30px")
setstyle(panel, "border-radius", 14)
setstyle(panel, "align-items", "center")
setstyle(panel, "gap", "10px")
setstyle(panel, "display", "none")

# ---------------------------------------------------------------- game state
let coins = []
let got = 0
let t = 0
let done = false
let clock = 0

fn place_coins() {
  for c in coins { remove3d(c) }
  coins = []
  for p in coin_spots {
    let c = torus(s, 0.32, 0.1, "#ffd23f")
    look3d(c, {glow: "#6a4a00", shiny: 0.8, metal: 0.6})
    move3d(c, p[0] * CELL, 1.1, p[1] * CELL)
    tag3d(c, "coin")
    push(coins, c)
  }
}

fn start_game() {
  place_coins()
  got = 0
  t = 0
  done = false
  camera3d(s, start.x, start.y, start.z)
  camera_angles(s, -90, 0)
  fps_controls(s, {speed: 4.2, height: 1.6, radius: 0.35})
  setstyle(panel, "display", "none")
}

fn win() {
  done = true
  fps_controls(s, false)
  let best = store_get("maze3d_best", 0)
  if best == 0 or t < best {
    best = t
    store_set("maze3d_best", t)
  }
  clear(panel)
  heading(panel, "You found every coin!")
  label(panel, `Time: {fmt(t, 1)} s   ·   Best: {fmt(best, 1)} s`)
  button(panel, "Play again", fn() { start_game() })
  setstyle(panel, "display", "flex")
}

fn draw_map(cam) {
  let k = 150 / W
  draw_clear(mini, "rgba(0, 0, 0, 0.5)")
  for row, line in MAZE {
    for col in range(len(line)) {
      if line[col] == "#" { draw_rect(mini, col * k, row * k, k, k, "#c98a63") }
    }
  }
  for c in coins {
    let p = pos3d(c)
    draw_circle(mini, (p.x / CELL + 0.5) * k, (p.z / CELL + 0.5) * k, 3, "#ffd23f")
  }
  let px = (cam.x / CELL + 0.5) * k
  let pz = (cam.z / CELL + 0.5) * k
  draw_line(mini, px, pz, px + cam.dir.x * 12, pz + cam.dir.z * 12, "white", 2)
  draw_circle(mini, px, pz, 4, "#4fc3ff")
}

on_frame(fn(dt) {
  clock += dt
  let cam = camera_get(s)
  move3d(lamp, cam.x, cam.y + 0.5, cam.z)
  let keep = []
  for c in coins {
    spin3d(c, 0, 140 * dt, 0)
    let p = pos3d(c)
    move3d(c, p.x, 1.1 + 0.12 * sin(clock * 3 + p.x), p.z)
    if not done and dist3d(c, cam) < 0.95 {
      remove3d(c)
      got += 1
    } else {
      push(keep, c)
    }
  }
  coins = keep
  if not done {
    t += dt
    if len(coins) == 0 { win() }
  }
  settext(score_l, `🪙 {got} / {len(coin_spots)}`)
  settext(time_l, `⏱ {fmt(t, 1)} s`)
  draw_map(cam)
})

start_game()
