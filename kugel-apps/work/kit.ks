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
