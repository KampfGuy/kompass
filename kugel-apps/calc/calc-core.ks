# ---------------------------------------------------------------- calculator core (shared by Kugel Arithmetricks
# and the game Arithmetricks Premium): a safe expression evaluator (tokenizer + recursive-descent parser, it
# never runs code) and number formatting. calc_eval(text, opts) -> {ok, value, error}
let CALC_FUNCS = ["sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
  "sqrt", "cbrt", "ln", "log", "log2", "exp", "abs", "floor", "ceil", "round", "fact", "sec", "csc", "cot", "neg"]

fn calc_is_digit(c) { return c >= "0" and c <= "9" }
fn calc_is_alpha(c) { return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") }

fn calc_tokens(src) {
  let s = replace(replace(replace(replace(replace(src, "×", "*"), "÷", "/"), "−", "-"), "π", " pi "), "√", " sqrt ")
  s = replace(replace(replace(s, "²", "^2"), "³", "^3"), ",", "")
  s = replace(s, "mod", " mod ")
  let out = []
  let i = 0
  let n = len(s)
  while i < n {
    let c = s[i]
    if c == " " { i += 1; continue }
    if calc_is_digit(c) or c == "." {
      let j = i
      let dots = 0
      while j < n and (calc_is_digit(s[j]) or s[j] == ".") { if s[j] == "." { dots += 1 }; j += 1 }
      if j < n and (s[j] == "e" or s[j] == "E") and j + 1 < n and (calc_is_digit(s[j + 1]) or ((s[j + 1] == "-" or s[j + 1] == "+") and j + 2 < n and calc_is_digit(s[j + 2]))) {
        j += 2
        while j < n and calc_is_digit(s[j]) { j += 1 }
      }
      let t = slice(s, i, j)
      if dots > 1 or num(t) == nil { return {ok: false, error: "Invalid number " + t} }
      push(out, {k: "n", v: num(t)})
      i = j
      continue
    }
    if calc_is_alpha(c) {
      let j = i
      while j < n and (calc_is_alpha(s[j]) or calc_is_digit(s[j])) { j += 1 }
      push(out, {k: "id", v: lower(slice(s, i, j))})
      i = j
      continue
    }
    if contains("+-*/^()!%", c) { push(out, {k: "op", v: c}); i += 1; continue }
    return {ok: false, error: "Unexpected \"" + c + "\""}
  }
  return {ok: true, list: out}
}

fn calc_fact(n) {
  if n < 0 or n != floor(n) or n > 170 { return nil }
  let r = 1
  let i = 2
  while i <= n { r *= i; i += 1 }
  return r
}

fn calc_eval(src, opts) {
  if opts == nil { opts = {} }
  let tk = calc_tokens(src)
  if not tk.ok { return {ok: false, value: 0, error: tk.error} }
  let st = {t: tk.list, i: 0, err: "", deg: opts.angle == "deg", grad: opts.angle == "grad", x: opts.x, ans: opts.ans}
  if len(st.t) == 0 { return {ok: false, value: 0, error: "Enter an expression"} }
  let v = calc_expr(st)
  if st.err == "" and st.i < len(st.t) { st.err = "Unexpected \"" + str(st.t[st.i].v) + "\"" }
  if st.err != "" { return {ok: false, value: 0, error: st.err} }
  if v != v { return {ok: false, value: 0, error: "Result is undefined"} }
  if v > 1e300 or v < -1e300 { return {ok: false, value: 0, error: "Overflow"} }
  return {ok: true, value: v, error: ""}
}

fn calc_peek(st) { if st.i < len(st.t) { return st.t[st.i] }; return {k: "end", v: ""} }
fn calc_is_op(st, o) { let p = calc_peek(st); return p.k == "op" and p.v == o }

fn calc_expr(st) {
  let v = calc_term(st)
  while st.err == "" {
    if calc_is_op(st, "+") { st.i += 1; v = v + calc_term(st) }
    else if calc_is_op(st, "-") { st.i += 1; v = v - calc_term(st) }
    else { return v }
  }
  return 0
}
fn calc_starts_factor(p) { return p.k == "n" or p.k == "id" or (p.k == "op" and p.v == "(") }
fn calc_term(st) {
  let v = calc_unary(st)
  while st.err == "" {
    let p = calc_peek(st)
    if p.k == "op" and p.v == "*" { st.i += 1; v = v * calc_unary(st) }
    else if p.k == "op" and p.v == "/" {
      st.i += 1
      let d = calc_unary(st)
      if d == 0 { st.err = "Cannot divide by zero"; return 0 }
      v = v / d
    }
    else if p.k == "id" and p.v == "mod" {
      st.i += 1
      let d = calc_unary(st)
      if d == 0 { st.err = "Cannot divide by zero"; return 0 }
      v = v - d * floor(v / d)
    }
    else if calc_starts_factor(p) { v = v * calc_power(st) }      # implicit multiplication: 2pi, 3(4+1), 2sin(30)
    else { return v }
  }
  return 0
}
fn calc_unary(st) {
  if calc_is_op(st, "-") { st.i += 1; return 0 - calc_unary(st) }
  if calc_is_op(st, "+") { st.i += 1; return calc_unary(st) }
  return calc_power(st)
}
fn calc_power(st) {
  let b = calc_postfix(st)
  if st.err == "" and calc_is_op(st, "^") {
    st.i += 1
    let e = calc_unary(st)
    if b < 0 and e != floor(e) {
      let inv = 1 / e
      if inv == floor(inv) and inv % 2 == 1 { return 0 - pow(0 - b, e) }   # odd roots of negatives: (-8)^(1/3) = -2
      st.err = "Invalid input"
      return 0
    }
    if b == 0 and e < 0 { st.err = "Cannot divide by zero"; return 0 }
    return pow(b, e)
  }
  return b
}
fn calc_postfix(st) {
  let v = calc_primary(st)
  while st.err == "" {
    if calc_is_op(st, "!") {
      st.i += 1
      let f = calc_fact(v)
      if f == nil { st.err = "Invalid input"; return 0 }
      v = f
    } else if calc_is_op(st, "%") { st.i += 1; v = v / 100 }
    else { return v }
  }
  return 0
}
fn calc_to_rad(st, a) {
  if st.deg { return a * pi() / 180 }
  if st.grad { return a * pi() / 200 }
  return a
}
fn calc_from_rad(st, a) {
  if st.deg { return a * 180 / pi() }
  if st.grad { return a * 200 / pi() }
  return a
}
fn pi() { return 3.141592653589793 }
fn calc_clean(x) { if abs(x) < 1e-15 { return 0 }; return x }
fn calc_call(st, f, a) {
  if f == "sin" { return calc_clean(sin(calc_to_rad(st, a))) }
  if f == "cos" { return calc_clean(cos(calc_to_rad(st, a))) }
  if f == "tan" {
    let c = calc_clean(cos(calc_to_rad(st, a)))
    if c == 0 { st.err = "Invalid input"; return 0 }
    return calc_clean(sin(calc_to_rad(st, a)) / c)
  }
  if f == "sec" { let c = calc_clean(cos(calc_to_rad(st, a))); if c == 0 { st.err = "Invalid input"; return 0 }; return 1 / c }
  if f == "csc" { let c = calc_clean(sin(calc_to_rad(st, a))); if c == 0 { st.err = "Invalid input"; return 0 }; return 1 / c }
  if f == "cot" { let c = calc_clean(sin(calc_to_rad(st, a))); if c == 0 { st.err = "Invalid input"; return 0 }; return cos(calc_to_rad(st, a)) / c }
  if f == "asin" { if a < -1 or a > 1 { st.err = "Invalid input"; return 0 }; return calc_from_rad(st, asin(a)) }
  if f == "acos" { if a < -1 or a > 1 { st.err = "Invalid input"; return 0 }; return calc_from_rad(st, acos(a)) }
  if f == "atan" { return calc_from_rad(st, atan(a)) }
  if f == "sinh" { return (exp(a) - exp(0 - a)) / 2 }
  if f == "cosh" { return (exp(a) + exp(0 - a)) / 2 }
  if f == "tanh" { return (exp(a) - exp(0 - a)) / (exp(a) + exp(0 - a)) }
  if f == "asinh" { return log(a + sqrt(a * a + 1)) }
  if f == "acosh" { if a < 1 { st.err = "Invalid input"; return 0 }; return log(a + sqrt(a * a - 1)) }
  if f == "atanh" { if a <= -1 or a >= 1 { st.err = "Invalid input"; return 0 }; return 0.5 * log((1 + a) / (1 - a)) }
  if f == "sqrt" { if a < 0 { st.err = "Invalid input"; return 0 }; return sqrt(a) }
  if f == "cbrt" { if a < 0 { return 0 - pow(0 - a, 1 / 3) }; return pow(a, 1 / 3) }
  if f == "ln" { if a <= 0 { st.err = "Invalid input"; return 0 }; return log(a) }
  if f == "log" { if a <= 0 { st.err = "Invalid input"; return 0 }; return calc_clean_log(log(a, 10)) }
  if f == "log2" { if a <= 0 { st.err = "Invalid input"; return 0 }; return calc_clean_log(log(a, 2)) }
  if f == "exp" { return exp(a) }
  if f == "abs" { return abs(a) }
  if f == "floor" { return floor(a) }
  if f == "ceil" { return ceil(a) }
  if f == "round" { return round(a) }
  if f == "neg" { return 0 - a }
  if f == "fact" { let r = calc_fact(a); if r == nil { st.err = "Invalid input"; return 0 }; return r }
  st.err = "Unknown function " + f
  return 0
}
fn calc_clean_log(v) { let r = round(v); if abs(v - r) < 1e-12 { return r }; return v }
fn calc_primary(st) {
  let p = calc_peek(st)
  if p.k == "n" { st.i += 1; return p.v }
  if p.k == "op" and p.v == "(" {
    st.i += 1
    let v = calc_expr(st)
    if calc_is_op(st, ")") { st.i += 1 }        # a missing ")" at the end is forgiven, like Windows Calculator
    else if st.i < len(st.t) and st.err == "" { st.err = "Missing )" }
    return v
  }
  if p.k == "id" {
    st.i += 1
    let id = p.v
    if id == "pi" { return pi() }
    if id == "e" { return exp(1) }
    if id == "tau" { return 2 * pi() }
    if id == "x" and st.x != nil { return st.x }
    if id == "ans" { if st.ans == nil { return 0 }; return st.ans }
    if contains(CALC_FUNCS, id) {
      let a = 0
      if calc_is_op(st, "(") { a = calc_primary(st) } else { a = calc_power(st) }   # sin(30) or sin 30
      if st.err != "" { return 0 }
      return calc_call(st, id, a)
    }
    st.err = "Unknown name \"" + id + "\""
    return 0
  }
  if p.k == "end" { st.err = "Incomplete expression" } else { st.err = "Unexpected \"" + str(p.v) + "\"" }
  return 0
}

# ---------------------------------------------------------------- formatting
fn calc_group(int_part) {
  let neg = startswith(int_part, "-")
  if neg { int_part = slice(int_part, 1) }
  let out = ""
  let n = len(int_part)
  for i in range(n) {
    if i > 0 and (n - i) % 3 == 0 { out = out + "," }
    out = out + int_part[i]
  }
  if neg { return "-" + out }
  return out
}
# exact digits of a whole number below 2^53 (str() rounds to 10 decimals, so the calculator builds its own text)
fn calc_int_str(n) {
  if n == 0 { return "0" }
  let out = ""
  while n > 0 {
    let d = n % 10
    out = chr(48 + d) + out
    n = (n - d) / 10
  }
  return out
}
# plain text of a number: no exponent for normal sizes, up to 15 significant digits
fn calc_plain(v) {
  if v != v { return "Result is undefined" }
  if v == 0 { return "0" }
  let a = abs(v)
  let sign = ""
  if v < 0 { sign = "-" }
  if a >= 1e16 or a < 1e-10 {
    let e = floor(log(a, 10))
    let m = a / pow(10, e)
    if m >= 10 { m = m / 10; e += 1 }
    if m < 1 { m = m * 10; e -= 1 }
    let ms = calc_plain(m)
    if startswith(ms, "10") and not contains(ms, ".") { ms = "1"; e += 1 }
    let es = "+"
    if e < 0 { es = "-" }
    return sign + ms + "e" + es + calc_int_str(abs(e))
  }
  let digits = 15 - (floor(log(a, 10)) + 1)
  if digits < 0 { digits = 0 }
  if digits > 25 { digits = 25 }
  let big = round(a * pow(10, digits))
  while digits > 0 and big >= 9007199254740992 { digits -= 1; big = round(a * pow(10, digits)) }
  let s = calc_int_str(big)
  if digits == 0 { return sign + s }
  while len(s) <= digits { s = "0" + s }
  let ip = slice(s, 0, len(s) - digits)
  let fp = slice(s, len(s) - digits)
  while len(fp) > 0 and fp[-1] == "0" { fp = slice(fp, 0, len(fp) - 1) }
  if fp == "" { return sign + ip }
  return sign + ip + "." + fp
}
# display text: thousands separators (1,234,567.89)
fn calc_fmt(v) {
  let s = calc_plain(v)
  if contains(s, "e") or contains(s, "undefined") { return s }
  let parts = split(s, ".")
  let out = calc_group(parts[0])
  if len(parts) > 1 { out = out + "." + parts[1] }
  return out
}
# money for the game: $1,234.50
fn calc_money(v) {
  let neg = v < 0
  let c = round(abs(v) * 100)
  let whole = floor(c / 100)
  let cents = c - whole * 100
  let cs = str(cents)
  if cents < 10 { cs = "0" + cs }
  let out = "$" + calc_group(calc_int_str(whole)) + "." + cs
  if neg { return "−" + out }
  return out
}
