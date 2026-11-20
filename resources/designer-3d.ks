# 3D game: walk with W A S D, look by dragging the mouse, collect the gold coins. Lessons ⑫–⑮ explain every line.
let s = scene3d(body())
sky3d(s, "#87ceeb", "#e0f6ff")
let ground = plane(s, 40, 40, "#3a7d44")
look3d(ground, {texture: "grid", repeat: 20})
let coins = []
for i in range(8) {
  let k = torus(s, 0.35, 0.1, "#ffd23f")
  look3d(k, {glow: "#6a4a00", shiny: 0.8, metal: 0.6})
  move3d(k, random() * 30 - 15, 1.1, random() * 30 - 15)
  push(coins, k)
}
for i in range(6) {
  let w = cube(s, 2, 2, 2, "#b5653f")
  look3d(w, {texture: "bricks"})
  move3d(w, random() * 30 - 15, 1, random() * 30 - 15)
  solid3d(w)
}
let got = 0
let hud = label(s, "Coins: 0 / 8")
setstyle(hud, "position", "absolute")
setstyle(hud, "left", 16)
setstyle(hud, "top", 12)
setstyle(hud, "color", "white")
setstyle(hud, "font-size", 20)
setstyle(hud, "text-shadow", "0 1px 3px #000")
camera3d(s, 0, 1.6, 18)
fps_controls(s, {speed: 6, height: 1.6, radius: 0.35})
on_frame(fn(dt) {
  let cam = camera_get(s)
  for k in coins {
    spin3d(k, 0, 120 * dt, 0)
    if dist3d(k, cam) < 1.2 {
      remove3d(k)
      remove(coins, indexof(coins, k))
      got += 1
      settext(hud, "Coins: " + str(got) + " / 8")
      if got == 8 { settext(hud, "You found every coin! 🎉") }
      break
    }
  }
})
