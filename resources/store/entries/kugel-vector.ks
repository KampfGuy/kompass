# ============================================================================
#  ✒ Kugel Vector — Kugel Store app for Kompass 1.8+ (written in KampfScript)
#  Vector graphics like a small Illustrator: rectangles, ellipses, lines, stars, pen and freehand paths, text, fill / stroke, resize / rotate handles, arrange and align, SVG import, SVG and PNG export.
#  Built by tools/build-apps.js from kugel-apps/design/kit.ks, kugel-apps/design/vector.ks
# ============================================================================

# ---------------------------------------------------------------- Kugel Design kit (shared by Kugel Paint, Motion and Vector)
# Dark "Kugel Design" look (CSS classes .kapp-* / .kd-*), colour picker, dialogs, undo helpers. Everything stays on this PC.
fn kd_btn(parent, text, f, cls) { let c = "kapp-btn"; if cls != nil { c = c + " " + cls }; return button(parent, text, f, c) }
fn kd_tip(parent, text, tip, f) { let b = button(parent, text, f, "kapp-btn kd-ico"); settip(b, tip); return b }
fn kd_sec(parent, text) { return label(parent, text, "kapp-sec") }
fn kd_space(parent) { return box(parent, "kd-space") }
fn kd_toast(root, text) { let t = label(root, text, "kd-toast"); after(2400, fn() { destroy(t) }); return t }
fn kd_safe_name(s) {
  let out = ""
  for ch in split(trim(str(s)), "") { if contains("\\/:*?\"<>|", ch) { out = out + "_" } else { out = out + ch } }
  if out == "" { out = "Untitled" }
  return substr(out, 0, 60)
}
fn kd_dialog(root, title) {
  let shade = box(root, "kd-shade")
  let d = col(shade, "kd-dialog")
  let h = row(d, "kd-dhead")
  label(h, title, "kd-dtitle")
  kd_space(h)
  button(h, "✕", fn() { destroy(shade) }, "kd-x")
  return {box: d, close: fn() { destroy(shade) }}
}
fn kd_field(parent, text, value, cls) {
  let r = row(parent, "kd-frow")
  label(r, text, "kd-flabel")
  let t = textbox(r, "", nil, "kapp-field kd-fin")
  if cls != nil { addstyle(t, cls) }
  settext(t, str(value))
  return t
}
fn kd_num(t, dflt, lo, hi) {
  let s = trim(gettext(t))
  let n = num(s)
  if s == "" or n == nil { return dflt }
  return clamp(n, lo, hi)
}
# ---- colours
fn kd_hex2(n) { let h = "0123456789abcdef"; n = clamp(round(n), 0, 255); return substr(h, floor(n / 16), 1) + substr(h, n % 16, 1) }
fn kd_rgb_hex(r, g, b) { return "#" + kd_hex2(r) + kd_hex2(g) + kd_hex2(b) }
fn kd_hexval(c) { let h = "0123456789abcdef"; return indexof(h, lower(c)) }
fn kd_parse_hex(s) {
  let t = lower(trim(s))
  if startswith(t, "#") { t = substr(t, 1) }
  if len(t) == 3 { t = substr(t, 0, 1) + substr(t, 0, 1) + substr(t, 1, 1) + substr(t, 1, 1) + substr(t, 2, 1) + substr(t, 2, 1) }
  if len(t) != 6 and len(t) != 8 { return nil }
  for ch in split(t, "") { if kd_hexval(ch) < 0 { return nil } }
  return "#" + substr(t, 0, 6)
}
fn kd_rgb_of(hex) {
  let t = substr(hex, 1)
  return {r: kd_hexval(substr(t, 0, 1)) * 16 + kd_hexval(substr(t, 1, 1)), g: kd_hexval(substr(t, 2, 1)) * 16 + kd_hexval(substr(t, 3, 1)), b: kd_hexval(substr(t, 4, 1)) * 16 + kd_hexval(substr(t, 5, 1))}
}
fn kd_hsl_hex(h, s, l) {
  h = ((h % 360) + 360) % 360
  s = clamp(s, 0, 100) / 100
  l = clamp(l, 0, 100) / 100
  let c = (1 - abs(2 * l - 1)) * s
  let x = c * (1 - abs((h / 60) % 2 - 1))
  let m = l - c / 2
  let r = 0
  let g = 0
  let b = 0
  if h < 60 { r = c; g = x } else if h < 120 { r = x; g = c } else if h < 180 { g = c; b = x } else if h < 240 { g = x; b = c } else if h < 300 { r = x; b = c } else { r = c; b = x }
  return kd_rgb_hex((r + m) * 255, (g + m) * 255, (b + m) * 255)
}
fn kd_hex_hsl(hex) {
  let c = kd_rgb_of(hex)
  let r = c.r / 255
  let g = c.g / 255
  let b = c.b / 255
  let mx = max(r, g, b)
  let mn = min(r, g, b)
  let l = (mx + mn) / 2
  let h = 0
  let s = 0
  if mx != mn {
    let d = mx - mn
    if l > 0.5 { s = d / (2 - mx - mn) } else { s = d / (mx + mn) }
    if mx == r { h = (g - b) / d; if g < b { h += 6 } } else if mx == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
    h = h * 60
  }
  return {h: h, s: s * 100, l: l * 100}
}
let KD_PALETTE = ["#000000", "#ffffff", "#7f7f7f", "#c3c3c3", "#880015", "#b97a57", "#ed1c24", "#ffaec9", "#ff7f27", "#ffc90e", "#fff200", "#efe4b0",
  "#22b14c", "#b5e61d", "#00a2e8", "#99d9ea", "#3f48cc", "#7092be", "#a349a4", "#c8bfe7", "#ff8c1a", "#1d2027"]
# colour panel: palette, hue / saturation / lightness sliders, hex box, recent colours. on_pick(hex) when it changes.
fn kd_color_panel(parent, start, on_pick) {
  let st = {hex: start, recent: []}
  let wrap = col(parent, "kd-color")
  let top = row(wrap, "kd-crow")
  let sw = box(top, "kd-swatch big")
  setcolor(sw, start)
  let hexbox = textbox(top, "#rrggbb", nil, "kapp-field kd-hex")
  settext(hexbox, start)
  let grid = box(wrap, "kd-pal")
  let hs = nil
  let ss = nil
  let ls = nil
  let recent_row = row(wrap, "kd-recent")
  fn set_hex(h, from_slider) {
    st.hex = h
    setcolor(sw, h)
    settext(hexbox, h)
    if not from_slider { let q = kd_hex_hsl(h); setvalue(hs, q.h); setvalue(ss, q.s); setvalue(ls, q.l) }
    on_pick(h)
  }
  fn remember(h) {
    let l = [h]
    for x in st.recent { if x != h and len(l) < 10 { push(l, x) } }
    st.recent = l
    clear(recent_row)
    for x in st.recent { let b = button(recent_row, "", fn() { set_hex(x, false) }, "kd-swatch"); setcolor(b, x); settip(b, x) }
  }
  for c in KD_PALETTE { let b = button(grid, "", fn() { set_hex(c, false); remember(c) }, "kd-swatch"); setcolor(b, c); settip(b, c) }
  let q0 = kd_hex_hsl(start)
  label(wrap, "Hue", "kapp-tiny")
  hs = slider(wrap, 0, 359, q0.h, fn(v) { set_hex(kd_hsl_hex(v, getvalue(ss), getvalue(ls)), true) }, "kd-hue")
  label(wrap, "Saturation", "kapp-tiny")
  ss = slider(wrap, 0, 100, q0.s, fn(v) { set_hex(kd_hsl_hex(getvalue(hs), v, getvalue(ls)), true) }, nil)
  label(wrap, "Lightness", "kapp-tiny")
  ls = slider(wrap, 0, 100, q0.l, fn(v) { set_hex(kd_hsl_hex(getvalue(hs), getvalue(ss), v), true) }, nil)
  on_input(hexbox, fn(t) { let h = kd_parse_hex(t); if h != nil and h != st.hex { st.hex = h; setcolor(sw, h); let q = kd_hex_hsl(h); setvalue(hs, q.h); setvalue(ss, q.s); setvalue(ls, q.l); on_pick(h) } }, 300)
  return {get: fn() { return st.hex }, set: fn(h) { set_hex(h, false) }, remember: fn() { remember(st.hex) }}
}
# a hidden holder for off-screen canvases (layers, frames, undo copies)
fn kd_holder(root) { let h = box(root, "kd-holder"); return h }
fn kd_copy_canvas(holder, src, w, h) { let c = canvas(holder, w, h); draw_image(c, src, 0, 0, w, h); return c }
fn kd_checker(holder, w, h) {
  let c = canvas(holder, w, h)
  draw_clear(c, "#ffffff")
  let s = 10
  for y in range(0, ceil(h / s)) {
    for x in range(0, ceil(w / s)) { if (x + y) % 2 == 1 { draw_rect(c, x * s, y * s, s, s, "#e3e5ea") } }
  }
  return c
}

# ---------------------------------------------------------------- Kugel Vector
# Graphic design with shapes that stay sharp: rectangles, ellipses, lines, stars, pen paths, freehand, text.
# Select / move / resize / rotate with handles, align, arrange, duplicate, undo. Export SVG and PNG,
# save .kvector, import SVG (rect, circle, ellipse, line, polyline, polygon, path, text). Everything stays on this PC.
let doc = store_get("doc", nil)
let shapes = []
let AW = 800
let AH = 600
let bg = "#ffffff"
let z = 1
let ox = 0
let oy = 0
let tool = "select"
let selected = []
let undo_stack = []
let redo_stack = []
let clip = []
let next_id = 1
let snap = false
let drag = nil
let pen = nil
let mouse = {x: -1, y: -1}
let st_fill = "#ff8c1a"
let st_stroke = "#1d2027"
let st_sw = 2
let doc_name = store_get("name", "Untitled design")

fn nid() { next_id += 1; return next_id }
fn copy(v) { return parse_json(json(v)) }

# ---- geometry
fn bbox(s) {
  if (s.k == "line" or s.k == "path") and len(s.pts) == 0 { return {x: 0, y: 0, w: 0, h: 0} }
  if s.k == "line" or s.k == "path" {
    let xs = map(s.pts, fn(p) { return p[0] })
    let ys = map(s.pts, fn(p) { return p[1] })
    return {x: min(xs), y: min(ys), w: max(xs) - min(xs), h: max(ys) - min(ys)}
  }
  return {x: s.x, y: s.y, w: s.w, h: s.h}
}
fn center(s) { let b = bbox(s); return {x: b.x + b.w / 2, y: b.y + b.h / 2} }
fn move_shape(s, dx, dy) {
  if s.k == "line" or s.k == "path" { s.pts = map(s.pts, fn(p) { return [p[0] + dx, p[1] + dy] }) } else { s.x += dx; s.y += dy }
}
fn set_bbox(s, nb) {
  if s.k == "line" or s.k == "path" {
    let b = bbox(s)
    let kx = 1
    let ky = 1
    if b.w > 0.001 { kx = nb.w / b.w }
    if b.h > 0.001 { ky = nb.h / b.h }
    s.pts = map(s.pts, fn(p) { return [nb.x + (p[0] - b.x) * kx, nb.y + (p[1] - b.y) * ky] })
  } else { s.x = nb.x; s.y = nb.y; s.w = max(1, nb.w); s.h = max(1, nb.h) }
  if s.k == "text" { s.size = max(4, round(s.h / 1.25)) }
}
fn rotp(p, c, deg) {
  let a = deg * PI / 180
  let dx = p.x - c.x
  let dy = p.y - c.y
  return {x: c.x + dx * cos(a) - dy * sin(a), y: c.y + dx * sin(a) + dy * cos(a)}
}
fn star_pts(cx, cy, r1, r2, n) {
  let out = []
  for i in range(n * 2) {
    let r = r1
    if i % 2 == 1 { r = r2 }
    let a = PI * i / n - PI / 2
    push(out, [cx + cos(a) * r, cy + sin(a) * r])
  }
  return out
}
fn text_box(s) { s.w = max(10, text_width(s.text, s.size, s.font)); s.h = s.size * 1.25 }

# ---- shapes
fn mk(k) { return {id: nid(), k: k, x: 0, y: 0, w: 0, h: 0, pts: [], closed: false, fill: st_fill, stroke: st_stroke, sw: st_sw, op: 1, rot: 0, r: 0, text: "", size: 32, font: "Segoe UI", vis: true, lock: false, name: ""} }
fn shape_name(s) {
  if s.name != "" { return s.name }
  let m = {"rect": "Rectangle", "ellipse": "Ellipse", "line": "Line", "path": "Path", "text": "Text"}
  if s.k == "text" { return "Text “" + substr(s.text, 0, 14) + "”" }
  return m[s.k]
}
fn by_id(id) { for s in shapes { if s.id == id { return s } }; return nil }
fn sel_shapes() { let out = []; for s in shapes { if contains(selected, s.id) { push(out, s) } }; return out }

# ---- undo (snapshots of the shape list; small and quick)
fn snapshot() { return json({shapes: shapes, aw: AW, ah: AH, bg: bg}) }
fn record() {
  push(undo_stack, snapshot())
  if len(undo_stack) > 60 { remove(undo_stack, 0) }
  redo_stack = []
}
fn restore(snap_, other) {
  push(other, snapshot())
  let d = parse_json(snap_)
  shapes = d.shapes
  AW = d.aw
  AH = d.ah
  bg = d.bg
  selected = filter(selected, fn(id) { return by_id(id) != nil })
  changed()
}
fn undo() { if len(undo_stack) > 0 { restore(pop(undo_stack), redo_stack) } }
fn redo() { if len(redo_stack) > 0 { restore(pop(redo_stack), undo_stack) } }
let dirty = false
fn changed() { dirty = true; render(); draw_props(); draw_objects() }

# ---- UI
let root = box(body(), "kapp kd-vector")
let holder = kd_holder(root)
let bar = row(root, "kapp-bar")
label(bar, "✒ Kugel Vector", "kapp-title")
let name_box = textbox(bar, "Name", nil, "kapp-field kd-name")
settext(name_box, doc_name)
on_input(name_box, fn(t) { doc_name = t; store_set("name", t) }, 300)
kd_btn(bar, "New", fn() { new_dialog() }, nil)
kd_btn(bar, "Open", fn() { open_file() }, nil)
settip(kd_btn(bar, "Save", fn() { save_file() }, nil), "Save as .kvector — Ctrl+S")
kd_btn(bar, "Export SVG", fn() { export_svg() }, "go")
kd_btn(bar, "Export PNG", fn() { export_png() }, nil)
kd_tip(bar, "↶", "Undo (Ctrl+Z)", fn() { undo() })
kd_tip(bar, "↷", "Redo (Ctrl+Y)", fn() { redo() })
let opts = row(root, "kapp-bar kd-opts")
let main = row(root, "kapp-main")
let tools_p = col(main, "kapp-panel kd-tools")
let view_wrap = box(main, "kapp-view kd-viewwrap")
let view = canvas(view_wrap)
let right = col(main, "kapp-panel right kd-right")
let status = label(root, "", "kapp-status")
let props = col(right, "kd-props")
kd_sec(right, "Objects")
let objs = col(right, "kd-laylist")

let TOOLS = [["select", "➤", "Select / move / resize / rotate (V)"], ["rect", "▭", "Rectangle (R)"], ["ellipse", "◯", "Ellipse (O)"], ["line", "╱", "Line (L)"],
  ["star", "★", "Star (S)"], ["pen", "✒", "Pen: click points, double-click or Enter to finish (P)"], ["pencil", "✏", "Freehand (F)"], ["text", "T", "Text (T)"], ["hand", "✋", "Pan (H, or middle mouse)"]]
let tool_btns = {}
for t in TOOLS { let b = button(tools_p, t[1], fn() { set_tool(t[0]) }, "kapp-btn kd-tool"); settip(b, t[2]); tool_btns[t[0]] = b }
let star_n = 5
fn set_tool(t) {
  if pen != nil and t != "pen" { finish_pen() }
  tool = t
  for k in keys(tool_btns) { togglestyle(tool_btns[k], "on", k == t) }
  if t != "select" { selected = [] ; draw_props(); draw_objects() }
  draw_opts()
  render()
}
fn draw_opts() {
  clear(opts)
  label(opts, upper(substr(tool, 0, 1)) + substr(tool, 1), "kd-optname")
  if tool == "select" {
    kd_btn(opts, "Duplicate", fn() { duplicate() }, nil)
    kd_btn(opts, "Delete", fn() { delete_sel() }, nil)
    kd_tip(opts, "⇈", "Bring to front", fn() { arrange("front") })
    kd_tip(opts, "↑", "Forward", fn() { arrange("up") })
    kd_tip(opts, "↓", "Backward", fn() { arrange("down") })
    kd_tip(opts, "⇊", "Send to back", fn() { arrange("back") })
    kd_tip(opts, "⇤", "Align left", fn() { align("l") })
    kd_tip(opts, "↔", "Align centre", fn() { align("c") })
    kd_tip(opts, "⇥", "Align right", fn() { align("r") })
    kd_tip(opts, "⤒", "Align top", fn() { align("t") })
    kd_tip(opts, "↕", "Align middle", fn() { align("m") })
    kd_tip(opts, "⤓", "Align bottom", fn() { align("b") })
    kd_tip(opts, "⇋", "Flip horizontally", fn() { flip(true) })
    kd_tip(opts, "⥮", "Flip vertically", fn() { flip(false) })
  }
  if tool == "star" { label(opts, "Points", "kapp-tiny"); slider(opts, 3, 12, star_n, fn(v) { star_n = round(v); settext(sl, str(star_n)) }, "kd-slider"); let sl = label(opts, str(star_n), "kapp-tiny kd-val") }
  if tool == "rect" or tool == "ellipse" or tool == "star" or tool == "line" { label(opts, "Shift = keep proportions / 45°", "kapp-tiny") }
  if tool == "pen" { label(opts, "Click to add points · click the first point to close · double-click / Enter to finish · Esc cancels", "kapp-tiny") }
  checkbox(opts, "Snap 10 px", snap, fn(on) { snap = on }, nil)
  kd_space(opts)
  kd_tip(opts, "−", "Zoom out", fn() { zoom_at(1 / 1.25, -1, -1) })
  label(opts, str(round(z * 100)) + "%", "kapp-tiny kd-zoom")
  kd_tip(opts, "+", "Zoom in", fn() { zoom_at(1.25, -1, -1) })
  kd_btn(opts, "Fit", fn() { fit_view(); draw_opts(); render() }, nil)
}

# ---- properties panel (selection, or the next shape's style when nothing is selected)
let prop_recorded = false
fn prop_change(f) {
  if not prop_recorded { record(); prop_recorded = true }
  for s in sel_shapes() { f(s) }
  dirty = true
  render()
}
fn color_row(parent, title, value, allow_none, on_set) {
  let r = row(parent, "kd-frow")
  label(r, title, "kd-flabel")
  let sw = button(r, "", nil, "kd-swatch")
  let t = textbox(r, "#rrggbb", nil, "kapp-field kd-hex")
  let v = value
  if v == "" { settext(t, "none"); setcolor(sw, "#00000000") } else { settext(t, v); setcolor(sw, v) }
  on_input(t, fn(x) {
    if allow_none and (trim(lower(x)) == "none" or trim(x) == "") { setcolor(sw, "#00000000"); on_set(""); return }
    let h = kd_parse_hex(x)
    if h != nil { setcolor(sw, h); on_set(h) }
  }, 250)
  on_click(sw, fn() { settext(t, picker.get()); setcolor(sw, picker.get()); on_set(picker.get()) })
  settip(sw, "Click: use the colour from the picker below")
  return t
}
fn draw_props() {
  clear(props)
  prop_recorded = false
  let ss = sel_shapes()
  if len(ss) == 0 {
    kd_sec(props, "New shapes")
    color_row(props, "Fill", st_fill, true, fn(h) { st_fill = h })
    color_row(props, "Stroke", st_stroke, true, fn(h) { st_stroke = h })
    let r = row(props, "kd-frow")
    label(r, "Stroke width", "kd-flabel")
    slider(r, 0, 30, st_sw, fn(v) { st_sw = round(v) }, "kd-slider")
    kd_sec(props, "Artboard")
    color_row(props, "Background", bg, true, fn(h) { record(); bg = h; render() })
    label(props, str(AW) + " × " + str(AH) + " px  (New… to change)", "kapp-tiny")
  } else {
    let s = ss[0]
    kd_sec(props, str(len(ss)) + " selected — " + shape_name(s))
    if s.k != "line" { color_row(props, "Fill", s.fill, true, fn(h) { st_fill = h; prop_change(fn(q) { q.fill = h }) }) }
    color_row(props, "Stroke", s.stroke, true, fn(h) { st_stroke = h; prop_change(fn(q) { q.stroke = h }) })
    let r = row(props, "kd-frow")
    label(r, "Stroke width", "kd-flabel")
    slider(r, 0, 30, s.sw, fn(v) { prop_change(fn(q) { q.sw = round(v) }) }, "kd-slider")
    let r2 = row(props, "kd-frow")
    label(r2, "Opacity", "kd-flabel")
    slider(r2, 5, 100, s.op * 100, fn(v) { prop_change(fn(q) { q.op = v / 100 }) }, "kd-slider")
    if s.k == "rect" { let r3 = row(props, "kd-frow"); label(r3, "Corners", "kd-flabel"); slider(r3, 0, 100, s.r, fn(v) { prop_change(fn(q) { q.r = round(v) }) }, "kd-slider") }
    if len(ss) == 1 {
      let b = bbox(s)
      let g = row(props, "kd-xywh")
      let fx = kd_field(g, "X", round(b.x), nil)
      let fy = kd_field(g, "Y", round(b.y), nil)
      let g2 = row(props, "kd-xywh")
      let fw = kd_field(g2, "W", round(b.w), nil)
      let fh = kd_field(g2, "H", round(b.h), nil)
      let frot = kd_field(props, "Rotation °", round(s.rot), nil)
      fn apply_geom() {
        let nb = {x: kd_num(fx, b.x, -9999, 9999), y: kd_num(fy, b.y, -9999, 9999), w: kd_num(fw, b.w, 0, 9999), h: kd_num(fh, b.h, 0, 9999)}
        prop_change(fn(q) { set_bbox(q, nb); q.rot = kd_num(frot, q.rot, -360, 360) })
      }
      for f in [fx, fy, fw, fh, frot] { on_input(f, fn(t) { apply_geom() }, 500) }
      if s.k == "text" {
        let tt = kd_field(props, "Text", s.text, nil)
        on_input(tt, fn(t) { prop_change(fn(q) { q.text = t; text_box(q) }) }, 300)
        let fr = row(props, "kd-frow")
        label(fr, "Font", "kd-flabel")
        let fd = dropdown(fr, FONTS_V, fn(f) { prop_change(fn(q) { q.font = f; text_box(q) }) }, nil)
        setvalue(fd, s.font)
        let fs = kd_field(props, "Size", s.size, nil)
        on_input(fs, fn(t) { prop_change(fn(q) { q.size = kd_num(fs, q.size, 4, 400); text_box(q) }) }, 400)
      }
      let nm = kd_field(props, "Name", s.name, nil)
      on_input(nm, fn(t) { s.name = t; draw_objects() }, 400)
    }
  }
  kd_sec(props, "Colour picker")
  picker_holder = props
  picker = kd_color_panel(props, picker_color, fn(h) { picker_color = h })
}
let FONTS_V = ["Segoe UI", "bold Segoe UI", "Arial", "bold Arial", "Georgia", "italic Georgia", "Times New Roman", "Courier New", "Verdana", "Impact", "Comic Sans MS"]
let picker_color = "#ff8c1a"
let picker_holder = nil
let picker = nil
fn draw_objects() {
  clear(objs)
  let i = len(shapes) - 1
  while i >= 0 {
    let s = shapes[i]
    let r = row(objs, "kd-layer")
    if contains(selected, s.id) { addstyle(r, "on") }
    let eye = "👁"
    if not s.vis { eye = "◌" }
    button(r, eye, fn() { s.vis = not s.vis; dirty = true; render(); draw_objects() }, "kd-eye")
    let lk = "🔓"
    if s.lock { lk = "🔒" }
    button(r, lk, fn() { s.lock = not s.lock; dirty = true; draw_objects() }, "kd-eye")
    label(r, shape_name(s), "kd-layname")
    on_click(r, fn() { set_tool_quiet("select"); if key_down("shift") { toggle_sel(s.id) } else { selected = [s.id] }; draw_props(); draw_objects(); render() })
    i -= 1
  }
  if len(shapes) == 0 { label(objs, "Nothing yet — pick a tool on the left and drag on the artboard.", "kapp-tiny") }
}
fn set_tool_quiet(t) { tool = t; for k in keys(tool_btns) { togglestyle(tool_btns[k], "on", k == t) }; draw_opts() }
fn toggle_sel(id) { if contains(selected, id) { selected = filter(selected, fn(x) { return x != id }) } else { push(selected, id) } }

# ---- view
fn center_view() { let s = canvas_size(view); ox = round((s.w - AW * z) / 2); oy = round((s.h - AH * z) / 2) }
fn fit_view() { let s = canvas_size(view); z = max(0.05, min(1.5, (s.w - 50) / AW, (s.h - 50) / AH)); center_view() }
fn zoom_at(f, x, y) {
  let s = canvas_size(view)
  if x < 0 { x = s.w / 2; y = s.h / 2 }
  let dx = (x - ox) / z
  let dy = (y - oy) / z
  z = clamp(z * f, 0.05, 32)
  ox = round(x - dx * z)
  oy = round(y - dy * z)
  draw_opts()
  render()
}
fn to_doc(x, y) { return {x: (x - ox) / z, y: (y - oy) / z} }
fn to_view(p) { return {x: ox + p.x * z, y: oy + p.y * z} }
fn snapv(v) { if snap { return round(v / 10) * 10 }; return v }

# ---- drawing one shape on any canvas, with a transform k (zoom) and offset (dx, dy)
fn paint_shape(c, s, k, dx, dy) {
  if not s.vis { return }
  let ctr = center(s)
  draw_save(c)
  draw_alpha(c, s.op)
  draw_translate(c, dx + ctr.x * k, dy + ctr.y * k)
  if s.rot != 0 { draw_rotate(c, s.rot * PI / 180) }
  let b = bbox(s)
  let x = (b.x - ctr.x) * k
  let y = (b.y - ctr.y) * k
  let w = b.w * k
  let h = b.h * k
  let lw = s.sw * k
  if s.k == "rect" {
    if s.fill != "" { draw_round_rect(c, x, y, w, h, s.r * k, s.fill) }
    if s.stroke != "" and s.sw > 0 { draw_round_rect(c, x, y, w, h, s.r * k, s.stroke, lw) }
  } else if s.k == "ellipse" {
    if s.fill != "" { draw_ellipse(c, 0, 0, w / 2, h / 2, 0, s.fill) }
    if s.stroke != "" and s.sw > 0 { draw_ellipse(c, 0, 0, w / 2, h / 2, 0, s.stroke, lw) }
  } else if s.k == "line" or s.k == "path" {
    let P = map(s.pts, fn(p) { return [(p[0] - ctr.x) * k, (p[1] - ctr.y) * k] })
    if s.k == "path" and s.closed and s.fill != "" and len(P) > 2 { draw_poly(c, P, s.fill) }
    if s.stroke != "" and s.sw > 0 and len(P) > 1 {
      let L = P
      if s.closed { L = P + [P[0]] }
      draw_lines(c, L, s.stroke, lw)
      if not s.closed { for p in [P[0], P[len(P) - 1]] { draw_circle(c, p[0], p[1], lw / 2, s.stroke) } }
    }
  } else if s.k == "text" {
    if s.fill != "" { draw_text(c, x, 0, s.text, s.fill, s.size * k, "left", s.font) }
  }
  draw_restore(c)
}
fn render() {
  draw_clear(view, "#16181d")
  draw_rect(view, ox + 4, oy + 5, AW * z, AH * z, "#0b0c0f")
  if bg == "" { draw_image(view, checker, ox, oy, AW * z, AH * z) } else { draw_rect(view, ox, oy, AW * z, AH * z, bg) }
  for s in shapes { paint_shape(view, s, z, ox, oy) }
  # selection handles
  let ss = sel_shapes()
  if len(ss) == 1 {
    let s = ss[0]
    let b = bbox(s)
    let c = center(s)
    let corners = map([[b.x, b.y], [b.x + b.w, b.y], [b.x + b.w, b.y + b.h], [b.x, b.y + b.h]], fn(p) { return to_view(rotp({x: p[0], y: p[1]}, c, s.rot)) })
    draw_lines(view, map(corners + [corners[0]], fn(p) { return [p.x, p.y] }), "#2f8cff", 1)
    for hd in handles(s) { draw_rect(view, hd.vx - 4, hd.vy - 4, 8, 8, "#ffffff"); draw_rect(view, hd.vx - 4, hd.vy - 4, 8, 8, "#2f8cff", 1) }
  } else if len(ss) > 1 {
    let g = group_box(ss)
    let a = to_view({x: g.x, y: g.y})
    draw_rect(view, a.x, a.y, g.w * z, g.h * z, "#2f8cff", 1)
    for s in ss { let b = bbox(s); let q = to_view({x: b.x, y: b.y}); draw_rect(view, q.x, q.y, b.w * z, b.h * z, "#2f8cff66", 1) }
  }
  if drag != nil and drag.kind == "marquee" {
    let a = to_view(drag.a)
    let b = to_view(drag.b)
    draw_rect(view, min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y), "#2f8cff22")
    draw_rect(view, min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y), "#2f8cff", 1)
  }
  if pen != nil {
    let P = map(pen.pts, fn(p) { let v = to_view({x: p[0], y: p[1]}); return [v.x, v.y] })
    let m = [mouse.x, mouse.y]
    draw_lines(view, P + [m], "#2f8cff", 1.5)
    for p in P { draw_rect(view, p[0] - 3, p[1] - 3, 6, 6, "#ffffff") }
  }
  draw_status()
}
fn group_box(ss) {
  let x0 = 1000000
  let y0 = 1000000
  let x1 = -1000000
  let y1 = -1000000
  for s in ss { let b = bbox(s); x0 = min(x0, b.x); y0 = min(y0, b.y); x1 = max(x1, b.x + b.w); y1 = max(y1, b.y + b.h) }
  return {x: x0, y: y0, w: x1 - x0, h: y1 - y0}
}
# 8 resize handles (sx, sy in -1..1) + a rotate handle above the shape
fn handles(s) {
  let b = bbox(s)
  let c = center(s)
  let out = []
  for sy in [-1, 0, 1] {
    for sx in [-1, 0, 1] {
      if sx != 0 or sy != 0 {
        let p = rotp({x: c.x + sx * b.w / 2, y: c.y + sy * b.h / 2}, c, s.rot)
        let v = to_view(p)
        push(out, {sx: sx, sy: sy, vx: v.x, vy: v.y})
      }
    }
  }
  let top = rotp({x: c.x, y: c.y - b.h / 2 - 24 / z}, c, s.rot)
  let tv = to_view(top)
  push(out, {sx: 0, sy: 0, rot: true, vx: tv.x, vy: tv.y})
  return out
}
fn hit_shape(p) {
  let i = len(shapes) - 1
  while i >= 0 {
    let s = shapes[i]
    if s.vis {
      let c = center(s)
      let q = rotp(p, c, 0 - s.rot)
      let b = bbox(s)
      let pad = max(4 / z, s.sw / 2)
      if q.x >= b.x - pad and q.x <= b.x + b.w + pad and q.y >= b.y - pad and q.y <= b.y + b.h + pad { return s }
    }
    i -= 1
  }
  return nil
}
fn draw_status() {
  let t = str(AW) + " × " + str(AH) + "   ·   " + str(round(z * 100)) + "%   ·   " + str(len(shapes)) + " objects"
  if len(selected) > 0 { t = t + "   ·   " + str(len(selected)) + " selected" }
  let p = to_doc(mouse.x, mouse.y)
  if mouse.x >= 0 { t = t + "   ·   " + str(round(p.x)) + ", " + str(round(p.y)) }
  settext(status, t)
}

# ---- mouse
let last_click = {t: 0, x: 0, y: 0}
on_mouse(view, fn(e) {
  mouse.x = e.x
  mouse.y = e.y
  let p0 = to_doc(e.x, e.y)
  let p = {x: snapv(p0.x), y: snapv(p0.y)}
  if e.type == "wheel" { if e.dy < 0 { zoom_at(1.15, e.x, e.y) } else { zoom_at(1 / 1.15, e.x, e.y) }; return }
  if e.type == "down" {
    let dbl = time() - last_click.t < 350 and abs(e.x - last_click.x) < 5 and abs(e.y - last_click.y) < 5
    last_click = {t: time(), x: e.x, y: e.y}
    if e.button == "middle" or tool == "hand" { drag = {kind: "pan", x: e.x, y: e.y, ox: ox, oy: oy}; return }
    if tool == "select" { select_down(e, p0, dbl); return }
    if tool == "pen" { pen_click(p, dbl); return }
    if tool == "text" { text_dialog(p, nil); return }
    let s = mk(tool)
    if tool == "star" { s = mk("path"); s.closed = true; s.name = "Star"; s.pts = star_pts(p.x, p.y, 1, 0.5, star_n) }
    if tool == "pencil" { s = mk("path"); s.fill = ""; s.pts = [[p.x, p.y]]; s.name = "Freehand" }
    if tool == "line" { s.pts = [[p.x, p.y], [p.x, p.y]] }
    record()
    s.x = p.x
    s.y = p.y
    push(shapes, s)
    drag = {kind: "create", s: s, a: p}
    render()
    return
  }
  if e.type == "move" {
    if drag == nil { if pen != nil or tool == "select" { render() } else { draw_status() }; return }
    if drag.kind == "pan" { ox = drag.ox + e.x - drag.x; oy = drag.oy + e.y - drag.y; render(); return }
    if drag.kind == "create" { create_move(drag.s, drag.a, p, e.shift) }
    else if drag.kind == "move" { move_drag(p0, e.shift) }
    else if drag.kind == "resize" { resize_drag(p0, e.shift) }
    else if drag.kind == "rotate" { let c = drag.c; let a = atan2(p0.y - c.y, p0.x - c.x) * 180 / PI + 90; if e.shift { a = round(a / 15) * 15 }; drag.s.rot = round(((a % 360) + 360) % 360, 1) }
    else if drag.kind == "marquee" { drag.b = p0 }
    render()
    return
  }
  if e.type == "up" {
    if drag == nil { return }
    let k = drag.kind
    if k == "create" {
      let s = drag.s
      let b = bbox(s)
      if s.k != "path" and b.w < 2 and b.h < 2 and s.k != "line" { pop(shapes); pop(undo_stack) }
      else if s.k == "line" and hypot(s.pts[1][0] - s.pts[0][0], s.pts[1][1] - s.pts[0][1]) < 2 { pop(shapes); pop(undo_stack) }
      else if s.name == "Freehand" and len(s.pts) < 2 { pop(shapes); pop(undo_stack) }
      else { if s.name == "Freehand" { s.pts = simplify(s.pts, 1.2 / z) }; selected = [s.id] }
    }
    if k == "marquee" {
      let x0 = min(drag.a.x, drag.b.x)
      let y0 = min(drag.a.y, drag.b.y)
      let x1 = max(drag.a.x, drag.b.x)
      let y1 = max(drag.a.y, drag.b.y)
      if not drag.add { selected = [] }
      for s in shapes { let b = bbox(s); if s.vis and not s.lock and b.x >= x0 and b.y >= y0 and b.x + b.w <= x1 and b.y + b.h <= y1 { if not contains(selected, s.id) { push(selected, s.id) } } }
    }
    if k == "move" and not drag.moved { pop(undo_stack) }
    drag = nil
    if k != "pan" { if tool != "select" and k == "create" { set_tool_quiet("select") }; changed() }
  }
})
fn create_move(s, a, p, shift) {
  let dx = p.x - a.x
  let dy = p.y - a.y
  if s.name == "Freehand" { let l = s.pts[len(s.pts) - 1]; if hypot(p.x - l[0], p.y - l[1]) >= 2 / z { push(s.pts, [p.x, p.y]) }; return }
  if s.k == "line" {
    let q = p
    if shift { let ang = round(atan2(dy, dx) / (PI / 4)) * (PI / 4); let d = hypot(dx, dy); q = {x: a.x + cos(ang) * d, y: a.y + sin(ang) * d} }
    s.pts = [[a.x, a.y], [q.x, q.y]]
    return
  }
  if shift { let d = max(abs(dx), abs(dy)); dx = sign(dx + 0.0001) * d; dy = sign(dy + 0.0001) * d }
  let b = {x: min(a.x, a.x + dx), y: min(a.y, a.y + dy), w: abs(dx), h: abs(dy)}
  if s.name == "Star" {
    let r1 = max(b.w, b.h) / 2
    s.pts = star_pts(b.x + b.w / 2, b.y + b.h / 2, max(1, r1), max(0.5, r1 * 0.45), star_n)
    if not shift { set_bbox(s, b) }
    return
  }
  s.x = b.x
  s.y = b.y
  s.w = b.w
  s.h = b.h
}
fn simplify(pts, tol) {
  # drop points closer than tol to the straight line between their neighbours
  if len(pts) < 3 { return pts }
  let out = [pts[0]]
  for i in range(1, len(pts) - 1) {
    let a = out[len(out) - 1]
    let b = pts[i]
    let c = pts[i + 1]
    let L = hypot(c[0] - a[0], c[1] - a[1])
    let d = 0
    if L > 0 { d = abs((c[0] - a[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (c[1] - a[1])) / L } else { d = hypot(b[0] - a[0], b[1] - a[1]) }
    if d > tol { push(out, b) }
  }
  push(out, pts[len(pts) - 1])
  return out
}
fn select_down(e, p, dbl) {
  # handles of a single selected shape first
  let ss = sel_shapes()
  if len(ss) == 1 and not ss[0].lock {
    let s = ss[0]
    for hd in handles(s) {
      if abs(e.x - hd.vx) <= 6 and abs(e.y - hd.vy) <= 6 {
        record()
        if has(hd, "rot") { drag = {kind: "rotate", s: s, c: center(s)}; return }
        drag = {kind: "resize", s: s, sx: hd.sx, sy: hd.sy, b0: bbox(s), c0: center(s)}
        return
      }
    }
  }
  let s = hit_shape(p)
  if s != nil and s.lock { s = nil }
  if s == nil { drag = {kind: "marquee", a: p, b: p, add: e.shift}; if not e.shift { selected = [] }; draw_props(); draw_objects(); render(); return }
  if dbl and s.k == "text" { text_dialog(nil, s); return }
  if e.shift { toggle_sel(s.id) } else if not contains(selected, s.id) { selected = [s.id] }
  record()
  drag = {kind: "move", last: p, moved: false, start: p, orig: map(sel_shapes(), fn(q) { return {s: q, b: bbox(q)} })}
  draw_props()
  draw_objects()
  render()
}
fn move_drag(p, shift) {
  let dx = p.x - drag.start.x
  let dy = p.y - drag.start.y
  if shift { if abs(dx) > abs(dy) { dy = 0 } else { dx = 0 } }
  for o in drag.orig {
    let nb = {x: snapv(o.b.x + dx), y: snapv(o.b.y + dy), w: o.b.w, h: o.b.h}
    let cb = bbox(o.s)
    move_shape(o.s, nb.x - cb.x, nb.y - cb.y)
  }
  if abs(dx) + abs(dy) > 0 { drag.moved = true }
}
fn resize_drag(p, shift) {
  let s = drag.s
  let b0 = drag.b0
  let c0 = drag.c0
  let ml = rotp(p, c0, 0 - s.rot)
  let lx = ml.x - c0.x
  let ly = ml.y - c0.y
  let ax = 0 - drag.sx * b0.w / 2
  let ay = 0 - drag.sy * b0.h / 2
  let w = b0.w
  let h = b0.h
  let cx = 0
  let cy = 0
  if drag.sx != 0 { w = max(1, abs(lx - ax)); cx = (lx + ax) / 2 }
  if drag.sy != 0 { h = max(1, abs(ly - ay)); cy = (ly + ay) / 2 }
  if shift and drag.sx != 0 and drag.sy != 0 and b0.w > 0 and b0.h > 0 {
    let k = max(w / b0.w, h / b0.h)
    w = b0.w * k
    h = b0.h * k
    cx = ax + drag.sx * w / 2
    cy = ay + drag.sy * h / 2
  }
  let cw = rotp({x: c0.x + cx, y: c0.y + cy}, c0, s.rot)
  set_bbox(s, {x: cw.x - w / 2, y: cw.y - h / 2, w: w, h: h})
}

# ---- pen
fn pen_click(p, dbl) {
  if pen == nil { record(); pen = {pts: [[p.x, p.y]]}; render(); return }
  let f = pen.pts[0]
  if len(pen.pts) > 2 and hypot(p.x - f[0], p.y - f[1]) * z < 8 { finish_pen_closed(true); return }
  if dbl { finish_pen(); return }
  push(pen.pts, [p.x, p.y])
  render()
}
fn finish_pen() { finish_pen_closed(false) }
fn finish_pen_closed(closed) {
  if pen == nil { return }
  let pts = pen.pts
  pen = nil
  if len(pts) < 2 { pop(undo_stack); render(); return }
  let s = mk("path")
  s.pts = pts
  s.closed = closed
  if not closed { s.fill = "" }
  s.name = "Pen path"
  push(shapes, s)
  selected = [s.id]
  set_tool_quiet("select")
  changed()
}

# ---- text
fn text_dialog(p, existing) {
  let d = kd_dialog(root, "Text")
  let init = "Your text"
  if existing != nil { init = existing.text }
  let t = kd_field(d.box, "Text", init, nil)
  let fr = row(d.box, "kd-frow")
  label(fr, "Font", "kd-flabel")
  let fd = dropdown(fr, FONTS_V, nil, nil)
  let sz = kd_field(d.box, "Size", 40, nil)
  if existing != nil { setvalue(fd, existing.font); settext(sz, str(existing.size)) }
  let r = row(d.box, "kd-drow")
  kd_btn(r, "OK", fn() {
    let tx = gettext(t)
    d.close()
    if tx == "" { return }
    record()
    let s = existing
    if s == nil { s = mk("text"); s.x = p.x; s.y = p.y; s.stroke = ""; s.fill = st_fill; if s.fill == "" { s.fill = "#1d2027" }; push(shapes, s) }
    s.text = tx
    s.font = getvalue(fd)
    s.size = kd_num(sz, 40, 4, 400)
    text_box(s)
    selected = [s.id]
    set_tool_quiet("select")
    changed()
  }, "on")
  focus(t)
}

# ---- commands
fn delete_sel() { if len(selected) == 0 { return }; record(); shapes = filter(shapes, fn(s) { return not contains(selected, s.id) }); selected = []; changed() }
fn duplicate() {
  let ss = sel_shapes()
  if len(ss) == 0 { return }
  record()
  selected = []
  for s in ss { let c = copy(s); c.id = nid(); move_shape(c, 16, 16); push(shapes, c); push(selected, c.id) }
  changed()
}
fn arrange(how) {
  let ss = sel_shapes()
  if len(ss) == 0 { return }
  record()
  let rest = filter(shapes, fn(s) { return not contains(selected, s.id) })
  if how == "front" { shapes = rest + ss }
  else if how == "back" { shapes = ss + rest }
  else {
    # one step: swap each selected shape with its neighbour
    let l = slice(shapes, 0)
    if how == "up" {
      let i = len(l) - 2
      while i >= 0 { if contains(selected, l[i].id) and not contains(selected, l[i + 1].id) { let a = l[i]; l[i] = l[i + 1]; l[i + 1] = a }; i -= 1 }
    } else {
      for i in range(1, len(l)) { if contains(selected, l[i].id) and not contains(selected, l[i - 1].id) { let a = l[i]; l[i] = l[i - 1]; l[i - 1] = a } }
    }
    shapes = l
  }
  changed()
}
fn align(how) {
  let ss = sel_shapes()
  if len(ss) == 0 { return }
  record()
  let g = group_box(ss)
  if len(ss) == 1 { g = {x: 0, y: 0, w: AW, h: AH} }
  for s in ss {
    let b = bbox(s)
    let dx = 0
    let dy = 0
    if how == "l" { dx = g.x - b.x } else if how == "r" { dx = g.x + g.w - b.x - b.w } else if how == "c" { dx = g.x + g.w / 2 - b.x - b.w / 2 }
    if how == "t" { dy = g.y - b.y } else if how == "b" { dy = g.y + g.h - b.y - b.h } else if how == "m" { dy = g.y + g.h / 2 - b.y - b.h / 2 }
    move_shape(s, dx, dy)
  }
  changed()
}
fn flip(horiz) {
  let ss = sel_shapes()
  if len(ss) == 0 { return }
  record()
  for s in ss {
    let c = center(s)
    if s.k == "line" or s.k == "path" { s.pts = map(s.pts, fn(p) { if horiz { return [2 * c.x - p[0], p[1]] }; return [p[0], 2 * c.y - p[1]] }) }
    s.rot = 0 - s.rot
  }
  changed()
}
fn copy_sel() { clip = map(sel_shapes(), fn(s) { return copy(s) }); if len(clip) > 0 { kd_toast(root, "Copied " + str(len(clip))) } }
fn paste() {
  if len(clip) == 0 { return }
  record()
  selected = []
  for s in clip { let c = copy(s); c.id = nid(); move_shape(c, 20, 20); push(shapes, c); push(selected, c.id) }
  clip = map(clip, fn(s) { let c = copy(s); move_shape(c, 20, 20); return c })
  set_tool_quiet("select")
  changed()
}
fn nudge(dx, dy) { if len(selected) == 0 { return }; record(); for s in sel_shapes() { move_shape(s, dx, dy) }; changed() }

# ---- SVG export / import
fn n2(v) { return str(round(v, 2)) }
fn svg_paint(s) {
  let f = s.fill
  if f == "" { f = "none" }
  let st = s.stroke
  let out = " fill=\"" + f + "\""
  if st != "" and s.sw > 0 { out = out + " stroke=\"" + st + "\" stroke-width=\"" + n2(s.sw) + "\" stroke-linejoin=\"round\" stroke-linecap=\"round\"" }
  if s.op < 1 { out = out + " opacity=\"" + n2(s.op) + "\"" }
  if s.rot != 0 { let c = center(s); out = out + " transform=\"rotate(" + n2(s.rot) + " " + n2(c.x) + " " + n2(c.y) + ")\"" }
  return out
}
fn to_svg() {
  let out = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + str(AW) + "\" height=\"" + str(AH) + "\" viewBox=\"0 0 " + str(AW) + " " + str(AH) + "\">\n"
  out = out + "  <!-- made with Kugel Vector -->\n"
  if bg != "" { out = out + "  <rect width=\"100%\" height=\"100%\" fill=\"" + bg + "\"/>\n" }
  for s in shapes {
    if s.vis {
      if s.k == "rect" {
        let r = ""
        if s.r > 0 { r = " rx=\"" + n2(min(s.r, s.w / 2, s.h / 2)) + "\"" }
        out = out + "  <rect x=\"" + n2(s.x) + "\" y=\"" + n2(s.y) + "\" width=\"" + n2(s.w) + "\" height=\"" + n2(s.h) + "\"" + r + svg_paint(s) + "/>\n"
      } else if s.k == "ellipse" {
        out = out + "  <ellipse cx=\"" + n2(s.x + s.w / 2) + "\" cy=\"" + n2(s.y + s.h / 2) + "\" rx=\"" + n2(s.w / 2) + "\" ry=\"" + n2(s.h / 2) + "\"" + svg_paint(s) + "/>\n"
      } else if s.k == "line" {
        let q = copy(s)
        q.fill = ""
        out = out + "  <line x1=\"" + n2(s.pts[0][0]) + "\" y1=\"" + n2(s.pts[0][1]) + "\" x2=\"" + n2(s.pts[1][0]) + "\" y2=\"" + n2(s.pts[1][1]) + "\"" + svg_paint(q) + "/>\n"
      } else if s.k == "path" {
        let d = ""
        for i in range(len(s.pts)) { let c = "L"; if i == 0 { c = "M" }; d = d + c + n2(s.pts[i][0]) + " " + n2(s.pts[i][1]) + " " }
        if s.closed { d = d + "Z" }
        out = out + "  <path d=\"" + trim(d) + "\"" + svg_paint(s) + "/>\n"
      } else if s.k == "text" {
        let fam = s.font
        let wt = ""
        let it = ""
        if startswith(fam, "bold ") { fam = substr(fam, 5); wt = " font-weight=\"bold\"" }
        if startswith(fam, "italic ") { fam = substr(fam, 7); it = " font-style=\"italic\"" }
        out = out + "  <text x=\"" + n2(s.x) + "\" y=\"" + n2(s.y + s.h / 2) + "\" dominant-baseline=\"middle\" font-family=\"" + kd_xml(fam) + "\" font-size=\"" + n2(s.size) + "\"" + wt + it + svg_paint(s) + ">" + kd_xml(s.text) + "</text>\n"
      }
    }
  }
  return out + "</svg>\n"
}
fn kd_xml(s) { return replace(replace(replace(replace(str(s), "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), "\"", "&quot;") }
fn attr(n, k, d) { if has(n.attrs, k) { return n.attrs[k] }; return d }
fn attrn(n, k, d) { let v = num(replace(attr(n, k, ""), "px", "")); if v == nil { return d }; return v }
fn svg_color(v, d) {
  if v == nil { return d }
  let t = lower(trim(v))
  if t == "none" or t == "transparent" { return "" }
  let named = {"black": "#000000", "white": "#ffffff", "red": "#ff0000", "green": "#008000", "blue": "#0000ff", "yellow": "#ffff00", "orange": "#ffa500", "purple": "#800080", "gray": "#808080", "grey": "#808080", "pink": "#ffc0cb", "brown": "#a52a2a", "cyan": "#00ffff", "magenta": "#ff00ff", "lime": "#00ff00", "navy": "#000080", "teal": "#008080"}
  if has(named, t) { return named[t] }
  let h = kd_parse_hex(t)
  if h != nil { return h }
  if startswith(t, "rgb") {
    let inner = split(replace(replace(replace(t, "rgba(", ""), "rgb(", ""), ")", ""), ",")
    if len(inner) >= 3 { return kd_rgb_hex(num(trim(inner[0])) or 0, num(trim(inner[1])) or 0, num(trim(inner[2])) or 0) }
  }
  return d
}
fn style_map(n) {
  let m = {}
  for part in split(attr(n, "style", ""), ";") { let kv = split(part, ":"); if len(kv) == 2 { m[trim(kv[0])] = trim(kv[1]) } }
  return m
}
fn get_paint(n, k, inherited) { let sm = style_map(n); if has(sm, k) { return sm[k] }; if has(n.attrs, k) { return n.attrs[k] }; return inherited[k] }
fn path_points(d) {
  # M L H V C Q Z (absolute + relative); curves are flattened into 8 straight steps each
  let toks = []
  let cur_ = ""
  for ch in split(d, "") {
    if contains("MmLlHhVvCcQqZzSsTtAa", ch) { if cur_ != "" { push(toks, cur_) }; push(toks, ch); cur_ = "" }
    else if ch == "," or ch == " " or ch == "\n" or ch == "\t" { if cur_ != "" { push(toks, cur_) }; cur_ = "" }
    else if ch == "-" and cur_ != "" and not endswith(cur_, "e") { push(toks, cur_); cur_ = "-" }
    else { cur_ = cur_ + ch }
  }
  if cur_ != "" { push(toks, cur_) }
  let subs = []
  let pts = []
  let x = 0
  let y = 0
  let cmd = "M"
  let i = 0
  let closed = false
  fn nx() { i += 1; return num(toks[i - 1]) or 0 }
  while i < len(toks) {
    let t = toks[i]
    if contains("MmLlHhVvCcQqZzSsTtAa", t) { cmd = t; i += 1; if cmd == "Z" or cmd == "z" { closed = true; if len(pts) > 1 { push(subs, {pts: pts, closed: true}) }; if len(pts) > 0 { x = pts[0][0]; y = pts[0][1] }; pts = [] }; continue }
    let rel = lower(cmd) == cmd
    let bx = 0
    let by = 0
    if rel { bx = x; by = y }
    let c = upper(cmd)
    if c == "M" { if len(pts) > 1 { push(subs, {pts: pts, closed: false}) }; x = bx + nx(); y = by + nx(); pts = [[x, y]]; if rel { cmd = "l" } else { cmd = "L" } }
    else if c == "L" or c == "T" { x = bx + nx(); y = by + nx(); push(pts, [x, y]) }
    else if c == "H" { x = bx + nx(); push(pts, [x, y]) }
    else if c == "V" { y = by + nx(); push(pts, [x, y]) }
    else if c == "C" or c == "S" or c == "Q" {
      let c1x = 0
      let c1y = 0
      if c != "S" { c1x = bx + nx(); c1y = by + nx() } else { c1x = x; c1y = y }
      let c2x = c1x
      let c2y = c1y
      if c != "Q" { c2x = bx + nx(); c2y = by + nx() }
      let ex = bx + nx()
      let ey = by + nx()
      for s in range(1, 9) {
        let tt = s / 8
        let u = 1 - tt
        let px = u * u * u * x + 3 * u * u * tt * c1x + 3 * u * tt * tt * c2x + tt * tt * tt * ex
        let py = u * u * u * y + 3 * u * u * tt * c1y + 3 * u * tt * tt * c2y + tt * tt * tt * ey
        push(pts, [px, py])
      }
      x = ex
      y = ey
    }
    else if c == "A" { nx(); nx(); nx(); nx(); nx(); x = bx + nx(); y = by + nx(); push(pts, [x, y]) }
    else { i += 1 }
    if len(pts) == 0 { pts = [[x, y]] }
  }
  if len(pts) > 1 { push(subs, {pts: pts, closed: false}) }
  return subs
}
fn import_svg(text) {
  let root_ = xml_parse(text)
  if root_ == nil or root_.tag != "svg" { kd_toast(root, "That SVG could not be read"); return 0 }
  let vb = split(trim(replace(attr(root_, "viewBox", ""), ",", " ")), " ")
  let w = attrn(root_, "width", 0)
  let h = attrn(root_, "height", 0)
  if len(vb) == 4 { if w == 0 { w = num(vb[2]) or 800 }; if h == 0 { h = num(vb[3]) or 600 } }
  if w == 0 { w = 800 }
  if h == 0 { h = 600 }
  let added = []
  fn walk(n, inh) {
    let mine = {"fill": get_paint(n, "fill", inh), "stroke": get_paint(n, "stroke", inh), "stroke-width": get_paint(n, "stroke-width", inh)}
    let tg = n.tag
    let s = nil
    if tg == "rect" { s = mk("rect"); s.x = attrn(n, "x", 0); s.y = attrn(n, "y", 0); s.w = attrn(n, "width", 0); s.h = attrn(n, "height", 0); s.r = attrn(n, "rx", 0) }
    else if tg == "circle" { s = mk("ellipse"); let r = attrn(n, "r", 0); s.x = attrn(n, "cx", 0) - r; s.y = attrn(n, "cy", 0) - r; s.w = 2 * r; s.h = 2 * r }
    else if tg == "ellipse" { s = mk("ellipse"); let rx = attrn(n, "rx", 0); let ry = attrn(n, "ry", 0); s.x = attrn(n, "cx", 0) - rx; s.y = attrn(n, "cy", 0) - ry; s.w = 2 * rx; s.h = 2 * ry }
    else if tg == "line" { s = mk("line"); s.pts = [[attrn(n, "x1", 0), attrn(n, "y1", 0)], [attrn(n, "x2", 0), attrn(n, "y2", 0)]] }
    else if tg == "polyline" or tg == "polygon" {
      let nums = filter(map(split(trim(replace(replace(attr(n, "points", ""), ",", " "), "\n", " ")), " "), fn(t) { return num(t) }), fn(v) { return v != nil })
      s = mk("path")
      for j in range(0, len(nums) - 1, 2) { push(s.pts, [nums[j], nums[j + 1]]) }
      s.closed = tg == "polygon"
      if len(s.pts) < 2 { s = nil }
    }
    else if tg == "path" {
      for sub in path_points(attr(n, "d", "")) {
        let q = mk("path")
        q.pts = sub.pts
        q.closed = sub.closed
        apply_paint(q, mine)
        if not q.closed and get_paint(n, "fill", inh) == nil { q.fill = "" }
        push(added, q)
      }
    }
    else if tg == "text" {
      s = mk("text")
      s.text = trim(n.text)
      for ch in n.children { s.text = s.text + trim(ch.text) }
      s.size = attrn(n, "font-size", 16)
      s.x = attrn(n, "x", 0)
      s.y = attrn(n, "y", 0) - s.size
      s.stroke = ""
      if s.text == "" { s = nil } else { text_box(s) }
    }
    if s != nil { apply_paint(s, mine); push(added, s) }
    if tg == "g" or tg == "svg" or tg == "a" { for ch in n.children { walk(ch, mine) } }
  }
  for ch in root_.children { walk(ch, {"fill": "#000000", "stroke": nil, "stroke-width": nil}) }
  return {shapes: added, w: w, h: h}
}
fn apply_paint(s, m) {
  s.fill = svg_color(m["fill"], "#000000")
  if m["fill"] == nil { s.fill = "#000000" }
  s.stroke = svg_color(m["stroke"], "")
  if m["stroke"] == nil { s.stroke = "" }
  let sw = num(replace(str(m["stroke-width"] or "1"), "px", ""))
  if sw == nil { sw = 1 }
  s.sw = sw
  if s.k == "line" and s.stroke == "" { s.stroke = "#000000" }
}

# ---- files
fn kvector_json() { return json({app: "Kugel Vector", version: 1, w: AW, h: AH, bg: bg, shapes: shapes}) }
fn load_kvector(text, nm) {
  let d = parse_json(text)
  if d == nil or type(d) != "map" or not has(d, "shapes") { kd_toast(root, "That is not a Kugel Vector file"); return }
  record()
  shapes = d.shapes
  AW = d.w
  AH = d.h
  bg = d.bg
  for s in shapes { next_id = max(next_id, s.id) }
  selected = []
  doc_name = replace(nm, ".kvector", "")
  settext(name_box, doc_name)
  store_set("name", doc_name)
  fit_view()
  draw_opts()
  changed()
}
fn open_file() {
  let f = file_open(["kvector", "svg"])
  if f == nil { return }
  if f.ext == "kvector" { load_kvector(f.text, f.name); return }
  let r = import_svg(f.text)
  if type(r) != "map" { return }
  record()
  for s in r.shapes { s.id = nid(); push(shapes, s) }
  if len(shapes) == len(r.shapes) { AW = clamp(round(r.w), 16, 4000); AH = clamp(round(r.h), 16, 4000) }
  selected = map(r.shapes, fn(s) { return s.id })
  set_tool_quiet("select")
  fit_view()
  draw_opts()
  changed()
  kd_toast(root, "Imported " + str(len(r.shapes)) + " shapes from " + f.name)
}
fn save_file() { let r = file_save(kd_safe_name(doc_name) + ".kvector", kvector_json()); if r.ok { kd_toast(root, "Saved " + r.name) } }
fn export_svg() { let r = file_save(kd_safe_name(doc_name) + ".svg", to_svg()); if r.ok { kd_toast(root, "Exported " + r.name) } }
fn export_png() {
  let c = canvas(holder, AW, AH)
  if bg != "" { draw_clear(c, bg) }
  let prev = selected
  for s in shapes { paint_shape(c, s, 1, 0, 0) }
  let r = file_save(kd_safe_name(doc_name) + ".png", canvas_data(c))
  destroy(c)
  if r.ok { kd_toast(root, "Exported " + r.name) }
}
fn new_dialog() {
  let d = kd_dialog(root, "New design")
  let pr = row(d.box, "kd-drow")
  let tw = nil
  let th = nil
  for s in [[800, 600, "Default"], [1080, 1080, "Square post"], [1920, 1080, "Slide / banner"], [512, 512, "Icon / logo"], [1200, 630, "Social card"], [794, 1123, "A4 poster"]] {
    kd_btn(pr, s[2], fn() { settext(tw, str(s[0])); settext(th, str(s[1])) }, nil)
  }
  tw = kd_field(d.box, "Width", AW, nil)
  th = kd_field(d.box, "Height", AH, nil)
  let keep = checkbox(d.box, "Keep the current shapes (only change the artboard)", false, nil, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Create", fn() {
    record()
    AW = round(kd_num(tw, 800, 16, 4000))
    AH = round(kd_num(th, 600, 16, 4000))
    if not getvalue(keep) { shapes = []; selected = []; bg = "#ffffff"; doc_name = "Untitled design"; settext(name_box, doc_name) }
    d.close()
    fit_view()
    draw_opts()
    changed()
  }, "on")
}

# ---- keys
on_keypress(fn(k) {
  if key_down("control") {
    if k == "z" { undo() } else if k == "y" { redo() } else if k == "c" { copy_sel() } else if k == "v" { paste() } else if k == "d" { duplicate() }
    else if k == "a" { set_tool_quiet("select"); selected = map(filter(shapes, fn(s) { return not s.lock and s.vis }), fn(s) { return s.id }); changed() } else if k == "s" { save_file() }
    return
  }
  let m = {"v": "select", "r": "rect", "o": "ellipse", "l": "line", "s": "star", "p": "pen", "f": "pencil", "t": "text", "h": "hand"}
  if has(m, k) { set_tool(m[k]); return }
  let step = 1
  if key_down("shift") { step = 10 }
  if k == "delete" or k == "backspace" { delete_sel() }
  else if k == "enter" { finish_pen() }
  else if k == "escape" { if pen != nil { pen = nil; pop(undo_stack) }; selected = []; changed() }
  else if k == "left" { nudge(0 - step, 0) } else if k == "right" { nudge(step, 0) } else if k == "up" { nudge(0, 0 - step) } else if k == "down" { nudge(0, step) }
  else if k == "]" { arrange("up") } else if k == "[" { arrange("down") }
})

# ---- autosave (the shape list is small; very big imports are skipped)
every_ms(3000, fn() {
  if not dirty { return }
  dirty = false
  let j = kvector_json()
  if len(j) < 190000 { store_set("doc", parse_json(j)) }
})

# ---- start
let checker = kd_checker(holder, 200, 150)
fn sample() {
  let s = mk("rect"); s.x = 60; s.y = 60; s.w = 680; s.h = 480; s.r = 28; s.fill = "#1d2027"; s.stroke = ""; s.name = "Card"; push(shapes, s)
  let c = mk("ellipse"); c.x = 110; c.y = 120; c.w = 220; c.h = 220; c.fill = "#ff8c1a"; c.stroke = "#ffd28a"; c.sw = 6; c.name = "Sun"; push(shapes, c)
  let st = mk("path"); st.pts = star_pts(560, 220, 90, 40, 5); st.closed = true; st.fill = "#ffd84a"; st.stroke = ""; st.rot = 12; st.name = "Star"; push(shapes, st)
  let w = mk("path"); w.pts = [[100, 450], [200, 400], [300, 450], [400, 400], [500, 450], [600, 400], [700, 450]]; w.fill = ""; w.stroke = "#2fa84f"; w.sw = 8; w.name = "Wave"; push(shapes, w)
  let t = mk("text"); t.text = "Kugel Vector"; t.size = 54; t.font = "bold Segoe UI"; t.fill = "#ffffff"; t.stroke = ""; t.x = 380 - 170; t.y = 330; text_box(t); t.x = 400 - t.w / 2; push(shapes, t)
}
if doc != nil and type(doc) == "map" and has(doc, "shapes") {
  shapes = doc.shapes
  AW = doc.w
  AH = doc.h
  bg = doc.bg
  for s in shapes { next_id = max(next_id, s.id) }
} else { sample() }
set_tool("select")
draw_props()
draw_objects()
let last_vw = 0
let last_vh = 0
every_ms(700, fn() { let s = canvas_size(view); if s.w != last_vw or s.h != last_vh { let first = last_vw == 0; last_vw = s.w; last_vh = s.h; if first { fit_view(); draw_opts() }; render() } })
after(60, fn() { fit_view(); draw_opts(); render() })
