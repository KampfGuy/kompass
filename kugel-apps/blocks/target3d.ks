# ---- Kugel Blocks 3D: actors, the World, the 3D preview and the Look tab.
APP.icon = "🧊"
APP.looks_tab = "🧊 Look"
APP.hello = "Drag blocks into the middle and press ⚑ Go. Try ★ Samples: Coin Run, Maze Walk, Space Dodge."
let GEN = box(body())
css(GEN, {position: "absolute", left: -5000, top: 0, width: 400, height: 400, overflow: "hidden"})
let C3 = {red: "#e5383b", orange: "#ff8c1a", yellow: "#ffd23f", green: "#2dc653", blue: "#3d8bfd", purple: "#7b5cff", pink: "#ff70a6",
  black: "#1d2027", white: "#f4f5f7", gray: "#9aa1b2", brown: "#8d5524", sky: "#87ceeb", teal: "#2bb5a8", gold: "#f4c430"}
fn c3(c) { let h = C3[c]; if h == nil { return c } return h }
let THUMBS = {}

fn make_actor(name, shape, color, x, y, z) {
  let h = 1
  if shape == "plane" { h = 0.1 }
  return {name: name, is_stage: false, costumes: [], shape: shape, model: "", color: color, texture: "", glow: "", x: x, y: y, z: z, yaw: 0, size: 100,
    w: 1, h: h, d: 1, visible: true, grav: false, solid: false, scripts: [], procs: [], vars: {}, lists: {}}
}
fn make_world() {
  return {name: "World", is_stage: true, costumes: [], scripts: [], procs: [], vars: {}, lists: {},
    world: {sky: "sky", sky2: "white", ground: true, ground_color: "green", ground_tex: "grid", fog: false, light: "day", gravity: 20, perf: false, cam: {x: 0, y: 6, z: 12}}}
}
fn runtime_target(t) {
  let out = {}
  for k, v in t { if k != "scripts" and k != "procs" and k != "costumes" { out[k] = v } }
  out.costumes = []
  return out
}
fn target_thumb(t) {
  let key = ""
  if t.is_stage { key = "world:" + t.world.sky + t.world.ground_color } else { key = t.shape + ":" + t.color }
  if THUMBS[key] != nil { return THUMBS[key] }
  let c = canvas(GEN, 56, 44)
  if t.is_stage {
    draw_gradient(c, 0, 0, 56, 30, c3(t.world.sky), c3(t.world.sky2 or t.world.sky))
    draw_rect(c, 0, 30, 56, 14, c3(t.world.ground_color))
  } else {
    let col_ = c3(t.color)
    let sh = t.shape
    if sh == "sphere" { draw_circle(c, 28, 22, 17, ["down", "#ffffff", col_]) }
    if sh == "cube" or sh == "model" { draw_poly(c, [[14, 14], [36, 14], [44, 8], [22, 8]], "#ffffff"); draw_rect(c, 14, 14, 22, 24, col_); draw_poly(c, [[36, 14], [44, 8], [44, 32], [36, 38]], darker(col_, 0.7)) }
    if sh == "cylinder" { draw_rect(c, 14, 10, 28, 26, col_); draw_ellipse(c, 28, 10, 14, 5, 0, "#ffffff"); draw_ellipse(c, 28, 36, 14, 5, 0, col_) }
    if sh == "cone" { draw_poly(c, [[28, 4], [44, 36], [12, 36]], col_); draw_ellipse(c, 28, 36, 16, 5, 0, darker(col_, 0.8)) }
    if sh == "torus" { draw_circle(c, 28, 22, 15, col_, 7) }
    if sh == "plane" { draw_poly(c, [[6, 30], [20, 18], [50, 18], [36, 30]], col_) }
    if sh == "model" { draw_text(c, 40, 34, "M", "#ffffff", 12, "center") }
  }
  let d = canvas_data(c)
  destroy(c)
  THUMBS[key] = d
  return d
}
fn new_project() {
  let w = make_world()
  let p = make_actor("Player", "sphere", "orange", 0, 0.5, 0)
  return {name: "My 3D game", targets: [w, p], vars: {}, lists: {}, shown: {}, msgs: ["message1"], version: 1}
}
fn new_target_buttons(p) {
  btn(p, "＋ " + APP.thing, fn() { actor_popup() }, "Add a new actor")
}
fn actor_popup() {
  let p = popup(E.mx_page or 900, E.my_page or 500, "kb-menu kb-lib")
  label(p, "Add an actor", "kapp-sec")
  let g = row(p, "kb-libgrid")
  for it in [["Cube", "cube", "blue"], ["Ball", "sphere", "orange"], ["Cylinder", "cylinder", "green"], ["Cone", "cone", "yellow"], ["Ring", "torus", "gold"], ["Platform", "plane", "gray"]] {
    let tile = col(g, "kb-tile")
    let a = make_actor(it[0], it[1], it[2], 0, 0.5, 0)
    image(tile, target_thumb(a), "kb-thumb")
    label(tile, it[0], "kb-tile-name")
    on_click(tile, fn() { close_popups(); a.x = random(-4, 4); a.z = random(-4, 2); if a.shape == "plane" { a.w = 4; a.d = 4; a.y = 0.05 }; add_target(a) })
  }
  let models = model_list()
  label(p, "Your models (from the Kugel 3D Modeler → 📦 To games)", "kapp-sec")
  if len(models) == 0 { label(p, "None yet. Make one in the Kugel 3D Modeler (Kugel Store) and press 📦 To games.", "kapp-tiny") }
  let g2 = row(p, "kb-libgrid")
  for m in models {
    let name = m.name
    btn(g2, "▣ " + name, fn() { close_popups(); let a = make_actor(name, "model", "white", 0, 0.5, 0); a.model = name; add_target(a) })
  }
}

# ---------------------------------------------------------------- 3D preview (editor)
let PV = {s: nil, objs: [], ground: nil, drag: nil, sky: ""}
fn preview_init(p) {
  PV.s = scene3d(p, 384, 288)
  shadows3d(PV.s, false)
  pixel_ratio3d(PV.s, 1)
  camera3d(PV.s, 0, 6, 12, 0, 0, 0)
  orbit3d(PV.s, {target: {x: 0, y: 0.5, z: 0}})
  let hint = label(PV.s, "drag an actor to move it · right-drag: turn the view · wheel: zoom", "kapp-hud")
  setstyle(hint, "position", "absolute")
  setstyle(hint, "font-size", 10.5)
  on_mouse(PV.s, fn(e) {
    if e.type == "down" and e.button == "left" {
      let hit = pick3d(PV.s, e.x, e.y)
      if hit != nil {
        for it in PV.objs {
          if it.o == hit.obj {
            let i = indexof(E.proj.targets, it.t)
            PV.drag = {t: it.t, x: e.x, y: e.y}
            if i >= 0 and i != E.cur { select_target(i) }
          }
        }
      }
    }
    if e.type == "move" and PV.drag != nil {
      let cam = camera_get(PV.s)
      let a = cam.yaw * PI / 180
      let k = 0.02 * max(4, hypot(cam.x, cam.y, cam.z)) / 12
      let dx = (e.x - PV.drag.x) * k
      let dy = (e.y - PV.drag.y) * k
      let t = PV.drag.t
      t.x = round(t.x + cos(a) * dx + sin(a) * dy, 2)
      t.z = round(t.z - sin(a) * dx + cos(a) * dy, 2)
      PV.drag.x = e.x
      PV.drag.y = e.y
      for it in PV.objs { if it.t == t { move3d(it.o, t.x, t.y, t.z) } }
    }
    if e.type == "up" and PV.drag != nil { PV.drag = nil; refresh_props(); E.changed = true }
  })
}
fn pv_make(t) {
  let s = PV.s
  let col_ = c3(t.color)
  let o = nil
  if t.shape == "sphere" { o = sphere(s, 0.5, col_) }
  if t.shape == "cylinder" { o = cylinder(s, 0.5, 1, col_) }
  if t.shape == "cone" { o = cone(s, 0.5, 1, col_) }
  if t.shape == "torus" { o = torus(s, 0.38, 0.12, col_) }
  if t.shape == "model" and t.model != "" {
    let ok = false
    for m in model_list() { if m.name == t.model { ok = true } }
    if ok { o = load_model(s, t.model) }
  }
  if o == nil { o = cube(s, 1, 1, 1, col_) }
  if t.texture != "" and t.texture != "none" and t.shape != "model" { look3d(o, {texture: t.texture}) }
  if t.glow != "" and t.glow != "none" and t.shape != "model" { look3d(o, {glow: c3(t.glow)}) }
  let k = (t.size or 100) / 100
  move3d(o, t.x, t.y, t.z)
  turn3d(o, 0, t.yaw or 0, 0)
  if t.shape == "model" { scale3d(o, k) } else { scale3d(o, t.w * k, t.h * k, t.d * k) }
  show3d(o, t.visible != false)
  return o
}
fn preview_draw() {
  for it in PV.objs { remove3d(it.o) }
  PV.objs = []
  let w = stage_target().world
  let sk = w.sky + "|" + (w.sky2 or "") + "|" + str(w.ground) + w.ground_color + (w.ground_tex or "")
  if sk != PV.sky {
    PV.sky = sk
    if w.sky2 != nil and w.sky2 != "" { sky3d(PV.s, c3(w.sky), c3(w.sky2)) } else { sky3d(PV.s, c3(w.sky)) }
    if PV.ground != nil { remove3d(PV.ground); PV.ground = nil }
    if w.ground {
      PV.ground = plane(PV.s, 60, 60, c3(w.ground_color))
      if w.ground_tex != nil and w.ground_tex != "none" { look3d(PV.ground, {texture: w.ground_tex, repeat: 30}) }
    }
  }
  for i, t in E.proj.targets {
    if t.is_stage { continue }
    let o = pv_make(t)
    if i == E.cur and t.shape != "model" { look3d(o, {glow: "#553311"}) }
    push(PV.objs, {o: o, t: t})
  }
}
fn refresh_props() {
  clear(E.props)
  let t = cur_target()
  if t.is_stage {
    label(E.props, "The World: sky, ground, light, gravity and the start camera are in 🧊 Look. World scripts can change them while the game runs.", "kapp-tiny")
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
    on_input(f, fn(v) { let n = num(trim(v)); if n != nil { t[key] = clamp(n, lo, hi); E.sdirty = true; E.changed = true } }, 300)
  }
  checkbox(r1, "Show", t.visible != false, fn(on) { t.visible = on; E.sdirty = true })
  let r2 = row(E.props, "kb-proprow")
  fld(r2, "x", "x", -500, 500)
  fld(r2, "y", "y", -100, 500)
  fld(r2, "z", "z", -500, 500)
  let r3 = row(E.props, "kb-proprow")
  fld(r3, "Size %", "size", 5, 1000)
  fld(r3, "Direction", "yaw", -180, 180)
}

# ---------------------------------------------------------------- 🧊 Look tab
fn swatches(p, cur, pick) {
  let r = row(p, "kb-ptools")
  for name in COLOR_NAMES {
    let sw = box(r, "kb-swatch")
    setstyle(sw, "background", c3(name))
    settip(sw, name)
    if name == cur { addstyle(sw, "on") }
    let n = name
    on_click(sw, fn() { pick(n) })
  }
  return r
}
fn choice_row(p, items, cur, pick) {
  let r = row(p, "kb-ptools")
  for it in items {
    let v = it
    let b = btn(r, it, fn() { pick(v) })
    if it == cur { addstyle(b, "on") }
  }
  return r
}
fn looks_tab(p) {
  let t = cur_target()
  let changed = fn() { E.sdirty = true; E.changed = true; refresh_tiles(); show_tab("looks") }
  let c = col(p, "kb-look3d")
  if t.is_stage {
    let w = t.world
    label(c, "🌍 World", "kb-h2")
    label(c, "Sky (top)", "kapp-sec")
    swatches(c, w.sky, fn(n) { w.sky = n; changed() })
    label(c, "Sky (bottom)", "kapp-sec")
    swatches(c, w.sky2, fn(n) { w.sky2 = n; changed() })
    label(c, "Ground", "kapp-sec")
    checkbox(c, "Show the ground (y = 0)", w.ground, fn(on) { w.ground = on; changed() })
    swatches(c, w.ground_color, fn(n) { w.ground_color = n; changed() })
    choice_row(c, ["none", "grid", "checker", "noise", "bricks"], w.ground_tex or "none", fn(v) { w.ground_tex = v; changed() })
    label(c, "Light", "kapp-sec")
    choice_row(c, ["day", "sunset", "night"], w.light, fn(v) { w.light = v; changed() })
    checkbox(c, "Fog", w.fog == true, fn(on) { w.fog = on; changed() })
    label(c, "Gravity (20 = like a game, 9.8 = Earth)", "kapp-sec")
    let g = textbox(c, "", nil, "kapp-field kb-num")
    setvalue(g, str(w.gravity))
    on_input(g, fn(v) { let n = num(v); if n != nil { w.gravity = clamp(n, 0, 200) } }, 300)
    label(c, "Camera at the start (looks at 0, 0, 0)", "kapp-sec")
    let r = row(c, "kb-proprow")
    for k in ["x", "y", "z"] {
      label(r, k, "kapp-tiny")
      let f = textbox(r, "", nil, "kapp-field kb-num")
      setvalue(f, str(w.cam[k]))
      let kk = k
      on_input(f, fn(v) { let n = num(v); if n != nil { w.cam[kk] = n } }, 300)
    }
    label(c, "Speed", "kapp-sec")
    checkbox(c, "⚡ Performance mode for weak PCs (lower resolution)", w.perf == true, fn(on) { w.perf = on })
    return
  }
  label(c, "🧊 " + t.name, "kb-h2")
  label(c, "Shape", "kapp-sec")
  choice_row(c, ["cube", "sphere", "cylinder", "cone", "torus", "plane"], t.shape, fn(v) { t.shape = v; if v == "plane" and t.h > 0.2 { t.h = 0.1 }; if v != "plane" and t.h < 0.2 { t.h = 1 }; changed() })
  label(c, "Model from the Kugel 3D Modeler", "kapp-sec")
  let models = model_list()
  if len(models) == 0 { label(c, "No models yet — make one in the Kugel 3D Modeler and press 📦 To games.", "kapp-tiny") } else {
    choice_row(c, map(models, fn(m) { return m.name }), t.model, fn(v) { t.shape = "model"; t.model = v; changed() })
  }
  label(c, "Color", "kapp-sec")
  swatches(c, t.color, fn(n) { t.color = n; changed() })
  label(c, "Pattern", "kapp-sec")
  choice_row(c, ["none", "checker", "grid", "bricks", "stripes", "noise"], t.texture or "none", fn(v) { t.texture = v; changed() })
  label(c, "Glow", "kapp-sec")
  choice_row(c, ["none", "yellow", "orange", "red", "blue", "green", "white"], t.glow or "none", fn(v) { t.glow = v; changed() })
  label(c, "Size in metres (width × height × depth, at 100 %)", "kapp-sec")
  let r = row(c, "kb-proprow")
  for k in ["w", "h", "d"] {
    let f = textbox(r, "", nil, "kapp-field kb-num")
    setvalue(f, str(t[k]))
    let kk = k
    on_input(f, fn(v) { let n = num(v); if n != nil { t[kk] = clamp(n, 0.02, 200); E.sdirty = true } }, 300)
  }
  label(c, "At the start", "kapp-sec")
  checkbox(c, "Gravity (falls and lands on the ground / solid actors)", t.grav == true, fn(on) { t.grav = on })
  checkbox(c, "Solid (a wall or floor others bump into and stand on)", t.solid == true, fn(on) { t.solid = on })
}
