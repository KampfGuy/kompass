# ============================================================================================
#  Block editor shared by Kugel Blocks and Kugel Blocks 3D (built into one store app each by
#  tools/build-blocks.js). Blocks are drawn on a canvas; scripts compile to readable KampfScript
#  that runs with the game runtime (RUNTIME_SRC) in its own sandbox when you press the green flag.
# ============================================================================================
let E = {proj: nil, cur: 0, cat: "events", cv: nil, PW: 236, sx: -20, sy: -20, Z: 1, pal_sy: 0, hits: [], phits: [], dhits: [],
  drag: nil, snap: nil, pending: nil, pan: nil, edit: nil, app: nil, running: false, undo: [], redo: [], tab: "code", dirty: true,
  pal_blocks: [], pal_heads: [], name: "My game", flash_t: 0, saved_json: "", last_err: ""}
let SPEC = {}
let CATC = {}
let TW = {}
fn css(el, m) { for k, v in m { setstyle(el, k, v) } }
fn btn(p, text, f, tip, st) {
  let b = button(p, text, f, st or "kapp-btn")
  if tip != nil { settip(b, tip) }
  return b
}
fn deep(x) { return parse_json(json(x)) }
fn kq(s) { return "\"" + replace(replace(replace(replace(str(s), "\\", "\\\\"), "\"", "\\\""), "\n", "\\n"), "\r", "") + "\"" }
fn tw(t) {
  let w = TW[t]
  if w == nil {
    w = text_width(t, 12)
    if len(TW) > 3000 { TW = {} }
    TW[t] = w
  }
  return w
}
fn darker(hex, k) {
  return rgb_hex(floor(hex_to_r(hex) * k), floor(hex_to_g(hex) * k), floor(hex_to_b(hex) * k))
}
fn hexd(c) { return indexof("0123456789abcdef", lower(c)) }
fn hex_to_r(h) { return hexd(h[1]) * 16 + hexd(h[2]) }
fn hex_to_g(h) { return hexd(h[3]) * 16 + hexd(h[4]) }
fn hex_to_b(h) { return hexd(h[5]) * 16 + hexd(h[6]) }
fn h2(n) { let d = "0123456789abcdef"; n = clamp(floor(n), 0, 255); return d[floor(n / 16)] + d[n % 16] }
fn rgb_hex(r, g, b) { return "#" + h2(r) + h2(g) + h2(b) }
fn ident(s) {
  let out = ""
  for ch in str(s) {
    if indexof("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_", ch) >= 0 { out += ch } else { out += "_" }
  }
  if out == "" { out = "x" }
  return out
}

# ---------------------------------------------------------------- the spec (parts of each block)
fn parse_parts(text) {
  let parts = []
  let run = ""
  let si = 0
  for w in split(text, " ") {
    if startswith(w, "%") and len(w) >= 2 {
      if run != "" { push(parts, {t: run}); run = "" }
      let kind = w[1]
      let menu = nil
      if len(w) > 3 and w[2] == "." { menu = substr(w, 3) }
      if kind == "v" { menu = "var" }
      if kind == "l" { menu = "list" }
      push(parts, {kind: kind, menu: menu, i: si})
      si += 1
    } else {
      if run == "" { run = w } else { run += " " + w }
    }
  }
  if run != "" { push(parts, {t: run}) }
  return parts
}
for c in CATS { CATC[c.id] = {color: c.color, dark: darker(c.color, 0.78), label: c.label} }
CATC["custom"] = {color: "#ff6680", dark: darker("#ff6680", 0.78), label: "My Blocks"}
for row_ in SPEC_LIST {
  SPEC[row_[0]] = {op: row_[0], cat: row_[1], shape: row_[2], text: row_[3], defaults: row_[4], code: row_[5], flags: row_[6], parts: parse_parts(row_[3])}
}

# ---------------------------------------------------------------- project helpers
fn cur_target() { return E.proj.targets[E.cur] }
fn stage_target() { return E.proj.targets[0] }
fn sprite_names() { let out = []; for t in E.proj.targets { if not t.is_stage { push(out, t.name) } }; return out }
fn all_vars() {
  let out = []
  for k, v in E.proj.vars { push(out, k) }
  for k, v in cur_target().vars { push(out, k) }
  return out
}
fn all_lists() {
  let out = []
  for k, v in E.proj.lists { push(out, k) }
  for k, v in cur_target().lists { push(out, k) }
  return out
}
fn find_proc(t, name) { for p in t.procs { if p.name == name { return p } }; return nil }
fn spec_of(b) {
  let s = SPEC[b.op]
  if s != nil { return s }
  if b.op == "var" { return {shape: "rep", cat: "variables"} }
  if b.op == "listv" { return {shape: "rep", cat: "lists"} }
  if b.op == "param" { return {shape: "rep", cat: "custom"} }
  if b.op == "define" { return {shape: "hat", cat: "custom"} }
  if b.op == "call" { return {shape: "stack", cat: "custom"} }
  return {shape: "stack", cat: "control"}
}
fn parts_of(b) {
  let s = SPEC[b.op]
  if s != nil { return s.parts }
  if b.op == "var" or b.op == "listv" or b.op == "param" { return [{t: b.name}] }
  if b.op == "define" {
    let ps = [{t: "define"}, {t: b.name}]
    for p in b.params or [] { push(ps, {t: "(" + p + ")"}) }
    return ps
  }
  if b.op == "call" {
    let ps = [{t: b.name}]
    let i = 0
    for p in b.params or [] { push(ps, {kind: "s", menu: nil, i: i}); i += 1 }
    return ps
  }
  return [{t: b.op}]
}
fn menu_items(menu) {
  if menu == "var" { return all_vars() }
  if menu == "list" { return all_lists() }
  if menu == "msg" { return E.proj.msgs }
  let d = dyn_menu(menu)
  if d != nil { return d }
  let m = MENUS[menu]
  if m == nil { return [] }
  return m
}
fn new_block(op) {
  let s = SPEC[op]
  let b = {op: op, args: []}
  for i, d in s.defaults {
    let v = d
    if type(d) == "string" and startswith(d, "@") {
      v = menu_default(d)
      if v == nil {
        if d == "@var" { let vs = all_vars(); if len(vs) > 0 { v = vs[0] } else { v = "" } }
        if d == "@list" { let ls = all_lists(); if len(ls) > 0 { v = ls[0] } else { v = "" } }
        if d == "@msg" { if len(E.proj.msgs) == 0 { push(E.proj.msgs, "message1") }; v = E.proj.msgs[0] }
      }
    }
    push(b.args, v)
  }
  let nslots = 0
  for p in s.parts { if p.t == nil { nslots += 1 } }
  while len(b.args) < nslots { push(b.args, "") }
  if s.shape == "c" or s.shape == "c2" or s.shape == "ccap" { b.sub = [] }
  if s.shape == "c2" { b.sub2 = [] }
  return b
}
fn is_c(sh) { return sh == "c" or sh == "c2" or sh == "ccap" }
fn is_value(sh) { return sh == "rep" or sh == "num" or sh == "bool" }
fn is_capb(sh) { return sh == "cap" or sh == "ccap" }

# ---------------------------------------------------------------- measuring & placing blocks
fn measure(b) {
  let sp = spec_of(b)
  let sh = sp.shape
  let x = 8
  if sh == "bool" { x = 12 }
  if sh == "rep" or sh == "num" { x = 10 }
  let hmax = 16
  let ps = []
  for p in parts_of(b) {
    if p.t != nil {
      let w = tw(p.t)
      push(ps, {k: "t", x: x, w: w, t: p.t})
      x += w + 6
    } else {
      let a = b.args[p.i]
      if type(a) == "map" {
        measure(a)
        push(ps, {k: "r", x: x, w: a._w, h: a._h, i: p.i})
        x += a._w + 6
        hmax = max(hmax, a._h)
      } else {
        let disp = kb_disp(a)
        let w = max(26, tw(disp) + 14)
        if p.menu != nil { w = tw(disp) + 26 }
        if p.kind == "b" { w = 34 }
        push(ps, {k: "s", x: x, w: w, h: 20, i: p.i, kind: p.kind, menu: p.menu, t: disp})
        x += w + 6
        hmax = max(hmax, 20)
      }
    }
  }
  let w = x - 6 + 8
  if sh == "bool" { w = x - 6 + 12 }
  if sh == "rep" or sh == "num" { w = x - 6 + 10 }
  b._ps = ps
  if is_value(sh) {
    b._w = max(w, 30)
    b._h = max(24, hmax + 6)
    b._t = b._h
    b._cy = b._h / 2
    return
  }
  let top = max(36, hmax + 12)
  b._w = max(w, 60)
  if sh == "hat" {
    b._t = top + 16
    b._h = b._t
    b._cy = 16 + top / 2
    b._w = max(b._w, 100)
    return
  }
  b._t = top
  b._cy = top / 2
  if is_c(sh) {
    let s1 = max(22, measure_stack(b.sub))
    b._sy = top
    if sh == "c2" {
      let s2 = max(22, measure_stack(b.sub2))
      b._ey = top + s1
      b._s2y = top + s1 + 26
      b._h = top + s1 + 26 + s2 + 20
    } else {
      b._h = top + s1 + 20
    }
    b._w = max(b._w, 110)
    return
  }
  b._h = top
}
fn kb_disp(a) {
  if a == nil { return "" }
  if type(a) == "number" { if a == floor(a) { return str(a) } return str(round(a, 4)) }
  return str(a)
}
fn measure_stack(list) {
  let h = 0
  for b in list { measure(b); h += b._h }
  return h
}
fn stack_w(list) {
  let w = 0
  for b in list {
    w = max(w, b._w)
    if b.sub != nil { w = max(w, 16 + stack_w(b.sub)) }
    if b.sub2 != nil { w = max(w, 16 + stack_w(b.sub2)) }
  }
  return w
}
fn hat_text(b) {
  let out = []
  for p in parts_of(b) {
    if p.t != nil { push(out, p.t) } else {
      let a = b.args[p.i]
      if type(a) == "map" { push(out, "(…)") } else { push(out, kb_disp(a)) }
    }
  }
  return join(out, " ")
}
fn place(b, x, y, hits, list, idx, parent, slot) {
  b._x = x
  b._y = y
  push(hits, {k: "b", b: b, x: x, y: y, w: b._w, h: b._t, list: list, idx: idx, parent: parent, slot: slot})
  for p in b._ps {
    if p.k == "s" { push(hits, {k: "s", b: b, i: p.i, x: x + p.x, y: y + b._cy - 10, w: p.w, h: 20, kind: p.kind, menu: p.menu}) }
    if p.k == "r" {
      let a = b.args[p.i]
      place(a, x + p.x, y + b._cy - a._h / 2, hits, nil, nil, b, p.i)
    }
  }
  if b.sub != nil { place_stack(b.sub, x + 16, y + b._sy, hits) }
  if b.sub2 != nil { place_stack(b.sub2, x + 16, y + b._s2y, hits) }
}
fn place_stack(list, x, y, hits) {
  for i, b in list {
    place(b, x, y, hits, list, i, nil, nil)
    y += b._h
  }
}
fn relayout() {
  E.hits = []
  for s in cur_target().scripts {
    measure_stack(s.blocks)
    place_stack(s.blocks, s.x, s.y, E.hits)
  }
  E.dirty = true
}

# ---------------------------------------------------------------- drawing blocks
fn draw_block(c, b) {
  if b._x == nil or b._ps == nil { return }
  let sp = spec_of(b)
  let sh = sp.shape
  let cc = CATC[sp.cat]
  if cc == nil { cc = CATC["control"] }
  let x = b._x
  let y = b._y
  let fill = cc.color
  let edge = cc.dark
  if b._hl { fill = "#ffffff"; edge = cc.color }
  if sh == "rep" or sh == "num" {
    draw_round_rect(c, x, y, b._w, b._h, b._h / 2, fill)
    draw_round_rect(c, x, y, b._w, b._h, b._h / 2, edge, 1)
  }
  elif_bool(c, b, sh, x, y, fill, edge)
  if sh == "hat" {
    draw_ellipse(c, x + 42, y + 18, 40, 16, 0, fill)
    draw_round_rect(c, x, y + 14, b._w, b._t - 14, 5, fill)
    draw_ellipse(c, x + 42, y + 18, 40, 16, 0, edge, 1)
    draw_round_rect(c, x, y + 14, b._w, b._t - 14, 5, edge, 1)
    draw_rect(c, x + 3, y + 15, 78, 8, fill)
  }
  if sh == "stack" or sh == "cap" {
    draw_round_rect(c, x, y, b._w, b._t, 5, fill)
    draw_round_rect(c, x, y, b._w, b._t, 5, edge, 1)
  }
  if is_c(sh) {
    draw_rect(c, x, y + 4, 16, b._h - 8, fill)
    draw_round_rect(c, x, y, b._w, b._t, 5, fill)
    draw_round_rect(c, x, y + b._h - 20, max(80, b._w * 0.6), 20, 5, fill)
    if sh == "c2" {
      draw_round_rect(c, x, y + b._ey, max(80, b._w * 0.6), 26, 5, fill)
      draw_text(c, x + 10, y + b._ey + 13, "else", "#ffffff", 12)
    }
    draw_line(c, x + 0.5, y + 4, x + 0.5, y + b._h - 4, edge, 1)
    draw_line(c, x + 16, y + b._t, x + 16, y + b._h - 20, edge, 1)
    draw_line(c, x + 16, y + b._t, x + b._w - 4, y + b._t, edge, 1)
    draw_line(c, x + 16, y + b._h - 20, x + max(80, b._w * 0.6) - 4, y + b._h - 20, edge, 1)
    draw_line(c, x + 2, y + b._h, x + max(80, b._w * 0.6) - 4, y + b._h, edge, 1)
    if is_capb(sh) { draw_text(c, x + max(80, b._w * 0.6) - 18, y + b._h - 10, "↻", "#ffffff", 12) }
  }
  if not is_value(sh) and sh != "hat" { draw_rect(c, x + 14, y, 18, 3, edge) }
  if not is_value(sh) and not is_capb(sh) {
    draw_round_rect(c, x + 14, y + b._h - 1, 18, 5, 2, fill)
  }
  let tc = "#ffffff"
  if b._hl { tc = cc.dark }
  for p in b._ps {
    let px = x + p.x
    let py = y + b._cy
    if p.k == "t" { draw_text(c, px, py, p.t, tc, 12) }
    if p.k == "s" {
      if p.menu != nil {
        let mc = cc.dark
        if p.kind == "d" { mc = darker(cc.color, 0.88) }
        draw_round_rect(c, px, py - 10, p.w, 20, 4, mc)
        draw_text(c, px + 7, py, p.t, "#ffffff", 12)
        draw_text(c, px + p.w - 13, py, "▾", "#ffffff", 10)
      }
      elif_slot(c, p, px, py, cc)
    }
    if p.k == "r" { draw_block(c, b.args[p.i]) }
  }
  if b.sub != nil { for s in b.sub { draw_block(c, s) } }
  if b.sub2 != nil { for s in b.sub2 { draw_block(c, s) } }
}
fn elif_bool(c, b, sh, x, y, fill, edge) {
  if sh != "bool" { return }
  let h = b._h
  let pts = [[x, y + h / 2], [x + h / 2, y], [x + b._w - h / 2, y], [x + b._w, y + h / 2], [x + b._w - h / 2, y + h], [x + h / 2, y + h]]
  draw_poly(c, pts, fill)
  draw_poly(c, pts + [[x, y + h / 2]], edge, 1)
}
fn elif_slot(c, p, px, py, cc) {
  if p.menu != nil { return }
  if p.kind == "b" {
    let pts = [[px, py], [px + 9, py - 9], [px + p.w - 9, py - 9], [px + p.w, py], [px + p.w - 9, py + 9], [px + 9, py + 9]]
    draw_poly(c, pts, cc.dark)
    return
  }
  let r = 4
  if p.kind == "n" { r = 10 }
  draw_round_rect(c, px, py - 10, p.w, 20, r, "#ffffff")
  draw_text(c, px + p.w / 2, py, p.t, "#575e75", 12, "center")
}
fn draw_stack(c, list) { for b in list { draw_block(c, b) } }

# ---------------------------------------------------------------- palette
fn pal_allowed(s) {
  let t = cur_target()
  if s.flags == "s" and t.is_stage { return false }
  if s.flags == "st" and not t.is_stage { return false }
  return true
}
fn build_palette() {
  let list = []
  let heads = []
  let y = 12
  for c in CATS {
    if c.id == "myblocks" { continue }
    push(heads, {t: c.label, y: y, color: c.color, cat: c.id})
    y += 22
    let any_ = false
    if c.id == "variables" {
      for v in all_vars() { push(list, {b: {op: "var", name: v, args: []}, y: y}); y += 30 }
    }
    if c.id == "lists" {
      for v in all_lists() { push(list, {b: {op: "listv", name: v, args: []}, y: y}); y += 30 }
    }
    for row_ in SPEC_LIST {
      let s = SPEC[row_[0]]
      if s.cat != c.id or not pal_allowed(s) { continue }
      if (c.id == "variables" and len(all_vars()) == 0) or (c.id == "lists" and len(all_lists()) == 0) { continue }
      let b = new_block(s.op)
      measure(b)
      push(list, {b: b, y: y})
      y += b._h + 8
      if s.shape == "hat" { y += 2 }
    }
    if c.id == "variables" and len(all_vars()) == 0 { push(heads, {t: "(make a variable first)", y: y, small: true}); y += 22 }
    if c.id == "lists" and len(all_lists()) == 0 { push(heads, {t: "(make a list first)", y: y, small: true}); y += 22 }
    y += 10
    if c.id == "lists" {
      push(heads, {t: "My Blocks", y: y, color: "#ff6680", cat: "myblocks"})
      y += 22
      for p in cur_target().procs {
        let cb_ = {op: "call", name: p.name, params: p.params, args: map(p.params, fn(x) { return "" })}
        push(list, {b: cb_, y: y}); y += 44
        for pn in p.params { push(list, {b: {op: "param", name: pn, args: []}, y: y}); y += 30 }
      }
      if len(cur_target().procs) == 0 { push(heads, {t: "(make a block first)", y: y, small: true}); y += 22 }
      y += 10
    }
  }
  for it in list { measure(it.b) }
  E.pal_blocks = list
  E.pal_heads = heads
  E.pal_h = y
  E.dirty = true
}
fn pal_scroll_to(cat) {
  for h in E.pal_heads { if h.cat == cat { E.pal_sy = max(0, h.y - 6) } }
  E.cat = cat
  E.dirty = true
}

# ---------------------------------------------------------------- drawing the whole editor canvas
fn draw_editor() {
  let c = E.cv
  let cs = canvas_size(c)
  E.W = cs.w
  E.H = cs.h
  draw_clear(c, "#f9f9fb")
  # workspace grid dots
  draw_save(c)
  draw_translate(c, E.PW, 0)
  draw_scale(c, E.Z)
  draw_translate(c, -E.sx, -E.sy)
  let gx0 = floor(E.sx / 40) * 40
  let gy0 = floor(E.sy / 40) * 40
  let gx = gx0
  while gx < E.sx + (E.W - E.PW) / E.Z + 40 {
    let gy = gy0
    while gy < E.sy + E.H / E.Z + 40 { draw_rect(c, gx, gy, 2, 2, "#e1e3ea"); gy += 40 }
    gx += 40
  }
  for s in cur_target().scripts { draw_stack(c, s.blocks) }
  if E.snap != nil {
    let sn = E.snap
    if sn.type == "slot" {
      draw_round_rect(c, sn.x - 2, sn.y - 2, sn.w + 4, sn.h + 4, 8, "rgba(255,255,255,0.0)")
      draw_round_rect(c, sn.x - 2, sn.y - 2, sn.w + 4, sn.h + 4, 8, "#ffffff", 3)
      draw_round_rect(c, sn.x - 3, sn.y - 3, sn.w + 6, sn.h + 6, 9, "#ffab19", 1.5)
    } else {
      draw_round_rect(c, sn.x, sn.y - 3, max(80, stack_w(E.drag.blocks)), 6, 3, "rgba(70,80,110,0.55)")
    }
  }
  if E.drag != nil and not E.drag.over_pal { draw_alpha(c, 0.92); draw_stack(c, E.drag.blocks); draw_alpha(c, 1) }
  draw_restore(c)
  # palette
  draw_rect(c, 0, 0, E.PW, E.H, "#ffffff")
  draw_line(c, E.PW - 0.5, 0, E.PW - 0.5, E.H, "#dfe1e8", 1)
  draw_save(c)
  draw_translate(c, 0, -E.pal_sy)
  for h in E.pal_heads {
    if h.y - E.pal_sy > E.H + 40 or h.y - E.pal_sy < -60 { continue }
    if h.small { draw_text(c, 14, h.y + 8, h.t, "#9aa1b2", 11.5) } else {
      draw_circle(c, 18, h.y + 8, 6, h.color)
      draw_text(c, 30, h.y + 8, h.t, "#575e75", 13)
    }
  }
  for it in E.pal_blocks {
    if it.y - E.pal_sy > E.H + 40 or it.y - E.pal_sy + 60 < 0 { continue }
    let b = it.b
    place(b, 12, it.y, [], nil, nil, nil, nil)
    draw_block(c, b)
  }
  draw_restore(c)
  if E.drag != nil and E.drag.over_pal {
    draw_save(c)
    draw_translate(c, E.PW, 0)
    draw_scale(c, E.Z)
    draw_translate(c, -E.sx, -E.sy)
    draw_alpha(c, 0.45)
    draw_stack(c, E.drag.blocks)
    draw_alpha(c, 1)
    draw_restore(c)
    draw_text(c, E.PW / 2, E.H / 2, "🗑 drop to delete", "#d9473f", 14, "center")
  }
}
fn to_world(x, y) { return {x: (x - E.PW) / E.Z + E.sx, y: y / E.Z + E.sy} }
fn to_screen(x, y) { return {x: E.PW + (x - E.sx) * E.Z, y: (y - E.sy) * E.Z} }
fn hit_at(hits, x, y) {
  let i = len(hits) - 1
  while i >= 0 {
    let h = hits[i]
    if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h { return h }
    i -= 1
  }
  return nil
}
fn pal_hit(x, y) {
  let yy = y + E.pal_sy
  let i = len(E.pal_blocks) - 1
  while i >= 0 {
    let it = E.pal_blocks[i]
    let b = it.b
    if x >= 12 and x <= 12 + b._w and yy >= it.y and yy <= it.y + b._h { return it }
    i -= 1
  }
  return nil
}

# ---------------------------------------------------------------- undo
fn clean(x) {
  if type(x) == "list" { return map(x, fn(v) { return clean(v) }) }
  if type(x) == "map" {
    let out = {}
    for k, v in x { if not startswith(k, "_") { out[k] = clean(v) } }
    return out
  }
  return x
}
fn remember() {
  push(E.undo, {cur: E.cur, scripts: json(clean(cur_target().scripts)), procs: json(cur_target().procs)})
  if len(E.undo) > 40 { remove(E.undo, 0) }
  E.redo = []
  E.changed = true
}
fn undo_step(back) {
  let from = E.undo
  let to = E.redo
  if not back { from = E.redo; to = E.undo }
  if len(from) == 0 { flash("Nothing to undo"); return }
  let st = pop(from)
  if st.cur >= len(E.proj.targets) { return }
  E.cur = st.cur
  push(to, {cur: E.cur, scripts: json(clean(cur_target().scripts)), procs: json(cur_target().procs)})
  cur_target().scripts = parse_json(st.scripts)
  cur_target().procs = parse_json(st.procs)
  refresh_target()
}

# ---------------------------------------------------------------- mouse on the code canvas
fn detach(h) {
  remember()
  if h.parent != nil {
    let sp = SPEC[h.parent.op]
    let d = ""
    if sp != nil and h.slot < len(sp.defaults) { d = sp.defaults[h.slot]; if type(d) == "string" and startswith(d, "@") { d = "" } }
    h.parent.args[h.slot] = d
    return [h.b]
  }
  let list = h.list
  let out = slice(list, h.idx)
  while len(list) > h.idx { pop(list) }
  # a script whose blocks all left disappears
  cur_target().scripts = filter(cur_target().scripts, fn(s) { return len(s.blocks) > 0 })
  return out
}
fn script_of(list) { for s in cur_target().scripts { if s.blocks == list { return s } }; return nil }
fn start_drag(blocks, gx, gy, ox, oy, from_pal) {
  for b in blocks { clear_hl(b) }
  E.drag = {blocks: blocks, ox: ox, oy: oy, from_pal: from_pal, over_pal: false}
  relayout()
  drag_to(gx, gy)
}
fn clear_hl(b) { b._hl = false }
fn drag_to(sx_, sy_) {
  let d = E.drag
  let w = to_world(sx_, sy_)
  measure_stack(d.blocks)
  E.dhits = []
  place_stack(d.blocks, w.x - d.ox, w.y - d.oy, E.dhits)
  d.over_pal = sx_ < E.PW
  E.snap = nil
  if not d.over_pal { E.snap = find_snap() }
  E.dirty = true
}
fn find_snap() {
  let d = E.drag
  let first = d.blocks[0]
  let fsh = spec_of(first).shape
  let x0 = first._x
  let y0 = first._y
  let best = nil
  let bd = 48   # generous, like Scratch: kids should not have to be pixel-perfect
  if is_value(fsh) {
    let cx = x0
    let cy = y0 + first._h / 2
    for h in E.hits {
      let ok = false
      if h.k == "s" and h.menu == nil and (h.kind != "b" or fsh == "bool") { ok = true }
      if h.k == "s" and h.kind == "d" { ok = true }
      if h.k == "b" and h.parent != nil {
        let pk = slot_kind(h.parent, h.slot)
        if pk != "b" or fsh == "bool" { ok = true }
      }
      if not ok { continue }
      let dx = 0
      if cx < h.x { dx = h.x - cx }
      if cx > h.x + h.w { dx = cx - h.x - h.w }
      let dy = 0
      if cy < h.y { dy = h.y - cy }
      if cy > h.y + h.h { dy = cy - h.y - h.h }
      let dd = dx + dy
      if dd < 14 and dd <= bd {
        bd = dd
        let tb = h.b
        let ti = h.i
        if h.k == "b" { tb = h.parent; ti = h.slot }
        best = {type: "slot", b: tb, i: ti, x: h.x, y: h.y, w: h.w, h: h.h}
      }
    }
    return best
  }
  let last = d.blocks[len(d.blocks) - 1]
  let last_cap = is_capb(spec_of(last).shape)
  let dh = 0
  for b in d.blocks { dh += b._h }
  for h in E.hits {
    if h.k != "b" or h.list == nil { continue }
    let b = h.b
    let sh = spec_of(b).shape
    if fsh != "hat" {
      if not is_capb(sh) and (not last_cap or h.idx == len(h.list) - 1) {
        let dd = abs(x0 - b._x) + abs(y0 - (b._y + b._h))
        if dd < bd { bd = dd; best = {type: "after", list: h.list, idx: h.idx + 1, x: b._x, y: b._y + b._h} }
      }
      if is_c(sh) and (not last_cap or len(b.sub) == 0) {
        let dd = abs(x0 - (b._x + 16)) + abs(y0 - (b._y + b._sy))
        if dd < bd { bd = dd; best = {type: "after", list: b.sub, idx: 0, x: b._x + 16, y: b._y + b._sy} }
      }
      if sh == "c2" and (not last_cap or len(b.sub2) == 0) {
        let dd = abs(x0 - (b._x + 16)) + abs(y0 - (b._y + b._s2y))
        if dd < bd { bd = dd; best = {type: "after", list: b.sub2, idx: 0, x: b._x + 16, y: b._y + b._s2y} }
      }
    }
    if h.idx == 0 and not last_cap {
      let s = script_of(h.list)
      if s != nil and spec_of(s.blocks[0]).shape != "hat" {
        let dd = abs(x0 - s.x) + abs(y0 + dh - s.y)
        if dd < bd { bd = dd; best = {type: "top", script: s, x: s.x, y: s.y} }
      }
    }
  }
  return best
}
fn slot_kind(b, i) {
  for p in parts_of(b) { if p.t == nil and p.i == i { return p.kind } }
  return "s"
}
fn drop() {
  let d = E.drag
  let sn = E.snap
  E.drag = nil
  E.snap = nil
  if d.over_pal { relayout(); flash("Deleted"); return }
  if d.from_pal { remember() }
  let first = d.blocks[0]
  if sn == nil {
    push(cur_target().scripts, {x: round(first._x), y: round(first._y), blocks: d.blocks})
  }
  elif_drop(sn, d)
  relayout()
}
fn elif_drop(sn, d) {
  if sn == nil { return }
  if sn.type == "slot" {
    let old = sn.b.args[sn.i]
    sn.b.args[sn.i] = d.blocks[0]
    if type(old) == "map" { push(cur_target().scripts, {x: round(sn.x + 30), y: round(sn.y + 30), blocks: [old]}) }
  }
  if sn.type == "after" {
    let i = sn.idx
    for b in d.blocks { insert(sn.list, i, b); i += 1 }
  }
  if sn.type == "top" {
    let s = sn.script
    let dh = 0
    for b in d.blocks { dh += b._h }
    s.blocks = d.blocks + s.blocks
    s.y = round(s.y - dh)
    s.x = round(d.blocks[0]._x)
  }
}

# ---------------------------------------------------------------- editing a slot (text box over the canvas) and menus
fn close_edit() {
  if E.edit != nil { destroy(E.edit.box); E.edit = nil; relayout() }
}
fn edit_slot(h) {
  close_edit()
  let b = h.b
  let i = h.i
  let sp = to_screen(h.x, h.y)
  let t = textbox(E.wrap, "", fn(v) { close_edit() }, "kb-slotedit")
  css(t, {position: "absolute", left: sp.x, top: sp.y - 1, width: max(60, h.w * E.Z + 30), height: 22 * E.Z, "z-index": 4})
  setvalue(t, kb_disp(b.args[i]))
  remember()
  on_input(t, fn(v) {
    if h.kind == "n" {
      let n = num(trim(v))
      if n != nil { b.args[i] = n } else { b.args[i] = v }
    } else { b.args[i] = v }
    relayout()
  }, 0)
  focus(t)
  E.edit = {box: t, b: b, i: i}
}
fn menu_at(px, py, title, items, pick) {
  let p = popup(px, py + 10, "kb-menu")
  if title != nil { label(p, title, "kapp-sec") }
  let list = box(p, "kb-menu-list")
  for it in items {
    let v = it
    let lab = it
    if type(it) == "map" { v = it.v; lab = it.t }
    button(list, lab, fn() { pick(v) }, "kb-menu-item")
  }
  return p
}
fn open_menu(h, px, py) {
  let items = menu_items(h.menu)
  let extra = []
  if h.menu == "msg" { extra = [{t: "＋ New message…", v: "@new"}] }
  if h.menu == "var" { extra = [{t: "＋ New variable…", v: "@newvar"}] }
  if h.menu == "list" { extra = [{t: "＋ New list…", v: "@newlist"}] }
  menu_at(px, py, nil, items + extra, fn(v) {
    if v == "@new" { ask_name("New message", "message name", fn(n) { if not has(E.proj.msgs, n) { push(E.proj.msgs, n) }; remember(); h.b.args[h.i] = n; relayout() }); return }
    if v == "@newvar" { make_var(fn(n) { h.b.args[h.i] = n; relayout() }); return }
    if v == "@newlist" { make_list(fn(n) { h.b.args[h.i] = n; relayout() }); return }
    remember()
    h.b.args[h.i] = v
    relayout()
  })
}
fn ask_name(title, ph, done) {
  let p = popup(E.mx_page or 600, E.my_page or 300, "kb-menu")
  label(p, title, "kapp-sec")
  let t = textbox(p, ph, fn(v) { let n = trim(v); if n != "" { close_popups(); done(n) } }, "kapp-field")
  focus(t)
  let r = row(p)
  btn(r, "OK", fn() { let n = trim(gettext(t)); if n != "" { done(n) } }, nil, "kapp-btn on")
  btn(r, "Cancel", fn() { })
}
fn make_var(done) {
  let p = popup(E.mx_page or 600, E.my_page or 300, "kb-menu")
  label(p, "New variable", "kapp-sec")
  let t = textbox(p, "variable name", nil, "kapp-field")
  focus(t)
  let r = row(p)
  let mk = fn(local) {
    let n = trim(gettext(t))
    if n == "" { return }
    if local and not cur_target().is_stage { cur_target().vars[n] = 0 } else { E.proj.vars[n] = 0; E.proj.shown[n] = true }
    build_palette()
    flash("Made variable " + n)
    if done != nil { done(n) }
  }
  btn(r, "For all " + lower(APP.things), fn() { mk(false) }, nil, "kapp-btn on")
  if not cur_target().is_stage { btn(r, "This " + lower(APP.thing) + " only", fn() { mk(true) }) }
}
fn make_list(done) {
  let p = popup(E.mx_page or 600, E.my_page or 300, "kb-menu")
  label(p, "New list", "kapp-sec")
  let t = textbox(p, "list name", nil, "kapp-field")
  focus(t)
  let r = row(p)
  let mk = fn(local) {
    let n = trim(gettext(t))
    if n == "" { return }
    if local and not cur_target().is_stage { cur_target().lists[n] = [] } else { E.proj.lists[n] = [] }
    build_palette()
    if done != nil { done(n) }
  }
  btn(r, "For all " + lower(APP.things), fn() { mk(false) }, nil, "kapp-btn on")
  if not cur_target().is_stage { btn(r, "This " + lower(APP.thing) + " only", fn() { mk(true) }) }
}
fn make_block() {
  let p = popup(E.mx_page or 600, E.my_page or 300, "kb-menu")
  label(p, "Make a block", "kapp-sec")
  label(p, "A block of your own: name it, list its inputs (optional), then build what it does under \"define\".", "kapp-tiny")
  let t = textbox(p, "block name, e.g. jump", nil, "kapp-field")
  let ins = textbox(p, "inputs, e.g. height, speed (optional)", nil, "kapp-field")
  focus(t)
  btn(p, "OK", fn() {
    let n = trim(gettext(t))
    if n == "" or find_proc(cur_target(), n) != nil { return }
    let params = filter(map(split(gettext(ins), ","), fn(x) { return trim(x) }), fn(x) { return x != "" })
    remember()
    push(cur_target().procs, {name: n, params: params})
    let w = to_world(E.PW + 60, 60)
    push(cur_target().scripts, {x: round(w.x), y: round(w.y), blocks: [{op: "define", name: n, params: params, args: []}]})
    build_palette()
    relayout()
    close_popups()
  }, nil, "kapp-btn on")
}
fn context_menu(h, px, py) {
  if h == nil {
    menu_at(px, py, nil, [{t: "🧹 Clean up blocks", v: "clean"}, {t: "↶ Undo", v: "undo"}, {t: "＋ Make a variable", v: "var"}, {t: "＋ Make a block", v: "block"}], fn(v) {
      if v == "clean" { clean_up() }
      if v == "undo" { undo_step(true) }
      if v == "var" { make_var(nil) }
      if v == "block" { make_block() }
    })
    return
  }
  let items = [{t: "⧉ Duplicate", v: "dup"}, {t: "🗑 Delete block", v: "del"}]
  if h.b.op == "define" { items = [{t: "🗑 Delete this block definition", v: "deldef"}] }
  menu_at(px, py, nil, items, fn(v) {
    if v == "dup" {
      let src = [h.b]
      if h.list != nil { src = slice(h.list, h.idx) }
      remember()
      let copy = deep(clean(src))
      push(cur_target().scripts, {x: round(h.b._x + 24), y: round(h.b._y + 24), blocks: copy})
      relayout()
    }
    if v == "del" {
      let b = h.b
      remember()
      if h.parent != nil { h.parent.args[h.slot] = "" } else {
        remove(h.list, h.idx)
        if b.sub != nil { let i = h.idx; for s in b.sub + (b.sub2 or []) { insert(h.list, i, s); i += 1 } }
        cur_target().scripts = filter(cur_target().scripts, fn(s) { return len(s.blocks) > 0 })
      }
      relayout()
    }
    if v == "deldef" {
      remember()
      cur_target().procs = filter(cur_target().procs, fn(p) { return p.name != h.b.name })
      cur_target().scripts = filter(cur_target().scripts, fn(s) { return s.blocks[0] != h.b })
      build_palette()
      relayout()
    }
  })
}
fn clean_up() {
  remember()
  let y = 20
  for s in cur_target().scripts {
    s.x = 20
    s.y = y
    measure_stack(s.blocks)
    for b in s.blocks { y += b._h }
    y += 30
  }
  E.sx = -20
  E.sy = 0
  relayout()
}
fn pal_context(it, px, py) {
  let b = it.b
  if b.op == "var" {
    menu_at(px, py, "Variable " + b.name, [{t: "🗑 Delete variable", v: "del"}, {t: "✎ Rename…", v: "ren"}], fn(v) {
      if v == "del" { remove(E.proj.vars, b.name); remove(cur_target().vars, b.name); build_palette() }
      if v == "ren" { ask_name("Rename variable", b.name, fn(n) { rename_var(b.name, n) }) }
    })
  }
  if b.op == "listv" {
    menu_at(px, py, "List " + b.name, [{t: "🗑 Delete list", v: "del"}], fn(v) { remove(E.proj.lists, b.name); remove(cur_target().lists, b.name); build_palette() })
  }
}
fn rename_var(old, n) {
  if has(E.proj.vars, old) { E.proj.vars[n] = E.proj.vars[old]; remove(E.proj.vars, old); E.proj.shown[n] = E.proj.shown[old]; remove(E.proj.shown, old) }
  let t = cur_target()
  if has(t.vars, old) { t.vars[n] = t.vars[old]; remove(t.vars, old) }
  for tt in E.proj.targets { for s in tt.scripts { walk_blocks(s.blocks, fn(b) {
    if b.op == "var" and b.name == old { b.name = n }
    let sp = SPEC[b.op]
    if sp != nil { for p in sp.parts { if p.kind == "v" and b.args[p.i] == old { b.args[p.i] = n } } }
  }) } }
  build_palette()
  relayout()
}
fn walk_blocks(list, f) {
  for b in list {
    f(b)
    for a in b.args { if type(a) == "map" { walk_blocks([a], f) } }
    if b.sub != nil { walk_blocks(b.sub, f) }
    if b.sub2 != nil { walk_blocks(b.sub2, f) }
  }
}

fn on_code_mouse(e) {
  E.mx_page = e.px
  E.my_page = e.py
  if e.type == "wheel" {
    if e.x < E.PW { E.pal_sy = clamp(E.pal_sy + e.dy * 60, 0, max(0, E.pal_h - E.H + 40)); E.dirty = true; return }
    if e.shift { E.sx += e.dy * 60 / E.Z } else { E.sy += e.dy * 60 / E.Z }
    close_edit()
    E.dirty = true
    return
  }
  if e.type == "down" {
    close_edit()
    close_popups()
    if E.running and false { return }
    if e.x < E.PW {
      let it = pal_hit(e.x, e.y)
      if it == nil { return }
      if e.button == "right" { pal_context(it, e.px, e.py); return }
      let b = deep(clean(it.b))
      if b.op == "call" and b.params == nil { b.params = [] }
      E.pending = {pal: true, b: b, x: e.x, y: e.y, ox: (e.x - 12), oy: (e.y + E.pal_sy - it.y)}
      return
    }
    let w = to_world(e.x, e.y)
    let h = hit_at(E.hits, w.x, w.y)
    if e.button == "right" {
      let hb = h
      if h != nil and h.k == "s" { hb = hit_block_of(h.b) }
      context_menu(hb, e.px, e.py)
      return
    }
    if e.button == "middle" or h == nil {
      E.pan = {x: e.x, y: e.y, sx: E.sx, sy: E.sy}
      return
    }
    if h.k == "s" {
      if h.menu != nil { open_menu(h, e.px, e.py); return }
      if h.kind == "b" { E.pending = {h: hit_block_of(h.b), x: e.x, y: e.y, w: w}; return }
      edit_slot(h)
      return
    }
    E.pending = {h: h, x: e.x, y: e.y, w: w}
    return
  }
  if e.type == "move" {
    if E.pan != nil {
      E.sx = E.pan.sx - (e.x - E.pan.x) / E.Z
      E.sy = E.pan.sy - (e.y - E.pan.y) / E.Z
      E.dirty = true
      return
    }
    if E.pending != nil and abs(e.x - E.pending.x) + abs(e.y - E.pending.y) > 4 {
      let pd = E.pending
      E.pending = nil
      if pd.pal {
        start_drag([pd.b], e.x, e.y, pd.ox / E.Z, pd.oy / E.Z, true)
      } else {
        let h = pd.h
        let ox = pd.w.x - h.b._x
        let oy = pd.w.y - h.b._y
        let blocks = detach(h)
        start_drag(blocks, e.x, e.y, ox, oy, false)
      }
      return
    }
    if E.drag != nil { drag_to(e.x, e.y) }
    return
  }
  if e.type == "up" {
    E.pan = nil
    if E.drag != nil { drop(); return }
    if E.pending != nil {
      let pd = E.pending
      E.pending = nil
      if not pd.pal and pd.h != nil { click_script(pd.h) }
    }
  }
}
fn hit_block_of(b) { for h in E.hits { if h.k == "b" and h.b == b { return h } }; return nil }
fn click_script(h) {
  # clicking a block flashes it and, like Scratch, runs its script when the game is running
  let s = nil
  for sc in cur_target().scripts { if sc.blocks[0] == top_of(h.b) { s = sc } }
  h.b._hl = true
  E.dirty = true
  after(220, fn() { h.b._hl = false; E.dirty = true })
}
fn top_of(b) {
  for s in cur_target().scripts {
    let found = false
    walk_blocks(s.blocks, fn(x) { if x == b { found = true } })
    if found { return s.blocks[0] }
  }
  return b
}

# ---------------------------------------------------------------- compiler: blocks -> KampfScript
let CC = {procs: {}, t: nil}
fn lit_num(a) {
  let n = num(trim(str(a)))
  if n == nil { return "0" }
  if n < 0 { return "(" + str(n) + ")" }
  return str(n)
}
fn arg_code(b, p) {
  let a = b.args[p.i]
  if type(a) == "map" {
    let code = expr_code(a)
    let sh = spec_of(a).shape
    if p.kind == "n" and sh != "num" { return "kb_num(" + code + ")" }
    return code
  }
  if p.kind == "n" { return lit_num(a) }
  if p.kind == "b" { return "false" }
  if a == nil { return "\"\"" }
  return kq(kb_disp(a))
}
fn fill_template(b, line) {
  let out = line
  let sp = SPEC[b.op]
  let i = len(sp.parts) - 1
  # replace $9 .. $1 (high first so $1 does not eat $10)
  let codes = {}
  for p in sp.parts { if p.t == nil { codes[str(p.i + 1)] = arg_code(b, p) } }
  let k = 9
  while k >= 1 {
    if codes[str(k)] != nil { out = replace(out, "$" + str(k), codes[str(k)]) }
    k -= 1
  }
  return out
}
fn expr_code(a) {
  if a.op == "var" { return "kb_var(me, " + kq(a.name) + ")" }
  if a.op == "listv" { return "kb_list_text(me, " + kq(a.name) + ")" }
  if a.op == "param" { return "p_" + ident(a.name) }
  if SPEC[a.op] == nil { return "0" }
  return fill_template(a, SPEC[a.op].code)
}
fn stack_code(list, ind, lines) {
  for b in list {
    if b.op == "call" {
      let fname = CC.procs[b.name]
      if fname == nil { push(lines, ind + "# (missing block definition: " + b.name + ")"); continue }
      let args = ["me"]
      for p in parts_of(b) { if p.t == nil { push(args, arg_code(b, p)) } }
      push(lines, ind + fname + "(" + join(args, ", ") + ")")
      continue
    }
    let sp = SPEC[b.op]
    if sp == nil or sp.shape == "hat" or is_value(sp.shape) { continue }
    for ln in split(sp.code, "\n") {
      let tt = trim(ln)
      if tt == "$SUB" { stack_code(b.sub, ind + "  ", lines); continue }
      if tt == "$SUB2" { stack_code(b.sub2, ind + "  ", lines); continue }
      push(lines, ind + fill_template(b, ln))
    }
  }
}
fn hat_event(b) {
  let sp = SPEC[b.op]
  let ev = substr(sp.code, 1)
  let arg = "\"\""
  for p in sp.parts { if p.t == nil { arg = arg_code(b, p) } }
  return {ev: ev, arg: arg}
}
fn target_code(t, lines) {
  CC.t = t
  CC.procs = {}
  let used = {}
  for p in t.procs {
    let base = "my_" + ident(t.name) + "_" + ident(p.name)
    let nm = base
    let k = 2
    while used[nm] != nil { nm = base + str(k); k += 1 }
    used[nm] = true
    CC.procs[p.name] = nm
  }
  for s in t.scripts {
    let first = s.blocks[0]
    if first.op != "define" { continue }
    let ps = ["me"]
    for pn in first.params or [] { push(ps, "p_" + ident(pn)) }
    let fname = CC.procs[first.name]
    if fname == nil { continue }
    push(lines, "fn " + fname + "(" + join(ps, ", ") + ") {   # define " + first.name)
    stack_code(slice(s.blocks, 1), "  ", lines)
    push(lines, "}")
  }
  for s in t.scripts {
    let first = s.blocks[0]
    let sp = SPEC[first.op]
    if sp == nil or sp.shape != "hat" { continue }
    let he = hat_event(first)
    push(lines, "kb_when(" + kq(t.name) + ", " + kq(he.ev) + ", " + he.arg + ", fn(me) {   # " + hat_text(first))
    stack_code(slice(s.blocks, 1), "  ", lines)
    push(lines, "})")
  }
}
fn runtime_project(p) {
  let out = {name: p.name, vars: p.vars, lists: p.lists, shown: p.shown, targets: [], settings: p.settings or {}}
  for t in p.targets { push(out.targets, runtime_target(t)) }
  return out
}
fn compile_project(p, for_view) {
  let lines = []
  push(lines, "# ==== " + p.name + " — made with " + APP.name + " (blocks compiled to KampfScript)")
  if for_view {
    push(lines, "kb_start(PROJECT)   # PROJECT = the " + lower(APP.things) + ", costumes and variables (" + str(round(len(json(runtime_project(p))) / 1024)) + " KB of data)")
  } else {
    push(lines, "kb_start(parse_json(" + kq(json(clean(runtime_project(p)))) + "))")
  }
  for t in p.targets {
    let sub = []
    target_code(t, sub)
    if len(sub) == 0 { continue }
    push(lines, "")
    if t.is_stage { push(lines, "# ---- " + APP.stage_name) } else { push(lines, "# ---- " + APP.thing + ": " + t.name) }
    for l in sub { push(lines, l) }
  }
  push(lines, "")
  push(lines, "kb_go()   # = the green flag")
  return join(lines, "\n")
}
fn game_code(p) { return RUNTIME_SRC + "\n" + compile_project(p, false) + "\n" }

# ---------------------------------------------------------------- running the game
fn run_game() {
  stop_game()
  close_edit()
  let code = game_code(E.proj)
  show(E.runbox, true)
  E.running = true
  E.last_err = ""
  setstyle(E.flagbtn, "outline", "2px solid #fff")
  E.app = run_app(code, E.runbox, {name: APP.short, on_error: fn(msg, line) {
    E.last_err = msg
    status("⚠ " + msg + " (game line " + str(line) + ")")
  }, on_print: fn(x) { status("print: " + str(x)) }})
  status("▶ Running — press ⏹ to stop")
}
fn stop_game() {
  if E.app != nil { stop_app(E.app, true); E.app = nil }
  E.running = false
  if E.runbox != nil { show(E.runbox, false) }
  if E.flagbtn != nil { setstyle(E.flagbtn, "outline", "none") }
  E.sdirty = true
}

# ---------------------------------------------------------------- status line
fn status(t) { settext(E.status, t) }
fn flash(t) { status(t); E.flash_t = time() }

# ---------------------------------------------------------------- targets (sprites / actors) list
fn select_target(i) {
  close_edit()
  E.cur = clamp(i, 0, len(E.proj.targets) - 1)
  E.undo = []
  E.redo = []
  refresh_target()
}
fn refresh_target() {
  build_palette()
  relayout()
  refresh_tiles()
  refresh_props()
  if E.tab == "looks" { show_tab("looks") }
  if E.tab == "codeview" { show_tab("codeview") }
  E.sdirty = true
}
fn refresh_tiles() {
  clear(E.tiles)
  for i, t in E.proj.targets {
    let st = "kb-tile"
    if i == E.cur { st = "kb-tile on" }
    let tile = col(E.tiles, st)
    let th = target_thumb(t)
    if th != nil { let im = image(tile, th, "kb-thumb") } else { label(tile, "■", "kb-thumb-ph") }
    let nm = t.name
    if t.is_stage { nm = APP.stage_name }
    label(tile, nm, "kb-tile-name")
    let ii = i
    on_click(tile, fn() { select_target(ii) })
  }
}
fn rename_target(t, n) {
  n = trim(n)
  if n == "" or n == t.name or t.is_stage { return }
  for o in E.proj.targets { if o.name == n { flash("There is already one called " + n); return } }
  let old = t.name
  t.name = n
  for tt in E.proj.targets { for s in tt.scripts { walk_blocks(s.blocks, fn(b) {
    let sp = SPEC[b.op]
    if sp != nil { for p in sp.parts { if p.menu != nil and b.args[p.i] == old { b.args[p.i] = n } } }
  }) } }
  refresh_tiles()
  relayout()
}
fn delete_target() {
  let t = cur_target()
  if t.is_stage { return }
  if len(sprite_names()) <= 0 { return }
  remove(E.proj.targets, E.cur)
  E.cur = max(0, E.cur - 1)
  refresh_target()
  flash("Deleted " + t.name)
}
fn duplicate_target() {
  let t = cur_target()
  if t.is_stage { return }
  let c = deep(clean(t))
  c.name = unique_name(t.name)
  c.x = (c.x or 0) + 20
  push(E.proj.targets, c)
  select_target(len(E.proj.targets) - 1)
}
fn unique_name(base) {
  let n = base
  let k = 2
  let taken = true
  while taken {
    taken = false
    for t in E.proj.targets { if t.name == n { taken = true } }
    if taken { n = base + str(k); k += 1 }
  }
  return n
}
fn add_target(t) {
  t.name = unique_name(t.name)
  if t.scripts == nil { t.scripts = [] }
  if t.procs == nil { t.procs = [] }
  if t.vars == nil { t.vars = {} }
  if t.lists == nil { t.lists = {} }
  push(E.proj.targets, t)
  select_target(len(E.proj.targets) - 1)
}

# ---------------------------------------------------------------- tabs: Code / Looks / Generated KampfScript / Help
fn show_tab(which) {
  E.tab = which
  for k, b in E.tabbtns { togglestyle(b, "on", k == which) }
  show(E.codepane, which == "code")
  show(E.lookpane, which == "looks")
  show(E.viewpane, which == "codeview")
  show(E.helppane, which == "help")
  if which == "looks" { clear(E.lookpane); looks_tab(E.lookpane) }
  if which == "codeview" {
    clear(E.viewpane)
    let r = row(E.viewpane, "kb-viewbar")
    label(r, "This is the KampfScript your blocks turn into. The green flag runs exactly this (plus the small game engine).", "kapp-tiny")
    btn(r, "⧉ Copy", fn() { copy_text(compile_project(E.proj, true)); flash("Copied") })
    let cb_ = label(E.viewpane, compile_project(E.proj, true), "kapp-code kb-codeview")
  }
  if which == "code" { relayout() }
}

# ---------------------------------------------------------------- files
fn proj_json() { return json(clean(E.proj)) }
fn save_project() {
  let r = file_save(ident(E.proj.name) + "." + APP.ext, proj_json())
  if r.ok { E.saved_json = proj_json(); flash("Saved " + r.name) }
}
fn open_project() {
  let f = file_open([APP.ext, "json"])
  if f == nil { return }
  let p = parse_json(f.text)
  if p == nil or p.targets == nil { flash("That is not a " + APP.name + " project"); return }
  load_project(p)
  flash("Opened " + f.name)
}
fn export_game() {
  let code = "# " + E.proj.name + " — a game made with " + APP.name + " (Kompass). Open it in Kompass to play.\n" + game_code(E.proj)
  let r = file_save(ident(E.proj.name) + ".ks", code)
  if r.ok { flash("Exported playable game: " + r.name + " (" + str(round(r.bytes / 1024)) + " KB)") }
}
fn fix_project(p) {
  if p.vars == nil { p.vars = {} }
  if p.lists == nil { p.lists = {} }
  if p.shown == nil { p.shown = {} }
  if p.msgs == nil { p.msgs = [] }
  if p.name == nil { p.name = "My game" }
  for t in p.targets {
    if t.scripts == nil { t.scripts = [] }
    if t.procs == nil { t.procs = [] }
    if t.vars == nil { t.vars = {} }
    if t.lists == nil { t.lists = {} }
    if t.costumes == nil { t.costumes = [] }
  }
  return p
}
fn arrange_scripts(t) {
  let x = 20
  let y = 20
  let colw = 0
  for s in t.scripts {
    let h = measure_stack(s.blocks)
    let w = stack_w(s.blocks)
    if y > 20 and y + h > 760 { x += colw + 40; y = 20; colw = 0 }
    s.x = x
    s.y = y
    y += h + 36
    colw = max(colw, w)
  }
}
fn load_project(p) {
  stop_game()
  E.busy = true
  E.proj = fix_project(p)
  if p.arrange { for t in p.targets { arrange_scripts(t) }; p.arrange = false }
  E.cur = min(1, len(p.targets) - 1)
  E.sx = -20
  E.sy = -20
  E.pal_sy = 0
  settext(E.namebox, E.proj.name)
  E.saved_json = proj_json()
  select_target(E.cur)
  show_tab("code")
  E.busy = false
  E.dirty = true
  E.sdirty = true
}
fn new_project_click() {
  load_project(new_project())
  flash("New project")
}
fn samples_menu() {
  let items = map(samples(), fn(s) { return {t: s.title, v: s.title} })
  menu_at(E.mx_page or 300, 80, "Sample games", items, fn(v) {
    for s in samples() { if s.title == v { load_project(s.make()); flash("Opened sample: " + v + " — press the green flag") } }
  })
}
fn autosave() {
  let j = proj_json()
  if len(j) < 190000 { store_set("autosave", j) }
}

# ---------------------------------------------------------------- main layout
fn build_ui() {
  let root = box(body(), "kapp")
  let bar = row(root, "kapp-bar")
  label(bar, APP.icon + " " + APP.name, "kapp-title")
  E.namebox = textbox(bar, "project name", nil, "kapp-field kb-name")
  on_input(E.namebox, fn(v) { E.proj.name = trim(v) or "My game" }, 200)
  btn(bar, "New", fn() { new_project_click() }, "Start an empty project")
  btn(bar, "Open", fn() { open_project() }, "Open a ." + APP.ext + " project")
  btn(bar, "Save", fn() { save_project() }, "Save the project (." + APP.ext + ")")
  btn(bar, "★ Samples", fn() { samples_menu() }, "Open a sample game")
  btn(bar, "⇩ Export game", fn() { export_game() }, "Save a playable .ks game anyone with Kompass can run")
  label(bar, "│", "kapp-tiny")
  E.tabbtns = {}
  E.tabbtns["code"] = btn(bar, "🧩 Code", fn() { show_tab("code") })
  E.tabbtns["looks"] = btn(bar, APP.looks_tab, fn() { show_tab("looks") })
  E.tabbtns["codeview"] = btn(bar, "{ } KampfScript", fn() { show_tab("codeview") }, "See the code your blocks make")
  E.tabbtns["help"] = btn(bar, "? Help", fn() { show_tab("help") })
  let mainrow = row(root, "kapp-main")
  # category column
  let cats = col(mainrow, "kb-cats")
  for c in CATS {
    let cid = c.id
    let b = col(cats, "kb-cat")
    let dot = label(b, "●", "kb-cat-dot")
    setstyle(dot, "color", c.color)
    label(b, c.label, "kb-cat-label")
    on_click(b, fn() {
      if cid == "myblocks" { pal_scroll_to("myblocks"); return }
      pal_scroll_to(cid)
    })
  }
  let mk = col(cats, "kb-cat")
  label(mk, "＋", "kb-cat-dot")
  label(mk, "Variable", "kb-cat-label")
  on_click(mk, fn() { make_var(nil) })
  let mkl = col(cats, "kb-cat")
  label(mkl, "＋", "kb-cat-dot")
  label(mkl, "List", "kb-cat-label")
  on_click(mkl, fn() { make_list(nil) })
  let mkb = col(cats, "kb-cat")
  label(mkb, "＋", "kb-cat-dot")
  label(mkb, "Block", "kb-cat-label")
  on_click(mkb, fn() { make_block() })
  # centre
  let center = box(mainrow, "kapp-view")
  E.codepane = box(center, "kb-pane")
  E.wrap = E.codepane
  E.cv = canvas(E.codepane)
  on_mouse(E.cv, fn(e) { on_code_mouse(e) })
  let zr = row(E.codepane, "kb-zoom")
  btn(zr, "－", fn() { E.Z = max(0.5, E.Z - 0.15); E.dirty = true; close_edit() }, "Zoom out")
  btn(zr, "＝", fn() { E.Z = 1; E.dirty = true; close_edit() }, "Normal size")
  btn(zr, "＋", fn() { E.Z = min(1.8, E.Z + 0.15); E.dirty = true; close_edit() }, "Zoom in")
  btn(zr, "🧹", fn() { clean_up() }, "Clean up: line the scripts up")
  E.lookpane = box(center, "kb-pane kb-scroll")
  E.viewpane = col(center, "kb-pane kb-scroll")
  E.helppane = col(center, "kb-pane kb-scroll kb-help")
  help_page(E.helppane)
  # right: stage + sprites
  let right = col(mainrow, "kapp-panel right kb-right")
  let rb = row(right, "kb-runbar")
  E.flagbtn = btn(rb, "⚑ Go", fn() { run_game() }, "Green flag: run the game", "kapp-btn go")
  btn(rb, "⏹ Stop", fn() { stop_game(); status("Stopped") }, "Stop everything", "kapp-btn stop")
  E.coords = label(rb, "", "kapp-tiny kb-coords")
  E.stagebox = box(right, "kb-stage")
  preview_init(E.stagebox)
  E.runbox = box(E.stagebox, "kb-run")
  show(E.runbox, false)
  E.props = col(right, "kb-props")
  let sh = row(right, "kb-sprhead")
  label(sh, APP.things, "kapp-sec")
  spacer_(sh)
  new_target_buttons(sh)
  btn(sh, "⧉", fn() { duplicate_target() }, "Duplicate")
  btn(sh, "🗑", fn() { delete_target() }, "Delete")
  E.tiles = row(right, "kb-tiles")
  E.status = label(root, "", "kapp-status")
  on_keypress(fn(k) {
    if E.running and k == "escape" { stop_game(); return }
    if E.running { return }
    if k == "z" and key_down("control") {
      if key_down("shift") { undo_step(false) } else { undo_step(true) }
    }
  })
  on_frame(fn(dt) {
    if E.proj == nil or E.busy { return }
    if E.tab == "code" and E.dirty { E.dirty = false; draw_editor() }
    if E.sdirty and not E.running { E.sdirty = false; preview_draw() }
    if E.running and E.app != nil {
      let st = app_status(E.app)
      if not st.running and st.error != "" { E.running = false }
    }
  })
  every_ms(4000, fn() { if E.changed { E.changed = false; autosave() } })
}
fn spacer_(p) { let s = box(p); setstyle(s, "flex", 1) }
fn help_page(p) {
  label(p, APP.icon + " " + APP.name, "kb-h1")
  for para in HELP { 
    if startswith(para, "## ") { label(p, substr(para, 3), "kb-h2") } else { label(p, para, "kb-p") }
  }
}


fn dv(v, d) { if v == nil { return d } return v }
