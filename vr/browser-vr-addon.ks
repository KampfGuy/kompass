
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

status_text("Kompass VR · point and pull the trigger (or pinch) to click · hold it for the quick menu ☰")
print("Kompass VR additions loaded")
