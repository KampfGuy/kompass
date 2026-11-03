# ==================================================================
#  Kompass — a desktop web browser written in KampfScript.
#
#  The Electron shell only renders pages and offers native built-ins
#  (tab_new, tab_navigate, tab_back, load_data, kugel_search, ...).
#  EVERYTHING you see — tabs, toolbar, the ⚙ settings page, the start
#  page, the Learn KampfScript course, shortcuts — is this program.
#  Edit it! (Ctrl+Shift+K -> "★ browser.ks" -> "Save & restart browser")
#  Look inside it while it runs: F12 / Ctrl+Shift+I = KampfScript DevTools.
# ==================================================================

let VERSION = "1.5.0"
let HOME = "kompass://home"

# ---------------------------------------------------------- saved data
let DEFAULTS = {engine: "kugel", adblock: true, home: HOME, theme: "brass", accent: "",
  bookmarks_bar: true, devtools: true, video1_url: "", video2_url: "", home_ks: ""}
let settings = load_data("settings", {})
for k in keys(DEFAULTS) { if settings[k] == nil { settings[k] = DEFAULTS[k] } }
if settings.home == "kampf://home" { settings.home = HOME }
adblock(settings.adblock != false)

let THEMES = [
  {id: "brass", name: "Brass", desc: "Warm gold on dark leather — the classic navigator", colors: ["#17120c", "#2c2216", "#d4a440", "#e4572e"]},
  {id: "midnight", name: "Midnight", desc: "Deep navy, cyan needle, violet dusk", colors: ["#0b1020", "#18213b", "#4fc3f7", "#7c4dff"]},
  {id: "neon", name: "Neon", desc: "Synthwave magenta and electric cyan", colors: ["#08060d", "#1a1228", "#ff2bd6", "#00f0ff"]},
  {id: "paper", name: "Paper", desc: "Light parchment chart with copper ink", colors: ["#fbf7ef", "#e6dccb", "#b5651d", "#2e6f6a"]}
]
let ACCENTS = ["#d4a440", "#e4572e", "#4fc3f7", "#7c4dff", "#ff2bd6", "#00f0ff", "#43c59e", "#b5651d"]

fn apply_look() {
  set_theme(settings.theme)
  set_accent(settings.accent)
}
apply_look()

let bookmarks = load_data("bookmarks", [
  {title: "Kompass", url: "kompass://home"},
  {title: "Learn KampfScript", url: "kompass://learn"},
  {title: "YouTube", url: "https://www.youtube.com/"},
  {title: "Wikipedia", url: "https://en.wikipedia.org/"},
  {title: "GitHub", url: "https://github.com/"}
])
for b in bookmarks { if b.url == "kampf://home" { b.url = "kompass://home"; b.title = "Kompass" } }
let history = load_data("history", [])

fn save_settings() { save_data("settings", settings) }
fn save_bookmarks() { save_data("bookmarks", bookmarks) }

# ---------------------------------------------------------- the window
let ui = col(body(), "browser")
let strip = row(ui, "tabstrip")
let brand = row(strip, "brand")
box(brand, "compass-mark")
label(brand, "Kompass", "brand-name")
on_click(brand, fn() { go(HOME) })
let tabrow = row(strip, "tabs")
let plus = button(strip, "+", fn() { new_tab(settings.home) }, "newtab")
settip(plus, "New tab (Ctrl+T)")

let bar = row(ui, "toolbar")
let navs = row(bar, "navgroup")
let back_btn = button(navs, "‹", fn() { tab_back(current) }, "nav")
let fwd_btn = button(navs, "›", fn() { tab_forward(current) }, "nav")
let reload_btn = button(navs, "↻", fn() { tab_reload(current) }, "nav")
let home_btn = button(navs, "⌂", fn() { go(settings.home) }, "nav")
let omni = row(bar, "omnibox")
box(omni, "omni-needle")
let address = textbox(omni, "Search with Kugel or type a URL", fn(t) { go(t) }, "address")
let star = button(omni, "☆", fn() { toggle_bookmark() }, "star")
let tools = row(bar, "toolgroup")
let yt = button(tools, "▶", fn() { go("https://www.youtube.com/") }, "tool")
let gp_btn = button(tools, "G  Make Google page with KS", fn() { open_page("kompass://builder") }, "tool gtool")
let learn_btn = button(tools, "📘", fn() { open_page("kompass://learn") }, "tool")
let ed_btn = button(tools, "⚡", fn() { open_editor() }, "tool")
let dt_btn = button(tools, "{ }", fn() { ks_devtools() }, "tool")
let gear = button(tools, "⚙", fn() { open_page("kompass://settings") }, "gear")
settip(back_btn, "Back (Alt+Left)")
settip(fwd_btn, "Forward (Alt+Right)")
settip(reload_btn, "Reload (F5)")
settip(home_btn, "Home")
settip(star, "Bookmark this page (Ctrl+D)")
settip(yt, "YouTube (Ctrl+Y)")
settip(gp_btn, "Make Google page with KS (kompass://builder)")
settip(learn_btn, "Learn KampfScript (kompass://learn)")
settip(ed_btn, "KampfScript editor & console (Ctrl+Shift+K)")
settip(dt_btn, "KampfScript DevTools (F12 / Ctrl+Shift+I)")
settip(gear, "Settings")

let pwbar = row(ui, "pw-bar")
show(pwbar, false)
# auto-update banner: shown when a new version has downloaded (see draw_update_bar below)
let updbar = row(ui, "upd-bar")
show(updbar, false)
let gnote = row(ui, "google-note")
show(gnote, false)
let bmbar = row(ui, "bookmarks")
show(bmbar, settings.bookmarks_bar)
let view = box(ui, "view")
view_area(view)
let status = label(ui, "Ready", "status")

# open an internal page: reuse the current tab if it is showing an internal page, else a new tab
fn open_page(url) {
  if current != nil and is_internal(tab_url(current)) { tab_navigate(current, url) } else { new_tab(url) }
}
fn is_internal(u) { return u != nil and (startswith(u, "kompass:") or startswith(u, "kampf:")) }

# ---------------------------------------------------------- tabs
let tabs = {}      # id -> {id, title, url, el, text, icon}
let order = []
let current = nil

fn new_tab(url) {
  let id = tab_new()
  let el = row(tabrow, "tab")
  box(el, "tab-glow")
  let icon = image(el, "", "favicon")
  let text = label(el, "New tab", "tabtitle")
  button(el, "×", fn() { close_tab(id) }, "tabclose")
  on_click(el, fn() { select_tab(id) })
  on_middle_click(el, fn() { close_tab(id) })
  tabs[str(id)] = {id: id, title: "New tab", url: "", el: el, text: text, icon: icon, loading: false}
  push(order, id)
  select_tab(id)
  tab_navigate(id, fix_url(url))
  return id
}

fn select_tab(id) {
  current = id
  tab_select(id)
  for t in order { togglestyle(tabs[str(t)].el, "active", t == id) }
  refresh_toolbar()
}

fn close_tab(id) {
  let i = indexof(order, id)
  tab_close(id)
  destroy(tabs[str(id)].el)
  remove(tabs, str(id))
  remove(order, i)
  if len(order) == 0 { new_tab(settings.home); return }
  if id == current { select_tab(order[min(i, len(order) - 1)]) }
}

fn next_tab() {
  let i = indexof(order, current) + 1
  if i >= len(order) { i = 0 }
  select_tab(order[i])
}

fn refresh_toolbar() {
  if current == nil { return }
  let t = tabs[str(current)]
  let u = tab_url(current)
  if u == HOME or u == "kampf://home" { settext(address, "") } else { settext(address, u) }
  enable(back_btn, tab_can_back(current))
  enable(fwd_btn, tab_can_forward(current))
  if is_bookmarked(u) { settext(star, "★") } else { settext(star, "☆") }
  set_window_title(t.title + " — Kompass")
}

# ---------------------------------------------------------- URLs & search
fn looks_like_url(s) {
  if startswith(s, "http://") or startswith(s, "https://") or is_internal(s) or startswith(s, "about:") { return true }
  if contains(s, " ") { return false }
  if startswith(s, "localhost") { return true }
  let dot = indexof(s, ".")
  return dot > 0 and dot < len(s) - 2
}

fn search_url(q) {
  if settings.engine == "google" { return "https://www.google.com/search?q=" + url_encode(q) }
  if settings.engine == "duckduckgo" { return "https://duckduckgo.com/?q=" + url_encode(q) }
  return "kompass://search?q=" + url_encode(q)
}

fn fix_url(input_text) {
  let q = trim(input_text)
  if q == "" { return settings.home }
  if not looks_like_url(q) { return search_url(q) }
  if startswith(q, "http://") or startswith(q, "https://") or is_internal(q) or startswith(q, "about:") { return q }
  return "https://" + q
}

fn go(input_text) {
  if current == nil { new_tab(input_text); return }
  tab_navigate(current, fix_url(input_text))
}

fn domain(url) {
  if url == nil { return "" }
  let rest = url
  if contains(rest, "://") { rest = split(rest, "://")[1] }
  let host = split(rest, "/")[0]
  if startswith(host, "www.") { host = slice(host, 4) }
  return host
}

fn query_param(url, name) {
  if not contains(url, "?") { return "" }
  for part in split(split(url, "?")[1], "&") {
    let kv = split(part, "=")
    if kv[0] == name and len(kv) > 1 { return url_decode(replace(kv[1], "+", " ")) }
  }
  return ""
}

# ---------------------------------------------------------- bookmarks & history
fn is_bookmarked(url) {
  for b in bookmarks { if b.url == url { return true } }
  return false
}

fn toggle_bookmark() {
  let u = tab_url(current)
  let i = 0
  for b in bookmarks {
    if b.url == u { remove(bookmarks, i); save_bookmarks(); draw_bookmarks(); refresh_toolbar(); return }
    i += 1
  }
  push(bookmarks, {title: slice(tabs[str(current)].title, 0, 40), url: u})
  save_bookmarks()
  draw_bookmarks()
  refresh_toolbar()
  status_text("Bookmarked " + u)
}

fn draw_bookmarks() {
  clear(bmbar)
  for b in bookmarks {
    let url = b.url
    let l = link(bmbar, b.title, fn() { go(url) }, "bm")
    settip(l, url)
  }
}

fn add_history(url, title) {
  if is_internal(url) { return }
  push(history, {url: url, title: title, time: now_text()})
  if len(history) > 500 { remove(history, 0) }
  save_data("history", history)
}

fn status_text(s) { settext(status, s) }

# ---------------------------------------------------------- events from the engine
on_tab_event(fn(ev, id, value) {
  if ev == "popup" { new_tab(value); return }
  let t = tabs[str(id)]
  if t == nil { return }
  if ev == "url" and contains(str(value), "accounts.google.com") and contains(str(value), "/rejected") { google_note(true) }
  if ev == "title" {
    t.title = value
    settext(t.text, value)
    settip(t.el, value)
    if len(history) > 0 and history[-1].url == tab_url(id) { history[-1].title = value; save_data("history", history) }
  } else if ev == "favicon" {
    setimage(t.icon, value)
  } else if ev == "loading" {
    t.loading = value
    togglestyle(t.el, "loading", value)
    if id == current { if value { settext(reload_btn, "✕"); status_text("Loading " + domain(tab_url(id)) + "…") } else { settext(reload_btn, "↻"); status_text("Done") } }
  } else if ev == "visit" {
    if not contains(str(value), "accounts.google.com") { google_note(false) }
    add_history(value, t.title)
    if contains(str(tab_url(id)), "accounts.google.com") and (contains(str(value), "Couldn") or contains(value, "not be secure")) { google_note(true) }
  } else if ev == "error" {
    status_text("Could not load page: " + value)
  } else if ev == "internal" {
    setimage(t.icon, "")
    render_internal(id, value)
  }
  if id == current { refresh_toolbar() }
})

# ---------------------------------------------------------- built-in pages
fn set_tab_title(id, title) {
  let t = tabs[str(id)]
  t.title = title
  settext(t.text, title)
  if id == current { refresh_toolbar() }
}

fn kugel_logo(parent, size) {
  let r = row(parent, "kugel-logo-" + size)
  box(r, "compass-mark")
  label(r, "Kugel", "kugel-word")
  return r
}

fn quick_link(parent, icon, name, url) {
  let tile = col(parent, "tile")
  label(tile, icon, "tile-icon")
  label(tile, name, "tile-name")
  on_click(tile, fn() { go(url) })
}

fn feature_card(parent, icon, title, desc, action) {
  let c = col(parent, "feature")
  label(c, icon, "feature-icon")
  label(c, title, "feature-title")
  label(c, desc, "feature-desc")
  on_click(c, action)
}

fn page_home(id, page) {
  if settings.home_ks != "" and settings.home_ks != nil {
    let mine = find_builder_page(settings.home_ks)
    if mine != nil {
      if custom_home(id, page, mine) { return }
    }
  }
  page_default_home(id, page)
}

# the user's own KampfScript home page (made in kompass://builder)
fn custom_home(id, page, mine) {
  set_tab_title(id, mine.name)
  let holder = box(page, "custom-home")
  let stage = box(holder, "custom-stage")
  let bar_ = row(holder, "custom-bar")
  label(bar_, "★ " + mine.name + " · your KampfScript home page", "custom-bar-name")
  button(bar_, "✎ Edit", fn() { builder.current = mine.name; save_builder(); tab_navigate(id, "kompass://builder") }, "pill ghost")
  button(bar_, "↺ Restore default", fn() { restore_default_home(); tab_reload(id) }, "pill ghost")
  let r = run_page(mine.code, stage, page_handlers(id, false))
  if r.ok { return true }
  destroy(holder)
  let warn = row(page, "custom-error")
  label(warn, "Your home page \"" + mine.name + "\" has an error: " + r.error, "out-err")
  button(warn, "✎ Fix it", fn() { builder.current = mine.name; save_builder(); tab_navigate(id, "kompass://builder") }, "pill")
  return false
}

fn page_default_home(id, page) {
  set_tab_title(id, "Kompass")
  let c = col(page, "home")
  let hero = col(c, "hero")
  box(hero, "compass-rose")
  label(hero, "Kompass", "wordmark")
  label(hero, "Navigate the web — a browser scripted in KampfScript", "tagline")
  let sbox = row(c, "home-searchbar")
  box(sbox, "omni-needle")
  let box_ = textbox(sbox, "Search Kugel or type a URL", fn(t) { go(t) }, "home-search")
  focus(box_)
  let r = row(c, "chips")
  button(r, "Kugel", fn() { go(gettext(box_)) }, "chip")
  button(r, "Google", fn() { tab_navigate(id, "https://www.google.com/search?q=" + url_encode(gettext(box_))) }, "chip")
  button(r, "DuckDuckGo", fn() { tab_navigate(id, "https://duckduckgo.com/?q=" + url_encode(gettext(box_))) }, "chip")
  button(r, "YouTube", fn() { tab_navigate(id, "https://www.youtube.com/results?search_query=" + url_encode(gettext(box_))) }, "chip")
  let mk = button(c, "G   Make Google page with KS  →", fn() { go("kompass://builder") }, "make-gp")
  settip(mk, "Build your own Google-style start page in KampfScript, then set it as your home page")
  let tiles = row(c, "tiles")
  quick_link(tiles, "▶", "YouTube", "https://www.youtube.com/")
  quick_link(tiles, "W", "Wikipedia", "https://en.wikipedia.org/")
  quick_link(tiles, "⌥", "GitHub", "https://github.com/")
  quick_link(tiles, "G", "Google", "https://www.google.com/")
  quick_link(tiles, "◐", "DuckDuckGo", "https://duckduckgo.com/")
  quick_link(tiles, "⟲", "History", "kompass://history")
  let feats = row(c, "features")
  feature_card(feats, "G", "Make Google page with KS", "Build your own search home page", fn() { go("kompass://builder") })
  feature_card(feats, "🛒", "Kugel Store", "Play games & apps people made", fn() { go("kompass://store") })
  feature_card(feats, "📘", "Learn KampfScript", "Lessons, videos & exercises", fn() { go("kompass://learn") })
  feature_card(feats, "⚙", "Settings", "Themes, search, privacy", fn() { go("kompass://settings") })
  feature_card(feats, "⚡", "Editor", "Write & run .ks scripts", fn() { open_editor() })
  feature_card(feats, "{ }", "DevTools", "Look inside browser.ks (F12)", fn() { ks_devtools(true) })
  label(c, "Kompass " + VERSION + " · this page is drawn by browser.ks · theme: " + settings.theme, "home-foot")
}

fn page_search(id, page, url) {
  let q = query_param(url, "q")
  set_tab_title(id, q + " — Kugel")
  let top = row(page, "serp-top")
  let logo = kugel_logo(top, "small")
  on_click(logo, fn() { go(HOME) })
  let sb = textbox(top, "Search Kugel", fn(t) { go(t) }, "serp-search")
  settext(sb, q)
  let alt = row(page, "serp-alt")
  label(alt, "Also try:")
  link(alt, "Google", fn() { tab_navigate(id, "https://www.google.com/search?q=" + url_encode(q)) })
  link(alt, "DuckDuckGo", fn() { tab_navigate(id, "https://duckduckgo.com/?q=" + url_encode(q)) })
  link(alt, "YouTube", fn() { tab_navigate(id, "https://www.youtube.com/results?search_query=" + url_encode(q)) })
  let results = col(page, "serp")
  let wait = label(results, "Searching…", "muted")
  let started = time()
  let r = kugel_search(q)
  if tab_url(id) != url { return }   # user already went somewhere else
  destroy(wait)
  if not r.ok {
    label(results, "Kugel had a problem: " + r.error, "error")
    return
  }
  label(results, "About " + len(r.results) + " results (" + round((time() - started) / 1000, 2) + " seconds) · " + r.engine, "muted")
  if len(r.results) == 0 {
    label(results, "No Kugel results. Try Google or DuckDuckGo above.", "muted")
  }
  for res in r.results {
    let target = res.url
    let item = col(results, "result")
    label(item, domain(target), "result-url")
    link(item, res.title, fn() { tab_navigate(id, target) }, "result-title")
    label(item, res.snippet, "result-snippet")
  }
}

fn page_history(id, page) {
  set_tab_title(id, "History")
  let c = col(page, "list-page")
  heading(c, "History", "page-title")
  let r = row(c)
  button(r, "Clear history", fn() { history = []; save_data("history", history); tab_reload(id) }, "pill")
  if len(history) == 0 { label(c, "Nothing here yet.", "muted") }
  for h in reverse(history) {
    let u = h.url
    let line = row(c, "list-item")
    label(line, h.time, "muted")
    link(line, h.title or u, fn() { go(u) })
    label(line, domain(u), "muted")
  }
}

fn page_bookmarks(id, page) {
  set_tab_title(id, "Bookmarks")
  let c = col(page, "list-page")
  heading(c, "Bookmarks", "page-title")
  let i = 0
  for b in bookmarks {
    let u = b.url
    let idx = i
    let line = row(c, "list-item")
    link(line, b.title, fn() { go(u) })
    label(line, u, "muted")
    button(line, "Remove", fn() { remove(bookmarks, idx); save_bookmarks(); draw_bookmarks(); tab_reload(id) }, "pill")
    i += 1
  }
}

# ---------------------------------------------------------- ⚙ settings
fn set_card(parent, icon, title, anchor) {
  let card = col(parent, "set-card")
  let h = row(card, "set-card-head")
  label(h, icon, "set-icon")
  label(h, title, "set-card-title")
  return card
}

fn set_row(card, title, desc) {
  let r = row(card, "set-row")
  let t = col(r, "set-text")
  label(t, title, "set-title")
  if desc != "" { label(t, desc, "set-desc") }
  return r
}

# a toggle switch; change() flips the setting and returns the new state
fn set_switch(card, title, desc, on, change) {
  let r = set_row(card, title, desc)
  let sw = nil
  sw = button(r, "", fn() { togglestyle(sw, "on", change()) }, "switch")
  togglestyle(sw, "on", on)
  return sw
}

fn page_settings(id, page) {
  set_tab_title(id, "Settings")
  let wrap = row(page, "set-page")
  let side = col(wrap, "set-side")
  let brand_ = row(side, "set-brand")
  box(brand_, "compass-mark")
  label(brand_, "Settings", "set-brand-name")
  for s in ["Search", "Appearance", "Privacy", "Interface", "KampfScript", "Updates", "About"] { label(side, s, "set-nav") }
  label(side, "Every control on this page is KampfScript — see page_settings() in browser.ks", "set-side-foot")
  let c = col(wrap, "set-main")
  heading(c, "Kompass settings", "page-title")

  # --- search & home
  let s1 = set_card(c, "⌕", "Search & home page", "search")
  let r = set_row(s1, "Default search engine", "Used when you type words in the address bar")
  let seg = row(r, "segmented")
  let engine_btns = []
  for e in [["kugel", "Kugel"], ["google", "Google"], ["duckduckgo", "DuckDuckGo"]] {
    let key = e[0]
    let b = button(seg, e[1], fn() {
      settings.engine = key
      save_settings()
      for x in engine_btns { togglestyle(x.btn, "selected", x.key == key) }
    }, "seg")
    togglestyle(b, "selected", settings.engine == key)
    push(engine_btns, {key: key, btn: b})
  }
  let r2 = set_row(s1, "Home page", "Address opened by ⌂, new tabs and on start")
  let hb = textbox(r2, "kompass://home", fn(t) { settings.home = fix_url(t); save_settings(); status_text("Home page set to " + settings.home) }, "set-input")
  settext(hb, settings.home)
  button(r2, "Save", fn() { settings.home = fix_url(gettext(hb)); save_settings(); settext(hb, settings.home); status_text("Home page set to " + settings.home) }, "pill")
  button(r2, "Default", fn() { settings.home = HOME; save_settings(); settext(hb, HOME) }, "pill ghost")

  # --- appearance
  let s2 = set_card(c, "◐", "Appearance", "appearance")
  label(s2, "Theme", "set-title")
  let grid = row(s2, "theme-grid")
  let theme_cards = []
  for th in THEMES {
    let tid = th.id
    let card = col(grid, "theme-card")
    let prev = row(card, "theme-preview")
    for colr in th.colors { let sw = box(prev, "theme-swatch"); setcolor(sw, colr) }
    label(card, th.name, "theme-name")
    label(card, th.desc, "theme-desc")
    togglestyle(card, "selected", settings.theme == tid)
    push(theme_cards, {id: tid, el: card})
    on_click(card, fn() {
      settings.theme = tid
      save_settings()
      apply_look()
      for x in theme_cards { togglestyle(x.el, "selected", x.id == tid) }
    })
  }
  let r3 = set_row(s2, "Accent colour", "Overrides the theme's accent (needle, highlights, gradients)")
  let dots = row(r3, "accent-row")
  let auto = button(dots, "Theme", fn() { settings.accent = ""; save_settings(); apply_look() }, "pill ghost")
  for a in ACCENTS {
    let col_ = a
    let d = button(dots, "", fn() { settings.accent = col_; save_settings(); apply_look() }, "accent-dot")
    setcolor(d, col_)
    settip(d, col_)
  }
  let custom = textbox(dots, "#hex", fn(t) {
    let v = trim(t)
    if startswith(v, "#") and (len(v) == 4 or len(v) == 7) { settings.accent = v; save_settings(); apply_look() } else { status_text("Use a colour like #c9a227") }
  }, "hex-input")
  settext(custom, settings.accent)

  # --- privacy
  let s3 = set_card(c, "⛨", "Privacy & data", "privacy")
  let ab = adblock()
  set_switch(s3, "Block ads & trackers", "Uses resources/ks/blocklist.txt · " + ab.blocked + " requests blocked this session", ab.on, fn() {
    settings.adblock = not adblock().on
    adblock(settings.adblock)
    save_settings()
    return settings.adblock
  })
  let r4 = set_row(s3, "History", len(history) + " pages remembered")
  button(r4, "View", fn() { go("kompass://history") }, "pill ghost")
  button(r4, "Clear history", fn() {
    if confirm("Clear your Kompass browsing history?") { history = []; save_data("history", history); status_text("History cleared"); tab_reload(id) }
  }, "pill")
  let r5 = set_row(s3, "Browsing data", "Cookies, site storage, logins and cache for all websites (plus history)")
  button(r5, "Clear all data", fn() {
    if confirm("Clear cookies, site data, cache and history? You will be signed out of websites.") {
      clear_browsing_data()
      history = []
      save_data("history", history)
      status_text("Browsing data cleared")
      tab_reload(id)
    }
  }, "pill danger")

  # --- interface
  let s4 = set_card(c, "▤", "Interface", "interface")
  set_switch(s4, "Show bookmarks bar", "The row of bookmarks under the address bar (Ctrl+D adds one)", settings.bookmarks_bar, fn() {
    settings.bookmarks_bar = not settings.bookmarks_bar
    show(bmbar, settings.bookmarks_bar)
    save_settings()
    return settings.bookmarks_bar
  })
  set_switch(s4, "KampfScript DevTools", "F12 / Ctrl+Shift+I open the inspector for browser.ks (web-page devtools stay in the menu below)", settings.devtools, fn() {
    settings.devtools = not settings.devtools
    if not settings.devtools { ks_devtools(false) }
    show(dt_btn, settings.devtools)
    save_settings()
    return settings.devtools
  })
  let r6 = set_row(s4, "Bookmarks", len(bookmarks) + " saved")
  button(r6, "Manage", fn() { go("kompass://bookmarks") }, "pill ghost")

  # --- KampfScript
  let s5 = set_card(c, "⚡", "KampfScript", "kampfscript")
  let r7 = set_row(s5, "Learn KampfScript", "Lessons with runnable examples, exercises and tutorial videos")
  button(r7, "📘 Open kompass://learn", fn() { go("kompass://learn") }, "pill")
  let r7b = set_row(s5, "Make Google page with KS", "Design your own search home page in KampfScript · home page now: " + home_desc())
  button(r7b, "G Open builder", fn() { go("kompass://builder") }, "pill")
  button(r7b, "↺ Restore default home", fn() { restore_default_home(); tab_reload(id) }, "pill ghost")
  let r7c = set_row(s5, "KampfScript for AIs", "One complete, copy-friendly language reference to paste into an AI assistant")
  button(r7c, "🤖 Open kompass://learn/ai", fn() { go("kompass://learn/ai") }, "pill ghost")
  let r7d = set_row(s5, "Passwords", "Built-in encrypted password manager (master password, auto-lock, autofill)")
  button(r7d, "🔑 Open kompass://passwords", fn() { go("kompass://passwords") }, "pill ghost")
  let r8 = set_row(s5, "Editor & console", "Write .ks scripts or edit browser.ks itself")
  button(r8, "⚡ Editor", fn() { open_editor() }, "pill ghost")
  button(r8, "✎ Edit browser.ks", fn() { open_editor("@browser") }, "pill ghost")
  button(r8, "📁 Data folder", fn() { open_data_folder() }, "pill ghost")
  let r9 = set_row(s5, "Developer tools", "KampfScript DevTools (F12) or Chromium devtools for the current web page")
  button(r9, "{ } KampfScript DevTools", fn() { ks_devtools(true) }, "pill ghost")
  button(r9, "🛠 Page devtools", fn() { tab_devtools(current) }, "pill ghost")
  let r10 = set_row(s5, "Tutorial video URLs", "Optional https:// .mp4 links, used when resources/videos/lesson1.mp4 / lesson2.mp4 are not present")
  let v1 = textbox(r10, "Video 1 URL", fn(t) { settings.video1_url = trim(t); save_settings(); status_text("Video 1 URL saved") }, "set-input")
  settext(v1, settings.video1_url)
  let v2 = textbox(r10, "Video 2 URL", fn(t) { settings.video2_url = trim(t); save_settings(); status_text("Video 2 URL saved") }, "set-input")
  settext(v2, settings.video2_url)
  button(r10, "Save", fn() { settings.video1_url = trim(gettext(v1)); settings.video2_url = trim(gettext(v2)); save_settings(); status_text("Video URLs saved") }, "pill")
  let r11 = set_row(s5, "Reset browser.ks", "Throw away your edits to browser.ks and restore the built-in " + VERSION + " version")
  button(r11, "Reset & restart", fn() {
    if confirm("Restore the original browser.ks and restart Kompass? Your edits to browser.ks will be lost.") { reset_browser() }
  }, "pill danger")

  # --- updates
  let su = set_card(c, "⬆", "Updates", "updates")
  let ust = update_state()
  set_switch(su, "Auto-update", "Check GitHub on launch and every few hours, download new versions in the background and install them on restart", ust.autoUpdate, fn() {
    let n = update_auto(not update_state().autoUpdate)
    return n.autoUpdate
  })
  let ru = set_row(su, "Kompass " + app_version(), update_text(ust))
  let uinfo = label(ru, "", "set-desc upd-info")
  button(ru, "Check for updates", fn() {
    settext(uinfo, "Checking…")
    let r = update_check()
    settext(uinfo, update_text(r))
  }, "pill")
  let urestart = button(ru, "Restart to update", fn() { update_install() }, "pill")
  show(urestart, ust.status == "ready")
  push(upd_listeners, fn(st) { settext(uinfo, update_text(st)); show(urestart, st.status == "ready") })

  # --- about
  let s6 = set_card(c, "🧭", "About", "about")
  let r12 = set_row(s6, "Kompass " + VERSION, "App " + app_version() + " · interface: browser.ks (KampfScript) · engine: Chromium in sandboxed webviews · search: Kugel")
  button(r12, "About page", fn() { go("kompass://about") }, "pill ghost")
  button(r12, "GitHub", fn() { go("https://github.com/KampfGuy/kompass") }, "pill ghost")
}

fn page_about(id, page) {
  set_tab_title(id, "About Kompass")
  let c = col(page, "about")
  box(c, "compass-rose")
  label(c, "Kompass", "wordmark")
  label(c, "Version " + VERSION, "tagline")
  label(c, "A web browser whose whole interface is a KampfScript program (browser.ks).")
  label(c, "Pages are rendered by Chromium in sandboxed webviews. Search by Kugel. Fonts: Space Grotesk & Space Mono (SIL OFL).")
  let r = row(c, "chips")
  button(r, "📘 Learn KampfScript", fn() { go("kompass://learn") }, "chip")
  button(r, "⚙ Settings", fn() { go("kompass://settings") }, "chip")
  button(r, "GitHub", fn() { go("https://github.com/KampfGuy/kompass") }, "chip")
}

# ---------------------------------------------------------- 📘 kompass://learn — Learn KampfScript
# Lessons are plain KampfScript data. "Try it" runs code in run_sandbox(): a fresh interpreter
# with only the core built-ins (and, for the UI lesson, a little stage to draw in).
let LESSONS = [
  {icon: "①", title: "Hello, KampfScript", ui: false,
   text: ["KampfScript is a tiny, friendly language. A program is a list of statements, one per line (or separated by ;).",
          "print() shows values. Text goes in quotes; numbers don't. Lines starting with # are comments."],
   code: "# my first program\nprint(\"Hello, Kompass!\")\nprint(\"2 + 3 =\", 2 + 3)\nprint(10 / 4, 7 % 3)",
   task: "Print exactly: KampfScript rocks", starter: "print(\"...\")\n", expect: "KampfScript rocks"},
  {icon: "②", title: "Variables", ui: false,
   text: ["let creates a variable. Assign a new value with =, or update it with += -= *= /=.",
          "Strings join with +. Numbers join with strings automatically. len() counts letters, upper() shouts."],
   code: "let name = \"Kampf\"\nlet age = 16\nage += 1\nprint(\"Hi \" + name + \", next year you are \" + age)\nprint(upper(name), len(name))",
   task: "Make a variable score = 40, add 2 to it with +=, then print it (42).", starter: "let score = 40\n", expect: "42"},
  {icon: "③", title: "If / else", ui: false,
   text: ["if runs a block only when a condition is true. Compare with == != < > <= >=, combine with and / or / not.",
          "Chain choices with else if, and catch everything else with else."],
   code: "let temp = 23\nif temp > 30 {\n  print(\"hot\")\n} else if temp > 15 {\n  print(\"nice\")\n} else {\n  print(\"cold\")\n}\nprint(temp > 20 and temp < 25)",
   task: "Set n = 7. Print \"odd\" if n % 2 == 1, otherwise print \"even\".", starter: "let n = 7\n", expect: "odd"},
  {icon: "④", title: "Loops", ui: false,
   text: ["while repeats as long as a condition is true. for x in list walks through a list, string, map keys or a number.",
          "range(5) is [0, 1, 2, 3, 4]. break leaves a loop early, continue skips to the next round."],
   code: "for i in range(1, 4) {\n  print(\"round\", i)\n}\nlet n = 1\nwhile n < 100 { n *= 3 }\nprint(\"first power of 3 over 100:\", n)",
   task: "Print the numbers 1, 2, 3, 4, 5 — one per line — with a for loop.", starter: "for i in range(1, 6) {\n  \n}\n", expect: "1\n2\n3\n4\n5"},
  {icon: "⑤", title: "Functions", ui: false,
   text: ["fn name(params) { ... } makes a function; return sends a value back. Functions are values too: fn(x) { ... } without a name.",
          "map(list, f) and filter(list, f) take a function and apply it to every item."],
   code: "fn square(x) { return x * x }\nprint(square(9))\nlet double = fn(x) { return x * 2 }\nprint(map([1, 2, 3], double))\nprint(filter(range(10), fn(x) { return x % 3 == 0 }))",
   task: "Write fn greet(who) that returns \"Hello, \" + who + \"!\" and print greet(\"Kampf\").", starter: "fn greet(who) {\n  \n}\nprint(greet(\"Kampf\"))\n", expect: "Hello, Kampf!"},
  {icon: "⑥", title: "Lists & maps", ui: false,
   text: ["Lists hold items in order: [1, 2, 3]. Read with list[0], last item with list[-1], add with push().",
          "Maps hold named fields: {title: \"YouTube\", url: \"...\"}. Read with m.title or m[\"title\"]; keys(m) lists the names."],
   code: "let sites = [{title: \"YouTube\", url: \"youtube.com\"}]\npush(sites, {title: \"Wiki\", url: \"wikipedia.org\"})\nfor s in sites { print(s.title, \"->\", s.url) }\nlet ages = {kampf: 13, ada: 36}\nages.linus = 54\nprint(keys(ages), len(ages))",
   task: "Make a list nums = [3, 9, 4], push 10 onto it and print the sum of all items (26).", starter: "let nums = [3, 9, 4]\nlet total = 0\n", expect: "26"},
  {icon: "⑦", title: "Drawing UI", ui: true,
   text: ["Kompass draws its whole interface with UI built-ins: body(), row(), col(), label(), button(), textbox(), heading().",
          "Each takes a parent and returns an element. button(parent, text, fn) runs the fn when clicked. In this lesson body() is the little stage below the code."],
   code: "let card = col(body())\nheading(card, \"Counter\")\nlet n = 0\nlet shown = label(card, \"Clicked 0 times\")\nbutton(card, \"Click me\", fn() {\n  n += 1\n  settext(shown, \"Clicked \" + n + \" times\")\n})",
   task: "Make a label that says Ready and print(gettext(...)) it.", starter: "let l = label(body(), \"Ready\")\n", expect: "Ready"},
  {icon: "⑧", title: "Scripting the browser", ui: false,
   text: ["browser.ks uses browser built-ins: tab_new, tab_navigate(id, url), tab_back, tab_url, on_tab_event(fn(ev, id, value) {...}), on_key(\"ctrl+t\", fn), load_data / save_data.",
          "Here open_tab is sandboxed (it only prints). Try the real thing in the ⚡ editor (Ctrl+Shift+K), or open { } DevTools (F12) and type tab_url(current) in its console to poke the live browser."],
   code: "fn fix_url(s) {\n  if startswith(s, \"http\") { return s }\n  return \"https://\" + s\n}\nfor site in [\"youtube.com\", \"https://github.com\"] {\n  open_tab(fix_url(site))\n}",
   task: "Write fn domain(url) that returns the part after \"://\" (use split) and print domain(\"https://kompass.app\").", starter: "fn domain(url) {\n  \n}\nprint(domain(\"https://kompass.app\"))\n", expect: "kompass.app"},
  {icon: "⑨", title: "Make Google page with KS", ui: true,
   text: ["kompass://builder lets you design your OWN Google-style home page in KampfScript: code on the left, live preview on the right, then ⌂ Set as my home page.",
          "Styling built-ins: colorletters(parent, text, colors) colours each letter, setfont(el, family, size, weight), setstyle(el, prop, value), gradient(el, c1, c2), setsize(el, w, h), spacer(parent, px). In the builder, search(text) and lucky(text) really search."],
   code: "let page = col(body())\nlet logo = colorletters(page, \"Kompass\", [\"#4285f4\", \"#ea4335\", \"#fbbc05\", \"#34a853\"])\nsetfont(logo, \"Arial\", 48, \"bold\")\nlet q = textbox(page, \"Search…\")\nbutton(page, \"Search\", fn() { print(\"searching for \" + gettext(q)) })\nbutton(page, \"I'm Feeling Lucky\", fn() { print(\"lucky: \" + gettext(q)) })",
   task: "Logo colours repeat: let colors = [\"#4285f4\", \"#ea4335\", \"#fbbc05\"]. Print the colour of letter number 4 (index 4) of \"Google\" using colors[i % len(colors)].", starter: "let colors = [\"#4285f4\", \"#ea4335\", \"#fbbc05\"]\n", expect: "#ea4335"},
  {icon: "⑩", title: "Your own pages", ui: true,
   text: ["Any script can be a page: save it in the ⚡ editor as scripts/NAME.ks and open kompass://page/NAME — Kompass runs it in its own tab. 📄 New page in the editor makes a starter page for you.",
          "From an editor script, page_new(\"Title\") opens a fresh tab and returns a box to draw into. Pages get the UI + styling built-ins and search(), lucky(), open_url(), engine()."],
   code: "let page = col(body())\nheading(page, \"My page\")\nlet todo = [\"learn KampfScript\", \"make a page\"]\nfor t in todo { label(page, \"☐ \" + t) }\nlet box_ = textbox(page, \"add a todo + Enter\", fn(t) { label(page, \"☐ \" + t) })",
   task: "Print the address of a page saved as scripts/todo.ks: \"kompass://page/\" + name, with let name = \"todo\".", starter: "let name = \"todo\"\n", expect: "kompass://page/todo"},
  {icon: "⑪", title: "New in 1.3: games & apps", ui: true,
   text: ["Friendlier syntax: `template strings` put values inside text with {braces}: `Hi {name}, next year you are {age + 1}`. for i, item in list gives the index too (for key, value in map). x %= 3 works, and typos get a hint: pirnt -> did you mean print?",
          "Build real apps: canvas(parent, w, h) + draw_rect / draw_circle / draw_line / draw_text / draw_poly, on_frame(fn(dt) {...}) runs every frame, key_down(\"left\") and on_mouse(c, fn(e) {...}) read input, slider / checkbox / dropdown make controls, store_get / store_set remember things, vec / vadd / vlen / atan2 / clamp do the maths. The whole Spaceflight Sim (kompass://spaceflight) is written this way."],
   code: "let c = canvas(body(), 320, 160)\nlet ball = {x: 40, y: 40, vx: 120, vy: 90}\non_frame(fn(dt) {\n  ball.x += ball.vx * dt\n  ball.y += ball.vy * dt\n  if ball.x < 10 or ball.x > 310 { ball.vx = -ball.vx }\n  if ball.y < 10 or ball.y > 150 { ball.vy = -ball.vy }\n  draw_clear(c, \"#141414\")\n  draw_circle(c, ball.x, ball.y, 10, \"#ff4500\")\n  draw_text(c, 10, 14, `x = {round(ball.x)}`, \"white\", 12)\n})",
   task: "With let age = 16, print a template string so the output is: next year: 17", starter: "let age = 16\n", expect: "next year: 17"}
]

let learn = load_data("learn_progress", {done: {}, tried: {}, last: 0})
if learn.done == nil { learn.done = {} }
if learn.tried == nil { learn.tried = {} }
if learn.last == nil { learn.last = 0 }
fn save_learn() { save_data("learn_progress", learn) }

fn video_src(n) {
  let f = video_file("lesson" + str(n) + ".mp4")
  if f != "" { return f }
  let u = settings["video" + str(n) + "_url"]
  if u != nil and startswith(u, "https://") { return u }
  return ""
}

fn video_slot(parent, n, title, topic) {
  let card = col(parent, "video-card")
  let src = video_src(n)
  if src != "" {
    video(card, src, "lesson-video")
  } else {
    let ph = col(card, "video-placeholder")
    box(ph, "compass-rose small")
    label(ph, "Video coming soon", "ph-title")
    label(ph, "Narrated tutorial by the Engineering Department", "ph-sub")
    label(ph, "Drop lesson" + str(n) + ".mp4 into resources/videos/ (MP4 · H.264/AAC · 1920×1080)", "ph-hint")
  }
  label(card, "Video " + str(n) + " · " + title, "video-title")
  label(card, topic, "video-topic")
}

fn count_done() {
  let n = 0
  for k in keys(learn.done) { if learn.done[k] { n += 1 } }
  return n
}

fn page_learn(id, page) {
  set_tab_title(id, "Learn KampfScript")
  let wrap = row(page, "learn-page")
  let side = col(wrap, "learn-side")
  let brand_ = row(side, "set-brand")
  box(brand_, "compass-mark")
  label(brand_, "Learn", "set-brand-name")
  let prog = label(side, "", "learn-progress")
  let bar_ = box(side, "progress-track")
  let fill = box(bar_, "progress-fill")
  let items = []
  let main = col(wrap, "learn-main")

  fn update_progress() {
    let d = count_done()
    settext(prog, str(d) + " of " + str(len(LESSONS)) + " exercises solved")
    for k in range(9) { removestyle(fill, "p" + str(k)) }
    addstyle(fill, "p" + str(round(d * 8 / len(LESSONS))))
    let i = 0
    for it in items {
      togglestyle(it, "done", learn.done[str(i)] == true)
      togglestyle(it, "active", i == learn.last)
      i += 1
    }
  }

  fn show_lesson(i) {
    learn.last = i
    save_learn()
    clear(main)
    draw_lesson(main, i)
    update_progress()
  }

  fn draw_intro(m) {
    let hero = col(m, "learn-hero")
    label(hero, "LEARN KAMPFSCRIPT", "eyebrow")
    heading(hero, "Script your own browser", "learn-title")
    label(hero, "Eleven short lessons. Every example runs right here — press ▶ Try it, change the code, try again. Solve the small exercise at the end of each lesson to fill your compass.", "learn-lead")
    let extra = row(m, "chips")
    button(extra, "G Make Google page with KS", fn() { go("kompass://builder") }, "chip")
    button(extra, "🤖 For AIs: copy the whole language reference", fn() { go("kompass://learn/ai") }, "chip")
    button(extra, "🚀 Example: Spaceflight Sim in KampfScript", fn() { go("kompass://spaceflight") }, "chip")
    let vids = row(m, "video-row")
    video_slot(vids, 1, "Intro to KampfScript", "variables, print, if, loops")
    video_slot(vids, 2, "Functions, lists & the browser", "functions, lists/maps, and scripting the Kompass browser")
  }

  fn draw_lesson(m, i) {
    if i == 0 { draw_intro(m) }
    let L = LESSONS[i]
    let card = col(m, "lesson")
    let head = row(card, "lesson-head")
    label(head, L.icon, "lesson-num")
    heading(head, L.title, "lesson-title")
    for p in L.text { label(card, p, "lesson-text") }
    label(card, "Example", "lesson-label")
    code_runner(card, L.code, L.ui, "")
    let ex = col(card, "exercise")
    let eh = row(ex, "exercise-head")
    label(eh, "✎ Exercise", "exercise-tag")
    label(eh, L.task, "exercise-task")
    code_runner(ex, L.starter, L.ui, L.expect, fn() {
      learn.done[str(i)] = true
      save_learn()
      update_progress()
    })
    let nav = row(m, "lesson-nav")
    if i > 0 { button(nav, "‹ " + LESSONS[i - 1].title, fn() { show_lesson(i - 1) }, "pill ghost") }
    if i < len(LESSONS) - 1 { button(nav, LESSONS[i + 1].title + " ›", fn() { show_lesson(i + 1) }, "pill") }
    else { button(nav, "🎉 Open the ⚡ editor and build something", fn() { open_editor() }, "pill") }
  }

  let i = 0
  for L in LESSONS {
    let idx = i
    let it = row(side, "learn-item")
    label(it, L.icon, "learn-item-num")
    label(it, L.title, "learn-item-title")
    label(it, "✓", "learn-item-check")
    on_click(it, fn() { show_lesson(idx) })
    push(items, it)
    i += 1
  }
  label(side, "More", "learn-more-head")
  let more1 = row(side, "learn-item learn-extra")
  label(more1, "G", "learn-item-num")
  label(more1, "Make Google page with KS", "learn-item-title")
  on_click(more1, fn() { go("kompass://builder") })
  let more2 = row(side, "learn-item learn-extra")
  label(more2, "🤖", "learn-item-num")
  label(more2, "For AIs: KampfScript reference", "learn-item-title")
  on_click(more2, fn() { go("kompass://learn/ai") })
  label(side, "Progress is saved in learn_progress.json", "set-side-foot")
  link(side, "Reset progress", fn() { learn.done = {}; save_learn(); show_lesson(0) }, "set-side-foot")
  show_lesson(learn.last)
}

# code box + ▶ Try it + output. When expect != "", checks the printed output.
fn code_runner(parent, code, with_ui, expect, on_pass) {
  let box_ = col(parent, "runner")
  let editor = codebox(box_, code, "try-code")
  let tools_ = row(box_, "runner-bar")
  let out = col(box_, "try-out")
  let stage = nil
  if with_ui { stage = box(box_, "try-stage") }
  let run_it = fn() {
    clear(out)
    let r = run_sandbox(gettext(editor), stage)
    for line in r.output { label(out, line, "out-line") }
    if not r.ok { label(out, "✖ " + r.error, "out-err") }
    if expect == "" {
      if r.ok { label(out, "✔ ran in " + str(r.steps) + " steps", "out-ok") }
      return
    }
    if r.ok and trim(join(r.output, "\n")) == expect {
      label(out, "★ Correct! Exercise solved.", "out-pass")
      if on_pass != nil { on_pass() }
    } else if r.ok {
      label(out, "Not quite — expected output: " + replace(expect, "\n", " / "), "out-hint")
    }
  }
  button(tools_, "▶ Try it", run_it, "try-btn")
  button(tools_, "↺ Reset", fn() { settext(editor, code); clear(out) }, "pill ghost")
  if expect != "" { label(tools_, "Your output is checked automatically", "muted") } else { label(tools_, "Sandboxed: no tabs, files or network", "muted") }
}


# ---------------------------------------------------------- G kompass://builder — Make Google page with KS
# Your pages are KampfScript programs saved in builder.json. They run in an isolated interpreter
# (run_page) with the UI + styling built-ins and a small page API: search, lucky, open_url, engine.
let TEMPLATES = [
  {name: "Classic Google", file: "builder-classic.ks", desc: "Coloured logo, search box, two buttons, tiles"},
  {name: "Dark mode", file: "builder-dark.ks", desc: "Gradient background, your own name as logo"},
  {name: "Minimal", file: "builder-minimal.ks", desc: "One word and a search box"},
  {name: "Retro portal", file: "builder-retro.ks", desc: "90s neon, clock and random tips"}
]
let builder = load_data("builder", {pages: [], current: "", live: true})
if builder.pages == nil { builder.pages = [] }
if builder.live == nil { builder.live = true }
fn save_builder() { save_data("builder", builder) }

fn template_code(i) { return read_resource(TEMPLATES[i].file) }
fn find_builder_page(name) {
  for p in builder.pages { if p.name == name { return p } }
  return nil
}
fn home_desc() {
  if settings.home_ks != "" and settings.home_ks != nil and find_builder_page(settings.home_ks) != nil { return "\"" + settings.home_ks + "\" (KampfScript)" }
  return "default Kompass start page"
}
fn restore_default_home() {
  settings.home_ks = ""
  save_settings()
  status_text("Home page restored to the default Kompass start page")
}

fn lucky_url(q) {
  if settings.engine == "google" { return "https://www.google.com/search?btnI=1&q=" + url_encode(q) }
  if settings.engine == "duckduckgo" { return "https://duckduckgo.com/?q=" + url_encode("! " + q) }
  let r = kugel_search(q)
  if r.ok and len(r.results) > 0 { return r.results[0].url }
  return search_url(q)
}

# handlers for a running page; preview=true opens results in a new tab so the builder stays open
fn page_handlers(id, preview) {
  let target = fn(u) { if preview { new_tab(u) } else { tab_navigate(id, u) } }
  return {
    engine: settings.engine,
    search: fn(q) { if trim(q) != "" { target(fix_url(q)) } },
    lucky: fn(q) { if trim(q) != "" { target(lucky_url(trim(q))) } },
    open: fn(u) { target(fix_url(u)) },
    print: fn(s) { status_text("page: " + s) },
    error: fn(m) { status_text("Page error: " + m) }
  }
}

fn unique_name(base) {
  let n = base
  let i = 2
  while find_builder_page(n) != nil { n = base + " " + str(i); i += 1 }
  return n
}

fn page_builder(id, page) {
  set_tab_title(id, "Make Google page with KS")
  if len(builder.pages) == 0 {
    push(builder.pages, {name: "My Google page", code: template_code(0)})
    builder.current = "My Google page"
    save_builder()
  }
  let cur = find_builder_page(builder.current)
  if cur == nil { cur = builder.pages[0]; builder.current = cur.name }

  let wrap = col(page, "bld-page")
  let head = row(wrap, "bld-head")
  let t = row(head, "bld-title")
  colorletters(t, "G", ["#4285f4"], "bld-g")
  heading(t, "Make Google page with KS", "bld-h")
  let name_box = textbox(head, "page name", nil, "bld-name")
  settext(name_box, cur.name)
  let acts = row(head, "bld-actions")
  let msg = label(wrap, "", "bld-msg")
  let presets = row(wrap, "bld-presets")
  let mine = row(wrap, "bld-mine")
  let split_ = row(wrap, "bld-split")
  let left = col(split_, "bld-left")
  let lhead = row(left, "bld-pane-head")
  label(lhead, "KampfScript", "bld-pane-title")
  let live_btn = nil
  live_btn = button(lhead, "Live", fn() { builder.live = not builder.live; save_builder(); togglestyle(live_btn, "selected", builder.live); if builder.live { run_preview() } }, "seg")
  togglestyle(live_btn, "selected", builder.live)
  settip(live_btn, "Re-run the preview as you type")
  let editor = codebox(left, cur.code, "bld-code fill")
  let out = col(left, "bld-out")
  let right = col(split_, "bld-right")
  let rhead = row(right, "bld-pane-head")
  label(rhead, "Live preview", "bld-pane-title")
  label(rhead, "search / lucky open a new tab here · engine: " + settings.engine, "muted")
  let stage = box(right, "bld-stage")

  fn say(s) { settext(msg, s) }
  fn run_preview() {
    clear(out)
    let r = run_page(gettext(editor), stage, page_handlers(id, true))
    for line in r.output { label(out, line, "out-line") }
    if r.ok { label(out, "✔ ran in " + str(r.steps) + " steps", "out-ok") } else { label(out, "✖ " + r.error, "out-err") }
    return r.ok
  }
  fn store() {
    let nm = trim(gettext(name_box))
    if nm == "" { nm = unique_name("My Google page") }
    if nm != cur.name and find_builder_page(nm) != nil { say("A page named \"" + nm + "\" already exists"); return false }
    if settings.home_ks == cur.name and nm != cur.name { settings.home_ks = nm; save_settings() }
    cur.name = nm
    cur.code = gettext(editor)
    builder.current = nm
    save_builder()
    draw_mine()
    return true
  }
  fn load_page(p) {
    cur = p
    builder.current = p.name
    save_builder()
    settext(name_box, p.name)
    settext(editor, p.code)
    draw_mine()
    run_preview()
  }
  fn draw_mine() {
    clear(mine)
    label(mine, "My pages:", "bld-row-label")
    for p in builder.pages {
      let pp = p
      let star_ = ""
      if settings.home_ks == p.name { star_ = "⌂ " }
      let b = button(mine, star_ + p.name, fn() { store(); load_page(pp) }, "chip")
      togglestyle(b, "selected", p.name == cur.name)
    }
  }

  button(acts, "▶ Run", fn() { run_preview() }, "pill")
  button(acts, "💾 Save", fn() { if store() { say("Saved \"" + cur.name + "\"") } }, "pill ghost")
  button(acts, "＋ New", fn() {
    store()
    let p = {name: unique_name("My Google page"), code: template_code(0)}
    push(builder.pages, p)
    load_page(p)
    say("New page from the Classic Google template")
  }, "pill ghost")
  button(acts, "🗑 Delete", fn() {
    if len(builder.pages) < 2 { say("Keep at least one page (edit it instead)"); return }
    if not confirm("Delete \"" + cur.name + "\"?") { return }
    remove(builder.pages, indexof(map(builder.pages, fn(p) { return p.name }), cur.name))
    if settings.home_ks == cur.name { restore_default_home() }
    load_page(builder.pages[0])
  }, "pill ghost")
  button(acts, "⌂ Set as my home page", fn() {
    if not store() { return }
    if not run_preview() { say("Fix the error first — your home page must run cleanly"); return }
    settings.home_ks = cur.name
    settings.home = HOME
    save_settings()
    draw_mine()
    say("⌂ \"" + cur.name + "\" is now your home page (new tabs, ⌂ and start-up)")
  }, "pill gp-home-btn")
  button(acts, "🌍 Publish", fn() {
    if not store() { return }
    if not run_preview() { say("Fix the error first — published pages must run cleanly"); return }
    pub_draft = {title: cur.name, code: cur.code}
    go("kompass://store/publish")
  }, "pill ghost")
  button(acts, "↺ Restore default", fn() { restore_default_home(); draw_mine(); say("Home page is the default Kompass start page again") }, "pill ghost")

  label(presets, "Templates:", "bld-row-label")
  let ti = 0
  for tp in TEMPLATES {
    let idx = ti
    let b = button(presets, tp.name, fn() {
      settext(editor, template_code(idx))
      run_preview()
      say("Loaded the \"" + TEMPLATES[idx].name + "\" template — 💾 Save to keep it")
    }, "chip")
    settip(b, tp.desc)
    ti += 1
  }
  link(presets, "📘 Lesson", fn() { learn.last = 8; save_learn(); go("kompass://learn") }, "bld-link")
  link(presets, "🤖 Reference", fn() { go("kompass://learn/ai") }, "bld-link")

  on_input(editor, fn(code) { if builder.live { run_preview() } }, 450)
  draw_mine()
  say("Home page now: " + home_desc())
  run_preview()
}

# ---------------------------------------------------------- 🤖 kompass://learn/ai — KampfScript for AIs
fn page_ai(id, page) {
  set_tab_title(id, "KampfScript for AIs")
  let doc = read_resource("KAMPFSCRIPT_FOR_AI.md")
  let c = col(page, "ai-page")
  let h = row(c, "ai-head")
  let ht = col(h, "ai-head-text")
  label(ht, "LEARN · FOR AIs", "eyebrow")
  heading(ht, "KampfScript for AI assistants", "learn-title")
  label(ht, "One complete reference — language, every built-in, Kompass architecture, idioms, gotchas and examples. Paste it into ChatGPT, Claude, Grok… then ask it to write KampfScript.", "learn-lead")
  let acts = row(c, "ai-actions")
  let info = label(c, str(len(split(doc, "\n"))) + " lines · " + str(len(doc)) + " characters · generated from the real interpreter", "muted")
  button(acts, "⧉ Copy all", fn() { copy_text(doc); settext(info, "✔ Copied " + str(len(doc)) + " characters to the clipboard"); status_text("KampfScript reference copied") }, "pill ai-copy")
  button(acts, "💾 Save as .md", fn() { let f = save_text_file("KAMPFSCRIPT_FOR_AI.md", doc); if f != "" { settext(info, "✔ Saved " + f) } }, "pill ghost")
  button(acts, "💾 Save as .txt", fn() { let f = save_text_file("KAMPFSCRIPT_FOR_AI.txt", doc); if f != "" { settext(info, "✔ Saved " + f) } }, "pill ghost")
  button(acts, "‹ Back to Learn", fn() { go("kompass://learn") }, "pill ghost")
  if doc == "" { label(c, "The reference file is missing (resources/KAMPFSCRIPT_FOR_AI.md).", "error"); return }
  label(c, doc, "ai-doc")
}

fn render_internal(id, url) {
  let page = tab_page(id)
  let name = split(split(url, "?")[0], "//")
  let where = name[-1]
  if where == "home" or where == "kampf:" or where == "kompass:" { page_home(id, page) }
  else if where == "search" { page_search(id, page, url) }
  else if where == "history" { page_history(id, page) }
  else if where == "bookmarks" { page_bookmarks(id, page) }
  else if where == "settings" { page_settings(id, page) }
  else if where == "about" { page_about(id, page) }
  else if where == "learn" { page_learn(id, page) }
  else if where == "learn/ai" or where == "ai" { page_ai(id, page) }
  else if where == "builder" { page_builder(id, page) }
  else if where == "passwords" { page_passwords(id, page) }
  else if startswith(where, "page/") { page_user(id, page, slice(where, 5)) }
  else if where == "store" { page_store(id, page) }
  else if where == "store/publish" { page_publish(id, page) }
  else if startswith(where, "store/") { page_store_play(id, page, slice(where, 6)) }
  else if where == "spaceflight" { page_example(id, page, "spaceflight", "Spaceflight Sim") }
  else if where == "script" { if tabs[str(id)].title == "New tab" { set_tab_title(id, "Script page") } }
  else {
    set_tab_title(id, "Not found")
    let c = col(page, "list-page")
    heading(c, "No such Kompass page: " + url, "page-title")
    link(c, "Go home", fn() { go(HOME) })
  }
}


# ---------------------------------------------------------- Google sign-in note
fn google_note(on) {
  clear(gnote)
  show(gnote, on)
  if not on { return }
  label(gnote, "Google may refuse sign-in in browsers it doesn't recognise (\"This browser or app may not be secure\"). Kompass sends a standard Chrome user agent; if Google still says no, try again later, use a passkey / phone prompt, or sign in to that service in another browser.", "")
  button(gnote, "×", fn() { show(gnote, false) }, "pill ghost")
}

# ---------------------------------------------------------- 🔑 password manager (save bar)
# Passwords never reach KampfScript: we only see the site, the username and an offer id.
on_password_offer(fn(o) {
  clear(pwbar)
  show(pwbar, true)
  let who = o.username
  if who == "" { who = "(no username)" }
  let verb = "Save"
  if o.update { verb = "Update" }
  label(pwbar, "🔑 " + verb + " password for " + who + " on " + domain(o.origin) + "?", "")
  if o.locked {
    let m = pw_input(pwbar, "master password")
    button(pwbar, "Unlock & save", fn() {
      let r = pw_unlock(m)
      if not r.ok { status_text(r.error); return }
      pw_offer(o.id, "save")
      show(pwbar, false)
      status_text("Password saved in your Kompass vault")
    }, "pill")
  } else {
    button(pwbar, verb, fn() { let r = pw_offer(o.id, "save"); show(pwbar, false); if r.ok { status_text("Password saved in your Kompass vault") } else { status_text(r.error) } }, "pill")
  }
  button(pwbar, "Not now", fn() { pw_offer(o.id, "never"); show(pwbar, false) }, "pill ghost")
  button(pwbar, "Passwords…", fn() { open_page("kompass://passwords") }, "pill ghost")
})

# ---------------------------------------------------------- auto-update
# The native updater checks GitHub on launch and every 4 hours, downloads + verifies the new
# Kompass exe in the background and tells us here. Errors / offline stay silent.
let upd_dismissed = ""
fn update_text(st) {
  if st.status == "checking" { return "Checking for updates…" }
  if st.status == "downloading" { return "Downloading Kompass " + st.latest + "… " + st.progress + "%" }
  if st.status == "ready" { return "Kompass " + st.latest + " is ready — restart to update" }
  if st.status == "installing" { return "Installing update…" }
  if st.status == "uptodate" { return "You're up to date" }
  if st.status == "available" { return "Kompass " + st.latest + " is available" }
  if st.status == "error" { return "Couldn't check for updates: " + st.error }
  return "Auto-update is " + (st.autoUpdate and "on" or "off")
}
fn draw_update_bar(st) {
  clear(updbar)
  let want = (st.status == "ready" or st.status == "available") and upd_dismissed != st.latest
  show(updbar, want)
  if not want { return }
  label(updbar, "⬆", "upd-icon")
  if st.status == "ready" {
    label(updbar, "Update ready — Kompass " + st.latest + " installs when you restart", "upd-text")
    button(updbar, "Restart to update", fn() { update_install() }, "pill")
  } else {
    label(updbar, "Kompass " + st.latest + " is available", "upd-text")
    button(updbar, "Download", fn() { update_install() }, "pill")
  }
  button(updbar, "Later", fn() { upd_dismissed = st.latest; show(updbar, false) }, "pill ghost")
}
let upd_listeners = []
on_update(fn(st) {
  draw_update_bar(st)
  for f in upd_listeners { f(st) }
})
draw_update_bar(update_state())

fn page_passwords(id, page) {
  set_tab_title(id, "Passwords")
  let c = col(page, "pw-page")
  label(c, "KOMPASS PASSWORDS", "eyebrow")
  heading(c, "🔑 Password manager", "learn-title")
  let st = pw_status()
  if not st.unlocked {
    let card = col(c, "pw-lockcard")
    if st.exists {
      label(card, "Your vault is locked. Enter your master password.", "lesson-text")
    } else {
      label(card, "Create a master password (8+ characters). It encrypts your vault (scrypt + AES-256-GCM) and cannot be recovered — don't forget it.", "lesson-text")
    }
    let m = pw_input(card, "master password")
    focus(m)
    let err = label(card, "", "out-err")
    let unlock = fn() { let r = pw_unlock(m); if r.ok { tab_reload(id) } else { settext(err, r.error) } }
    if st.exists { button(card, "Unlock", unlock, "pill") } else { button(card, "Create vault", unlock, "pill") }
    label(card, "The vault is the file vault.kpv in your Kompass data folder. It locks itself after 5 minutes without use.", "muted")
    return
  }
  let top = row(c, "chips")
  let q = textbox(top, "Search sites and usernames", fn(t) { draw(t) }, "set-input")
  button(top, "＋ Add", fn() { form(nil, "", "") }, "pill")
  button(top, "🔒 Lock", fn() { pw_lock(); tab_reload(id) }, "pill ghost")
  let tools2 = row(c, "chips")
  let xpw = pw_input(tools2, "export/import password (encrypted)")
  let msg = label(c, "", "muted")
  button(tools2, "⇩ Export CSV", fn() { if confirm("A CSV file stores passwords in PLAIN TEXT. Export anyway?") { let r = pw_export("csv"); say_r(r, "Exported") } }, "pill ghost")
  button(tools2, "⇩ Export encrypted", fn() { say_r(pw_export("encrypted", xpw), "Exported (encrypted)") }, "pill ghost")
  button(tools2, "⇧ Import CSV / .kpx", fn() { say_r(pw_import(xpw), "Imported"); draw(gettext(q)) }, "pill ghost")
  let editor = col(c, "")
  let list_ = col(c, "")
  fn say_r(r, what) {
    if r.ok {
      let extra = ""
      if r.count != nil { extra = " · " + str(r.count) + " logins" }
      if r.path != nil { extra = extra + " · " + r.path }
      settext(msg, "✔ " + what + extra)
    } else { settext(msg, "✖ " + r.error) }
  }
  fn form(pid, site, user) {
    clear(editor)
    let f = row(editor, "pw-form")
    let s_ = textbox(f, "https://site.com", nil, "set-input")
    settext(s_, site)
    let u_ = textbox(f, "username", nil, "set-input")
    settext(u_, user)
    let p_ = pw_input(f, "password (leave empty to keep)")
    button(f, "🎲 Generate", fn() { pw_generate_into(p_, 20) }, "pill ghost")
    button(f, "Save", fn() {
      let r = pw_save(pid, gettext(s_), gettext(u_), p_)
      if r.ok { clear(editor); draw(gettext(q)); settext(msg, "✔ Saved") } else { settext(msg, "✖ " + r.error) }
    }, "pill")
    button(f, "Cancel", fn() { clear(editor) }, "pill ghost")
  }
  fn draw(filter_) {
    clear(list_)
    let items = pw_list(filter_)
    label(list_, str(len(items)) + " saved logins · click ••• to reveal (hides again after 20 s)", "muted")
    for it in items {
      let item = it
      let r = row(list_, "pw-row")
      label(r, domain(item.origin), "pw-site")
      label(r, item.username, "pw-user")
      pw_reveal(r, item.id)
      button(r, "⧉", fn() { pw_copy(item.id); settext(msg, "Password copied (clipboard clears in 30 s)") }, "pill ghost")
      button(r, "✎", fn() { form(item.id, item.origin, item.username) }, "pill ghost")
      button(r, "🗑", fn() { if confirm("Delete the login for " + item.username + " on " + domain(item.origin) + "?") { pw_delete(item.id); draw(gettext(q)) } }, "pill ghost")
    }
  }
  draw("")
}
on_vault_lock(fn() { if current != nil and tab_url(current) == "kompass://passwords" { tab_reload(current) } })

# ---------------------------------------------------------- double right-click quick menu
let QUICK = [
  ["‹", "Back", fn() { tab_back(current) }],
  ["›", "Forward", fn() { tab_forward(current) }],
  ["↻", "Reload", fn() { tab_reload(current) }],
  ["+", "New tab", fn() { new_tab(settings.home) }],
  ["×", "Close tab", fn() { close_tab(current) }],
  ["☆", "Bookmark", fn() { toggle_bookmark() }],
  ["⧉", "Copy URL", fn() { copy_text(tab_url(current)); status_text("Copied " + tab_url(current)) }],
  ["{ }", "DevTools", fn() { ks_devtools(true) }],
  ["⚙", "Settings", fn() { open_page("kompass://settings") }],
  ["📘", "Learn", fn() { open_page("kompass://learn") }],
  ["🔑", "Passwords", fn() { open_page("kompass://passwords") }],
  ["G", "My page", fn() { open_page("kompass://builder") }]
]
fn quick_menu(x, y, on_web, link_url) {
  let m = popup(x, y, "quick-menu")
  let h = row(m, "qm-head")
  box(h, "compass-mark")
  label(h, "Kompass quick menu", "")
  let g = box(m, "qm-grid")
  for q in QUICK {
    let b = button(g, "", q[2], "qm-btn")
    label(b, q[0], "qm-ico")
    label(b, q[1], "")
  }
  if link_url != "" {
    let lu = link_url
    button(m, "Open link in new tab", fn() { new_tab(lu) }, "pill ghost")
  }
}
on_double_right_click(fn(x, y, on_web, link_url) { quick_menu(x, y, on_web, link_url) })

# ---------------------------------------------------------- kompass://page/<name> — your own pages (scripts/<name>.ks)
fn page_user(id, page, name) {
  set_tab_title(id, name)
  let code = read_script(name)
  if code == "" {
    let c = col(page, "list-page")
    heading(c, "No page named \"" + name + "\"", "page-title")
    label(c, "Create scripts/" + name + ".ks in the ⚡ editor (📄 New page), or try kompass://builder.", "muted")
    button(c, "⚡ Open editor", fn() { open_editor() }, "pill")
    return
  }
  let stage = box(page, "custom-stage")
  let r = run_page(code, stage, page_handlers(id, false))
  if not r.ok {
    let warn = row(page, "custom-error")
    label(warn, "kompass://page/" + name + ": " + r.error, "out-err")
    button(warn, "✎ Edit " + name + ".ks", fn() { open_editor(name + ".ks") }, "pill")
  }
}

# ---------------------------------------------------------- kompass://spaceflight — bundled example apps (resources/<name>.ks)
fn page_example(id, page, name, title) {
  set_tab_title(id, title)
  let stage = box(page, "app-stage")
  let r = run_page(read_resource(name + ".ks"), stage, page_handlers(id, false))
  if not r.ok {
    let warn = row(page, "custom-error")
    label(warn, "kompass://" + name + ": " + r.error, "out-err")
  }
}

# ---------------------------------------------------------- 🛒 kompass://store — the Kugel Store
# The catalog is the public GitHub repo KampfGuy/kugel-store (index.json + entries/<id>.ks).
# Every entry runs with run_page(): an isolated sandbox interpreter that can only draw into its stage.
let pub_draft = nil
fn page_store(id, page) {
  set_tab_title(id, "Kugel Store")
  let c = col(page, "store-page")
  let head = row(c, "store-head")
  heading(head, "🛒 Kugel Store", "store-title")
  label(head, "Games & apps made with KampfScript — every one runs in a sandbox", "muted")
  let acts = row(c, "store-acts")
  button(acts, "🌍 Publish yours", fn() { go("kompass://store/publish") }, "pill")
  button(acts, "G Make one in the builder", fn() { go("kompass://builder") }, "pill ghost")
  let find_ = textbox(acts, "Search the store", nil, "store-search")
  let info = label(c, "Loading the store…", "muted")
  let grid = row(c, "store-grid")
  let items = []
  fn draw(q) {
    clear(grid)
    let n = 0
    for e in items {
      let hay = lower(e.title + " " + e.author + " " + e.description + " " + join(e.tags, " "))
      if q != "" and not contains(hay, lower(q)) { continue }
      n += 1
      let ee = e
      let card = col(grid, "store-card")
      label(card, e.icon, "store-icon")
      label(card, e.title, "store-name")
      label(card, "by " + e.author, "store-author")
      label(card, e.description, "store-desc")
      button(card, "▶ Play", fn() { go("kompass://store/" + ee.id) }, "pill store-play")
    }
    if n == 0 { label(grid, "Nothing found", "muted") }
  }
  on_input(find_, fn(t) { draw(trim(t)) }, 150)
  let r = store_index()
  if not r.ok { settext(info, "✖ " + r.error); return }
  items = r.entries
  let src_note = ""
  if r.source != "online" { src_note = " (offline copy — could not reach GitHub)" }
  settext(info, str(len(items)) + " programs" + src_note)
  draw("")
}

fn page_store_play(id, page, sid) {
  set_tab_title(id, "Kugel Store: " + sid)
  let r = store_code(sid)
  if not r.ok {
    let c = col(page, "list-page")
    heading(c, "Could not load " + sid, "page-title")
    label(c, r.error, "out-err")
    link(c, "‹ Back to the store", fn() { go("kompass://store") })
    return
  }
  let stage = box(page, "app-stage")
  let back = link(page, "‹ Store", fn() { go("kompass://store") }, "store-back")
  let res = run_page(r.code, stage, page_handlers(id, false), "store-" + sid)
  if not res.ok {
    let warn = row(page, "custom-error")
    label(warn, sid + ": " + res.error, "out-err")
  }
}

fn page_publish(id, page) {
  set_tab_title(id, "Publish to the Kugel Store")
  let d = publish_draft()
  if d == nil { d = pub_draft }
  pub_draft = nil
  if d == nil { d = {title: "", code: ""} }
  let c = col(page, "store-page")
  heading(c, "🌍 Publish to the Kugel Store", "store-title")
  label(c, "Kompass opens a ready-made GitHub page in your browser with your code in it. Sign in to GitHub there (free) and press “Submit new issue”. After a quick review it shows up in kompass://store for everyone. Kompass never needs or stores a password or token.", "store-help")
  let f = col(c, "store-form")
  label(f, "Title", "store-lbl")
  let t = textbox(f, "My cool game", nil, "store-in")
  settext(t, d.title)
  label(f, "Your name (shown on the card)", "store-lbl")
  let a = textbox(f, "KampfFan", nil, "store-in")
  if settings.store_author != nil { settext(a, settings.store_author) }
  label(f, "Description", "store-lbl")
  let ds = textbox(f, "What is it? How do you play?", nil, "store-in")
  label(f, "KampfScript code", "store-lbl")
  let code = codebox(f, d.code, "store-code")
  let msg = label(f, "", "store-msg")
  let r_ = row(f)
  button(r_, "🌍 Publish", fn() {
    let src = gettext(code)
    if trim(gettext(t)) == "" { settext(msg, "Give it a title first"); return }
    if trim(src) == "" { settext(msg, "Paste or write some KampfScript first"); return }
    settings.store_author = trim(gettext(a))
    save_settings()
    let r = store_publish(trim(gettext(t)), trim(gettext(ds)), trim(gettext(a)), src)
    if r.copied { settext(msg, "✔ Opened GitHub in your browser. Your code is big, so it was copied — click in the Code box there and press Ctrl+V, then Submit.") }
    else { settext(msg, "✔ Opened GitHub in your browser with everything filled in — just press “Submit new issue”.") }
  }, "pill")
  button(r_, "‹ Back to the store", fn() { go("kompass://store") }, "pill ghost")
}

# ---------------------------------------------------------- pages made by ⚡ editor scripts
# A script run in the editor can call new_page("Title") to get a fresh kompass://script tab to draw into.
fn page_for_script(title) {
  let id = new_tab("kompass://script")
  set_tab_title(id, title)
  let p = col(tab_page(id), "script-page")
  return p
}

# ---------------------------------------------------------- keyboard shortcuts
on_key("ctrl+t", fn() { new_tab(settings.home) })
on_key("ctrl+w", fn() { close_tab(current) })
on_key("ctrl+tab", fn() { next_tab() })
on_key("ctrl+l", fn() { focus(address) })
on_key("ctrl+r", fn() { tab_reload(current) })
on_key("f5", fn() { tab_reload(current) })
on_key("alt+arrowleft", fn() { tab_back(current) })
on_key("alt+arrowright", fn() { tab_forward(current) })
on_key("ctrl+d", fn() { toggle_bookmark() })
on_key("ctrl+h", fn() { new_tab("kompass://history") })
on_key("ctrl+y", fn() { new_tab("https://www.youtube.com/") })
on_key("ctrl+,", fn() { open_page("kompass://settings") })
on_key("ctrl+g", fn() { open_page("kompass://builder") })
on_key("ctrl+shift+p", fn() { open_page("kompass://passwords") })
on_key("f1", fn() { open_page("kompass://learn") })
on_key("f12", fn() { if settings.devtools { ks_devtools() } })
on_key("ctrl+shift+i", fn() { if settings.devtools { ks_devtools() } })
on_key("ctrl+shift+j", fn() { tab_devtools(current) })

# ---------------------------------------------------------- start!
show(dt_btn, settings.devtools)
draw_bookmarks()
new_tab(settings.home)
print("Kompass " + VERSION + " started (" + len(bookmarks) + " bookmarks, " + len(history) + " history entries, theme " + settings.theme + ")")
