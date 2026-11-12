
# ==================================================================
#  Kompass VR additions (Meta Quest / Horizon OS build only).
#  vr/build-web.js appends this block to resources/browser.ks when it
#  builds the APK, so the Windows browser.ks stays exactly as it is.
#  Everything above still works; this only adapts it for VR:
#   - a big ☰ quick-menu button (VR controllers have no right-click;
#     holding the trigger / a pinch for 0.6 s opens it too)
#   - more quick-menu entries, compact toolbar labels
#   - the calm "midnight" dark theme on first start
# ==================================================================
VERSION = VERSION + " VR"
let VR = true

# quick menu at the top-right, next to the button (popup() keeps it on screen)
fn vr_quick_menu() { quick_menu(100000, 0, false, "") }
let vr_menu_btn = button(tools, "☰", fn() { vr_quick_menu() }, "tool vr-menu")
settip(vr_menu_btn, "Quick menu (or hold the trigger / pinch anywhere)")

push(QUICK, ["⌂", "Home", fn() { go(settings.home) }])
push(QUICK, ["⚡", "Editor", fn() { open_editor() }])
push(QUICK, ["🏪", "Store", fn() { open_page("kompass://store") }])
push(QUICK, ["▶", "YouTube", fn() { go("https://www.youtube.com/") }])

# shorter toolbar labels: the Quest panel is narrower than a desktop window
settext(gp_btn, "G")
settip(gp_btn, "Make your own Google page with KampfScript (kompass://builder)")

# first start in VR: the comfortable dark theme
if settings.vr_setup == nil {
  settings.vr_setup = 1
  if settings.theme == "brass" { settings.theme = "midnight" }
  save_settings()
  apply_look()
  tab_reload(current)
}

# ⑯ the VR lesson (only in Kompass VR: it uses the vr_* built-ins)
push(LESSONS, {icon: "⑯", title: "VR games: hands, swings & immersive mode", ui: true,
   text: ["vr_setup(s) turns a 3D scene into a VR world: a player rig with a head and two hands. vr_hand(s, \"right\") tells you where a controller is (x, y, z), where it points (dir), how fast it moves (speed, vx, vy, vz — perfect for swings, punches and slices) and its buttons (trigger, grip, a, b, stick_x, stick_y). vr_attach(s, obj, \"right\") glues a sword, racket or hand model to a controller; -z points forward out of your fist.",
          "vr_start(s) enters immersive VR where WebXR exists (the Quest Browser); in the Kompass VR app it opens the game in the Quest Browser, and on a normal screen it returns \"flat\": then the mouse is your right hand (hold Shift for the left), left click = trigger, right click = grip. In the headset you can't see HTML labels, so draw scores on a canvas and show it in the world with panel3d(s, canvas, width). vr_rig(s, x, y, z, yaw) moves the player (that is how locomotion works), vr_haptic(s, hand, strength, ms) rumbles. Try it: flick the mouse through the orange ball!"],
   code: "# VR sword practice: hit the orange ball with your blade\nlet s = scene3d(body(), nil, 320)\nsky3d(s, \"#0b1d3a\", \"#3a6ea5\")\nlet ground = plane(s, 20, 20, \"#22324a\")\nlook3d(ground, {texture: \"grid\", repeat: 20})\nvr_setup(s)\nlet blade = cylinder(s, 0.02, 1, \"#55ddff\")\nlook3d(blade, {glow: \"#55ddff\"})\nturn3d(blade, 90, 0, 0)\nvr_attach(s, blade, \"right\")\nmove3d(blade, 0, 0, -0.55)\nlet target = sphere(s, 0.18, \"#ffaa00\")\nmove3d(target, 0, 1.4, -1.3)\nlet hits = 0\nlet board = canvas(s, 256, 64)\nsetstyle(board, \"display\", \"none\")\nlet panel = panel3d(s, board, 0.8)\nmove3d(panel, 0, 2.2, -2)\nlet info = label(s, \"Mouse = right hand · flick it through the ball\")\nsetstyle(info, \"color\", \"white\")\nsetstyle(info, \"padding\", \"6px 10px\")\nif vr_available() != \"none\" { button(s, \"🥽 Enter VR\", fn() { vr_start(s) }) }\non_frame(fn(dt) {\n  let h = vr_hand(s, \"right\")\n  let tip = [h.x + h.dir.x * 0.8, h.y + h.dir.y * 0.8, h.z + h.dir.z * 0.8]\n  if h.speed > 1.5 and (dist3d(tip, target) < 0.35 or dist3d(blade, target) < 0.35) {\n    hits += 1\n    vr_haptic(s, \"right\", 0.8, 40)\n    move3d(target, random(-6, 6) / 10, random(11, 17) / 10, -1.3)\n  }\n  draw_clear(board)\n  draw_rect(board, 0, 0, 256, 64, \"#102a4c\")\n  draw_text(board, 128, 32, `Hits: {hits}`, \"white\", 30, \"center\")\n})",
   task: "Make a scene with vr_setup and print vr_mode(s), the right hand's name and the head height (vr_head(s).y) on one line", starter: "let s = scene3d(body(), nil, 160)\nvr_setup(s)\n", expect: "flat right 1.6"})

status_text("Kompass VR · point and pull the trigger (or pinch) to click · hold it for the quick menu ☰")
print("Kompass VR additions loaded")
