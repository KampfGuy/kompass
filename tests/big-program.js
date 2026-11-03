// Builds a deterministic ~330 KB KampfScript program for the 1.5.1 big-code tests: 400 generated level maps,
// 300 helper functions, a heavy start-up (decodes every level ≈ 400k+ steps) and a canvas game loop.
function bigProgram() {
  const L = ['# Big Level Pack — a generated 300 KB+ KampfScript program (Kompass 1.5.1 big-code test)', 'let LEVELS = ['];
  let seed = 7; const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
  for (let i = 0; i < 460; i++) {
    const rows = []; for (let r = 0; r < 12; r++) { let s = ''; for (let c = 0; c < 40; c++) s += rnd() < 0.18 ? '#' : rnd() < 0.03 ? '*' : '.'; rows.push(JSON.stringify(s)); }
    L.push('  {name: "Level ' + (i + 1) + '", rows: [' + rows.join(', ') + ']},');
  }
  L.push(']');
  for (let i = 0; i < 400; i++) L.push('fn helper_' + i + '(x) {\n  # helper ' + i + ' — scales and clamps a value for level ' + (i % 460 + 1) + '\n  let y = x * ' + (i % 7 + 1) + ' + ' + i + '\n  if y > 1000 { return y % 1000 }\n  return y\n}');
  L.push(`let walls = 0
let stars = 0
for lv in LEVELS {
  for row in lv.rows {
    for ch in row { if ch == "#" { walls += 1 } else if ch == "*" { stars += 1 } }
  }
}
let check = 0
for i in range(300) { check += helper_0(i) }
print("levels", len(LEVELS), "walls", walls, "stars", stars)
let c = canvas(body())
let level = 0
let t = 0
on_keypress(fn(k) { if k == "right" { level = (level + 1) % len(LEVELS) } })
on_frame(fn(dt) {
  t += dt
  let s = canvas_size(c)
  draw_clear(c, "#10141c")
  let lv = LEVELS[level]
  let cw = s.w / 40
  let chh = (s.h - 60) / 12
  for y, row in lv.rows {
    for x, ch in row {
      if ch == "#" { draw_rect(c, x * cw, 60 + y * chh, cw - 1, chh - 1, "#3b4a66") }
      else if ch == "*" { draw_circle(c, x * cw + cw / 2, 60 + y * chh + chh / 2, chh / 3, "#ffcc33") }
    }
  }
  draw_text(c, 16, 30, lv.name + " of " + str(len(LEVELS)) + "  ·  " + str(walls) + " walls, " + str(stars) + " stars  ·  → next level", "white", 16)
})`);
  return L.join('\n') + '\n';
}
module.exports = { bigProgram };
if (require.main === module) process.stdout.write(bigProgram());
