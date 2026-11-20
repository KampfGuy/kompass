# ============================================================================
#  🔷 Kugel Prism — Kugel Store app for Kompass 1.8+ (written in KampfScript)
#  Slides and presentations: themes, text, shapes and images, fullscreen presenting, .pptx import / export and PNG export.
#  Built by tools/build-apps.js from kugel-apps/work/kit.ks, kugel-apps/work/prism.ks
# ============================================================================

# ---------------------------------------------------------------- Kugel Work kit (shared by Kugel Notes, Lattice and Prism)
# Small helpers + the light "Kugel Work" look (CSS classes .kw-* in Kompass 1.8). Everything stays on this PC.
let KW_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
fn kw_civil(z) {
  z = z + 719468
  let era = floor(z / 146097)
  let doe = z - era * 146097
  let yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  let mp = floor((5 * doy + 2) / 153)
  let d = doy - floor((153 * mp + 2) / 5) + 1
  let m = mp + 3
  if mp >= 10 { m = mp - 9 }
  if m <= 2 { y += 1 }
  return {y: y, m: m, d: d}
}
fn kw_date(ms) { let c = kw_civil(floor(ms / 86400000)); return KW_MONTHS[c.m - 1] + " " + str(c.d) + ", " + str(c.y) }
fn kw_iso(ms) { let c = kw_civil(floor(ms / 86400000)); let m = str(c.m); let d = str(c.d); if c.m < 10 { m = "0" + m }; if c.d < 10 { d = "0" + d }; return str(c.y) + "-" + m + "-" + d }
fn kw_id() { return str(time()) + "-" + str(random(1000, 9999)) }
fn kw_esc(s) { return replace(replace(replace(replace(str(s), "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), "\"", "&quot;") }
fn kw_unesc(s) { return replace(replace(replace(replace(replace(str(s), "&lt;", "<"), "&gt;", ">"), "&quot;", "\""), "&apos;", "'"), "&amp;", "&") }
fn kw_btn(parent, text, f, cls) { let c = "kw-btn"; if cls != nil { c = c + " " + cls }; return button(parent, text, f, c) }
fn kw_tool(parent, text, tip, f) { let b = button(parent, text, f, "kw-tool"); settip(b, tip); return b }
fn kw_sep(parent) { return box(parent, "kw-sep") }
fn kw_space(parent) { return box(parent, "kw-space") }
fn kw_toast(root, text) { let t = label(root, text, "kw-toast"); after(2600, fn() { destroy(t) }); return t }
fn kw_safe_name(s) {
  let out = ""
  for ch in split(trim(s), "") { if contains("\\/:*?\"<>|", ch) { out = out + "_" } else { out = out + ch } }
  if out == "" { out = "Untitled" }
  return substr(out, 0, 60)
}
# a simple in-app dialog: returns {box, close}
fn kw_dialog(root, title) {
  let shade = box(root, "kw-shade")
  let d = col(shade, "kw-dialog")
  let h = row(d, "kw-dhead")
  label(h, title, "kw-dtitle")
  kw_space(h)
  button(h, "✕", fn() { destroy(shade) }, "kw-x")
  return {box: d, close: fn() { destroy(shade) }}
}
# stable merge sort with a compare fn(a, b) -> negative / 0 / positive
fn kw_sort(l, cmp) {
  if len(l) <= 1 { return slice(l, 0) }
  let mid = floor(len(l) / 2)
  let a = kw_sort(slice(l, 0, mid), cmp)
  let b = kw_sort(slice(l, mid), cmp)
  let out = []
  let i = 0
  let j = 0
  while i < len(a) and j < len(b) { if cmp(b[j], a[i]) < 0 { push(out, b[j]); j += 1 } else { push(out, a[i]); i += 1 } }
  while i < len(a) { push(out, a[i]); i += 1 }
  while j < len(b) { push(out, b[j]); j += 1 }
  return out
}

# ---------------------------------------------------------------- Kugel Prism
# Slides like Google Slides / PowerPoint: themes, layouts, text boxes with bullets, shapes, pictures,
# speaker notes, present full screen. Opens and saves PowerPoint .pptx, saves .kprism, exports a slide as PNG.
# Everything stays on this PC.
let SW = 960
let SH = 540
let THEMES = [
  {name: "Kugel Light", bg: "#ffffff", title: "#1d2129", text: "#3a4150", accent: "#2563eb", font: "Segoe UI", band: "#eef2fb"},
  {name: "Kugel Dark", bg: "#1d2027", title: "#ffffff", text: "#cfd3dc", accent: "#ff8c1a", font: "Segoe UI", band: "#272b34"},
  {name: "Ocean", bg: "#0f3d5e", title: "#ffffff", text: "#d5ecff", accent: "#38bdf8", font: "Verdana", band: "#145079"},
  {name: "Sunset", bg: "#fff4e6", title: "#9a3412", text: "#44403c", accent: "#f97316", font: "Georgia", band: "#ffe4c4"},
  {name: "Forest", bg: "#ecfdf3", title: "#14532d", text: "#1f2937", accent: "#16a34a", font: "Trebuchet MS", band: "#d1fadf"},
  {name: "Royal", bg: "#2e1065", title: "#fde68a", text: "#ede9fe", accent: "#a78bfa", font: "Georgia", band: "#3b1683"}]
let LAYOUTS = ["Title slide", "Title and content", "Section header", "Two columns", "Title only", "Big picture", "Blank"]
let deck = store_get("deck", nil)
let next_id = 1
let cur = 0
let sel = ""
let drag = nil
let undo_stack = []
let redo_stack = []
let dirty = false
let presenting = false
let pres_i = 0

fn nid() { next_id += 1; return "e" + str(next_id) + "-" + str(random(100, 999)) }
fn theme() { for t in THEMES { if t.name == deck.theme { return t } }; return THEMES[0] }
fn slide() { return deck.slides[cur] }
fn el_by_id(id) { for e in slide().els { if e.id == id { return e } }; return nil }
fn text_el(x, y, w, h, text, size, role) { return {id: nid(), k: "text", x: x, y: y, w: w, h: h, text: text, size: size, role: role, color: "", bold: role == "title", italic: false, align: "left", font: "", fill: "", stroke: "", sw: 0, img: "", r: 0} }
fn shape_el(k, x, y, w, h) { return {id: nid(), k: k, x: x, y: y, w: w, h: h, text: "", size: 24, role: "body", color: "", bold: false, italic: false, align: "center", font: "", fill: "", stroke: "", sw: 0, img: "", r: 0} }
fn make_slide(layout) {
  let s = {id: nid(), layout: layout, els: [], bg: "", notes: ""}
  if layout == "Title slide" { push(s.els, text_el(80, 170, 800, 110, "Click to add a title", 54, "title")); s.els[0].align = "center"; push(s.els, text_el(160, 300, 640, 60, "Subtitle", 24, "body")); s.els[1].align = "center" }
  else if layout == "Title and content" { push(s.els, text_el(60, 40, 840, 80, "Slide title", 40, "title")); push(s.els, text_el(60, 140, 840, 340, "- First point\n- Second point\n- Third point", 26, "body")) }
  else if layout == "Section header" { push(s.els, text_el(80, 200, 800, 90, "Section", 50, "title")); push(s.els, text_el(80, 295, 800, 50, "What this part is about", 22, "body")); let b = shape_el("rect", 80, 180, 120, 8); b.role = "accent"; push(s.els, b) }
  else if layout == "Two columns" { push(s.els, text_el(60, 40, 840, 80, "Compare", 40, "title")); push(s.els, text_el(60, 140, 400, 340, "- Left side\n- Point", 24, "body")); push(s.els, text_el(500, 140, 400, 340, "- Right side\n- Point", 24, "body")) }
  else if layout == "Title only" { push(s.els, text_el(60, 40, 840, 80, "Slide title", 40, "title")) }
  else if layout == "Big picture" { push(s.els, text_el(60, 440, 840, 70, "Caption", 30, "title")); let r = shape_el("rect", 60, 40, 840, 380); r.role = "band"; r.text = "Insert ▸ Picture to add a photo"; r.size = 20; push(s.els, r) }
  return s
}
fn new_deck() {
  let d = {name: "My presentation", theme: "Kugel Light", slides: [], media: {}}
  return d
}
fn sample_deck() {
  let d = new_deck()
  deck = d
  let s1 = make_slide("Title slide")
  s1.els[0].text = "Kugel Prism"
  s1.els[1].text = "Slides that stay on your PC"
  s1.notes = "Welcome everyone. Press ▶ Present to show the slides full screen."
  let s2 = make_slide("Title and content")
  s2.els[0].text = "What you can do"
  s2.els[1].text = "- Pick a theme and a layout\n- Add text, shapes and pictures\n- Write speaker notes\n- Present full screen (← → to move)\n- Open and save PowerPoint .pptx files"
  let s3 = make_slide("Two columns")
  s3.els[0].text = "Plan for this week"
  s3.els[1].text = "Monday\n- Finish the deck\n- Send it out"
  s3.els[2].text = "Friday\n- Present it\n- Celebrate"
  let c = shape_el("ellipse", 800, 30, 110, 110)
  c.role = "accent"
  c.text = "★"
  c.size = 40
  c.color = "#ffffff"
  push(s3.els, c)
  d.slides = [s1, s2, s3]
  return d
}
if deck == nil or type(deck) != "map" or not has(deck, "slides") or len(deck.slides) == 0 { deck = sample_deck() }
if not has(deck, "media") { deck.media = {} }

# ---- undo (snapshots of the deck without pictures; pictures live in deck.media and are never removed during a session)
fn snap() { return json({name: deck.name, theme: deck.theme, slides: deck.slides, cur: cur}) }
fn record() { push(undo_stack, snap()); if len(undo_stack) > 50 { remove(undo_stack, 0) }; redo_stack = []; dirty = true }
fn restore(s, other) {
  push(other, snap())
  let d = parse_json(s)
  deck.name = d.name
  deck.theme = d.theme
  deck.slides = d.slides
  cur = clamp(d.cur, 0, len(deck.slides) - 1)
  sel = ""
  redraw_all()
}
fn undo() { if len(undo_stack) > 0 { restore(pop(undo_stack), redo_stack) } }
fn redo() { if len(redo_stack) > 0 { restore(pop(redo_stack), undo_stack) } }

# ---- UI
let root = box(body(), "kw kp")
let bar = row(root, "kw-bar")
label(bar, "🔷", "kw-logo")
label(bar, "Kugel Prism", "kw-title")
let name_box = textbox(bar, "Presentation name", nil, "kw-in kp-name")
settext(name_box, deck.name)
on_input(name_box, fn(t) { deck.name = t; dirty = true }, 300)
kw_space(bar)
kw_btn(bar, "New", fn() { new_dialog() }, nil)
kw_btn(bar, "Open", fn() { open_file() }, nil)
kw_btn(bar, "Save", fn() { save_file() }, nil)
kw_btn(bar, "Export", fn() { export_dialog() }, nil)
kw_btn(bar, "▶ Present", fn() { present(cur) }, "accent")
let tb = row(root, "kw-bar kp-tools")
kw_tool(tb, "↶", "Undo (Ctrl+Z)", fn() { undo() })
kw_tool(tb, "↷", "Redo (Ctrl+Y)", fn() { redo() })
kw_sep(tb)
let layout_dd = dropdown(tb, ["+ New slide…"] + LAYOUTS, fn(ch) { if ch != "+ New slide…" { add_slide(ch) }; setvalue(layout_dd, "+ New slide…") }, "kw-dd")
kw_tool(tb, "⧉", "Duplicate slide", fn() { dup_slide() })
kw_tool(tb, "🗑", "Delete slide", fn() { delete_slide() })
kw_sep(tb)
kw_tool(tb, "T Text", "Add a text box", fn() { add_el(text_el(300, 220, 360, 80, "New text", 28, "body")) })
kw_tool(tb, "▭", "Rectangle", fn() { let e = shape_el("rect", 380, 200, 200, 120); e.role = "accent"; add_el(e) })
kw_tool(tb, "▢", "Rounded rectangle", fn() { let e = shape_el("rect", 380, 200, 200, 120); e.role = "accent"; e.r = 18; add_el(e) })
kw_tool(tb, "◯", "Ellipse", fn() { let e = shape_el("ellipse", 400, 190, 160, 160); e.role = "accent"; add_el(e) })
kw_tool(tb, "🖼 Picture", "Insert a picture (PNG, JPG, GIF, WEBP)", fn() { insert_picture() })
kw_sep(tb)
let theme_dd = dropdown(tb, map(THEMES, fn(t) { return "Theme: " + t.name }), fn(ch) { record(); deck.theme = replace(ch, "Theme: ", ""); redraw_all() }, "kw-dd")

let main_ = row(root, "kw-main")
let thumbs = col(main_, "kp-thumbs")
let center_ = col(main_, "kp-center")
let stage_wrap = box(center_, "kp-stage")
let cv = canvas(stage_wrap)
let notes_box = codebox(center_, "", "kp-notes fill")
on_input(notes_box, fn(t) { if slide().notes != t { slide().notes = t; dirty = true } }, 300)
let props = col(main_, "kp-props")
let status = row(root, "kw-status")
let holder = box(root, "kp-holder")

# ---- drawing a slide on any canvas at scale k with offset (dx, dy)
fn el_color(e, t) { if e.color != "" { return e.color }; if e.role == "title" { return t.title }; if e.k != "text" and (e.role == "accent") { return "#ffffff" }; return t.text }
fn el_fill(e, t) { if e.fill == "none" { return "" }; if e.fill != "" { return e.fill }; if e.k == "text" { return "" }; if e.role == "band" { return t.band }; return t.accent }
fn el_font(e, t) { let f = e.font; if f == "" { f = t.font }; let st = ""; if e.bold { st = "bold " }; if e.italic { st = st + "italic " }; return st + f }
fn wrap_lines(text, w, size, font) {
  # -> list of {t, bullet}; lines starting with "- " / "• " are bullets
  let out = []
  for para in split(text, "\n") {
    let bullet = false
    let p = para
    if startswith(p, "- ") or startswith(p, "• ") { bullet = true; p = substr(p, 2) }
    let avail = w
    if bullet { avail = w - size * 1.1 }
    let words = split(p, " ")
    let line = ""
    let first = true
    for wd in words {
      let tryl = wd
      if line != "" { tryl = line + " " + wd }
      if line != "" and text_width(tryl, size, font) > avail { push(out, {t: line, bullet: bullet and first}); first = false; line = wd } else { line = tryl }
    }
    push(out, {t: line, bullet: bullet and first, cont: bullet and not first})
  }
  return out
}
fn paint_el(c, e, t, k, dx, dy) {
  let x = dx + e.x * k
  let y = dy + e.y * k
  let w = e.w * k
  let h = e.h * k
  let f = el_fill(e, t)
  if e.k == "image" {
    if has(deck.media, e.img) { if not draw_image(c, deck.media[e.img], x, y, w, h) { after(120, fn() { render() }) } } else { draw_rect(c, x, y, w, h, "#88888855") }
  } else if e.k == "ellipse" {
    if f != "" { draw_ellipse(c, x + w / 2, y + h / 2, w / 2, h / 2, 0, f) }
    if e.stroke != "" and e.sw > 0 { draw_ellipse(c, x + w / 2, y + h / 2, w / 2, h / 2, 0, e.stroke, e.sw * k) }
  } else {
    if f != "" { if e.r > 0 { draw_round_rect(c, x, y, w, h, e.r * k, f) } else { draw_rect(c, x, y, w, h, f) } }
    if e.stroke != "" and e.sw > 0 { draw_round_rect(c, x, y, w, h, e.r * k, e.stroke, e.sw * k) }
  }
  if e.text != "" and e.k != "image" {
    let size = e.size * k
    let font = el_font(e, t)
    let lines = wrap_lines(e.text, e.w * k - 8 * k, size, font)
    let lh = size * 1.25
    let total = len(lines) * lh
    let ty = y + 4 * k + lh / 2
    if e.k != "text" { ty = y + (h - total) / 2 + lh / 2 }
    let col_ = el_color(e, t)
    for ln in lines {
      let lx = x + 4 * k
      let ind = 0
      if ln.bullet or (has(ln, "cont") and ln.cont) { ind = size * 1.1 }
      if ln.bullet { draw_circle(c, lx + size * 0.35, ty, max(1.5, size * 0.12), el_fill_bullet(e, t)) }
      if e.align == "center" { draw_text(c, x + w / 2 + ind / 2, ty, ln.t, col_, size, "center", font) }
      else if e.align == "right" { draw_text(c, x + w - 4 * k, ty, ln.t, col_, size, "right", font) }
      else { draw_text(c, lx + ind, ty, ln.t, col_, size, "left", font) }
      ty += lh
    }
  }
}
fn el_fill_bullet(e, t) { return t.accent }
fn paint_slide(c, s, k, dx, dy) {
  let t = theme()
  let bgc = s.bg
  if bgc == "" { bgc = t.bg }
  draw_rect(c, dx, dy, SW * k, SH * k, bgc)
  for e in s.els { paint_el(c, e, t, k, dx, dy) }
}

# ---- editor canvas
let z = 1
let sx0 = 0
let sy0 = 0
fn fit() { let s = canvas_size(cv); z = max(0.1, min((s.w - 30) / SW, (s.h - 30) / SH)); sx0 = round((s.w - SW * z) / 2); sy0 = round((s.h - SH * z) / 2) }
fn render() {
  fit()
  draw_clear(cv, "#e9ecf1")
  draw_rect(cv, sx0 + 2, sy0 + 3, SW * z, SH * z, "#00000022")
  paint_slide(cv, slide(), z, sx0, sy0)
  let e = el_by_id(sel)
  if e != nil {
    let x = sx0 + e.x * z
    let y = sy0 + e.y * z
    draw_rect(cv, x, y, e.w * z, e.h * z, "#2563eb", 1.5)
    for hp in handle_pts(e) { draw_rect(cv, hp.x - 4, hp.y - 4, 8, 8, "#ffffff"); draw_rect(cv, hp.x - 4, hp.y - 4, 8, 8, "#2563eb", 1.5) }
  }
  settext_status()
}
fn handle_pts(e) {
  let x = sx0 + e.x * z
  let y = sy0 + e.y * z
  let w = e.w * z
  let h = e.h * z
  return [{x: x, y: y, hx: -1, hy: -1}, {x: x + w, y: y, hx: 1, hy: -1}, {x: x, y: y + h, hx: -1, hy: 1}, {x: x + w, y: y + h, hx: 1, hy: 1},
    {x: x + w / 2, y: y, hx: 0, hy: -1}, {x: x + w / 2, y: y + h, hx: 0, hy: 1}, {x: x, y: y + h / 2, hx: -1, hy: 0}, {x: x + w, y: y + h / 2, hx: 1, hy: 0}]
}
fn settext_status() {
  clear(status)
  label(status, "Slide " + str(cur + 1) + " of " + str(len(deck.slides)) + "  ·  " + theme().name, nil)
  kw_space(status)
  label(status, autosave_note, "kw-dim")
}
let autosave_note = "saved on this PC"
let last_click = {t: 0, id: ""}
on_mouse(cv, fn(e) {
  let px = (e.x - sx0) / z
  let py = (e.y - sy0) / z
  if e.type == "down" {
    let cur_el = el_by_id(sel)
    if cur_el != nil {
      for hp in handle_pts(cur_el) {
        if abs(e.x - hp.x) <= 6 and abs(e.y - hp.y) <= 6 { record(); drag = {kind: "resize", e: cur_el, hx: hp.hx, hy: hp.hy, b: {x: cur_el.x, y: cur_el.y, w: cur_el.w, h: cur_el.h}, p0: {x: px, y: py}, moved: false}; return }
      }
    }
    let hit = nil
    let els = slide().els
    let i = len(els) - 1
    while i >= 0 and hit == nil { let q = els[i]; if px >= q.x and px <= q.x + q.w and py >= q.y and py <= q.y + q.h { hit = q }; i -= 1 }
    if hit == nil { sel = ""; drag = nil; draw_props(); render(); return }
    let dbl = time() - last_click.t < 400 and last_click.id == hit.id
    last_click = {t: time(), id: hit.id}
    sel = hit.id
    record()
    drag = {kind: "move", e: hit, b: {x: hit.x, y: hit.y}, p0: {x: px, y: py}, moved: false}
    draw_props()
    render()
    if dbl and text_input != nil { focus_end_text() }
    return
  }
  if e.type == "move" {
    if drag == nil { return }
    let dx = px - drag.p0.x
    let dy = py - drag.p0.y
    if abs(dx) + abs(dy) > 0.5 { drag.moved = true }
    let q = drag.e
    if drag.kind == "move" { q.x = round(clamp(drag.b.x + dx, 0 - q.w + 10, SW - 10)); q.y = round(clamp(drag.b.y + dy, 0 - q.h + 10, SH - 10)) }
    else {
      let b = drag.b
      if drag.hx == -1 { q.x = round(min(b.x + dx, b.x + b.w - 10)); q.w = round(b.w - (q.x - b.x)) }
      if drag.hx == 1 { q.w = round(max(10, b.w + dx)) }
      if drag.hy == -1 { q.y = round(min(b.y + dy, b.y + b.h - 10)); q.h = round(b.h - (q.y - b.y)) }
      if drag.hy == 1 { q.h = round(max(10, b.h + dy)) }
      if e.shift and q.k != "text" and drag.hx != 0 and drag.hy != 0 { q.h = round(q.w * b.h / b.w) }
    }
    render()
    return
  }
  if e.type == "up" {
    if drag == nil { return }
    if not drag.moved { pop(undo_stack) } else { dirty = true; draw_thumbs() }
    drag = nil
    draw_props()
  }
})

# ---- slide list
fn draw_thumbs() {
  clear(thumbs)
  for i in range(len(deck.slides)) {
    let idx = i
    let r = row(thumbs, "kp-thumb")
    if idx == cur { addstyle(r, "on") }
    label(r, str(i + 1), "kp-tnum")
    let c = canvas(r, 160, 90, "kp-tcv")
    paint_slide(c, deck.slides[i], 160 / SW, 0, 0)
    on_click(r, fn() { go_slide(idx) })
  }
  let add = kw_btn(thumbs, "+ New slide", fn() { add_slide("Title and content") }, "ghost")
}
fn go_slide(i) { cur = clamp(i, 0, len(deck.slides) - 1); sel = ""; settext(notes_box, slide().notes); draw_thumbs(); draw_props(); render() }
fn add_slide(layout) { record(); insert(deck.slides, cur + 1, make_slide(layout)); go_slide(cur + 1) }
fn dup_slide() { record(); let s = parse_json(json(slide())); s.id = nid(); for e in s.els { e.id = nid() }; insert(deck.slides, cur + 1, s); go_slide(cur + 1) }
fn delete_slide() { if len(deck.slides) == 1 { kw_toast(root, "A presentation needs at least one slide"); return }; record(); remove(deck.slides, cur); go_slide(min(cur, len(deck.slides) - 1)) }
fn move_slide(d) { let j = cur + d; if j < 0 or j >= len(deck.slides) { return }; record(); let a = deck.slides[cur]; deck.slides[cur] = deck.slides[j]; deck.slides[j] = a; go_slide(j) }
fn add_el(e) { record(); push(slide().els, e); sel = e.id; draw_props(); draw_thumbs(); render() }
fn delete_el() { if sel == "" { return }; record(); slide().els = filter(slide().els, fn(e) { return e.id != sel }); sel = ""; draw_props(); draw_thumbs(); render() }
fn arrange(front) {
  let e = el_by_id(sel)
  if e == nil { return }
  record()
  let rest = filter(slide().els, fn(q) { return q.id != sel })
  if front { slide().els = rest + [e] } else { slide().els = [e] + rest }
  draw_thumbs()
  render()
}

# ---- properties
let text_input = nil
let prop_rec = false
fn pchange(f) { let e = el_by_id(sel); if e == nil { return }; if not prop_rec { record(); prop_rec = true }; f(e); dirty = true; render(); draw_thumbs_soon() }
let thumbs_pending = false
fn draw_thumbs_soon() { if thumbs_pending { return }; thumbs_pending = true; after(400, fn() { thumbs_pending = false; draw_thumbs() }) }
fn focus_end_text() { focus(text_input); after(40, fn() { let t = gettext(text_input); settext(text_input, ""); text_insert(text_input, t, "") }) }
fn color_pick(parent, title, value, f) {
  let r = row(parent, "kp-prow")
  label(r, title, "kp-plabel")
  let choices = ["Theme", "White", "Black", "Grey", "Blue", "Orange", "Green", "Red", "Purple", "Yellow", "None"]
  let hexes = {"Theme": "", "White": "#ffffff", "Black": "#111111", "Grey": "#6b7280", "Blue": "#2563eb", "Orange": "#f97316", "Green": "#16a34a", "Red": "#dc2626", "Purple": "#7c3aed", "Yellow": "#facc15", "None": "none"}
  let dd = dropdown(r, choices, fn(ch) { f(hexes[ch]) }, "kw-dd")
  for k in choices { if hexes[k] == value { setvalue(dd, k) } }
  let tbx = textbox(r, "#hex", nil, "kw-in kp-hex")
  if value != "" and value != "none" { settext(tbx, value) }
  on_input(tbx, fn(t) { let h = trim(t); if len(h) == 7 and startswith(h, "#") { f(h) } }, 400)
}
fn draw_props() {
  clear(props)
  prop_rec = false
  text_input = nil
  let e = el_by_id(sel)
  if e == nil {
    label(props, "Slide", "kw-h3")
    let r = row(props, "kp-prow")
    label(r, "Layout", "kp-plabel")
    label(r, slide().layout, "kw-dim")
    color_pick(props, "Background", slide().bg, fn(h) { record(); if h == "none" { h = "" }; slide().bg = h; render(); draw_thumbs() })
    let r2 = row(props, "kp-prow")
    kw_btn(r2, "▲ Move up", fn() { move_slide(-1) }, "small")
    kw_btn(r2, "▼ Move down", fn() { move_slide(1) }, "small")
    label(props, "Click something on the slide to change it. Double-click text to type. Drag the corners to resize.", "kw-dim")
    label(props, "Speaker notes go in the box under the slide.", "kw-dim")
    return
  }
  let names = {"text": "Text box", "rect": "Shape", "ellipse": "Ellipse", "image": "Picture"}
  label(props, names[e.k], "kw-h3")
  if e.k != "image" {
    label(props, "Text", "kp-plabel")
    text_input = codebox(props, e.text, "kp-text fill")
    on_input(text_input, fn(t) { pchange(fn(q) { q.text = t }) }, 250)
    label(props, "Start a line with “- ” for a bullet.", "kw-dim")
    let r = row(props, "kp-prow")
    label(r, "Size", "kp-plabel")
    slider(r, 8, 120, e.size, fn(v) { pchange(fn(q) { q.size = round(v) }) }, nil)
    let r2 = row(props, "kp-prow")
    let bb = kw_tool(r2, "B", "Bold", fn() { pchange(fn(q) { q.bold = not q.bold }); togglestyle(bb, "on", e.bold) })
    togglestyle(bb, "on", e.bold)
    let ii = kw_tool(r2, "I", "Italic", fn() { pchange(fn(q) { q.italic = not q.italic }); togglestyle(ii, "on", e.italic) })
    togglestyle(ii, "on", e.italic)
    for a in [["left", "⇤"], ["center", "↔"], ["right", "⇥"]] { let ab = kw_tool(r2, a[1], "Align " + a[0], fn() { pchange(fn(q) { q.align = a[0] }); draw_props() }); togglestyle(ab, "on", e.align == a[0]) }
    let fr = row(props, "kp-prow")
    label(fr, "Font", "kp-plabel")
    let fd = dropdown(fr, ["Theme font", "Segoe UI", "Arial", "Georgia", "Verdana", "Trebuchet MS", "Times New Roman", "Courier New", "Comic Sans MS"], fn(ch) { pchange(fn(q) { if ch == "Theme font" { q.font = "" } else { q.font = ch } }) }, "kw-dd")
    if e.font != "" { setvalue(fd, e.font) }
    color_pick(props, "Text colour", e.color, fn(h) { pchange(fn(q) { if h == "none" { h = "" }; q.color = h }) })
  }
  if e.k != "image" { color_pick(props, "Fill", e.fill, fn(h) { pchange(fn(q) { q.fill = h }) }) }
  if e.k != "text" and e.k != "image" {
    let r3 = row(props, "kp-prow")
    label(r3, "Corners", "kp-plabel")
    slider(r3, 0, 80, e.r, fn(v) { pchange(fn(q) { q.r = round(v) }) }, nil)
  }
  let r4 = row(props, "kp-prow")
  label(r4, "Outline", "kp-plabel")
  slider(r4, 0, 12, e.sw, fn(v) { pchange(fn(q) { q.sw = round(v); if q.stroke == "" { q.stroke = theme().title } }) }, nil)
  let r5 = row(props, "kp-prow")
  kw_btn(r5, "To front", fn() { arrange(true) }, "small")
  kw_btn(r5, "To back", fn() { arrange(false) }, "small")
  kw_btn(r5, "Delete", fn() { delete_el() }, "small danger")
  label(props, "Position " + str(e.x) + ", " + str(e.y) + " · size " + str(e.w) + " × " + str(e.h), "kw-dim")
}
fn redraw_all() {
  settext(name_box, deck.name)
  setvalue(theme_dd, "Theme: " + deck.theme)
  settext(notes_box, slide().notes)
  dirty = true
  draw_thumbs()
  draw_props()
  render()
}

# ---- pictures
fn insert_picture() {
  let f = file_open(["png", "jpg", "jpeg", "gif", "webp"])
  if f == nil { return }
  let info = load_image(f.data)
  if not info.ok { kw_toast(root, "Could not read that picture"); return }
  let id = "img" + str(time()) + str(random(10, 99))
  deck.media[id] = f.data
  let k = min(1, 640 / info.w, 400 / info.h)
  let e = shape_el("image", 0, 0, round(info.w * k), round(info.h * k))
  e.x = round((SW - e.w) / 2)
  e.y = round((SH - e.h) / 2)
  e.img = id
  add_el(e)
}

# ---- present (full screen)
let pres = nil
let pres_cv = nil
let pres_label = nil
fn present(i) {
  presenting = true
  pres_i = i
  sel = ""
  pres = box(root, "kp-present")
  pres_cv = canvas(pres)
  pres_label = label(pres, "", "kp-pcount")
  on_mouse(pres_cv, fn(e) { if e.type == "down" { if e.button == "right" { pres_go(pres_i - 1) } else { pres_go(pres_i + 1) } } })
  fullscreen(true)
  after(80, fn() { pres_draw() })
}
fn pres_draw() {
  if not presenting { return }
  let s = canvas_size(pres_cv)
  let k = min(s.w / SW, s.h / SH)
  draw_clear(pres_cv, "#000000")
  paint_slide(pres_cv, deck.slides[pres_i], k, (s.w - SW * k) / 2, (s.h - SH * k) / 2)
  settext(pres_label, str(pres_i + 1) + " / " + str(len(deck.slides)) + "   ·   ← →  ·  Esc to stop")
}
fn pres_go(i) {
  if i >= len(deck.slides) { stop_present(); return }
  pres_i = clamp(i, 0, len(deck.slides) - 1)
  pres_draw()
}
fn stop_present() {
  if not presenting { return }
  presenting = false
  destroy(pres)
  fullscreen(false)
  go_slide(pres_i)
}
every_ms(600, fn() { if presenting { if not fullscreen() { stop_present() } else { pres_draw() } } })

on_keypress(fn(k) {
  if presenting {
    if k == "right" or k == "space" or k == "enter" or k == "down" { pres_go(pres_i + 1) }
    else if k == "left" or k == "up" or k == "backspace" { pres_go(pres_i - 1) }
    else if k == "escape" { stop_present() }
    return
  }
  if key_down("control") {
    if k == "z" { undo() } else if k == "y" { redo() } else if k == "s" { save_file() } else if k == "d" { dup_slide() }
    return
  }
  if k == "delete" { delete_el() }
  else if k == "f5" { present(0) }
  else if sel == "" and (k == "down" or k == "right") { go_slide(cur + 1) }
  else if sel == "" and (k == "up" or k == "left") { go_slide(cur - 1) }
  else if sel != "" and k == "escape" { sel = ""; draw_props(); render() }
})

# ---- PowerPoint .pptx export
fn emu(v) { return str(round(v * 12700)) }
fn hex6(c) { return upper(substr(c, 1, 6)) }
fn x_esc(s) { return kw_esc(s) }
fn solid(c) { return "<a:solidFill><a:srgbClr val=\"" + hex6(c) + "\"/></a:solidFill>" }
fn sp_xml(e, n, t, rels) {
  let off = "<a:xfrm><a:off x=\"" + emu(e.x) + "\" y=\"" + emu(e.y) + "\"/><a:ext cx=\"" + emu(e.w) + "\" cy=\"" + emu(e.h) + "\"/></a:xfrm>"
  if e.k == "image" {
    if not has(deck.media, e.img) { return "" }
    let rid = "rId" + str(len(rels) + 2)
    push(rels, {rid: rid, img: e.img})
    return "<p:pic><p:nvPicPr><p:cNvPr id=\"" + str(n) + "\" name=\"Picture " + str(n) + "\"/><p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"" + rid + "\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>" + off + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>"
  }
  let geom = "rect"
  let av = "<a:avLst/>"
  if e.k == "ellipse" { geom = "ellipse" }
  if e.k == "rect" and e.r > 0 { geom = "roundRect"; av = "<a:avLst><a:gd name=\"adj\" fmla=\"val " + str(round(clamp(e.r / max(1, min(e.w, e.h)), 0, 0.5) * 100000)) + "\"/></a:avLst>" }
  let f = el_fill(e, t)
  let fill = "<a:noFill/>"
  if f != "" { fill = solid(f) }
  let ln = "<a:ln><a:noFill/></a:ln>"
  if e.stroke != "" and e.sw > 0 { ln = "<a:ln w=\"" + emu(e.sw) + "\">" + solid(e.stroke) + "</a:ln>" }
  let txbox = ""
  if e.k == "text" { txbox = " txBox=\"1\"" }
  let algn = "l"
  if e.align == "center" { algn = "ctr" } else if e.align == "right" { algn = "r" }
  let anchor = "t"
  if e.k != "text" { anchor = "ctr" }
  let fontname = e.font
  if fontname == "" { fontname = t.font }
  let paras = ""
  for para in split(e.text, "\n") {
    let p = para
    let ppr = "<a:pPr algn=\"" + algn + "\"><a:buNone/></a:pPr>"
    if startswith(p, "- ") or startswith(p, "• ") { p = substr(p, 2); ppr = "<a:pPr marL=\"342900\" indent=\"-342900\" algn=\"" + algn + "\"><a:buFont typeface=\"Arial\"/><a:buChar char=\"•\"/></a:pPr>" }
    let b = "0"
    if e.bold { b = "1" }
    let i = "0"
    if e.italic { i = "1" }
    let rpr = "<a:rPr lang=\"en-US\" sz=\"" + str(round(e.size * 100)) + "\" b=\"" + b + "\" i=\"" + i + "\" dirty=\"0\">" + solid(el_color(e, t)) + "<a:latin typeface=\"" + x_esc(fontname) + "\"/></a:rPr>"
    if p == "" { paras = paras + "<a:p>" + ppr + "<a:endParaRPr lang=\"en-US\" sz=\"" + str(round(e.size * 100)) + "\"/></a:p>" }
    else { paras = paras + "<a:p>" + ppr + "<a:r>" + rpr + "<a:t>" + x_esc(p) + "</a:t></a:r></a:p>" }
  }
  return "<p:sp><p:nvSpPr><p:cNvPr id=\"" + str(n) + "\" name=\"Shape " + str(n) + "\"/><p:cNvSpPr" + txbox + "/><p:nvPr/></p:nvSpPr><p:spPr>" + off + "<a:prstGeom prst=\"" + geom + "\">" + av + "</a:prstGeom>" + fill + ln + "</p:spPr><p:txBody><a:bodyPr wrap=\"square\" lIns=\"50800\" tIns=\"50800\" rIns=\"50800\" bIns=\"50800\" anchor=\"" + anchor + "\"><a:normAutofit/></a:bodyPr><a:lstStyle/>" + paras + "</p:txBody></p:sp>"
}
let NS = "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""
let XH = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
let EMPTY_TREE = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
fn media_ext(u) { if startswith(u, "data:image/jpeg") { return "jpeg" }; if startswith(u, "data:image/gif") { return "gif" }; if startswith(u, "data:image/webp") { return "png" }; return "png" }
fn to_pptx() {
  let t = theme()
  let files = {}
  let n = len(deck.slides)
  let ct = XH + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"png\" ContentType=\"image/png\"/><Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/><Default Extension=\"gif\" ContentType=\"image/gif\"/>"
  ct = ct + "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/><Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/><Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/><Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/><Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"
  for i in range(n) { ct = ct + "<Override PartName=\"/ppt/slides/slide" + str(i + 1) + ".xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" }
  files["[Content_Types].xml"] = ct + "</Types>"
  files["_rels/.rels"] = XH + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/></Relationships>"
  files["docProps/core.xml"] = XH + "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><dc:title>" + x_esc(deck.name) + "</dc:title><dc:creator>Kugel Prism</dc:creator></cp:coreProperties>"
  files["docProps/app.xml"] = XH + "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\"><Application>Kugel Prism</Application><Slides>" + str(n) + "</Slides></Properties>"
  let sld_ids = ""
  let prels = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>"
  for i in range(n) { sld_ids = sld_ids + "<p:sldId id=\"" + str(256 + i) + "\" r:id=\"rId" + str(i + 10) + "\"/>"; prels = prels + "<Relationship Id=\"rId" + str(i + 10) + "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide" + str(i + 1) + ".xml\"/>" }
  files["ppt/presentation.xml"] = XH + "<p:presentation " + NS + " saveSubsetFonts=\"1\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst><p:sldIdLst>" + sld_ids + "</p:sldIdLst><p:sldSz cx=\"12192000\" cy=\"6858000\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/><p:defaultTextStyle><a:defPPr><a:defRPr lang=\"en-US\"/></a:defPPr></p:defaultTextStyle></p:presentation>"
  files["ppt/_rels/presentation.xml.rels"] = XH + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" + prels + "</Relationships>"
  files["ppt/slideMasters/slideMaster1.xml"] = XH + "<p:sldMaster " + NS + "><p:cSld><p:bg><p:bgPr>" + solid(t.bg) + "<a:effectLst/></p:bgPr></p:bg><p:spTree>" + EMPTY_TREE + "</p:spTree></p:cSld><p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/><p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle><a:lvl1pPr><a:defRPr sz=\"4400\"/></a:lvl1pPr></p:titleStyle><p:bodyStyle><a:lvl1pPr><a:defRPr sz=\"2400\"/></a:lvl1pPr></p:bodyStyle><p:otherStyle><a:lvl1pPr><a:defRPr sz=\"1800\"/></a:lvl1pPr></p:otherStyle></p:txStyles></p:sldMaster>"
  files["ppt/slideMasters/_rels/slideMaster1.xml.rels"] = XH + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"../theme/theme1.xml\"/></Relationships>"
  files["ppt/slideLayouts/slideLayout1.xml"] = XH + "<p:sldLayout " + NS + " type=\"blank\" preserve=\"1\"><p:cSld name=\"Blank\"><p:spTree>" + EMPTY_TREE + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"
  files["ppt/slideLayouts/_rels/slideLayout1.xml.rels"] = XH + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/></Relationships>"
  files["ppt/theme/theme1.xml"] = theme_xml(t)
  let media_n = 0
  let media_done = {}
  for i in range(n) {
    let s = deck.slides[i]
    let rels = []
    let body_ = ""
    let id = 2
    for e in s.els { body_ = body_ + sp_xml(e, id, t, rels); id += 1 }
    let bgc = s.bg
    if bgc == "" { bgc = t.bg }
    files["ppt/slides/slide" + str(i + 1) + ".xml"] = XH + "<p:sld " + NS + "><p:cSld><p:bg><p:bgPr>" + solid(bgc) + "<a:effectLst/></p:bgPr></p:bg><p:spTree>" + EMPTY_TREE + body_ + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
    let rx = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>"
    for r in rels {
      if not has(media_done, r.img) { media_n += 1; media_done[r.img] = "image" + str(media_n) + "." + media_ext(deck.media[r.img]); files["ppt/media/" + media_done[r.img]] = deck.media[r.img] }
      rx = rx + "<Relationship Id=\"" + r.rid + "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/" + media_done[r.img] + "\"/>"
    }
    files["ppt/slides/_rels/slide" + str(i + 1) + ".xml.rels"] = XH + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" + rx + "</Relationships>"
  }
  return zip_create(files, true)
}
fn theme_xml(t) {
  let c = "<a:dk1><a:srgbClr val=\"" + hex6(t.title) + "\"/></a:dk1><a:lt1><a:srgbClr val=\"" + hex6(t.bg) + "\"/></a:lt1><a:dk2><a:srgbClr val=\"" + hex6(t.text) + "\"/></a:dk2><a:lt2><a:srgbClr val=\"" + hex6(t.band) + "\"/></a:lt2>"
  for i in range(1, 7) { c = c + "<a:accent" + str(i) + "><a:srgbClr val=\"" + hex6(t.accent) + "\"/></a:accent" + str(i) + ">" }
  c = c + "<a:hlink><a:srgbClr val=\"0563C1\"/></a:hlink><a:folHlink><a:srgbClr val=\"954F72\"/></a:folHlink>"
  let fnt = "<a:latin typeface=\"" + x_esc(t.font) + "\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/>"
  let fill3 = "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
  let ln3 = "<a:ln w=\"6350\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln><a:ln w=\"12700\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln><a:ln w=\"19050\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
  let ef3 = "<a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle>"
  return XH + "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"" + x_esc(t.name) + "\"><a:themeElements><a:clrScheme name=\"Kugel\">" + c + "</a:clrScheme><a:fontScheme name=\"Kugel\"><a:majorFont>" + fnt + "</a:majorFont><a:minorFont>" + fnt + "</a:minorFont></a:fontScheme><a:fmtScheme name=\"Kugel\"><a:fillStyleLst>" + fill3 + "</a:fillStyleLst><a:lnStyleLst>" + ln3 + "</a:lnStyleLst><a:effectStyleLst>" + ef3 + "</a:effectStyleLst><a:bgFillStyleLst>" + fill3 + "</a:bgFillStyleLst></a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>"
}

# ---- PowerPoint .pptx import (text boxes, shapes with solid fills, pictures, backgrounds)
fn kids(n, tag) { let out = []; if n == nil { return out }; for c in n.children { if c.tag == tag { push(out, c) } }; return out }
fn kid(n, tag) { if n == nil { return nil }; for c in n.children { if c.tag == tag { return c } }; return nil }
fn find_all(n, tag, out) { if n == nil { return out }; if n.tag == tag { push(out, n) }; for c in n.children { find_all(c, tag, out) }; return out }
fn xattr(n, k, d) { if n != nil and has(n.attrs, k) { return n.attrs[k] }; return d }
fn color_of(n) {
  if n == nil { return "" }
  let s = kid(n, "a:srgbClr")
  if s != nil { return "#" + lower(xattr(s, "val", "000000")) }
  let sc = kid(n, "a:schemeClr")
  if sc != nil { let v = xattr(sc, "val", ""); if v == "bg1" or v == "lt1" { return "#ffffff" }; if v == "tx1" or v == "dk1" { return "#000000" }; return "" }
  return ""
}
fn rels_map(text) {
  let m = {}
  if text == nil { return m }
  let x = xml_parse(text)
  if x == nil { return m }
  for r in x.children { m[xattr(r, "Id", "")] = xattr(r, "Target", "") }
  return m
}
fn resolve(base_dir, target) {
  let parts = split(base_dir + "/" + target, "/")
  let out = []
  for p in parts { if p == ".." { if len(out) > 0 { pop(out) } } else if p != "" and p != "." { push(out, p) } }
  return join(out, "/")
}
fn ph_kind(ph) { let t = xattr(ph, "type", "body"); if t == "ctrTitle" { return "title" }; if t == "subTitle" { return "body" }; return t }
fn ph_xfrm(ph, x) {
  if x == nil { return [] }
  let want = ph_kind(ph)
  let idx = xattr(ph, "idx", "")
  let best = []
  for sp in find_all(x, "p:sp", []) {
    let p2 = find_all(sp, "p:ph", [])
    if len(p2) > 0 {
      let xf = find_all(kid(sp, "p:spPr"), "a:xfrm", [])
      if len(xf) > 0 {
        if idx != "" and xattr(p2[0], "idx", "") == idx { return xf }
        if ph_kind(p2[0]) == want and len(best) == 0 { best = xf }
      }
    }
  }
  return best
}
fn fake_xfrm(ph) {
  # last resort: a sensible title / body area (in EMU)
  let y = 1778000
  let h = 4318000
  if ph_kind(ph) == "title" { y = 508000; h = 1016000 }
  return {tag: "a:xfrm", attrs: {}, text: "", children: [{tag: "a:off", attrs: {x: "762000", y: str(y)}, children: [], text: ""}, {tag: "a:ext", attrs: {cx: "10668000", cy: str(h)}, children: [], text: ""}]}
}
fn import_pptx(data, nm) {
  let z_ = zip_read(data)
  if not has(z_, "ppt/presentation.xml") { kw_toast(root, "That is not a PowerPoint file"); return }
  let pres_ = xml_parse(z_["ppt/presentation.xml"])
  let sz = kid(pres_, "p:sldSz")
  let cx = num(xattr(sz, "cx", "12192000")) or 12192000
  let cy = num(xattr(sz, "cy", "6858000")) or 6858000
  let k = SW / (cx / 12700)
  let ky = SH / (cy / 12700)
  k = min(k, ky)
  let prel = rels_map(z_["ppt/_rels/presentation.xml.rels"])
  let order = []
  for sid in find_all(kid(pres_, "p:sldIdLst"), "p:sldId", []) { let rid = xattr(sid, "r:id", ""); if has(prel, rid) { push(order, resolve("ppt", prel[rid])) } }
  let d = new_deck()
  d.name = replace(nm, ".pptx", "")
  d.theme = "Kugel Light"
  for path in order {
    if has(z_, path) {
      let sx = xml_parse(z_[path])
      let dir = substr(path, 0, len(path) - len(split(path, "/")[len(split(path, "/")) - 1]) - 1)
      let fname = split(path, "/")[len(split(path, "/")) - 1]
      let srels = rels_map(z_[dir + "/_rels/" + fname + ".rels"])
      let s = {id: nid(), layout: "Imported", els: [], bg: "", notes: ""}
      let bgpr = find_all(sx, "p:bgPr", [])
      if len(bgpr) > 0 { let c = color_of(kid(bgpr[0], "a:solidFill")); if c != "" { s.bg = c } }
      if s.bg == "" { s.bg = "#ffffff" }
      # placeholders without their own position take it from the slide layout, then the master
      let lay_path = ""
      for rk in keys(srels) { if contains(srels[rk], "slideLayout") { lay_path = resolve(dir, srels[rk]) } }
      let lay_x = nil
      let mas_x = nil
      if lay_path != "" and has(z_, lay_path) {
        lay_x = xml_parse(z_[lay_path])
        let lfn = split(lay_path, "/")[len(split(lay_path, "/")) - 1]
        let lrels = rels_map(z_[replace(lay_path, lfn, "_rels/" + lfn + ".rels")])
        for rk in keys(lrels) { if contains(lrels[rk], "slideMaster") { let mp = resolve("ppt/slideLayouts", lrels[rk]); if has(z_, mp) { mas_x = xml_parse(z_[mp]) } } }
      }
      for sp in find_all(sx, "p:sp", []) + find_all(sx, "p:pic", []) {
        let xf = find_all(kid(sp, "p:spPr"), "a:xfrm", [])
        let phs = find_all(sp, "p:ph", [])
        if len(xf) == 0 and len(phs) > 0 { xf = ph_xfrm(phs[0], lay_x); if len(xf) == 0 { xf = ph_xfrm(phs[0], mas_x) } }
        if len(xf) == 0 and len(phs) > 0 { xf = [fake_xfrm(phs[0])] }
        if len(xf) > 0 {
          let off = kid(xf[0], "a:off")
          let ext = kid(xf[0], "a:ext")
          let e = shape_el("rect", round((num(xattr(off, "x", "0")) or 0) / 12700 * k), round((num(xattr(off, "y", "0")) or 0) / 12700 * k), round((num(xattr(ext, "cx", "0")) or 0) / 12700 * k), round((num(xattr(ext, "cy", "0")) or 0) / 12700 * k))
          e.role = "plain"
          if sp.tag == "p:pic" {
            let blip = find_all(sp, "a:blip", [])
            if len(blip) > 0 {
              let rid = xattr(blip[0], "r:embed", "")
              if has(srels, rid) { let mp = resolve(dir, srels[rid]); if has(z_, mp) and startswith(z_[mp], "data:image") { let mid = "img" + str(time()) + str(random(100, 999)) + str(len(d.slides)); d.media[mid] = z_[mp]; e.k = "image"; e.img = mid; push(s.els, e) } }
            }
          } else {
            let spPr = kid(sp, "p:spPr")
            let geom = kid(spPr, "a:prstGeom")
            let g = xattr(geom, "prst", "rect")
            if g == "ellipse" { e.k = "ellipse" }
            if g == "roundRect" { e.r = round(min(e.w, e.h) * 0.16) }
            let sf = kid(spPr, "a:solidFill")
            if sf != nil { e.fill = color_of(sf) } else { e.fill = "none" }
            if e.fill == "" { e.fill = "#4472c4" }
            let ln = kid(spPr, "a:ln")
            if ln != nil and kid(ln, "a:solidFill") != nil { e.stroke = color_of(kid(ln, "a:solidFill")); e.sw = max(1, round((num(xattr(ln, "w", "12700")) or 12700) / 12700)) }
            let txb = kid(sp, "p:txBody")
            let lines = []
            let size = 0
            let col_ = ""
            let bold = false
            let algn = ""
            for p in kids(txb, "a:p") {
              let line = ""
              for r in kids(p, "a:r") {
                let tt = kid(r, "a:t")
                if tt != nil { line = line + tt.text }
                let rpr = kid(r, "a:rPr")
                if rpr != nil {
                  let szv = num(xattr(rpr, "sz", ""))
                  if szv != nil and size == 0 { size = szv / 100 }
                  if xattr(rpr, "b", "0") == "1" { bold = true }
                  let c = color_of(kid(rpr, "a:solidFill"))
                  if c != "" and col_ == "" { col_ = c }
                }
              }
              let ppr = kid(p, "a:pPr")
              if ppr != nil { if algn == "" { algn = xattr(ppr, "algn", "") }; if kid(ppr, "a:buChar") != nil and line != "" { line = "- " + line } }
              push(lines, line)
            }
            let ph = find_all(sp, "p:ph", [])
            let is_title = len(ph) > 0 and (xattr(ph[0], "type", "") == "title" or xattr(ph[0], "type", "") == "ctrTitle")
            if size == 0 { if is_title { size = 40 } else { size = 22 } }
            if len(ph) > 0 and xattr(ph[0], "type", "body") == "body" { lines = map(lines, fn(l) { if l != "" and not startswith(l, "- ") { return "- " + l }; return l }) }
            e.text = join(lines, "\n")
            e.size = max(8, round(size * k))
            e.bold = bold or is_title
            e.color = col_
            if col_ == "" { e.color = "#1d2129"; if sf != nil and len(ph) == 0 { e.color = "#ffffff" } }
            if algn == "ctr" { e.align = "center" } else if algn == "r" { e.align = "right" } else { e.align = "left" }
            if sf == nil and xattr(kid(sp, "p:nvSpPr") and kid(kid(sp, "p:nvSpPr"), "p:cNvSpPr"), "txBox", "") == "1" { e.k = "text" }
            if sf == nil and len(ph) > 0 { e.k = "text" }
            if e.k == "text" { e.fill = ""; e.align = e.align }
            if e.fill == "none" and e.k != "text" and e.text != "" and e.sw == 0 { e.k = "text"; e.fill = "" }
            if e.w > 0 and e.h > 0 and (e.text != "" or e.k != "text") { push(s.els, e) }
          }
        }
      }
      push(d.slides, s)
    }
  }
  if len(d.slides) == 0 { kw_toast(root, "No slides found in " + nm); return }
  record()
  deck = d
  cur = 0
  sel = ""
  redraw_all()
  kw_toast(root, "Opened " + nm + " — " + str(len(d.slides)) + " slides")
}

# ---- files
fn save_file() { let r = file_save(kw_safe_name(deck.name) + ".kprism", json(deck)); if r.ok { kw_toast(root, "Saved " + r.name) } }
fn open_file() {
  let f = file_open(["pptx", "kprism"])
  if f == nil { return }
  if f.ext == "pptx" { import_pptx(f.data, f.name); return }
  let d = parse_json(f.text)
  if d == nil or type(d) != "map" or not has(d, "slides") { kw_toast(root, "That is not a Kugel Prism file"); return }
  if not has(d, "media") { d.media = {} }
  record()
  deck = d
  cur = 0
  sel = ""
  redraw_all()
}
fn export_dialog() {
  let d = kw_dialog(root, "Export")
  let r = col(d.box, "kw-drow")
  kw_btn(r, "PowerPoint (.pptx) — opens in PowerPoint, Google Slides, LibreOffice", fn() { d.close(); let res = file_save(kw_safe_name(deck.name) + ".pptx", to_pptx()); if res.ok { kw_toast(root, "Exported " + res.name) } }, "accent")
  kw_btn(r, "This slide as a picture (.png)", fn() {
    d.close()
    let c = canvas(holder, SW * 2, SH * 2)
    paint_slide(c, slide(), 2, 0, 0)
    let res = file_save(kw_safe_name(deck.name) + " slide " + str(cur + 1) + ".png", canvas_data(c))
    destroy(c)
    if res.ok { kw_toast(root, "Exported " + res.name) }
  }, nil)
  kw_btn(r, "Kugel Prism file (.kprism) — keeps everything", fn() { d.close(); save_file() }, nil)
  label(d.box, "Speaker notes are kept in .kprism files; .pptx gets the slides.", "kw-dim")
}
fn new_dialog() {
  let d = kw_dialog(root, "New presentation")
  label(d.box, "Pick a theme:", "kw-dim")
  let g = box(d.box, "kp-themes")
  for t in THEMES {
    let card = col(g, "kp-themecard")
    let c = canvas(card, 160, 90)
    draw_rect(c, 0, 0, 160, 90, t.bg)
    draw_text(c, 12, 34, "Title", t.title, 20, "left", "bold " + t.font)
    draw_rect(c, 12, 52, 50, 4, t.accent)
    draw_text(c, 12, 70, "Text here", t.text, 11, "left", t.font)
    label(card, t.name, "kp-themename")
    on_click(card, fn() {
      d.close()
      record()
      deck = new_deck()
      deck.theme = t.name
      deck.slides = [make_slide("Title slide")]
      cur = 0
      sel = ""
      redraw_all()
    })
  }
}

# ---- autosave (pictures can make a deck too big to keep automatically; then use Save)
every_ms(3000, fn() {
  if not dirty or presenting { return }
  dirty = false
  let j = json(deck)
  if len(j) < 190000 { store_set("deck", deck); autosave_note = "saved on this PC" } else { autosave_note = "too big to keep automatically (pictures) — use Save" }
  settext_status()
})

redraw_all()
let last_w = 0
every_ms(500, fn() { let s = canvas_size(cv); if s.w != last_w { last_w = s.w; render() } })
