# ==============================================================
#  My Google page — a search home page written in KampfScript.
#  Change anything: the preview updates as you type.
#  Page API: search(text), lucky(text), open_url(url), engine()
# ==============================================================
let BG = "#ffffff"
let TEXT = "#202124"
let LOGO = "Google"
let COLORS = ["#4285f4", "#ea4335", "#fbbc05", "#4285f4", "#34a853", "#ea4335"]
let SHORTCUTS = [
  ["YouTube", "▶", "https://www.youtube.com/"],
  ["Wikipedia", "W", "https://en.wikipedia.org/"],
  ["GitHub", "⌥", "https://github.com/"],
  ["Maps", "⌖", "https://maps.google.com/"],
  ["News", "✎", "https://news.google.com/"]
]

let page = col(body(), "gp-page")
setstyle(page, "background", BG)
setstyle(page, "color", TEXT)

# top-right links
let top = row(page, "gp-top")
link(top, "Gmail", fn() { open_url("https://mail.google.com/") })
link(top, "Images", fn() { open_url("https://images.google.com/") })

# the logo: one colour per letter
spacer(page, 60)
let logo = colorletters(page, LOGO, COLORS, "gp-logo")
setfont(logo, "Arial", 92, "bold")

# the search box really searches (Kugel / Google / DuckDuckGo from ⚙ Settings)
let bar = row(page, "gp-searchbar")
label(bar, "⌕", "gp-icon")
let q = textbox(bar, "Search " + engine() + " or type a URL", fn(t) { search(t) }, "gp-search")
focus(q)

let btns = row(page, "gp-buttons")
button(btns, "Google Search", fn() { search(gettext(q)) }, "gp-btn")
button(btns, "I'm Feeling Lucky", fn() { lucky(gettext(q)) }, "gp-btn")

# shortcut tiles
let tiles = row(page, "gp-tiles")
for s in SHORTCUTS {
  let url = s[2]
  let t = col(tiles, "gp-tile")
  label(t, s[1], "gp-tile-icon")
  label(t, s[0], "gp-tile-name")
  on_click(t, fn() { open_url(url) })
}

label(page, "Made with KampfScript in Kompass", "gp-foot")
