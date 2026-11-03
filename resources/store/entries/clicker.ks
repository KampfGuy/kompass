# Kugel Clicker — click the ball, buy upgrades. A UI demo (labels, buttons, store_get / store_set).
fn css(e, m) { for k, v in m { setstyle(e, k, v) } }
let root = col(body())
css(root, {padding: 40, gap: 12, "align-items": "center", background: "#141414", color: "white", "min-height": "100%"})
let coins = store_get("coins", 0)
let per = store_get("per", 1)
let title = label(root, "🟠 Kugel Clicker")
css(title, {"font-size": 32, "font-weight": 800})
let shown = label(root, "")
css(shown, {"font-size": 22})
fn update() { settext(shown, `{coins} coins · +{per} per click`); store_set("coins", coins); store_set("per", per) }
let big = button(root, "🟠", fn() { coins += per; update() })
css(big, {"font-size": 72, padding: 20, "border-radius": 999})
button(root, "Upgrade (+1 per click) — 10 × level", fn() { if coins >= 10 * per { coins -= 10 * per; per += 1; update() } })
button(root, "Reset", fn() { coins = 0; per = 1; update() })
update()
