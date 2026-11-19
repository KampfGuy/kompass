# ---- Kugel Blocks runtime, 3D part: actors are 3D shapes (or models from the Kugel 3D Modeler) in a three.js scene.
# Sizes are metres, y is up, the ground is y = 0. Direction = yaw in degrees (0 looks toward -z, 90 toward -x).
# Gravity, jumping, standing on and bumping into solid actors are done here every frame (simple boxes, cheap on weak PCs).
let KB3_COLORS = {red: "#e5383b", orange: "#ff8c1a", yellow: "#ffd23f", green: "#2dc653", blue: "#3d8bfd", purple: "#7b5cff", pink: "#ff70a6",
  black: "#1d2027", white: "#f4f5f7", gray: "#9aa1b2", brown: "#8d5524", sky: "#87ceeb", teal: "#2bb5a8", gold: "#f4c430"}
fn kb3_col(c) { let h = KB3_COLORS[kb_str(c)]; if h == nil { return kb_str(c) } return h }
fn kb_removed(me) { if me.obj != nil { remove3d(me.obj); me.obj = nil }; if me.hud != nil { destroy(me.hud); me.hud = nil } }
fn kb3_has_model(n) { for m in model_list() { if m.name == n { return true } }; return false }
fn kb3_dims(me) {
  let k = me.size / 100
  return {x: me.w * k / 2, y: me.h * k / 2, z: me.d * k / 2}
}
fn kb3_make_obj(me) {
  let s = KB.s
  let c = kb3_col(me.color)
  let o = nil
  if me.shape == "sphere" { o = sphere(s, 0.5, c) }
  if me.shape == "cylinder" { o = cylinder(s, 0.5, 1, c) }
  if me.shape == "cone" { o = cone(s, 0.5, 1, c) }
  if me.shape == "torus" { o = torus(s, 0.38, 0.12, c) }
  if me.shape == "plane" { o = cube(s, 1, 1, 1, c) }
  if me.shape == "model" and me.model != "" {
    if kb3_has_model(me.model) { o = load_model(s, me.model) }
  }
  if o == nil { o = cube(s, 1, 1, 1, c) }
  if me.texture != "" and me.texture != "none" and me.shape != "model" { look3d(o, {texture: me.texture, repeat: 1}) }
  if me.glow != "" and me.glow != "none" and me.shape != "model" { look3d(o, {glow: kb3_col(me.glow)}) }
  me.obj = o
  me._sk = ""
  me._vis = nil
}
fn kb_new_inst(t, from) {
  let me = {name: t.name, t: t, x: 0, y: 0, z: 0, yaw: 0, rx: 0, rz: 0, size: 100, visible: true, say: "", think: false, vars: {}, lists: {}, clone: false, dead: false,
    threads: [], is_stage: t.is_stage, vy: 0, grav: false, ground: false, solid: false, shape: "cube", model: "", color: "orange", texture: "", glow: "",
    w: 1, h: 1, d: 1, obj: nil, hud: nil}
  let src = t
  if from != nil { src = from }
  for k in ["x", "y", "z", "yaw", "size", "visible", "grav", "solid", "shape", "model", "color", "texture", "w", "h", "d", "rx", "rz", "glow"] { if src[k] != nil { me[k] = src[k] } }
  if me.shape == "plane" and from == nil { me.h = 0.1 }
  if from != nil { for k, v in from.vars { me.vars[k] = v }; for k, v in from.lists { me.lists[k] = slice(v) }; me.clone = true } else {
    for k, v in t.vars { me.vars[k] = v }
    for k, v in t.lists { me.lists[k] = slice(v) }
  }
  if not t.is_stage {
    if from != nil and from.obj != nil and me.shape == "model" { me.obj = clone3d(from.obj); me._sk = ""; me._vis = nil } else { kb3_make_obj(me) }
  }
  push(KB.insts, me)
  return me
}
fn kb_stage_inst() { for i in KB.insts { if i.is_stage { return i } }; return nil }
fn kb3_find(name) { for i in KB.insts { if i.name == name and not i.clone and not i.dead and not i.is_stage { return i } }; return nil }

# ---- motion
fn kb3_solid_hit(me, x, y, z) {
  let a = kb3_dims(me)
  for o in KB.insts {
    if o == me or not o.solid or o.dead or o.is_stage or not o.visible { continue }
    let b = kb3_dims(o)
    if abs(x - o.x) < a.x + b.x - 0.01 and abs(z - o.z) < a.z + b.z - 0.01 and abs(y - o.y) < a.y + b.y - 0.06 { return o }
  }
  return nil
}
fn kb3_to(me, x, y, z) {
  # walls (solid actors) stop movement; slide along one axis if the other is free
  x = kb_num(x)
  y = kb_num(y)
  z = kb_num(z)
  if me.solid or kb3_solid_hit(me, x, y, z) == nil { me.x = x; me.y = y; me.z = z; return }
  if kb3_solid_hit(me, x, me.y, me.z) == nil { me.x = x }
  if kb3_solid_hit(me, me.x, me.y, z) == nil { me.z = z }
}
fn kb3_goto(me, x, y, z) { me.x = kb_num(x); me.y = kb_num(y); me.z = kb_num(z); me.vy = 0 }
fn kb3_move(me, n) {
  let a = me.yaw * PI / 180
  kb3_to(me, me.x - sin(a) * kb_num(n), me.y, me.z - cos(a) * kb_num(n))
}
fn kb3_turn(me, d) { me.yaw = kb3_dir(me.yaw - kb_num(d)) }
fn kb3_dir(d) { let r = kb_mod(d + 180, 360) - 180; if r == -180 { r = 180 }; return r }
fn kb3_where(what) {
  if what == "random position" { return {x: random_float(-8, 8), y: 0.5, z: random_float(-8, 8)} }
  if what == "camera" { let c = camera_get(KB.s); return {x: c.x, y: c.y, z: c.z} }
  let o = kb3_find(what)
  if o == nil { return nil }
  return {x: o.x, y: o.y, z: o.z}
}
fn kb3_goto_target(me, what) { let p = kb3_where(what); if p != nil { kb3_goto(me, p.x, max(p.y, kb3_dims(me).y), p.z) } }
fn kb3_point_towards(me, what) {
  let p = kb3_where(what)
  if p == nil { return }
  let dx = p.x - me.x
  let dz = p.z - me.z
  if dx == 0 and dz == 0 { return }
  me.yaw = kb3_dir(atan2(-dx, -dz) * 180 / PI)
}
fn kb3_glide(me, secs, x, y, z) {
  let t0 = time()
  let dur = max(0.001, kb_num(secs)) * 1000
  let sx = me.x
  let sy = me.y
  let sz = me.z
  let tx = kb_num(x)
  let ty = kb_num(y)
  let tz = kb_num(z)
  while time() - t0 < dur {
    let k = (time() - t0) / dur
    me.x = sx + (tx - sx) * k
    me.y = sy + (ty - sy) * k
    me.z = sz + (tz - sz) * k
    kb_yield(me)
  }
  kb3_goto(me, tx, ty, tz)
}
fn kb3_walk(me, scheme, speed) {
  let dt = KB.dt
  let fwd = 0
  let side = 0
  let turn = 0
  let pad = gamepad()
  if scheme == "WASD + mouse" {
    if key_down("w") or key_down("up") { fwd += 1 }
    if key_down("s") or key_down("down") { fwd -= 1 }
    if key_down("a") { side -= 1 }
    if key_down("d") { side += 1 }
    if key_down("left") { turn += 1 }
    if key_down("right") { turn -= 1 }
  } else {
    if key_down("up") or key_down("w") { fwd += 1 }
    if key_down("down") or key_down("s") { fwd -= 1 }
    if key_down("left") or key_down("a") { turn += 1 }
    if key_down("right") or key_down("d") { turn -= 1 }
  }
  if pad.connected {
    if abs(pad.ly) > 0.15 { fwd -= pad.ly }
    if abs(pad.lx) > 0.15 { if scheme == "WASD + mouse" { side += pad.lx } else { turn -= pad.lx } }
    if abs(pad.rx) > 0.15 { turn -= pad.rx }
  }
  me.yaw = kb3_dir(me.yaw + turn * 140 * dt)
  let a = me.yaw * PI / 180
  let sp = kb_num(speed) * dt
  if key_down("shift") { sp *= 1.7 }
  let nx = me.x + (-sin(a) * fwd + cos(a) * side) * sp
  let nz = me.z + (-cos(a) * fwd - sin(a) * side) * sp
  if fwd != 0 or side != 0 { kb3_to(me, nx, me.y, nz) }
}
fn kb3_jump(me, v) { if me.ground or not me.grav { me.vy = kb_num(v); me.ground = false; if not me.grav { me.grav = true } } }
fn kb3_on_ground(me) { return me.ground }

# ---- looks
fn kb3_set_color(me, c) { me.color = kb_str(c); if me.obj != nil and me.shape != "model" { look3d(me.obj, {color: kb3_col(c)}) } }
fn kb3_set_glow(me, c) { me.glow = kb_str(c); if me.obj != nil and me.shape != "model" { if kb_str(c) == "none" { look3d(me.obj, {glow: "#000000"}) } else { look3d(me.obj, {glow: kb3_col(c)}) } } }
fn kb3_set_texture(me, t) { me.texture = kb_str(t); if me.obj != nil and me.shape != "model" { if me.texture == "none" { look3d(me.obj, {texture: false}) } else { look3d(me.obj, {texture: me.texture}) } } }
fn kb3_set_shape(me, shape, model) {
  me.shape = kb_str(shape)
  if model != nil { me.model = kb_str(model) }
  if me.obj != nil { remove3d(me.obj) }
  kb3_make_obj(me)
}
fn kb3_spin(me, x, y, z) { me.rx += kb_num(x); me.yaw = kb3_dir(me.yaw + kb_num(y)); me.rz += kb_num(z) }

# ---- sensing
fn kb3_touching(me, what) {
  if not me.visible or me.is_stage { return false }
  if what == "ground" { return me.y - kb3_dims(me).y <= 0.02 and KB.world.ground }
  let a = kb3_dims(me)
  for o in KB.insts {
    if o == me or o.name != what or o.dead or not o.visible { continue }
    let b = kb3_dims(o)
    if abs(me.x - o.x) <= a.x + b.x + 0.02 and abs(me.y - o.y) <= a.y + b.y + 0.02 and abs(me.z - o.z) <= a.z + b.z + 0.02 { return true }
  }
  return false
}
fn kb3_distance(me, what) { let p = kb3_where(what); if p == nil { return 0 } return round(hypot(p.x - me.x, p.y - me.y, p.z - me.z), 3) }
fn kb3_of(what, prop) {
  let o = kb3_find(what)
  if o == nil { return 0 }
  if prop == "x position" { return o.x }
  if prop == "y position" { return o.y }
  if prop == "z position" { return o.z }
  if prop == "direction" { return o.yaw }
  if prop == "size" { return o.size }
  let v = o.vars[prop]
  if v == nil { return 0 }
  return v
}
fn kb3_pad(btn) { let p = gamepad(); if not p.connected { return false } return p[btn] == true or (type(p[btn]) == "number" and p[btn] > 0.5) }
fn kb3_stick(axis) { let p = gamepad(); if not p.connected { return 0 } return round(p[axis], 3) }
fn kb_mouse_down() { return KB.mdown }

# ---- camera & world
fn kb3_follow(me, who) { KB.cam.mode = "follow"; KB.cam.target = who }
fn kb3_first(me, who) { KB.cam.mode = "first"; KB.cam.target = who }
fn kb3_fixed(x, y, z) { KB.cam.mode = "fixed"; KB.cam.x = kb_num(x); KB.cam.y = kb_num(y); KB.cam.z = kb_num(z); KB.cam.target = "" }
fn kb3_cam_dist(d) { KB.cam.dist = clamp(kb_num(d), 1, 60) }
fn kb3_fov(f) { camera_fov(KB.s, clamp(kb_num(f), 20, 120)) }
fn kb3_sky(c) { KB.world.sky = kb3_col(c); KB.world.sky2 = ""; sky3d(KB.s, KB.world.sky) }
fn kb3_fog(on) { if on == "on" { fog3d(KB.s, KB.world.sky, 12, 60) } else { fog3d(KB.s, false) } }
fn kb3_ground_color(c) { if KB.ground != nil { look3d(KB.ground, {color: kb3_col(c)}) } }
fn kb3_gravity(g) { KB.world.gravity = kb_num(g) }
fn kb3_light(kind) {
  light3d(KB.s, "none")
  if kind == "night" { light3d(KB.s, "ambient", "#5060a0", 0.5); light3d(KB.s, "sun", "#a0b0ff", 0.5, -4, 8, 3) }
  elif_light(kind)
}
fn elif_light(kind) {
  if kind == "sunset" { light3d(KB.s, "ambient", "#ffd0b0", 0.7); light3d(KB.s, "sun", "#ff9a50", 1.6, -8, 4, 2) }
  if kind == "day" or kind == "" { light3d(KB.s, "ambient", "#ffffff", 0.9); light3d(KB.s, "sun", "#ffffff", 1.6, 4, 9, 5) }
}
fn kb3_apply_world(w) {
  if w.sky2 != nil and w.sky2 != "" { sky3d(KB.s, kb3_col(w.sky), kb3_col(w.sky2)) } else { sky3d(KB.s, kb3_col(w.sky)) }
  kb3_light(w.light or "day")
  if w.fog == true { fog3d(KB.s, kb3_col(w.sky), 12, 60) }
  if w.ground {
    KB.ground = plane(KB.s, 200, 200, kb3_col(w.ground_color))
    if w.ground_tex != nil and w.ground_tex != "none" { look3d(KB.ground, {texture: w.ground_tex, repeat: 100}) }
  }
}

# ---- every frame: physics, objects, camera, speech bubbles, variable monitors
fn kb3_frame(dt) {
  KB.dt = dt
  let g = KB.world.gravity
  for me in KB.insts {
    if me.is_stage or me.dead or me.obj == nil { continue }
    if me.grav {
      me.vy -= g * dt
      let ny = me.y + me.vy * dt
      let a = kb3_dims(me)
      let floor = -1000
      if KB.world.ground { floor = 0 }
      me.ground = false
      for o in KB.insts {
        if o == me or not o.solid or o.dead or o.is_stage or not o.visible { continue }
        let b = kb3_dims(o)
        if abs(me.x - o.x) < a.x + b.x - 0.02 and abs(me.z - o.z) < a.z + b.z - 0.02 {
          let top = o.y + b.y
          if me.y - a.y >= top - 0.08 and ny - a.y <= top + 0.001 { floor = max(floor, top) }
          let bottom = o.y - b.y
          if me.vy > 0 and me.y + a.y <= bottom + 0.05 and ny + a.y > bottom { ny = bottom - a.y; me.vy = 0 }
        }
      }
      if ny - a.y <= floor and me.vy <= 0 { ny = floor + a.y; me.vy = 0; me.ground = true }
      if ny < -60 { ny = -60; me.vy = 0 }
      me.y = ny
    }
    move3d(me.obj, me.x, me.y, me.z)
    turn3d(me.obj, me.rx, me.yaw, me.rz)
    let k = me.size / 100
    let sk = str(me.w * k) + "," + str(me.h * k) + "," + str(me.d * k)
    if sk != me._sk {
      me._sk = sk
      if me.shape == "model" { scale3d(me.obj, k) } else { scale3d(me.obj, me.w * k, me.h * k, me.d * k) }
    }
    let vis = me.visible and not (KB.cam.mode == "first" and KB.cam.target == me.name and not me.clone)
    if vis != me._vis { me._vis = vis; show3d(me.obj, vis) }
  }
  kb3_camera(dt)
  kb3_huds()
}
fn kb3_camera(dt) {
  let c = KB.cam
  if c.mode == "fixed" { camera3d(KB.s, c.x, c.y, c.z, c.lx, c.ly, c.lz); return }
  let o = kb3_find(c.target)
  if o == nil { return }
  let a = o.yaw * PI / 180
  let h = kb3_dims(o).y
  if c.mode == "first" {
    camera3d(KB.s, o.x, o.y + h * 0.6, o.z)
    camera_angles(KB.s, o.yaw, c.pitch)
    return
  }
  let tx = o.x + sin(a) * c.dist
  let ty = o.y + c.dist * 0.45 + 0.5
  let tz = o.z + cos(a) * c.dist
  let k = min(1, dt * 5)
  if c.cx == nil { c.cx = tx; c.cy = ty; c.cz = tz }
  c.cx += (tx - c.cx) * k
  c.cy += (ty - c.cy) * k
  c.cz += (tz - c.cz) * k
  camera3d(KB.s, c.cx, c.cy, c.cz, o.x, o.y + h * 0.5, o.z)
}
fn kb3_huds() {
  for me in KB.insts {
    if me.is_stage or me.dead { continue }
    if me.say == "" or not me.visible {
      if me.hud != nil { show(me.hud, false) }
      continue
    }
    if me.hud == nil {
      me.hud = label(KB.s, "")
      css3(me.hud, {position: "absolute", background: "#ffffff", color: "#1d2027", padding: "4px 9px", "border-radius": 10, "font-size": 13, "pointer-events": "none", "white-space": "nowrap", "box-shadow": "0 2px 6px rgba(0,0,0,0.3)", transform: "translate(-50%, -100%)", "z-index": 3})
    }
    let p = project3d(KB.s, {x: me.x, y: me.y + kb3_dims(me).y + 0.3, z: me.z})
    if not p.visible { show(me.hud, false); continue }
    show(me.hud, true)
    if gettext(me.hud) != me.say { settext(me.hud, me.say) }
    setstyle(me.hud, "left", round(p.x))
    setstyle(me.hud, "top", round(p.y))
  }
  let lines = []
  for name, on in KB.shown { if on { push(lines, name + ": " + kb_str(KB.vars[name])) } }
  let t = join(lines, "   ")
  if t != KB.mon_text {
    KB.mon_text = t
    settext(KB.mon, t)
    show(KB.mon, t != "")
  }
}
fn css3(el, m) { for k, v in m { setstyle(el, k, v) } }
fn kb_start(project) {
  KB.project = project
  KB.dt = 1 / 60
  KB.root = box(body())
  css3(KB.root, {position: "absolute", inset: 0, background: "#000000"})
  KB.s = scene3d(KB.root)
  shadows3d(KB.s, false)
  let st = nil
  for t in project.targets { if t.is_stage { st = t } }
  KB.world = {sky: "sky", sky2: "", ground: true, ground_color: "green", ground_tex: "grid", fog: false, light: "day", gravity: 20, perf: false, cam: {x: 0, y: 6, z: 12}}
  if st != nil and st.world != nil { for k, v in st.world { KB.world[k] = v } }
  if KB.world.perf { pixel_ratio3d(KB.s, 0.6) } else { pixel_ratio3d(KB.s, 1) }
  KB.cam = {mode: "fixed", target: "", x: KB.world.cam.x, y: KB.world.cam.y, z: KB.world.cam.z, lx: 0, ly: 0, lz: 0, dist: 6, pitch: -8}
  kb3_apply_world(KB.world)
  KB.mon = label(KB.s, "")
  css3(KB.mon, {position: "absolute", left: 8, top: 8, background: "rgba(20,22,28,0.75)", color: "#ffffff", padding: "3px 9px", "border-radius": 6, "font-size": 13, "pointer-events": "none", "z-index": 3})
  show(KB.mon, false)
  KB.mon_text = ""
  for t in project.targets {
    let tt = t
    if tt.vars == nil { tt.vars = {} }
    if tt.lists == nil { tt.lists = {} }
    KB.targets[t.name] = tt
    push(KB.order, t.name)
  }
  for k, v in project.vars { KB.vars[k] = v }
  for k, v in project.lists { KB.lists[k] = slice(v) }
  for k, v in project.shown { KB.shown[k] = v }
  for name in KB.order { kb_new_inst(KB.targets[name], nil) }
  KB.lastx = nil
  on_mouse(KB.s, fn(e) {
    if e.type == "down" {
      KB.mdown = true
      KB.lastx = e.x
      KB.lasty = e.y
      let hit = pick3d(KB.s, e.x, e.y)
      let who = nil
      if hit != nil { for i in KB.insts { if i.obj == hit.obj and not i.dead { who = i } } }
      if who != nil { kb_fire("click", "", who) } else { let w = kb_stage_inst(); if w != nil { kb_fire("click", "", w) } }
    }
    if e.type == "up" { KB.mdown = false }
    if e.type == "move" and KB.mdown and KB.lastx != nil and KB.cam.mode != "fixed" {
      # dragging the mouse turns the followed actor (and looks up / down in first person)
      let o = kb3_find(KB.cam.target)
      if o != nil {
        o.yaw = kb3_dir(o.yaw - (e.x - KB.lastx) * 0.3)
        KB.cam.pitch = clamp(KB.cam.pitch - (e.y - KB.lasty) * 0.25, -80, 80)
      }
      KB.lastx = e.x
      KB.lasty = e.y
    }
  })
  on_keypress(fn(k) { kb_fire("key", k, nil) })
  on_frame(fn(dt) { kb3_frame(dt) })
}
fn kb_go() {
  KB.ready = true
  kb_fire("flag", "", nil)
}
fn kb_say3(me, text, secs) { me.say = kb_str(text); kb_wait(me, secs); me.say = "" }
