# ---- Kugel Blocks game runtime: the part shared by 2D and 3D games (numbers, scripts as threads, broadcasts,
# clones, variables, lists, sound, ask). Every script runs as its own thread and pauses each loop round (kb_yield).
let KB = {targets: {}, order: [], insts: [], handlers: [], vars: {}, lists: {}, shown: {}, timer0: time(), cv: nil, pen: [], pencv: nil,
  mx: 0, my: 0, mdown: false, answer: "", asking: nil, stopped: false, scale: 1, ox: 0, oy: 0, layer: 0, costume_size: {}, ready: false, project: nil, backdrop: 0, volume: 100}
fn kb_num(v) {
  if type(v) == "number" { return v }
  if type(v) == "bool" { if v { return 1 } return 0 }
  let n = num(trim(str(v)))
  if n == nil { return 0 }
  return n
}
fn kb_int(v) { return floor(kb_num(v) + 0.5) }
fn kb_str(v) {
  if type(v) == "number" { if v == floor(v) and abs(v) < 1e15 { return str(v) } return str(round(v, 6)) }
  if v == nil { return "" }
  return str(v)
}
fn kb_bool(v) {
  if type(v) == "bool" { return v }
  if type(v) == "number" { return v != 0 }
  let s = lower(kb_str(v))
  return s != "" and s != "0" and s != "false"
}
fn kb_eq(a, b) {
  let na = num(trim(kb_str(a)))
  let nb = num(trim(kb_str(b)))
  if na != nil and nb != nil { return na == nb }
  return lower(kb_str(a)) == lower(kb_str(b))
}
fn kb_lt(a, b) {
  let na = num(trim(kb_str(a)))
  let nb = num(trim(kb_str(b)))
  if na != nil and nb != nil { return na < nb }
  return lower(kb_str(a)) < lower(kb_str(b))
}
fn kb_gt(a, b) { return kb_lt(b, a) }
fn kb_div(a, b) { if kb_num(b) == 0 { return 0 } return kb_num(a) / kb_num(b) }
fn kb_mod(a, b) {
  let n = kb_num(b)
  if n == 0 { return 0 }
  let r = kb_num(a) % n
  if r < 0 and n > 0 { r += n }
  return r
}
fn kb_random(a, b) {
  let lo = kb_num(a)
  let hi = kb_num(b)
  if hi < lo { let t = lo; lo = hi; hi = t }
  if lo == floor(lo) and hi == floor(hi) { return random(lo, hi) }
  return random_float(lo, hi)
}
fn kb_letter(n, s) {
  let t = kb_str(s)
  let i = kb_int(n)
  if i < 1 or i > len(t) { return "" }
  return t[i - 1]
}
fn kb_math(op, v) {
  let x = kb_num(v)
  if op == "abs" { return abs(x) }
  if op == "floor" { return floor(x) }
  if op == "ceiling" { return ceil(x) }
  if op == "sqrt" { if x < 0 { return 0 } return sqrt(x) }
  if op == "sin" { return round(sin(x * PI / 180), 10) }
  if op == "cos" { return round(cos(x * PI / 180), 10) }
  if op == "tan" { return round(tan(x * PI / 180), 10) }
  if op == "asin" { return asin(clamp(x, -1, 1)) * 180 / PI }
  if op == "acos" { return acos(clamp(x, -1, 1)) * 180 / PI }
  if op == "atan" { return atan(x) * 180 / PI }
  if op == "ln" { if x <= 0 { return 0 } return log(x) }
  if op == "log" { if x <= 0 { return 0 } return log(x, 10) }
  if op == "e ^" { return exp(x) }
  if op == "10 ^" { return pow(10, x) }
  return x
}
fn kb_target(name) { return KB.targets[name] }
fn kb_when(target, event, arg, f) { push(KB.handlers, {target: target, event: event, arg: lower(kb_str(arg)), f: f}) }
fn kb_run(h, me) {
  let id = spawn(fn(m) { h.f(m); kb_thread_done(m) }, me)
  push(me.threads, {id: id, h: h})
  return id
}
fn kb_thread_done(me) { }
fn kb_fire(event, arg, only) {
  let ids = []
  let a = lower(kb_str(arg))
  for h in KB.handlers {
    if h.event != event { continue }
    if h.arg != "" and h.arg != a and not (event == "key" and h.arg == "any") { continue }
    for me in slice(KB.insts) {
      if me.dead or me.name != h.target { continue }
      if only != nil and me != only { continue }
      if event == "flag" and me.clone { continue }
      push(ids, kb_run(h, me))
    }
  }
  return ids
}
fn kb_yield(me) {
  if KB.stopped or me.dead { exit_thread() }
  next_frame()
  if KB.stopped or me.dead { exit_thread() }
}
fn kb_wait(me, secs) {
  let until = time() + kb_num(secs) * 1000
  kb_yield(me)
  while time() < until { kb_yield(me) }
}
fn kb_stop_all() {
  KB.stopped = true
  exit_thread()
}
fn kb_stop_others(me) {
  me.stop_gen = (me.stop_gen or 0) + 1
}
fn kb_broadcast(m) { kb_fire("msg", m, nil) }
fn kb_broadcast_wait(me, m) {
  let ids = kb_fire("msg", m, nil)
  let busy = true
  while busy {
    kb_yield(me)
    busy = false
    for id in ids { if thread_alive(id) { busy = true } }
  }
}
fn kb_clone(me, which) {
  let src = me
  if which != "myself" and which != "_myself_" {
    src = nil
    for i in KB.insts { if i.name == which and not i.clone and not i.dead { src = i } }
  }
  if src == nil or src.is_stage { return }
  let n = 0
  for i in KB.insts { if i.clone and not i.dead { n += 1 } }
  if n >= 300 { return }
  let c = kb_new_inst(src.t, src)
  kb_fire("clone", "", c)
}
fn kb_delete_clone(me) {
  if not me.clone { return }
  me.dead = true
  KB.insts = filter(KB.insts, fn(i) { return i != me })
  kb_removed(me)
  exit_thread()
}
fn kb_key(k) {
  let n = lower(kb_str(k))
  if n == "any" {
    for x in ["space", "up", "down", "left", "right", "enter", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] { if key_down(x) { return true } }
    return false
  }
  if n == "up arrow" { n = "up" }
  if n == "down arrow" { n = "down" }
  if n == "left arrow" { n = "left" }
  if n == "right arrow" { n = "right" }
  return key_down(n)
}
fn kb_timer() { return round((time() - KB.timer0) / 1000, 3) }
fn kb_reset_timer() { KB.timer0 = time() }
fn kb_ask(me, q) {
  KB.asking = {q: kb_str(q), me: me, done: false}
  if not me.is_stage { me.say = kb_str(q); me.think = false }
  kb_show_ask()
  while not KB.asking.done { kb_yield(me) }
  me.say = ""
  KB.asking = nil
}
fn kb_current(what) {
  let t = time() / 1000
  if what == "year" { return 2026 }
  if what == "second" { return floor(t % 60) }
  if what == "minute" { return floor(t / 60 % 60) }
  return 0
}
fn kb_var(me, name) {
  if has(me.vars, name) { return me.vars[name] }
  let v = KB.vars[name]
  if v == nil { return 0 }
  return v
}
fn kb_set(me, name, v) {
  if has(me.vars, name) { me.vars[name] = v } else { KB.vars[name] = v }
}
fn kb_change(me, name, d) { kb_set(me, name, kb_num(kb_var(me, name)) + kb_num(d)) }
fn kb_show_var(name, on) { KB.shown[name] = on }
fn kb_list(me, name) {
  if has(me.lists, name) { return me.lists[name] }
  if KB.lists[name] == nil { KB.lists[name] = [] }
  return KB.lists[name]
}
fn kb_list_add(me, name, v) { let l = kb_list(me, name); if len(l) < 200000 { push(l, v) } }
fn kb_list_idx(l, i) {
  if kb_str(i) == "last" { return len(l) - 1 }
  if kb_str(i) == "random" { if len(l) == 0 { return -1 } return random(0, len(l) - 1) }
  return kb_int(i) - 1
}
fn kb_list_del(me, name, i) {
  let l = kb_list(me, name)
  if kb_str(i) == "all" { while len(l) > 0 { pop(l) }; return }
  let k = kb_list_idx(l, i)
  if k >= 0 and k < len(l) { remove(l, k) }
}
fn kb_list_del_all(me, name) { let l = kb_list(me, name); while len(l) > 0 { pop(l) } }
fn kb_list_insert(me, name, i, v) {
  let l = kb_list(me, name)
  let k = kb_list_idx(l, i)
  if k >= 0 and k <= len(l) { insert(l, k, v) }
}
fn kb_list_replace(me, name, i, v) {
  let l = kb_list(me, name)
  let k = kb_list_idx(l, i)
  if k >= 0 and k < len(l) { l[k] = v }
}
fn kb_list_item(me, name, i) {
  let l = kb_list(me, name)
  let k = kb_list_idx(l, i)
  if k < 0 or k >= len(l) { return "" }
  return l[k]
}
fn kb_list_find(me, name, v) {
  let l = kb_list(me, name)
  for i, x in l { if kb_eq(x, v) { return i + 1 } }
  return 0
}
fn kb_list_has(me, name, v) { return kb_list_find(me, name, v) > 0 }
fn kb_list_text(me, name) {
  let l = kb_list(me, name)
  return join(map(l, fn(x) { return kb_str(x) }), " ")
}
fn kb_sound(me, name, wait_done) {
  if KB.volume > 0 { sound(name, KB.volume / 250) }
  if wait_done { kb_wait(me, 0.35) }
}
fn kb_note(me, n, beats) {
  let f = 440 * pow(2, (kb_num(n) - 69) / 12)
  let secs = kb_num(beats) * 0.5
  if KB.volume > 0 { beep(f, max(0.02, secs), "triangle", KB.volume / 300) }
  kb_wait(me, secs)
}
fn kb_set_volume(v) { KB.volume = clamp(kb_num(v), 0, 100) }
fn kb_show_ask() {
  if KB.ask_box != nil { destroy(KB.ask_box) }
  let r = row(KB.root)
  setstyle(r, "position", "absolute")
  setstyle(r, "left", "10%")
  setstyle(r, "right", "10%")
  setstyle(r, "bottom", 12)
  setstyle(r, "z-index", 5)
  let t = textbox(r, "type your answer and press Enter", fn(v) {
    KB.answer = v
    if KB.asking != nil { KB.asking.done = true }
    destroy(r)
    KB.ask_box = nil
  })
  setstyle(t, "flex", 1)
  focus(t)
  KB.ask_box = r
}
fn kb_answer() { return KB.answer }
fn kb_join(a, b) { return kb_str(a) + kb_str(b) }
fn kb_contains(a, b) { return has(lower(kb_str(a)), lower(kb_str(b))) }
fn kb_stop(me, what) {
  if what == "all" { kb_stop_all() }
  exit_thread()
}
fn kb_days() { return round(time() / 86400000 - 10957, 3) }
fn dv(v, d) { if v == nil { return d } return v }

