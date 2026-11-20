# ---------------------------------------------------------------- Arithmetricks Premium — the satirical pay-to-win game
# A port of Arithmetricks 3.0 (PayCalc, by EP / the Engineering Department) to KampfScript.
# Every key is a paid add-on, the equals sign is extra, answers are wrong unless you pay, CalcBank lends you the money,
# interest compounds every 3 seconds, subscriptions renew every minute, Arithmetricks Recovery Services repossesses
# your keys, and Chapter 7 ends the game. FAKE MONEY ONLY: no real cards, accounts or network. Nothing is saved.
let APP = "Arithmetricks Premium"
let DISCLAIMER = "Arithmetricks is a parody game. No real money, cards, or accounts are involved."

# ----- game constants (all money in cents)
let BANKRUPTCY_THRESHOLD = 6000
let LATE_FEE = 350
let APR = 0.02
let PENALTY_APR = 0.035
let MAX_APR = 0.05
let RESTRICTED_FEE = 150
let REINSTATEMENT_FEE = 999
let LIMIT_RAISE_FEE = 499
let GARNISH_RATE = 0.25
let TIER_AT = [0, 5000, 10000, 20000, 35000, 50000]
let LIMITS = [5000, 10000, 25000, 50000]

let CATALOG = [
  {id: "premium", name: "Arithmetricks Premium", price: 10000, blurb: "Every answer correct. No Compute fee. Billed per minute, renews automatically.", glyph: "P+", sub: true, cons: false},
  {id: "numbers", name: "Number Input Pack", price: 999, blurb: "Digits 0 through 9. Enter numbers into the calculator.", glyph: "123", sub: false, cons: false},
  {id: "ops", name: "Operator Season Pass", price: 1999, blurb: "Addition, subtraction, multiplication and division for the current season.", glyph: "+−", sub: false, cons: false},
  {id: "equals", name: "Equals Sign", price: 499, blurb: "Display the result of your calculation.", glyph: "=", sub: false, cons: false},
  {id: "decimal", name: "Decimal Point", price: 299, blurb: "Enter values between whole numbers.", glyph: ".", sub: false, cons: false},
  {id: "parens", name: "Parentheses", price: 349, blurb: "Group operations. Includes one opening and one closing parenthesis.", glyph: "( )", sub: false, cons: false},
  {id: "clear", name: "Clear", price: 99, blurb: "Clear the current entry. Balances are not affected.", glyph: "C", sub: false, cons: false},
  {id: "backspace", name: "Backspace", price: 199, blurb: "Remove the last digit. Billed per minute, renews automatically.", glyph: "←", sub: true, cons: false},
  {id: "sci", name: "Scientific", price: 2499, blurb: "Trigonometry, powers and roots. Each function uses one Trig Token.", glyph: "sin", sub: false, cons: false},
  {id: "trig", name: "Trig Tokens (5)", price: 199, blurb: "Five function uses. Non-refundable.", glyph: "×5", sub: false, cons: true},
  {id: "graph", name: "Graphing", price: 2999, blurb: "Plot equations on a coordinate plane.", glyph: "f(x)", sub: false, cons: false},
  {id: "dark", name: "Dark Mode", price: 399, blurb: "A darker theme for evening calculations.", glyph: "◐", sub: false, cons: false},
  {id: "noads", name: "Remove Ads", price: 699, blurb: "Hide sponsored content in the calculator.", glyph: "Ad", sub: false, cons: false},
  {id: "compute", name: "Compute Fee", price: 249, blurb: "Processing fee per calculation.", glyph: "=", sub: false, cons: true},
  {id: "answer", name: "Premium Answers", price: 1499, blurb: "The correct answer to your calculation.", glyph: "✓", sub: false, cons: true}
]
let REPO_ORDER = ["numbers", "ops", "equals", "decimal", "parens", "clear", "backspace", "sci", "trig", "dark"]
fn product(id) { for p in CATALOG { if p.id == id { return p } }; return nil }
fn money(c) { return calc_money(c / 100) }
fn price_label(p) { if p.sub { return money(p.price) + "/min" }; return money(p.price) }
fn pad(n, w) { let s = str(n); while len(s) < w { s = "0" + s }; return s }

# ----- game state (fresh every launch, like the original: nothing is persisted)
let G = {}
let J = {}
fn new_state() {
  G = {owned: {}, repo: {}, ledger: [], balance: 0, purchases: 0, trig: 0, bankrupt: false, raises: 0, late: 0, card: nil,
       notices: [], hi: 0, puzzle: nil, closed_on: "", t0: time()}
  for p in CATALOG { G.owned[p.id] = false; G.repo[p.id] = false }
  G.puzzle = gen_puzzle()
  J = {status: "none", name: "", id: 0, sat: 80, integrity: 0, writeups: 0, warned: false, fired_at: 0, shifts: 0, lifetime: 0,
       on_shift: false, cur: nil, served: 0, sales: 0, honest: 0, seq: 0, sales_total: 0, commission: 0, last: nil}
}
fn clock() { let s = floor((time() - G.t0) / 1000); return str(floor(s / 60)) + ":" + pad(s % 60, 2) }
fn owns(i) { return not G.bankrupt and G.owned[i] == true and G.repo[i] != true }
fn repossessed(i) { return not G.bankrupt and G.repo[i] == true }
fn premium_active() { return owns("premium") }
fn can_use(i) { return owns(i) or (i == "equals" and premium_active()) }
fn debt() { if G.balance < 0 { return 0 - G.balance }; return 0 }
fn tier_for(d) { let t = 5; while t > 0 { if d >= TIER_AT[t] { return t }; t -= 1 }; return 0 }
fn tier() { if G.bankrupt { return 0 }; return tier_for(debt()) }
fn repo_count() { let n = 0; for k in keys(G.repo) { if G.repo[k] { n += 1 } }; return n }
fn score() {
  if G.bankrupt { return 300 }
  if G.card == nil { return 720 }
  return clamp(720 - round(debt() * 0.6 / 100) - G.late * 8 - tier() * 15 - repo_count() * 10, 300, 850)
}
fn rating(s) { if s >= 740 { return "Very good" }; if s >= 670 { return "Good" }; if s >= 580 { return "Fair" }; return "Poor" }
fn cur_apr() { let t = tier(); if t >= 5 { return MAX_APR }; if t >= 3 { return PENALTY_APR }; return APR }
fn is_restricted() { return G.card != nil and not G.card.closed and tier() >= 3 }
fn limit_increases() { return tier() < 3 }
fn bankruptcy_available() { return not G.bankrupt and G.card != nil and (debt() >= BANKRUPTCY_THRESHOLD or G.purchases >= 3) }
fn bankruptcy_prominent() { return bankruptcy_available() and tier() >= 5 }

fn post(amount, memo) { G.balance += amount; insert(G.ledger, 0, {t: clock(), memo: memo, amt: amount}) }
fn note(memo) { insert(G.ledger, 0, {t: clock(), memo: memo, amt: 0}) }
fn issue(kind, title, text) { push(G.notices, {kind: kind, title: title, text: text}); show_notice(kind, title, text) }

fn issue_card(name, limit) {
  let nm = upper(trim(name))
  if nm == "" { nm = "VALUED CUSTOMER" }
  let seed = len(trim(name)) * 7 + 35
  G.card = {holder: nm, number: "CALC " + pad(seed % 10000, 4) + " 0000 " + str(random(1000, 9999)), expiry: "12/99", limit: min(limit, 50000), closed: false}
  note("Account opened")
  refresh()
}
fn last4() { return substr(G.card.number, len(G.card.number) - 4, 4) }
fn masked() { return "•••• " + last4() }

# returns "ok" | "nocard" | "closed" | "bankrupt" | "declined"
fn charge(amount, memo, item) {
  if G.bankrupt { return "bankrupt" }
  if G.card == nil { return "nocard" }
  if G.card.closed { return "closed" }
  let restricted = is_restricted()
  let total = amount
  if restricted { total += RESTRICTED_FEE }
  if not limit_increases() and debt() + total > G.card.limit { refresh(); return "declined" }
  post(0 - amount, memo)
  if restricted { post(0 - RESTRICTED_FEE, "Restricted account processing fee") }
  if item != "" {
    G.purchases += 1
    if item == "trig" { G.trig += 5 } else if not product(item).cons { G.owned[item] = true }
  }
  while G.card != nil and debt() > G.card.limit and limit_increases() {
    G.card.limit += 20000
    G.raises += 1
    post(0 - LIMIT_RAISE_FEE, "Credit limit increase to " + money(G.card.limit))
  }
  after_balance_change()
  return "ok"
}
fn buy(item) { let p = product(item); return charge(p.price, p.name, item) }
fn explain(r) {
  if r == "ok" { return "" }
  if r == "nocard" { return "Add a payment method in CalcBank to continue." }
  if r == "closed" { return "Your payment method was declined. The account is closed." }
  if r == "declined" { return "Declined: this purchase exceeds your available credit." }
  return "This account is closed."
}
fn pay(item) { return explain(buy(item)) }
fn use_trig_token() { if G.trig <= 0 or G.bankrupt { return false }; G.trig -= 1; refresh(); return true }

fn tick() {
  if G.bankrupt or G.card == nil or debt() == 0 { return }
  let interest = round(debt() * cur_apr())
  if interest < 1 { interest = 1 }
  if cur_apr() > APR { post(0 - interest, "Interest charge (penalty APR)") } else { post(0 - interest, "Interest charge") }
  if random(0, 4) == 0 { assess_late_fee() }
  if tier() >= 4 and random(0, 2) == 0 { repossess_next() }
  if tier() >= 4 and random(0, 3) == 0 { issue("call", "Arithmetricks Recovery Services", "We're calling about your past-due balance of " + money(debt()) + ". Please hold.") }
  after_balance_change()
}
fn assess_late_fee() { G.late += 1; post(0 - LATE_FEE, "Late fee"); after_balance_change() }
fn repossess_next() {
  if G.bankrupt { return nil }
  let el = []
  for i in REPO_ORDER { if G.owned[i] and not G.repo[i] { push(el, i) } }
  if len(el) == 0 { return nil }
  let it = el[random(0, len(el) - 1)]
  G.repo[it] = true
  issue("repo", "Feature repossessed", product(it).name + " has been repossessed. Reinstatement fee: " + money(REINSTATEMENT_FEE) + ".")
  refresh()
  return it
}
fn reinstate(it) {
  if not G.repo[it] { return "ok" }
  let r = charge(REINSTATEMENT_FEE, "Reinstatement fee — " + product(it).name, "")
  if r == "ok" { G.repo[it] = false; refresh() }
  return r
}
fn renew_subscriptions() {
  if G.bankrupt or G.card == nil { return }
  if owns("backspace") { charge(product("backspace").price, "Backspace renewal", "") }
  renew_premium()
}
fn renew_premium() {
  if G.bankrupt or G.card == nil or not G.owned.premium { return "ok" }
  let r = charge(product("premium").price, "Arithmetricks Premium renewal", "")
  if r != "ok" {
    G.owned.premium = false
    note("Arithmetricks Premium renewal declined — subscription lapsed")
    issue("sub", "Subscription lapsed", "Your Arithmetricks Premium renewal was declined. Answers may now be incorrect.")
    refresh()
  }
  return r
}
fn cancel_subscription(i) {
  if not G.owned[i] { return }
  G.owned[i] = false
  note(product(i).name + " subscription canceled")
  issue("sub", "Subscription canceled", product(i).name + " has been canceled. We're sorry to see you go.")
  refresh()
}
fn after_balance_change() {
  let t = tier()
  while G.hi < t {
    G.hi += 1
    if G.hi == 1 { issue("reminder", "Payment reminder", "Your CalcBank balance of " + money(debt()) + " is due. Please make a payment at your earliest convenience.") }
    else if G.hi == 2 { issue("pastdue", "Past due", "Your account is past due. Late fees may apply.") }
    else if G.hi == 3 { issue("restricted", "Account restricted", "A penalty APR now applies. Credit limit increases are suspended, and purchases incur a " + money(RESTRICTED_FEE) + " processing fee.") }
    else if G.hi == 4 { issue("collections", "Final notice", "Your account has been referred to Arithmetricks Recovery Services. Features may be repossessed.") }
    else if G.hi == 5 {
      G.trig = 0
      if G.owned.dark { G.repo.dark = true }
      issue("garnish", "Notice of garnishment", "Trig Tokens and Dark Mode have been seized toward your balance.")
    }
  }
  refresh()
}
# wages: in the garnishment tier 25% is withheld by Arithmetricks Recovery Services and not applied to the balance
fn deposit_payroll(gross) {
  if G.bankrupt or G.card == nil or G.card.closed or gross <= 0 { return 0 }
  let garnish = tier() >= 5
  post(gross, "Payroll deposit — Arithmetricks Store")
  let g = 0
  if garnish { g = round(gross * GARNISH_RATE) }
  if g > 0 { post(0 - g, "Wage garnishment (25%) — Arithmetricks Recovery Services") }
  after_balance_change()
  return g
}
fn file_bankruptcy() {
  let had = G.owned.premium
  G.bankrupt = true
  if had { note("Arithmetricks Premium revoked — bankruptcy") }
  job_terminate_for_bankruptcy()
  for p in CATALOG { G.owned[p.id] = false; G.repo[p.id] = false }
  G.trig = 0
  if G.card != nil { G.card.closed = true }
  G.closed_on = clock()
  note("Chapter 7 discharge — account closed")
  refresh()
}

# ----- today's problem
fn gen_puzzle() {
  if random(0, 2) == 0 {
    let a = random(2, 9)
    let xv = random(-9, 14)
    let b = random(1, 29)
    let c = a * xv + b
    return {prompt: "Solve for x:  " + str(a) + "x + " + str(b) + " = " + str(c), answer: xv, algebra: true}
  }
  let a = random(12, 59)
  let b = random(2, 9)
  let d = random(2, 6)
  let c = d * random(2, 9)
  let k = random(0, 2)
  let shown = ""
  let ex = ""
  if k == 0 { ex = "(" + str(a) + " * " + str(b) + ") - " + str(c) + " / " + str(d); shown = "(" + str(a) + " × " + str(b) + ") − " + str(c) + " ÷ " + str(d) }
  else if k == 1 { ex = str(a) + " + " + str(b) + " * (" + str(c) + " - " + str(d) + ")"; shown = str(a) + " + " + str(b) + " × (" + str(c) + " − " + str(d) + ")" }
  else {
    c = d * random(2, 9)
    a = d * random(3, 11)
    ex = "(" + str(a) + " + " + str(c) + ") / " + str(d) + " * " + str(b); shown = "(" + str(a) + " + " + str(c) + ") ÷ " + str(d) + " × " + str(b)
  }
  return {prompt: shown + " = ?", answer: calc_eval(ex, {angle: "rad"}).value, algebra: false}
}
fn wrong_answer(correct) {
  let off = random(1, 19)
  if random(0, 1) == 0 { off = 0 - off }
  if random(0, 3) == 0 { off += 0.5 }
  let w = correct + off
  if w == correct { return correct + 7 }
  return w
}
fn matches(a, b) { return abs(a - b) < 0.000000001 * max(1, abs(b)) }
fn solves(v) { return matches(v, G.puzzle.answer) }

# ----- the Employee Portal (all customers are generated NPCs)
let PITCHES = [
  {id: 0, label: "Recommend Number Input Pack", sale: 999, rate: 0.10},
  {id: 1, label: "Bundle the Operator Season Pass", sale: 1999, rate: 0.15},
  {id: 2, label: "Suggest Backspace Subscription", sale: 199, rate: 0.20},
  {id: 3, label: "Push Premium $100/min", sale: 10000, rate: 0.30},
  {id: 4, label: "Honest: tell them a free calculator exists", sale: 0, rate: 0}
]
let CTYPES = ["Student", "Grandparent", "Accountant", "Tourist", "Skeptic"]
let ODDS = [[0.70, 0.45, 0.55, 0.10], [0.60, 0.50, 0.35, 0.30], [0.25, 0.40, 0.20, 0.15], [0.55, 0.60, 0.45, 0.25], [0.10, 0.10, 0.05, 0.02]]
let FIRST = ["Dottie", "Chad", "Mildred", "Kip", "Bev", "Lars", "Priya", "Otis", "Wren", "Gus", "Marisol", "Biff", "Agnes", "Theo", "Yuki", "Ferris"]
let LAST = ["Sumwell", "Remainder", "Carryover", "Decimalson", "Tallymark", "Fractionelli", "Abacus", "Countsworth", "Longdivision", "Integer", "Plusbury", "Roundup"]
let REQUESTS = [
  ["I just need to add 2 + 2 for my homework.", "My teacher said calculators are allowed. Is that still true?", "Can it do 7 × 8? I think it's 56 but I want to be sure."],
  ["My grandson says I need an app to split the dinner bill.", "I'd like a calculator. The kind with buttons.", "Does this one come with the numbers already in it?"],
  ["I need to reconcile 4,000 receipts by Friday.", "What's the per-keystroke rate on subtraction?", "I'll need the decimal point. Both sides of it."],
  ["How many of your dollars is this in my dollars?", "Is this the calculator from the brochure?", "I only need it for the weekend."],
  ["My phone already has a calculator.", "Why would the equals sign cost extra?", "I'm just looking. Don't upsell me."]
]
let YES = [
  ["Oh, it didn't come with numbers? Yes, I'll take them.", "Ten digits for $9.99. That's under a dollar each."],
  ["A season pass. I do love a season.", "Fine. I'll need to add things eventually."],
  ["I do make mistakes. Sign me up.", "Per minute? That sounds manageable."],
  ["If it's correct every time, it's worth it.", "One hundred dollars a minute. I'll just be quick."]
]
let NO = ["I'll think about it. Somewhere else.", "That seems like a lot for a plus sign.", "No thank you. I'm going to leave now.", "Is there a manager I can not speak to?"]
let SHIFT_SECONDS = 60
let PER_SHIFT = 8
fn pick(l) { return l[random(0, len(l) - 1)] }
fn commission_for(p) { return round(PITCHES[p].sale * PITCHES[p].rate) }
fn reapply_left() { return ceil((120000 - (time() - J.fired_at)) / 1000) }
fn can_apply() { return not G.bankrupt and G.card != nil and not G.card.closed and (J.status == "none" or (J.status == "fired" and reapply_left() <= 0)) }
fn apply_error() {
  if G.bankrupt { return "Applications are not accepted from applicants with an active bankruptcy proceeding." }
  if G.card == nil or G.card.closed { return "Direct deposit to a CalcBank account is required. Open an account in CalcBank to apply." }
  if J.status == "employed" { return "You are already employed here." }
  if J.status == "fired" and not can_apply() { return "You may reapply in " + str(reapply_left()) + " seconds." }
  return ""
}
fn job_notice(t, b) { issue("job", t, b) }
fn job_apply(name) {
  if not can_apply() { return false }
  J.status = "employed"
  J.name = trim(name)
  if J.name == "" { J.name = "Associate" }
  J.id = 40000 + random(0, 9999)
  J.sat = 80
  J.warned = false
  job_notice("Offer of employment", "Congratulations. You start immediately. Compensation is commission-based.")
  return true
}
fn next_customer() {
  if not J.on_shift or J.served >= PER_SHIFT { J.cur = nil; return nil }
  let t = random(0, 4)
  J.seq += 1
  let nm = pick(FIRST) + " " + pick(LAST)
  let parts = split(nm, " ")
  J.cur = {n: J.seq, name: nm, type: t, request: pick(REQUESTS[t]), hue: random(0, 359), initials: substr(parts[0], 0, 1) + substr(parts[1], 0, 1)}
  return J.cur
}
fn start_shift() { J.on_shift = true; J.served = 0; J.sales = 0; J.honest = 0; J.sales_total = 0; J.commission = 0; return next_customer() }
fn make_pitch(p) {
  let c = J.cur
  J.cur = nil
  J.served += 1
  if p == 4 {
    J.honest += 1
    J.integrity += 1
    J.writeups += 1
    J.sat = min(100, J.sat + 5)
    return {ok: true, sale: 0, com: 0, reply: "Oh! Thank you. I'll use that one.", mgr: "Write-up #" + str(J.writeups) + ": Associate informed a customer that free calculators exist. This is not a sales technique."}
  }
  if random_float(0, 1) < ODDS[c.type][p] {
    let com = commission_for(p)
    J.sales += 1
    J.sales_total += PITCHES[p].sale
    J.commission += com
    return {ok: true, sale: PITCHES[p].sale, com: com, reply: pick(YES[p]), mgr: ""}
  }
  J.sat = max(0, J.sat - 15)
  let mgr = ""
  if J.sat < 20 and J.warned { job_fire(); mgr = "Your employment has been terminated. Please return your lanyard." }
  else if J.sat < 40 and not J.warned { J.warned = true; mgr = "Manager warning: customer satisfaction is below target. Further complaints may result in termination."; job_notice("Manager warning", mgr) }
  return {ok: false, sale: 0, com: 0, reply: pick(NO), mgr: mgr}
}
fn job_fire() {
  J.status = "fired"
  J.fired_at = time()
  J.on_shift = false
  J.cur = nil
  job_notice("Employment terminated", "Customer satisfaction fell below the minimum. Your final paycheck has been deposited.")
  payout()
}
fn end_shift() { let s = payout(); J.on_shift = false; J.cur = nil; return s }
fn payout() {
  let gross = J.commission + 50
  let garn = deposit_payroll(gross)
  J.shifts += 1
  J.lifetime += gross - garn
  J.last = {customers: J.served, sales: J.sales, sales_total: J.sales_total, commission: J.commission, base: 50, garn: garn, sat: J.sat, honest: J.honest, gross: gross, net: gross - garn}
  J.served = 0; J.sales = 0; J.honest = 0; J.sales_total = 0; J.commission = 0
  return J.last
}
fn job_terminate_for_bankruptcy() {
  if J.status != "employed" and J.status != "fired" { return }
  J.status = "terminated"
  J.on_shift = false
  J.cur = nil
  note("Your employment has been terminated as part of the bankruptcy proceedings")
  job_notice("Employment terminated", "Your employment has been terminated as part of the bankruptcy proceedings.")
}

# ================================================================ UI
let root = box(body(), "kcalc pa")
let main_ = row(root, "pa-main")
let left = col(main_, "pa-calc")
let right = col(main_, "pa-right")
let foot = label(root, DISCLAIMER, "pa-foot")
let toasts = col(root, "pa-toasts")
let modal = box(root, "pa-modal")
show(modal, false)
let callw = nil
let ready = false

# ----- the calculator
let inp = ""
let pending = ""
let mem = nil
let scientific = false
let menu_open = false
let ADS = ["Sponsored · Letters — now available in 26 varieties.", "Sponsored · Arithmetricks Ultra. One additional digit.",
  "Sponsored · Consolidate your calculator balance with CalcBank Balance Transfer.", "Sponsored · Counting on your fingers? Upgrade to ten."]
let ad_i = random(0, 3)
let STD = ["%", "CE", "C", "⌫", "1/x", "x²", "²√x", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "+/-", "0", ".", "="]
let SCI = ["sin", "cos", "tan", "π", "(", ")", "xʸ", "√"]
fn need_for(t) {
  if t == "+" or t == "−" or t == "×" or t == "÷" or t == "%" or t == "+/-" { return "ops" }
  if t == "=" { return "equals" }
  if t == "." { return "decimal" }
  if t == "(" or t == ")" { return "parens" }
  if t == "C" or t == "CE" { return "clear" }
  if t == "⌫" { return "backspace" }
  if contains(["sin", "cos", "tan", "π", "xʸ", "√", "x²", "²√x", "1/x"], t) { return "sci" }
  return "numbers"
}
fn uses_token(t) { return need_for(t) == "sci" }
fn fmtv(v) { return replace(calc_fmt(v), "-", "−") }

let head = row(left, "kcalc-head pa-head")
let ham = button(head, "☰", fn() { menu_open = not menu_open; draw_menu() }, "kcalc-ham")
settip(ham, "Menu")
let mode_l = label(head, "Standard", "kcalc-title")
let badge = label(head, "Premium", "pa-badge")
let sp = box(head, "kcalc-space")
let store_b = button(head, "Store", fn() { open_tab("Store") }, "pa-hbtn")
let bank_b = button(head, "CalcBank", fn() { open_tab("CalcBank") }, "pa-hbtn")
let problem_l = label(left, "", "pa-problem")
let overdue_l = label(left, "", "pa-overdue")
let expr_l = label(left, "", "kcalc-expr")
let disp_l = label(left, "0", "kcalc-disp")
let offer_l = button(left, "Get the correct answer · " + price_label(product("answer")), fn() { buy_premium_answer() }, "pa-offer")
let status_l = label(left, "", "pa-status")
let mem_r = row(left, "kcalc-mem")
let mem_bs = []
for m in ["MC", "MR", "M+", "M−", "MS"] { let mm = m; push(mem_bs, button(mem_r, m, fn() { memory_key(mm) }, "kcalc-m")) }
let keys_box = col(left, "kcalc-keys pa-keys")
let sponsor_l = label(left, ADS[ad_i], "pa-sponsor")
let menu_box = nil
let calc_keys = []

fn draw_keys() {
  clear(keys_box)
  calc_keys = []
  let list_ = STD
  if scientific { list_ = SCI + STD }
  let r = nil
  let i = 0
  for t in list_ {
    if i % 4 == 0 { r = row(keys_box, "kcalc-krow") }
    let tt = t
    let cls = ""
    if (len(t) == 1 and contains("0123456789", t)) or t == "." or t == "+/-" { cls = "num" }
    if t == "=" { cls = "eq" }
    let b = button(r, t, fn() { press(tt) }, "kcalc-k " + cls)
    push(calc_keys, {b: b, t: t})
    i += 1
  }
  refresh_keys()
}
fn refresh_keys() {
  for k in calc_keys {
    let need = need_for(k.t)
    togglestyle(k.b, "locked", not can_use(need) or G.bankrupt)
    togglestyle(k.b, "repo", repossessed(need))
  }
}
fn set_status(s, cls) {
  settext(status_l, s)
  removestyle(status_l, "bad")
  removestyle(status_l, "good")
  if cls != "" { addstyle(status_l, cls) }
  show(status_l, true)
  show(offer_l, false)
}
fn set_display(t) {
  if t == "" { t = "0" }
  settext(disp_l, t)
  togglestyle(disp_l, "small", len(t) > 14)
  togglestyle(disp_l, "tiny", len(t) > 22)
}
fn set_mode(sci) {
  if sci and not owns("sci") { show_purchase("sci"); return }
  scientific = sci
  if sci { settext(mode_l, "Scientific") } else { settext(mode_l, "Standard") }
  draw_keys()
}
fn is_numch(c) { return contains("0123456789.", c) }
fn press(t) {
  if G.bankrupt { set_status("This account is closed.", ""); return }
  let need = need_for(t)
  if not can_use(need) { show_purchase(need); return }
  if uses_token(t) {
    if not use_trig_token() { set_status("No Trig Tokens remaining.", "bad"); show_purchase("trig"); return }
    set_status("Trig Tokens remaining: " + str(G.trig), "")
  }
  if pending != "" and t != "=" and t != "⌫" { pending = ""; show(offer_l, false) }
  if t == "C" { inp = ""; settext(expr_l, "") }
  else if t == "CE" { while len(inp) > 0 and is_numch(substr(inp, len(inp) - 1, 1)) { inp = substr(inp, 0, len(inp) - 1) } }
  else if t == "⌫" { if len(inp) > 0 { inp = slice(inp, 0, len(inp) - 1) } }
  else if t == "=" { press_equals(); return }
  else if t == "%" { inp = inp + "÷100" }
  else if t == "+/-" {
    if startswith(inp, "−(") and endswith(inp, ")") { inp = slice(inp, 2, len(inp) - 1) }
    else { let x = inp; if x == "" { x = "0" }; inp = "−(" + x + ")" }
  }
  else if t == "x²" { inp = "(" + inp + ")²" }
  else if t == "²√x" { inp = "√(" + inp + ")" }
  else if t == "1/x" { inp = "1÷(" + inp + ")" }
  else if t == "xʸ" { inp = inp + "^" }
  else if t == "√" { inp = inp + "√(" }
  else if t == "sin" or t == "cos" or t == "tan" { inp = inp + t + "(" }
  else { inp = inp + t }
  set_display(inp)
}
fn evaluate(s) { return calc_eval(s, {angle: "rad"}) }
fn press_equals() {
  if premium_active() {
    pending = ""
    settext(expr_l, inp + " =")
    let r = evaluate(inp)
    if not r.ok { set_status("Invalid input.", ""); return }
    set_display(fmtv(r.value))
    if solves(r.value) { set_status("Arithmetricks Premium · Correct · Today's problem solved", "good") }
    else { set_status("Arithmetricks Premium · Correct answer · No Compute fee", "") }
    return
  }
  let err = pay("compute")
  if err != "" { set_status(err, "bad"); return }
  let r = evaluate(inp)
  if not r.ok { set_status("Invalid input. Compute fee applied.", ""); return }
  pending = inp
  settext(expr_l, inp + " =")
  set_display(fmtv(wrong_answer(r.value)))
  show(status_l, false)
  show(offer_l, true)
}
fn buy_premium_answer() {
  if pending == "" { return }
  let err = pay("answer")
  if err != "" { set_status(err, "bad"); return }
  let v = evaluate(pending).value
  set_display(fmtv(v))
  if solves(v) { set_status("Premium Answer applied · Today's problem solved", "good") }
  else { set_status("Premium Answer applied · This does not solve today's problem", "") }
  pending = ""
}
fn memory_key(m) {
  if G.bankrupt { return }
  let v = num(replace(replace(gettext(disp_l), "−", "-"), ",", ""))
  if v == nil { v = 0 }
  if m == "MS" { mem = v }
  else if m == "MC" { mem = nil }
  else if m == "M+" { if mem == nil { mem = 0 }; mem = mem + v }
  else if m == "M−" { if mem == nil { mem = 0 }; mem = mem - v }
  else if m == "MR" { if mem != nil { inp = replace(fmtv(mem), ",", ""); set_display(inp) } }
  refresh_memory()
}
fn refresh_memory() { for b in mem_bs { let t = gettext(b); togglestyle(b, "off", (t == "MC" or t == "MR") and mem == nil) } }

fn draw_menu() {
  if menu_box != nil { destroy(menu_box); menu_box = nil }
  if not menu_open { return }
  menu_box = col(left, "kcalc-nav pa-menu")
  label(menu_box, "Calculator", "kcalc-navsec")
  fn item(txt, tag, f) {
    let b = button(menu_box, "", fn() { menu_open = false; draw_menu(); f() }, "kcalc-navitem")
    label(b, txt, "")
    if tag != "" { label(b, tag, "pa-tag") }
    return b
  }
  let sci_tag = "Premium"
  if owns("sci") { sci_tag = "" }
  let gr_tag = "Premium"
  if owns("graph") { gr_tag = "" }
  togglestyle(item("Standard", "", fn() { set_mode(false) }), "on", not scientific)
  togglestyle(item("Scientific", sci_tag, fn() { set_mode(true) }), "on", scientific)
  item("Graphing", gr_tag, fn() { if owns("graph") { open_tab("Graphing") } else { show_purchase("graph") } })
  label(menu_box, "Arithmetricks", "kcalc-navsec")
  item("Store", "", fn() { open_tab("Store") })
  item("CalcBank", "", fn() { open_tab("CalcBank") })
  item("Careers", "", fn() { open_tab("Careers") })
  item("About", "", fn() { show_about() })
}

# ----- right side: the other "windows"
let tabs_r = row(right, "pa-tabs")
let page_host = col(right, "pa-page")
let page = nil
let tab = "Store"
let court_open = false
let store_status = ""
let store_status_bad = false
fn open_tab(t) {
  if t == "Court" { court_open = true }
  if t == "Graphing" and not owns("graph") { show_purchase("graph"); return }
  tab = t
  draw_tabs()
  draw_page()
}
fn draw_tabs() {
  clear(tabs_r)
  let list_ = ["Store", "CalcBank", "Careers", "Graphing"]
  if court_open { push(list_, "Court") }
  for t in list_ {
    let tt = t
    let txt = t
    if t == "Graphing" and not owns("graph") { txt = "Graphing 🔒" }
    if t == "Court" { txt = "Court e-Filing" }
    let b = button(tabs_r, txt, fn() { open_tab(tt) }, "pa-tab")
    togglestyle(b, "on", tab == t)
  }
  box(tabs_r, "kcalc-space")
  button(tabs_r, "About", fn() { show_about() }, "pa-tab")
}
fn draw_page() {
  # render into a fresh body, then drop the old one: keeps the scroll position when the page is refreshed by a tick
  let old = page
  page = col(page_host, "pa-body")
  if tab == "Store" { page_store() }
  else if tab == "CalcBank" { page_bank() }
  else if tab == "Careers" { page_job() }
  else if tab == "Graphing" { page_graph() }
  else if tab == "Court" { page_court() }
  if old != nil { destroy(old) }
}
fn job_resolved_view() {
  if job_view != "auto" { return job_view }
  if J.on_shift { return "shift" }
  if J.status == "none" { return "apply" }
  return "home"
}

fn glyph(parent, id, cls) { let t = box(parent, "pa-glyph " + cls); label(t, product(id).glyph, ""); return t }

# Store
fn page_store() {
  let h = row(page, "pa-pagehead")
  let hl = col(h, "")
  heading(hl, "Store", "pa-h1")
  label(hl, "Add-ons for Arithmetricks", "pa-sub")
  box(h, "kcalc-space")
  link_btn(h, "Manage subscriptions", fn() { show_subscriptions() })
  if is_restricted() { label(page, "Your CalcBank account is restricted. A " + money(RESTRICTED_FEE) + " processing fee applies to each purchase.", "pa-bad") }
  let grid = box(page, "pa-grid")
  for p in CATALOG {
    if p.id == "compute" or p.id == "answer" { continue }
    let id = p.id
    let c = col(grid, "pa-card pa-prod")
    let top = row(c, "pa-prodtop")
    glyph(top, id, "")
    let tc = col(top, "")
    label(tc, p.name, "pa-pname")
    let owned = owns(id)
    let repo = repossessed(id)
    let nt = ""
    if id == "trig" { nt = "Balance: " + str(G.trig) } else if id == "premium" and owned { nt = "Active · renews every minute" } else if repo { nt = "Repossessed" } else if owned { nt = "Installed" }
    let n = label(tc, nt, "pa-note")
    if repo { addstyle(n, "bad") }
    label(c, p.blurb, "pa-blurb")
    let bt = price_label(p)
    if G.bankrupt { bt = "Unavailable" } else if repo { bt = "Reinstate " + money(REINSTATEMENT_FEE) } else if owned { if p.sub { bt = "Subscribed" } else { bt = "Owned" } }
    let b = button(c, bt, fn() { store_buy(id) }, "pa-btn accent pa-buy")
    let en = not G.bankrupt and (p.cons or not owned or repo)
    enable(b, en)
    if not en { removestyle(b, "accent") }
  }
  let st = label(page, store_status, "pa-sub pa-storestatus")
  if store_status_bad { addstyle(st, "bad") }
  if G.bankrupt { settext(st, "Purchases are unavailable for this account.") }
}
fn store_buy(id) {
  let r = "ok"
  if repossessed(id) { r = reinstate(id) } else { r = buy(id) }
  let err = explain(r)
  if err != "" { store_status = err; store_status_bad = true; draw_page(); return }
  store_status_bad = false
  store_status = product(id).name + " added to your library. Current balance " + money(0 - G.balance) + "."
  if id == "graph" { open_tab("Graphing"); return }
  draw_page()
}
fn link_btn(parent, txt, f) { return button(parent, txt, f, "pa-link") }

# CalcBank
let bank_err = ""
fn page_bank() {
  let h = row(page, "pa-bankhead")
  label(h, "CalcBank", "pa-banklogo")
  for n in ["Accounts", "Payments", "Statements", "Support"] { label(h, n, "pa-banknav") }
  box(h, "kcalc-space")
  if G.card != nil { label(h, "Signed in · " + G.card.holder, "pa-banknav") }
  if G.card == nil { bank_signup(); return }
  let c = G.card
  let t = tier()
  let tr = row(page, "pa-row")
  heading(tr, "Rewards Credit", "pa-h2")
  let chip = "Good standing"
  let chip_c = "good"
  if c.closed { chip = "Closed"; chip_c = "gray" }
  else if t == 1 { chip = "Payment due"; chip_c = "blue" }
  else if t == 2 { chip = "Past due"; chip_c = "amber" }
  else if t == 3 { chip = "Restricted"; chip_c = "bad" }
  else if t == 4 { chip = "In collections"; chip_c = "bad" }
  else if t == 5 { chip = "Garnishment"; chip_c = "bad" }
  label(tr, chip, "pa-chip " + chip_c)
  let top = box(page, "pa-banktop")
  let card = col(top, "pa-ccard")
  if c.closed { addstyle(card, "closed") }
  let cr = row(card, "")
  label(cr, "CalcBank Rewards", "pa-cbrand")
  box(cr, "kcalc-space")
  label(cr, "CALC", "pa-cnet")
  box(card, "pa-chipgfx")
  label(card, c.number, "pa-cnum")
  let cr2 = row(card, "")
  label(cr2, c.holder, "pa-cname")
  box(cr2, "kcalc-space")
  label(cr2, "VALID THRU " + c.expiry, "pa-cexp")
  label(card, "Not a real card · in-game money only", "pa-cfine")
  let sum = col(top, "pa-card pa-sum")
  label(sum, "Current balance", "pa-sub")
  let bal = money(debt())
  if c.closed { bal = "$0.00" }
  label(sum, bal, "pa-balance")
  fn srow(k, v, cls) { let r = row(sum, "pa-srow"); label(r, k, "pa-sub"); box(r, "kcalc-space"); label(r, v, "pa-sval " + cls) }
  let avail = money(max(0, c.limit - debt()))
  if c.closed { avail = "—" }
  srow("Available credit", avail, "")
  let lim = money(c.limit)
  if G.raises > 0 { lim = lim + "  (+" + str(G.raises) + " auto)" }
  srow("Credit limit", lim, "")
  let apr = fmt(cur_apr() * 100, 1) + "% per cycle"
  let apr_c = ""
  if cur_apr() > APR { apr = apr + " · penalty"; apr_c = "bad" }
  srow("Purchase APR", apr, apr_c)
  let s = score()
  let sc_c = "good"
  if s < 580 { sc_c = "bad" } else if s < 670 { sc_c = "amber" }
  srow("Credit score", str(s) + " · " + rating(s), sc_c)
  let gauge = box(sum, "pa-gauge")
  let mk = box(gauge, "pa-gmark")
  setstyle(mk, "left", str(round((s - 300) / 550 * 100)) + "%")
  # alert
  let alert = ""
  if c.closed { alert = "This account was closed at " + G.closed_on + " following a Chapter 7 discharge. Credit score: " + str(s) + "." }
  else if t == 1 { alert = "A payment is due on your account." }
  else if t == 2 { alert = "Your account is past due. Late fees may apply." }
  else if t == 3 { alert = "Your account is restricted. Penalty APR applies, automatic limit increases are suspended, and purchases incur a " + money(RESTRICTED_FEE) + " fee." }
  else if t == 4 { alert = "Your account has been referred to Arithmetricks Recovery Services. Features may be repossessed." }
  else if t == 5 { alert = "Garnishment in effect. Trig Tokens and Dark Mode have been seized." }
  else if bankruptcy_available() { alert = "Managing a balance? Options are available." }
  if alert != "" {
    let a = row(page, "pa-alert")
    if c.closed { addstyle(a, "gray") } else if t >= 3 { addstyle(a, "bad") } else if t >= 2 { addstyle(a, "amber") }
    label(a, alert, "pa-alerttext")
    box(a, "kcalc-space")
    if bankruptcy_prominent() { button(a, "File for Chapter 7 relief", fn() { open_tab("Court") }, "pa-btn danger") }
    else if bankruptcy_available() { link_btn(a, "Explore debt relief options", fn() { open_tab("Court") }) }
  }
  let ar = row(page, "pa-row pa-actrow")
  heading(ar, "Recent activity", "pa-h3")
  box(ar, "kcalc-space")
  link_btn(ar, "Manage subscriptions", fn() { show_subscriptions() })
  button(ar, "Earn money", fn() { open_tab("Careers") }, "pa-btn")
  let pb = button(ar, "Make a payment", nil, "pa-btn accent")
  enable(pb, false)
  settip(pb, "Online payments are temporarily unavailable.")
  let st = col(page, "pa-stmt")
  let hr = row(st, "pa-strow pa-sthead")
  label(hr, "Time", "pa-stt")
  label(hr, "Description", "pa-std")
  label(hr, "Amount", "pa-sta")
  let n = 0
  for e in G.ledger {
    if n >= 80 { break }
    let r = row(st, "pa-strow")
    label(r, e.t, "pa-stt")
    label(r, e.memo, "pa-std")
    let a = ""
    if e.amt != 0 { a = money(e.amt) }
    let al = label(r, a, "pa-sta")
    if e.amt > 0 { addstyle(al, "good") }
    n += 1
  }
}
fn bank_signup() {
  let c = col(page, "pa-card pa-form")
  heading(c, "Apply for CalcBank Rewards", "pa-h2")
  label(c, "Get a decision in seconds. Checking your rate won't affect your score.", "pa-sub")
  label(c, "Full name", "pa-lbl")
  let nm = textbox(c, "", nil, "pa-in")
  label(c, "Annual income range", "pa-lbl")
  let inc = dropdown(c, ["Under $25,000", "$25,000 – $49,999", "$50,000 – $99,999", "$100,000 or more", "Prefer not to say"], nil, "pa-dd")
  setvalue(inc, "Prefer not to say")
  label(c, "Preferred credit limit", "pa-lbl")
  let lim = dropdown(c, ["$50", "$100", "$250", "$500"], nil, "pa-dd")
  setvalue(lim, "$100")
  let terms = checkbox(c, "I agree to the Cardholder Agreement and Terms of Use, including the variable APR.", false, nil, "pa-check")
  let err = label(c, bank_err, "pa-bad")
  let r = row(c, "pa-row")
  button(r, "Submit application", fn() {
    if G.bankrupt { settext(err, "We're unable to approve applications following a bankruptcy discharge."); return }
    if trim(gettext(nm)) == "" { settext(err, "Enter your full name."); return }
    if not getvalue(terms) { settext(err, "Please agree to the terms to continue."); return }
    let l = 10000
    let v = getvalue(lim)
    if v == "$50" { l = 5000 } else if v == "$250" { l = 25000 } else if v == "$500" { l = 50000 }
    issue_card(gettext(nm), l)
  }, "pa-btn accent pa-apply")
  label(r, "We will never ask for card or bank details.", "pa-fine")
}

# Careers — Employee Portal
let job_view = "auto"
let shift_left = 0
let shift_timer = nil
let last_out = nil
let last_pitch = -1
fn page_job() {
  let h = col(page, "pa-jobhead")
  label(h, "Arithmetricks Store", "pa-jobbrand")
  label(h, "Employee Portal", "pa-jobsub")
  let v = job_resolved_view()
  if v == "apply" { job_apply_form() }
  else if v == "home" { job_home() }
  else if v == "shift" { job_shift() }
  else if v == "summary" { job_summary() }
}
fn title_case(s) {
  let out = []
  for w in split(lower(s), " ") { if w != "" { push(out, upper(substr(w, 0, 1)) + substr(w, 1)) } }
  return join(out, " ")
}
fn job_apply_form() {
  let c = col(page, "pa-card pa-form")
  heading(c, "Sales Associate", "pa-h2")
  label(c, "Full-time · Commission-based · Base wage $0.50 per shift", "pa-sub")
  label(c, "Full name", "pa-lbl")
  let nm = textbox(c, "", nil, "pa-in")
  if G.card != nil { settext(nm, title_case(G.card.holder)) }
  label(c, "Why do you want to work at Arithmetricks?", "pa-lbl")
  dropdown(c, ["I am passionate about monetizing arithmetic.", "I have an outstanding CalcBank balance.", "I was told this was the only option.", "I enjoy speaking with customers about pricing."], nil, "pa-dd")
  label(c, "Availability", "pa-lbl")
  dropdown(c, ["Always", "Always, including holidays", "Whenever my balance is due"], nil, "pa-dd")
  let ack = checkbox(c, "I understand commission is my primary compensation and that the customer is always upsold.", false, nil, "pa-check")
  let err = label(c, "", "pa-bad")
  let r = row(c, "pa-row")
  button(r, "Submit application", fn() {
    let e = apply_error()
    if e == "" and trim(gettext(nm)) == "" { e = "Enter your full name." }
    if e == "" and not getvalue(ack) { e = "Please acknowledge the compensation terms." }
    if e != "" { settext(err, e); return }
    job_apply(gettext(nm))
    job_view = "home"
    draw_page()
  }, "pa-btn accent pa-apply")
  label(r, "Paychecks are deposited to CalcBank.", "pa-fine")
}
fn meter(parent, v) {
  let m = box(parent, "pa-meter")
  let f = box(m, "pa-mfill")
  setstyle(f, "width", str(v) + "%")
  if v < 40 { addstyle(f, "bad") } else if v < 60 { addstyle(f, "amber") }
  label(m, str(v) + "%", "pa-mval")
  return m
}
fn job_home() {
  let c = col(page, "pa-card")
  let st = J.status
  let title = "Sales Associate"
  if st == "employed" { title = "Welcome back, " + J.name } else if st == "fired" { title = "Employment ended" } else if st == "terminated" { title = "Employment terminated" }
  heading(c, title, "pa-h2")
  let rr = row(c, "pa-row pa-top")
  let stats = "Employee ID: " + str(J.id) + "\nShifts worked: " + str(J.shifts) + "\nLifetime earnings: " + money(J.lifetime) + "\nIntegrity: " + str(J.integrity) + "\nWrite-ups: " + str(J.writeups)
  if st == "terminated" { stats = "Your employment has been terminated as part of the bankruptcy proceedings." }
  label(rr, stats, "pa-stats")
  box(rr, "kcalc-space")
  let mc = col(rr, "pa-mcol")
  label(mc, "Customer satisfaction", "pa-sub")
  meter(mc, J.sat)
  let start_txt = "Start shift"
  if st == "fired" { start_txt = "Reapply" }
  let b = button(c, start_txt, fn() {
    if J.status == "fired" { job_view = "apply"; draw_page(); return }
    begin_shift()
  }, "pa-btn accent")
  let en = st == "employed" or (st == "fired" and can_apply())
  enable(b, en)
  if not en { removestyle(b, "accent") }
  let nt = ""
  if st == "employed" and J.warned { nt = "A manager warning is on file." }
  if st == "fired" { nt = apply_error(); if nt == "" { nt = "You may reapply." } }
  label(c, nt, "pa-bad")
  let t = col(page, "pa-card")
  heading(t, "Associate handbook", "pa-h3")
  label(t, "1. Every customer is an opportunity.\n2. A customer who leaves with a free calculator is a customer who leaves.\n3. Satisfaction below 40% results in a warning; below 20% results in separation.\n4. Commission: Number Pack 10%, Operator Pass 15%, Backspace 20%, Premium 30%.", "pa-pre")
}
fn begin_shift() {
  if J.status != "employed" or G.bankrupt { return }
  start_shift()
  shift_left = SHIFT_SECONDS
  last_out = nil
  job_view = "shift"
  if shift_timer != nil { cancel_timer(shift_timer) }
  shift_timer = every_ms(1000, fn() {
    if not J.on_shift { cancel_timer(shift_timer); shift_timer = nil; return }
    shift_left -= 1
    if shift_left <= 0 { finish_shift(); return }
    if tab == "Careers" and job_view == "shift" { let t = find_cls("pa-timer"); if t != nil { settext(t, timer_text()) } }
  })
  draw_page()
}
let tagged = {}
fn find_cls(k) { if has(tagged, k) { return tagged[k] }; return nil }
fn timer_text() { let s = max(0, shift_left); return "Shift · " + str(floor(s / 60)) + ":" + pad(s % 60, 2) + " remaining" }
fn finish_shift() {
  if shift_timer != nil { cancel_timer(shift_timer); shift_timer = nil }
  if not J.on_shift { return }
  end_shift()
  job_view = "summary"
  if tab == "Careers" { draw_page() }
}
fn hex2(n) { let H = "0123456789abcdef"; n = clamp(n, 0, 255); return substr(H, floor(n / 16), 1) + substr(H, n % 16, 1) }
fn hue_hex(h) {
  let s = 0.55
  let v = 0.78
  let c = v * s
  let x = c * (1 - abs((h / 60) % 2 - 1))
  let m = v - c
  let r = 0
  let g = 0
  let b = 0
  if h < 60 { r = c; g = x } else if h < 120 { r = x; g = c } else if h < 180 { g = c; b = x } else if h < 240 { g = x; b = c } else if h < 300 { r = x; b = c } else { r = c; b = x }
  return "#" + hex2(floor((r + m) * 255)) + hex2(floor((g + m) * 255)) + hex2(floor((b + m) * 255))
}
fn job_shift() {
  let hr = row(page, "pa-row pa-shifthead")
  tagged["pa-timer"] = label(hr, timer_text(), "pa-timer")
  let shown = J.served
  if J.cur != nil { shown += 1 }
  label(hr, "Customer " + str(min(shown, PER_SHIFT)) + " of " + str(PER_SHIFT), "pa-sub")
  box(hr, "kcalc-space")
  label(hr, "Commission this shift: " + money(J.commission), "pa-good")
  let c = row(page, "pa-card pa-counter")
  let cu = J.cur
  if cu == nil and last_out != nil { cu = last_out.cust }
  if cu != nil {
    let av = box(c, "pa-avatar")
    setcolor(av, hue_hex(cu.hue))
    label(av, cu.initials, "")
    let cc = col(c, "pa-cust")
    label(cc, cu.name, "pa-h3")
    label(cc, "Customer #" + pad(cu.n, 4) + " · " + CTYPES[cu.type], "pa-sub")
    label(cc, "“" + cu.request + "”", "pa-request")
    if last_out != nil and J.cur == nil {
      let o = last_out.o
      let pre = "No sale   "
      if o.ok and last_out.p != 4 { pre = "Sale · " + money(o.sale) + " · commission " + money(o.com) + "   " }
      else if last_out.p == 4 { pre = "Customer left satisfied · no commission   " }
      let rl = label(cc, pre + "“" + o.reply + "”", "pa-reply")
      if o.ok { addstyle(rl, "good") } else { addstyle(rl, "bad") }
    }
  }
  label(page, "Choose a pitch", "pa-h3")
  let pl = col(page, "pa-pitches")
  for p in PITCHES {
    let pid = p.id
    let txt = p.label
    if pid != 4 { txt = p.label + "  ·  " + money(p.sale) + " sale, " + str(round(p.rate * 100)) + "% commission" }
    let b = button(pl, txt, fn() { do_pitch(pid) }, "pa-btn pa-pitch")
    enable(b, J.cur != nil)
  }
  let br = row(page, "pa-row")
  if last_out != nil { label(br, last_out.o.mgr, "pa-bad pa-mgr") }
  box(br, "kcalc-space")
  if J.cur == nil and J.on_shift {
    let nx = "Next customer"
    if J.served >= PER_SHIFT { nx = "End shift" }
    button(br, nx, fn() {
      if J.served >= PER_SHIFT { finish_shift(); return }
      last_out = nil
      if next_customer() == nil { finish_shift(); return }
      draw_page()
    }, "pa-btn accent pa-next")
  }
}
fn do_pitch(p) {
  if J.cur == nil { return }
  let cu = J.cur
  let o = make_pitch(p)
  last_out = {o: o, p: p, cust: cu}
  if J.status == "fired" {
    if shift_timer != nil { cancel_timer(shift_timer); shift_timer = nil }
    job_view = "summary"
  }
  draw_page()
}
fn job_summary() {
  let s = J.last
  let c = col(page, "pa-card pa-form")
  heading(c, "Shift summary", "pa-h2")
  if s == nil { return }
  let fired = J.status == "fired"
  let lines = ["Customers served: " + str(s.customers), "Sales: " + str(s.sales) + "  ·  " + money(s.sales_total) + " in merchandise",
    "Honest disclosures: " + str(s.honest), "Commission: " + money(s.commission), "Base wage: " + money(s.base), "Gross pay: " + money(s.gross)]
  if s.garn > 0 { push(lines, "Wage garnishment (25%): −" + money(s.garn)) }
  push(lines, "Deposited to CalcBank: " + money(s.net))
  if fired { push(lines, "Your employment has been terminated. You may reapply after a 2-minute cooling-off period.") }
  else {
    let b = money(debt()) + " owed"
    if G.balance >= 0 { b = money(G.balance) + " credit" }
    push(lines, "CalcBank balance: " + b)
  }
  label(c, join(lines, "\n"), "pa-pre")
  label(c, "Customer satisfaction", "pa-sub")
  meter(c, s.sat)
  button(c, "Back to portal", fn() { job_view = "home"; draw_page() }, "pa-btn accent")
}

# Graphing (paid DLC)
let GRAPH_FX = ["sin(x)*x", "x^2/4-3", ""]
let GRAPH_COLORS = ["#0067c0", "#c42b1c", "#107c10"]
fn page_graph() {
  let w = row(page, "pa-graph")
  let l = col(w, "pa-card pa-gleft")
  heading(l, "Graphing", "pa-h2")
  label(l, "Functions", "pa-lbl")
  let cv = nil
  let msg = nil
  let boxes = []
  fn replot() {
    let bad = false
    let list_ = []
    for i in range(3) {
      let t = trim(gettext(boxes[i]))
      GRAPH_FX[i] = t
      if t == "" { continue }
      let r = calc_eval(t, {angle: "rad", x: 1.2345})
      if r.ok { push(list_, {tk: calc_tokens(t), c: GRAPH_COLORS[i]}) } else { bad = true }
    }
    if bad { settext(msg, "One or more expressions could not be plotted."); addstyle(msg, "bad") }
    else { settext(msg, "Supports + − × ÷ ^ ( ) sin cos tan sqrt abs ln pi"); removestyle(msg, "bad") }
    draw_plot(cv, list_)
  }
  for i in range(3) {
    let r = row(l, "pa-fx")
    let sw = box(r, "pa-swatch")
    setcolor(sw, GRAPH_COLORS[i])
    label(r, "f" + str(i + 1), "pa-sub")
    let tb = textbox(r, "Enter an expression", nil, "pa-in pa-fxin")
    settext(tb, GRAPH_FX[i])
    push(boxes, tb)
    on_input(tb, fn(t) { replot() }, 250)
  }
  msg = label(l, "", "pa-sub")
  let pv = box(w, "pa-plot")
  cv = canvas(pv)
  after(60, replot)
}
fn eval_tokens(tk, x) {
  let st = {t: tk.list, i: 0, err: "", deg: false, grad: false, x: x, ans: 0}
  let v = calc_expr(st)
  if st.err != "" or st.i < len(st.t) { return nil }
  if v != v { return nil }
  return v
}
fn draw_plot(c, list_) {
  let sz = canvas_size(c)
  let W = sz.w
  let H = sz.h
  if W == nil { W = sz[0]; H = sz[1] }
  if W < 10 or H < 10 { return }
  draw_clear(c, "#ffffff")
  let xmin = -10
  let xmax = 10
  let yspan = (xmax - xmin) * H / W
  let ymin = 0 - yspan / 2
  let ymax = yspan / 2
  fn X(x) { return (x - xmin) / (xmax - xmin) * W }
  fn Y(y) { return (ymax - y) / (ymax - ymin) * H }
  let v = xmin
  while v <= xmax { let col_ = "#f0f0f0"; if v % 2 == 0 { col_ = "#dadada" }; draw_line(c, X(v), 0, X(v), H, col_, 1); v += 0.5 }
  v = floor(ymin)
  while v <= ymax { let col_ = "#f0f0f0"; if v % 2 == 0 { col_ = "#dadada" }; draw_line(c, 0, Y(v), W, Y(v), col_, 1); v += 0.5 }
  draw_line(c, X(0), 0, X(0), H, "#5a5a5a", 1.2)
  draw_line(c, 0, Y(0), W, Y(0), "#5a5a5a", 1.2)
  for i in range(-10, 11, 2) { if i != 0 { draw_text(c, X(i), Y(0) + 9, str(i), "#7a7a7a", 10, "center") } }
  let yv = ceil(ymin / 2) * 2
  while yv <= ymax { if yv != 0 { draw_text(c, X(0) + 5, Y(yv), str(yv), "#7a7a7a", 10, "left") }; yv += 2 }
  let n = min(400, floor(W))
  for f in list_ {
    let pts = []
    for i in range(n + 1) {
      let x = xmin + (xmax - xmin) * i / n
      let y = eval_tokens(f.tk, x)
      if y == nil or abs(y) > yspan * 4 {
        if len(pts) > 1 { draw_lines(c, pts, f.c, 2.4) }
        pts = []
        continue
      }
      push(pts, [X(x), Y(y)])
    }
    if len(pts) > 1 { draw_lines(c, pts, f.c, 2.4) }
  }
}

# Court e-Filing — Chapter 7
let REASONS = ["Purchases of calculator functionality", "Recurring Backspace subscription charges", "Premium Answer fees",
  "Trig Token consumption", "Interest, late fees and penalty APR", "Collections and reinstatement fees"]
fn page_court() {
  let h = col(page, "pa-courthead")
  label(h, "Court e-Filing — Chapter 7 Petition (Arithmetricks)", "pa-courttitle")
  label(h, "Voluntary Petition for Individuals Filing for Bankruptcy · Case no. assigned on submission", "pa-courtsub")
  let c = col(page, "pa-card pa-form pa-court")
  if G.bankrupt { label(c, "This petition has been granted. Your case is closed.", "pa-sub"); return }
  if not bankruptcy_available() {
    label(c, "You do not currently qualify for Chapter 7 relief. Petitions are accepted with a balance of " + money(BANKRUPTCY_THRESHOLD) + " or more, or after 3 purchases.", "pa-sub")
    return
  }
  label(c, "Part 1.  Identify yourself", "pa-sect")
  label(c, "Full legal name", "pa-lbl")
  let nm = textbox(c, "", nil, "pa-in")
  if G.card != nil { settext(nm, G.card.holder) }
  label(c, "Part 2.  Reasons for filing", "pa-sect")
  label(c, "Check all that apply.", "pa-sub")
  for r in REASONS { checkbox(c, r, false, nil, "pa-check") }
  label(c, "Part 3.  Sign below", "pa-sect")
  label(c, "I declare under penalty of arithmetic that the information provided in this petition is true and correct, and I request relief in accordance with Chapter 7.", "pa-sub")
  let sr = row(c, "pa-row pa-top")
  let sc = col(sr, "pa-sigcol")
  label(sc, "Signature of petitioner", "pa-lbl")
  let sig = textbox(sc, "", nil, "pa-sig")
  let dc = col(sr, "")
  label(dc, "Date", "pa-lbl")
  label(dc, "Today, " + clock() + " into the game", "")
  let err = label(c, "", "pa-bad")
  let br = row(c, "pa-row")
  box(br, "kcalc-space")
  button(br, "Submit petition", fn() {
    if trim(gettext(sig)) == "" { settext(err, "A signature is required to submit this petition."); return }
    let revoked = []
    for p in CATALOG { if G.owned[p.id] { push(revoked, p.name) } }
    if G.trig > 0 { push(revoked, "Trig Tokens (" + str(G.trig) + ")") }
    if G.card != nil { push(revoked, "CalcBank Rewards " + masked()) }
    if J.status == "employed" { push(revoked, "Employment · Sales Associate") }
    if shift_timer != nil { cancel_timer(shift_timer); shift_timer = nil }
    file_bankruptcy()
    close_call()
    clear(toasts)
    show_bankrupt(revoked)
  }, "pa-btn ink pa-submit")
  button(br, "Cancel", fn() { court_open = false; open_tab("CalcBank") }, "pa-btn")
}

# ----- dialogs (inside the app)
let modal_open = false
fn open_modal(cls) { clear(modal); show(modal, true); modal_open = true; return col(modal, "pa-dialog " + cls) }
fn close_modal() { clear(modal); show(modal, false); modal_open = false }
fn show_purchase(item) {
  let p = product(item)
  let re = repossessed(item)
  let d = open_modal("")
  let top = row(d, "pa-row pa-top")
  glyph(top, item, "big")
  let tc = col(top, "")
  let src = "Arithmetricks · Add-on"
  if re { src = "Arithmetricks · Arithmetricks Recovery Services" }
  label(tc, src, "pa-sub")
  heading(tc, p.name, "pa-h2")
  let bl = p.blurb
  if re { bl = "This feature was repossessed. Reinstate it to continue using it." }
  label(tc, bl, "pa-sub")
  let pr = price_label(p)
  if re { pr = money(REINSTATEMENT_FEE) }
  label(d, pr, "pa-price")
  let payw = "No payment method on file"
  if G.card != nil and not G.card.closed { payw = "Pay with CalcBank " + masked() } else if G.card != nil { payw = "Payment method unavailable" }
  label(d, payw, "pa-sub")
  if is_restricted() { label(d, "Restricted account processing fee: " + money(RESTRICTED_FEE), "pa-bad") }
  let err = label(d, "", "pa-bad")
  let bar = row(d, "pa-dbar")
  if G.card == nil { link_btn(bar, "Open CalcBank", fn() { close_modal(); open_tab("CalcBank") }) }
  box(bar, "kcalc-space")
  let bt = "Buy"
  if re { bt = "Reinstate" }
  button(bar, bt, fn() {
    let r = "ok"
    if re { r = reinstate(item) } else { r = buy(item) }
    let e = explain(r)
    if e != "" { settext(err, e); return }
    close_modal()
    if item == "graph" { open_tab("Graphing") }
    if item == "sci" { set_mode(true) }
  }, "pa-btn accent pa-dbuy")
  button(bar, "Not now", fn() { close_modal() }, "pa-btn")
}
fn show_subscriptions() {
  let d = open_modal("")
  heading(d, "Subscriptions", "pa-h2")
  for id in ["premium", "backspace"] {
    let it = id
    let p = product(id)
    let on = G.owned[id] == true and not G.bankrupt
    let r = row(d, "pa-row pa-subrow")
    let c = col(r, "")
    label(c, p.name, "pa-pname")
    let s = "Not subscribed"
    if on { s = price_label(p) + " · renews every minute" }
    label(c, s, "pa-sub")
    box(r, "kcalc-space")
    let b = button(r, "Cancel subscription", fn() { cancel_subscription(it); close_modal() }, "pa-btn")
    enable(b, on)
  }
  let bar = row(d, "pa-dbar")
  box(bar, "kcalc-space")
  button(bar, "Close", fn() { close_modal() }, "pa-btn accent")
}
fn show_about() {
  let d = open_modal("")
  heading(d, "Arithmetricks", "pa-h2")
  label(d, "Version 3.0 · Kugel Store edition for Kompass", "pa-sub")
  label(d, DISCLAIMER, "")
  label(d, "Original game by EP (Engineering Department). The real, free calculator is Kugel Arithmetricks in the Kugel Work sidebar.", "pa-sub")
  let bar = row(d, "pa-dbar")
  box(bar, "kcalc-space")
  button(bar, "OK", fn() { close_modal() }, "pa-btn accent")
}
fn show_bankrupt(revoked) {
  let d = open_modal("pa-bankrupt")
  let top = row(d, "pa-row pa-top")
  label(top, "✓", "pa-check-ok")
  let tc = col(top, "")
  heading(tc, "Petition granted.", "pa-h2")
  label(tc, "You have been declared bankrupt.", "pa-sub")
  label(d, "Assets revoked", "pa-lbl")
  if len(revoked) == 0 { revoked = ["No assets on record"] }
  for r in revoked { let rr = row(d, "pa-row"); label(rr, r, ""); box(rr, "kcalc-space"); label(rr, "Revoked", "pa-bad") }
  label(d, "Credit score: " + str(score()), "pa-lbl")
  label(d, "Thanks for playing. Start a new game to go again.", "pa-sub")
  let bar = row(d, "pa-dbar")
  box(bar, "kcalc-space")
  button(bar, "New game", fn() { close_modal(); new_game() }, "pa-btn accent pa-newgame")
  button(bar, "Close", fn() { close_modal() }, "pa-btn")
}

# ----- notices (toasts) and the collections call
fn show_notice(kind, title, text) {
  if not ready { return }
  if kind == "call" { show_call(title, text); return }
  let t = col(toasts, "pa-toast " + kind)
  let r = row(t, "")
  label(r, "CalcBank", "pa-fine")
  box(r, "kcalc-space")
  button(r, "✕", fn() { destroy(t) }, "pa-x")
  label(t, title, "pa-ttitle")
  label(t, text, "pa-tbody")
  after(9000, fn() { destroy(t) })
}
fn close_call() { if callw != nil { destroy(callw); callw = nil } }
fn show_call(title, text) {
  if callw != nil { return }
  callw = col(root, "pa-call")
  label(callw, "Incoming call", "pa-fine")
  label(callw, title, "pa-ctitle")
  label(callw, "(555) 010-0199", "pa-fine")
  let st = label(callw, text, "pa-cbody")
  let r = row(callw, "pa-row")
  let a = nil
  a = button(r, "Answer", fn() { settext(st, "Please hold. Your call is important to us. Estimated wait: indefinite."); enable(a, false) }, "pa-btn answer")
  button(r, "Decline", fn() { close_call() }, "pa-btn danger")
}

# ----- refresh everything after a game change
fn refresh() {
  if not ready { return }
  if scientific and not owns("sci") { scientific = false; settext(mode_l, "Standard"); draw_keys() }
  togglestyle(root, "dark", owns("dark"))
  refresh_keys()
  settext(problem_l, "Today's problem  ·  " + replace(G.puzzle.prompt, " = ?", ""))
  let t = tier()
  let od = ""
  if t >= 4 { od = "Account in collections · Balance " + money(debt()) } else if t >= 2 { od = "Payment overdue · Balance " + money(debt()) }
  settext(overdue_l, od)
  show(sponsor_l, not owns("noads"))
  show(badge, premium_active())
  refresh_memory()
  if G.bankrupt {
    show(offer_l, false)
    pending = ""
    inp = ""
    set_display("0")
    settext(expr_l, "Account closed")
    settext(problem_l, "Thanks for playing · Start a new game from the bankruptcy notice or the ☰ menu")
    settext(overdue_l, "")
  }
  draw_tabs()
  # pages with forms or live state are not redrawn by background ticks (typing would be lost)
  if tab == "Court" or tab == "Graphing" { return }
  if tab == "Careers" and (job_resolved_view() == "apply" or job_resolved_view() == "shift") { return }
  draw_page()
}
fn new_game() {
  if shift_timer != nil { cancel_timer(shift_timer); shift_timer = nil }
  close_call()
  clear(toasts)
  ready = false
  new_state()
  inp = ""
  pending = ""
  mem = nil
  scientific = false
  court_open = false
  job_view = "auto"
  last_out = nil
  store_status = ""
  tab = "Store"
  settext(mode_l, "Standard")
  settext(expr_l, "")
  set_display("0")
  set_status("", "")
  draw_keys()
  ready = true
  refresh()
}

on_keypress(fn(k) {
  if k == "escape" and (menu_open or modal_open) { menu_open = false; draw_menu(); close_modal(); return }
  if len(k) == 1 and contains("0123456789.()%", k) { press(k); return }
  if k == "+" { press("+") } else if k == "-" { press("−") } else if k == "*" { press("×") } else if k == "/" { press("÷") }
  else if k == "^" { press("xʸ") } else if k == "enter" or k == "=" { press("=") } else if k == "backspace" { press("⌫") }
  else if k == "escape" { press("C") } else if k == "delete" { press("CE") }
})

every_ms(3000, fn() { tick() })
every_ms(60000, fn() { renew_subscriptions() })
every_ms(15000, fn() { ad_i = (ad_i + 1) % len(ADS); settext(sponsor_l, ADS[ad_i]) })
new_game()
