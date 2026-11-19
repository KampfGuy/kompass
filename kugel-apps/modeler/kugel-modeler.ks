# ============================================================================
#  ⬢ Kugel 3D Modeler — a small Blender-style 3D modeler written in KampfScript
#  Kugel Store app for Kompass 1.7+.  Made to run on weak PCs: no shadows, a low
#  pixel ratio in ⚡ Performance mode, simple materials.
#
#  Mouse:  left click = select (Shift = add) · drag on empty space = box select
#          right / middle drag = orbit · Shift + right/middle drag = pan · wheel = zoom
#  Keys:   Tab = Object / Edit mode · 1 vertices · 3 faces · A = select all / none
#          G move · R rotate · S scale  (then X / Y / Z = axis, type a number, click = OK,
#          Esc or right click = cancel) · E extrude · X / Delete delete · Shift+D duplicate
#          M merge · F frame selection · Ctrl+Z undo · Ctrl+Shift+Z redo
#  Your models in games:  "📦 To games" saves the model in Kompass' model library.
#  Any KampfScript 3D game (and Kugel Blocks 3D) can then use it:
#      let s = scene3d(body())
#      let ship = load_model(s, "my ship")
# ============================================================================
let APP = "Kugel 3D Modeler"
let PALETTE = ["#b8bcc4", "#f2f2f2", "#3a3d45", "#e8443a", "#ff8c1a", "#ffd23f", "#4caf50", "#2bb5a8", "#3d8bfd", "#7b5cff", "#e055b3", "#8d5a3b"]
let BGS = {Studio: "#3b4150", Day: "#87ceeb", Night: "#10131c", White: "#f4f5f7"}

# ---------------------------------------------------------------- state
let objs = []            # records: {h, name, kind, smooth, wire, visible, mat, pos, rot, scale}
let sel = []             # selected records (object mode)
let active = nil         # the active record
let mode = "object"      # "object" or "edit"
let selmode = "vert"     # edit mode: "vert" or "face"
let ev = []              # edit mode: selected vertices
let ef = []              # edit mode: selected faces
let tool = "move"        # gizmo: move / rotate / scale
let undo_stack = []
let redo_stack = []
let perf = store_get("perf", false)
let counter = 0
let modal = nil          # running G / R / S / gizmo drag
let pressed = nil        # mouse down on empty space (click or box select)
let lights = []
let bgname = store_get("bg", "Studio")
let lightname = store_get("light", "Studio")
let sun_power = 2.4
let project_name = "untitled"
let dirty = false

# ---------------------------------------------------------------- small helpers
fn css(el, m) { for k, v in m { setstyle(el, k, v) } }
fn btn(p, text, f, tip) {
  let b = button(p, text, f, "kapp-btn")
  if tip != nil { settip(b, tip) }
  return b
}
fn v3(x, y, z) { return {x: x, y: y, z: z} }
fn vadd3(a, b) { return v3(a.x + b.x, a.y + b.y, a.z + b.z) }
fn vsub3(a, b) { return v3(a.x - b.x, a.y - b.y, a.z - b.z) }
fn vmul3(a, k) { return v3(a.x * k, a.y * k, a.z * k) }
fn vdot3(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z }
fn vcross3(a, b) { return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) }
fn vnorm3(a) {
  let l = sqrt(vdot3(a, a))
  if l < 0.000001 { return v3(0, 0, 0) }
  return vmul3(a, 1 / l)
}
fn axis_vec(a) {
  if a == "x" { return v3(1, 0, 0) }
  if a == "y" { return v3(0, 1, 0) }
  return v3(0, 0, 1)
}
fn has_item(l, x) { return indexof(l, x) >= 0 }
fn without(l, x) { return filter(l, fn(y) { return y != x }) }
fn fnum(n) { return str(round(n, 3)) }

# ---------------------------------------------------------------- the window
let root = box(body(), "kapp")
let bar = row(root, "kapp-bar")
label(bar, "⬢ Kugel 3D Modeler", "kapp-title")
let mainrow = row(root, "kapp-main")
let left = col(mainrow, "kapp-panel")
css(left, {width: 132, "min-width": 132})
let view = box(mainrow, "kapp-view")
let right = col(mainrow, "kapp-panel right")
css(right, {width: 250, "min-width": 250})
let status = label(root, "", "kapp-status")

let s = scene3d(view)
shadows3d(s, false)
let grid = grid3d(s, 24, 24)
orbit3d(s, {target: [0, 0.5, 0], min: 0.3, max: 400})
camera3d(s, 3.4, 2.8, 4.4, 0, 0.5, 0)
orbit3d(s, {target: [0, 0.5, 0]})
let hud = label(s, "", "kapp-hud")
css(hud, {position: "absolute", left: 8, bottom: 8})
let help_hint = label(s, "Right-drag: orbit · Shift+right-drag: pan · Wheel: zoom · Tab: edit mode · G R S E X", "kapp-hud")
css(help_hint, {position: "absolute", left: 8, top: 8, bottom: "auto"})
let selbox = box(s, "kapp-box")
css(selbox, {position: "absolute", left: 0, top: 0, width: 0, height: 0})
show(selbox, false)

# gizmo: three arrows that follow the selection (drawn by KampfScript, picked in screen space)
let giz = group3d(s)
let giz_parts = {}
fn make_arrow(axis, colr) {
  let shaft = cylinder(s, 0.025, 1, colr)
  let tip = cone(s, 0.08, 0.22, colr)
  let knob = cube(s, 0.13, 0.13, 0.13, colr)
  for o in [shaft, tip, knob] { look3d(o, {glow: colr}) }
  move3d(shaft, 0, 0.5, 0)
  move3d(tip, 0, 1.08, 0)
  move3d(knob, 0, 1.08, 0)
  let g = group3d(s)
  attach3d(g, shaft)
  attach3d(g, tip)
  attach3d(g, knob)
  if axis == "x" { turn3d(g, 0, 0, -90) }
  if axis == "z" { turn3d(g, 90, 0, 0) }
  attach3d(giz, g)
  giz_parts[axis] = {tip: tip, knob: knob}
}
make_arrow("x", "#e8443a")
make_arrow("y", "#4caf50")
make_arrow("z", "#3d8bfd")
show3d(giz, false)

fn gizmo_tool_shape() {
  for a in ["x", "y", "z"] {
    show3d(giz_parts[a].tip, tool != "scale")
    show3d(giz_parts[a].knob, tool == "scale")
  }
}

# ---------------------------------------------------------------- object records
fn rec_of(h) {
  for r in objs { if r.h == h { return r } }
  return nil
}
fn new_name(kind) {
  counter += 1
  let base = upper(substr(kind, 0, 1)) + substr(kind, 1)
  let n = base
  let i = 1
  while name_taken(n) { i += 1; n = base + "." + str(i) }
  return n
}
fn name_taken(n) {
  for r in objs { if r.name == n { return true } }
  return false
}
fn apply_look(r) {
  look3d(r.h, {color: r.mat.color, shiny: r.mat.shiny, metal: r.mat.metal, opacity: r.mat.opacity, glow: r.mat.glow, wire: r.wire})
  mesh_smooth(r.h, r.smooth)
  show3d(r.h, r.visible)
}
fn apply_transform(r) {
  move3d(r.h, r.pos.x, r.pos.y, r.pos.z)
  turn3d(r.h, r.rot.x, r.rot.y, r.rot.z)
  scale3d(r.h, r.scale.x, r.scale.y, r.scale.z)
}
fn add_record(h, kind, name, colr) {
  let r = {h: h, name: name, kind: kind, smooth: false, wire: false, visible: true,
    mat: {color: colr, shiny: 0.3, metal: 0, opacity: 1, glow: ""},
    pos: v3(0, 0, 0), rot: v3(0, 0, 0), scale: v3(1, 1, 1)}
  name3d(h, name)
  push(objs, r)
  return r
}
fn add_shape(kind) {
  if mode == "edit" { set_mode("object") }
  push_undo()
  let segs = 24
  if perf { segs = 14 }
  let colr = PALETTE[0]
  let opts = {segments: segs}
  if kind == "plane" { opts = {size: 2, divisions: 1} }
  if kind == "cube" { opts = {size: 1} }
  let h = mesh3d(s, kind, colr, opts)
  let r = add_record(h, kind, new_name(kind), colr)
  if kind == "cube" or kind == "sphere" or kind == "cylinder" or kind == "cone" { r.pos = v3(0, 0.5, 0) }
  if kind == "torus" { r.pos = v3(0, 0.5, 0); r.rot = v3(90, 0, 0) }
  apply_transform(r)
  apply_look(r)
  select_only(r)
  dirty = true
  refresh_all()
}

# ---------------------------------------------------------------- selection (object mode)
fn highlight() {
  for r in objs {
    if mode == "edit" and r == active { continue }
    if has_item(sel, r) { mesh_edit(r.h, true, {verts: false, edges: "#ff8c1a"}) } else { mesh_edit(r.h, false) }
  }
}
fn select_only(r) {
  sel = []
  if r != nil { push(sel, r) }
  active = r
  highlight()
}
fn toggle_sel(r) {
  if has_item(sel, r) {
    sel = without(sel, r)
    if active == r {
      if len(sel) > 0 { active = sel[len(sel) - 1] } else { active = nil }
    }
  } else { push(sel, r); active = r }
  highlight()
}
fn select_all_objects() {
  if len(sel) == len(objs) { sel = []; active = nil } else { sel = slice(objs); if active == nil and len(objs) > 0 { active = objs[0] } }
  highlight()
}

# ---------------------------------------------------------------- edit mode
fn edit_verts() {
  # the vertices an operation works on
  if selmode == "face" { return mesh_face_verts(active.h, ef) }
  return ev
}
fn edit_faces() {
  if selmode == "face" { return ef }
  return mesh_faces_of(active.h, ev)
}
fn show_edit_sel() {
  if mode != "edit" or active == nil { return }
  if selmode == "face" { mesh_select(active.h, mesh_face_verts(active.h, ef), ef) } else { mesh_select(active.h, ev, mesh_faces_of(active.h, ev)) }
}
fn set_mode(m) {
  if m == mode { return }
  if m == "edit" {
    if active == nil {
      if len(objs) == 0 { return }
      select_only(objs[len(objs) - 1])
    }
    mode = "edit"
    ev = []
    ef = []
    sel = [active]
    highlight()
    mesh_edit(active.h, true, {verts: selmode == "vert"})
    show_edit_sel()
  } else {
    mode = "object"
    if active != nil { mesh_select(active.h, [], []) }
    highlight()
  }
  refresh_all()
}
fn set_selmode(m) {
  if mode == "edit" and active != nil {
    # keep what was selected: faces <-> their vertices
    if m == "face" and selmode == "vert" { ef = mesh_faces_of(active.h, ev) }
    if m == "vert" and selmode == "face" { ev = mesh_face_verts(active.h, ef) }
  }
  selmode = m
  if mode == "edit" and active != nil { mesh_edit(active.h, true, {verts: selmode == "vert"}); show_edit_sel() }
  refresh_all()
}
fn edit_select_all() {
  let info = mesh_info(active.h)
  if selmode == "vert" {
    if len(ev) == info.verts { ev = [] } else { ev = range(info.verts) }
  } else {
    if len(ef) == info.faces { ef = [] } else { ef = range(info.faces) }
  }
  show_edit_sel()
  refresh_all()
}

# ---------------------------------------------------------------- undo / redo (whole-scene snapshots)
fn snapshot() {
  let list = []
  for r in objs {
    push(list, {name: r.name, kind: r.kind, smooth: r.smooth, wire: r.wire, visible: r.visible, mat: r.mat, pos: r.pos, rot: r.rot, scale: r.scale, data: mesh_get(r.h)})
  }
  let ai = -1
  if active != nil { ai = indexof(objs, active) }
  return {objs: list, active: ai, mode: mode}
}
fn copy_map(m) { return parse_json(json(m)) }
fn restore(snap) {
  for r in objs { remove3d(r.h) }
  objs = []
  sel = []
  active = nil
  for o in snap.objs {
    let h = mesh3d(s, o.data, o.mat.color)
    let r = add_record(h, o.kind, o.name, o.mat.color)
    r.smooth = o.smooth
    r.wire = o.wire
    r.visible = o.visible
    r.mat = copy_map(o.mat)
    r.pos = copy_map(o.pos)
    r.rot = copy_map(o.rot)
    r.scale = copy_map(o.scale)
    apply_transform(r)
    apply_look(r)
  }
  if snap.active >= 0 and snap.active < len(objs) { select_only(objs[snap.active]) }
  mode = "object"
  ev = []
  ef = []
  if snap.mode == "edit" and active != nil { set_mode("edit") }
  highlight()
  refresh_all()
}
fn push_undo() {
  push(undo_stack, snapshot())
  if len(undo_stack) > 30 { remove(undo_stack, 0) }
  redo_stack = []
  dirty = true
}
fn do_undo() {
  if len(undo_stack) == 0 { flash("Nothing to undo"); return }
  push(redo_stack, snapshot())
  restore(pop(undo_stack))
  flash("Undo")
}
fn do_redo() {
  if len(redo_stack) == 0 { flash("Nothing to redo"); return }
  push(undo_stack, snapshot())
  restore(pop(redo_stack))
  flash("Redo")
}

# ---------------------------------------------------------------- geometry of the view
fn cam_axes() {
  let c = camera_get(s)
  let fwd = vnorm3(v3(c.dir.x, c.dir.y, c.dir.z))
  let rt = vnorm3(vcross3(fwd, v3(0, 1, 0)))
  if vdot3(rt, rt) < 0.5 { rt = v3(1, 0, 0) }
  let up = vnorm3(vcross3(rt, fwd))
  return {fwd: fwd, right: rt, up: up, pos: v3(c.x, c.y, c.z)}
}
fn screen_dir(center, dir) {
  # pixels moved on screen when a point moves 1 unit along dir
  let a = project3d(s, center)
  let b = project3d(s, vadd3(center, dir))
  return {x: b.x - a.x, y: b.y - a.y}
}
fn sel_center() {
  if mode == "edit" and active != nil {
    let vs = edit_verts()
    if len(vs) == 0 { return nil }
    return mesh_center(active.h, vs)
  }
  if len(sel) == 0 { return nil }
  let c = v3(0, 0, 0)
  for r in sel { c = vadd3(c, r.pos) }
  return vmul3(c, 1 / len(sel))
}
fn view_axis() {
  # the world axis that points most toward the viewer (rotations without X/Y/Z)
  let f = cam_axes().fwd
  let ax = "z"
  let best = abs(f.z)
  if abs(f.x) > best { ax = "x"; best = abs(f.x) }
  if abs(f.y) > best { ax = "y" }
  return ax
}

# ---------------------------------------------------------------- transforms (modal G / R / S and the gizmo)
fn begin_modal(kind, how, mx, my, axis) {
  let c = sel_center()
  if c == nil { flash("Select something first"); return }
  push_undo()
  let starts = []
  for r in sel { push(starts, {r: r, pos: copy_map(r.pos), rot: copy_map(r.rot), scale: copy_map(r.scale)}) }
  if mode == "edit" { mesh_snapshot(active.h) }
  let pc = project3d(s, c)
  modal = {kind: kind, how: how, axis: axis, dir: nil, mx: mx, my: my, x: mx, y: my, center: c, pc: pc, starts: starts, typed: "", verts: [], pushed: true, extruded: false}
  if mode == "edit" { modal.verts = edit_verts() }
  update_modal()
}
fn modal_amount() {
  let m = modal
  let dx = m.x - m.mx
  let dy = m.y - m.my
  if m.kind == "move" {
    if m.dir != nil or m.axis != "" {
      let d = m.dir
      if d == nil { d = axis_vec(m.axis) }
      let sd = screen_dir(m.center, d)
      let l2 = sd.x * sd.x + sd.y * sd.y
      let t = 0
      if l2 > 0.0001 { t = (dx * sd.x + dy * sd.y) / l2 }
      if m.typed != "" and num(m.typed) != nil { t = num(m.typed) }
      return vmul3(d, t)
    }
    # free move in the view plane: solve mouse delta = a * right + b * up (on screen)
    let ax = cam_axes()
    let sr = screen_dir(m.center, ax.right)
    let su = screen_dir(m.center, ax.up)
    let det = sr.x * su.y - sr.y * su.x
    if abs(det) < 0.0001 { return v3(0, 0, 0) }
    let a = (dx * su.y - dy * su.x) / det
    let b = (sr.x * dy - sr.y * dx) / det
    return vadd3(vmul3(ax.right, a), vmul3(ax.up, b))
  }
  if m.kind == "rotate" {
    let a0 = atan2(m.my - m.pc.y, m.mx - m.pc.x)
    let a1 = atan2(m.y - m.pc.y, m.x - m.pc.x)
    let deg = (a1 - a0) * 180 / PI
    if m.how == "gizmo" { deg = (dx - dy) * 0.6 }
    if key_down("control") { deg = round(deg / 15) * 15 }
    let ax = m.axis
    if ax == "" { ax = view_axis() }
    # turn the same way the mouse turns, as seen by the viewer (a typed angle is used as it is)
    if vdot3(cam_axes().fwd, axis_vec(ax)) < 0 { deg = -deg }
    if m.typed != "" and num(m.typed) != nil { deg = num(m.typed) }
    return {axis: ax, deg: deg}
  }
  # scale
  let d0 = hypot(m.mx - m.pc.x, m.my - m.pc.y)
  let d1 = hypot(m.x - m.pc.x, m.y - m.pc.y)
  let k = 1
  if d0 > 2 { k = d1 / d0 }
  if m.how == "gizmo" { k = max(0.02, 1 + (dx - dy) / 120) }
  if key_down("control") { k = round(k * 10) / 10 }
  if m.typed != "" and num(m.typed) != nil { k = num(m.typed) }
  return k
}
fn update_modal() {
  let m = modal
  let amt = modal_amount()
  let info = ""
  if mode == "edit" {
    if m.kind == "move" { mesh_transform(active.h, m.verts, {move: [amt.x, amt.y, amt.z], from_snapshot: true}); info = `Move  {fnum(amt.x)}, {fnum(amt.y)}, {fnum(amt.z)}` }
    if m.kind == "rotate" {
      let rv = [0, 0, 0]
      if amt.axis == "x" { rv = [amt.deg, 0, 0] }
      if amt.axis == "y" { rv = [0, amt.deg, 0] }
      if amt.axis == "z" { rv = [0, 0, amt.deg] }
      mesh_transform(active.h, m.verts, {rotate: rv, center: m.center, from_snapshot: true})
      info = `Rotate {fnum(amt.deg)}° around {upper(amt.axis)}`
    }
    if m.kind == "scale" {
      let sv = [amt, amt, amt]
      if m.axis == "x" { sv = [amt, 1, 1] }
      if m.axis == "y" { sv = [1, amt, 1] }
      if m.axis == "z" { sv = [1, 1, amt] }
      mesh_transform(active.h, m.verts, {scale: sv, center: m.center, from_snapshot: true})
      info = `Scale {fnum(amt)}`
    }
  } else {
    for st in m.starts {
      let r = st.r
      if m.kind == "move" { r.pos = vadd3(st.pos, amt) }
      if m.kind == "rotate" {
        r.rot = copy_map(st.rot)
        r.rot[amt.axis] = st.rot[amt.axis] + amt.deg
      }
      if m.kind == "scale" {
        r.scale = copy_map(st.scale)
        if m.axis == "" { r.scale = vmul3(st.scale, amt) } else { r.scale[m.axis] = st.scale[m.axis] * amt }
      }
      apply_transform(r)
    }
    if m.kind == "move" { info = `Move  {fnum(amt.x)}, {fnum(amt.y)}, {fnum(amt.z)}` }
    if m.kind == "rotate" { info = `Rotate {fnum(amt.deg)}° around {upper(amt.axis)}` }
    if m.kind == "scale" { info = `Scale {fnum(amt)}` }
  }
  let ax = "free (X / Y / Z to lock an axis)"
  if m.axis != "" { ax = "along " + upper(m.axis) }
  if m.dir != nil { ax = "along the normal" }
  if m.typed != "" { info += "   typed: " + m.typed }
  settext(hud, info + "   ·  " + ax + "\nclick = OK · Esc / right click = cancel · Ctrl = snap")
  place_gizmo()
}
fn end_modal(ok) {
  if modal == nil { return }
  if not ok {
    if mode == "edit" { mesh_transform(active.h, modal.verts, {move: [0, 0, 0], from_snapshot: true}) }
    for st in modal.starts {
      st.r.pos = st.pos
      st.r.rot = st.rot
      st.r.scale = st.scale
      apply_transform(st.r)
    }
    if modal.pushed { pop(undo_stack) }
    if modal.extruded { modal = nil; restore(pop(undo_stack)); return }
  }
  modal = nil
  refresh_all()
}

# ---------------------------------------------------------------- edit operations
fn op_extrude() {
  if mode != "edit" or active == nil { flash("Extrude works in Edit mode (Tab) on selected faces"); return }
  let fs = edit_faces()
  if len(fs) == 0 { flash("Select faces to extrude (press 3 for face select)"); return }
  push_undo()
  let normal = mesh_normal(active.h, fs)
  let r = mesh_extrude(active.h, fs, 0)
  ef = r.faces
  ev = r.verts
  show_edit_sel()
  begin_modal("move", "key", mouse_x, mouse_y, "")
  if modal != nil {
    modal.dir = vnorm3(v3(normal.x, normal.y, normal.z))
    modal.extruded = true
    update_modal()
  }
}
fn op_delete() {
  if mode == "edit" {
    if active == nil { return }
    let vs = edit_verts()
    if len(vs) == 0 and len(ef) == 0 { flash("Nothing selected"); return }
    push_undo()
    if selmode == "face" { mesh_delete(active.h, ef, []) } else { mesh_delete(active.h, [], ev) }
    ev = []
    ef = []
    show_edit_sel()
    refresh_all()
    return
  }
  if len(sel) == 0 { flash("Nothing selected"); return }
  push_undo()
  for r in sel {
    remove3d(r.h)
    objs = without(objs, r)
  }
  sel = []
  active = nil
  refresh_all()
}
fn op_duplicate() {
  if mode == "edit" { flash("Duplicate works in Object mode"); return }
  if len(sel) == 0 { flash("Select an object to duplicate"); return }
  push_undo()
  let made = []
  for r in sel {
    let h = clone3d(r.h)
    let n = add_record(h, r.kind, new_name(r.kind), r.mat.color)
    n.smooth = r.smooth
    n.wire = r.wire
    n.mat = copy_map(r.mat)
    n.pos = vadd3(r.pos, v3(0.5, 0, 0.5))
    n.rot = copy_map(r.rot)
    n.scale = copy_map(r.scale)
    apply_transform(n)
    apply_look(n)
    push(made, n)
  }
  sel = made
  active = made[len(made) - 1]
  highlight()
  refresh_all()
  begin_modal("move", "key", mouse_x, mouse_y, "")
  if modal != nil { pop(undo_stack); modal.pushed = false }
}
fn op_subdivide() {
  if active == nil { flash("Select an object"); return }
  let info = mesh_info(active.h)
  if info.faces > 6000 { flash("That mesh is already very detailed"); return }
  push_undo()
  mesh_subdivide(active.h)
  ev = []
  ef = []
  show_edit_sel()
  refresh_all()
}
fn op_merge() {
  if mode != "edit" { flash("Merge works in Edit mode on selected vertices"); return }
  let vs = edit_verts()
  if len(vs) < 2 { flash("Select 2 or more vertices to merge"); return }
  push_undo()
  mesh_merge(active.h, vs)
  ev = []
  ef = []
  show_edit_sel()
  refresh_all()
}
fn op_flip() {
  if active == nil { return }
  push_undo()
  if mode == "edit" and len(edit_faces()) > 0 { mesh_flip(active.h, edit_faces()) } else { mesh_flip(active.h) }
  flash("Normals flipped")
}
fn op_join() {
  if mode != "object" or len(sel) < 2 or active == nil { flash("Select 2+ objects to join (the last one clicked keeps its name)"); return }
  push_undo()
  for r in sel {
    if r == active { continue }
    mesh_join(active.h, r.h)
    remove3d(r.h)
    objs = without(objs, r)
  }
  select_only(active)
  refresh_all()
}
fn op_smooth(on) {
  if len(sel) == 0 { return }
  push_undo()
  for r in sel { r.smooth = on; mesh_smooth(r.h, on) }
  refresh_all()
}
fn frame_selection() {
  let c = sel_center()
  if c == nil { c = v3(0, 0.5, 0) }
  let o = orbit3d_get(s)
  orbit3d(s, {target: [c.x, c.y, c.z]})
  let cam = camera_get(s)
  let d = vsub3(v3(cam.x, cam.y, cam.z), v3(o.x, o.y, o.z))
  let nd = vnorm3(d)
  let dist = 4
  camera3d(s, c.x + nd.x * dist, c.y + nd.y * dist, c.z + nd.z * dist, c.x, c.y, c.z)
  orbit3d(s, {target: [c.x, c.y, c.z]})
}

# ---------------------------------------------------------------- the gizmo
fn place_gizmo() {
  let c = sel_center()
  if c == nil or (modal != nil and modal.how == "key") { show3d(giz, false); return }
  show3d(giz, true)
  move3d(giz, c.x, c.y, c.z)
  let cam = camera_get(s)
  let k = dist3d(c, v3(cam.x, cam.y, cam.z)) * 0.16
  scale3d(giz, k)
}
fn seg_dist(px, py, ax, ay, bx, by) {
  let vx = bx - ax
  let vy = by - ay
  let l2 = vx * vx + vy * vy
  let t = 0
  if l2 > 0 { t = clamp(((px - ax) * vx + (py - ay) * vy) / l2, 0, 1) }
  return hypot(px - (ax + vx * t), py - (ay + vy * t))
}
fn gizmo_axis_at(x, y) {
  let c = sel_center()
  if c == nil { return "" }
  let cam = camera_get(s)
  let k = dist3d(c, v3(cam.x, cam.y, cam.z)) * 0.16
  let p0 = project3d(s, c)
  let best = ""
  let bd = 11
  for a in ["x", "y", "z"] {
    let tip = project3d(s, vadd3(c, vmul3(axis_vec(a), k * 1.2)))
    let d = seg_dist(x, y, p0.x, p0.y, tip.x, tip.y)
    if d < bd { bd = d; best = a }
  }
  return best
}

# ---------------------------------------------------------------- mouse in the viewport
let mouse_x = 0
let mouse_y = 0
on_mouse(s, fn(e) {
  mouse_x = e.x
  mouse_y = e.y
  if e.type == "move" {
    if modal != nil { modal.x = e.x; modal.y = e.y; update_modal(); return }
    if pressed != nil {
      if hypot(e.x - pressed.x, e.y - pressed.y) > 5 { pressed.box = true }
      if pressed.box {
        show(selbox, true)
        css(selbox, {left: min(e.x, pressed.x), top: min(e.y, pressed.y), width: abs(e.x - pressed.x), height: abs(e.y - pressed.y)})
      }
    }
    return
  }
  if e.type == "down" {
    if modal != nil {
      if e.button == "left" { end_modal(true) } else { end_modal(false) }
      return
    }
    if e.button != "left" { return }
    let a = gizmo_axis_at(e.x, e.y)
    if a != "" {
      begin_modal(tool, "gizmo", e.x, e.y, a)
      return
    }
    pressed = {x: e.x, y: e.y, box: false, shift: e.shift}
    return
  }
  if e.type == "up" {
    if modal != nil and modal.how == "gizmo" { end_modal(true); return }
    if pressed == nil { return }
    let p = pressed
    pressed = nil
    show(selbox, false)
    if p.box { box_select(p.x, p.y, e.x, e.y, p.shift) } else { click_select(e.x, e.y, p.shift) }
  }
})
fn click_select(x, y, add) {
  if mode == "edit" {
    if selmode == "vert" {
      let v = mesh_vertex_at(s, active.h, x, y, 14)
      if v < 0 {
        if not add { ev = [] }
      } else if add {
        if has_item(ev, v) { ev = without(ev, v) } else { push(ev, v) }
      } else { ev = [v] }
    } else {
      let pk = mesh_pick(s, x, y, [active.h])
      if pk == nil {
        if not add { ef = [] }
      } else if add {
        if has_item(ef, pk.face) { ef = without(ef, pk.face) } else { push(ef, pk.face) }
      } else { ef = [pk.face] }
    }
    show_edit_sel()
    refresh_all()
    return
  }
  let pk = mesh_pick(s, x, y)
  if pk == nil {
    if not add { select_only(nil) }
  } else {
    let r = rec_of(pk.obj)
    if r != nil {
      if add { toggle_sel(r) } else { select_only(r) }
    }
  }
  refresh_all()
}
fn box_select(x1, y1, x2, y2, add) {
  if mode == "edit" {
    let vs = mesh_box_select(s, active.h, x1, y1, x2, y2)
    if selmode == "vert" {
      if add { for v in vs { if not has_item(ev, v) { push(ev, v) } } } else { ev = vs }
    } else {
      let fs = mesh_faces_of(active.h, vs)
      if add { for f in fs { if not has_item(ef, f) { push(ef, f) } } } else { ef = fs }
    }
    show_edit_sel()
    refresh_all()
    return
  }
  if not add { sel = [] }
  for r in objs {
    if not r.visible { continue }
    let p = project3d(s, mesh_center(r.h))
    if p.visible and p.x >= min(x1, x2) and p.x <= max(x1, x2) and p.y >= min(y1, y2) and p.y <= max(y1, y2) {
      if not has_item(sel, r) { push(sel, r) }
    }
  }
  if len(sel) > 0 { active = sel[len(sel) - 1] } else { active = nil }
  highlight()
  refresh_all()
}

# ---------------------------------------------------------------- keyboard
on_keypress(fn(k) {
  let ctrl = key_down("control")
  let shift = key_down("shift")
  if modal != nil {
    if k == "escape" { end_modal(false); return }
    if k == "enter" { end_modal(true); return }
    if k == "x" or k == "y" or k == "z" {
      if modal.axis == k { modal.axis = "" } else { modal.axis = k }
      modal.dir = nil
      update_modal()
      return
    }
    if k == "-" or k == "." or (len(k) == 1 and ord(k) >= 48 and ord(k) <= 57) { modal.typed += k; update_modal(); return }
    if k == "backspace" { modal.typed = substr(modal.typed, 0, max(0, len(modal.typed) - 1)); update_modal(); return }
    return
  }
  if ctrl and k == "z" { if shift { do_redo() } else { do_undo() }; return }
  if ctrl and k == "s" { save_project(); return }
  if ctrl and k == "j" { op_join(); return }
  if ctrl { return }
  if k == "tab" { if mode == "object" { set_mode("edit") } else { set_mode("object") }; return }
  if k == "g" { begin_modal("move", "key", mouse_x, mouse_y, ""); return }
  if k == "r" { begin_modal("rotate", "key", mouse_x, mouse_y, ""); return }
  if k == "s" { begin_modal("scale", "key", mouse_x, mouse_y, ""); return }
  if k == "e" { op_extrude(); return }
  if k == "x" or k == "delete" { op_delete(); return }
  if k == "d" and shift { op_duplicate(); return }
  if k == "m" { op_merge(); return }
  if k == "f" { frame_selection(); return }
  if k == "a" {
    if mode == "edit" { edit_select_all() } else { select_all_objects(); refresh_all() }
    return
  }
  if k == "1" and mode == "edit" { set_selmode("vert"); return }
  if k == "3" and mode == "edit" { set_selmode("face"); return }
  if k == "escape" { if mode == "edit" { set_mode("object") } }
})

# ---------------------------------------------------------------- files
fn project_text() {
  let snap = snapshot()
  return json({app: "kugel-3d-modeler", version: 1, name: project_name, background: bgname, light: lightname, objects: snap.objs}, true)
}
fn save_project() {
  let r = file_save(project_name + ".kmodel", project_text())
  if r.ok { dirty = false; flash("Saved " + r.name) } else { flash("Not saved") }
}
fn open_project() {
  let f = file_open(["kmodel", "json"])
  if f == nil { return }
  let p = parse_json(f.text)
  if p == nil or p.objects == nil { flash("That is not a Kugel 3D Modeler project"); return }
  push_undo()
  restore({objs: p.objects, active: 0, mode: "object"})
  project_name = replace(replace(f.name, ".kmodel", ""), ".json", "")
  if p.background != nil { set_bg(p.background) }
  if p.light != nil { set_light(p.light) }
  frame_selection()
  flash("Opened " + f.name)
}
fn new_project() {
  push_undo()
  restore({objs: [], active: -1, mode: "object"})
  project_name = "untitled"
  add_shape("cube")
  flash("New project (Ctrl+Z brings the old one back)")
}
fn import_model() {
  let f = file_open(["obj", "glb", "gltf"])
  if f == nil { return }
  let data = f.text
  if data == nil { data = f.data }
  push_undo()
  let list = import3d(s, data, f.ext)
  if len(list) == 0 { flash("Nothing found in " + f.name); return }
  sel = []
  for h in list {
    let m = material3d(h)
    let colr = PALETTE[0]
    if m != nil { colr = m.color }
    let r = add_record(h, "import", new_name(replace(name3d(h), " ", "_")), colr)
    apply_look(r)
    push(sel, r)
  }
  active = sel[len(sel) - 1]
  set_mode("object")
  highlight()
  frame_selection()
  refresh_all()
  flash(`Imported {len(list)} object(s) from {f.name}`)
}
fn export_list() {
  let out = []
  for r in objs { if r.visible { push(out, r.h) } }
  return out
}
fn export_model(fmt) {
  if len(export_list()) == 0 { flash("Nothing to export"); return }
  set_mode("object")
  let keep = sel
  select_only(nil)
  let data = export3d(export_list(), fmt)
  sel = keep
  if len(sel) > 0 { active = sel[len(sel) - 1] }
  highlight()
  let r = file_save(project_name + "." + fmt, data)
  if r.ok { flash(`Exported {upper(fmt)}: {r.name}`) }
}
fn to_library() {
  if len(export_list()) == 0 { flash("Nothing to save"); return }
  let p = popup(500, 200)
  label(p, "📦 Save for games", "kapp-sec")
  label(p, "Your model goes into Kompass' model library. Use it in any 3D game with load_model, or pick it in Kugel Blocks 3D.", "kapp-tiny")
  let nm = textbox(p, "model name")
  setvalue(nm, project_name)
  let msg = label(p, "", "kapp-tiny")
  button(p, "Save", fn() {
    let n = trim(gettext(nm))
    if n == "" { return }
    set_mode("object")
    let keep = sel
    select_only(nil)
    let ok = model_save(n, export3d(export_list(), "glb"))
    sel = keep
    highlight()
    flash(`Saved "{n}" — in a game: load_model(s, "{n}")`)
  }, "kapp-btn on")
}
fn render_png() {
  set_mode("object")
  let keep = sel
  select_only(nil)
  show3d(giz, false)
  show3d(grid, false)
  let png = snapshot3d(s, 1280, 720)
  show3d(grid, show_grid)
  sel = keep
  if len(sel) > 0 { active = sel[len(sel) - 1] }
  highlight()
  place_gizmo()
  let p = popup(600, 300)
  label(p, "📷 Render", "kapp-sec")
  let im = image(p, png)
  setsize(im, 480, 270)
  let rw = row(p)
  button(rw, "💾 Save PNG", fn() { let r = file_save(project_name + ".png", png); if r.ok { flash("Saved " + r.name) } }, "kapp-btn on")
  button(rw, "Close", fn() { }, "kapp-btn")
}

# ---------------------------------------------------------------- scene settings
fn set_bg(name) {
  if BGS[name] == nil { return }
  bgname = name
  store_set("bg", name)
  if name == "Studio" { sky3d(s, "#4a5163", "#2a2e38") } else { sky3d(s, BGS[name]) }
}
fn set_light(name) {
  lightname = name
  store_set("light", name)
  for l in lights { remove3d(l) }
  lights = []
  light3d(s, "none")
  if name == "Studio" {
    push(lights, light3d(s, "ambient", "#ffffff", 0.9))
    push(lights, light3d(s, "sun", "#ffffff", sun_power, 5, 9, 6))
    push(lights, light3d(s, "sun", "#9fb6ff", sun_power * 0.4, -6, 3, -5))
  } else if name == "Sun" {
    push(lights, light3d(s, "ambient", "#cfe0ff", 0.6))
    push(lights, light3d(s, "sun", "#fff3d6", sun_power * 1.3, 8, 12, 4))
  } else if name == "Sunset" {
    push(lights, light3d(s, "ambient", "#ffb38a", 0.5))
    push(lights, light3d(s, "sun", "#ff8a3d", sun_power * 1.2, -9, 3, 4))
  } else {
    push(lights, light3d(s, "ambient", "#6070a0", 0.35))
    push(lights, light3d(s, "point", "#ffe6b0", 40 * sun_power / 2.4, 2, 4, 3))
  }
}
let show_grid = true
fn set_perf(on) {
  perf = on
  store_set("perf", on)
  if on { pixel_ratio3d(s, 0.6) } else { pixel_ratio3d(s, 1) }
}

# ---------------------------------------------------------------- top bar + tool panel
btn(bar, "New", fn() { new_project() }, "Start again (Ctrl+Z undoes it)")
btn(bar, "Open", fn() { open_project() }, "Open a .kmodel project")
btn(bar, "Save", fn() { save_project() }, "Save the project as .kmodel (Ctrl+S)")
btn(bar, "Import", fn() { import_model() }, "Import OBJ, GLB or glTF")
let fmt_pick = dropdown(bar, ["OBJ", "GLB", "glTF"])
settip(fmt_pick, "Export format")
btn(bar, "Export", fn() { export_model(lower(getvalue(fmt_pick))) }, "Export the visible objects")
btn(bar, "📷 Render", fn() { render_png() }, "Render a 1280×720 PNG")
btn(bar, "📦 To games", fn() { to_library() }, "Save in Kompass' model library for load_model() and Kugel Blocks 3D")
label(bar, "│", "kapp-tiny")
btn(bar, "↶", fn() { do_undo() }, "Undo (Ctrl+Z)")
btn(bar, "↷", fn() { do_redo() }, "Redo (Ctrl+Shift+Z)")
label(bar, "│", "kapp-tiny")
let b_obj = btn(bar, "Object", fn() { set_mode("object") }, "Object mode (Tab)")
let b_edit = btn(bar, "Edit", fn() { set_mode("edit") }, "Edit mode (Tab): vertices and faces")
let b_vert = btn(bar, "• Vertex", fn() { set_selmode("vert") }, "Select vertices (1)")
let b_face = btn(bar, "▰ Face", fn() { set_selmode("face") }, "Select faces (3)")
label(bar, "│", "kapp-tiny")
let perf_box = checkbox(bar, "⚡ Performance", perf, fn(on) { set_perf(on) })
settip(perf_box, "For weak PCs: lower resolution, fewer segments on new shapes")
btn(bar, "?", fn() { show_help() }, "Keys and help")

label(left, "Add", "kapp-sec")
for it in [["▢ Cube", "cube"], ["◯ Sphere", "sphere"], ["⌭ Cylinder", "cylinder"], ["△ Cone", "cone"], ["▭ Plane", "plane"], ["◎ Torus", "torus"]] {
  let kind = it[1]
  button(left, it[0], fn() { add_shape(kind) }, "kapp-btn wide")
}
label(left, "Gizmo", "kapp-sec")
let b_move = btn(left, "✥ Move  G", fn() { tool = "move"; gizmo_tool_shape(); refresh_all() }, "Drag an arrow to move along that axis")
let b_rot = btn(left, "⟳ Rotate  R", fn() { tool = "rotate"; gizmo_tool_shape(); refresh_all() }, "Drag an arrow to turn around that axis")
let b_scl = btn(left, "⤢ Scale  S", fn() { tool = "scale"; gizmo_tool_shape(); refresh_all() }, "Drag a handle to stretch along that axis")
for b in [b_move, b_rot, b_scl] { addstyle(b, "wide") }
label(left, "Mesh", "kapp-sec")
button(left, "⇡ Extrude  E", fn() { op_extrude() }, "kapp-btn wide")
button(left, "✕ Delete  X", fn() { op_delete() }, "kapp-btn wide")
button(left, "⧉ Duplicate ⇧D", fn() { op_duplicate() }, "kapp-btn wide")
button(left, "⊞ Subdivide", fn() { op_subdivide() }, "kapp-btn wide")
button(left, "⊙ Merge  M", fn() { op_merge() }, "kapp-btn wide")
button(left, "⇄ Flip normals", fn() { op_flip() }, "kapp-btn wide")
button(left, "⧓ Join  Ctrl+J", fn() { op_join() }, "kapp-btn wide")
button(left, "◍ Smooth", fn() { op_smooth(true) }, "kapp-btn wide")
button(left, "◆ Flat", fn() { op_smooth(false) }, "kapp-btn wide")
label(left, "View", "kapp-sec")
let vrow1 = row(left)
button(vrow1, "Front", fn() { orbit3d_view(s, "front") }, "kapp-btn")
button(vrow1, "Right", fn() { orbit3d_view(s, "right") }, "kapp-btn")
let vrow2 = row(left)
button(vrow2, "Top", fn() { orbit3d_view(s, "top") }, "kapp-btn")
button(vrow2, "3D", fn() { orbit3d_view(s, "persp") }, "kapp-btn")
button(left, "⌖ Frame  F", fn() { frame_selection() }, "kapp-btn wide")

# ---------------------------------------------------------------- right panel: outliner + properties
label(right, "Outliner", "kapp-sec")
let outl = col(right)
css(outl, {gap: 1, "max-height": 190, "overflow-y": "auto"})
label(right, "Object", "kapp-sec")
let props = col(right)
label(right, "Scene", "kapp-sec")
let scenep = col(right)

fn draw_outliner() {
  clear(outl)
  if len(objs) == 0 { label(outl, "Empty — add a shape on the left", "kapp-tiny"); return }
  for r in objs {
    let rr = r
    let line = row(outl)
    css(line, {gap: 2})
    let st = "kapp-item"
    if has_item(sel, r) { st = "kapp-item on" }
    let nm = label(line, r.name, st)
    css(nm, {flex: 1})
    on_click(nm, fn() {
      if mode == "edit" { set_mode("object") }
      if key_down("shift") { toggle_sel(rr) } else { select_only(rr) }
      refresh_all()
    })
    let eye = "👁"
    if not r.visible { eye = "◌" }
    button(line, eye, fn() { rr.visible = not rr.visible; show3d(rr.h, rr.visible); refresh_all() }, "kapp-btn")
  }
}
fn num_field(p, value, f) {
  let t = textbox(p, "", fn(txt) { let v = num(txt); if v != nil { f(v) } }, "kapp-field")
  setvalue(t, fnum(value))
  setsize(t, 56)
  return t
}
fn draw_props() {
  clear(props)
  if active == nil { label(props, "Nothing selected", "kapp-tiny"); return }
  let r = active
  let nmrow = row(props)
  let nm = textbox(nmrow, "name", nil, "kapp-field")
  setvalue(nm, r.name)
  css(nm, {flex: 1})
  on_input(nm, fn(t) { let n = trim(t); if n != "" { r.name = n; name3d(r.h, n); draw_outliner() } }, 300)
  let info = mesh_info(r.h)
  label(props, `{info.verts} vertices · {info.faces} faces · {info.tris} triangles`, "kapp-tiny")
  for row_ in [["Location", "pos"], ["Rotation°", "rot"], ["Scale", "scale"]] {
    let key = row_[1]
    label(props, row_[0], "kapp-tiny")
    let rw = row(props)
    css(rw, {gap: 3})
    for a in ["x", "y", "z"] {
      let ax = a
      num_field(rw, r[key][a], fn(v) { push_undo(); r[key][ax] = v; apply_transform(r); place_gizmo() })
    }
  }
  label(props, "Colour", "kapp-tiny")
  let sw = row(props)
  css(sw, {"flex-wrap": "wrap", gap: 3})
  for c in PALETTE {
    let cc = c
    let b = button(sw, "", fn() { push_undo(); for x in sel { x.mat.color = cc; apply_look(x) }; draw_props() }, "kapp-btn")
    setcolor(b, cc)
    setsize(b, 22, 22)
    if r.mat.color == cc { css(b, {border: "2px solid white"}) }
  }
  let hexrow = row(props)
  label(hexrow, "Hex", "kapp-tiny")
  let hx = textbox(hexrow, "#rrggbb", fn(t) { let v = trim(t); if len(v) == 7 and startswith(v, "#") { push_undo(); for x in sel { x.mat.color = v; apply_look(x) }; draw_props() } }, "kapp-field")
  setvalue(hx, r.mat.color)
  setsize(hx, 80)
  for m in [["Shiny", "shiny"], ["Metal", "metal"], ["Opacity", "opacity"]] {
    let key = m[1]
    let rw = row(props)
    let l = label(rw, m[0], "kapp-tiny")
    setsize(l, 52)
    slider(rw, 0, 1, r.mat[key], fn(v) { for x in sel { x.mat[key] = v; apply_look(x) }; dirty = true })
  }
  let rw2 = row(props)
  checkbox(rw2, "Glow", r.mat.glow != "", fn(on) { push_undo(); for x in sel { if on { x.mat.glow = shade(x.mat.color, -0.3) } else { x.mat.glow = "" }; apply_look(x) } })
  checkbox(rw2, "Smooth", r.smooth, fn(on) { op_smooth(on) })
  checkbox(rw2, "Wire", r.wire, fn(on) { for x in sel { x.wire = on; apply_look(x) } })
}
fn draw_scene_panel() {
  clear(scenep)
  let r1 = row(scenep)
  label(r1, "Background", "kapp-tiny")
  let bd = dropdown(r1, keys(BGS), fn(v) { set_bg(v) })
  setvalue(bd, bgname)
  let r2 = row(scenep)
  label(r2, "Lights", "kapp-tiny")
  let ld = dropdown(r2, ["Studio", "Sun", "Sunset", "Lamp"], fn(v) { set_light(v) })
  setvalue(ld, lightname)
  let r3 = row(scenep)
  let l3 = label(r3, "Brightness", "kapp-tiny")
  setsize(l3, 64)
  slider(r3, 0.3, 5, sun_power, fn(v) { sun_power = v; set_light(lightname) })
  checkbox(scenep, "Grid", show_grid, fn(on) { show_grid = on; show3d(grid, on) })
}
fn refresh_all() {
  togglestyle(b_obj, "on", mode == "object")
  togglestyle(b_edit, "on", mode == "edit")
  togglestyle(b_vert, "on", selmode == "vert")
  togglestyle(b_face, "on", selmode == "face")
  togglestyle(b_move, "on", tool == "move")
  togglestyle(b_rot, "on", tool == "rotate")
  togglestyle(b_scl, "on", tool == "scale")
  show(b_vert, mode == "edit")
  show(b_face, mode == "edit")
  draw_outliner()
  draw_props()
  place_gizmo()
  let tv = 0
  let tf = 0
  for r in objs { let i = mesh_info(r.h); tv += i.verts; tf += i.faces }
  let m = "Object mode"
  if mode == "edit" {
    m = "Edit mode · "
    if selmode == "vert" { m += str(len(ev)) + " vertices selected" } else { m += str(len(ef)) + " faces selected" }
  }
  let p = ""
  if perf { p = " · ⚡ performance mode" }
  settext(status, `{m} · {len(objs)} objects · {len(sel)} selected · {fmt(tv)} vertices · {fmt(tf)} faces{p}`)
  if modal == nil { settext(hud, hud_text()) }
}
fn hud_text() {
  if mode == "edit" {
    if selmode == "vert" { return "EDIT · vertices — click / Shift+click / drag a box · G R S move · E extrude needs faces (3)" }
    return "EDIT · faces — click / Shift+click / drag a box · E extrude · G R S · X delete"
  }
  if len(objs) == 0 { return "Add a shape from the left panel" }
  return "OBJECT · click to select · G R S or drag the gizmo arrows · Tab = edit mode"
}
let flash_n = 0
fn flash(t) {
  flash_n += 1
  let me = flash_n
  settext(hud, t)
  after(2200, fn() { if flash_n == me and modal == nil { settext(hud, hud_text()) } })
}
fn show_help() {
  let p = popup(520, 300)
  css(p, {"max-width": 520})
  label(p, "⬢ Kugel 3D Modeler — keys", "kapp-sec")
  for t in ["Right-drag or middle-drag: orbit · Shift + drag: pan · wheel: zoom",
      "Left click: select (Shift adds) · drag on empty space: box select",
      "Tab: Object / Edit mode · in Edit mode 1 = vertices, 3 = faces · A: all / none",
      "G move · R rotate · S scale → then X / Y / Z locks an axis, type a number, click to finish, Esc cancels",
      "E extrude faces · X delete · Shift+D duplicate · M merge vertices · Ctrl+J join · F frame",
      "Ctrl+Z undo · Ctrl+Shift+Z redo · Ctrl+S save",
      "📦 To games saves your model for KampfScript games: let m = load_model(s, \"name\")",
      "⚡ Performance: lower resolution for weak PCs (integrated graphics, 4 GB RAM)"] {
    label(p, "• " + t, "kapp-tiny")
  }
}

# ---------------------------------------------------------------- start
set_bg(bgname)
set_light(lightname)
set_perf(perf)
gizmo_tool_shape()
draw_scene_panel()
add_shape("cube")
undo_stack = []
dirty = false
refresh_all()
on_frame(fn(dt) {
  if modal == nil { place_gizmo() }
})
