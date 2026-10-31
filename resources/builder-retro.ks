# Retro 90s portal: neon colours, a clock and a random tip.
let page = col(body(), "gp-page")
gradient(page, "#1a0033", "#330066", 135)
setstyle(page, "color", "#00ffcc")

spacer(page, 50)
let logo = colorletters(page, "K-PORTAL", ["#ff00ff", "#00ffff", "#ffff00", "#00ff66"], "gp-logo")
setfont(logo, "Courier New", 76, "bold")
setstyle(logo, "text-shadow", "0 0 12px #ff00ff")
let clock = label(page, "", "gp-sub")
fn tick() { settext(clock, "★ " + str(floor(time() / 1000) % 86400) + " seconds into the UTC day ★") }
tick()

let bar = row(page, "gp-searchbar")
setstyle(bar, "background", "#000000")
setstyle(bar, "border", "2px solid #00ffcc")
setstyle(bar, "border-radius", "0px")
let q = textbox(bar, "SEARCH THE INFORMATION SUPERHIGHWAY", fn(t) { search(t) }, "gp-search")
setstyle(q, "color", "#00ffcc")

let btns = row(page, "gp-buttons")
let go_btn = button(btns, ">> SEARCH <<", fn() { search(gettext(q)) }, "gp-btn")
let luck = button(btns, "FEELING LUCKY?", fn() { lucky(gettext(q)) }, "gp-btn")
for b in [go_btn, luck] { setstyle(b, "background", "#000000"); setstyle(b, "color", "#ffff00"); setstyle(b, "border-radius", "0px") }

let TIPS = ["Tip: Ctrl+T opens a new tab", "Tip: F12 opens KampfScript DevTools", "Tip: this page is a .ks program"]
label(page, TIPS[random(0, len(TIPS) - 1)], "gp-foot")
