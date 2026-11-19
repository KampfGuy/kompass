# ---- Kugel Blocks (2D): sample games and the help page
fn sample_bounce() {
  ensure_lib()
  let st = make_stage([deep(BACKS["Sky"]), deep(BACKS["Grass"])])
  st.scripts = [scr(20, 20, [mk("whenstageclicked"), mk("nextbackdrop"), mk("playsound", ["pop"])])]
  let k = make_sprite("Kugel", [deep(LIB["Kugel"]), deep(LIB["Kugel 2"])], 0, 0)
  k.scripts = [
    scr(20, 20, [mk("flag"), mk("gotoxy", [0, 0]), mk("point", [45]), mk("sayfor", ["Hi! I'm Kugel. Click me!", 2]),
      mk("forever", [], [mk("move", [6]), mk("bounce"), mk("if", [mk("touching", ["edge"])], [mk("playsound", ["click"])])])]),
    scr(20, 330, [mk("whenclicked"), mk("nextcostume"), mk("playsound", ["jump"]), mk("repeat", [5], [mk("chsize", [8])]), mk("repeat", [5], [mk("chsize", [-8])]), mk("nextcostume")]),
    scr(330, 330, [mk("whenkey", ["space"]), mk("turnr", [mk("rand", [90, 180])])])]
  let b = make_sprite("Ball", [deep(LIB["Ball"])], -150, 80)
  b.scripts = [scr(20, 20, [mk("flag"), mk("point", [-30]), mk("forever", [], [mk("move", [4]), mk("bounce"), mk("if", [mk("touching", ["Kugel"])], [mk("say", ["Boing!"]), mk("turnr", [180]), mk("move", [20])], [])])])]
  return {name: "Bouncing Kugel", targets: [st, k, b], vars: {}, lists: {}, shown: {}, msgs: ["message1"], version: 1, arrange: true}
}
fn sample_catch() {
  ensure_lib()
  let st = make_stage([deep(BACKS["Grass"])])
  st.scripts = [scr(20, 20, [mk("flag"), mk("setvar", ["score", 0]), mk("setvar", ["lives", 3]), mk("showvar", ["score"]), mk("showvar", ["lives"])])]
  let pad = make_sprite("Paddle", [deep(LIB["Paddle"])], 0, -150)
  pad.scripts = [
    scr(20, 20, [mk("flag"), mk("gotoxy", [0, -150]), mk("forever", [], [
      mk("if", [mk("keypressed", ["left arrow"])], [mk("chx", [-9])]),
      mk("if", [mk("keypressed", ["right arrow"])], [mk("chx", [9])])])]),
    scr(20, 330, [mk("whenreceive", ["win"]), mk("playsound", ["win"]), mk("sayfor", ["You win! 🎉", 2]), mk("stop", ["all"])]),
    scr(330, 330, [mk("whenreceive", ["game over"]), mk("playsound", ["lose"]), mk("sayfor", ["Game over!", 2]), mk("stop", ["all"])])]
  let star = make_sprite("Star", [deep(LIB["Star"])], 0, 170)
  star.scripts = [
    scr(20, 20, [mk("flag"), mk("forever", [], [
      mk("gotoxy", [mk("rand", [-220, 220]), 180]),
      mk("repeatuntil", [mk("or", [mk("touching", ["Paddle"]), mk("lt", [mk("ypos"), -170])])], [mk("chy", [mk("sub", [-3, mk("div", [vr("score"), 2])])]), mk("turnr", [4])]),
      mk("ifelse", [mk("touching", ["Paddle"])], [mk("chvar", ["score", 1]), mk("playsound", ["coin"])], [mk("chvar", ["lives", -1]), mk("playsound", ["hit"])]),
      mk("if", [mk("gt", [vr("score"), 9])], [mk("broadcast", ["win"]), mk("stop", ["this script"])]),
      mk("if", [mk("lt", [vr("lives"), 1])], [mk("broadcast", ["game over"]), mk("stop", ["this script"])])])])]
  return {name: "Catch the Star", targets: [st, pad, star], vars: {score: 0, lives: 3}, lists: {}, shown: {score: true, lives: true}, msgs: ["win", "game over"], version: 1, arrange: true}
}
fn sample_shooter() {
  ensure_lib()
  let st = make_stage([deep(BACKS["Space"])])
  st.scripts = [scr(20, 20, [mk("flag"), mk("setvar", ["score", 0]), mk("showvar", ["score"]), mk("playsound", ["laser"])])]
  let ship = make_sprite("Rocket", [deep(LIB["Rocket"])], 0, -140)
  ship.scripts = [
    scr(20, 20, [mk("flag"), mk("gotoxy", [0, -140]), mk("show"), mk("forever", [], [
      mk("if", [mk("keypressed", ["left arrow"])], [mk("chx", [-8])]),
      mk("if", [mk("keypressed", ["right arrow"])], [mk("chx", [8])]),
      mk("if", [mk("touching", ["Alien"])], [mk("broadcast", ["game over"])])])]),
    scr(20, 360, [mk("whenkey", ["space"]), mk("clone", ["Laser"]), mk("playsound", ["laser"])]),
    scr(330, 360, [mk("whenreceive", ["game over"]), mk("playsound", ["boom"]), mk("sayfor", [mk("join", ["Game over! Score: ", vr("score")]), 2]), mk("stop", ["all"])])]
  let laser = make_sprite("Laser", [deep(LIB["Laser"])], 0, -100)
  laser.visible = false
  laser.scripts = [
    scr(20, 20, [mk("flag"), mk("hide")]),
    scr(20, 120, [mk("whenclone"), mk("goto", ["Rocket"]), mk("chy", [30]), mk("show"),
      mk("repeatuntil", [mk("gt", [mk("ypos"), 175])], [mk("chy", [12])]), mk("deleteclone")])]
  let alien = make_sprite("Alien", [deep(LIB["Alien"])], 0, 150)
  alien.visible = false
  alien.procs = [{name: "explode", params: []}]
  alien.scripts = [
    scr(20, 20, [mk("flag"), mk("hide"), mk("forever", [], [mk("clone", ["myself"]), mk("wait", [mk("rand", [0.6, 1.4])])])]),
    scr(20, 230, [mk("whenclone"), mk("gotoxy", [mk("rand", [-210, 210]), 170]), mk("show"),
      mk("repeatuntil", [mk("lt", [mk("ypos"), -175])], [
        mk("chy", [-3]),
        mk("if", [mk("touching", ["Laser"])], [{op: "call", name: "explode", params: [], args: []}])]),
      mk("deleteclone")]),
    scr(400, 20, [{op: "define", name: "explode", params: [], args: []}, mk("chvar", ["score", 1]), mk("playsound", ["boom"]),
      mk("repeat", [6], [mk("cheffect", ["ghost", 16]), mk("chsize", [10])]), mk("deleteclone")])]
  return {name: "Space Shooter", targets: [st, ship, laser, alien], vars: {score: 0}, lists: {}, shown: {score: true}, msgs: ["game over"], version: 1, arrange: true}
}
fn samples() {
  return [{title: "Bouncing Kugel", make: sample_bounce}, {title: "Catch the Star", make: sample_catch}, {title: "Space Shooter (clones)", make: sample_shooter},
    {title: "Empty project", make: new_project}]
}
let HELP = [
  "Kugel Blocks is a Scratch-style game maker. Snap blocks together, press ⚑ Go, and your game runs on the stage on the right. Every block turns into real KampfScript — open { } KampfScript to see it.",
  "## Your first game in 1 minute",
  "1. Click Events on the left and drag “when ⚑ clicked” into the middle.",
  "2. From Control drag “forever” under it, so it clicks into place.",
  "3. From Motion drag “move 10 steps” and “if on edge, bounce” INTO the forever.",
  "4. Press ⚑ Go. Your sprite bounces around. Press ⏹ Stop to stop.",
  "## Tips",
  "• Click a white field on a block to type a number or text. Click a dark field for a menu.",
  "• Round blocks (values) and pointy blocks (true/false) go into the holes of other blocks.",
  "• Drag a block back onto the palette to delete it. Right-click for Duplicate, Delete and Clean up.",
  "• Dragging a block takes every block under it too. Ctrl+Z undoes, Ctrl+Shift+Z redoes.",
  "• Each sprite has its own scripts — pick it under Sprites on the right. The Stage has scripts too.",
  "• 🎨 Costumes has a paint editor (brush, eraser, fill, shapes) and a library. Drag sprites on the stage to place them.",
  "• Variables: “＋ Variable” on the far left. Tick-free: they show on the stage while the game runs (hide them with “hide variable”).",
  "• Clones: “create clone of myself” + “when I start as a clone” — see the Space Shooter sample.",
  "• My Blocks: “＋ Block” makes your own block; build what it does under its “define” hat.",
  "## Saving and sharing",
  "Save keeps an editable .kblocks project. ⇩ Export game writes a .ks file: open it in Kompass (or paste it into the Kompass editor) and it plays — nobody needs Kugel Blocks for that.",
  "## Coordinates",
  "The stage is 480 × 360: x goes from -240 (left) to 240 (right), y from -180 (bottom) to 180 (top). Direction 90 = right, 0 = up, -90 = left, 180 = down."]
