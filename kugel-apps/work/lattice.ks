# ---------------------------------------------------------------- Kugel Lattice — spreadsheets
# A canvas grid (only the visible cells are drawn, so it stays fast on a weak PC), formulas with 40+ functions,
# several sheets, formatting, sorting, charts, undo, CSV and .xlsx import / export and its own .klattice files.
# Saved on this PC as you type (store_set). Nothing goes online.
let ROWS = 200
let COLS = 52
let RH = 24
let HW = 46
let DW = 96
let HH = 24
fn new_sheet(name) { return {name: name, cells: {}, colw: {}, charts: []} }
fn demo_book() {
  let sh = new_sheet("Budget")
  let data = [["Item", "Jan", "Feb", "Mar", "Total"], ["Rent", "950", "950", "950", "=SUM(B2:D2)"], ["Food", "320", "285.5", "301", "=SUM(B3:D3)"],
    ["Transport", "75", "82", "64", "=SUM(B4:D4)"], ["Fun", "120", "60", "145", "=SUM(B5:D5)"], ["Total", "=SUM(B2:B5)", "=SUM(C2:C5)", "=SUM(D2:D5)", "=SUM(E2:E5)"],
    ["", "", "", "", ""], ["Average month", "=AVERAGE(B6:D6)", "", "Biggest", "=INDEX(A2:A5, MATCH(MAX(E2:E5), E2:E5, 0))"]]
  for r in range(len(data)) { for c in range(5) { if data[r][c] != "" { sh.cells[col_name(c) + str(r + 1)] = {v: data[r][c]} } } }
  for c in range(5) { sh.cells[col_name(c) + "1"].b = true; sh.cells[col_name(c) + "1"].bg = "#e8effd" }
  for c in range(1, 5) { for r in range(2, 7) { sh.cells[col_name(c) + str(r)].nf = "cur" } }
  sh.cells["A6"].b = true
  sh.cells["B8"].nf = "cur"
  sh.cells["D8"].b = true
  sh.colw["A"] = 130
  push(sh.charts, {type: "bar", range: "A1:D5", title: "Spending by month"})
  return {name: "My budget", sheets: [sh, new_sheet("Sheet2")], active: 0}
}

# ----- addresses
let LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
fn col_name(c) { let s = ""; let n = c + 1; while n > 0 { let m = (n - 1) % 26; s = substr(LETTERS, m, 1) + s; n = floor((n - 1) / 26) }; return s }
fn col_index(s) { let n = 0; for ch in split(upper(s), "") { n = n * 26 + indexof(LETTERS, ch) + 1 }; return n - 1 }
fn key_of(c, r) { return col_name(c) + str(r + 1) }
fn is_letter(ch) { return ch != "" and contains(LETTERS, upper(ch)) and len(ch) == 1 }
fn is_digit(ch) { return ch >= "0" and ch <= "9" and len(ch) == 1 }
# "B12" / "$B$12" -> {c, r, ac, ar} (0-based) or nil
fn parse_ref(t) {
  let i = 0
  let n = len(t)
  let ac = false
  let ar = false
  if i < n and t[i] == "$" { ac = true; i += 1 }
  let s = i
  while i < n and is_letter(t[i]) { i += 1 }
  if i == s or i - s > 3 { return nil }
  let cs = substr(t, s, i - s)
  if i < n and t[i] == "$" { ar = true; i += 1 }
  let s2 = i
  while i < n and is_digit(t[i]) { i += 1 }
  if i == s2 or i != n { return nil }
  let r = num(substr(t, s2, i - s2)) - 1
  let c = col_index(cs)
  if r < 0 or c < 0 { return nil }
  return {c: c, r: r, ac: ac, ar: ar}
}
fn ref_text(p) { let s = ""; if p.ac { s = "$" }; s = s + col_name(p.c); if p.ar { s = s + "$" }; return s + str(p.r + 1) }

# ----- formula tokens (kept with their positions so references can be rewritten when copying / inserting)
fn tokens(src) {
  let out = []
  let i = 0
  let n = len(src)
  while i < n {
    let ch = src[i]
    if ch == " " { i += 1; continue }
    let s = i
    if is_digit(ch) or (ch == "." and i + 1 < n and is_digit(src[i + 1])) {
      while i < n and (is_digit(src[i]) or src[i] == ".") { i += 1 }
      if i < n and (src[i] == "e" or src[i] == "E") and i + 1 < n and (is_digit(src[i + 1]) or src[i + 1] == "-" or src[i + 1] == "+") { i += 2; while i < n and is_digit(src[i]) { i += 1 } }
      push(out, {k: "num", v: num(substr(src, s, i - s)), s: s, e: i})
      continue
    }
    if ch == "\"" {
      i += 1
      let txt = ""
      while i < n {
        if src[i] == "\"" { if i + 1 < n and src[i + 1] == "\"" { txt = txt + "\""; i += 2; continue }; break }
        txt = txt + src[i]
        i += 1
      }
      i += 1
      push(out, {k: "str", v: txt, s: s, e: i})
      continue
    }
    if is_letter(ch) or ch == "$" or ch == "_" {
      while i < n and (is_letter(src[i]) or is_digit(src[i]) or src[i] == "$" or src[i] == "_" or src[i] == ".") { i += 1 }
      let w = substr(src, s, i - s)
      let j = i
      while j < n and src[j] == " " { j += 1 }
      if j < n and src[j] == "(" { push(out, {k: "fn", v: upper(w), s: s, e: i}); continue }
      let p = parse_ref(w)
      if p != nil { push(out, {k: "ref", v: p, s: s, e: i}); continue }
      if upper(w) == "TRUE" or upper(w) == "FALSE" { push(out, {k: "bool", v: upper(w) == "TRUE", s: s, e: i}); continue }
      push(out, {k: "name", v: w, s: s, e: i})
      continue
    }
    let two = substr(src, i, 2)
    if two == "<=" or two == ">=" or two == "<>" { push(out, {k: "op", v: two, s: s, e: i + 2}); i += 2; continue }
    if ch == ";" { ch = "," }
    push(out, {k: "op", v: ch, s: s, e: i + 1})
    i += 1
  }
  return out
}
# rewrite every reference in a formula: f(p) -> new p or nil (= #REF!)
fn rewrite_refs(raw, f) {
  if not startswith(raw, "=") { return raw }
  let src = substr(raw, 1)
  let tk = tokens(src)
  let out = ""
  let at = 0
  for t in tk {
    if t.k == "ref" {
      out = out + substr(src, at, t.s - at)
      let p = f(t.v)
      if p == nil { out = out + "#REF!" } else { out = out + ref_text(p) }
      at = t.e
    }
  }
  return "=" + out + substr(src, at)
}
fn move_formula(raw, dr, dc) {
  return rewrite_refs(raw, fn(p) {
    let q = {c: p.c, r: p.r, ac: p.ac, ar: p.ar}
    if not p.ac { q.c = p.c + dc }
    if not p.ar { q.r = p.r + dr }
    if q.c < 0 or q.r < 0 { return nil }
    return q
  })
}

# ----- evaluation
let book = store_get("book", nil)
if book == nil or type(book) != "map" or not has(book, "sheets") { book = demo_book() }
let vals = {}
let busy = {}
fn sheet() { return book.sheets[book.active] }
fn err(e) { return {e: e} }
fn is_err(v) { return type(v) == "map" and has(v, "e") }
fn is_range(v) { return type(v) == "map" and has(v, "rg") }
fn cell_raw(key) { let cs = sheet().cells; if has(cs, key) { return cs[key].v }; return "" }
fn literal(raw) {
  if raw == "" { return nil }
  let t = trim(raw)
  let u = upper(t)
  if u == "TRUE" { return true }
  if u == "FALSE" { return false }
  let s = replace(replace(t, ",", ""), "$", "")
  if endswith(s, "%") { let n = num(substr(s, 0, len(s) - 1)); if n != nil { return n / 100 } }
  let n = num(s)
  if n != nil and s != "" and not contains(s, " ") { return n }
  return raw
}
fn value_of(key) {
  if has(vals, key) { return vals[key] }
  if busy[key] == true { return err("#CIRC!") }
  let raw = cell_raw(key)
  let v = nil
  if startswith(raw, "=") and len(raw) > 1 {
    busy[key] = true
    v = eval_formula(substr(raw, 1))
    busy[key] = false
    if is_range(v) { v = range_first(v) }
  } else { v = literal(raw) }
  vals[key] = v
  return v
}
fn recalc() { vals = {}; busy = {} }
fn range_first(rg) { if len(rg.keys) == 0 { return nil }; return value_of(rg.keys[0]) }
fn make_range(a, b) {
  let c0 = min(a.c, b.c)
  let c1 = max(a.c, b.c)
  let r0 = min(a.r, b.r)
  let r1 = max(a.r, b.r)
  let ks = []
  for r in range(r0, r1 + 1) { for c in range(c0, c1 + 1) { push(ks, key_of(c, r)) } }
  return {rg: true, keys: ks, w: c1 - c0 + 1, h: r1 - r0 + 1, c0: c0, r0: r0}
}
fn eval_formula(src) {
  let st = {t: tokens(src), i: 0, err: ""}
  if len(st.t) == 0 { return nil }
  let v = p_compare(st)
  if st.err != "" { return err(st.err) }
  if st.i < len(st.t) { return err("#ERROR!") }
  return v
}
fn peek(st) { if st.i < len(st.t) { return st.t[st.i] }; return {k: "end", v: ""} }
fn is_op(st, o) { let p = peek(st); return p.k == "op" and p.v == o }
fn to_num(v) {
  if v == nil { return 0 }
  if type(v) == "number" { return v }
  if type(v) == "bool" { if v { return 1 }; return 0 }
  if is_err(v) { return v }
  if is_range(v) { return to_num(range_first(v)) }
  let n = literal(str(v))
  if type(n) == "number" { return n }
  if trim(str(v)) == "" { return 0 }
  return err("#VALUE!")
}
fn to_text(v) {
  if v == nil { return "" }
  if type(v) == "bool" { if v { return "TRUE" }; return "FALSE" }
  if type(v) == "number" { return gen_num(v) }
  if is_range(v) { return to_text(range_first(v)) }
  if is_err(v) { return v.e }
  return str(v)
}
fn truthy(v) { if type(v) == "bool" { return v }; if type(v) == "number" { return v != 0 }; if v == nil { return false }; let u = upper(str(v)); return u == "TRUE" }
fn compare(a, b) {
  if type(a) == "number" and type(b) == "number" { return a - b }
  if a == nil { a = 0; if type(b) == "string" { a = "" } }
  if b == nil { b = 0; if type(a) == "string" { b = "" } }
  if type(a) == "number" and type(b) == "number" { return a - b }
  if type(a) == "number" and type(b) != "number" { return -1 }
  if type(b) == "number" and type(a) != "number" { return 1 }
  let x = lower(to_text(a))
  let y = lower(to_text(b))
  if x < y { return -1 }
  if x > y { return 1 }
  return 0
}
fn p_compare(st) {
  let a = p_concat(st)
  while true {
    let p = peek(st)
    if p.k != "op" or not contains(["=", "<>", "<", ">", "<=", ">="], p.v) { return a }
    st.i += 1
    let b = p_concat(st)
    if is_range(a) { a = range_first(a) }
    if is_range(b) { b = range_first(b) }
    if is_err(a) { return a }
    if is_err(b) { return b }
    let c = compare(a, b)
    if p.v == "=" { a = c == 0 } else if p.v == "<>" { a = c != 0 } else if p.v == "<" { a = c < 0 } else if p.v == ">" { a = c > 0 } else if p.v == "<=" { a = c <= 0 } else { a = c >= 0 }
  }
}
fn p_concat(st) {
  let a = p_add(st)
  while is_op(st, "&") {
    st.i += 1
    let b = p_add(st)
    if is_err(a) { return a }
    if is_err(b) { return b }
    a = to_text(a) + to_text(b)
  }
  return a
}
fn arith(a, b, o) {
  let x = to_num(a)
  let y = to_num(b)
  if is_err(x) { return x }
  if is_err(y) { return y }
  if o == "+" { return x + y }
  if o == "-" { return x - y }
  if o == "*" { return x * y }
  if o == "/" { if y == 0 { return err("#DIV/0!") }; return x / y }
  if o == "^" { let r = pow(x, y); if r != r { return err("#NUM!") }; return r }
  return err("#VALUE!")
}
fn p_add(st) {
  let a = p_mul(st)
  while is_op(st, "+") or is_op(st, "-") { let o = peek(st).v; st.i += 1; a = arith(a, p_mul(st), o) }
  return a
}
fn p_mul(st) {
  let a = p_pow(st)
  while is_op(st, "*") or is_op(st, "/") { let o = peek(st).v; st.i += 1; a = arith(a, p_pow(st), o) }
  return a
}
fn p_pow(st) {
  let a = p_unary(st)
  while is_op(st, "^") { st.i += 1; a = arith(a, p_unary(st), "^") }
  return a
}
fn p_unary(st) {
  if is_op(st, "-") { st.i += 1; return arith(0, p_unary(st), "-") }
  if is_op(st, "+") { st.i += 1; return p_unary(st) }
  return p_postfix(st)
}
fn p_postfix(st) {
  let a = p_primary(st)
  while is_op(st, "%") { st.i += 1; a = arith(a, 100, "/") }
  return a
}
fn p_primary(st) {
  let p = peek(st)
  if p.k == "end" { st.err = "#ERROR!"; return nil }
  st.i += 1
  if p.k == "num" or p.k == "str" or p.k == "bool" { return p.v }
  if p.k == "ref" {
    if is_op(st, ":") {
      st.i += 1
      let q = peek(st)
      if q.k != "ref" { st.err = "#REF!"; return nil }
      st.i += 1
      return make_range(p.v, q.v)
    }
    return value_of(key_of(p.v.c, p.v.r))
  }
  if p.k == "fn" {
    if not is_op(st, "(") { st.err = "#ERROR!"; return nil }
    st.i += 1
    let args = []
    if not is_op(st, ")") {
      push(args, p_compare(st))
      while is_op(st, ",") { st.i += 1; push(args, p_compare(st)) }
    }
    if not is_op(st, ")") { st.err = "#ERROR!"; return nil }
    st.i += 1
    return call_fn(p.v, args)
  }
  if p.k == "op" and p.v == "(" {
    let v = p_compare(st)
    if not is_op(st, ")") { st.err = "#ERROR!"; return nil }
    st.i += 1
    return v
  }
  if p.k == "name" { return err("#NAME?") }
  st.err = "#ERROR!"
  return nil
}
# all values of the arguments, ranges expanded
fn flat(args) {
  let out = []
  for a in args { if is_range(a) { for k in a.keys { push(out, value_of(k)) } } else { push(out, a) } }
  return out
}
fn nums(args, strict) {
  let out = []
  for a in args {
    if is_range(a) { for k in a.keys { let v = value_of(k); if is_err(v) { return v }; if type(v) == "number" { push(out, v) } } }
    else {
      if is_err(a) { return a }
      let n = to_num(a)
      if is_err(n) { if strict { return n } } else { push(out, n) }
    }
  }
  return out
}
fn first_err(l) { if is_err(l) { return l }; return nil }
fn criteria(cr) {
  let s = to_text(cr)
  let op = "="
  for o in ["<=", ">=", "<>", "<", ">", "="] { if startswith(s, o) { op = o; s = substr(s, len(o)); break } }
  let target = literal(s)
  return fn(v) {
    if op == "=" and type(target) == "string" and contains(target, "*") { return startswith(lower(to_text(v)), lower(replace(target, "*", ""))) }
    let c = compare(v, target)
    if op == "=" { return c == 0 }
    if op == "<>" { return c != 0 }
    if op == "<" { return c < 0 }
    if op == ">" { return c > 0 }
    if op == "<=" { return c <= 0 }
    return c >= 0
  }
}
fn round_to(x, d) { let m = pow(10, d); return round(x * m) / m }
let FN_NAMES = ["SUM", "AVERAGE", "AVG", "MIN", "MAX", "COUNT", "COUNTA", "COUNTBLANK", "PRODUCT", "MEDIAN", "IF", "IFERROR", "AND", "OR", "NOT",
  "ROUND", "ROUNDUP", "ROUNDDOWN", "INT", "ABS", "SQRT", "POWER", "MOD", "PI", "RAND", "RANDBETWEEN", "LEN", "UPPER", "LOWER", "PROPER", "TRIM",
  "LEFT", "RIGHT", "MID", "CONCAT", "CONCATENATE", "TEXTJOIN", "FIND", "SUBSTITUTE", "VLOOKUP", "HLOOKUP", "INDEX", "MATCH", "SUMIF", "COUNTIF",
  "AVERAGEIF", "TODAY", "NOW", "YEAR", "MONTH", "DAY", "ISNUMBER", "ISTEXT", "ISBLANK", "VALUE", "TEXT", "EXP", "LN", "LOG10", "SIGN", "STDEV"]
fn call_fn(name, a) {
  let n = len(a)
  if name == "SUM" { let l = nums(a, true); if is_err(l) { return l }; return sum(l) }
  if name == "AVERAGE" or name == "AVG" { let l = nums(a, true); if is_err(l) { return l }; if len(l) == 0 { return err("#DIV/0!") }; return sum(l) / len(l) }
  if name == "MIN" { let l = nums(a, true); if is_err(l) { return l }; if len(l) == 0 { return 0 }; return min(l) }
  if name == "MAX" { let l = nums(a, true); if is_err(l) { return l }; if len(l) == 0 { return 0 }; return max(l) }
  if name == "COUNT" { let c = 0; for v in flat(a) { if type(v) == "number" { c += 1 } }; return c }
  if name == "COUNTA" { let c = 0; for v in flat(a) { if v != nil and v != "" { c += 1 } }; return c }
  if name == "COUNTBLANK" { let c = 0; for v in flat(a) { if v == nil or v == "" { c += 1 } }; return c }
  if name == "PRODUCT" { let l = nums(a, true); if is_err(l) { return l }; let p = 1; for x in l { p = p * x }; return p }
  if name == "MEDIAN" { let l = nums(a, true); if is_err(l) { return l }; if len(l) == 0 { return err("#NUM!") }; l = sort(l); let m = floor(len(l) / 2); if len(l) % 2 == 1 { return l[m] }; return (l[m - 1] + l[m]) / 2 }
  if name == "STDEV" { let l = nums(a, true); if is_err(l) { return l }; if len(l) < 2 { return err("#DIV/0!") }; let m = sum(l) / len(l); let s = 0; for x in l { s += (x - m) * (x - m) }; return sqrt(s / (len(l) - 1)) }
  if name == "IF" { if n < 2 { return err("#N/A") }; let c = a[0]; if is_range(c) { c = range_first(c) }; if is_err(c) { return c }; if truthy(c) { return a[1] }; if n > 2 { return a[2] }; return false }
  if name == "IFERROR" { if n < 2 { return err("#N/A") }; let v = a[0]; if is_range(v) { v = range_first(v) }; if is_err(v) { return a[1] }; return v }
  if name == "AND" { for v in flat(a) { if is_err(v) { return v }; if not truthy(v) { return false } }; return true }
  if name == "OR" { for v in flat(a) { if is_err(v) { return v }; if truthy(v) { return true } }; return false }
  if name == "NOT" { return not truthy(a[0]) }
  if name == "PI" { return 3.141592653589793 }
  if name == "RAND" { return random() }
  if name == "TODAY" { return floor(time() / 86400000) + 25569 }
  if name == "NOW" { return time() / 86400000 + 25569 }
  if name == "CONCAT" or name == "CONCATENATE" { let s = ""; for v in flat(a) { if is_err(v) { return v }; s = s + to_text(v) }; return s }
  if name == "TEXTJOIN" { let sep = to_text(a[0]); let parts = []; for v in flat(slice(a, 2)) { let t = to_text(v); if t != "" or not truthy(a[1]) { push(parts, t) } }; return join(parts, sep) }
  if name == "SUMIF" or name == "COUNTIF" or name == "AVERAGEIF" {
    if n < 2 or not is_range(a[0]) { return err("#VALUE!") }
    let test = criteria(a[1])
    let src = a[0]
    if n > 2 and is_range(a[2]) { src = a[2] }
    let c = 0
    let s = 0
    for i in range(len(a[0].keys)) {
      if test(value_of(a[0].keys[i])) {
        c += 1
        if i < len(src.keys) { let v = value_of(src.keys[i]); if type(v) == "number" { s += v } }
      }
    }
    if name == "COUNTIF" { return c }
    if name == "SUMIF" { return s }
    if c == 0 { return err("#DIV/0!") }
    return s / c
  }
  if name == "VLOOKUP" or name == "HLOOKUP" {
    if n < 3 or not is_range(a[1]) { return err("#N/A") }
    let want = a[0]
    if is_range(want) { want = range_first(want) }
    let rg = a[1]
    let idx = to_num(a[2])
    if is_err(idx) { return idx }
    let exact = n > 3 and not truthy(a[3])
    let vert = name == "VLOOKUP"
    let count = rg.h
    if not vert { count = rg.w }
    let found = -1
    for i in range(count) {
      let k = key_of(rg.c0, rg.r0 + i)
      if not vert { k = key_of(rg.c0 + i, rg.r0) }
      let c = compare(value_of(k), want)
      if c == 0 { found = i; break }
      if not exact and c < 0 { found = i }
      if not exact and c > 0 { break }
    }
    if found < 0 { return err("#N/A") }
    if idx < 1 { return err("#VALUE!") }
    if vert { if idx > rg.w { return err("#REF!") }; return value_of(key_of(rg.c0 + idx - 1, rg.r0 + found)) }
    if idx > rg.h { return err("#REF!") }
    return value_of(key_of(rg.c0 + found, rg.r0 + idx - 1))
  }
  if name == "INDEX" {
    if n < 2 or not is_range(a[0]) { return err("#REF!") }
    let r = to_num(a[1])
    let c = 1
    if n > 2 { c = to_num(a[2]) }
    if is_err(r) { return r }
    if is_err(c) { return c }
    if a[0].h == 1 and n == 2 { c = r; r = 1 }
    if r < 1 or c < 1 or r > a[0].h or c > a[0].w { return err("#REF!") }
    return value_of(key_of(a[0].c0 + c - 1, a[0].r0 + r - 1))
  }
  if name == "MATCH" {
    if n < 2 or not is_range(a[1]) { return err("#N/A") }
    let want = a[0]
    if is_range(want) { want = range_first(want) }
    let mode = 1
    if n > 2 { mode = to_num(a[2]) }
    let best = -1
    for i in range(len(a[1].keys)) {
      let c = compare(value_of(a[1].keys[i]), want)
      if c == 0 { return i + 1 }
      if mode == 1 and c < 0 { best = i }
      if mode == 1 and c > 0 { break }
    }
    if mode == 1 and best >= 0 { return best + 1 }
    return err("#N/A")
  }
  if name == "ISNUMBER" { let v = a[0]; if is_range(v) { v = range_first(v) }; return type(v) == "number" }
  if name == "ISTEXT" { let v = a[0]; if is_range(v) { v = range_first(v) }; return type(v) == "string" }
  if name == "ISBLANK" { let v = a[0]; if is_range(v) { v = range_first(v) }; return v == nil }
  # one-value functions
  let x = nil
  if n > 0 { x = a[0]; if is_range(x) { x = range_first(x) } }
  if is_err(x) { return x }
  if name == "LEN" { return len(to_text(x)) }
  if name == "UPPER" { return upper(to_text(x)) }
  if name == "LOWER" { return lower(to_text(x)) }
  if name == "TRIM" { return trim(to_text(x)) }
  if name == "PROPER" { let out = []; for w in split(lower(to_text(x)), " ") { if w == "" { push(out, w) } else { push(out, upper(substr(w, 0, 1)) + substr(w, 1)) } }; return join(out, " ") }
  if name == "LEFT" { let k = 1; if n > 1 { k = to_num(a[1]) }; return substr(to_text(x), 0, k) }
  if name == "RIGHT" { let k = 1; if n > 1 { k = to_num(a[1]) }; let t = to_text(x); return substr(t, max(0, len(t) - k)) }
  if name == "MID" { if n < 3 { return err("#VALUE!") }; return substr(to_text(x), to_num(a[1]) - 1, to_num(a[2])) }
  if name == "FIND" { let i = indexof(to_text(a[1]), to_text(x)); if i < 0 { return err("#VALUE!") }; return i + 1 }
  if name == "SUBSTITUTE" { if n < 3 { return err("#VALUE!") }; return replace(to_text(x), to_text(a[1]), to_text(a[2])) }
  if name == "TEXT" { if n < 2 { return to_text(x) }; let f = to_text(a[1]); let v = to_num(x); if is_err(v) { return to_text(x) }; if contains(f, "%") { return fixed(v * 100, decimals_in(f)) + "%" }; if contains(f, "$") { return "$" + fixed(v, decimals_in(f)) }; return fixed(v, decimals_in(f)) }
  if name == "VALUE" { return to_num(x) }
  let v = to_num(x)
  if is_err(v) { return v }
  if name == "ROUND" { let d = 0; if n > 1 { d = to_num(a[1]) }; return round_to(v, d) }
  if name == "ROUNDUP" { let d = 0; if n > 1 { d = to_num(a[1]) }; let m = pow(10, d); if v < 0 { return 0 - ceil(abs(v) * m - 1e-9) / m }; return ceil(v * m - 1e-9) / m }
  if name == "ROUNDDOWN" { let d = 0; if n > 1 { d = to_num(a[1]) }; let m = pow(10, d); if v < 0 { return 0 - floor(abs(v) * m + 1e-9) / m }; return floor(v * m + 1e-9) / m }
  if name == "INT" { return floor(v) }
  if name == "ABS" { return abs(v) }
  if name == "SIGN" { return sign(v) }
  if name == "SQRT" { if v < 0 { return err("#NUM!") }; return sqrt(v) }
  if name == "EXP" { return exp(v) }
  if name == "LN" { if v <= 0 { return err("#NUM!") }; return log(v) }
  if name == "LOG10" { if v <= 0 { return err("#NUM!") }; return log(v, 10) }
  if name == "POWER" { return arith(v, a[1], "^") }
  if name == "MOD" { let d = to_num(a[1]); if d == 0 { return err("#DIV/0!") }; return v - d * floor(v / d) }
  if name == "RANDBETWEEN" { return random(ceil(v), floor(to_num(a[1]))) }
  if name == "YEAR" or name == "MONTH" or name == "DAY" { let c = kw_civil(floor(v) - 25569); if name == "YEAR" { return c.y }; if name == "MONTH" { return c.m }; return c.d }
  return err("#NAME?")
}
fn decimals_in(f) { let i = indexof(f, "."); if i < 0 { return 0 }; let d = 0; i += 1; while i < len(f) and (f[i] == "0" or f[i] == "#") { d += 1; i += 1 }; return d }

# ----- number formats
fn fixed(v, d) {
  let neg = v < 0
  let big = round(abs(v) * pow(10, d))
  let s = calc_int_str(big)
  while len(s) <= d { s = "0" + s }
  let ip = slice(s, 0, len(s) - d)
  let out = calc_group(ip)
  if d > 0 { out = out + "." + slice(s, len(s) - d) }
  if neg and big != 0 { return "-" + out }
  return out
}
fn gen_num(v) {
  if v == floor(v) and abs(v) < 1e15 { if v < 0 { return "-" + calc_int_str(0 - v) }; return calc_int_str(v) }
  let s = calc_plain(v)
  if len(s) > 12 and not contains(s, "e") { s = calc_plain(round_to(v, 10 - min(9, max(0, floor(log(abs(v) + 1e-300, 10)))))) }
  return s
}
fn show_value(v, cell) {
  if v == nil { return "" }
  if is_err(v) { return v.e }
  if type(v) == "bool" { if v { return "TRUE" }; return "FALSE" }
  if type(v) == "number" {
    let nf = "gen"
    if cell != nil and has(cell, "nf") { nf = cell.nf }
    if nf == "num" { return fixed(v, 2) }
    if nf == "cur" { if v < 0 { return "-$" + fixed(0 - v, 2) }; return "$" + fixed(v, 2) }
    if nf == "pct" { return fixed(v * 100, 1) + "%" }
    if nf == "int" { return fixed(v, 0) }
    if nf == "date" { let c = kw_civil(floor(v) - 25569); return str(c.y) + "-" + pad2(c.m) + "-" + pad2(c.d) }
    return gen_num(v)
  }
  return str(v)
}
fn pad2(n) { if n < 10 { return "0" + str(n) }; return str(n) }

# ================================================================ UI
let root = box(body(), "kw kl")
let bar = row(root, "kw-bar")
label(bar, "▦", "kw-logo kl-logo")
label(bar, "Kugel Lattice", "kw-title")
let name_box = textbox(bar, "Workbook name", nil, "kw-in kl-name")
settext(name_box, book.name)
on_input(name_box, fn(t) { book.name = t; save_book() }, 400)
kw_space(bar)
kw_btn(bar, "New", fn() { new_book() }, nil)
kw_btn(bar, "Open", fn() { open_file() }, nil)
kw_btn(bar, "Save", fn() { file_save(kw_safe_name(book.name) + ".klattice", json({app: "kugel-lattice", version: 1, book: book}, false)) }, nil)
kw_btn(bar, "Export", fn() { export_dialog() }, "accent")
let tb = row(root, "kw-toolbar kl-tools")
let fxrow = row(root, "kl-fxrow")
let name_l = label(fxrow, "A1", "kl-namebox")
label(fxrow, "fx", "kl-fx")
let fx = textbox(fxrow, "", fn(t) { commit_text(t); focus_grid() }, "kw-in kl-fxin")
let main_ = row(root, "kl-main")
let wrap = box(main_, "kl-grid")
let cv = canvas(wrap)
let ed = textbox(wrap, "", nil, "kl-ed idle")
let charts_panel = col(main_, "kl-charts")
let tabs = row(root, "kl-tabs")
let status = row(root, "kw-status")

let act = {c: 0, r: 0}
let anc = {c: 0, r: 0}
let sr = 0
let sc = 0
let editing = false
let undo_stack = []
let redo_stack = []
let clip = nil
let show_charts = true
fn save_book() { store_set("book", book) }
fn colw(c) { let n = col_name(c); let cw = sheet().colw; if has(cw, n) { return cw[n] }; return DW }
fn sel_rect() { return {c0: min(act.c, anc.c), c1: max(act.c, anc.c), r0: min(act.r, anc.r), r1: max(act.r, anc.r)} }
fn sel_text() { let s = sel_rect(); let t = key_of(s.c0, s.r0); if s.c0 != s.c1 or s.r0 != s.r1 { t = t + ":" + key_of(s.c1, s.r1) }; return t }
fn cell_at(key) { let cs = sheet().cells; if has(cs, key) { return cs[key] }; return nil }
fn ensure_cell(key) { let cs = sheet().cells; if not has(cs, key) { cs[key] = {v: ""} }; return cs[key] }

# ----- undo: snapshots of the cells a change touches
fn snapshot(keys) {
  let snap = []
  for k in keys { let c = cell_at(k); if c == nil { push(snap, {k: k, c: nil}) } else { push(snap, {k: k, c: parse_json(json(c))}) } }
  return {sheet: book.active, cells: snap}
}
fn record(keys) { push(undo_stack, snapshot(keys)); if len(undo_stack) > 100 { remove(undo_stack, 0) }; redo_stack = [] }
fn restore(sn, into) {
  book.active = sn.sheet
  let keys = []
  for s in sn.cells { push(keys, s.k) }
  push(into, snapshot(keys))
  let cs = sheet().cells
  for s in sn.cells { if s.c == nil { if has(cs, s.k) { remove(cs, s.k) } } else { cs[s.k] = s.c } }
  changed()
}
fn rect_keys(s) { let ks = []; for r in range(s.r0, s.r1 + 1) { for c in range(s.c0, s.c1 + 1) { push(ks, key_of(c, r)) } }; return ks }
fn changed() { recalc(); save_book(); draw_all() }

# ----- editing
fn set_raw(key, raw) {
  let cs = sheet().cells
  if raw == "" { if has(cs, key) { cs[key].v = ""; if len(keys(cs[key])) == 1 { remove(cs, key) } } }
  else { ensure_cell(key).v = raw }
}
fn commit_text(t) {
  let key = key_of(act.c, act.r)
  if t != cell_raw(key) { record([key]); set_raw(key, t); recalc(); save_book() }
  stop_edit()
  draw_all()
}
fn begin_edit(text) {
  editing = true
  removestyle(ed, "idle")
  key_prevent(ed, ["enter", "tab", "shift+tab", "shift+enter", "escape"])
  place_editor()
  if text != nil { settext(ed, ""); focus(ed); after(40, fn() { settext(ed, ""); text_insert(ed, text, "") }) }
}
fn focus_end() { focus(ed); after(40, fn() { let t = gettext(ed); settext(ed, ""); text_insert(ed, t, "") }) }
fn stop_edit() {
  editing = false
  addstyle(ed, "idle")
  settext(ed, "")
  key_prevent(ed, NAV_KEYS)
}
let NAV_KEYS = ["up", "down", "left", "right", "enter", "tab", "shift+tab", "shift+enter", "delete", "backspace", "f2", "escape", "pageup", "pagedown", "home",
  "ctrl+c", "ctrl+x", "ctrl+z", "ctrl+y", "ctrl+b", "ctrl+i", "ctrl+a", "ctrl+d", "ctrl+home", "shift+up", "shift+down", "shift+left", "shift+right", "ctrl+s"]
fn focus_grid() { focus(ed) }
fn place_editor() {
  let p = cell_pos(act.c, act.r)
  if p == nil { setstyle(ed, "left", -9999); return }
  setstyle(ed, "left", p.x)
  setstyle(ed, "top", p.y)
  setstyle(ed, "width", max(colw(act.c), 120))
  setstyle(ed, "height", RH)
}
fn cell_pos(c, r) {
  if c < sc or r < sr { return nil }
  let x = HW
  for i in range(sc, c) { x += colw(i) }
  return {x: x, y: HH + (r - sr) * RH}
}
fn move_to(c, r, extend) {
  act = {c: clamp(c, 0, COLS - 1), r: clamp(r, 0, ROWS - 1)}
  if not extend { anc = {c: act.c, r: act.r} }
  scroll_into_view()
  draw_all()
}
fn scroll_into_view() {
  let sz = canvas_size(cv)
  if act.r < sr { sr = act.r }
  let vis_rows = max(1, floor((sz.h - HH) / RH) - 1)
  if act.r >= sr + vis_rows { sr = act.r - vis_rows + 1 }
  if act.c < sc { sc = act.c }
  while true {
    let x = HW
    for i in range(sc, act.c + 1) { x += colw(i) }
    if x <= sz.w or sc >= act.c { break }
    sc += 1
  }
}
on_input(ed, fn(t) {
  if not editing and t != "" {
    if contains(t, "\t") or contains(t, "\n") { paste_text(t); settext(ed, ""); return }
    begin_edit(nil)
  }
  if editing { settext(fx, t) }
}, 1)
on_keydown(ed, fn(k) {
  if editing {
    if k.name == "enter" { commit_text(gettext(ed)); if k.shift { move_to(act.c, act.r - 1, false) } else { move_to(act.c, act.r + 1, false) } }
    else if k.name == "tab" { commit_text(gettext(ed)); if k.shift { move_to(act.c - 1, act.r, false) } else { move_to(act.c + 1, act.r, false) } }
    else if k.name == "escape" { stop_edit(); draw_all() }
    return
  }
  let c = k.combo
  let ext = k.shift
  if k.name == "up" { move_to(act.c, act.r - 1, ext) }
  else if k.name == "down" { move_to(act.c, act.r + 1, ext) }
  else if k.name == "left" { move_to(act.c - 1, act.r, ext) }
  else if k.name == "right" { move_to(act.c + 1, act.r, ext) }
  else if k.name == "enter" { if k.shift { move_to(act.c, act.r - 1, false) } else { move_to(act.c, act.r + 1, false) } }
  else if k.name == "tab" { if k.shift { move_to(act.c - 1, act.r, false) } else { move_to(act.c + 1, act.r, false) } }
  else if k.name == "pagedown" { move_to(act.c, act.r + 20, ext) }
  else if k.name == "pageup" { move_to(act.c, act.r - 20, ext) }
  else if c == "ctrl+home" or k.name == "home" { move_to(0, act.r, ext); if c == "ctrl+home" { move_to(0, 0, false) } }
  else if k.name == "delete" or k.name == "backspace" { clear_cells() }
  else if k.name == "f2" { begin_edit(cell_raw(key_of(act.c, act.r))) }
  else if k.name == "escape" { anc = {c: act.c, r: act.r}; draw_all() }
  else if c == "ctrl+z" { undo() }
  else if c == "ctrl+y" { redo() }
  else if c == "ctrl+c" { copy_sel(false) }
  else if c == "ctrl+x" { copy_sel(true) }
  else if c == "ctrl+v" { if clip != nil { paste_clip() } }
  else if c == "ctrl+b" { toggle_fmt("b") }
  else if c == "ctrl+i" { toggle_fmt("i") }
  else if c == "ctrl+a" { anc = {c: 0, r: 0}; act = {c: COLS - 1, r: ROWS - 1}; draw_all() }
  else if c == "ctrl+d" { fill_down() }
  else if c == "ctrl+s" { save_book(); kw_toast(root, "Saved on this PC") }
}, NAV_KEYS)

# ----- mouse on the grid
let drag = ""
let resize_col = -1
let resize_x0 = 0
let resize_w0 = 0
let last_down = {t: 0, c: -1, r: -1}
fn hit(x, y) {
  let c = -1
  let cx = HW
  let edge = -1
  let i = sc
  while cx < 4000 and i < COLS {
    let w = colw(i)
    if abs(x - (cx + w)) <= 3 { edge = i }
    if x >= cx and x < cx + w { c = i }
    cx += w
    i += 1
  }
  let r = -1
  if y >= HH { r = sr + floor((y - HH) / RH) }
  return {c: c, r: min(r, ROWS - 1), edge: edge, head_c: y < HH, head_r: x < HW}
}
on_mouse(cv, fn(e) {
  if e.type == "wheel" {
    if e.shift { sc = clamp(sc + e.dy, 0, COLS - 1) } else { sr = clamp(sr + e.dy * 3, 0, ROWS - 1) }
    draw_grid()
    place_editor()
    return
  }
  let h = hit(e.x, e.y)
  if e.type == "down" {
    if editing { commit_text(gettext(ed)) }
    if h.head_c and h.edge >= 0 { drag = "resize"; resize_col = h.edge; resize_x0 = e.x; resize_w0 = colw(h.edge); return }
    if h.head_c and h.head_r { anc = {c: 0, r: 0}; act = {c: COLS - 1, r: ROWS - 1}; draw_all(); return }
    if h.head_c and h.c >= 0 { anc = {c: h.c, r: 0}; act = {c: h.c, r: ROWS - 1}; if e.shift { anc.c = act.c }; drag = "cols"; draw_all(); focus_grid(); return }
    if h.head_r and h.r >= 0 { anc = {c: 0, r: h.r}; act = {c: COLS - 1, r: h.r}; drag = "rows"; draw_all(); focus_grid(); return }
    if h.c < 0 or h.r < 0 { return }
    let dbl = time() - last_down.t < 400 and last_down.c == h.c and last_down.r == h.r
    last_down = {t: time(), c: h.c, r: h.r}
    act = {c: h.c, r: h.r}
    if not e.shift { anc = {c: h.c, r: h.r} }
    drag = "cells"
    draw_all()
    focus_grid()
    if dbl { begin_edit(cell_raw(key_of(act.c, act.r))) }
    return
  }
  if e.type == "move" {
    if drag == "resize" { sheet().colw[col_name(resize_col)] = clamp(resize_w0 + e.x - resize_x0, 24, 600); draw_grid(); return }
    if drag == "cells" and h.c >= 0 and h.r >= 0 and (h.c != act.c or h.r != act.r) { act = {c: h.c, r: h.r}; draw_grid(); draw_status(); return }
    if drag == "cols" and h.c >= 0 { act.c = h.c; draw_grid(); return }
    if drag == "rows" and h.r >= 0 { act.r = h.r; draw_grid(); return }
    return
  }
  if e.type == "up" {
    # on_mouse also reports mouseup anywhere in the window: only finish our own drags, and never redraw the
    # tabs / charts here, or a real click on a tab button would lose its element between mouseup and click
    if drag == "" { return }
    if drag == "resize" { save_book() }
    drag = ""
    draw_grid()
    draw_fx()
    draw_status()
    place_editor()
  }
})

# ----- drawing
let last_size = {w: 0, h: 0}
fn fit_text(t, w, size, font) {
  if text_width(t, size, font) <= w { return t }
  let lo = 0
  let hi = len(t)
  while lo < hi { let mid = floor((lo + hi + 1) / 2); if text_width(substr(t, 0, mid) + "…", size, font) <= w { lo = mid } else { hi = mid - 1 } }
  return substr(t, 0, lo) + "…"
}
fn draw_grid() {
  let sz = canvas_size(cv)
  let W = sz.w
  let H = sz.h
  last_size = {w: W, h: H}
  if W < 20 or H < 20 { return }
  draw_clear(cv, "#ffffff")
  let s = sel_rect()
  let xs = []
  let x = HW
  let c = sc
  while x < W and c < COLS { push(xs, {c: c, x: x, w: colw(c)}); x += colw(c); c += 1 }
  let nrows = min(ROWS - sr, ceil((H - HH) / RH))
  let cells = sheet().cells
  # cell backgrounds + selection
  for ri in range(nrows) {
    let r = sr + ri
    let y = HH + ri * RH
    for col_ in xs {
      let k = key_of(col_.c, r)
      if has(cells, k) and has(cells[k], "bg") { draw_rect(cv, col_.x, y, col_.w, RH, cells[k].bg) }
      if col_.c >= s.c0 and col_.c <= s.c1 and r >= s.r0 and r <= s.r1 and (s.c0 != s.c1 or s.r0 != s.r1) { draw_rect(cv, col_.x, y, col_.w, RH, "rgba(37,99,235,0.11)") }
    }
  }
  # grid lines
  for col_ in xs { draw_line(cv, col_.x + col_.w - 0.5, HH, col_.x + col_.w - 0.5, H, "#e3e6eb", 1) }
  for ri in range(nrows + 1) { let y = HH + ri * RH - 0.5; draw_line(cv, HW, y, W, y, "#e3e6eb", 1) }
  # text
  for ri in range(nrows) {
    let r = sr + ri
    let y = HH + ri * RH + RH / 2
    for col_ in xs {
      let k = key_of(col_.c, r)
      if not has(cells, k) { continue }
      let cell = cells[k]
      if cell.v == "" { continue }
      let v = value_of(k)
      let t = show_value(v, cell)
      if t == "" { continue }
      let font = "Segoe UI"
      if cell.b == true and cell.i == true { font = "bold italic Segoe UI" } else if cell.b == true { font = "bold Segoe UI" } else if cell.i == true { font = "italic Segoe UI" }
      let color = "#1d2129"
      if has(cell, "fg") { color = cell.fg }
      if is_err(v) { color = "#c42b1c" }
      let al = "left"
      if type(v) == "number" or type(v) == "bool" or is_err(v) { al = "right" }
      if has(cell, "al") { al = cell.al }
      t = fit_text(t, col_.w - 8, 13, font)
      if al == "right" { draw_text(cv, col_.x + col_.w - 5, y, t, color, 13, "right", font) }
      else if al == "center" { draw_text(cv, col_.x + col_.w / 2, y, t, color, 13, "center", font) }
      else { draw_text(cv, col_.x + 5, y, t, color, 13, "left", font) }
    }
  }
  # headers
  draw_rect(cv, 0, 0, W, HH, "#f3f4f6")
  draw_rect(cv, 0, 0, HW, H, "#f3f4f6")
  for col_ in xs {
    let on = col_.c >= s.c0 and col_.c <= s.c1
    if on { draw_rect(cv, col_.x, 0, col_.w, HH, "#dfe8fb") }
    draw_line(cv, col_.x + col_.w - 0.5, 0, col_.x + col_.w - 0.5, HH, "#d3d8e0", 1)
    let colr = "#4b5260"
    if on { colr = "#1d4fd7" }
    draw_text(cv, col_.x + col_.w / 2, HH / 2, col_name(col_.c), colr, 12, "center")
  }
  for ri in range(nrows) {
    let r = sr + ri
    let y = HH + ri * RH
    let on = r >= s.r0 and r <= s.r1
    if on { draw_rect(cv, 0, y, HW, RH, "#dfe8fb") }
    draw_line(cv, 0, y + RH - 0.5, HW, y + RH - 0.5, "#d3d8e0", 1)
    let colr = "#4b5260"
    if on { colr = "#1d4fd7" }
    draw_text(cv, HW / 2, y + RH / 2, str(r + 1), colr, 12, "center")
  }
  draw_line(cv, HW - 0.5, 0, HW - 0.5, H, "#c9ced8", 1)
  draw_line(cv, 0, HH - 0.5, W, HH - 0.5, "#c9ced8", 1)
  # selection outline + active cell
  let p0 = cell_pos(max(s.c0, sc), max(s.r0, sr))
  if p0 != nil and (s.c0 != s.c1 or s.r0 != s.r1) {
    let x1 = p0.x
    for i in range(max(s.c0, sc), s.c1 + 1) { x1 += colw(i) }
    let y1 = HH + (s.r1 - sr + 1) * RH
    draw_rect(cv, p0.x, p0.y, x1 - p0.x, y1 - p0.y, "#2563eb", 1)
  }
  let pa = cell_pos(act.c, act.r)
  if pa != nil { draw_rect(cv, pa.x - 1, pa.y - 1, colw(act.c) + 1, RH + 1, "#2563eb", 2); draw_rect(cv, pa.x + colw(act.c) - 4, pa.y + RH - 4, 6, 6, "#2563eb") }
}
fn draw_status() {
  clear(status)
  let s = sel_rect()
  label(status, sel_text(), "kl-sref")
  if s.c0 != s.c1 or s.r0 != s.r1 {
    let total = 0
    let n = 0
    let cnt = 0
    let cs = sheet().cells
    if (s.c1 - s.c0 + 1) * (s.r1 - s.r0 + 1) <= 5000 {
      for k in keys(cs) {
        let p = parse_ref(k)
        if p != nil and p.c >= s.c0 and p.c <= s.c1 and p.r >= s.r0 and p.r <= s.r1 {
          let v = value_of(k)
          if v != nil and v != "" { cnt += 1 }
          if type(v) == "number" { total += v; n += 1 }
        }
      }
    }
    kw_space(status)
    if n > 0 { label(status, "Average: " + gen_num(round_to(total / n, 6)) + "    Count: " + str(cnt) + "    Sum: " + gen_num(round_to(total, 6)), "") }
    else { label(status, "Count: " + str(cnt), "") }
  } else {
    kw_space(status)
    label(status, str(len(keys(sheet().cells))) + " cells used · saved on this PC", "")
  }
}
fn draw_fx() {
  settext(name_l, key_of(act.c, act.r))
  if not editing { settext(fx, cell_raw(key_of(act.c, act.r))) }
}
fn draw_tabs() {
  clear(tabs)
  for i in range(len(book.sheets)) {
    let ii = i
    let b = button(tabs, book.sheets[i].name, fn() { if editing { commit_text(gettext(ed)) }; book.active = ii; act = {c: 0, r: 0}; anc = {c: 0, r: 0}; sr = 0; sc = 0; changed() }, "kl-tab")
    togglestyle(b, "on", i == book.active)
  }
  kw_tool(tabs, "+", "Add a sheet", fn() { push(book.sheets, new_sheet("Sheet" + str(len(book.sheets) + 1))); book.active = len(book.sheets) - 1; changed() })
  kw_tool(tabs, "✎", "Rename or delete this sheet", fn() { sheet_dialog() })
  kw_space(tabs)
  let cb = kw_tool(tabs, "📊 Charts (" + str(len(sheet().charts)) + ")", "Show / hide the charts of this sheet", fn() { show_charts = not show_charts; draw_charts(); draw_tabs() })
  togglestyle(cb, "on", show_charts and len(sheet().charts) > 0)
}
fn draw_all() { draw_grid(); draw_fx(); draw_status(); place_editor(); draw_tabs(); draw_charts() }

# ----- toolbar
fn sel_keys() { return rect_keys(sel_rect()) }
fn sel_small() { let s = sel_rect(); if (s.c1 - s.c0 + 1) * (s.r1 - s.r0 + 1) > 2000 { kw_toast(root, "Select a smaller range (max 2000 cells)"); return false }; return true }
fn toggle_fmt(f) {
  if not sel_small() { return }
  let ks = sel_keys()
  let first = cell_at(ks[0])
  let on = not (first != nil and has(first, f) and first[f] == true)
  record(ks)
  for k in ks { let c = ensure_cell(k); c[f] = on }
  changed()
}
fn set_fmt(f, v) {
  if not sel_small() { return }
  let ks = sel_keys()
  record(ks)
  for k in ks { let c = ensure_cell(k); if v == nil { if has(c, f) { remove(c, f) } } else { c[f] = v } }
  changed()
}
fn clear_cells() {
  if not sel_small() { return }
  let ks = sel_keys()
  record(ks)
  for k in ks { if cell_at(k) != nil { sheet().cells[k].v = "" } }
  changed()
}
fn clear_format() {
  if not sel_small() { return }
  let ks = sel_keys()
  record(ks)
  for k in ks { let c = cell_at(k); if c != nil { sheet().cells[k] = {v: c.v} } }
  changed()
}
kw_tool(tb, "↶", "Undo (Ctrl+Z)", fn() { undo() })
kw_tool(tb, "↷", "Redo (Ctrl+Y)", fn() { redo() })
kw_sep(tb)
kw_tool(tb, "B", "Bold (Ctrl+B)", fn() { toggle_fmt("b") })
kw_tool(tb, "I", "Italic (Ctrl+I)", fn() { toggle_fmt("i") })
kw_tool(tb, "⇤", "Align left", fn() { set_fmt("al", "left") })
kw_tool(tb, "↔", "Align center", fn() { set_fmt("al", "center") })
kw_tool(tb, "⇥", "Align right", fn() { set_fmt("al", "right") })
kw_sep(tb)
let NF = [["General", "gen"], ["Number 1,234.50", "num"], ["Currency $", "cur"], ["Percent %", "pct"], ["Whole 1,235", "int"], ["Date", "date"]]
let nf_names = []
for f in NF { push(nf_names, f[0]) }
let nf_dd = dropdown(tb, nf_names, fn(ch) { for f in NF { if f[0] == ch { set_fmt("nf", f[1]) } }; focus_grid() }, "kw-dd")
settip(nf_dd, "Number format")
let COLORS = [["Text: default", ""], ["Text: red", "#c42b1c"], ["Text: green", "#0f7b0f"], ["Text: blue", "#1d4fd7"], ["Text: gray", "#6b7280"]]
let FILLS = [["Fill: none", ""], ["Fill: yellow", "#fff4c2"], ["Fill: green", "#dcf5df"], ["Fill: blue", "#e8effd"], ["Fill: red", "#fde2e0"], ["Fill: gray", "#eef0f4"]]
fn names_of(l) { let o = []; for x in l { push(o, x[0]) }; return o }
dropdown(tb, names_of(COLORS), fn(ch) { for f in COLORS { if f[0] == ch { if f[1] == "" { set_fmt("fg", nil) } else { set_fmt("fg", f[1]) } } }; focus_grid() }, "kw-dd")
dropdown(tb, names_of(FILLS), fn(ch) { for f in FILLS { if f[0] == ch { if f[1] == "" { set_fmt("bg", nil) } else { set_fmt("bg", f[1]) } } }; focus_grid() }, "kw-dd")
kw_tool(tb, "⌫ fmt", "Clear formatting", fn() { clear_format() })
kw_sep(tb)
kw_tool(tb, "Σ", "AutoSum: add a SUM below (or right of) the selection", fn() { autosum() })
kw_tool(tb, "A→Z", "Sort the selected rows by the active column", fn() { sort_sel(true) })
kw_tool(tb, "Z→A", "Sort descending", fn() { sort_sel(false) })
kw_sep(tb)
kw_tool(tb, "+Row", "Insert a row above", fn() { insert_rc("r", act.r, 1) })
kw_tool(tb, "+Col", "Insert a column left", fn() { insert_rc("c", act.c, 1) })
kw_tool(tb, "−Row", "Delete the selected rows", fn() { let s = sel_rect(); insert_rc("r", s.r0, 0 - (s.r1 - s.r0 + 1)) })
kw_tool(tb, "−Col", "Delete the selected columns", fn() { let s = sel_rect(); insert_rc("c", s.c0, 0 - (s.c1 - s.c0 + 1)) })
kw_sep(tb)
kw_tool(tb, "📊 Chart", "Make a chart from the selection", fn() { chart_dialog() })
kw_tool(tb, "ƒ", "Function list", fn() { fn_dialog() })

fn autosum() {
  let s = sel_rect()
  if s.r0 == s.r1 and s.c0 == s.c1 {
    # single cell: sum the numbers above it
    let r = act.r - 1
    while r >= 0 and type(value_of(key_of(act.c, r))) == "number" { r -= 1 }
    if r == act.r - 1 { begin_edit("=SUM()"); return }
    record([key_of(act.c, act.r)])
    set_raw(key_of(act.c, act.r), "=SUM(" + key_of(act.c, r + 1) + ":" + key_of(act.c, act.r - 1) + ")")
    changed()
    return
  }
  let ks = []
  if s.r1 > s.r0 { for c in range(s.c0, s.c1 + 1) { push(ks, key_of(c, s.r1 + 1)) } } else { push(ks, key_of(s.c1 + 1, s.r0)) }
  record(ks)
  if s.r1 > s.r0 { for c in range(s.c0, s.c1 + 1) { set_raw(key_of(c, s.r1 + 1), "=SUM(" + key_of(c, s.r0) + ":" + key_of(c, s.r1) + ")") } }
  else { set_raw(key_of(s.c1 + 1, s.r0), "=SUM(" + key_of(s.c0, s.r0) + ":" + key_of(s.c1, s.r0) + ")") }
  changed()
}
fn sort_sel(asc) {
  let s = sel_rect()
  if s.r0 == s.r1 {
    # one cell selected: sort the whole block of used rows under the header
    s = used_block()
    if s == nil { return }
  }
  if (s.r1 - s.r0 + 1) * (s.c1 - s.c0 + 1) > 5000 { kw_toast(root, "Too many cells to sort"); return }
  let rows_ = []
  for r in range(s.r0, s.r1 + 1) {
    let cellsr = []
    for c in range(s.c0, s.c1 + 1) { let cl = cell_at(key_of(c, r)); if cl == nil { push(cellsr, nil) } else { push(cellsr, parse_json(json(cl))) } }
    push(rows_, {v: value_of(key_of(act.c, r)), cells: cellsr, r: r})
  }
  let sorted = kw_sort(rows_, fn(a, b) {
    if a.v == nil and b.v != nil { return 1 }
    if b.v == nil and a.v != nil { return -1 }
    let c = compare(a.v, b.v)
    if asc { return c }
    return 0 - c
  })
  record(rect_keys(s))
  let cs = sheet().cells
  for i in range(len(sorted)) {
    for j in range(s.c1 - s.c0 + 1) {
      let k = key_of(s.c0 + j, s.r0 + i)
      let cl = sorted[i].cells[j]
      if cl == nil { if has(cs, k) { remove(cs, k) } }
      else {
        let dr = s.r0 + i - sorted[i].r
        if dr != 0 and type(cl.v) == "string" and startswith(cl.v, "=") { cl.v = move_formula(cl.v, dr, 0) }
        cs[k] = cl
      }
    }
  }
  changed()
}
fn used_block() {
  let cs = sheet().cells
  let maxr = -1
  let maxc = -1
  for k in keys(cs) { let p = parse_ref(k); if p != nil and cs[k].v != "" { maxr = max(maxr, p.r); maxc = max(maxc, p.c) } }
  if maxr < 1 { return nil }
  return {c0: 0, c1: maxc, r0: 1, r1: maxr}
}
fn insert_rc(axis, at, delta) {
  let cs = sheet().cells
  let old = parse_json(json(cs))
  let ks = keys(cs)
  let nc = {}
  for k in ks {
    let p = parse_ref(k)
    if p == nil { continue }
    let q = {c: p.c, r: p.r, ac: false, ar: false}
    if axis == "r" { if delta < 0 and p.r >= at and p.r < at - delta { continue }; if p.r >= at { q.r = p.r + delta } }
    else { if delta < 0 and p.c >= at and p.c < at - delta { continue }; if p.c >= at { q.c = p.c + delta } }
    if q.r < 0 or q.c < 0 or q.r >= ROWS or q.c >= COLS { continue }
    nc[key_of(q.c, q.r)] = cs[k]
  }
  for k in keys(nc) {
    nc[k].v = rewrite_refs(nc[k].v, fn(p) {
      let q = {c: p.c, r: p.r, ac: p.ac, ar: p.ar}
      if axis == "r" { if delta < 0 and p.r >= at and p.r < at - delta { return nil }; if p.r >= at { q.r = p.r + delta } }
      else { if delta < 0 and p.c >= at and p.c < at - delta { return nil }; if p.c >= at { q.c = p.c + delta } }
      return q
    })
  }
  push(undo_stack, {sheet: book.active, whole: old})
  sheet().cells = nc
  changed()
}
# whole-sheet undo entries (insert / delete rows and columns)
fn restore_whole(sn, into) { push(into, {sheet: sn.sheet, whole: parse_json(json(book.sheets[sn.sheet].cells))}); book.active = sn.sheet; sheet().cells = sn.whole; changed() }
fn undo() { if len(undo_stack) > 0 { let sn = pop(undo_stack); if has(sn, "whole") { restore_whole(sn, redo_stack) } else { restore(sn, redo_stack) } } }
fn redo() { if len(redo_stack) > 0 { let sn = pop(redo_stack); if has(sn, "whole") { restore_whole(sn, undo_stack) } else { restore(sn, undo_stack) } } }

# ----- clipboard (inside Lattice; formulas move their relative references)
fn copy_sel(cut) {
  if not sel_small() { return }
  let s = sel_rect()
  let items = []
  for r in range(s.r0, s.r1 + 1) { for c in range(s.c0, s.c1 + 1) { let cl = cell_at(key_of(c, r)); if cl != nil { push(items, {dr: r - s.r0, dc: c - s.c0, cell: parse_json(json(cl))}) } } }
  clip = {r0: s.r0, c0: s.c0, items: items, w: s.c1 - s.c0 + 1, h: s.r1 - s.r0 + 1}
  key_prevent(ed, NAV_KEYS + ["ctrl+v"])
  if cut { record(rect_keys(s)); for k in rect_keys(s) { if cell_at(k) != nil { remove(sheet().cells, k) } }; changed() }
  kw_toast(root, "Copied " + str(clip.w * clip.h) + " cells")
}
fn paste_clip() {
  let ks = []
  for r in range(clip.h) { for c in range(clip.w) { push(ks, key_of(act.c + c, act.r + r)) } }
  record(ks)
  for k in ks { if cell_at(k) != nil { remove(sheet().cells, k) } }
  for it in clip.items {
    let c = act.c + it.dc
    let r = act.r + it.dr
    if c >= COLS or r >= ROWS { continue }
    let cl = parse_json(json(it.cell))
    cl.v = move_formula(cl.v, act.r - clip.r0, act.c - clip.c0)
    sheet().cells[key_of(c, r)] = cl
  }
  changed()
}
fn paste_text(t) {
  let lines = split(replace(t, "\r", ""), "\n")
  if len(lines) > 0 and lines[-1] == "" { pop(lines) }
  let ks = []
  for i in range(len(lines)) { let parts = split(lines[i], "\t"); for j in range(len(parts)) { push(ks, key_of(act.c + j, act.r + i)) } }
  record(ks)
  for i in range(len(lines)) { let parts = split(lines[i], "\t"); for j in range(len(parts)) { if act.c + j < COLS and act.r + i < ROWS { set_raw(key_of(act.c + j, act.r + i), parts[j]) } } }
  changed()
}
fn fill_down() {
  let s = sel_rect()
  if s.r0 == s.r1 { return }
  let ks = rect_keys({c0: s.c0, c1: s.c1, r0: s.r0 + 1, r1: s.r1})
  record(ks)
  for c in range(s.c0, s.c1 + 1) {
    let top = cell_at(key_of(c, s.r0))
    for r in range(s.r0 + 1, s.r1 + 1) {
      if top == nil { if cell_at(key_of(c, r)) != nil { remove(sheet().cells, key_of(c, r)) }; continue }
      let cl = parse_json(json(top))
      cl.v = move_formula(cl.v, r - s.r0, 0)
      sheet().cells[key_of(c, r)] = cl
    }
  }
  changed()
}

# ----- charts
let CHART_COLORS = ["#2563eb", "#f59e0b", "#10b981", "#ef4444", "#8b5cf6", "#06b6d4", "#ec4899", "#84cc16"]
fn chart_data(ch) {
  let parts = split(ch.range, ":")
  let a = parse_ref(parts[0])
  let b = a
  if len(parts) > 1 { b = parse_ref(parts[1]) }
  if a == nil or b == nil { return nil }
  let rg = make_range(a, b)
  # first row = series names when it is text, first column = labels when it is text
  let has_head = rg.h > 1 and type(value_of(key_of(rg.c0 + rg.w - 1, rg.r0))) == "string"
  let has_lab = rg.w > 1 and type(value_of(key_of(rg.c0, rg.r0 + rg.h - 1))) == "string"
  let r_start = rg.r0
  if has_head { r_start += 1 }
  let c_start = rg.c0
  if has_lab { c_start += 1 }
  let labels = []
  for r in range(r_start, rg.r0 + rg.h) { if has_lab { push(labels, to_text(value_of(key_of(rg.c0, r)))) } else { push(labels, str(r + 1)) } }
  let series = []
  for c in range(c_start, rg.c0 + rg.w) {
    let nm = col_name(c)
    if has_head { nm = to_text(value_of(key_of(c, rg.r0))) }
    let vs = []
    for r in range(r_start, rg.r0 + rg.h) { let v = value_of(key_of(c, r)); if type(v) == "number" { push(vs, v) } else { push(vs, 0) } }
    push(series, {name: nm, vals: vs})
  }
  return {labels: labels, series: series}
}
fn draw_chart(c, ch) {
  let sz = canvas_size(c)
  let W = sz.w
  let H = sz.h
  draw_clear(c, "#ffffff")
  let d = chart_data(ch)
  if d == nil or len(d.series) == 0 or len(d.labels) == 0 { draw_text(c, W / 2, H / 2, "No numbers in " + ch.range, "#6b7280", 12, "center"); return }
  draw_text(c, W / 2, 14, ch.title, "#1d2129", 13, "center", "bold Segoe UI")
  if ch.type == "pie" {
    let vs = d.series[0].vals
    let tot = 0
    for v in vs { tot += max(0, v) }
    if tot <= 0 { return }
    let cx = W * 0.36
    let cy = H / 2 + 10
    let rr = min(W * 0.3, H / 2 - 24)
    let a0 = 0 - 1.5708
    for i in range(len(vs)) {
      let a1 = a0 + max(0, vs[i]) / tot * 6.283185
      let pts = [[cx, cy]]
      let steps = max(2, ceil((a1 - a0) * 12))
      for k in range(steps + 1) { let a = a0 + (a1 - a0) * k / steps; push(pts, [cx + cos(a) * rr, cy + sin(a) * rr]) }
      draw_poly(c, pts, CHART_COLORS[i % len(CHART_COLORS)])
      a0 = a1
    }
    for i in range(min(len(vs), 8)) {
      let y = 40 + i * 18
      draw_rect(c, W * 0.7, y - 5, 10, 10, CHART_COLORS[i % len(CHART_COLORS)])
      draw_text(c, W * 0.7 + 16, y, fit_text(d.labels[i] + " " + fixed(max(0, vs[i]) / tot * 100, 0) + "%", W * 0.3 - 20, 11, "Segoe UI"), "#1d2129", 11)
    }
    return
  }
  let lo = 0
  let hi = 0
  for s in d.series { for v in s.vals { lo = min(lo, v); hi = max(hi, v) } }
  if hi == lo { hi = lo + 1 }
  let L = 44
  let R = W - 10
  let T = 30
  let B = H - 34
  # nice ticks
  let span = hi - lo
  let step = pow(10, floor(log(span, 10)))
  if span / step > 6 { step = step * 2 }
  if span / step < 3 { step = step / 2 }
  hi = ceil(hi / step) * step
  lo = floor(lo / step) * step
  fn Y(v) { return B - (v - lo) / (hi - lo) * (B - T) }
  let t = lo
  while t <= hi + step / 2 {
    draw_line(c, L, Y(t), R, Y(t), "#eef0f4", 1)
    draw_text(c, L - 4, Y(t), gen_num(round_to(t, 6)), "#6b7280", 10, "right")
    t += step
  }
  draw_line(c, L, Y(0), R, Y(0), "#9aa1ad", 1)
  let n = len(d.labels)
  let gw = (R - L) / n
  for i in range(n) { if n <= 12 or i % ceil(n / 12) == 0 { draw_text(c, L + gw * (i + 0.5), B + 12, fit_text(d.labels[i], gw * 1.6, 10, "Segoe UI"), "#4b5260", 10, "center") } }
  let ns = len(d.series)
  for si in range(ns) {
    let s = d.series[si]
    let colr = CHART_COLORS[si % len(CHART_COLORS)]
    if ch.type == "line" {
      let pts = []
      for i in range(n) { push(pts, [L + gw * (i + 0.5), Y(s.vals[i])]) }
      draw_lines(c, pts, colr, 2.2)
      for p in pts { draw_circle(c, p[0], p[1], 3, colr) }
    } else {
      let bw = gw * 0.8 / ns
      for i in range(n) {
        let x = L + gw * i + gw * 0.1 + bw * si
        let y0 = Y(0)
        let y1 = Y(s.vals[i])
        draw_rect(c, x, min(y0, y1), max(1, bw - 1), abs(y1 - y0), colr)
      }
    }
    if ns > 1 { draw_rect(c, L + si * 90, H - 12, 9, 9, colr); draw_text(c, L + si * 90 + 13, H - 8, fit_text(s.name, 72, 10, "Segoe UI"), "#4b5260", 10) }
  }
}
fn draw_charts() {
  clear(charts_panel)
  let chs = sheet().charts
  show(charts_panel, show_charts and len(chs) > 0)
  if not show_charts or len(chs) == 0 { return }
  for i in range(len(chs)) {
    let ii = i
    let ch = chs[i]
    let card = col(charts_panel, "kl-chart")
    let h = row(card, "kl-charthead")
    label(h, ch.range, "kw-dim")
    kw_space(h)
    for t in [["bar", "▮"], ["line", "⟋"], ["pie", "◔"]] { let tt = t[0]; let b = kw_tool(h, t[1], t[0], fn() { ch.type = tt; save_book(); draw_charts() }); togglestyle(b, "on", ch.type == tt) }
    kw_tool(h, "✕", "Delete chart", fn() { remove(chs, ii); save_book(); draw_charts(); draw_tabs() })
    let holder = box(card, "kl-chartbox")
    let c = canvas(holder)
    after(30, fn() { draw_chart(c, ch) })
  }
}
fn chart_dialog() {
  let d = kw_dialog(root, "Insert chart")
  label(d.box, "Data range (labels in the first column, series names in the first row):", "kw-dim")
  let rg = textbox(d.box, "A1:B5", nil, "kw-in")
  settext(rg, sel_text())
  label(d.box, "Title", "kw-dim")
  let tt = textbox(d.box, "Chart title", nil, "kw-in")
  settext(tt, "Chart " + str(len(sheet().charts) + 1))
  let ty = dropdown(d.box, ["Bar chart", "Line chart", "Pie chart"], nil, "kw-dd")
  let r = row(d.box, "kw-drow")
  kw_space(r)
  kw_btn(r, "Cancel", fn() { d.close() }, nil)
  kw_btn(r, "Insert", fn() {
    let t = "bar"
    if getvalue(ty) == "Line chart" { t = "line" } else if getvalue(ty) == "Pie chart" { t = "pie" }
    push(sheet().charts, {type: t, range: upper(trim(gettext(rg))), title: gettext(tt)})
    show_charts = true
    save_book()
    d.close()
    draw_all()
  }, "accent")
}
fn fn_dialog() {
  let d = kw_dialog(root, "Functions")
  label(d.box, "Click one to start a formula in " + key_of(act.c, act.r) + ".", "kw-dim")
  let g = box(d.box, "kl-fngrid")
  for f in sort(FN_NAMES) { let ff = f; kw_btn(g, f, fn() { d.close(); begin_edit("=" + ff + "(") }, "small") }
}
fn sheet_dialog() {
  let d = kw_dialog(root, "Sheet")
  let nm = textbox(d.box, "Sheet name", nil, "kw-in")
  settext(nm, sheet().name)
  let r = row(d.box, "kw-drow")
  let del = kw_btn(r, "Delete sheet", fn() { remove(book.sheets, book.active); book.active = max(0, book.active - 1); d.close(); changed() }, "danger")
  enable(del, len(book.sheets) > 1)
  kw_space(r)
  kw_btn(r, "Rename", fn() { let t = trim(gettext(nm)); if t != "" { sheet().name = t }; d.close(); changed() }, "accent")
}

# ----- files: .klattice, CSV, XLSX
fn new_book() {
  let d = kw_dialog(root, "New workbook")
  label(d.box, "Start a new, empty workbook? The current one is replaced (save it first if you want to keep it).", "")
  let r = row(d.box, "kw-drow")
  kw_space(r)
  kw_btn(r, "Cancel", fn() { d.close() }, nil)
  kw_btn(r, "New workbook", fn() { book = {name: "Workbook", sheets: [new_sheet("Sheet1")], active: 0}; settext(name_box, book.name); undo_stack = []; d.close(); changed() }, "accent")
}
fn csv_parse(t) {
  let rows_ = []
  let rowv = []
  let f = ""
  let q = false
  let i = 0
  let n = len(t)
  let sep = ","
  let nl = indexof(t, "\n")
  let first = t
  if nl > 0 { first = substr(t, 0, nl) }
  if len(split(first, ";")) > len(split(first, ",")) { sep = ";" }
  if len(split(first, "\t")) > len(split(first, sep)) { sep = "\t" }
  while i < n {
    let ch = t[i]
    if q {
      if ch == "\"" { if i + 1 < n and t[i + 1] == "\"" { f = f + "\""; i += 1 } else { q = false } } else { f = f + ch }
    } else if ch == "\"" { q = true }
    else if ch == sep { push(rowv, f); f = "" }
    else if ch == "\n" { push(rowv, f); push(rows_, rowv); rowv = []; f = "" }
    else if ch != "\r" { f = f + ch }
    i += 1
  }
  if f != "" or len(rowv) > 0 { push(rowv, f); push(rows_, rowv) }
  return rows_
}
fn csv_cell(s) { if contains(s, ",") or contains(s, "\"") or contains(s, "\n") { return "\"" + replace(s, "\"", "\"\"") + "\"" }; return s }
fn sheet_bounds(sh) {
  let maxr = -1
  let maxc = -1
  for k in keys(sh.cells) { let p = parse_ref(k); if p != nil and sh.cells[k].v != "" { maxr = max(maxr, p.r); maxc = max(maxc, p.c) } }
  return {r: maxr, c: maxc}
}
fn to_csv() {
  let b = sheet_bounds(sheet())
  let lines = []
  for r in range(b.r + 1) {
    let parts = []
    for c in range(b.c + 1) { let k = key_of(c, r); let v = value_of(k); let t = ""; if v != nil { t = to_text(v); if type(v) == "number" { t = gen_num(v) } }; push(parts, csv_cell(t)) }
    push(lines, join(parts, ","))
  }
  return join(lines, "\n") + "\n"
}
fn xlsx_sheet_xml(sh, idx) {
  let saved = book.active
  book.active = idx
  recalc()
  let b = sheet_bounds(sh)
  let out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>"
  for r in range(b.r + 1) {
    out = out + "<row r=\"" + str(r + 1) + "\">"
    for c in range(b.c + 1) {
      let k = key_of(c, r)
      let cl = cell_at(k)
      if cl == nil or cl.v == "" { continue }
      let s = ""
      if cl.b == true { s = " s=\"1\"" }
      let v = value_of(k)
      if startswith(cl.v, "=") {
        let f = "<f>" + kw_esc(substr(cl.v, 1)) + "</f>"
        if type(v) == "number" { out = out + "<c r=\"" + k + "\"" + s + ">" + f + "<v>" + gen_num(v) + "</v></c>" }
        else if type(v) == "bool" { let bv = "0"; if v { bv = "1" }; out = out + "<c r=\"" + k + "\" t=\"b\"" + s + ">" + f + "<v>" + bv + "</v></c>" }
        else { out = out + "<c r=\"" + k + "\" t=\"str\"" + s + ">" + f + "<v>" + kw_esc(to_text(v)) + "</v></c>" }
      } else if type(v) == "number" { out = out + "<c r=\"" + k + "\"" + s + "><v>" + gen_num(v) + "</v></c>" }
      else if type(v) == "bool" { let bv = "0"; if v { bv = "1" }; out = out + "<c r=\"" + k + "\" t=\"b\"" + s + "><v>" + bv + "</v></c>" }
      else { out = out + "<c r=\"" + k + "\" t=\"inlineStr\"" + s + "><is><t xml:space=\"preserve\">" + kw_esc(to_text(v)) + "</t></is></c>" }
    }
    out = out + "</row>"
  }
  book.active = saved
  recalc()
  return out + "</sheetData></worksheet>"
}
fn to_xlsx() {
  let files = {}
  let n = len(book.sheets)
  let ct = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
  let wb = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
  let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
  for i in range(n) {
    let id = str(i + 1)
    ct = ct + "<Override PartName=\"/xl/worksheets/sheet" + id + ".xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
    wb = wb + "<sheet name=\"" + kw_esc(substr(book.sheets[i].name, 0, 31)) + "\" sheetId=\"" + id + "\" r:id=\"rId" + id + "\"/>"
    rels = rels + "<Relationship Id=\"rId" + id + "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet" + id + ".xml\"/>"
    files["xl/worksheets/sheet" + id + ".xml"] = xlsx_sheet_xml(book.sheets[i], i)
  }
  rels = rels + "<Relationship Id=\"rId" + str(n + 1) + "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
  files["[Content_Types].xml"] = ct + "</Types>"
  files["_rels/.rels"] = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
  files["xl/workbook.xml"] = wb + "</sheets></workbook>"
  files["xl/_rels/workbook.xml.rels"] = rels
  files["xl/styles.xml"] = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><fonts count=\"2\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font><font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts><fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills><borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs><cellXfs count=\"2\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/><xf numFmtId=\"0\" fontId=\"1\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\"/></cellXfs><cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles></styleSheet>"
  return zip_create(files, true)
}
fn xml_find(node, tag) { if node == nil { return nil }; for ch in node.children { if ch.tag == tag { return ch } }; return nil }
fn xml_all(node, tag) { let out = []; if node == nil { return out }; for ch in node.children { if ch.tag == tag { push(out, ch) } }; return out }
fn xml_text(node) {
  if node == nil { return "" }
  let s = node.text
  if s == nil { s = "" }
  for ch in node.children { s = s + xml_text(ch) }
  return s
}
fn strip_ns(t) { let i = indexof(t, ":"); if i >= 0 { return substr(t, i + 1) }; return t }
fn from_xlsx(files) {
  let wbx = xml_parse(files["xl/workbook.xml"])
  if wbx == nil { return nil }
  let rels = {}
  if has(files, "xl/_rels/workbook.xml.rels") {
    let rx = xml_parse(files["xl/_rels/workbook.xml.rels"])
    for r in rx.children { rels[r.attrs["Id"]] = r.attrs["Target"] }
  }
  let shared = []
  if has(files, "xl/sharedStrings.xml") {
    let sx = xml_parse(files["xl/sharedStrings.xml"])
    for si in sx.children { push(shared, xml_text(si)) }
  }
  let nb = {name: "Imported", sheets: [], active: 0}
  let sheets_node = nil
  for ch in wbx.children { if strip_ns(ch.tag) == "sheets" { sheets_node = ch } }
  if sheets_node == nil { return nil }
  for s in sheets_node.children {
    let rid = ""
    for k in keys(s.attrs) { if strip_ns(k) == "id" { rid = s.attrs[k] } }
    let target = "worksheets/sheet" + str(len(nb.sheets) + 1) + ".xml"
    if has(rels, rid) { target = rels[rid] }
    if startswith(target, "/") { target = substr(target, 1) } else { target = "xl/" + target }
    let sh = new_sheet(s.attrs["name"])
    if has(files, target) {
      let x = xml_parse(files[target])
      let data = nil
      for ch in x.children { if strip_ns(ch.tag) == "sheetData" { data = ch } }
      if data != nil {
        let count = 0
        for rw in data.children {
          for c in rw.children {
            if count > 20000 { break }
            let ref = c.attrs["r"]
            if ref == nil or parse_ref(ref) == nil { continue }
            let t = c.attrs["t"]
            let f = nil
            let v = nil
            for part in c.children { let tg = strip_ns(part.tag); if tg == "f" { f = xml_text(part) } else if tg == "v" { v = xml_text(part) } else if tg == "is" { v = xml_text(part) } }
            let raw = ""
            if f != nil and f != "" { raw = "=" + f }
            else if t == "s" and v != nil { let i = num(v); if i != nil and i < len(shared) { raw = shared[i] } }
            else if t == "b" { if v == "1" { raw = "TRUE" } else { raw = "FALSE" } }
            else if v != nil { raw = v }
            if raw != "" { sh.cells[ref] = {v: raw}; count += 1 }
          }
        }
      }
    }
    push(nb.sheets, sh)
  }
  if len(nb.sheets) == 0 { return nil }
  return nb
}
fn open_file() {
  let f = file_open(["klattice", "csv", "tsv", "txt", "xlsx"])
  if f == nil or not f.ok { return }
  let lname = lower(f.name)
  let base = f.name
  let dot = indexof(base, ".")
  if dot > 0 { base = substr(base, 0, dot) }
  if endswith(lname, ".klattice") {
    let d = parse_json(f.text)
    if d == nil or type(d) != "map" or not has(d, "book") { kw_toast(root, "That is not a Kugel Lattice file"); return }
    book = d.book
  } else if endswith(lname, ".xlsx") {
    let files = zip_read(f.data)
    let nb = from_xlsx(files)
    if nb == nil { kw_toast(root, "Could not read that .xlsx file"); return }
    nb.name = base
    book = nb
  } else {
    let rows_ = csv_parse(f.text)
    let sh = new_sheet(substr(base, 0, 31))
    for r in range(min(len(rows_), ROWS)) { for c in range(min(len(rows_[r]), COLS)) { if rows_[r][c] != "" { sh.cells[key_of(c, r)] = {v: rows_[r][c]} } } }
    book = {name: base, sheets: [sh], active: 0}
  }
  settext(name_box, book.name)
  undo_stack = []
  act = {c: 0, r: 0}
  anc = {c: 0, r: 0}
  sr = 0
  sc = 0
  changed()
  kw_toast(root, "Opened " + f.name)
}
fn export_dialog() {
  let d = kw_dialog(root, "Export")
  let nm = kw_safe_name(book.name)
  let r = col(d.box, "")
  kw_btn(r, "Excel workbook (.xlsx) — all sheets", fn() { d.close(); file_save(nm + ".xlsx", to_xlsx()) }, "accent")
  kw_btn(r, "CSV (.csv) — this sheet", fn() { d.close(); file_save(nm + " - " + kw_safe_name(sheet().name) + ".csv", to_csv()) }, nil)
  kw_btn(r, "Kugel Lattice (.klattice) — everything, charts too", fn() { d.close(); file_save(nm + ".klattice", json({app: "kugel-lattice", version: 1, book: book}, false)) }, nil)
}

every_ms(400, fn() { let sz = canvas_size(cv); if sz.w != last_size.w or sz.h != last_size.h { draw_grid(); place_editor() } })
stop_edit()
after(80, fn() { draw_all(); focus_grid() })
