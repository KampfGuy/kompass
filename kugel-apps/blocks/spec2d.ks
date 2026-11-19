# ---- Kugel Blocks (2D): block palette. Each block: [op, category, shape, text, defaults, KampfScript template, flags]
# Shapes: hat, stack, c (one mouth), c2 (if/else), cap (nothing below), rep (value), num (number value), bool (true/false).
# Slots in the text: %n number, %s text, %b true/false, %m.menu fixed menu, %d.menu menu that also takes a value block,
# %v variable, %l list. $1, $2 ... in the template are the slots; $SUB / $SUB2 are the blocks inside the mouths.
# Flags: "s" = sprites only, "st" = Stage only.
let APP = {name: "Kugel Blocks", short: "blocks", ext: "kblocks", is3d: false, stage_name: "Stage", thing: "Sprite", things: "Sprites"}
let CATS = [
  {id: "motion", label: "Motion", color: "#4c97ff"}, {id: "looks", label: "Looks", color: "#9966ff"}, {id: "sound", label: "Sound", color: "#cf63cf"},
  {id: "events", label: "Events", color: "#ffbf00"}, {id: "control", label: "Control", color: "#ffab19"}, {id: "sensing", label: "Sensing", color: "#5cb1d6"},
  {id: "operators", label: "Operators", color: "#59c059"}, {id: "variables", label: "Variables", color: "#ff8c1a"}, {id: "lists", label: "Lists", color: "#ff661a"},
  {id: "myblocks", label: "My Blocks", color: "#ff6680"}, {id: "pen", label: "Pen", color: "#0fbd8c"}]
let SPEC_LIST = [
  ["move", "motion", "stack", "move %n steps", [10], "kb_move(me, $1)", "s"],
  ["turnr", "motion", "stack", "turn ↻ %n degrees", [15], "kb_turn(me, $1)", "s"],
  ["turnl", "motion", "stack", "turn ↺ %n degrees", [15], "kb_turn_left(me, $1)", "s"],
  ["goto", "motion", "stack", "go to %d.goto", ["random position"], "kb_goto_target(me, $1)", "s"],
  ["gotoxy", "motion", "stack", "go to x: %n y: %n", [0, 0], "kb_goto(me, $1, $2)", "s"],
  ["glide", "motion", "stack", "glide %n secs to %d.goto", [1, "random position"], "kb_glide_to(me, $1, $2)", "s"],
  ["glidexy", "motion", "stack", "glide %n secs to x: %n y: %n", [1, 0, 0], "kb_glide(me, $1, $2, $3)", "s"],
  ["point", "motion", "stack", "point in direction %n", [90], "kb_point(me, $1)", "s"],
  ["towards", "motion", "stack", "point towards %d.towards", ["mouse-pointer"], "kb_point_towards(me, $1)", "s"],
  ["chx", "motion", "stack", "change x by %n", [10], "kb_goto(me, me.x + $1, me.y)", "s"],
  ["setx", "motion", "stack", "set x to %n", [0], "kb_goto(me, $1, me.y)", "s"],
  ["chy", "motion", "stack", "change y by %n", [10], "kb_goto(me, me.x, me.y + $1)", "s"],
  ["sety", "motion", "stack", "set y to %n", [0], "kb_goto(me, me.x, $1)", "s"],
  ["bounce", "motion", "stack", "if on edge, bounce", [], "kb_bounce(me)", "s"],
  ["rotstyle", "motion", "stack", "set rotation style %m.rot", ["left-right"], "me.rot = $1", "s"],
  ["xpos", "motion", "num", "x position", [], "me.x", "s"],
  ["ypos", "motion", "num", "y position", [], "me.y", "s"],
  ["dir", "motion", "num", "direction", [], "me.dir", "s"],
  ["sayfor", "looks", "stack", "say %s for %n seconds", ["Hello!", 2], "kb_say(me, $1, $2, false)", "s"],
  ["say", "looks", "stack", "say %s", ["Hello!"], "kb_say(me, $1, nil, false)", "s"],
  ["thinkfor", "looks", "stack", "think %s for %n seconds", ["Hmm...", 2], "kb_say(me, $1, $2, true)", "s"],
  ["think", "looks", "stack", "think %s", ["Hmm..."], "kb_say(me, $1, nil, true)", "s"],
  ["costume", "looks", "stack", "switch costume to %d.costume", ["@costume"], "kb_set_costume(me, $1)", "s"],
  ["nextcostume", "looks", "stack", "next costume", [], "kb_set_costume(me, \"next costume\")", "s"],
  ["backdrop", "looks", "stack", "switch backdrop to %d.backdrop", ["@backdrop"], "kb_backdrop($1)", ""],
  ["nextbackdrop", "looks", "stack", "next backdrop", [], "kb_backdrop(\"next backdrop\")", ""],
  ["chsize", "looks", "stack", "change size by %n", [10], "kb_change_size(me, $1)", "s"],
  ["setsize", "looks", "stack", "set size to %n %", [100], "kb_set_size(me, $1)", "s"],
  ["cheffect", "looks", "stack", "change %m.effect effect by %n", ["ghost", 25], "kb_effect(me, $1, $2, true)", ""],
  ["seteffect", "looks", "stack", "set %m.effect effect to %n", ["ghost", 0], "kb_effect(me, $1, $2, false)", ""],
  ["cleareffects", "looks", "stack", "clear graphic effects", [], "me.ghost = 0\nme.bright = 0", ""],
  ["show", "looks", "stack", "show", [], "me.visible = true", "s"],
  ["hide", "looks", "stack", "hide", [], "me.visible = false", "s"],
  ["front", "looks", "stack", "go to %m.front layer", ["front"], "kb_front(me, $1 == \"front\")", "s"],
  ["layers", "looks", "stack", "go %m.fwd %n layers", ["forward", 1], "kb_layers2(me, $1, $2)", "s"],
  ["costumeinfo", "looks", "rep", "costume %m.numname", ["number"], "kb_costume_info(me, $1)", "s"],
  ["backdropinfo", "looks", "rep", "backdrop %m.numname", ["number"], "kb_backdrop_info($1)", ""],
  ["size", "looks", "num", "size", [], "me.size", "s"],
  ["whenbackdrop", "events", "hat", "when backdrop switches to %d.backdrop", ["@backdrop"], "@backdrop", ""],
  ["touching", "sensing", "bool", "touching %d.touch ?", ["mouse-pointer"], "kb_touching(me, $1)", "s"],
  ["distance", "sensing", "num", "distance to %d.towards", ["mouse-pointer"], "kb_distance(me, $1)", "s"],
  ["mousex", "sensing", "num", "mouse x", [], "kb_mouse_x()", ""],
  ["mousey", "sensing", "num", "mouse y", [], "kb_mouse_y()", ""],
  ["of", "sensing", "rep", "%m.prop of %d.sprite", ["x position", "@sprite"], "kb_of($2, $1)", ""],
  ["penclear", "pen", "stack", "erase all", [], "kb_pen_clear()", ""],
  ["stamp", "pen", "stack", "stamp", [], "kb_stamp(me)", "s"],
  ["pendown", "pen", "stack", "pen down", [], "kb_pen_down(me, true)", "s"],
  ["penup", "pen", "stack", "pen up", [], "kb_pen_down(me, false)", "s"],
  ["pencolor", "pen", "stack", "set pen color to %m.pcolor", ["blue"], "kb_pen_color(me, $1)", "s"],
  ["pensize", "pen", "stack", "set pen size to %n", [3], "kb_pen_size(me, $1, false)", "s"],
  ["chpensize", "pen", "stack", "change pen size by %n", [1], "kb_pen_size(me, $1, true)", "s"]] + COMMON_ROWS
let MENUS = merge_maps(COMMON_MENUS, {rot: ["left-right", "don't rotate", "all around"], effect: ["ghost", "brightness"], front: ["front", "back"], fwd: ["forward", "backward"],
  numname: ["number", "name"], stop: ["all", "this script"], math: ["abs", "floor", "ceiling", "sqrt", "sin", "cos", "tan", "asin", "acos", "atan", "ln", "log", "e ^", "10 ^"],
  prop: ["x position", "y position", "direction", "costume #", "size", "backdrop #"], pcolor: ["red", "orange", "yellow", "green", "blue", "purple", "pink", "black", "white", "brown"]})
# menus that depend on the project (sprite names, costumes, messages ...)
fn dyn_menu(name) {
  let others = filter(sprite_names(), fn(n) { return n != cur_target().name })
  if name == "goto" { return (["random position", "mouse-pointer"] + others) }
  if name == "towards" { return (["mouse-pointer"] + others) }
  if name == "touch" { return (["mouse-pointer", "edge"] + others) }
  if name == "clone" { if cur_target().is_stage { return sprite_names() } return (["myself"] + others) }
  if name == "sprite" { return sprite_names() }
  if name == "costume" { return map(cur_target().costumes, fn(c) { return c.name }) }
  if name == "backdrop" { return map(stage_target().costumes, fn(c) { return c.name }) }
  if name == "sound" { return sound_names() }
  return nil
}
fn menu_default(tag) {
  if tag == "@costume" { let cs = cur_target().costumes; if len(cs) > 0 { return cs[0].name } return "" }
  if tag == "@backdrop" { let cs = stage_target().costumes; if len(cs) > 0 { return cs[0].name } return "" }
  if tag == "@sprite" { let n = sprite_names(); if len(n) > 0 { return n[0] } return "" }
  return nil
}
