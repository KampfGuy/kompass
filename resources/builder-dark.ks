# Dark mode search page with a gradient and your own name as the logo.
let NAME = "Kampfle"
let COLORS = ["#8ab4f8", "#f28b82", "#fdd663", "#8ab4f8", "#81c995", "#f28b82", "#c58af9"]

let page = col(body(), "gp-page")
gradient(page, "#202124", "#0b0c10", 180)
setstyle(page, "color", "#e8eaed")

spacer(page, 90)
let logo = colorletters(page, NAME, COLORS, "gp-logo")
setfont(logo, "Georgia", 84, "bold")
label(page, "Good to see you!", "gp-sub")

let bar = row(page, "gp-searchbar")
setstyle(bar, "background", "#303134")
setstyle(bar, "border", "1px solid #5f6368")
label(bar, "⌕", "gp-icon")
let q = textbox(bar, "Search the web", fn(t) { search(t) }, "gp-search")
focus(q)

let btns = row(page, "gp-buttons")
for b in [["Search", false], ["I'm Feeling Lucky", true]] {
  let lucky_btn = b[1]
  let el = button(btns, b[0], fn() { if lucky_btn { lucky(gettext(q)) } else { search(gettext(q)) } }, "gp-btn")
  setstyle(el, "background", "#303134")
  setstyle(el, "color", "#e8eaed")
}

let tiles = row(page, "gp-tiles")
for s in [["YouTube", "▶", "https://www.youtube.com/"], ["Reddit", "◉", "https://www.reddit.com/"], ["GitHub", "⌥", "https://github.com/"]] {
  let url = s[2]
  let t = col(tiles, "gp-tile")
  setstyle(t, "background", "#303134")
  label(t, s[1], "gp-tile-icon")
  label(t, s[0], "gp-tile-name")
  on_click(t, fn() { open_url(url) })
}
label(page, "engine: " + engine(), "gp-foot")
