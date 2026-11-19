# ---- Kugel Blocks (2D): sprites, costumes, the paint editor, the stage preview, sample games.
APP.icon = "🧩"
APP.looks_tab = "🎨 Costumes"
APP.hello = "Drag blocks from the left into the middle, snap them together, then press ⚑ Go. Samples: ★ Samples."
let GEN = box(body())
css(GEN, {position: "absolute", left: -5000, top: 0, width: 1000, height: 1000, overflow: "hidden"})
let LIB = nil
let BACKS = nil

# ---------------------------------------------------------------- procedural costumes (drawn at 2x)
fn gen_costume(name, w, h, painter) {
  let c = canvas(GEN, w * 2, h * 2)
  draw_save(c)
  draw_scale(c, 2)
  painter(c, w, h)
  draw_restore(c)
  let data = canvas_data(c)
  destroy(c)
  return {name: name, data: data, w: w, h: h}
}
fn star_pts(cx, cy, r1, r2, n) {
  let pts = []
  for i in n * 2 {
    let r = r1
    if i % 2 == 1 { r = r2 }
    let a = -PI / 2 + i * PI / n
    push(pts, [cx + cos(a) * r, cy + sin(a) * r])
  }
  return pts
}
fn face(c, cx, cy, s) {
  draw_circle(c, cx - s * 0.32, cy - s * 0.12, s * 0.16, "#ffffff")
  draw_circle(c, cx + s * 0.32, cy - s * 0.12, s * 0.16, "#ffffff")
  draw_circle(c, cx - s * 0.28, cy - s * 0.1, s * 0.08, "#1d2027")
  draw_circle(c, cx + s * 0.36, cy - s * 0.1, s * 0.08, "#1d2027")
  draw_arc(c, cx, cy + s * 0.12, s * 0.3, 0.3, PI - 0.3, "#1d2027", max(1.5, s * 0.07))
}
let PAINTERS = {
  "Kugel": [70, 70, fn(c, w, h) {
    draw_circle(c, 35, 35, 32, ["down", "#ffb347", "#ff7a00"])
    draw_circle(c, 35, 35, 32, "#c25a00", 2)
    draw_ellipse(c, 24, 20, 9, 5, -0.5, "rgba(255,255,255,0.55)")
    face(c, 35, 37, 22)
  }],
  "Kugel 2": [70, 70, fn(c, w, h) {
    draw_circle(c, 35, 37, 31, ["down", "#ffb347", "#ff7a00"])
    draw_circle(c, 35, 37, 31, "#c25a00", 2)
    face(c, 35, 39, 21)
    draw_circle(c, 35, 47, 6, "#c0392b")
  }],
  "Star": [60, 60, fn(c, w, h) {
    draw_poly(c, star_pts(30, 32, 28, 12, 5), ["down", "#fff275", "#ffc300"])
    draw_poly(c, star_pts(30, 32, 28, 12, 5) + [star_pts(30, 32, 28, 12, 5)[0]], "#d18f00", 2)
  }],
  "Rocket": [50, 80, fn(c, w, h) {
    draw_poly(c, [[8, 66], [16, 48], [16, 70]], "#e5383b")
    draw_poly(c, [[42, 66], [34, 48], [34, 70]], "#e5383b")
    draw_ellipse(c, 25, 40, 12, 32, 0, ["#d9dde6", "#ffffff", "#c9ced9"])
    draw_poly(c, [[13, 22], [25, 2], [37, 22]], "#e5383b")
    draw_circle(c, 25, 34, 6, "#3d8bfd")
    draw_circle(c, 25, 34, 6, "#1d2027", 1.5)
    draw_poly(c, [[18, 72], [25, 80], [32, 72]], "#ff9f1c")
  }],
  "Alien": [64, 56, fn(c, w, h) {
    draw_ellipse(c, 32, 30, 28, 20, 0, ["down", "#8ef06b", "#3fa34d"])
    draw_line(c, 22, 12, 16, 2, "#3fa34d", 3)
    draw_line(c, 42, 12, 48, 2, "#3fa34d", 3)
    draw_circle(c, 16, 3, 3, "#ffd23f")
    draw_circle(c, 48, 3, 3, "#ffd23f")
    draw_ellipse(c, 22, 28, 7, 9, 0, "#ffffff")
    draw_ellipse(c, 42, 28, 7, 9, 0, "#ffffff")
    draw_circle(c, 23, 30, 4, "#1d2027")
    draw_circle(c, 41, 30, 4, "#1d2027")
    draw_arc(c, 32, 38, 8, 0.4, PI - 0.4, "#1d2027", 2)
  }],
  "Ball": [40, 40, fn(c, w, h) {
    draw_circle(c, 20, 20, 18, ["down", "#7cc4ff", "#1f6fd1"])
    draw_ellipse(c, 14, 13, 5, 3, -0.5, "rgba(255,255,255,0.6)")
  }],
  "Apple": [50, 54, fn(c, w, h) {
    draw_circle(c, 18, 32, 17, "#e5383b")
    draw_circle(c, 32, 32, 17, "#e5383b")
    draw_ellipse(c, 15, 26, 5, 3, -0.6, "rgba(255,255,255,0.5)")
    draw_line(c, 25, 16, 27, 6, "#6b3e1f", 3)
    draw_ellipse(c, 33, 9, 7, 3.5, -0.4, "#2dc653")
  }],
  "Heart": [50, 46, fn(c, w, h) {
    draw_circle(c, 15, 16, 13, "#ff4d6d")
    draw_circle(c, 35, 16, 13, "#ff4d6d")
    draw_poly(c, [[3, 21], [25, 44], [47, 21], [25, 12]], "#ff4d6d")
  }],
  "Paddle": [110, 22, fn(c, w, h) {
    draw_round_rect(c, 2, 2, 106, 18, 9, ["down", "#7b5cff", "#4b2fd1"])
    draw_round_rect(c, 8, 5, 94, 4, 2, "rgba(255,255,255,0.35)")
  }],
  "Ghost": [56, 64, fn(c, w, h) {
    draw_circle(c, 28, 26, 24, "#f4f5ff")
    draw_rect(c, 4, 26, 48, 26, "#f4f5ff")
    draw_poly(c, [[4, 50], [12, 62], [20, 50], [28, 62], [36, 50], [44, 62], [52, 50]], "#f4f5ff")
    draw_ellipse(c, 20, 24, 4, 6, 0, "#1d2027")
    draw_ellipse(c, 36, 24, 4, 6, 0, "#1d2027")
  }],
  "Fish": [70, 44, fn(c, w, h) {
    draw_poly(c, [[50, 22], [68, 6], [68, 38]], "#ff9f1c")
    draw_ellipse(c, 30, 22, 26, 17, 0, ["#ffd23f", "#ff9f1c"])
    draw_circle(c, 16, 18, 4, "#1d2027")
    draw_arc(c, 34, 22, 9, -1.2, 1.2, "#e07b00", 2)
  }],
  "Tree": [70, 96, fn(c, w, h) {
    draw_rect(c, 29, 60, 12, 34, "#8d5524")
    draw_circle(c, 35, 32, 26, "#2dc653")
    draw_circle(c, 20, 46, 17, "#25a244")
    draw_circle(c, 50, 46, 17, "#25a244")
  }],
  "Cloud": [90, 50, fn(c, w, h) {
    draw_circle(c, 28, 30, 18, "#ffffff")
    draw_circle(c, 48, 22, 20, "#ffffff")
    draw_circle(c, 66, 32, 16, "#ffffff")
    draw_rect(c, 26, 32, 42, 16, "#ffffff")
  }],
  "Coin": [40, 40, fn(c, w, h) {
    draw_circle(c, 20, 20, 18, "#ffc300")
    draw_circle(c, 20, 20, 13, "#ffd60a")
    draw_text(c, 20, 21, "K", "#c98a00", 16, "center")
  }],
  "Laser": [8, 26, fn(c, w, h) { draw_round_rect(c, 1, 1, 6, 24, 3, ["down", "#ffffff", "#ff4d6d"]) }],
  "Brick": [60, 30, fn(c, w, h) {
    draw_rect(c, 1, 1, 58, 28, "#c0583a")
    draw_line(c, 1, 15, 59, 15, "#8f3b22", 2)
    draw_line(c, 30, 1, 30, 15, "#8f3b22", 2)
    draw_line(c, 15, 15, 15, 29, "#8f3b22", 2)
    draw_line(c, 45, 15, 45, 29, "#8f3b22", 2)
  }],
  "Arrow": [60, 40, fn(c, w, h) { draw_poly(c, [[2, 14], [36, 14], [36, 2], [58, 20], [36, 38], [36, 26], [2, 26]], "#3d8bfd") }],
  "Car": [90, 46, fn(c, w, h) {
    draw_round_rect(c, 4, 18, 82, 18, 6, "#e5383b")
    draw_round_rect(c, 22, 4, 44, 18, 6, "#e5383b")
    draw_rect(c, 28, 8, 14, 10, "#bde0fe")
    draw_rect(c, 46, 8, 14, 10, "#bde0fe")
    draw_circle(c, 24, 38, 8, "#1d2027")
    draw_circle(c, 66, 38, 8, "#1d2027")
  }]}
let BACK_PAINTERS = {
  "Sky": fn(c, w, h) { draw_gradient(c, 0, 0, w, h, "#5ab0f2", "#d6efff"); for i in 4 { let x = 60 + i * 110; draw_circle(c, x, 70 + (i % 2) * 30, 22, "rgba(255,255,255,0.85)"); draw_circle(c, x + 24, 64 + (i % 2) * 30, 26, "rgba(255,255,255,0.85)"); draw_circle(c, x + 48, 72 + (i % 2) * 30, 18, "rgba(255,255,255,0.85)") } },
  "Space": fn(c, w, h) {
    draw_gradient(c, 0, 0, w, h, "#05060f", "#1b1440")
    let seed = 7
    for i in 120 { seed = (seed * 9301 + 49297) % 233280; let x = seed / 233280 * w; seed = (seed * 9301 + 49297) % 233280; let y = seed / 233280 * h; draw_circle(c, x, y, 0.6 + (i % 3) * 0.5, "#ffffff") }
    draw_circle(c, 400, 70, 34, ["down", "#ffcf99", "#c7743d"])
  },
  "Grass": fn(c, w, h) { draw_gradient(c, 0, 0, w, h * 0.7, "#79c7ff", "#d9f1ff"); draw_rect(c, 0, h * 0.7, w, h * 0.3, "#5cbf4a"); draw_rect(c, 0, h * 0.7, w, 6, "#4aa63a"); draw_circle(c, 70, 60, 26, "#ffd23f") },
  "Ocean": fn(c, w, h) { draw_gradient(c, 0, 0, w, h, "#4cc9f0", "#03396c"); for i in 6 { draw_arc(c, 40 + i * 80, 40, 30, 0.2, PI - 0.2, "rgba(255,255,255,0.35)", 3) }; draw_rect(c, 0, h - 30, w, 30, "#e9d8a6") },
  "City night": fn(c, w, h) {
    draw_gradient(c, 0, 0, w, h, "#0b1026", "#2b2d6e")
    let xs = [0, 60, 110, 190, 240, 320, 380, 430]
    let hs = [150, 220, 120, 260, 170, 210, 140, 240]
    for i, x in xs {
      draw_rect(c, x, h - hs[i], 52, hs[i], "#161a33")
      let y = h - hs[i] + 12
      while y < h - 12 { draw_rect(c, x + 8, y, 8, 8, "#ffd166"); draw_rect(c, x + 30, y, 8, 8, "#ffd166"); y += 22 }
    }
  },
  "Desert": fn(c, w, h) { draw_gradient(c, 0, 0, w, h, "#ffb36b", "#ffe8c2"); draw_circle(c, 380, 90, 40, "#fff3b0"); draw_ellipse(c, 120, h, 220, 110, 0, "#e9b872"); draw_ellipse(c, 400, h, 240, 80, 0, "#d9a05b") },
  "Grid": fn(c, w, h) { draw_rect(c, 0, 0, w, h, "#ffffff"); let x = 0; while x <= w { draw_line(c, x, 0, x, h, "#e3e6ee", 1); x += 20 }; let y = 0; while y <= h { draw_line(c, 0, y, w, y, "#e3e6ee", 1); y += 20 }; draw_line(c, w / 2, 0, w / 2, h, "#b9c0d0", 1); draw_line(c, 0, h / 2, w, h / 2, "#b9c0d0", 1) },
  "White": fn(c, w, h) { draw_rect(c, 0, 0, w, h, "#ffffff") }}
fn lib_costume(name) { let p = PAINTERS[name]; return gen_costume(name, p[0], p[1], p[2]) }
fn lib_backdrop(name) { return gen_costume(name, 480, 360, BACK_PAINTERS[name]) }
fn ensure_lib() {
  if LIB != nil { return }
  LIB = {}
  for k, v in PAINTERS { LIB[k] = lib_costume(k) }
  BACKS = {}
  for k, v in BACK_PAINTERS { BACKS[k] = lib_backdrop(k) }
}

# ---------------------------------------------------------------- targets
fn make_sprite(name, costumes, x, y) {
  return {name: name, is_stage: false, costumes: costumes, costume: 0, x: x, y: y, dir: 90, size: 100, visible: true, rot: "all around", scripts: [], procs: [], vars: {}, lists: {}}
}
fn make_stage(backs) { return {name: "Stage", is_stage: true, costumes: backs, costume: 0, scripts: [], procs: [], vars: {}, lists: {}} }
fn runtime_target(t) {
  return {name: t.name, is_stage: t.is_stage, costumes: t.costumes, x: t.x or 0, y: t.y or 0, dir: dv(t.dir, 90), size: t.size or 100, costume: t.costume or 0,
    visible: t.visible != false, rot: t.rot or "all around", vars: t.vars, lists: t.lists}
}
fn target_thumb(t) {
  if len(t.costumes) == 0 { return nil }
  return t.costumes[clamp(t.costume or 0, 0, len(t.costumes) - 1)].data
}
fn new_project() {
  ensure_lib()
  let st = make_stage([BACKS["White"]])
  let k = make_sprite("Kugel", [LIB["Kugel"], LIB["Kugel 2"]], 0, 0)
  return {name: "My game", targets: [st, k], vars: {}, lists: {}, shown: {}, msgs: ["message1"], version: 1}
}
fn new_target_buttons(p) {
  btn(p, "＋ " + APP.thing, fn() { library_popup() }, "Pick a sprite from the library")
  btn(p, "🖌", fn() {
    let c = gen_costume("costume1", 80, 80, fn(c, w, h) { })
    add_target(make_sprite("Sprite", [c], 0, 0))
    show_tab("looks")
  }, "Paint a new sprite")
  btn(p, "⇧", fn() { upload_sprite() }, "Upload an image as a new sprite")
}
fn library_popup() {
  ensure_lib()
  let p = popup(E.mx_page or 900, E.my_page or 500, "kb-menu kb-lib")
  label(p, "Pick a sprite", "kapp-sec")
  let g = row(p, "kb-libgrid")
  for k, v in LIB {
    if k == "Kugel 2" { continue }
    let tile = col(g, "kb-tile")
    image(tile, v.data, "kb-thumb")
    label(tile, k, "kb-tile-name")
    let name = k
    on_click(tile, fn() {
      close_popups()
      let cs = [deep(LIB[name])]
      if name == "Kugel" { push(cs, deep(LIB["Kugel 2"])) }
      add_target(make_sprite(name, cs, random(-150, 150), random(-100, 100)))
      flash("Added " + name)
    })
  }
}
fn image_costume(f, name) {
  let info = load_image(f.data)
  if not info.ok { flash("Could not read that image"); return nil }
  let w = info.w
  let h = info.h
  let k = min(1, 200 / max(w, h))
  return {name: name, data: f.data, w: round(w * k), h: round(h * k)}
}
fn upload_sprite() {
  let f = file_open(["png", "jpg", "jpeg", "gif", "webp", "svg"])
  if f == nil or f.data == nil { return }
  let c = image_costume(f, replace(f.name, "." + f.ext, ""))
  if c == nil { return }
  add_target(make_sprite(c.name, [c], 0, 0))
}

# ---------------------------------------------------------------- stage preview (when the game is not running)
let PV = {c: nil, drag: nil, W: 384, H: 288}
fn preview_init(p) {
  PV.c = canvas(p, PV.W, PV.H)
  on_mouse(PV.c, fn(e) {
    let sx = e.x / PV.W * 480 - 240
    let sy = 180 - e.y / PV.H * 360
    settext(E.coords, "x: " + str(round(sx)) + "  y: " + str(round(sy)))
    if e.type == "down" {
      let hit = nil
      for i, t in E.proj.targets {
        if t.is_stage or not (t.visible != false) { continue }
        let b = tbox(t)
        if sx >= b.l and sx <= b.r and sy >= b.b and sy <= b.t { hit = i }
      }
      if hit != nil {
        let t = E.proj.targets[hit]
        PV.drag = {t: t, dx: sx - t.x, dy: sy - t.y}
        if hit != E.cur { select_target(hit) }
      }
    }
    if e.type == "move" and PV.drag != nil {
      PV.drag.t.x = round(clamp(sx - PV.drag.dx, -240, 240))
      PV.drag.t.y = round(clamp(sy - PV.drag.dy, -180, 180))
      E.sdirty = true
    }
    if e.type == "up" and PV.drag != nil { PV.drag = nil; refresh_props(); E.changed = true }
  })
}
fn tbox(t) {
  let c = t.costumes[clamp(t.costume or 0, 0, max(0, len(t.costumes) - 1))]
  let w = 40
  let h = 40
  if c != nil { w = c.w; h = c.h }
  let k = (t.size or 100) / 100
  return {l: t.x - w * k / 2, r: t.x + w * k / 2, b: t.y - h * k / 2, t: t.y + h * k / 2}
}
fn preview_draw() {
  let c = PV.c
  let k = PV.W / 480
  draw_clear(c, "#ffffff")
  let st = stage_target()
  if len(st.costumes) > 0 {
    let bd = st.costumes[clamp(st.costume or 0, 0, len(st.costumes) - 1)]
    draw_image(c, bd.data, 0, 0, PV.W, PV.H)
  }
  for i, t in E.proj.targets {
    if t.is_stage or t.visible == false or len(t.costumes) == 0 { continue }
    let co = t.costumes[clamp(t.costume or 0, 0, len(t.costumes) - 1)]
    let s = (t.size or 100) / 100 * k
    let w = co.w * s
    let h = co.h * s
    let rot = 0
    if dv(t.rot, "all around") == "all around" { rot = ((dv(t.dir, 90)) - 90) * PI / 180 }
    if t.rot == "left-right" and (dv(t.dir, 90)) < 0 { w = -w }
    let ok = draw_image(c, co.data, (t.x + 240) * k - abs(w) / 2, (180 - t.y) * k - h / 2, w, h, rot)
    if not ok { E.sdirty = true }
    if i == E.cur { draw_round_rect(c, (t.x + 240) * k - abs(w) / 2 - 3, (180 - t.y) * k - h / 2 - 3, abs(w) + 6, h + 6, 4, "rgba(61,139,253,0.7)", 1.5) }
  }
}
fn refresh_props() {
  clear(E.props)
  let t = cur_target()
  if t.is_stage {
    label(E.props, "The Stage: its backdrops are in 🎨 Costumes. Its scripts can switch backdrops, play sounds and broadcast.", "kapp-tiny")
    return
  }
  let r1 = row(E.props, "kb-proprow")
  label(r1, "Name", "kapp-tiny")
  let nm = textbox(r1, "name", fn(v) { rename_target(t, v) }, "kapp-field kb-pname")
  setvalue(nm, t.name)
  on_input(nm, fn(v) { rename_target(t, v) }, 600)
  let fld = fn(parent, lab, key, lo, hi) {
    label(parent, lab, "kapp-tiny")
    let f = textbox(parent, "", nil, "kapp-field kb-num")
    setvalue(f, str(t[key]))
    on_input(f, fn(v) { let n = num(trim(v)); if n != nil { t[key] = clamp(n, lo, hi); E.sdirty = true; E.changed = true } }, 250)
  }
  fld(r1, "x", "x", -240, 240)
  fld(r1, "y", "y", -180, 180)
  let r2 = row(E.props, "kb-proprow")
  fld(r2, "Size", "size", 5, 500)
  fld(r2, "Direction", "dir", -179, 180)
  checkbox(r2, "Show", t.visible != false, fn(on) { t.visible = on; E.sdirty = true })
}

# ---------------------------------------------------------------- 🎨 Costumes tab: costume list + paint editor
let PE = {c: nil, ov: nil, tool: "brush", color: "#1d2027", size: 6, undo: [], last: nil, start: nil, costume: nil, k: 1, W: 0, H: 0}
let PAINT_COLORS = ["#1d2027", "#ffffff", "#9aa1b2", "#e5383b", "#ff8c1a", "#ffd23f", "#2dc653", "#0fbd8c", "#3d8bfd", "#7b5cff", "#e055b3", "#8d5524"]
fn looks_tab(p) {
  let t = cur_target()
  let wrap = row(p, "kb-looks")
  let left = col(wrap, "kb-costumes")
  let word = "Costumes"
  if t.is_stage { word = "Backdrops" }
  label(left, word, "kapp-sec")
  for i, co in t.costumes {
    let st = "kb-tile wide"
    if i == (t.costume or 0) { st = "kb-tile wide on" }
    let tile = row(left, st)
    image(tile, co.data, "kb-thumb")
    let info = col(tile)
    label(info, str(i + 1) + ". " + co.name, "kb-tile-name")
    label(info, str(co.w) + "×" + str(co.h), "kapp-tiny")
    let ii = i
    on_click(tile, fn() { t.costume = ii; E.sdirty = true; refresh_tiles(); show_tab("looks") })
  }
  let r = row(left)
  if t.is_stage {
    btn(r, "＋ Backdrop", fn() { backdrop_popup() })
  } else {
    btn(r, "＋ Library", fn() { costume_popup() })
  }
  btn(r, "🖌 New", fn() {
    let w = 80
    let h = 80
    if t.is_stage { w = 480; h = 360 }
    push(t.costumes, gen_costume("costume" + str(len(t.costumes) + 1), w, h, fn(c, w, h) { if t.is_stage { draw_rect(c, 0, 0, w, h, "#ffffff") } }))
    t.costume = len(t.costumes) - 1
    show_tab("looks")
  })
  btn(r, "⇧", fn() {
    let f = file_open(["png", "jpg", "jpeg", "gif", "webp", "svg"])
    if f == nil or f.data == nil { return }
    let c = image_costume(f, replace(f.name, "." + f.ext, ""))
    if c == nil { return }
    if t.is_stage { c.w = 480; c.h = 360 }
    push(t.costumes, c)
    t.costume = len(t.costumes) - 1
    refresh_tiles()
    show_tab("looks")
  }, "Upload an image")
  if len(t.costumes) > 1 {
    btn(left, "🗑 Delete this costume", fn() {
      remove(t.costumes, t.costume or 0)
      t.costume = 0
      refresh_tiles()
      E.sdirty = true
      show_tab("looks")
    })
  }
  if len(t.costumes) == 0 { return }
  paint_editor(wrap, t, t.costumes[clamp(t.costume or 0, 0, len(t.costumes) - 1)])
}
fn costume_popup() {
  ensure_lib()
  let t = cur_target()
  let p = popup(E.mx_page or 500, E.my_page or 400, "kb-menu kb-lib")
  label(p, "Add a costume", "kapp-sec")
  let g = row(p, "kb-libgrid")
  for k, v in LIB {
    let tile = col(g, "kb-tile")
    image(tile, v.data, "kb-thumb")
    label(tile, k, "kb-tile-name")
    let name = k
    on_click(tile, fn() { close_popups(); push(t.costumes, deep(LIB[name])); t.costume = len(t.costumes) - 1; refresh_tiles(); E.sdirty = true; show_tab("looks") })
  }
}
fn backdrop_popup() {
  ensure_lib()
  let t = stage_target()
  let p = popup(E.mx_page or 500, E.my_page or 400, "kb-menu kb-lib")
  label(p, "Add a backdrop", "kapp-sec")
  let g = row(p, "kb-libgrid")
  for k, v in BACKS {
    let tile = col(g, "kb-tile")
    image(tile, v.data, "kb-thumb wide")
    label(tile, k, "kb-tile-name")
    let name = k
    on_click(tile, fn() { close_popups(); push(t.costumes, deep(BACKS[name])); t.costume = len(t.costumes) - 1; refresh_tiles(); E.sdirty = true; show_tab("looks") })
  }
}
fn paint_editor(parent, t, co) {
  PE.costume = co
  PE.undo = []
  let pane = col(parent, "kb-paint")
  let tools = row(pane, "kb-ptools")
  let nm = textbox(tools, "costume name", nil, "kapp-field kb-pname")
  setvalue(nm, co.name)
  on_input(nm, fn(v) { if trim(v) != "" { co.name = trim(v) } }, 400)
  for it in [["brush", "✏ Brush"], ["eraser", "⌫ Eraser"], ["fill", "🪣 Fill"], ["line", "╱ Line"], ["rect", "▭ Box"], ["circle", "◯ Circle"]] {
    let id = it[0]
    let b = btn(tools, it[1], fn() { PE.tool = id; show_tab("looks") })
    if PE.tool == id { addstyle(b, "on") }
  }
  btn(tools, "↶", fn() { paint_undo() }, "Undo")
  btn(tools, "Clear", fn() { paint_snapshot(); draw_clear(PE.c); paint_commit() })
  let cr = row(pane, "kb-ptools")
  for c in PAINT_COLORS {
    let sw = box(cr, "kb-swatch")
    setstyle(sw, "background", c)
    if c == PE.color { addstyle(sw, "on") }
    let cc = c
    on_click(sw, fn() { PE.color = cc; show_tab("looks") })
  }
  label(cr, "Size", "kapp-tiny")
  let sl = slider(cr, 1, 40, PE.size, fn(v) { PE.size = v })
  setstyle(sl, "width", 110)
  # canvas sized to the costume
  let k = min(min(520 / co.w, 380 / co.h), 6)
  PE.k = k
  PE.W = round(co.w * k)
  PE.H = round(co.h * k)
  let holder = box(pane, "kb-pholder")
  css(holder, {width: PE.W, height: PE.H})
  PE.c = canvas(holder, PE.W, PE.H)
  PE.ov = canvas(holder, PE.W, PE.H, "kb-overlay")
  canvas_load(PE.c, co.data)
  label(pane, "Costume size: " + str(co.w) + " × " + str(co.h) + " (stage units). The middle of the picture is where the sprite is.", "kapp-tiny")
  on_mouse(PE.ov, fn(e) { paint_mouse(e) })
}
fn paint_snapshot() {
  push(PE.undo, canvas_data(PE.c))
  if len(PE.undo) > 20 { remove(PE.undo, 0) }
}
fn paint_undo() {
  if len(PE.undo) == 0 { return }
  canvas_load(PE.c, pop(PE.undo))
  paint_commit()
}
fn paint_commit() {
  PE.costume.data = canvas_data(PE.c)
  E.sdirty = true
  E.changed = true
  refresh_tiles()
}
fn brush_dot(x0, y0, x1, y1) {
  let c = PE.c
  if PE.tool == "eraser" { draw_blend(c, "erase") }
  let col_ = PE.color
  if PE.tool == "eraser" { col_ = "#000000" }
  draw_line(c, x0, y0, x1, y1, col_, PE.size)
  draw_circle(c, x1, y1, PE.size / 2, col_)
  draw_circle(c, x0, y0, PE.size / 2, col_)
  draw_blend(c, "normal")
}
fn shape_to(c, a, b, color) {
  if PE.tool == "line" { draw_line(c, a.x, a.y, b.x, b.y, color, PE.size); draw_circle(c, a.x, a.y, PE.size / 2, color); draw_circle(c, b.x, b.y, PE.size / 2, color) }
  if PE.tool == "rect" { draw_rect(c, min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y), color) }
  if PE.tool == "circle" { draw_ellipse(c, (a.x + b.x) / 2, (a.y + b.y) / 2, abs(b.x - a.x) / 2, abs(b.y - a.y) / 2, 0, color) }
}
fn paint_mouse(e) {
  let p = {x: e.x, y: e.y}
  if e.type == "down" {
    paint_snapshot()
    if PE.tool == "fill" { draw_fill(PE.c, e.x, e.y, PE.color, 40); paint_commit(); return }
    PE.start = p
    PE.last = p
    if PE.tool == "brush" or PE.tool == "eraser" { brush_dot(p.x, p.y, p.x, p.y) }
    return
  }
  if e.type == "move" {
    draw_clear(PE.ov)
    if PE.start == nil {
      draw_circle(PE.ov, p.x, p.y, max(2, PE.size / 2), "rgba(0,0,0,0.5)", 1)
      return
    }
    if PE.tool == "brush" or PE.tool == "eraser" { brush_dot(PE.last.x, PE.last.y, p.x, p.y); PE.last = p; return }
    shape_to(PE.ov, PE.start, p, PE.color)
    return
  }
  if e.type == "up" and PE.start != nil {
    if PE.tool == "line" or PE.tool == "rect" or PE.tool == "circle" { draw_clear(PE.ov); shape_to(PE.c, PE.start, p, PE.color) }
    PE.start = nil
    paint_commit()
  }
}
