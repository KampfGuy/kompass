# ---- Kugel Blocks runtime, 2D part: a stage of 480 × 360 Scratch units (x -240..240, y -180..180), sprites with
# costumes, motion, looks, say / think bubbles, touching, pen. Drawn on one canvas every frame.
fn kb_removed(me) { }
# ---- targets, instances, threads
fn kb_new_inst(t, from) {
  KB.layer += 1
  let me = {name: t.name, t: t, x: 0, y: 0, dir: 90, size: 100, costume: 0, visible: true, ghost: 0, bright: 0, layer: KB.layer,
    say: "", think: false, say_until: 0, vars: {}, lists: {}, clone: false, dead: false, rot: "all around", threads: [], is_stage: t.is_stage,
    pen: false, pen_color: "#3d8bfd", pen_size: 2, drag: false}
  if from == nil {
    me.x = t.x
    me.y = t.y
    me.dir = t.dir
    me.size = t.size
    me.costume = t.costume
    me.visible = t.visible
    me.rot = t.rot
    for k, v in t.vars { me.vars[k] = v }
    for k, v in t.lists { me.lists[k] = slice(v) }
  } else {
    for k in ["x", "y", "dir", "size", "costume", "visible", "ghost", "bright", "rot", "pen", "pen_color", "pen_size"] { me[k] = from[k] }
    for k, v in from.vars { me.vars[k] = v }
    for k, v in from.lists { me.lists[k] = slice(v) }
    me.clone = true
    me.layer = from.layer
    from.layer = KB.layer + 1
    KB.layer += 1
  }
  push(KB.insts, me)
  return me
}
# ---- costumes
fn kb_costumes(me) { return me.t.costumes }
fn kb_cur(me) {
  let cs = me.t.costumes
  if len(cs) == 0 { return nil }
  return cs[kb_mod(me.costume, len(cs))]
}
fn kb_set_costume(me, c) {
  let cs = me.t.costumes
  if len(cs) == 0 { return }
  if type(c) == "number" { me.costume = kb_mod(kb_int(c) - 1, len(cs)); return }
  let name = kb_str(c)
  for i, k in cs { if k.name == name { me.costume = i; return } }
  if name == "next costume" or name == "next backdrop" { me.costume = kb_mod(me.costume + 1, len(cs)); return }
  if name == "previous costume" or name == "previous backdrop" { me.costume = kb_mod(me.costume - 1, len(cs)); return }
  let n = num(name)
  if n != nil { me.costume = kb_mod(kb_int(n) - 1, len(cs)) }
}
fn kb_costume_num(me) { return me.costume + 1 }
fn kb_costume_name(me) { let c = kb_cur(me); if c == nil { return "" } return c.name }
fn kb_stage_inst() {
  for i in KB.insts { if i.is_stage { return i } }
  return nil
}
fn kb_backdrop(name) {
  let st = kb_stage_inst()
  if st == nil { return }
  kb_set_costume(st, name)
  kb_fire("backdrop", kb_costume_name(st), nil)
}
fn kb_backdrop_name() { let st = kb_stage_inst(); if st == nil { return "" } return kb_costume_name(st) }
fn kb_backdrop_num() { let st = kb_stage_inst(); if st == nil { return 1 } return st.costume + 1 }
fn kb_csize(c) {
  if c.w != nil { return {w: c.w, h: c.h} }
  return {w: 64, h: 64}
}
# ---- motion
fn kb_fence(me) {
  # like Scratch: a sprite can not leave the stage completely (15 units stay visible)
  let c = kb_cur(me)
  let s = {w: 40, h: 40}
  if c != nil { s = kb_csize(c) }
  let k = me.size / 100
  let hw = max(0, s.w * k / 2 - 15)
  let hh = max(0, s.h * k / 2 - 15)
  me.x = clamp(me.x, -240 - hw, 240 + hw)
  me.y = clamp(me.y, -180 - hh, 180 + hh)
}
fn kb_moved(me, ox, oy) {
  if me.pen { push(KB.pen, [ox, oy, me.x, me.y, me.pen_color, me.pen_size]) }
}
fn kb_goto(me, x, y) {
  let ox = me.x
  let oy = me.y
  me.x = kb_num(x)
  me.y = kb_num(y)
  kb_fence(me)
  kb_moved(me, ox, oy)
}
fn kb_move(me, n) {
  let a = (90 - me.dir) * PI / 180
  kb_goto(me, me.x + cos(a) * kb_num(n), me.y + sin(a) * kb_num(n))
}
fn kb_turn(me, d) { me.dir = kb_dir(me.dir + kb_num(d)) }
fn kb_dir(d) {
  let r = kb_mod(d + 180, 360) - 180
  if r == -180 { r = 180 }
  return r
}
fn kb_point(me, d) { me.dir = kb_dir(kb_num(d)) }
fn kb_where(me, what) {
  if what == "random position" { return {x: random(-240, 240), y: random(-180, 180)} }
  if what == "mouse-pointer" { return {x: KB.mx, y: KB.my} }
  for i in KB.insts { if i.name == what and not i.clone and not i.dead { return {x: i.x, y: i.y} } }
  return nil
}
fn kb_goto_target(me, what) { let p = kb_where(me, what); if p != nil { kb_goto(me, p.x, p.y) } }
fn kb_point_towards(me, what) {
  let p = kb_where(me, what)
  if p == nil { return }
  let dx = p.x - me.x
  let dy = p.y - me.y
  if dx == 0 and dy == 0 { return }
  me.dir = kb_dir(90 - atan2(dy, dx) * 180 / PI)
}
fn kb_glide(me, secs, x, y) {
  let t0 = time()
  let dur = max(0.001, kb_num(secs)) * 1000
  let sx = me.x
  let sy = me.y
  let tx = kb_num(x)
  let ty = kb_num(y)
  while time() - t0 < dur {
    let k = (time() - t0) / dur
    kb_goto(me, sx + (tx - sx) * k, sy + (ty - sy) * k)
    kb_yield(me)
  }
  kb_goto(me, tx, ty)
}
fn kb_glide_to(me, secs, what) { let p = kb_where(me, what); if p != nil { kb_glide(me, secs, p.x, p.y) } }
fn kb_box(me) {
  let c = kb_cur(me)
  let s = {w: 40, h: 40}
  if c != nil { s = kb_csize(c) }
  let k = me.size / 100
  return {l: me.x - s.w * k / 2, r: me.x + s.w * k / 2, b: me.y - s.h * k / 2, t: me.y + s.h * k / 2}
}
fn kb_bounce(me) {
  let b = kb_box(me)
  let a = (90 - me.dir) * PI / 180
  let dx = cos(a)
  let dy = sin(a)
  let hit = false
  if b.l < -240 { dx = abs(dx); me.x += -240 - b.l; hit = true }
  if b.r > 240 { dx = -abs(dx); me.x -= b.r - 240; hit = true }
  if b.b < -180 { dy = abs(dy); me.y += -180 - b.b; hit = true }
  if b.t > 180 { dy = -abs(dy); me.y -= b.t - 180; hit = true }
  if hit { me.dir = kb_dir(90 - atan2(dy, dx) * 180 / PI) }
}
# ---- looks
fn kb_say(me, text, secs, think) {
  me.say = kb_str(text)
  me.think = think
  me.say_until = 0
  if secs != nil {
    kb_wait(me, secs)
    me.say = ""
  }
}
fn kb_change_size(me, d) { me.size = clamp(me.size + kb_num(d), 5, 500) }
fn kb_set_size(me, v) { me.size = clamp(kb_num(v), 5, 500) }
fn kb_effect(me, which, v, add) {
  if which == "ghost" { if add { me.ghost += kb_num(v) } else { me.ghost = kb_num(v) }; me.ghost = clamp(me.ghost, 0, 100) }
  if which == "brightness" { if add { me.bright += kb_num(v) } else { me.bright = kb_num(v) }; me.bright = clamp(me.bright, -100, 100) }
}
fn kb_front(me, front) {
  KB.layer += 1
  if front { me.layer = KB.layer } else { me.layer = -KB.layer }
}
fn kb_layers(me, n) { me.layer += kb_num(n) * 1.5 }
# ---- sensing
fn kb_touching(me, what) {
  if not me.visible { return false }
  let b = kb_box(me)
  let shrink = 0.18
  let bw = (b.r - b.l) * shrink
  let bh = (b.t - b.b) * shrink
  if what == "edge" { return b.l < -240 or b.r > 240 or b.b < -180 or b.t > 180 }
  if what == "mouse-pointer" { return KB.mx >= b.l and KB.mx <= b.r and KB.my >= b.b and KB.my <= b.t }
  for o in KB.insts {
    if o == me or o.name != what or o.dead or not o.visible { continue }
    let c = kb_box(o)
    let cw = (c.r - c.l) * shrink
    let ch = (c.t - c.b) * shrink
    if b.l + bw < c.r - cw and b.r - bw > c.l + cw and b.b + bh < c.t - ch and b.t - bh > c.b + ch { return true }
  }
  return false
}
fn kb_distance(me, what) {
  let p = kb_where(me, what)
  if p == nil { return 0 }
  return hypot(p.x - me.x, p.y - me.y)
}
fn kb_of(what, prop) {
  let o = nil
  for i in KB.insts { if i.name == what and not i.clone and not i.dead { o = i } }
  if o == nil { return 0 }
  if prop == "x position" { return o.x }
  if prop == "y position" { return o.y }
  if prop == "direction" { return o.dir }
  if prop == "costume #" or prop == "backdrop #" { return o.costume + 1 }
  if prop == "size" { return o.size }
  let v = o.vars[prop]
  if v == nil { return 0 }
  return v
}
# ---- variables & lists ("for all sprites" live in KB.vars, "this sprite only" in me.vars)
# ---- sound
# ---- pen
fn kb_pen_down(me, on) { me.pen = on; if on { push(KB.pen, [me.x, me.y, me.x + 0.01, me.y, me.pen_color, me.pen_size]) } }
fn kb_pen_clear() { KB.pen = []; KB.pen_clear = true }
fn kb_stamp(me) { push(KB.pen, ["stamp", me.x, me.y, me.dir, me.size, me.costume, me.t.name, me.ghost]) }
# ---- drawing
fn kb_sx(x) { return KB.ox + (x + 240) * KB.scale }
fn kb_sy(y) { return KB.oy + (180 - y) * KB.scale }
fn kb_draw_costume(c, me, x, y, dir, size, cidx, ghost) {
  let cs = me.t.costumes
  if len(cs) == 0 { return }
  let co = cs[kb_mod(cidx, len(cs))]
  let s = kb_csize(co)
  let k = size / 100 * KB.scale
  let w = s.w * k
  let h = s.h * k
  let rot = 0
  if me.rot == "all around" { rot = (dir - 90) * PI / 180 }
  if me.rot == "left-right" and dir < 0 { w = -w }
  draw_image(c, co.data, kb_sx(x) - abs(w) / 2, kb_sy(y) - h / 2, w, h, rot, clamp(1 - ghost / 100, 0, 1))
}
fn kb_bubble(c, me) {
  let b = kb_box(me)
  let t = me.say
  if len(t) > 60 { t = substr(t, 0, 57) + "..." }
  let fs = 13 * KB.scale
  let w = text_width(t, fs) + 18 * KB.scale
  let x = kb_sx(b.r) - 4 * KB.scale
  let y = kb_sy(b.t) - 34 * KB.scale
  if x + w > kb_sx(240) { x = kb_sx(b.l) - w + 4 * KB.scale }
  if y < kb_sy(180) { y = kb_sy(180) + 2 }
  draw_round_rect(c, x, y, w, 26 * KB.scale, 10 * KB.scale, "#ffffff")
  draw_round_rect(c, x, y, w, 26 * KB.scale, 10 * KB.scale, "#9aa1b2", 1.5)
  if me.think { draw_circle(c, x + 10 * KB.scale, y + 32 * KB.scale, 4 * KB.scale, "#ffffff") } else { draw_poly(c, [[x + 10 * KB.scale, y + 25 * KB.scale], [x + 22 * KB.scale, y + 25 * KB.scale], [x + 8 * KB.scale, y + 36 * KB.scale]], "#ffffff") }
  draw_text(c, x + 9 * KB.scale, y + 13 * KB.scale, t, "#1d2027", fs)
}
fn kb_render(c) {
  let cs = canvas_size(c)
  KB.scale = min(cs.w / 480, cs.h / 360)
  KB.ox = (cs.w - 480 * KB.scale) / 2
  KB.oy = (cs.h - 360 * KB.scale) / 2
  draw_clear(c, "#000000")
  let st = kb_stage_inst()
  draw_rect(c, KB.ox, KB.oy, 480 * KB.scale, 360 * KB.scale, "#ffffff")
  if st != nil {
    let bd = kb_cur(st)
    if bd != nil { draw_image(c, bd.data, KB.ox, KB.oy, 480 * KB.scale, 360 * KB.scale) }
  }
  # pen layer
  for p in KB.pen {
    if p[0] == "stamp" {
      let t = KB.targets[p[6]]
      if t != nil { kb_draw_costume(c, {t: t, rot: "all around"}, p[1], p[2], p[3], p[4], p[5], p[7]) }
    } else { draw_line(c, kb_sx(p[0]), kb_sy(p[1]), kb_sx(p[2]), kb_sy(p[3]), p[4], p[5] * KB.scale) }
  }
  let list = sort_layers(filter(KB.insts, fn(i) { return not i.is_stage and i.visible and not i.dead }))
  for me in list { kb_draw_costume(c, me, me.x, me.y, me.dir, me.size, me.costume, me.ghost) }
  for me in list { if me.say != "" { kb_bubble(c, me) } }
  # variable monitors
  let y = KB.oy + 6 * KB.scale
  for name, on in KB.shown {
    if not on { continue }
    let t = name + ": " + kb_str(KB.vars[name])
    let w = text_width(t, 12 * KB.scale) + 14 * KB.scale
    draw_round_rect(c, KB.ox + 6 * KB.scale, y, w, 20 * KB.scale, 5 * KB.scale, "rgba(230,232,238,0.92)")
    draw_text(c, KB.ox + 13 * KB.scale, y + 10 * KB.scale, t, "#1d2027", 12 * KB.scale)
    y += 24 * KB.scale
  }
  if KB.asking != nil and KB.asking.me.is_stage { draw_text(c, KB.ox + 10 * KB.scale, KB.oy + 330 * KB.scale, KB.asking.q, "#1d2027", 14 * KB.scale) }
  # letterbox
  if KB.ox > 0 { draw_rect(c, 0, 0, KB.ox, cs.h, "#000000"); draw_rect(c, KB.ox + 480 * KB.scale, 0, KB.ox + 1, cs.h, "#000000") }
}
fn sort_layers(l) {
  # insertion sort by layer (small lists)
  let out = []
  for x in l {
    let i = len(out)
    while i > 0 and out[i - 1].layer > x.layer { i -= 1 }
    insert(out, i, x)
  }
  return out
}
fn kb_mouse_x() { return round(KB.mx) }
fn kb_mouse_y() { return round(KB.my) }
fn kb_mouse_down() { return KB.mdown }
# ---- start
fn kb_start(project) {
  KB.project = project
  KB.root = box(body())
  setstyle(KB.root, "position", "absolute")
  setstyle(KB.root, "inset", 0)
  setstyle(KB.root, "background", "#000000")
  let c = canvas(KB.root)
  KB.cv = c
  for t in project.targets {
    let tt = {name: t.name, is_stage: t.is_stage == true, costumes: t.costumes, x: t.x or 0, y: t.y or 0, dir: dv(t.dir, 90), size: t.size or 100,
      costume: t.costume or 0, visible: t.visible != false, rot: t.rot or "all around", vars: t.vars or {}, lists: t.lists or {}}
    KB.targets[t.name] = tt
    push(KB.order, t.name)
    for co in t.costumes { load_image(co.data) }
  }
  for k, v in project.vars { KB.vars[k] = v }
  for k, v in project.lists { KB.lists[k] = slice(v) }
  for k, v in project.shown { KB.shown[k] = v }
  for name in KB.order { kb_new_inst(KB.targets[name], nil) }
  on_mouse(c, fn(e) {
    if KB.scale > 0 {
      KB.mx = clamp((e.x - KB.ox) / KB.scale - 240, -240, 240)
      KB.my = clamp(180 - (e.y - KB.oy) / KB.scale, -180, 180)
    }
    if e.type == "down" {
      KB.mdown = true
      let hit = nil
      for me in sort_layers(filter(KB.insts, fn(i) { return not i.is_stage and i.visible and not i.dead })) {
        let b = kb_box(me)
        if KB.mx >= b.l and KB.mx <= b.r and KB.my >= b.b and KB.my <= b.t { hit = me }
      }
      if hit != nil { kb_fire("click", "", hit) } else { let st = kb_stage_inst(); if st != nil { kb_fire("click", "", st) } }
    }
    if e.type == "up" { KB.mdown = false }
  })
  on_keypress(fn(k) { kb_fire("key", k, nil) })
  on_frame(fn(dt) { kb_render(c) })
}
fn kb_go() {
  KB.ready = true
  kb_fire("flag", "", nil)
}
fn kb_turn_left(me, d) { kb_turn(me, -kb_num(d)) }
fn kb_layers2(me, way, n) { if way == "backward" { kb_layers(me, -kb_num(n)) } else { kb_layers(me, n) } }
fn kb_costume_info(me, which) { if which == "name" { return kb_costume_name(me) } return me.costume + 1 }
fn kb_backdrop_info(which) { if which == "name" { return kb_backdrop_name() } return kb_backdrop_num() }
let KB_COLORS = {red: "#e5383b", orange: "#f48c06", yellow: "#ffd60a", green: "#2dc653", blue: "#3d8bfd", purple: "#9d4edd", pink: "#ff70a6", black: "#111111", white: "#ffffff", brown: "#8d5524"}
fn kb_pen_color(me, c) { let h = KB_COLORS[kb_str(c)]; if h == nil { h = kb_str(c) } me.pen_color = h }
fn kb_pen_size(me, n, add) { if add { me.pen_size += kb_num(n) } else { me.pen_size = kb_num(n) }; me.pen_size = clamp(me.pen_size, 1, 100) }
fn kb_set_drag(me, on) { me.drag = on }
