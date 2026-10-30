# ==================================================================
#  Kompass — a desktop web browser written in KampfScript.
#
#  The Electron shell only renders pages and offers native built-ins
#  (tab_new, tab_navigate, tab_back, load_data, kugel_search, ...).
#  EVERYTHING you see — tabs, address bar, bookmarks, history, the
#  Kugel start page, shortcuts — is this program. Edit it!
#  (Ctrl+Shift+K -> "★ browser.ks" -> "Save & restart browser")
# ==================================================================

let VERSION = "1.0.0"
let HOME = "kampf://home"

# ---------------------------------------------------------- saved data
let settings = load_data("settings", {engine: "kugel", adblock: true, home: HOME})
if settings.engine == nil { settings.engine = "kugel" }
if settings.home == nil { settings.home = HOME }
adblock(settings.adblock != false)

let bookmarks = load_data("bookmarks", [
  {title: "Kugel", url: "kampf://home"},
  {title: "YouTube", url: "https://www.youtube.com/"},
  {title: "Wikipedia", url: "https://en.wikipedia.org/"},
  {title: "GitHub", url: "https://github.com/"},
  {title: "Example", url: "https://example.com/"}
])
let history = load_data("history", [])

fn save_settings() { save_data("settings", settings) }
fn save_bookmarks() { save_data("bookmarks", bookmarks) }

# ---------------------------------------------------------- the window
let ui = col(body(), "browser")
let strip = row(ui, "tabstrip")
let tabrow = row(strip, "tabs")
button(strip, "+", fn() { new_tab(settings.home) }, "newtab")

let bar = row(ui, "toolbar")
let back_btn = button(bar, "←", fn() { tab_back(current) }, "nav")
let fwd_btn = button(bar, "→", fn() { tab_forward(current) }, "nav")
let reload_btn = button(bar, "⟳", fn() { tab_reload(current) }, "nav")
button(bar, "⌂", fn() { go(settings.home) }, "nav")
let address = textbox(bar, "Search with Kugel or type a URL", fn(t) { go(t) }, "address")
let star = button(bar, "☆", fn() { toggle_bookmark() }, "nav")
button(bar, "▶ YouTube", fn() { go("https://www.youtube.com/") }, "yt")
button(bar, "⚡", fn() { open_editor() }, "nav")
button(bar, "☰", fn() { go("kampf://settings") }, "nav")
settip(back_btn, "Back (Alt+Left)")
settip(fwd_btn, "Forward (Alt+Right)")
settip(star, "Bookmark this page (Ctrl+D)")

let bmbar = row(ui, "bookmarks")
let view = box(ui, "view")
view_area(view)
let status = label(ui, "Ready", "status")

# ---------------------------------------------------------- tabs
let tabs = {}      # id -> {id, title, url, el, text, icon}
let order = []
let current = nil

fn new_tab(url) {
  let id = tab_new()
  let el = row(tabrow, "tab")
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
  if u == HOME { settext(address, "") } else { settext(address, u) }
  enable(back_btn, tab_can_back(current))
  enable(fwd_btn, tab_can_forward(current))
  if is_bookmarked(u) { settext(star, "★") } else { settext(star, "☆") }
  set_window_title(t.title + " — Kompass")
}

# ---------------------------------------------------------- URLs & search
fn looks_like_url(s) {
  if startswith(s, "http://") or startswith(s, "https://") or startswith(s, "kampf:") or startswith(s, "about:") { return true }
  if contains(s, " ") { return false }
  if startswith(s, "localhost") { return true }
  let dot = indexof(s, ".")
  return dot > 0 and dot < len(s) - 2
}

fn search_url(q) {
  if settings.engine == "google" { return "https://www.google.com/search?q=" + url_encode(q) }
  if settings.engine == "duckduckgo" { return "https://duckduckgo.com/?q=" + url_encode(q) }
  return "kampf://search?q=" + url_encode(q)
}

fn fix_url(input_text) {
  let q = trim(input_text)
  if q == "" { return settings.home }
  if not looks_like_url(q) { return search_url(q) }
  if startswith(q, "http://") or startswith(q, "https://") or startswith(q, "kampf:") or startswith(q, "about:") { return q }
  return "https://" + q
}

fn go(input_text) {
  if current == nil { new_tab(input_text); return }
  tab_navigate(current, fix_url(input_text))
}

fn domain(url) {
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
    let l = link(bmbar, "🔖 " + b.title, fn() { go(url) }, "bm")
    settip(l, url)
  }
}

fn add_history(url, title) {
  if startswith(url, "kampf:") { return }
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
    if id == current { if value { settext(reload_btn, "✕"); status_text("Loading " + domain(tab_url(id)) + "…") } else { settext(reload_btn, "⟳"); status_text("Done") } }
  } else if ev == "visit" {
    add_history(value, t.title)
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
  let letters = ["K", "u", "g", "e", "l"]
  let i = 1
  for ch in letters { label(r, ch, "k" + str(i)); i += 1 }
  return r
}

fn quick_link(parent, icon, name, url) {
  let tile = col(parent, "tile")
  label(tile, icon, "tile-icon")
  label(tile, name, "tile-name")
  on_click(tile, fn() { go(url) })
}

fn page_home(id, page) {
  set_tab_title(id, "Kugel")
  let c = col(page, "home")
  kugel_logo(c, "big")
  let box_ = textbox(c, "Search Kugel or type a URL", fn(t) { go(t) }, "home-search")
  focus(box_)
  let r = row(c, "home-buttons")
  button(r, "Kugel Search", fn() { go(gettext(box_)) })
  button(r, "Search Google", fn() { tab_navigate(id, "https://www.google.com/search?q=" + url_encode(gettext(box_))) })
  button(r, "Search DuckDuckGo", fn() { tab_navigate(id, "https://duckduckgo.com/?q=" + url_encode(gettext(box_))) })
  let tiles = row(c, "tiles")
  quick_link(tiles, "▶", "YouTube", "https://www.youtube.com/")
  quick_link(tiles, "📚", "Wikipedia", "https://en.wikipedia.org/")
  quick_link(tiles, "🐙", "GitHub", "https://github.com/")
  quick_link(tiles, "🔎", "Google", "https://www.google.com/")
  quick_link(tiles, "🦆", "DuckDuckGo", "https://duckduckgo.com/")
  quick_link(tiles, "🕘", "History", "kampf://history")
  label(c, "Kompass " + VERSION + " · this page is drawn by browser.ks — press Ctrl+Shift+K to change it", "home-foot")
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
  heading(c, "🕘 History")
  let r = row(c)
  button(r, "Clear history", fn() { history = []; save_data("history", history); tab_reload(id) })
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
  heading(c, "🔖 Bookmarks")
  let i = 0
  for b in bookmarks {
    let u = b.url
    let idx = i
    let line = row(c, "list-item")
    link(line, b.title, fn() { go(u) })
    label(line, u, "muted")
    button(line, "Remove", fn() { remove(bookmarks, idx); save_bookmarks(); draw_bookmarks(); tab_reload(id) })
    i += 1
  }
}

fn page_settings(id, page) {
  set_tab_title(id, "Settings")
  let c = col(page, "list-page")
  heading(c, "☰ Kompass settings")
  label(c, "Default search engine", "section")
  let r = row(c)
  for e in ["kugel", "google", "duckduckgo"] {
    let name = e
    let b = button(r, name, fn() { settings.engine = name; save_settings(); tab_reload(id) })
    togglestyle(b, "selected", settings.engine == name)
  }
  label(c, "Ad & tracker blocker", "section")
  let ab = adblock()
  let r2 = row(c)
  let txt = "off"
  if ab.on { txt = "on" }
  label(r2, "Currently " + txt + " · " + ab.blocked + " requests blocked this session")
  button(r2, "Toggle", fn() { settings.adblock = not adblock().on; adblock(settings.adblock); save_settings(); tab_reload(id) })
  label(c, "Pages", "section")
  let r3 = row(c)
  button(r3, "History", fn() { go("kampf://history") })
  button(r3, "Bookmarks", fn() { go("kampf://bookmarks") })
  button(r3, "About", fn() { go("kampf://about") })
  label(c, "KampfScript", "section")
  let r4 = row(c)
  button(r4, "⚡ Open editor / console", fn() { open_editor() })
  button(r4, "✎ Edit browser.ks", fn() { open_editor("@browser") })
  button(r4, "📁 Open data folder", fn() { open_data_folder() })
  button(r4, "🛠 Page devtools", fn() { app_devtools() })
}

fn page_about(id, page) {
  set_tab_title(id, "About Kompass")
  let c = col(page, "list-page")
  kugel_logo(c, "small")
  heading(c, "Kompass " + VERSION)
  label(c, "A web browser whose whole interface is a KampfScript program (browser.ks).")
  label(c, "Pages are rendered by Chromium in sandboxed webviews. Search by Kugel.")
  link(c, "github.com/KampfGuy/kompass", fn() { go("https://github.com/KampfGuy/kompass") })
}

fn render_internal(id, url) {
  let page = tab_page(id)
  let name = split(split(url, "?")[0], "//")
  let where = name[-1]
  if where == "home" or where == "kampf:" { page_home(id, page) }
  else if where == "search" { page_search(id, page, url) }
  else if where == "history" { page_history(id, page) }
  else if where == "bookmarks" { page_bookmarks(id, page) }
  else if where == "settings" { page_settings(id, page) }
  else if where == "about" { page_about(id, page) }
  else {
    set_tab_title(id, "Not found")
    heading(page, "No such Kompass page: " + url)
  }
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
on_key("ctrl+h", fn() { new_tab("kampf://history") })
on_key("ctrl+y", fn() { new_tab("https://www.youtube.com/") })

# ---------------------------------------------------------- start!
draw_bookmarks()
new_tab(settings.home)
print("Kompass " + VERSION + " started (" + len(bookmarks) + " bookmarks, " + len(history) + " history entries)")
