# ---- Kugel Blocks 3D: block palette (same format as spec2d.ks). Sizes are metres; y is up; the ground is y = 0.
let APP = {name: "Kugel Blocks 3D", short: "blocks3d", ext: "kblocks3d", is3d: true, stage_name: "World", thing: "Actor", things: "Actors"}
let CATS = [
  {id: "motion", label: "Motion", color: "#4c97ff"}, {id: "looks", label: "Looks", color: "#9966ff"}, {id: "physics", label: "Physics", color: "#2bb5a8"},
  {id: "camera", label: "Camera", color: "#e05555"}, {id: "world", label: "World", color: "#6cbf3f"}, {id: "sound", label: "Sound", color: "#cf63cf"},
  {id: "events", label: "Events", color: "#ffbf00"}, {id: "control", label: "Control", color: "#ffab19"}, {id: "sensing", label: "Sensing", color: "#5cb1d6"},
  {id: "operators", label: "Operators", color: "#59c059"}, {id: "variables", label: "Variables", color: "#ff8c1a"}, {id: "lists", label: "Lists", color: "#ff661a"},
  {id: "myblocks", label: "My Blocks", color: "#ff6680"}]
let SPEC_LIST = [
  ["walk", "motion", "stack", "walk with %m.walk keys, speed %n", ["arrows / WASD", 4], "kb3_walk(me, $1, $2)", "s"],
  ["move3", "motion", "stack", "move %n metres", [1], "kb3_move(me, $1)", "s"],
  ["turnr3", "motion", "stack", "turn ↻ %n degrees", [15], "kb3_turn(me, $1)", "s"],
  ["turnl3", "motion", "stack", "turn ↺ %n degrees", [15], "kb3_turn(me, -1 * $1)", "s"],
  ["goto3", "motion", "stack", "go to x: %n y: %n z: %n", [0, 0.5, 0], "kb3_goto(me, $1, $2, $3)", "s"],
  ["gotot3", "motion", "stack", "go to %d.goto3", ["random position"], "kb3_goto_target(me, $1)", "s"],
  ["glide3", "motion", "stack", "glide %n secs to x: %n y: %n z: %n", [1, 0, 0.5, 0], "kb3_glide(me, $1, $2, $3, $4)", "s"],
  ["chx3", "motion", "stack", "change x by %n", [1], "kb3_to(me, me.x + $1, me.y, me.z)", "s"],
  ["chy3", "motion", "stack", "change y by %n", [1], "kb3_to(me, me.x, me.y + $1, me.z)", "s"],
  ["chz3", "motion", "stack", "change z by %n", [1], "kb3_to(me, me.x, me.y, me.z + $1)", "s"],
  ["setx3", "motion", "stack", "set x to %n", [0], "me.x = $1", "s"],
  ["sety3", "motion", "stack", "set y to %n", [0], "me.y = $1", "s"],
  ["setz3", "motion", "stack", "set z to %n", [0], "me.z = $1", "s"],
  ["point3", "motion", "stack", "point in direction %n", [0], "me.yaw = kb3_dir($1)", "s"],
  ["towards3", "motion", "stack", "point towards %d.towards3", ["camera"], "kb3_point_towards(me, $1)", "s"],
  ["spin3", "motion", "stack", "spin x: %n y: %n z: %n degrees", [0, 10, 0], "kb3_spin(me, $1, $2, $3)", "s"],
  ["xpos3", "motion", "num", "x position", [], "me.x", "s"],
  ["ypos3", "motion", "num", "y position", [], "me.y", "s"],
  ["zpos3", "motion", "num", "z position", [], "me.z", "s"],
  ["dir3", "motion", "num", "direction", [], "me.yaw", "s"],
  ["color3", "looks", "stack", "set color to %d.color", ["red"], "kb3_set_color(me, $1)", "s"],
  ["glow3", "looks", "stack", "set glow to %d.glow", ["yellow"], "kb3_set_glow(me, $1)", "s"],
  ["tex3", "looks", "stack", "set pattern to %m.tex", ["checker"], "kb3_set_texture(me, $1)", "s"],
  ["shape3", "looks", "stack", "change shape to %m.shape", ["sphere"], "kb3_set_shape(me, $1, nil)", "s"],
  ["model3", "looks", "stack", "change to model %d.model", ["@model"], "kb3_set_shape(me, \"model\", $1)", "s"],
  ["sayfor3", "looks", "stack", "say %s for %n seconds", ["Hello!", 2], "kb_say3(me, $1, $2)", "s"],
  ["say3", "looks", "stack", "say %s", ["Hello!"], "me.say = kb_str($1)", "s"],
  ["chsize3", "looks", "stack", "change size by %n", [10], "me.size = clamp(me.size + $1, 5, 1000)", "s"],
  ["setsize3", "looks", "stack", "set size to %n %", [100], "me.size = clamp($1, 5, 1000)", "s"],
  ["show3", "looks", "stack", "show", [], "me.visible = true", "s"],
  ["hide3", "looks", "stack", "hide", [], "me.visible = false", "s"],
  ["size3", "looks", "num", "size", [], "me.size", "s"],
  ["grav3", "physics", "stack", "gravity %m.onoff", ["on"], "me.grav = $1 == \"on\"\nme.vy = 0", "s"],
  ["jump3", "physics", "stack", "jump with power %n", [8], "kb3_jump(me, $1)", "s"],
  ["solid3", "physics", "stack", "solid (others bump into me) %m.onoff", ["on"], "me.solid = $1 == \"on\"", "s"],
  ["ground3", "physics", "bool", "on the ground?", [], "kb3_on_ground(me)", "s"],
  ["vy3", "physics", "num", "falling speed", [], "me.vy", "s"],
  ["follow3", "camera", "stack", "camera: follow %d.actor", ["@me"], "kb3_follow(me, $1)", ""],
  ["first3", "camera", "stack", "camera: first person as %d.actor", ["@me"], "kb3_first(me, $1)", ""],
  ["fixed3", "camera", "stack", "camera: fixed at x: %n y: %n z: %n", [0, 6, 12], "kb3_fixed($1, $2, $3)", ""],
  ["camdist3", "camera", "stack", "camera distance %n", [6], "kb3_cam_dist($1)", ""],
  ["fov3", "camera", "stack", "field of view %n", [70], "kb3_fov($1)", ""],
  ["sky3", "world", "stack", "set sky to %d.color", ["sky"], "kb3_sky($1)", ""],
  ["fog3", "world", "stack", "fog %m.onoff", ["on"], "kb3_fog($1)", ""],
  ["light3", "world", "stack", "light: %m.light", ["sunset"], "kb3_light($1)", ""],
  ["groundc3", "world", "stack", "set ground color to %d.color", ["green"], "kb3_ground_color($1)", ""],
  ["gravity3", "world", "stack", "set world gravity to %n", [20], "kb3_gravity($1)", ""],
  ["touch3", "sensing", "bool", "touching %d.touch3 ?", ["ground"], "kb3_touching(me, $1)", "s"],
  ["dist3", "sensing", "num", "distance to %d.towards3", ["camera"], "kb3_distance(me, $1)", "s"],
  ["of3", "sensing", "rep", "%m.prop3 of %d.actor", ["x position", "@actor"], "kb3_of($2, $1)", ""],
  ["pad3", "sensing", "bool", "gamepad %m.pad pressed?", ["a"], "kb3_pad($1)", ""],
  ["stick3", "sensing", "num", "gamepad stick %m.stick", ["lx"], "kb3_stick($1)", ""]] + COMMON_ROWS
let COLOR_NAMES = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "black", "white", "gray", "brown", "sky", "teal", "gold"]
let MENUS = merge_maps(COMMON_MENUS, {walk: ["arrows / WASD", "WASD + mouse"], color: COLOR_NAMES, glow: ["none"] + COLOR_NAMES, tex: ["none", "checker", "grid", "bricks", "stripes", "noise"],
  shape: ["cube", "sphere", "cylinder", "cone", "torus", "plane"], onoff: ["on", "off"], light: ["day", "sunset", "night"],
  prop3: ["x position", "y position", "z position", "direction", "size"], pad: ["a", "b", "x", "y", "lb", "rb", "start", "select", "up", "down", "left", "right"], stick: ["lx", "ly", "rx", "ry"]})
fn dyn_menu(name) {
  let others = filter(sprite_names(), fn(n) { return n != cur_target().name })
  if name == "goto3" { return ["random position"] + others }
  if name == "towards3" { return ["camera"] + others }
  if name == "touch3" { return ["ground"] + others }
  if name == "clone" { if cur_target().is_stage { return sprite_names() } return ["myself"] + others }
  if name == "actor" { return sprite_names() }
  if name == "sound" { return sound_names() }
  if name == "model" { return map(model_list(), fn(m) { return m.name }) }
  return nil
}
fn menu_default(tag) {
  if tag == "@me" { if cur_target().is_stage { let n = sprite_names(); if len(n) > 0 { return n[0] } return "" } return cur_target().name }
  if tag == "@actor" { let n = sprite_names(); if len(n) > 0 { return n[0] } return "" }
  if tag == "@model" { let l = model_list(); if len(l) > 0 { return l[0].name } return "" }
  return nil
}
for r in SPEC_LIST {
  if r[0] == "whenclicked" { r[3] = "when this actor clicked" }
  if r[0] == "whenstageclicked" { r[3] = "when the world is clicked" }
}
