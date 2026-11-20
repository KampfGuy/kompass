# ---------------------------------------------------------------- Kugel Motion
# Frame-by-frame animation: draw each frame (brush, eraser, line, rectangle, ellipse, fill, move), onion skin,
# a shared background layer, timeline with thumbnails, play / loop at 1-30 fps, per-frame undo.
# Export animated GIF, WebM video and sprite-sheet PNG; save .kmotion. Everything stays on this PC.
let W = 480
let H = 320
let frames = []
let cur = 0
let bg_layer = nil
let on_bg = false
let tool = "brush"
let bsize = 6
let color = "#1d2027"
let fill_shapes = true
let fps = 8
let onion = true
let onion_next = false
let loop_on = true
let playing = false
let play_t = 0
let z = 1
let ox = 0
let oy = 0
let drag = nil
let undo_stack = []
let redo_stack = []
let MAX_FRAMES = 120
let doc_name = store_get("name", "My animation")
let dirty = false

let root = box(body(), "kapp kd-motion")
let holder = kd_holder(root)
let checker = nil
let tmp = nil

fn new_canvas() { return canvas(holder, W, H) }
fn reset_doc(w, h) {
  W = clamp(round(w), 16, 1024)
  H = clamp(round(h), 16, 1024)
  clear(holder)
  checker = kd_checker(holder, W, H)
  tmp = new_canvas()
  bg_layer = new_canvas()
  frames = [new_canvas()]
  cur = 0
  undo_stack = []
  redo_stack = []
}
fn target() { if on_bg { return bg_layer }; return frames[cur] }

# ---- undo: copy of the canvas being changed (frame or background) + whole-timeline entries
fn record() {
  push(undo_stack, {t: "px", c: target(), copy: kd_copy_canvas(holder, target(), W, H)})
  while len(undo_stack) > 14 { let e = remove(undo_stack, 0); if e.t == "px" { destroy(e.copy) } }
  for e in redo_stack { if e.t == "px" { destroy(e.copy) } }
  redo_stack = []
  dirty = true
}
fn record_list() {
  push(undo_stack, {t: "list", frames: slice(frames, 0), cur: cur})
  while len(undo_stack) > 14 { let e = remove(undo_stack, 0); if e.t == "px" { destroy(e.copy) } }
  redo_stack = []
  dirty = true
}
fn apply(e, other) {
  if e.t == "px" {
    push(other, {t: "px", c: e.c, copy: kd_copy_canvas(holder, e.c, W, H)})
    draw_clear(e.c)
    draw_image(e.c, e.copy, 0, 0, W, H)
    destroy(e.copy)
  } else {
    push(other, {t: "list", frames: slice(frames, 0), cur: cur})
    frames = e.frames
    cur = clamp(e.cur, 0, len(frames) - 1)
  }
  dirty = true
  draw_timeline()
  render()
}
fn undo() { if len(undo_stack) > 0 { apply(pop(undo_stack), redo_stack) } }
fn redo() { if len(redo_stack) > 0 { apply(pop(redo_stack), undo_stack) } }

# ---- UI
let bar = row(root, "kapp-bar")
label(bar, "🎞 Kugel Motion", "kapp-title")
let name_box = textbox(bar, "Name", nil, "kapp-field kd-name")
settext(name_box, doc_name)
on_input(name_box, fn(t) { doc_name = t; store_set("name", t) }, 300)
kd_btn(bar, "New", fn() { new_dialog() }, nil)
kd_btn(bar, "Open", fn() { open_file() }, nil)
settip(kd_btn(bar, "Save", fn() { save_file() }, nil), "Save as .kmotion — Ctrl+S")
kd_btn(bar, "Export…", fn() { export_dialog() }, "go")
kd_tip(bar, "↶", "Undo (Ctrl+Z)", fn() { undo() })
kd_tip(bar, "↷", "Redo (Ctrl+Y)", fn() { redo() })
let opts = row(root, "kapp-bar kd-opts")
let main = row(root, "kapp-main")
let tools_p = col(main, "kapp-panel kd-tools")
let view_wrap = box(main, "kapp-view kd-viewwrap")
let view = canvas(view_wrap)
let right = col(main, "kapp-panel right kd-right")
let tl_bar = row(root, "kd-tlbar")
let timeline = row(root, "kd-timeline")
let status = label(root, "", "kapp-status")

let TOOLS = [["brush", "🖌", "Brush (B)"], ["eraser", "⌫", "Eraser (E)"], ["line", "╱", "Line (L)"], ["rect", "▭", "Rectangle (R)"], ["ellipse", "◯", "Ellipse (O)"], ["fill", "🪣", "Fill (G)"], ["move", "✥", "Move the drawing on this frame (V)"]]
let tool_btns = {}
for t in TOOLS { let b = button(tools_p, t[1], fn() { set_tool(t[0]) }, "kapp-btn kd-tool"); settip(b, t[2]); tool_btns[t[0]] = b }
fn set_tool(t) { tool = t; for k in keys(tool_btns) { togglestyle(tool_btns[k], "on", k == t) }; draw_opts() }
fn draw_opts() {
  clear(opts)
  label(opts, upper(substr(tool, 0, 1)) + substr(tool, 1), "kd-optname")
  if tool != "fill" and tool != "move" {
    label(opts, "Size", "kapp-tiny")
    slider(opts, 1, 60, bsize, fn(v) { bsize = round(v); settext(szl, str(bsize) + " px") }, "kd-slider")
    let szl = label(opts, str(bsize) + " px", "kapp-tiny kd-val")
  }
  if tool == "rect" or tool == "ellipse" { checkbox(opts, "Filled", fill_shapes, fn(on) { fill_shapes = on }, nil) }
  checkbox(opts, "Onion skin", onion, fn(on) { onion = on; render() }, nil)
  checkbox(opts, "+ next frame", onion_next, fn(on) { onion_next = on; render() }, nil)
  let bgc = checkbox(opts, "Draw on background", on_bg, fn(on) { on_bg = on; draw_timeline(); render() }, nil)
  settip(bgc, "The background layer shows under every frame")
}
kd_sec(right, "Colour")
let picker = kd_color_panel(right, color, fn(h) { color = h })
kd_sec(right, "Playback")
let fps_row = row(right, "kd-frow")
label(fps_row, "Speed", "kd-flabel")
let fps_sl = slider(fps_row, 1, 30, fps, fn(v) { fps = round(v); settext(fps_l, str(fps) + " fps"); dirty = true }, "kd-slider")
let fps_l = label(fps_row, str(fps) + " fps", "kapp-tiny kd-val")
checkbox(right, "Loop", loop_on, fn(on) { loop_on = on }, nil)
kd_sec(right, "Frame")
let fr_tools = row(right, "kd-laytools")
kd_tip(fr_tools, "+", "New blank frame after this one (N)", fn() { add_frame(false) })
kd_tip(fr_tools, "⧉", "Duplicate this frame (D)", fn() { add_frame(true) })
kd_tip(fr_tools, "◀", "Move frame earlier", fn() { move_frame(-1) })
kd_tip(fr_tools, "▶", "Move frame later", fn() { move_frame(1) })
kd_tip(fr_tools, "🗑", "Delete frame", fn() { delete_frame() })
kd_btn(right, "Clear this frame", fn() { record(); draw_clear(target()); changed() }, "wide")
kd_btn(right, "Tween: fill in-between frames…", fn() { tween_dialog() }, "wide")

# timeline bar
let play_btn = kd_btn(tl_bar, "▶ Play", fn() { toggle_play() }, "go")
kd_tip(tl_bar, "⏮", "First frame", fn() { go_frame(0) })
kd_tip(tl_bar, "◀", "Previous frame (,)", fn() { go_frame(cur - 1) })
kd_tip(tl_bar, "▶", "Next frame (.)", fn() { go_frame(cur + 1) })
kd_tip(tl_bar, "⏭", "Last frame", fn() { go_frame(len(frames) - 1) })
let fr_label = label(tl_bar, "", "kapp-tiny kd-frlabel")

fn go_frame(i) { if len(frames) == 0 { return }; cur = clamp(i, 0, len(frames) - 1); on_bg = false; draw_timeline(); render(); draw_opts() }
fn draw_timeline() {
  clear(timeline)
  for i in range(len(frames)) {
    let idx = i
    let cell = col(timeline, "kd-frame")
    if idx == cur and not on_bg { addstyle(cell, "on") }
    let th = canvas(cell, 64, round(64 * H / W), "kd-fthumb")
    draw_image(th, checker, 0, 0, 64, round(64 * H / W))
    draw_image(th, bg_layer, 0, 0, 64, round(64 * H / W))
    draw_image(th, frames[i], 0, 0, 64, round(64 * H / W))
    label(cell, str(i + 1), "kd-fnum")
    on_click(cell, fn() { go_frame(idx) })
  }
  if len(frames) < MAX_FRAMES { let add = button(timeline, "+", fn() { add_frame(false) }, "kd-frame add"); settip(add, "New frame") }
  settext(fr_label, "Frame " + str(cur + 1) + " of " + str(len(frames)) + "   ·   " + str(round(len(frames) / fps, 2)) + " s at " + str(fps) + " fps")
}
fn refresh_thumb() { draw_timeline() }
fn add_frame(dup) {
  if len(frames) >= MAX_FRAMES { kd_toast(root, "At most " + str(MAX_FRAMES) + " frames (keeps it quick on a weak PC)"); return }
  record_list()
  let c = new_canvas()
  if dup { draw_image(c, frames[cur], 0, 0, W, H) }
  insert(frames, cur + 1, c)
  go_frame(cur + 1)
}
fn move_frame(d) {
  let j = cur + d
  if j < 0 or j >= len(frames) { return }
  record_list()
  let a = frames[cur]
  frames[cur] = frames[j]
  frames[j] = a
  go_frame(j)
}
fn delete_frame() {
  if len(frames) == 1 { record(); draw_clear(frames[0]); changed(); return }
  record_list()
  remove(frames, cur)
  go_frame(min(cur, len(frames) - 1))
}

# ---- view
fn fit_view() { let s = canvas_size(view); z = max(0.1, min(4, (s.w - 40) / W, (s.h - 40) / H)); ox = round((s.w - W * z) / 2); oy = round((s.h - H * z) / 2) }
fn to_doc(x, y) { return {x: (x - ox) / z, y: (y - oy) / z} }
fn render() {
  draw_clear(view, "#16181d")
  draw_smooth(view, true)
  draw_rect(view, ox + 4, oy + 5, W * z, H * z, "#0b0c0f")
  draw_image(view, checker, ox, oy, W * z, H * z)
  draw_image(view, bg_layer, ox, oy, W * z, H * z)
  if playing {
    draw_image(view, frames[cur], ox, oy, W * z, H * z)
  } else {
    if onion and cur > 0 and not on_bg { draw_image(view, frames[cur - 1], ox, oy, W * z, H * z, 0, 0.28) }
    if onion and cur > 1 and not on_bg { draw_image(view, frames[cur - 2], ox, oy, W * z, H * z, 0, 0.12) }
    if onion_next and cur < len(frames) - 1 and not on_bg { draw_image(view, frames[cur + 1], ox, oy, W * z, H * z, 0, 0.22) }
    if on_bg {
      for f in [frames[cur]] { draw_image(view, f, ox, oy, W * z, H * z, 0, 0.35) }
    } else {
      if drag != nil and drag.kind == "move" { draw_image(view, drag.float, ox + drag.dx * z, oy + drag.dy * z, W * z, H * z) } else { draw_image(view, frames[cur], ox, oy, W * z, H * z) }
    }
    if drag != nil and drag.kind == "brush" { draw_image(view, tmp, ox, oy, W * z, H * z) }
    if drag != nil and drag.kind == "shape" { draw_save(view); draw_translate(view, ox, oy); draw_scale(view, z); shape_on(view, drag.a, drag.b, drag.shift); draw_restore(view) }
  }
  let t = str(W) + " × " + str(H) + "   ·   frame " + str(cur + 1) + "/" + str(len(frames)) + "   ·   " + str(fps) + " fps"
  if on_bg { t = t + "   ·   drawing on the BACKGROUND layer" }
  settext(status, t)
}
fn shape_on(c, a, b, shift) {
  let x1 = b.x
  let y1 = b.y
  if shift { let d = max(abs(b.x - a.x), abs(b.y - a.y)); x1 = a.x + sign(b.x - a.x + 0.0001) * d; y1 = a.y + sign(b.y - a.y + 0.0001) * d }
  if tool == "line" { draw_line(c, a.x, a.y, b.x, b.y, color, bsize); draw_circle(c, a.x, a.y, bsize / 2, color); draw_circle(c, b.x, b.y, bsize / 2, color); return }
  let x = min(a.x, x1)
  let y = min(a.y, y1)
  let w = abs(x1 - a.x)
  let h = abs(y1 - a.y)
  if tool == "rect" { if fill_shapes { draw_rect(c, x, y, w, h, color) } else { draw_rect(c, x, y, w, h, color, bsize) } }
  if tool == "ellipse" { if fill_shapes { draw_ellipse(c, x + w / 2, y + h / 2, w / 2, h / 2, 0, color) } else { draw_ellipse(c, x + w / 2, y + h / 2, w / 2, h / 2, 0, color, bsize) } }
}
fn changed() { dirty = true; draw_timeline(); render() }

on_mouse(view, fn(e) {
  if playing { return }
  let p = to_doc(e.x, e.y)
  if e.type == "down" {
    if tool == "brush" { record(); draw_clear(tmp); draw_circle(tmp, p.x, p.y, bsize / 2, color); drag = {kind: "brush", last: p} }
    else if tool == "eraser" { record(); draw_blend(target(), "erase"); draw_circle(target(), p.x, p.y, bsize / 2, "#000000"); drag = {kind: "eraser", last: p} }
    else if tool == "fill" { record(); let n = draw_fill(target(), p.x, p.y, color, 32); if n == 0 { let e2 = pop(undo_stack); destroy(e2.copy) }; changed() }
    else if tool == "move" {
      record()
      let fl = kd_copy_canvas(holder, target(), W, H)
      draw_clear(target())
      drag = {kind: "move", p0: p, dx: 0, dy: 0, float: fl}
    }
    else { drag = {kind: "shape", a: p, b: p, shift: e.shift} }
    render()
    return
  }
  if e.type == "move" {
    if drag == nil { return }
    if drag.kind == "brush" { draw_line(tmp, drag.last.x, drag.last.y, p.x, p.y, color, bsize); draw_circle(tmp, p.x, p.y, bsize / 2, color); drag.last = p }
    else if drag.kind == "eraser" { draw_line(target(), drag.last.x, drag.last.y, p.x, p.y, "#000000", bsize); draw_circle(target(), p.x, p.y, bsize / 2, "#000000"); drag.last = p }
    else if drag.kind == "shape" { drag.b = p; drag.shift = e.shift }
    else if drag.kind == "move" { drag.dx = round(p.x - drag.p0.x); drag.dy = round(p.y - drag.p0.y) }
    render()
    return
  }
  if e.type == "up" {
    if drag == nil { return }
    let k = drag.kind
    if k == "brush" { draw_image(target(), tmp, 0, 0, W, H); draw_clear(tmp) }
    else if k == "eraser" { draw_blend(target(), "normal") }
    else if k == "shape" { if abs(drag.b.x - drag.a.x) + abs(drag.b.y - drag.a.y) >= 1 { record(); shape_on(target(), drag.a, drag.b, drag.shift) } }
    else if k == "move" { draw_image(target(), drag.float, drag.dx, drag.dy, W, H); destroy(drag.float) }
    drag = nil
    changed()
  }
})

# ---- playback
fn toggle_play() {
  playing = not playing
  if playing { settext(play_btn, "⏸ Stop"); play_t = 0 } else { settext(play_btn, "▶ Play"); draw_timeline() }
  render()
}
on_frame(fn(dt) {
  if not playing { return }
  play_t += dt
  if play_t >= 1 / fps {
    play_t = 0
    if cur + 1 >= len(frames) { if loop_on { cur = 0 } else { toggle_play(); return } } else { cur += 1 }
    render()
    settext(fr_label, "Frame " + str(cur + 1) + " of " + str(len(frames)))
  }
})

# ---- tween: blend in-between frames from this frame to a later one (cross-fade + optional slide)
fn tween_dialog() {
  let d = kd_dialog(root, "Tween")
  label(d.box, "Adds frames between this frame and the next one that fade (and optionally slide) from one drawing to the other.", "kapp-tiny")
  let n = kd_field(d.box, "Frames to add", 3, nil)
  let dx = kd_field(d.box, "Slide X (px)", 0, nil)
  let dy = kd_field(d.box, "Slide Y (px)", 0, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Add frames", fn() {
    let cnt = round(kd_num(n, 3, 1, 30))
    let sx = kd_num(dx, 0, -2000, 2000)
    let sy = kd_num(dy, 0, -2000, 2000)
    d.close()
    if cur >= len(frames) - 1 and sx == 0 and sy == 0 { kd_toast(root, "Add a next frame first, or set a slide"); return }
    if len(frames) + cnt > MAX_FRAMES { kd_toast(root, "That would go over " + str(MAX_FRAMES) + " frames"); return }
    record_list()
    let a = frames[cur]
    let b = nil
    if cur < len(frames) - 1 { b = frames[cur + 1] }
    for i in range(1, cnt + 1) {
      let t = i / (cnt + 1)
      let c = new_canvas()
      draw_image(c, a, sx * t, sy * t, W, H, 0, 1 - t * 0.999 * (b != nil and 1 or 0))
      if b != nil { draw_image(c, b, sx * t - sx, sy * t - sy, W, H, 0, t) }
      insert(frames, cur + i, c)
    }
    changed()
    kd_toast(root, "Added " + str(cnt) + " frames")
  }, "on")
}

# ---- export
fn composite(i) { let c = new_canvas(); draw_clear(c, export_bg); draw_image(c, bg_layer, 0, 0, W, H); draw_image(c, frames[i], 0, 0, W, H); return c }
let export_bg = "#ffffff"
fn export_dialog() {
  if playing { toggle_play() }
  let d = kd_dialog(root, "Export animation")
  let fr = row(d.box, "kd-frow")
  label(fr, "Background", "kd-flabel")
  let bgd = dropdown(fr, ["White", "Black", "Main colour"], nil, nil)
  fn pick_bg() { let v = getvalue(bgd); export_bg = "#ffffff"; if v == "Black" { export_bg = "#000000" } else if v == "Main colour" { export_bg = color } }
  let r = col(d.box, "kd-drow")
  kd_btn(r, "Animated GIF (.gif)", fn() { pick_bg(); d.close(); export_gif() }, "on")
  kd_btn(r, "Video (.webm)", fn() { pick_bg(); d.close(); export_webm() }, nil)
  kd_btn(r, "Sprite sheet (.png) — all frames in a grid, for games", fn() { pick_bg(); d.close(); export_sheet() }, nil)
  kd_btn(r, "This frame (.png)", fn() { pick_bg(); d.close(); let c = composite(cur); let res = file_save(kd_safe_name(doc_name) + " frame " + str(cur + 1) + ".png", canvas_data(c)); destroy(c); if res.ok { kd_toast(root, "Exported " + res.name) } }, nil)
}
fn export_gif() {
  if W > 1024 or H > 1024 { kd_toast(root, "GIFs can be at most 1024 px"); return }
  let t = kd_toast(root, "Making the GIF…")
  let list = []
  for i in range(len(frames)) { push(list, composite(i)) }
  let url = gif_encode(list, W, H, round(1000 / fps), loop_on)
  for c in list { destroy(c) }
  let r = file_save(kd_safe_name(doc_name) + ".gif", url)
  if r.ok { kd_toast(root, "Exported " + r.name + " (" + str(round(r.bytes / 1024)) + " KB)") }
}
fn export_sheet() {
  let n = len(frames)
  let cols = min(n, max(1, floor(4096 / W)), ceil(sqrt(n)))
  let rows = ceil(n / cols)
  if rows * H > 4096 { kd_toast(root, "Too many frames for one sheet"); return }
  let sh = canvas(holder, cols * W, rows * H)
  for i in range(n) { let c = composite(i); draw_image(sh, c, (i % cols) * W, floor(i / cols) * H, W, H); destroy(c) }
  let r = file_save(kd_safe_name(doc_name) + " sheet " + str(cols) + "x" + str(rows) + ".png", canvas_data(sh))
  destroy(sh)
  if r.ok { kd_toast(root, "Exported " + r.name + " — " + str(n) + " frames of " + str(W) + "×" + str(H)) }
}
fn export_webm() {
  let d = kd_dialog(root, "Recording video…")
  let k = min(1, 560 / W, 360 / H)
  let pv = canvas(d.box, round(W * k), round(H * k))
  label(d.box, "Plays the animation once" + (loop_on and " (twice when it is short)" or "") + " while it records.", "kapp-tiny")
  let n = len(frames)
  let secs = n / fps
  if secs < 1.5 { secs = secs * 2 }
  secs = clamp(secs, 0.5, 60)
  let i = 0
  let comps = []
  for j in range(n) { push(comps, composite(j)) }
  fn show() { draw_clear(pv, export_bg); draw_image(pv, comps[i % n], 0, 0, round(W * k), round(H * k)); i += 1 }
  show()
  let timer = every_ms(max(16, round(1000 / fps)), fn() { show() })
  let url = canvas_record(pv, secs, max(fps, 12))
  cancel_timer(timer)
  for c in comps { destroy(c) }
  d.close()
  let r = file_save(kd_safe_name(doc_name) + ".webm", url)
  if r.ok { kd_toast(root, "Exported " + r.name + " (" + str(round(r.bytes / 1024)) + " KB)") }
}

# ---- files
fn kmotion_json() {
  let fl = []
  for f in frames { push(fl, canvas_data(f)) }
  return json({app: "Kugel Motion", version: 1, w: W, h: H, fps: fps, loop: loop_on, background: canvas_data(bg_layer), frames: fl})
}
fn load_kmotion(text, nm) {
  let d = parse_json(text)
  if d == nil or type(d) != "map" or not has(d, "frames") { kd_toast(root, "That is not a Kugel Motion file"); return }
  reset_doc(d.w, d.h)
  canvas_load(bg_layer, d.background)
  frames = []
  for u in slice(d.frames, 0, MAX_FRAMES) { let c = new_canvas(); canvas_load(c, u); push(frames, c) }
  if len(frames) == 0 { frames = [new_canvas()] }
  fps = d.fps
  loop_on = d.loop
  setvalue(fps_sl, fps)
  settext(fps_l, str(fps) + " fps")
  doc_name = replace(nm, ".kmotion", "")
  settext(name_box, doc_name)
  store_set("name", doc_name)
  fit_view()
  go_frame(0)
}
fn open_file() {
  let f = file_open(["kmotion", "png", "gif", "jpg", "webp"])
  if f == nil { return }
  if f.ext == "kmotion" { load_kmotion(f.text, f.name); return }
  # a picture goes onto the background layer (trace over it)
  on_bg = true
  record()
  draw_smooth(bg_layer, true)
  let info = load_image(f.data)
  if info.ok { let s = min(W / info.w, H / info.h); draw_image(bg_layer, f.data, round((W - info.w * s) / 2), round((H - info.h * s) / 2), round(info.w * s), round(info.h * s)) }
  on_bg = false
  changed()
  kd_toast(root, "Put " + f.name + " on the background layer")
}
fn save_file() { let r = file_save(kd_safe_name(doc_name) + ".kmotion", kmotion_json()); if r.ok { kd_toast(root, "Saved " + r.name) } }
fn new_dialog() {
  let d = kd_dialog(root, "New animation")
  let pr = row(d.box, "kd-drow")
  let tw = nil
  let th = nil
  for s in [[480, 320, "Default"], [640, 360, "Wide"], [320, 320, "Square"], [128, 128, "Game sprite"], [64, 64, "Small sprite"]] { kd_btn(pr, s[2], fn() { settext(tw, str(s[0])); settext(th, str(s[1])) }, nil) }
  tw = kd_field(d.box, "Width", W, nil)
  th = kd_field(d.box, "Height", H, nil)
  let r = row(d.box, "kd-drow")
  kd_btn(r, "Create", fn() {
    let nw = kd_num(tw, 480, 16, 1024)
    let nh = kd_num(th, 320, 16, 1024)
    d.close()
    reset_doc(nw, nh)
    doc_name = "My animation"
    settext(name_box, doc_name)
    if nw <= 128 { bsize = 2 }
    fit_view()
    draw_opts()
    go_frame(0)
  }, "on")
}

# ---- autosave (small animations only; bigger: Save .kmotion)
every_ms(5000, fn() {
  if not dirty or playing { return }
  dirty = false
  let j = kmotion_json()
  if len(j) < 190000 { store_set("anim", j); settext(status, gettext(status) + "   ·   kept on this PC") }
})

on_keypress(fn(k) {
  if key_down("control") {
    if k == "z" { undo() } else if k == "y" { redo() } else if k == "s" { save_file() }
    return
  }
  let m = {"b": "brush", "e": "eraser", "l": "line", "r": "rect", "o": "ellipse", "g": "fill", "v": "move"}
  if has(m, k) { set_tool(m[k]); return }
  if k == "space" { toggle_play() } else if k == "," or k == "left" { go_frame(cur - 1) } else if k == "." or k == "right" { go_frame(cur + 1) }
  else if k == "n" { add_frame(false) } else if k == "d" { add_frame(true) }
})

# ---- start: last animation (kept on this PC) or a bouncing-ball sample
fn sample() {
  reset_doc(480, 320)
  draw_gradient(bg_layer, 0, 0, W, 250, "#bfe6ff", "#f2fbff")
  draw_rect(bg_layer, 0, 250, W, 70, "#6cc04a")
  draw_rect(bg_layer, 0, 250, W, 6, "#4fa333")
  frames = []
  let ys = [40, 80, 140, 205, 228, 205, 140, 80]
  for i in range(len(ys)) {
    let c = new_canvas()
    let y = ys[i]
    let sq = 1
    if y >= 228 { sq = 0.7 }
    let x = 90 + i * 40
    draw_ellipse(c, x, 268, 26 * (1.2 - y / 400), 6, 0, "#00000033")
    draw_ellipse(c, x, y, 22 / sq * 0.95, 22 * sq, 0, "#ff5a36")
    draw_circle(c, x - 7, y - 8 * sq, 6, "#ffffff88")
    push(frames, c)
  }
  draw_text(bg_layer, 12, 18, "Bouncing ball — press ▶ Play", "#33415588", 14)
}
let saved = store_get("anim", "")
if saved != "" { load_kmotion(saved, store_get("name", "My animation") + ".kmotion") } else { sample() }
set_tool("brush")
draw_timeline()
let last_vw = 0
let last_vh = 0
every_ms(700, fn() { let s = canvas_size(view); if s.w != last_vw or s.h != last_vh { last_vw = s.w; last_vh = s.h; fit_view(); render() } })
after(60, fn() { fit_view(); render() })
