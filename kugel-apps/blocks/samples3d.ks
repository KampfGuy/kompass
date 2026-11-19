# ---- Kugel Blocks 3D: sample games and the help page
fn sample_coins() {
  let w = make_world()
  w.scripts = [scr(20, 20, [mk("flag"), mk("setvar", ["score", 0]), mk("showvar", ["score"]), mk("waituntil", [mk("eq", [vr("score"), 8])]), mk("broadcast", ["win"])])]
  let pl = make_actor("Player", "sphere", "orange", 0, 0.5, 4)
  pl.grav = true
  pl.scripts = [
    scr(20, 20, [mk("flag"), mk("follow3", ["Player"]), mk("goto3", [0, 0.5, 4]), mk("sayfor3", ["Arrows to walk, Space to jump!", 2.5])]),
    scr(20, 200, [mk("flag"), mk("forever", [], [mk("walk", ["arrows / WASD", 5]),
      mk("if", [mk("and", [mk("keypressed", ["space"]), mk("ground3")])], [mk("jump3", [8]), mk("playsound", ["jump"])])])]),
    scr(20, 420, [mk("whenreceive", ["win"]), mk("playsound", ["win"]), mk("sayfor3", ["All coins! 🎉", 3]), mk("stop", ["all"])])]
  let step = make_actor("Step", "cube", "blue", 3, 0.5, -2)
  step.w = 2
  step.d = 2
  step.solid = true
  step.texture = "grid"
  let tower = make_actor("Tower", "cube", "gray", -4, 1, -5)
  tower.w = 2
  tower.h = 2
  tower.d = 2
  tower.solid = true
  tower.texture = "bricks"
  let coin = make_actor("Coin", "torus", "gold", 0, 1, 0)
  coin.glow = "orange"
  coin.size = 80
  coin.scripts = [
    scr(20, 20, [mk("flag"), mk("hide3"), mk("goto3", [-4, 2.7, -5]), mk("clone", ["myself"]),
      mk("repeat", [7], [mk("goto3", [mk("rand", [-8, 8]), 1, mk("rand", [-10, 2])]), mk("clone", ["myself"])])]),
    scr(20, 330, [mk("whenclone"), mk("show3"), mk("forever", [], [mk("spin3", [0, 5, 0]),
      mk("if", [mk("touch3", ["Player"])], [mk("chvar", ["score", 1]), mk("playsound", ["coin"]), mk("deleteclone")])])])]
  return {name: "Coin Run", targets: [w, pl, step, tower, coin], vars: {score: 0}, lists: {}, shown: {score: true}, msgs: ["win"], version: 1, arrange: true}
}
fn sample_maze() {
  let w = make_world()
  w.world.sky = "teal"
  w.world.sky2 = "white"
  w.world.ground_color = "gray"
  w.world.ground_tex = "checker"
  w.world.cam = {x: 0, y: 22, z: 14}
  let wx = []
  let wz = []
  let x = -8
  while x <= 8 { push(wx, x); push(wz, -8); push(wx, x); push(wz, 8); x += 2 }
  let z = -6
  while z <= 6 { push(wx, -8); push(wz, z); push(wx, 8); push(wz, z); z += 2 }
  for row_ in [[4, -6, 2], [0, -2, 6], [-4, -6, 2]] {
    let xx = row_[1]
    while xx <= row_[2] { push(wx, xx); push(wz, row_[0]); xx += 2 }
  }
  w.scripts = [scr(20, 20, [mk("flag"), mk("light3", ["day"]), mk("fog3", ["on"])])]
  let pl = make_actor("Player", "cylinder", "white", -6, 0.75, 6)
  pl.h = 1.5
  pl.w = 0.6
  pl.d = 0.6
  pl.grav = true
  pl.scripts = [
    scr(20, 20, [mk("flag"), mk("first3", ["Player"]), mk("goto3", [-6, 0.75, 6]), mk("point3", [-90]), mk("forever", [], [mk("walk", ["WASD + mouse", 4])])]),
    scr(20, 260, [mk("whenreceive", ["win"]), mk("fixed3", [0, 22, 14]), mk("playsound", ["win"]), mk("show3"), mk("sayfor3", ["Out of the maze! 🎉", 3]), mk("stop", ["all"])])]
  let wall = make_actor("Wall", "cube", "brown", 0, 1.25, 0)
  wall.w = 2
  wall.h = 2.5
  wall.d = 2
  wall.solid = true
  wall.texture = "bricks"
  wall.visible = false
  wall.scripts = [
    scr(20, 20, [mk("flag"), mk("hide3"), mk("setvar", ["i", 1]), mk("repeat", [mk("listlen", ["wx"])], [
      mk("goto3", [mk("listitem", [vr("i"), "wx"]), 1.25, mk("listitem", [vr("i"), "wz"])]), mk("clone", ["myself"]), mk("chvar", ["i", 1])])]),
    scr(20, 280, [mk("whenclone"), mk("show3")])]
  let goal = make_actor("Goal", "torus", "gold", 6, 1.2, -6)
  goal.glow = "yellow"
  goal.size = 150
  goal.scripts = [scr(20, 20, [mk("flag"), mk("forever", [], [mk("spin3", [0, 3, 0]), mk("if", [mk("touch3", ["Player"])], [mk("broadcast", ["win"]), mk("stop", ["this script"])])])])]
  return {name: "Maze Walk", targets: [w, pl, wall, goal], vars: {i: 1}, lists: {wx: wx, wz: wz}, shown: {}, msgs: ["win"], version: 1, arrange: true}
}
fn sample_dodge() {
  let w = make_world()
  w.world.sky = "black"
  w.world.sky2 = "purple"
  w.world.ground = false
  w.world.light = "night"
  w.world.cam = {x: 0, y: 3, z: 9}
  w.scripts = [scr(20, 20, [mk("flag"), mk("setvar", ["score", 0]), mk("showvar", ["score"]), mk("forever", [], [mk("wait", [1]), mk("chvar", ["score", 1])])])]
  let ship = make_actor("Ship", "cone", "blue", 0, 0.5, 4)
  ship.glow = "blue"
  ship.scripts = [
    scr(20, 20, [mk("flag"), mk("fixed3", [0, 3, 9]), mk("goto3", [0, 0.5, 4]), mk("forever", [], [
      mk("if", [mk("and", [mk("keypressed", ["left arrow"]), mk("gt", [mk("xpos3"), -5])])], [mk("chx3", [-0.15])]),
      mk("if", [mk("and", [mk("keypressed", ["right arrow"]), mk("lt", [mk("xpos3"), 5])])], [mk("chx3", [0.15])]),
      mk("if", [mk("gt", [mk("stick3", ["lx"]), 0.3])], [mk("chx3", [0.15])]),
      mk("if", [mk("lt", [mk("stick3", ["lx"]), -0.3])], [mk("chx3", [-0.15])])])]),
    scr(20, 330, [mk("whenreceive", ["boom"]), mk("playsound", ["boom"]), mk("color3", ["red"]), mk("sayfor3", [mk("join", ["Boom! Score: ", vr("score")]), 3]), mk("stop", ["all"])])]
  let rock = make_actor("Rock", "sphere", "gray", 0, 0.5, -40)
  rock.texture = "noise"
  rock.visible = false
  rock.scripts = [
    scr(20, 20, [mk("flag"), mk("hide3"), mk("forever", [], [mk("clone", ["myself"]), mk("wait", [mk("rand", [0.3, 0.8])])])]),
    scr(20, 200, [mk("whenclone"), mk("goto3", [mk("rand", [-5, 5]), 0.5, -40]), mk("setsize3", [mk("rand", [60, 160])]), mk("show3"),
      mk("repeatuntil", [mk("gt", [mk("zpos3"), 10])], [mk("chz3", [mk("add", [0.3, mk("div", [vr("score"), 60])])]), mk("spin3", [4, 0, 2]),
        mk("if", [mk("touch3", ["Ship"])], [mk("broadcast", ["boom"])])]), mk("deleteclone")])]
  return {name: "Space Dodge", targets: [w, ship, rock], vars: {score: 0}, lists: {}, shown: {score: true}, msgs: ["boom"], version: 1, arrange: true}
}
fn samples() {
  return [{title: "Coin Run (third person)", make: sample_coins}, {title: "Maze Walk (first person)", make: sample_maze}, {title: "Space Dodge (clones)", make: sample_dodge},
    {title: "Empty project", make: new_project}]
}
let HELP = [
  "Kugel Blocks 3D makes 3D games from blocks. It works like Kugel Blocks (Scratch-style), but your actors are 3D shapes — or models you made in the Kugel 3D Modeler — and there are blocks for gravity, jumping, walls and cameras, so a walking-and-jumping game takes about ten blocks.",
  "## A jumping game in 1 minute",
  "1. Select the Player (an orange ball). In 🧊 Look tick “Gravity”.",
  "2. Events: drag “when ⚑ clicked”. Camera: add “camera: follow Player”.",
  "3. Control: add “forever”. Inside it put Motion → “walk with arrows / WASD keys, speed 4”.",
  "4. Also inside: “if key space pressed? and on the ground? then jump with power 8” (Sensing, Operators, Physics).",
  "5. Press ⚑ Go. Walk with the arrows, jump with Space. Add a Cube actor, tick “Solid”, and you can jump onto it.",
  "## Tips",
  "• Sizes are metres. The ground is y = 0, so a 1 m ball stands at y = 0.5.",
  "• Solid actors are walls and floors: walkers bump into them and gravity lets actors stand on them.",
  "• Cameras: follow (third person, drag the mouse to turn), first person (WASD + mouse), or fixed.",
  "• Gamepads work: the left stick walks, “gamepad a pressed?” reads buttons.",
  "• Models: make one in the Kugel 3D Modeler, press 📦 To games, then pick it in 🧊 Look or with “change to model”.",
  "• Clones, broadcasts, variables, lists and My Blocks work exactly like in Kugel Blocks.",
  "• Weak PC? World → 🧊 Look → ⚡ Performance mode renders at a lower resolution. There are no shadows, to keep it fast.",
  "## Saving and sharing",
  "Save keeps an editable .kblocks3d project. ⇩ Export game writes a .ks file that plays in Kompass. Open { } KampfScript to see the code your blocks make."]
