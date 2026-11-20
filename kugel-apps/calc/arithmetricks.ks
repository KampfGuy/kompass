# ---------------------------------------------------------------- Kugel Arithmetricks — the real calculator
# Standard (like Windows 11: each operator finishes the previous one), Scientific (full expressions with precedence),
# Programmer (HEX / DEC / OCT / BIN, AND / OR / XOR / NOT / shifts), Date calculation and 8 unit converters.
# History and memory are kept on this PC. Keyboard: digits, + - * / ^ ( ) . % Enter = Backspace Esc Delete.
let APP = "Kugel Arithmetricks"
let theme = store_get("theme", "light")
let mode = store_get("mode", "Standard")
let history = store_get("history", [])
let memory = store_get("memory", [])
let angle = store_get("angle", "deg")

let root = box(body(), "kcalc")
let head = row(root, "kcalc-head")
let main_ = row(root, "kcalc-main")
let left = col(main_, "kcalc-left")
let side = col(main_, "kcalc-side")
let nav = nil

fn save_all() { store_set("history", history); store_set("memory", memory); store_set("mode", mode); store_set("theme", theme); store_set("angle", angle) }
fn apply_theme() { togglestyle(root, "dark", theme == "dark") }

# ---------------------------------------------------------------- shared display helpers
let expr_l = nil
let disp_l = nil
let info_l = nil
fn set_display(t) {
  settext(disp_l, t)
  removestyle(disp_l, "small")
  removestyle(disp_l, "tiny")
  if len(t) > 16 { addstyle(disp_l, "small") }
  if len(t) > 24 { addstyle(disp_l, "tiny") }
}
fn add_history(expr, result) {
  insert(history, 0, {e: expr, r: result})
  if len(history) > 100 { pop(history) }
  save_all()
  draw_side()
}
fn key(parent, text, f, cls) {
  let b = button(parent, text, f, "kcalc-k " + cls)
  return b
}

# ---------------------------------------------------------------- Standard mode (Windows 11 behaviour)
let S = {acc: nil, op: "", entry: "0", fresh: true, expr: "", last_op: "", last_b: nil, err: ""}
fn s_reset() { S.acc = nil; S.op = ""; S.entry = "0"; S.fresh = true; S.expr = ""; S.last_op = ""; S.last_b = nil; S.err = "" }
fn entry_num() { let v = num(S.entry); if v == nil { return 0 }; return v }
fn op_sym(o) { if o == "*" { return "×" }; if o == "/" { return "÷" }; if o == "-" { return "−" }; return o }
fn apply_op(a, o, b) {
  if o == "+" { return {ok: true, v: a + b} }
  if o == "-" { return {ok: true, v: a - b} }
  if o == "*" { return {ok: true, v: a * b} }
  if o == "/" { if b == 0 { if a == 0 { return {ok: false, e: "Result is undefined"} }; return {ok: false, e: "Cannot divide by zero"} }; return {ok: true, v: a / b} }
  if o == "^" { return {ok: true, v: pow(a, b)} }
  return {ok: true, v: b}
}
fn s_error(msg) { S.err = msg; S.entry = "0"; S.acc = nil; S.op = ""; S.fresh = true; set_display(msg) }
fn s_show() {
  if S.err != "" { return }
  let t = S.entry
  if startswith(t, "-") and len(t) > 1 { t = "-" + t }
  let parts = split(S.entry, ".")
  let shown = calc_group(parts[0])
  if len(parts) > 1 { shown = shown + "." + parts[1] }
  if contains(S.entry, "e") { shown = S.entry }
  set_display(shown)
  settext(expr_l, S.expr)
}
fn s_digit(d) {
  if S.err != "" { s_reset() }
  if S.fresh { S.entry = "0"; S.fresh = false; if S.op == "" and S.acc == nil { S.expr = "" } }
  let digits = len(replace(replace(S.entry, "-", ""), ".", ""))
  if digits >= 16 { return }
  if d == "." { if not contains(S.entry, ".") { S.entry = S.entry + "." } }
  else if S.entry == "0" { S.entry = d }
  else if S.entry == "-0" { S.entry = "-" + d }
  else { S.entry = S.entry + d }
  s_show()
}
fn s_set_value(v) { S.entry = calc_plain(v); S.fresh = true }
fn s_operator(o) {
  if S.err != "" { s_reset() }
  if S.acc != nil and S.op != "" and not S.fresh {
    let r = apply_op(S.acc, S.op, entry_num())
    if not r.ok { s_error(r.e); return }
    S.acc = r.v
  } else if S.acc == nil or S.op == "" {
    S.acc = entry_num()
  }
  S.op = o
  S.expr = calc_fmt(S.acc) + " " + op_sym(o)
  s_set_value(S.acc)
  s_show()
}
fn s_equals() {
  if S.err != "" { s_reset(); s_show(); return }
  if S.op != "" {
    let b = entry_num()
    let r = apply_op(S.acc, S.op, b)
    let txt = calc_fmt(S.acc) + " " + op_sym(S.op) + " " + calc_fmt(b) + " ="
    if not r.ok { S.expr = txt; s_error(r.e); settext(expr_l, txt); return }
    S.last_op = S.op
    S.last_b = b
    S.expr = txt
    S.acc = nil
    S.op = ""
    s_set_value(r.v)
    add_history(txt, calc_fmt(r.v))
  } else if S.last_op != "" {
    let a = entry_num()
    let r = apply_op(a, S.last_op, S.last_b)
    let txt = calc_fmt(a) + " " + op_sym(S.last_op) + " " + calc_fmt(S.last_b) + " ="
    if not r.ok { s_error(r.e); return }
    S.expr = txt
    s_set_value(r.v)
    add_history(txt, calc_fmt(r.v))
  } else {
    S.expr = calc_fmt(entry_num()) + " ="
    S.fresh = true
  }
  s_show()
}
fn s_unary(kind) {
  if S.err != "" { s_reset() }
  let x = entry_num()
  let v = 0
  let label_ = ""
  if kind == "inv" { if x == 0 { s_error("Cannot divide by zero"); return }; v = 1 / x; label_ = "1/(" + calc_fmt(x) + ")" }
  else if kind == "sqr" { v = x * x; label_ = "sqr(" + calc_fmt(x) + ")" }
  else if kind == "sqrt" { if x < 0 { s_error("Invalid input"); return }; v = sqrt(x); label_ = "√(" + calc_fmt(x) + ")" }
  else if kind == "pct" {
    if S.acc != nil and (S.op == "+" or S.op == "-") { v = S.acc * x / 100 } else { v = x / 100 }
    label_ = calc_fmt(v)
  }
  else if kind == "neg" {
    if S.fresh and S.entry == "0" { return }
    if startswith(S.entry, "-") { S.entry = slice(S.entry, 1) } else { S.entry = "-" + S.entry }
    s_show()
    return
  }
  if S.op != "" { S.expr = calc_fmt(S.acc) + " " + op_sym(S.op) + " " + label_ } else { S.expr = label_ }
  s_set_value(v)
  S.fresh = true
  if S.op != "" { S.fresh = false }
  s_show()
}
fn s_back() {
  if S.err != "" { s_reset(); s_show(); return }
  if S.fresh { if S.op == "" { S.expr = "" }; s_show(); return }
  S.entry = slice(S.entry, 0, len(S.entry) - 1)
  if S.entry == "" or S.entry == "-" { S.entry = "0" }
  s_show()
}
fn s_ce() { S.entry = "0"; S.err = ""; S.fresh = false; s_show() }
fn s_c() { s_reset(); s_show() }

# ---------------------------------------------------------------- Scientific mode (whole expression, precedence)
let X = {text: "", second: false, fe: false, last: nil, done: false}
fn x_show() {
  if X.text == "" { set_display("0") } else { set_display(X.text) }
  let r = calc_eval(X.text, {angle: angle, ans: X.last})
  if X.done { return }
  if X.text != "" and r.ok { settext(expr_l, "= " + x_fmt(r.value)) } else { settext(expr_l, "") }
}
fn x_fmt(v) {
  if X.fe {
    let s = calc_plain(v)
    if contains(s, "e") { return s }
    if v == 0 { return "0.e+0" }
    let e = floor(log(abs(v), 10))
    return calc_plain(v / pow(10, e)) + "e" + (e < 0 and "-" or "+") + calc_int_str(abs(e))
  }
  return calc_fmt(v)
}
fn x_put(t) {
  if X.done {
    let ops = ["+", "−", "×", "÷", "^", "!", "%", " mod "]
    if contains(ops, t) { X.text = "ans" } else { X.text = "" }
    X.done = false
  }
  X.text = X.text + t
  x_show()
}
fn x_equals() {
  if X.text == "" { return }
  let r = calc_eval(X.text, {angle: angle, ans: X.last})
  if not r.ok { settext(expr_l, X.text + " ="); set_display(r.error); X.done = true; X.text = ""; return }
  let shown = replace(X.text, "ans", calc_plain(X.last or 0))
  settext(expr_l, shown + " =")
  X.last = r.value
  set_display(x_fmt(r.value))
  add_history(shown + " =", x_fmt(r.value))
  X.text = calc_plain(r.value)
  X.done = true
}
fn x_back() {
  if X.done { X.text = ""; X.done = false; x_show(); return }
  let fns = ["asinh(", "acosh(", "atanh(", "asin(", "acos(", "atan(", "sinh(", "cosh(", "tanh(", "sin(", "cos(", "tan(", "sqrt(", "cbrt(", "log2(", "log(", "ln(", "abs(", "fact(", "exp(", " mod ", "pi", "ans"]
  for f in fns { if endswith(X.text, f) { X.text = slice(X.text, 0, len(X.text) - len(f)); x_show(); return } }
  X.text = slice(X.text, 0, len(X.text) - 1)
  x_show()
}
fn x_wrap(pre, post) {
  if X.text == "" { X.text = "0" }
  X.text = pre + "(" + X.text + ")" + post
  X.done = false
  x_show()
}

# ---------------------------------------------------------------- Programmer mode (integers, two's complement)
let P = {acc: nil, op: "", v: 0, fresh: true, base: 10, bits: 32, expr: ""}
fn p_mod() { return pow(2, P.bits) }
fn p_wrap(v) { let m = p_mod(); v = floor(v); v = v - m * floor(v / m); return v }   # 0 .. 2^bits-1
fn p_signed(u) { if u >= p_mod() / 2 { return u - p_mod() }; return u }
fn p_bits_of(u) { let out = []; for i in range(P.bits) { push(out, u % 2); u = floor(u / 2) }; return out }
fn p_from_bits(b) { let v = 0; let k = 1; for x in b { v += x * k; k *= 2 }; return v }
fn p_bitop(a, b, f) {
  let x = p_bits_of(p_wrap(a))
  let y = p_bits_of(p_wrap(b))
  let r = []
  for i in range(P.bits) { push(r, f(x[i], y[i])) }
  return p_from_bits(r)
}
fn p_to_base(u, base) {
  if u == 0 { return "0" }
  let digs = "0123456789ABCDEF"
  let out = ""
  while u > 0 { let d = u % base; out = digs[d] + out; u = floor(u / base) }
  return out
}
fn p_group(s, n) {
  let out = ""
  let k = len(s)
  for i in range(k) { if i > 0 and (k - i) % n == 0 { out = out + " " }; out = out + s[i] }
  return out
}
fn p_text(u, base) {
  if base == 10 { let sv = p_signed(u); if sv < 0 { return "-" + calc_group(calc_int_str(0 - sv)) }; return calc_group(calc_int_str(sv)) }
  if base == 2 { return p_group(p_to_base(u, 2), 4) }
  if base == 16 { return p_group(p_to_base(u, 16), 4) }
  return p_group(p_to_base(u, 8), 3)
}
fn p_apply(a, o, b) {
  if o == "+" { return {ok: true, v: a + b} }
  if o == "-" { return {ok: true, v: a - b} }
  if o == "*" { return {ok: true, v: p_signed(p_wrap(a)) * p_signed(p_wrap(b))} }
  if o == "/" { if p_signed(p_wrap(b)) == 0 { return {ok: false, e: "Cannot divide by zero"} }; let q = p_signed(p_wrap(a)) / p_signed(p_wrap(b)); if q < 0 { q = ceil(q) } else { q = floor(q) }; return {ok: true, v: q} }
  if o == "mod" { let bb = p_signed(p_wrap(b)); if bb == 0 { return {ok: false, e: "Cannot divide by zero"} }; let aa = p_signed(p_wrap(a)); let q = aa / bb; if q < 0 { q = ceil(q) } else { q = floor(q) }; return {ok: true, v: aa - q * bb} }
  if o == "and" { return {ok: true, v: p_bitop(a, b, fn(x, y) { return x * y })} }
  if o == "or" { return {ok: true, v: p_bitop(a, b, fn(x, y) { if x + y > 0 { return 1 }; return 0 })} }
  if o == "xor" { return {ok: true, v: p_bitop(a, b, fn(x, y) { return (x + y) % 2 })} }
  if o == "lsh" { return {ok: true, v: p_wrap(a) * pow(2, clamp(b, 0, 64))} }
  if o == "rsh" { return {ok: true, v: floor(p_signed(p_wrap(a)) / pow(2, clamp(b, 0, 64)))} }
  return {ok: true, v: b}
}
let P_SYM = {"+": "+", "-": "−", "*": "×", "/": "÷", mod: "%", and: "AND", or: "OR", xor: "XOR", lsh: "<<", rsh: ">>"}
fn p_digit(d) {
  let val = indexof("0123456789ABCDEF", upper(d))
  if val < 0 or val >= P.base { return }
  if P.fresh { P.v = 0; P.fresh = false }
  let nv = P.v * P.base + val
  if p_signed(p_wrap(nv)) != nv and nv >= p_mod() { return }
  P.v = p_wrap(nv)
  p_show()
}
fn p_operator(o) {
  if P.acc != nil and P.op != "" and not P.fresh {
    let r = p_apply(P.acc, P.op, P.v)
    if not r.ok { set_display(r.e); P.acc = nil; P.op = ""; return }
    P.acc = p_wrap(r.v)
  } else if P.acc == nil or P.op == "" { P.acc = P.v }
  P.op = o
  P.expr = p_text(P.acc, P.base) + " " + P_SYM[o]
  P.v = P.acc
  P.fresh = true
  p_show()
}
fn p_equals() {
  if P.op == "" { return }
  let r = p_apply(P.acc, P.op, P.v)
  let txt = p_text(P.acc, P.base) + " " + P_SYM[P.op] + " " + p_text(P.v, P.base) + " ="
  if not r.ok { settext(expr_l, txt); set_display(r.e); P.acc = nil; P.op = ""; P.fresh = true; return }
  P.v = p_wrap(r.v)
  P.expr = txt
  P.acc = nil
  P.op = ""
  P.fresh = true
  add_history(txt, p_text(P.v, P.base))
  p_show()
}
let base_rows = {}
fn p_show() {
  set_display(p_text(P.v, P.base))
  settext(expr_l, P.expr)
  for k in keys(base_rows) { settext(base_rows[k], p_text(P.v, num(k))) }
}

# ---------------------------------------------------------------- memory
fn current_value() {
  if mode == "Standard" { return entry_num() }
  if mode == "Scientific" { let r = calc_eval(X.text, {angle: angle, ans: X.last}); if r.ok { return r.value }; return 0 }
  if mode == "Programmer" { return p_signed(P.v) }
  return 0
}
fn recall(v) {
  if mode == "Standard" { s_set_value(v); S.fresh = false; s_show() }
  else if mode == "Scientific" { x_put(calc_plain(v)) }
  else if mode == "Programmer" { P.v = p_wrap(v); P.fresh = true; p_show() }
}
fn mem_do(k) {
  let v = current_value()
  if k == "MS" { insert(memory, 0, v) }
  else if k == "MC" { memory = [] }
  else if k == "MR" { if len(memory) > 0 { recall(memory[0]) } }
  else if k == "M+" { if len(memory) == 0 { push(memory, v) } else { memory[0] = memory[0] + v } }
  else if k == "M-" { if len(memory) == 0 { push(memory, 0 - v) } else { memory[0] = memory[0] - v } }
  save_all()
  mem_refresh()
  draw_side()
  if mode == "Standard" { S.fresh = true }
}
let mem_btns = []
fn mem_refresh() { for b in mem_btns { togglestyle(b, "off", len(memory) == 0) } }
fn mem_row(parent) {
  let r = row(parent, "kcalc-mem")
  mem_btns = []
  for k in ["MC", "MR", "M+", "M-", "MS"] { let kk = k; let b = button(r, replace(k, "-", "−"), fn() { mem_do(kk) }, "kcalc-m"); if k == "MC" or k == "MR" { push(mem_btns, b) } }
  mem_refresh()
}

# ---------------------------------------------------------------- side panel: history / memory
let side_tab = "History"
fn draw_side() {
  mem_refresh()
  clear(side)
  let tabs = row(side, "kcalc-tabs")
  for t in ["History", "Memory"] { let tt = t; let b = button(tabs, t, fn() { side_tab = tt; draw_side() }, "kcalc-tab"); togglestyle(b, "on", side_tab == t) }
  let list_ = col(side, "kcalc-list")
  if side_tab == "History" {
    if len(history) == 0 { label(list_, "There's no history yet", "kcalc-empty") }
    for h in history {
      let hh = h
      let it = col(list_, "kcalc-hitem")
      label(it, h.e, "kcalc-he")
      label(it, h.r, "kcalc-hr")
      on_click(it, fn() { let v = num(replace(hh.r, ",", "")); if v != nil and mode != "Programmer" { recall(v) } })
    }
    if len(history) > 0 { button(side, "🗑 Clear history", fn() { history = []; save_all(); draw_side() }, "kcalc-clear") }
  } else {
    if len(memory) == 0 { label(list_, "There's nothing saved in memory", "kcalc-empty") }
    let i = 0
    for m in memory {
      let idx = i
      let it = col(list_, "kcalc-hitem")
      label(it, calc_fmt(m), "kcalc-hr")
      let acts = row(it, "kcalc-macts")
      button(acts, "MC", fn() { remove(memory, idx); save_all(); draw_side() }, "kcalc-m")
      button(acts, "M+", fn() { memory[idx] = memory[idx] + current_value(); save_all(); draw_side() }, "kcalc-m")
      button(acts, "M−", fn() { memory[idx] = memory[idx] - current_value(); save_all(); draw_side() }, "kcalc-m")
      on_click(label(it, "Use", "kcalc-use"), fn() { recall(memory[idx]) })
      i += 1
    }
    if len(memory) > 0 { button(side, "🗑 Clear memory", fn() { memory = []; save_all(); draw_side() }, "kcalc-clear") }
  }
}

# ---------------------------------------------------------------- keypads
fn display_block() {
  expr_l = label(left, "", "kcalc-expr")
  disp_l = label(left, "0", "kcalc-disp")
}
fn pad_standard() {
  display_block()
  mem_row(left)
  let g = col(left, "kcalc-keys")
  let rows = [
    [["%", "fn", fn() { s_unary("pct") }], ["CE", "fn", fn() { s_ce() }], ["C", "fn", fn() { s_c() }], ["⌫", "fn", fn() { s_back() }]],
    [["¹/ₓ", "fn", fn() { s_unary("inv") }], ["x²", "fn", fn() { s_unary("sqr") }], ["²√x", "fn", fn() { s_unary("sqrt") }], ["÷", "fn", fn() { s_operator("/") }]],
    [["7", "num", fn() { s_digit("7") }], ["8", "num", fn() { s_digit("8") }], ["9", "num", fn() { s_digit("9") }], ["×", "fn", fn() { s_operator("*") }]],
    [["4", "num", fn() { s_digit("4") }], ["5", "num", fn() { s_digit("5") }], ["6", "num", fn() { s_digit("6") }], ["−", "fn", fn() { s_operator("-") }]],
    [["1", "num", fn() { s_digit("1") }], ["2", "num", fn() { s_digit("2") }], ["3", "num", fn() { s_digit("3") }], ["+", "fn", fn() { s_operator("+") }]],
    [["+/−", "num", fn() { s_unary("neg") }], ["0", "num", fn() { s_digit("0") }], [".", "num", fn() { s_digit(".") }], ["=", "eq", fn() { s_equals() }]]
  ]
  for r in rows { let rr = row(g, "kcalc-krow"); for k in r { key(rr, k[0], k[2], k[1]) } }
  s_show()
}
let sci_trig = nil
fn pad_scientific() {
  display_block()
  let opts = row(left, "kcalc-opts")
  let ab = nil
  ab = button(opts, upper(angle), fn() { if angle == "deg" { angle = "rad" } else if angle == "rad" { angle = "grad" } else { angle = "deg" }; settext(ab, upper(angle)); save_all(); x_show() }, "kcalc-m")
  settip(ab, "Angle unit: degrees, radians or gradians")
  let fe = nil
  fe = button(opts, "F-E", fn() { X.fe = not X.fe; togglestyle(fe, "on", X.fe); x_show() }, "kcalc-m")
  settip(fe, "Scientific notation")
  mem_row(left)
  sci_trig = row(left, "kcalc-trig")
  let g = col(left, "kcalc-keys sci")
  fn draw_keys() {
    clear(sci_trig)
    clear(g)
    let s2 = X.second
    let trig = [["sin", "asin"], ["cos", "acos"], ["tan", "atan"], ["sinh", "asinh"], ["cosh", "acosh"], ["tanh", "atanh"]]
    for t in trig { let name = t[0]; if s2 { name = t[1] }; let nn = name; button(sci_trig, nn, fn() { x_put(nn + "(") }, "kcalc-m") }
    let rows = [
      [["2ⁿᵈ", "fn", fn() { X.second = not X.second; draw_keys() }], ["π", "fn", fn() { x_put("π") }], ["e", "fn", fn() { x_put("e") }], ["C", "fn", fn() { X.text = ""; X.done = false; x_show(); settext(expr_l, "") }], ["⌫", "fn", fn() { x_back() }]],
      [[s2 and "x³" or "x²", "fn", fn() { if X.second { x_put("³") } else { x_put("²") } }], ["¹/ₓ", "fn", fn() { x_wrap("1/", "") }], ["|x|", "fn", fn() { x_wrap("abs", "") }], ["exp", "fn", fn() { x_put("e^") }], ["mod", "fn", fn() { x_put(" mod ") }]],
      [[s2 and "³√x" or "²√x", "fn", fn() { if X.second { x_put("cbrt(") } else { x_put("√(") } }], ["(", "fn", fn() { x_put("(") }], [")", "fn", fn() { x_put(")") }], ["n!", "fn", fn() { x_put("!") }], ["÷", "fn", fn() { x_put("÷") }]],
      [[s2 and "ʸ√x" or "xʸ", "fn", fn() { if X.second { x_put("^(1/") } else { x_put("^") } }], ["7", "num", fn() { x_put("7") }], ["8", "num", fn() { x_put("8") }], ["9", "num", fn() { x_put("9") }], ["×", "fn", fn() { x_put("×") }]],
      [[s2 and "2ˣ" or "10ˣ", "fn", fn() { if X.second { x_put("2^") } else { x_put("10^") } }], ["4", "num", fn() { x_put("4") }], ["5", "num", fn() { x_put("5") }], ["6", "num", fn() { x_put("6") }], ["−", "fn", fn() { x_put("−") }]],
      [[s2 and "log₂" or "log", "fn", fn() { if X.second { x_put("log2(") } else { x_put("log(") } }], ["1", "num", fn() { x_put("1") }], ["2", "num", fn() { x_put("2") }], ["3", "num", fn() { x_put("3") }], ["+", "fn", fn() { x_put("+") }]],
      [[s2 and "eˣ" or "ln", "fn", fn() { if X.second { x_put("e^") } else { x_put("ln(") } }], ["+/−", "num", fn() { x_wrap("-", "") }], ["0", "num", fn() { x_put("0") }], [".", "num", fn() { x_put(".") }], ["=", "eq", fn() { x_equals() }]]
    ]
    for r in rows { let rr = row(g, "kcalc-krow"); for k in r { let b = key(rr, k[0], k[2], k[1]); if k[0] == "2ⁿᵈ" { togglestyle(b, "on", X.second) } } }
  }
  draw_keys()
  x_show()
}
fn pad_programmer() {
  display_block()
  base_rows = {}
  let bases = col(left, "kcalc-bases")
  for b in [[16, "HEX"], [10, "DEC"], [8, "OCT"], [2, "BIN"]] {
    let bb = b[0]
    let r = row(bases, "kcalc-base")
    togglestyle(r, "on", P.base == bb)
    label(r, b[1], "kcalc-bname")
    base_rows[str(bb)] = label(r, "0", "kcalc-bval")
    on_click(r, fn() { P.base = bb; draw_mode() })
  }
  let opts = row(left, "kcalc-opts")
  let ws = nil
  ws = button(opts, {"8": "BYTE", "16": "WORD", "32": "DWORD"}[str(P.bits)], fn() {
    if P.bits == 32 { P.bits = 16 } else if P.bits == 16 { P.bits = 8 } else { P.bits = 32 }
    P.v = p_wrap(P.v)
    draw_mode()
  }, "kcalc-m")
  settip(ws, "Word size (32, 16 or 8 bit)")
  let g = col(left, "kcalc-keys sci")
  let rows = [
    [["A", "num", fn() { p_digit("A") }], ["«", "fn", fn() { p_operator("lsh") }], ["»", "fn", fn() { p_operator("rsh") }], ["C", "fn", fn() { P.v = 0; P.acc = nil; P.op = ""; P.expr = ""; p_show() }], ["⌫", "fn", fn() { P.v = floor(P.v / P.base); p_show() }]],
    [["B", "num", fn() { p_digit("B") }], ["AND", "fn", fn() { p_operator("and") }], ["OR", "fn", fn() { p_operator("or") }], ["XOR", "fn", fn() { p_operator("xor") }], ["÷", "fn", fn() { p_operator("/") }]],
    [["C", "num", fn() { p_digit("C") }], ["7", "num", fn() { p_digit("7") }], ["8", "num", fn() { p_digit("8") }], ["9", "num", fn() { p_digit("9") }], ["×", "fn", fn() { p_operator("*") }]],
    [["D", "num", fn() { p_digit("D") }], ["4", "num", fn() { p_digit("4") }], ["5", "num", fn() { p_digit("5") }], ["6", "num", fn() { p_digit("6") }], ["−", "fn", fn() { p_operator("-") }]],
    [["E", "num", fn() { p_digit("E") }], ["1", "num", fn() { p_digit("1") }], ["2", "num", fn() { p_digit("2") }], ["3", "num", fn() { p_digit("3") }], ["+", "fn", fn() { p_operator("+") }]],
    [["F", "num", fn() { p_digit("F") }], ["NOT", "fn", fn() { P.v = p_bitop(P.v, 0, fn(x, y) { return 1 - x }); P.fresh = true; p_show() }], ["0", "num", fn() { p_digit("0") }], ["%", "fn", fn() { p_operator("mod") }], ["=", "eq", fn() { p_equals() }]]
  ]
  for r in rows {
    let rr = row(g, "kcalc-krow")
    for k in r {
      let b = key(rr, k[0], k[2], k[1])
      let dv = indexof("0123456789ABCDEF", k[0])
      if k[1] == "num" and len(k[0]) == 1 and dv >= P.base { addstyle(b, "off"); enable(b, false) }
    }
  }
  p_show()
}

# ---------------------------------------------------------------- Date calculation (proleptic Gregorian, days from 1970-01-01)
fn days_from_civil(y, m, d) {
  if m <= 2 { y -= 1 }
  let era = floor(y / 400)
  let yoe = y - era * 400
  let mp = (m + 9) % 12
  let doy = floor((153 * mp + 2) / 5) + d - 1
  let doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
fn civil_from_days(z) {
  z += 719468
  let era = floor(z / 146097)
  let doe = z - era * 146097
  let yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  let mp = floor((5 * doy + 2) / 153)
  let d = doy - floor((153 * mp + 2) / 5) + 1
  let m = mp + 3
  if m > 12 { m -= 12 }
  if m <= 2 { y += 1 }
  return {y: y, m: m, d: d}
}
let MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
let WEEKDAYS = ["Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday"]
fn date_text(z) { let c = civil_from_days(z); return WEEKDAYS[((z % 7) + 7) % 7] + ", " + MONTHS[c.m - 1] + " " + str(c.d) + ", " + str(c.y) }
fn iso(z) { let c = civil_from_days(z); let mm = str(c.m); let dd = str(c.d); if c.m < 10 { mm = "0" + mm }; if c.d < 10 { dd = "0" + dd }; return str(c.y) + "-" + mm + "-" + dd }
fn parse_date(t) {
  let p = split(trim(t), "-")
  if len(p) != 3 { return nil }
  let y = num(p[0])
  let m = num(p[1])
  let d = num(p[2])
  if y == nil or m == nil or d == nil or m < 1 or m > 12 or d < 1 or d > 31 { return nil }
  let z = days_from_civil(y, m, d)
  if iso(z) != str(y) + "-" + slice("0" + str(m), -2) + "-" + slice("0" + str(d), -2) { return nil }
  return z
}
fn today() { return floor(time() / 86400000) }
fn pad_date() {
  let c = col(left, "kcalc-form")
  label(c, "Difference between dates", "kcalc-sec")
  label(c, "From (YYYY-MM-DD)", "kcalc-lbl")
  let a = textbox(c, "YYYY-MM-DD", nil, "kcalc-in")
  settext(a, iso(today()))
  label(c, "To", "kcalc-lbl")
  let b = textbox(c, "YYYY-MM-DD", nil, "kcalc-in")
  settext(b, iso(today() + 30))
  let res = label(c, "", "kcalc-result")
  let res2 = label(c, "", "kcalc-lbl")
  fn diff() {
    let za = parse_date(gettext(a))
    let zb = parse_date(gettext(b))
    if za == nil or zb == nil { settext(res, "Enter dates like 2026-11-19"); settext(res2, ""); return }
    let n = abs(zb - za)
    let w = floor(n / 7)
    let dd = n - w * 7
    let ca = civil_from_days(min(za, zb))
    let cb = civil_from_days(max(za, zb))
    let months = (cb.y - ca.y) * 12 + (cb.m - ca.m)
    if cb.d < ca.d { months -= 1 }
    let yrs = floor(months / 12)
    let mo = months - yrs * 12
    if n == 0 { settext(res, "Same dates") } else if n == 1 { settext(res, "1 day") } else { settext(res, str(n) + " days") }
    fn pl(n, word) { if n == 1 { return "1 " + word }; return str(n) + " " + word + "s" }
    let parts = []
    if yrs != 0 { push(parts, pl(yrs, "year")) }
    if mo != 0 { push(parts, pl(mo, "month")) }
    let wk = []
    if w != 0 { push(wk, pl(w, "week")) }
    if dd != 0 or len(wk) == 0 { push(wk, pl(dd, "day")) }
    if len(parts) == 0 { settext(res2, join(wk, ", ")) } else { settext(res2, join(parts, ", ") + " · " + join(wk, ", ")) }
  }
  on_input(a, fn(t) { diff() }, 200)
  on_input(b, fn(t) { diff() }, 200)
  diff()
  label(c, "Add or subtract days", "kcalc-sec")
  label(c, "Start date", "kcalc-lbl")
  let s = textbox(c, "YYYY-MM-DD", nil, "kcalc-in")
  settext(s, iso(today()))
  label(c, "Days (negative subtracts)", "kcalc-lbl")
  let n = textbox(c, "e.g. 100", nil, "kcalc-in")
  settext(n, "100")
  let res3 = label(c, "", "kcalc-result")
  fn addd() {
    let z = parse_date(gettext(s))
    let k = num(trim(gettext(n)))
    if z == nil or k == nil { settext(res3, "Enter a date and a number of days"); return }
    settext(res3, date_text(z + round(k)))
  }
  on_input(s, fn(t) { addd() }, 200)
  on_input(n, fn(t) { addd() }, 200)
  addd()
}

# ---------------------------------------------------------------- converters (factor to a base unit; temperature is special)
let CONV = {
  Length: [["Millimeters", 0.001], ["Centimeters", 0.01], ["Meters", 1], ["Kilometers", 1000], ["Inches", 0.0254], ["Feet", 0.3048], ["Yards", 0.9144], ["Miles", 1609.344], ["Nautical miles", 1852]],
  "Weight and mass": [["Milligrams", 0.000001], ["Grams", 0.001], ["Kilograms", 1], ["Metric tonnes", 1000], ["Ounces", 0.028349523125], ["Pounds", 0.45359237], ["Stone", 6.35029318], ["US tons", 907.18474]],
  Temperature: [["Celsius", 0], ["Fahrenheit", 0], ["Kelvin", 0]],
  Volume: [["Milliliters", 0.001], ["Liters", 1], ["Cubic meters", 1000], ["Teaspoons (US)", 0.00492892159375], ["Tablespoons (US)", 0.01478676478125], ["Fluid ounces (US)", 0.0295735295625], ["Cups (US)", 0.2365882365], ["Pints (US)", 0.473176473], ["Quarts (US)", 0.946352946], ["Gallons (US)", 3.785411784], ["Gallons (UK)", 4.54609]],
  Area: [["Square centimeters", 0.0001], ["Square meters", 1], ["Hectares", 10000], ["Square kilometers", 1000000], ["Square inches", 0.00064516], ["Square feet", 0.09290304], ["Square yards", 0.83612736], ["Acres", 4046.8564224], ["Square miles", 2589988.110336]],
  Speed: [["Meters per second", 1], ["Kilometers per hour", 0.2777777777777778], ["Miles per hour", 0.44704], ["Feet per second", 0.3048], ["Knots", 0.5144444444444445]],
  Time: [["Milliseconds", 0.001], ["Seconds", 1], ["Minutes", 60], ["Hours", 3600], ["Days", 86400], ["Weeks", 604800], ["Years (365 d)", 31536000]],
  Data: [["Bits", 0.125], ["Bytes", 1], ["Kilobytes", 1000], ["Kibibytes", 1024], ["Megabytes", 1000000], ["Mebibytes", 1048576], ["Gigabytes", 1000000000], ["Gibibytes", 1073741824], ["Terabytes", 1000000000000]],
  Energy: [["Joules", 1], ["Kilojoules", 1000], ["Calories", 4.184], ["Kilocalories", 4184], ["Watt-hours", 3600], ["Kilowatt-hours", 3600000], ["BTU", 1055.05585262]],
  Pressure: [["Pascals", 1], ["Kilopascals", 1000], ["Bar", 100000], ["Atmospheres", 101325], ["PSI", 6894.757293168], ["mmHg", 133.322387415]]
}
fn to_base_t(u, v) { if u == "Celsius" { return v }; if u == "Fahrenheit" { return (v - 32) * 5 / 9 }; return v - 273.15 }
fn from_base_t(u, c) { if u == "Celsius" { return c }; if u == "Fahrenheit" { return c * 9 / 5 + 32 }; return c + 273.15 }
fn convert(cat, from, to, v) {
  if cat == "Temperature" { return from_base_t(to, to_base_t(from, v)) }
  let f = 0
  let t = 0
  for u in CONV[cat] { if u[0] == from { f = u[1] }; if u[0] == to { t = u[1] } }
  return v * f / t
}
fn pad_converter(cat) {
  let units = map(CONV[cat], fn(u) { return u[0] })
  let c = col(left, "kcalc-form")
  label(c, cat, "kcalc-sec")
  let a = textbox(c, "0", nil, "kcalc-in big")
  settext(a, "1")
  let ua = dropdown(c, units, fn(x) { upd() }, "kcalc-dd")
  let swap = button(c, "⇅ Swap", fn() { let t = getvalue(ua); setvalue(ua, getvalue(ub)); setvalue(ub, t); upd() }, "kcalc-m")
  let out = label(c, "", "kcalc-result big")
  let ub = dropdown(c, units, fn(x) { upd() }, "kcalc-dd")
  setvalue(ub, units[min(2, len(units) - 1)])
  if cat == "Temperature" { setvalue(ub, "Fahrenheit") }
  let more = label(c, "", "kcalc-lbl")
  fn upd() {
    let r = calc_eval(gettext(a), {angle: angle})
    if not r.ok { settext(out, "—"); settext(more, r.error); return }
    let v = convert(cat, getvalue(ua), getvalue(ub), r.value)
    settext(out, calc_fmt(v))
    settext(more, calc_fmt(r.value) + " " + getvalue(ua) + " = " + calc_fmt(v) + " " + getvalue(ub))
  }
  on_input(a, fn(t) { upd() }, 120)
  upd()
}

# ---------------------------------------------------------------- navigation + header
let MODES = [["Calculator", ""], ["Standard", "▦"], ["Scientific", "∫"], ["Programmer", "</>"], ["Date calculation", "📅"],
  ["Converter", ""], ["Length", "📏"], ["Weight and mass", "⚖"], ["Temperature", "🌡"], ["Volume", "🧪"], ["Area", "▭"], ["Speed", "🏎"], ["Time", "⏱"], ["Data", "💾"], ["Energy", "⚡"], ["Pressure", "🎈"]]
let nav_open = false
fn draw_head() {
  clear(head)
  let hb = button(head, "☰", fn() { nav_open = not nav_open; draw_nav() }, "kcalc-ham")
  settip(hb, "Open navigation")
  label(head, mode, "kcalc-title")
  let sp = box(head, "kcalc-space")
  let tb = button(head, theme == "dark" and "☀" or "🌙", fn() { if theme == "dark" { theme = "light" } else { theme = "dark" }; save_all(); apply_theme(); draw_head() }, "kcalc-ham")
  settip(tb, "Light / dark theme")
  let hs = button(head, "🕘", fn() { togglestyle(side, "shown"); }, "kcalc-ham kcalc-histbtn")
  settip(hs, "History and memory")
}
fn draw_nav() {
  if nav != nil { destroy(nav); nav = nil }
  if not nav_open { return }
  nav = col(root, "kcalc-nav")
  for m in MODES {
    let mm = m[0]
    if m[1] == "" { label(nav, mm, "kcalc-navsec"); continue }
    let b = button(nav, "", fn() { mode = mm; nav_open = false; save_all(); draw_nav(); draw_mode() }, "kcalc-navitem")
    label(b, m[1], "kcalc-navico")
    label(b, mm, "")
    togglestyle(b, "on", mode == mm)
  }
  label(nav, "Everything stays on this PC.", "kcalc-navnote")
}
fn draw_mode() {
  clear(left)
  draw_head()
  expr_l = nil
  disp_l = nil
  show(side, mode == "Standard" or mode == "Scientific" or mode == "Programmer")
  if mode == "Standard" { pad_standard() }
  else if mode == "Scientific" { pad_scientific() }
  else if mode == "Programmer" { pad_programmer() }
  else if mode == "Date calculation" { pad_date() }
  else { if CONV[mode] == nil { mode = "Standard"; draw_mode(); return }; pad_converter(mode) }
}

# ---------------------------------------------------------------- keyboard
on_keypress(fn(k) {
  if nav_open and k == "escape" { nav_open = false; draw_nav(); return }
  if mode == "Standard" {
    if contains("0123456789.", k) and len(k) == 1 { s_digit(k) }
    else if k == "+" or k == "-" or k == "*" or k == "/" { s_operator(k) }
    else if k == "enter" or k == "=" { s_equals() }
    else if k == "backspace" { s_back() }
    else if k == "escape" { s_c() }
    else if k == "delete" { s_ce() }
    else if k == "%" { s_unary("pct") }
    else if k == "r" { s_unary("inv") }
    else if k == "@" { s_unary("sqrt") }
    else if k == "q" { s_unary("sqr") }
    else if k == "f9" { s_unary("neg") }
  } else if mode == "Scientific" {
    let map_ = {"*": "×", "/": "÷", "-": "−"}
    if len(k) == 1 and contains("0123456789.+()^!%", k) { x_put(k) }
    else if len(k) == 1 and has(map_, k) { x_put(map_[k]) }
    else if k == "p" { x_put("π") }
    else if k == "s" { x_put("sin(") }
    else if k == "o" { x_put("cos(") }
    else if k == "t" { x_put("tan(") }
    else if k == "l" { x_put("log(") }
    else if k == "n" { x_put("ln(") }
    else if k == "enter" or k == "=" { x_equals() }
    else if k == "backspace" { x_back() }
    else if k == "escape" { X.text = ""; X.done = false; x_show(); settext(expr_l, "") }
  } else if mode == "Programmer" {
    if len(k) == 1 and contains("0123456789abcdef", k) { p_digit(k) }
    else if k == "+" or k == "-" or k == "*" or k == "/" { p_operator(k) }
    else if k == "%" { p_operator("mod") }
    else if k == "&" { p_operator("and") }
    else if k == "|" { p_operator("or") }
    else if k == "^" { p_operator("xor") }
    else if k == "<" { p_operator("lsh") }
    else if k == ">" { p_operator("rsh") }
    else if k == "enter" or k == "=" { p_equals() }
    else if k == "backspace" { P.v = floor(P.v / P.base); p_show() }
    else if k == "escape" { P.v = 0; P.acc = nil; P.op = ""; P.expr = ""; p_show() }
  }
})

apply_theme()
draw_side()
draw_mode()
