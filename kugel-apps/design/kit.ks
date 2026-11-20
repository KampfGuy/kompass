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
