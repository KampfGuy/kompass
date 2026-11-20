# ============================================================================
#  🖌 Kugel Paint — Kugel Store app for Kompass 1.8+ (written in KampfScript)
#  Painting like a small Photoshop / Fresco: layers with opacity and blend modes, brushes, eraser, fill, shapes, selection (copy / move / crop), filters, undo, PNG import / export.
#  Built by tools/build-apps.js from kugel-apps/design/kit.ks, kugel-apps/design/paint.ks
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

# ---------------------------------------------------------------- Kugel Paint
# Layers, brush / pencil / eraser / shapes / fill / text / picker / selection / move, zoom + pan, undo,
# filters, flip / rotate / resize / crop. Open PNG / JPG / GIF / WEBP, save .kpaint (keeps layers), export PNG.
# Everything stays on this PC. Drawing happens on fixed-size off-screen canvases, so it stays quick on a weak PC.
let W = 800
let H = 500
let layers = []
let cur = 0
let tool = "brush"
let bsize = 8
let balpha = 1
let color = "#1d2027"
let color2 = "#ffffff"
let fill_shapes = false
let tolerance = 32
let z = 1
let ox = 0
let oy = 0
let undo_stack = []
let redo_stack = []
let MAX_UNDO = 12
let sel = nil
let clip = nil
let doc_name = store_get("name", "Untitled")
let mouse = {x: -1, y: -1, in: false}
let drag = nil
let dirty_save = false

let root = box(body(), "kapp kd-paint")
let holder = kd_holder(root)
let tmp = nil
let checker = nil

# ---- layers
fn new_layer(name) { return {name: name, cv: canvas(holder, W, H), vis: true, op: 1} }
fn layer() { return layers[cur] }
fn reset_doc(w, h, fill) {
  W = clamp(round(w), 16, 2400)
  H = clamp(round(h), 16, 2400)
  clear(holder)
  tmp = canvas(holder, W, H)
  checker = kd_checker(holder, W, H)
  let bg = new_layer("Background")
  if fill != nil { draw_clear(bg.cv, fill) }
  layers = [bg]
  cur = 0
  sel = nil
  undo_stack = []
  redo_stack = []
}
fn flatten(bgfill) {
  let c = canvas(holder, W, H)
  if bgfill != nil { draw_clear(c, bgfill) }
  for l in layers { if l.vis { draw_image(c, l.cv, 0, 0, W, H, 0, l.op) } }
  return c
}

# ---- undo: copies of a layer before a change, or the whole document (size / layer list changes)
fn prune(st) {
  while len(st) > MAX_UNDO {
    let e = remove(st, 0)
    if e.t == "px" { destroy(e.cv) }
  }
}
fn record() {
  push(undo_stack, {t: "px", l: layer(), cv: kd_copy_canvas(holder, layer().cv, W, H)})
  prune(undo_stack)
  for e in redo_stack { if e.t == "px" { destroy(e.cv) } }
  redo_stack = []
  dirty_save = true
}
fn doc_state() { return {t: "doc", w: W, h: H, layers: slice(layers, 0), cur: cur, tmp: tmp, checker: checker, meta: map(layers, fn(l) { return {name: l.name, vis: l.vis, op: l.op} })} }
fn record_doc() {
  push(undo_stack, doc_state())
  prune(undo_stack)
  redo_stack = []
  dirty_save = true
}
fn apply(e, other) {
  if e.t == "px" {
    push(other, {t: "px", l: e.l, cv: kd_copy_canvas(holder, e.l.cv, W, H)})
    draw_clear(e.l.cv)
    draw_image(e.l.cv, e.cv, 0, 0, W, H)
    destroy(e.cv)
  } else {
    push(other, doc_state())
    W = e.w
    H = e.h
    layers = e.layers
    tmp = e.tmp
    checker = e.checker
    for i in range(len(layers)) { layers[i].name = e.meta[i].name; layers[i].vis = e.meta[i].vis; layers[i].op = e.meta[i].op }
    cur = clamp(e.cur, 0, len(layers) - 1)
    sel = nil
    fit_view()
    draw_opts()
  }
  dirty_save = true
  draw_layers()
  render()
}
fn undo() { if len(undo_stack) > 0 { apply(pop(undo_stack), redo_stack) } }
fn redo() { if len(redo_stack) > 0 { apply(pop(redo_stack), undo_stack) } }

# ---- UI: top bar
let bar = row(root, "kapp-bar")
label(bar, "🎨 Kugel Paint", "kapp-title")
let name_box = textbox(bar, "Name", nil, "kapp-field kd-name")
settext(name_box, doc_name)
on_input(name_box, fn(t) { doc_name = t; store_set("name", t) }, 300)
kd_btn(bar, "New", fn() { new_dialog() }, nil)
kd_btn(bar, "Open", fn() { open_file(false) }, nil)
settip(kd_btn(bar, "Import", fn() { open_file(true) }, nil), "Add a picture as a new layer")
settip(kd_btn(bar, "Save", fn() { save_file() }, nil), "Save as .kpaint (keeps layers) — Ctrl+S")
kd_btn(bar, "Export PNG", fn() { export_png() }, "go")
kd_tip(bar, "↶", "Undo (Ctrl+Z)", fn() { undo() })
kd_tip(bar, "↷", "Redo (Ctrl+Y)", fn() { redo() })
let img_dd = dropdown(bar, ["Image…", "Flip horizontal", "Flip vertical", "Rotate 90° right", "Rotate 90° left", "Rotate 180°", "Resize image…", "Canvas size…", "Crop to selection", "Clear layer"], fn(ch) { image_cmd(ch) }, nil)
let adj_dd = dropdown(bar, ["Adjust…", "Grayscale", "Sepia", "Invert", "Blur", "Sharpen-ish (contrast)", "Brighter", "Darker", "More saturated", "Hue shift"], fn(ch) { adjust_cmd(ch) }, nil)

# options row
let opts = row(root, "kapp-bar kd-opts")
let main = row(root, "kapp-main")
let tools_p = col(main, "kapp-panel kd-tools")
let view_wrap = box(main, "kapp-view kd-viewwrap")
let view = canvas(view_wrap)
let right = col(main, "kapp-panel right kd-right")
let status = label(root, "", "kapp-status")

let TOOLS = [["brush", "🖌", "Brush (B)"], ["pencil", "✏", "Pencil, hard pixels (P)"], ["eraser", "⌫", "Eraser (E)"], ["fill", "🪣", "Fill (G)"],
  ["picker", "💧", "Colour picker (I)"], ["line", "╱", "Line (L)"], ["rect", "▭", "Rectangle (R)"], ["ellipse", "◯", "Ellipse (O)"],
  ["text", "T", "Text (T)"], ["select", "⬚", "Select (S)"], ["move", "✥", "Move layer / selection (V)"], ["hand", "✋", "Pan (H, or middle mouse)"]]
let tool_btns = {}
for t in TOOLS { let b = button(tools_p, t[1], fn() { set_tool(t[0]) }, "kapp-btn kd-tool"); settip(b, t[2]); tool_btns[t[0]] = b }
kd_space(tools_p)
let sw_main = button(tools_p, "", fn() { let a = color; color = color2; color2 = a; picker.set(color); draw_swatches() }, "kd-swatch big")
settip(sw_main, "Main colour (click: swap with second)")
let sw_2 = button(tools_p, "", fn() { let a = color; color = color2; color2 = a; picker.set(color); draw_swatches() }, "kd-swatch")
settip(sw_2, "Second colour (X swaps)")
fn draw_swatches() { setcolor(sw_main, color); setcolor(sw_2, color2) }

fn set_tool(t) {
  tool = t
  for k in keys(tool_btns) { togglestyle(tool_btns[k], "on", k == t) }
  draw_opts()
  render()
}
fn draw_opts() {
  clear(opts)
  label(opts, upper(substr(tool, 0, 1)) + substr(tool, 1), "kd-optname")
  if tool == "brush" or tool == "pencil" or tool == "eraser" or tool == "line" or tool == "rect" or tool == "ellipse" {
    label(opts, "Size", "kapp-tiny")
    let sl = slider(opts, 1, 120, bsize, fn(v) { bsize = round(v); settext(szl, str(bsize) + " px") }, "kd-slider")
    let szl = label(opts, str(bsize) + " px", "kapp-tiny kd-val")
    label(opts, "Opacity", "kapp-tiny")
    let al = slider(opts, 5, 100, balpha * 100, fn(v) { balpha = v / 100; settext(all, str(round(v)) + "%") }, "kd-slider")
    let all = label(opts, str(round(balpha * 100)) + "%", "kapp-tiny kd-val")
  }
  if tool == "rect" or tool == "ellipse" { checkbox(opts, "Filled", fill_shapes, fn(on) { fill_shapes = on }, nil); label(opts, "Shift = square / circle", "kapp-tiny") }
  if tool == "line" { label(opts, "Shift = 45° steps", "kapp-tiny") }
  if tool == "fill" {
    label(opts, "Tolerance", "kapp-tiny")
    slider(opts, 0, 160, tolerance, fn(v) { tolerance = round(v); settext(tl, str(tolerance)) }, "kd-slider")
    let tl = label(opts, str(tolerance), "kapp-tiny kd-val")
  }
  if tool == "select" or sel != nil {
    kd_btn(opts, "Copy", fn() { copy_sel(false) }, nil)
    kd_btn(opts, "Cut", fn() { copy_sel(true) }, nil)
    kd_btn(opts, "Paste", fn() { paste() }, nil)
    kd_btn(opts, "Delete", fn() { delete_sel() }, nil)
    kd_btn(opts, "Crop", fn() { image_cmd("Crop to selection") }, nil)
    kd_btn(opts, "Select all", fn() { sel = {x: 0, y: 0, w: W, h: H}; render() }, nil)
    kd_btn(opts, "Deselect", fn() { sel = nil; draw_opts(); render() }, nil)
  }
  if tool == "text" { label(opts, "Click where the text should start.", "kapp-tiny") }
  if tool == "picker" { label(opts, "Click to pick a colour from the picture.", "kapp-tiny") }
  if tool == "hand" { label(opts, "Drag to move around. Wheel zooms.", "kapp-tiny") }
  kd_space(opts)
  kd_tip(opts, "−", "Zoom out", fn() { zoom_at(1 / 1.25, -1, -1) })
  let zl = label(opts, str(round(z * 100)) + "%", "kapp-tiny kd-zoom")
  kd_tip(opts, "+", "Zoom in", fn() { zoom_at(1.25, -1, -1) })
  kd_btn(opts, "Fit", fn() { fit_view(); render() }, nil)
  kd_btn(opts, "100%", fn() { z = 1; center_view(); render() }, nil)
}

# ---- right panel: colours + layers
kd_sec(right, "Colour")
let picker = kd_color_panel(right, color, fn(h) { color = h; draw_swatches() })
kd_sec(right, "Layers")
let lay_tools = row(right, "kd-laytools")
kd_tip(lay_tools, "+", "New layer", fn() { add_layer() })
kd_tip(lay_tools, "⧉", "Duplicate layer", fn() { dup_layer() })
kd_tip(lay_tools, "▲", "Move layer up", fn() { move_layer(1) })
kd_tip(lay_tools, "▼", "Move layer down", fn() { move_layer(-1) })
kd_tip(lay_tools, "⤓", "Merge down", fn() { merge_down() })
kd_tip(lay_tools, "🗑", "Delete layer", fn() { delete_layer() })
let lay_list = col(right, "kd-laylist")
let op_row = row(right, "kd-oprow")
label(op_row, "Layer opacity", "kapp-tiny")
let op_sl = slider(op_row, 0, 100, 100, fn(v) { layer().op = v / 100; dirty_save = true; render() }, "kd-slider")

fn draw_layers() {
  clear(lay_list)
  let i = len(layers) - 1
  while i >= 0 {
    let idx = i
    let l = layers[i]
    let r = row(lay_list, "kd-layer")
    if idx == cur { addstyle(r, "on") }
    let eye = "👁"
    if not l.vis { eye = "◌" }
    button(r, eye, fn() { l.vis = not l.vis; dirty_save = true; draw_layers(); render() }, "kd-eye")
    let th = canvas(r, 44, 28, "kd-thumb")
    draw_image(th, checker, 0, 0, 44, 28)
    draw_image(th, l.cv, 0, 0, 44, 28)
    let nm = label(r, l.name, "kd-layname")
    on_click(r, fn() { cur = idx; draw_layers(); render() })
    button(r, "✎", fn() { rename_layer(idx) }, "kd-eye")
    i -= 1
  }
  setvalue(op_sl, layer().op * 100)
}
fn refresh_thumbs() { draw_layers() }
fn add_layer() { record_doc(); insert(layers, cur + 1, new_layer("Layer " + str(len(layers) + 1))); cur += 1; draw_layers(); render() }
fn dup_layer() {
  record_doc()
  let l = new_layer(layer().name + " copy")
  draw_image(l.cv, layer().cv, 0, 0, W, H)
  l.op = layer().op
  insert(layers, cur + 1, l)
  cur += 1
  draw_layers()
  render()
}
fn move_layer(d) {
  let j = cur + d
  if j < 0 or j >= len(layers) { return }
  record_doc()
  let a = layers[cur]
  layers[cur] = layers[j]
  layers[j] = a
  cur = j
  draw_layers()
  render()
}
fn merge_down() {
  if cur == 0 { kd_toast(root, "Nothing below to merge into"); return }
  record_doc()
  let below = new_layer(layers[cur - 1].name)
  draw_image(below.cv, layers[cur - 1].cv, 0, 0, W, H, 0, layers[cur - 1].op)
  if layer().vis { draw_image(below.cv, layer().cv, 0, 0, W, H, 0, layer().op) }
  layers[cur - 1] = below
  remove(layers, cur)
  cur -= 1
  draw_layers()
  render()
}
fn delete_layer() {
  if len(layers) == 1 { kd_toast(root, "A picture needs at least one layer"); return }
  record_doc()
  remove(layers, cur)
  cur = clamp(cur - 1, 0, len(layers) - 1)
  draw_layers()
  render()
}
fn rename_layer(idx) {
  let d = kd_dialog(root, "Rename layer")
  let t = kd_field(d.box, "Name", layers[idx].name, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Rename", fn() { let n = trim(gettext(t)); if n != "" { record_doc(); layers[idx].name = substr(n, 0, 30) }; d.close(); draw_layers() }, "on")
  focus(t)
}

# ---- view
fn center_view() {
  let s = canvas_size(view)
  ox = round((s.w - W * z) / 2)
  oy = round((s.h - H * z) / 2)
}
fn fit_view() {
  let s = canvas_size(view)
  z = min(1, (s.w - 40) / W, (s.h - 40) / H)
  z = max(z, 0.05)
  center_view()
}
fn zoom_at(f, x, y) {
  let s = canvas_size(view)
  if x < 0 { x = s.w / 2; y = s.h / 2 }
  let nz = clamp(z * f, 0.05, 32)
  let dx = (x - ox) / z
  let dy = (y - oy) / z
  z = nz
  ox = round(x - dx * z)
  oy = round(y - dy * z)
  draw_opts()
  render()
}
fn to_doc(x, y) { return {x: (x - ox) / z, y: (y - oy) / z} }
fn to_view(x, y) { return {x: ox + x * z, y: oy + y * z} }
fn shape_pts(a, b, shift) {
  let x0 = a.x
  let y0 = a.y
  let x1 = b.x
  let y1 = b.y
  if shift {
    if tool == "line" {
      let ang = atan2(y1 - y0, x1 - x0)
      let st = PI / 4
      ang = round(ang / st) * st
      let d = hypot(x1 - x0, y1 - y0)
      x1 = x0 + cos(ang) * d
      y1 = y0 + sin(ang) * d
    } else {
      let d = max(abs(x1 - x0), abs(y1 - y0))
      x1 = x0 + sign(x1 - x0 + 0.0001) * d
      y1 = y0 + sign(y1 - y0 + 0.0001) * d
    }
  }
  return {x0: x0, y0: y0, x1: x1, y1: y1}
}
fn draw_shape(c, p, k, col_, width, filled) {
  if tool == "line" { draw_line(c, p.x0, p.y0, p.x1, p.y1, col_, width); draw_circle(c, p.x0, p.y0, width / 2, col_); draw_circle(c, p.x1, p.y1, width / 2, col_); return }
  let x = min(p.x0, p.x1)
  let y = min(p.y0, p.y1)
  let w = abs(p.x1 - p.x0)
  let h = abs(p.y1 - p.y0)
  if tool == "rect" { if filled { draw_rect(c, x, y, w, h, col_) } else { draw_rect(c, x + width / 2, y + width / 2, max(0, w - width), max(0, h - width), col_, width) } }
  if tool == "ellipse" { if filled { draw_ellipse(c, x + w / 2, y + h / 2, w / 2, h / 2, 0, col_) } else { draw_ellipse(c, x + w / 2, y + h / 2, max(0, w / 2 - width / 2), max(0, h / 2 - width / 2), 0, col_, width) } }
}
fn render() {
  let s = canvas_size(view)
  draw_clear(view, "#16181d")
  draw_smooth(view, z < 1)
  draw_rect(view, ox + 4, oy + 5, W * z, H * z, "#0b0c0f")
  draw_image(view, checker, ox, oy, W * z, H * z)
  for i in range(len(layers)) {
    let l = layers[i]
    if l.vis {
      if drag != nil and drag.kind == "move" and i == cur {
        draw_image(view, l.cv, ox, oy, W * z, H * z, 0, l.op)
        draw_image(view, drag.float, ox + (drag.fx + drag.dx) * z, oy + (drag.fy + drag.dy) * z, drag.fw * z, drag.fh * z, 0, l.op)
      } else { draw_image(view, l.cv, ox, oy, W * z, H * z, 0, l.op) }
      if drag != nil and drag.kind == "brush" and i == cur { draw_image(view, tmp, ox, oy, W * z, H * z, 0, balpha * l.op) }
    }
  }
  if drag != nil and drag.kind == "shape" {
    let p = shape_pts(to_view(drag.a.x, drag.a.y), to_view(drag.b.x, drag.b.y), drag.shift)
    draw_alpha(view, balpha)
    draw_shape(view, p, tool, color, bsize * z, fill_shapes)
    draw_alpha(view, 1)
  }
  let sr = sel
  if drag != nil and drag.kind == "select" { sr = norm_rect(drag.a, drag.b) }
  if sr != nil {
    let a = to_view(sr.x, sr.y)
    draw_rect(view, a.x, a.y, sr.w * z, sr.h * z, "#000000", 1)
    draw_rect(view, a.x + 1, a.y + 1, max(0, sr.w * z - 2), max(0, sr.h * z - 2), "#ffffff", 1)
  }
  if mouse.in and (tool == "brush" or tool == "eraser" or tool == "pencil") {
    draw_circle(view, mouse.x, mouse.y, max(1, bsize * z / 2), "#ffffff", 1)
    draw_circle(view, mouse.x, mouse.y, max(1, bsize * z / 2) + 1, "#00000088", 1)
  }
  draw_status()
}
fn norm_rect(a, b) {
  let x0 = clamp(floor(min(a.x, b.x)), 0, W)
  let y0 = clamp(floor(min(a.y, b.y)), 0, H)
  let x1 = clamp(ceil(max(a.x, b.x)), 0, W)
  let y1 = clamp(ceil(max(a.y, b.y)), 0, H)
  return {x: x0, y: y0, w: x1 - x0, h: y1 - y0}
}
fn draw_status() {
  let t = str(W) + " × " + str(H) + " px   ·   " + str(round(z * 100)) + "%   ·   layer " + layer().name
  if mouse.in { let p = to_doc(mouse.x, mouse.y); t = t + "   ·   " + str(floor(p.x)) + ", " + str(floor(p.y)) }
  if sel != nil { t = t + "   ·   selection " + str(sel.w) + " × " + str(sel.h) }
  t = t + "   ·   " + autosave_note
  settext(status, t)
}

# ---- painting
fn dab(c, x, y, col_) { draw_circle(c, x, y, max(0.5, bsize / 2), col_) }
fn stroke_to(c, a, b, col_) { draw_line(c, a.x, a.y, b.x, b.y, col_, bsize); dab(c, b.x, b.y, col_) }
fn pencil_line(c, a, b, col_) {
  let n = max(1, ceil(max(abs(b.x - a.x), abs(b.y - a.y))))
  let s = max(1, bsize)
  for i in range(n + 1) {
    let t = i / n
    draw_rect(c, floor(a.x + (b.x - a.x) * t - s / 2 + 0.5), floor(a.y + (b.y - a.y) * t - s / 2 + 0.5), s, s, col_)
  }
}
fn pick_color(p) {
  let f = flatten(nil)
  let c = pixel_at(f, p.x, p.y)
  destroy(f)
  if substr(c, 7, 2) == "00" { return }
  color = substr(c, 0, 7)
  picker.set(color)
  picker.remember()
  draw_swatches()
}
fn text_dialog(p) {
  let d = kd_dialog(root, "Add text")
  let t = kd_field(d.box, "Text", "Hello!", nil)
  let s = kd_field(d.box, "Size", 32, nil)
  let fr = row(d.box, "kd-frow")
  label(fr, "Font", "kd-flabel")
  let fd = dropdown(fr, ["Segoe UI", "bold Segoe UI", "Georgia", "bold Georgia", "Courier New", "Comic Sans MS", "Impact", "italic Times New Roman"], nil, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Add", fn() {
    let tx = gettext(t)
    if tx != "" {
      record()
      let sz = kd_num(s, 32, 4, 400)
      draw_alpha(layer().cv, balpha)
      draw_text(layer().cv, p.x, p.y + sz / 2, tx, color, sz, "left", getvalue(fd))
      draw_alpha(layer().cv, 1)
      changed()
    }
    d.close()
  }, "on")
  focus(t)
}
fn changed() { dirty_save = true; draw_layers(); render() }

on_mouse(view, fn(e) {
  mouse.x = e.x
  mouse.y = e.y
  let p = to_doc(e.x, e.y)
  if e.type == "wheel" { if e.dy < 0 { zoom_at(1.15, e.x, e.y) } else { zoom_at(1 / 1.15, e.x, e.y) }; return }
  if e.type == "down" {
    mouse.in = true
    if e.button == "middle" or tool == "hand" { drag = {kind: "pan", x: e.x, y: e.y, ox: ox, oy: oy}; return }
    let col_ = color
    if e.button == "right" { col_ = color2 }
    if tool == "brush" { record(); draw_clear(tmp); dab(tmp, p.x, p.y, col_); drag = {kind: "brush", last: p, col: col_} }
    else if tool == "pencil" { record(); pencil_line(layer().cv, p, p, col_); drag = {kind: "pencil", last: p, col: col_} }
    else if tool == "eraser" {
      record()
      draw_blend(layer().cv, "erase")
      draw_alpha(layer().cv, balpha)
      dab(layer().cv, p.x, p.y, "#000000")
      drag = {kind: "eraser", last: p}
    }
    else if tool == "line" or tool == "rect" or tool == "ellipse" { drag = {kind: "shape", a: p, b: p, shift: e.shift, col: col_} }
    else if tool == "fill" { record(); let n = draw_fill(layer().cv, p.x, p.y, col_, tolerance); if n == 0 { pop(undo_stack) }; changed() }
    else if tool == "picker" { pick_color(p) }
    else if tool == "text" { text_dialog(p) }
    else if tool == "select" { drag = {kind: "select", a: p, b: p} }
    else if tool == "move" { start_move(p) }
    render()
    return
  }
  if e.type == "move" {
    let vs = canvas_size(view)
    mouse.in = e.x >= 0 and e.y >= 0 and e.x < vs.w and e.y < vs.h
    if drag == nil { render(); return }
    if drag.kind == "pan" { ox = drag.ox + e.x - drag.x; oy = drag.oy + e.y - drag.y }
    else if drag.kind == "brush" { stroke_to(tmp, drag.last, p, drag.col); drag.last = p }
    else if drag.kind == "pencil" { pencil_line(layer().cv, drag.last, p, drag.col); drag.last = p }
    else if drag.kind == "eraser" { stroke_to(layer().cv, drag.last, p, "#000000"); drag.last = p }
    else if drag.kind == "shape" { drag.b = p; drag.shift = e.shift }
    else if drag.kind == "select" { drag.b = p }
    else if drag.kind == "move" { drag.dx = round(p.x - drag.p0.x); drag.dy = round(p.y - drag.p0.y) }
    render()
    return
  }
  if e.type == "up" {
    if drag == nil { return }
    let k = drag.kind
    if k == "brush" { draw_image(layer().cv, tmp, 0, 0, W, H, 0, balpha); draw_clear(tmp) }
    else if k == "eraser" { draw_alpha(layer().cv, 1); draw_blend(layer().cv, "normal") }
    else if k == "shape" {
      let pt = shape_pts(drag.a, drag.b, drag.shift)
      if abs(pt.x1 - pt.x0) + abs(pt.y1 - pt.y0) >= 1 {
        record()
        draw_alpha(layer().cv, balpha)
        draw_shape(layer().cv, pt, tool, drag.col, bsize, fill_shapes)
        draw_alpha(layer().cv, 1)
      }
    }
    else if k == "select" { let r = norm_rect(drag.a, drag.b); if r.w < 2 or r.h < 2 { sel = nil } else { sel = r }; drag = nil; draw_opts() }
    else if k == "move" { finish_move() }
    drag = nil
    if k != "pan" and k != "select" { changed() } else { render() }
  }
})

fn start_move(p) {
  record()
  let r = sel
  if r == nil { r = {x: 0, y: 0, w: W, h: H} }
  let fl = canvas(holder, r.w, r.h)
  draw_image(fl, layer().cv, 0 - r.x, 0 - r.y, W, H)
  draw_blend(layer().cv, "erase")
  draw_rect(layer().cv, r.x, r.y, r.w, r.h, "#000000")
  draw_blend(layer().cv, "normal")
  drag = {kind: "move", p0: p, dx: 0, dy: 0, float: fl, fx: r.x, fy: r.y, fw: r.w, fh: r.h}
}
fn finish_move() {
  draw_image(layer().cv, drag.float, drag.fx + drag.dx, drag.fy + drag.dy, drag.fw, drag.fh)
  if sel != nil { sel.x += drag.dx; sel.y += drag.dy }
  destroy(drag.float)
}

# ---- selection commands
fn copy_sel(cut) {
  let r = sel
  if r == nil { r = {x: 0, y: 0, w: W, h: H} }
  if clip != nil { destroy(clip.cv) }
  let c = canvas(holder, r.w, r.h)
  draw_image(c, layer().cv, 0 - r.x, 0 - r.y, W, H)
  clip = {cv: c, w: r.w, h: r.h, x: r.x, y: r.y}
  if cut { record(); draw_blend(layer().cv, "erase"); draw_rect(layer().cv, r.x, r.y, r.w, r.h, "#000000"); draw_blend(layer().cv, "normal"); changed() }
  kd_toast(root, "Copied " + str(r.w) + " × " + str(r.h))
}
fn paste() {
  if clip == nil { kd_toast(root, "Nothing copied yet"); return }
  record_doc()
  let l = new_layer("Pasted")
  draw_image(l.cv, clip.cv, clip.x, clip.y, clip.w, clip.h)
  insert(layers, cur + 1, l)
  cur += 1
  sel = {x: clip.x, y: clip.y, w: clip.w, h: clip.h}
  set_tool("move")
  changed()
}
fn delete_sel() {
  if sel == nil { return }
  record()
  draw_blend(layer().cv, "erase")
  draw_rect(layer().cv, sel.x, sel.y, sel.w, sel.h, "#000000")
  draw_blend(layer().cv, "normal")
  changed()
}

# ---- image commands
fn transform_doc(nw, nh, f) {
  # rebuild every layer at a new size; f(new_canvas, old_layer) draws the old picture into it
  record_doc()
  let nl = []
  let oldw = W
  let oldh = H
  W = nw
  H = nh
  for l in layers {
    let c = canvas(holder, W, H)
    f(c, l, oldw, oldh)
    push(nl, {name: l.name, cv: c, vis: l.vis, op: l.op})
  }
  layers = nl
  tmp = canvas(holder, W, H)
  checker = kd_checker(holder, W, H)
  sel = nil
  fit_view()
  draw_opts()
  changed()
}
fn image_cmd(ch) {
  setvalue(img_dd, "Image…")
  if ch == "Flip horizontal" { transform_doc(W, H, fn(c, l, w, h) { draw_image(c, l.cv, 0, 0, 0 - w, h) }) }
  else if ch == "Flip vertical" { transform_doc(W, H, fn(c, l, w, h) { draw_image(c, l.cv, 0, 0, w, 0 - h) }) }
  else if ch == "Rotate 180°" { transform_doc(W, H, fn(c, l, w, h) { draw_image(c, l.cv, 0, 0, w, h, PI) }) }
  else if ch == "Rotate 90° right" { transform_doc(H, W, fn(c, l, w, h) { draw_image(c, l.cv, h / 2 - w / 2, w / 2 - h / 2, w, h, PI / 2) }) }
  else if ch == "Rotate 90° left" { transform_doc(H, W, fn(c, l, w, h) { draw_image(c, l.cv, h / 2 - w / 2, w / 2 - h / 2, w, h, 0 - PI / 2) }) }
  else if ch == "Crop to selection" {
    if sel == nil or sel.w < 2 or sel.h < 2 { kd_toast(root, "Select an area first (⬚)"); return }
    let r = sel
    transform_doc(r.w, r.h, fn(c, l, w, h) { draw_image(c, l.cv, 0 - r.x, 0 - r.y, w, h) })
  }
  else if ch == "Clear layer" { record(); draw_clear(layer().cv); changed() }
  else if ch == "Resize image…" { size_dialog(true) }
  else if ch == "Canvas size…" { size_dialog(false) }
}
fn size_dialog(scale) {
  let title = "Canvas size"
  if scale { title = "Resize image" }
  let d = kd_dialog(root, title)
  let tw = kd_field(d.box, "Width", W, nil)
  let th = kd_field(d.box, "Height", H, nil)
  let keep = checkbox(d.box, "Keep proportions", true, nil, nil)
  let ratio = W / H
  on_input(tw, fn(t) { if getvalue(keep) { let n = num(t); if n != nil { settext(th, str(round(n / ratio))) } } }, 200)
  if scale { label(d.box, "Stretches every layer to the new size.", "kapp-tiny") } else { label(d.box, "Adds or cuts space at the right / bottom; the picture is not stretched.", "kapp-tiny") }
  let r = row(d.box, "kd-drow")
  kd_btn(r, "OK", fn() {
    let nw = kd_num(tw, W, 16, 2400)
    let nh = kd_num(th, H, 16, 2400)
    d.close()
    if scale { transform_doc(round(nw), round(nh), fn(c, l, w, h) { draw_smooth(c, true); draw_image(c, l.cv, 0, 0, round(nw), round(nh)) }) }
    else { transform_doc(round(nw), round(nh), fn(c, l, w, h) { draw_image(c, l.cv, 0, 0, w, h) }) }
  }, "on")
}
fn adjust_cmd(ch) {
  setvalue(adj_dd, "Adjust…")
  let m = {"Grayscale": ["grayscale", 100], "Sepia": ["sepia", 100], "Invert": ["invert", 100], "Blur": ["blur", 2], "Sharpen-ish (contrast)": ["contrast", 130],
    "Brighter": ["brightness", 120], "Darker": ["brightness", 80], "More saturated": ["saturate", 160], "Hue shift": ["hue", 60]}
  if not has(m, ch) { return }
  record()
  canvas_filter(layer().cv, m[ch][0], m[ch][1])
  changed()
}

# ---- files
fn new_dialog() {
  let d = kd_dialog(root, "New picture")
  let pr = row(d.box, "kd-drow")
  let tw = nil
  let th = nil
  for s in [[800, 500, "Default"], [1280, 720, "HD"], [1920, 1080, "Full HD"], [512, 512, "Square"], [64, 64, "Icon"], [32, 32, "Pixel art"]] {
    kd_btn(pr, s[2] + " " + str(s[0]) + "×" + str(s[1]), fn() { settext(tw, str(s[0])); settext(th, str(s[1])) }, nil)
  }
  tw = kd_field(d.box, "Width", W, nil)
  th = kd_field(d.box, "Height", H, nil)
  let fr = row(d.box, "kd-frow")
  label(fr, "Background", "kd-flabel")
  let bgd = dropdown(fr, ["White", "Transparent", "Main colour"], nil, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Create", fn() {
    let bgc = "#ffffff"
    if getvalue(bgd) == "Transparent" { bgc = nil } else if getvalue(bgd) == "Main colour" { bgc = color }
    let nw = kd_num(tw, 800, 16, 2400)
    let nh = kd_num(th, 500, 16, 2400)
    d.close()
    reset_doc(nw, nh, bgc)
    doc_name = "Untitled"
    settext(name_box, doc_name)
    if nw <= 64 and nh <= 64 { set_tool("pencil"); bsize = 1 }
    fit_view()
    draw_opts()
    changed()
  }, "on")
}
fn open_file(as_layer) {
  let f = file_open(["png", "jpg", "jpeg", "gif", "webp", "kpaint"])
  if f == nil { return }
  if f.ext == "kpaint" { load_kpaint(f.text, f.name); return }
  let info = load_image(f.data)
  if not info.ok { kd_toast(root, "Could not read that picture"); return }
  let w = info.w
  let h = info.h
  let k = 1
  if max(w, h) > 2400 { k = 2400 / max(w, h) }
  w = round(w * k)
  h = round(h * k)
  if as_layer {
    record_doc()
    let l = new_layer(substr(replace(f.name, "." + f.ext, ""), 0, 24))
    let s = min(1, W / w, H / h)
    draw_smooth(l.cv, true)
    draw_image(l.cv, f.data, round((W - w * s) / 2), round((H - h * s) / 2), round(w * s), round(h * s))
    insert(layers, cur + 1, l)
    cur += 1
  } else {
    reset_doc(w, h, nil)
    draw_smooth(layers[0].cv, true)
    draw_image(layers[0].cv, f.data, 0, 0, w, h)
    doc_name = replace(f.name, "." + f.ext, "")
    settext(name_box, doc_name)
    store_set("name", doc_name)
    fit_view()
    draw_opts()
  }
  changed()
}
fn kpaint_json() {
  let ls = []
  for l in layers { push(ls, {name: l.name, vis: l.vis, op: l.op, png: canvas_data(l.cv)}) }
  return json({app: "Kugel Paint", version: 1, w: W, h: H, layers: ls})
}
fn load_kpaint(text, nm) {
  let d = parse_json(text)
  if d == nil or type(d) != "map" or not has(d, "layers") or not has(d, "w") { kd_toast(root, "That is not a Kugel Paint file"); return }
  reset_doc(d.w, d.h, nil)
  layers = []
  for x in d.layers {
    let l = new_layer(str(x.name))
    l.vis = x.vis
    l.op = x.op
    canvas_load(l.cv, x.png)
    push(layers, l)
  }
  if len(layers) == 0 { layers = [new_layer("Background")] }
  cur = len(layers) - 1
  doc_name = replace(nm, ".kpaint", "")
  settext(name_box, doc_name)
  store_set("name", doc_name)
  fit_view()
  draw_opts()
  changed()
}
fn save_file() {
  let r = file_save(kd_safe_name(doc_name) + ".kpaint", kpaint_json())
  if r.ok { kd_toast(root, "Saved " + r.name) }
}
fn export_png() {
  let f = flatten(nil)
  let r = file_save(kd_safe_name(doc_name) + ".png", canvas_data(f))
  destroy(f)
  if r.ok { kd_toast(root, "Exported " + r.name) }
}

# ---- autosave on this PC (layers up to ~190 KB each; bigger pictures: use Save .kpaint)
let autosave_note = ""
fn autosave() {
  if not dirty_save { return }
  dirty_save = false
  let ls = []
  let total = 0
  for l in layers { let png = canvas_data(l.cv); total += len(png); push(ls, png) }
  if total > 1500000 or len(layers) > 8 { autosave_note = "too big to keep automatically — use Save .kpaint"; draw_status(); return }
  for i in range(len(ls)) {
    if len(ls[i]) > 190000 { autosave_note = "too big to keep automatically — use Save .kpaint"; draw_status(); return }
  }
  for i in range(len(ls)) { store_set("layer" + str(i), ls[i]) }
  store_set("doc", {w: W, h: H, cur: cur, n: len(ls), meta: map(layers, fn(l) { return {name: l.name, vis: l.vis, op: l.op} })})
  autosave_note = "kept on this PC"
  draw_status()
}
every_ms(4000, fn() { autosave() })

on_keypress(fn(k) {
  let ctrl = key_down("control")
  if ctrl {
    if k == "z" { undo() } else if k == "y" { redo() } else if k == "c" { copy_sel(false) } else if k == "x" { copy_sel(true) } else if k == "v" { paste() }
    else if k == "a" { sel = {x: 0, y: 0, w: W, h: H}; draw_opts(); render() } else if k == "s" { save_file() }
    return
  }
  let m = {"b": "brush", "p": "pencil", "e": "eraser", "g": "fill", "i": "picker", "l": "line", "r": "rect", "o": "ellipse", "t": "text", "s": "select", "v": "move", "h": "hand"}
  if has(m, k) { set_tool(m[k]); return }
  if k == "x" { let a = color; color = color2; color2 = a; picker.set(color); draw_swatches() }
  else if k == "delete" or k == "backspace" { delete_sel() }
  else if k == "escape" { sel = nil; draw_opts(); render() }
  else if k == "[" { bsize = max(1, bsize - 2); draw_opts(); render() }
  else if k == "]" { bsize = min(120, bsize + 2); draw_opts(); render() }
})

# ---- start: last picture (kept on this PC) or a welcome picture
fn welcome_picture() {
  reset_doc(800, 500, "#ffffff")
  let c = layers[0].cv
  draw_gradient(c, 0, 0, 800, 330, "#8fd3ff", "#e8f6ff")
  draw_glow(c, 640, 90, 70, "#fff6b0", "#fff6b000")
  draw_circle(c, 640, 90, 38, "#ffd84a")
  draw_ellipse(c, 200, 420, 360, 140, 0, "#5cbf4a")
  draw_ellipse(c, 640, 450, 330, 120, 0, "#4aa83c")
  draw_rect(c, 0, 400, 800, 100, "#4aa83c")
  draw_rect(c, 150, 250, 150, 120, "#f1e2c6")
  draw_poly(c, [[135, 255], [225, 185], [315, 255]], "#c0392b")
  draw_rect(c, 205, 305, 40, 65, "#7a4a2a")
  draw_rect(c, 168, 275, 28, 26, "#8fd3ff")
  draw_rect(c, 255, 275, 28, 26, "#8fd3ff")
  let l2 = new_layer("Sketch")
  draw_text(l2.cv, 400, 40, "Welcome to Kugel Paint", "#1d2027", 30, "center", "bold Segoe UI")
  draw_lines(l2.cv, [[470, 300], [500, 270], [530, 300], [560, 270], [590, 300]], "#1d2027", 4)
  push(layers, l2)
  cur = 1
}
let saved = store_get("doc", nil)
if saved != nil and type(saved) == "map" and has(saved, "n") {
  reset_doc(saved.w, saved.h, nil)
  layers = []
  for i in range(saved.n) {
    let mt = saved.meta[i]
    let l = new_layer(mt.name)
    l.vis = mt.vis
    l.op = mt.op
    let png = store_get("layer" + str(i), "")
    if png != "" { canvas_load(l.cv, png) }
    push(layers, l)
  }
  if len(layers) == 0 { layers = [new_layer("Background")] }
  cur = clamp(saved.cur, 0, len(layers) - 1)
  autosave_note = "kept on this PC"
} else { welcome_picture() }
draw_swatches()
set_tool("brush")
draw_layers()
after(60, fn() { fit_view(); draw_opts(); render() })
let last_vw = 0
let last_vh = 0
fn on_resize_fit() { every_ms(700, fn() { let s = canvas_size(view); if s.w != last_vw or s.h != last_vh { let first = last_vw == 0; last_vw = s.w; last_vh = s.h; if first { fit_view() }; render() } }) }
on_resize_fit()
