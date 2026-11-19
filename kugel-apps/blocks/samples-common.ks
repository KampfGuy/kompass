# ---- helpers to build sample projects in code
fn mk(op, args, sub, sub2) {
  let s = SPEC[op]
  let b = {op: op, args: []}
  let n = 0
  for p in s.parts { if p.t == nil { n += 1 } }
  for i in n {
    let v = ""
    if args != nil and i < len(args) { v = args[i] } else {
      if i < len(s.defaults) { v = s.defaults[i]; if type(v) == "string" and startswith(v, "@") { v = "" } }
    }
    push(b.args, v)
  }
  if is_c(s.shape) { b.sub = sub or [] }
  if s.shape == "c2" { b.sub2 = sub2 or [] }
  return b
}
fn vr(name) { return {op: "var", name: name, args: []} }
fn scr(x, y, blocks) { return {x: x, y: y, blocks: blocks} }
