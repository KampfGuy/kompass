# ============================================================================
#  Spaceflight Sim — Original by Rough_Capital1339/CatPrinceHQ2 · Mod by KampfGuy
#  Rebuilt in KampfScript for Kompass 1.3  (open kompass://spaceflight)
#
#  The original is a 4,800-line JavaScript single-file game. This is the same
#  game idea written only with KampfScript built-ins: canvas + draw_*,
#  on_frame, key_down / on_keypress, on_mouse, slider / checkbox / dropdown,
#  store_get / store_set, template strings and the vector/math helpers.
#  Credits: game design, part list, solar system data and physics constants
#  come from the original by Rough_Capital1339 / CatPrinceHQ2 (mod: KampfGuy).
# ============================================================================

# ---------------------------------------------------------------- constants
let CELL_WORLD = 4            # world units per build-grid cell
let AU = 1496000000
let SUN_RADIUS = 3800000
let SAFE_LANDING_SPEED = 300
let ORBIT_YEAR_SECONDS = 31557600
let GM_SUN = 4 * PI * PI * AU * AU * AU / (ORBIT_YEAR_SECONDS * ORBIT_YEAR_SECONDS) * 150
let PERIOD_CAL = 10
let PLANET_GM_MULT = 10
let SOI_SCALE = 0.4
let ATMO_DRAG_K = 0.05
let PARACHUTE_DRAG_MULT = 40
let GAS_GIANT_CRUSH_DEPTH = 0.4
let WARP_LEVELS = [0, 0.1, 0.5, 1, 5, 25, 100, 1000, 10000, 100000, 1000000]
let MOON_SOI_MULT = 2.5
let ORBIT_DECAY_K = 0.00012
let LAUNCH_PAD_HEIGHT = 8
let MOUSE_PULL_ACCEL = 1500
let ION_STORAGE_CAPACITY = 100

# ---------------------------------------------------------------- solar system (data from the original)
let PLANET_DEFS = [
  {key: "mercury", name: "Mercury", color: "#9c8d7b", radius: 32000, surfG: 3.7, distAU: 0.387, periodDays: 88, solid: true, atmo: false, eccMod: 0.794},
  {key: "venus", name: "Venus", color: "#d9b96a", radius: 90000, surfG: 8.9, distAU: 0.723, periodDays: 225, solid: true, atmo: true, atmoFrac: 0.5, atmoColor: "#c9a84c", eccMod: 0.993},
  {key: "earth", name: "Earth", color: "#3f7fdb", radius: 150000, surfG: 11, distAU: 1.0, periodDays: 365.25, solid: true, atmo: true, atmoFrac: 0.3, atmoColor: "#5599dd", eccMod: 0.983},
  {key: "mars", name: "Mars", color: "#c1440e", radius: 82000, surfG: 6.0, distAU: 1.524, periodDays: 687, solid: true, atmo: true, atmoFrac: 0.15, atmoColor: "#8b4010", eccMod: 0.907},
  {key: "jupiter", name: "Jupiter", color: "#d8ac6d", radius: 950000, surfG: 48, distAU: 5.203, periodDays: 4333, solid: false, atmo: true, atmoColor: "#c49050", eccMod: 0.951},
  {key: "saturn", name: "Saturn", color: "#e3c887", radius: 800000, surfG: 32, distAU: 9.537, periodDays: 10759, solid: false, atmo: true, atmoColor: "#d4b85a", eccMod: 0.943},
  {key: "uranus", name: "Uranus", color: "#a7dede", radius: 440000, surfG: 19, distAU: 19.191, periodDays: 30687, solid: false, atmo: true, atmoColor: "#70c8c8", eccMod: 0.954},
  {key: "neptune", name: "Neptune", color: "#4f6bf6", radius: 420000, surfG: 21, distAU: 30.07, periodDays: 60190, solid: false, atmo: true, atmoColor: "#3355cc", eccMod: 0.990},
  {key: "pluto", name: "Pluto", color: "#c9b8a8", radius: 18000, surfG: 1.3, distAU: 39.48, periodDays: 90560, solid: true, atmo: false, eccMod: 0.751}
]
let MOON_DEFS = [
  {key: "moon", name: "The Moon", parent: "earth", color: "#bdbdbd", radiusMod: 0.27240, distMod: 30.15, surfG: 1.62, eccMod: 0.94510},
  {key: "phobos", name: "Phobos", parent: "mars", color: "#8a7a6a", radiusMod: 0.00332, distMod: 2.77, surfG: 0.0057, eccMod: 0.98490},
  {key: "deimos", name: "Deimos", parent: "mars", color: "#9a8a7a", radiusMod: 0.00183, distMod: 6.92, surfG: 0.003, eccMod: 0.99980},
  {key: "io", name: "Io", parent: "jupiter", color: "#e8d24a", radiusMod: 0.02548, distMod: 6.03, surfG: 1.80, eccMod: 0.99590},
  {key: "europa", name: "Europa", parent: "jupiter", color: "#d8c9a8", radiusMod: 0.02183, distMod: 9.60, surfG: 1.31, eccMod: 0.99100},
  {key: "ganymede", name: "Ganymede", parent: "jupiter", color: "#8a8478", radiusMod: 0.03684, distMod: 15.31, surfG: 1.43, eccMod: 0.99870},
  {key: "callisto", name: "Callisto", parent: "jupiter", color: "#5c5248", radiusMod: 0.03371, distMod: 26.93, surfG: 1.24, eccMod: 0.99260},
  {key: "mimas", name: "Mimas", parent: "saturn", color: "#cfcfcf", radiusMod: 0.00329, distMod: 3.19, surfG: 0.064, eccMod: 0.97980},
  {key: "enceladus", name: "Enceladus", parent: "saturn", color: "#f2f2f2", radiusMod: 0.00418, distMod: 4.09, surfG: 0.113, eccMod: 0.99530},
  {key: "tethys", name: "Tethys", parent: "saturn", color: "#d6d6ce", radiusMod: 0.00881, distMod: 5.06, surfG: 0.145, eccMod: 0.99990},
  {key: "dione", name: "Dione", parent: "saturn", color: "#c9c9c1", radiusMod: 0.00932, distMod: 6.48, surfG: 0.232, eccMod: 0.99780},
  {key: "rhea", name: "Rhea", parent: "saturn", color: "#d0d0c8", radiusMod: 0.01267, distMod: 9.05, surfG: 0.264, eccMod: 0.99900},
  {key: "titan", name: "Titan", parent: "saturn", color: "#e0b060", radiusMod: 0.04272, distMod: 20.99, surfG: 1.35, eccMod: 0.97120},
  {key: "iapetus", name: "Iapetus", parent: "saturn", color: "#a89888", radiusMod: 0.01219, distMod: 61.15, surfG: 0.223, eccMod: 0.97140},
  {key: "miranda", name: "Miranda", parent: "uranus", color: "#b8c0c0", radiusMod: 0.00923, distMod: 5.10, surfG: 0.079, eccMod: 0.99870},
  {key: "ariel", name: "Ariel", parent: "uranus", color: "#c8d0d0", radiusMod: 0.02265, distMod: 7.53, surfG: 0.269, eccMod: 0.99880},
  {key: "umbriel", name: "Umbriel", parent: "uranus", color: "#787c7c", radiusMod: 0.02288, distMod: 10.49, surfG: 0.253, eccMod: 0.99610},
  {key: "titania", name: "Titania", parent: "uranus", color: "#9098a0", radiusMod: 0.03085, distMod: 17.20, surfG: 0.379, eccMod: 0.99890},
  {key: "oberon", name: "Oberon", parent: "uranus", color: "#888078", radiusMod: 0.02979, distMod: 23.01, surfG: 0.347, eccMod: 0.99860},
  {key: "triton", name: "Triton", parent: "neptune", color: "#e8c8d8", radiusMod: 0.05465, distMod: 14.41, surfG: 0.779, eccMod: 0.99998},
  {key: "nereid", name: "Nereid", parent: "neptune", color: "#9098a8", radiusMod: 0.00697, distMod: 223.9, surfG: 0.071, eccMod: 0.25100},
  {key: "charon", name: "Charon", parent: "pluto", color: "#a8a8a8", radiusMod: 0.50997, distMod: 16.49, surfG: 0.288, eccMod: 0.99995},
  {key: "styx", name: "Styx", parent: "pluto", color: "#9c9c9c", radiusMod: 0.00421, distMod: 35.9, surfG: 0.001, eccMod: 0.99420},
  {key: "nix", name: "Nix", parent: "pluto", color: "#a4a4a4", radiusMod: 0.02104, distMod: 40.99, surfG: 0.003, eccMod: 0.99800},
  {key: "kerberos", name: "Kerberos", parent: "pluto", color: "#909090", radiusMod: 0.00799, distMod: 48.64, surfG: 0.003, eccMod: 0.99670},
  {key: "hydra", name: "Hydra", parent: "pluto", color: "#989898", radiusMod: 0.02314, distMod: 54.5, surfG: 0.003, eccMod: 0.99410}
]

fn ecc_from_mod(m) { return clamp(1 - m, 0, 0.995) }

let SUN = {key: "sun", name: "Sun", parent: nil, radius: SUN_RADIUS, color: "#ffb020", GM: GM_SUN, solid: false, atmo: false, depth: 0, distance: 0, ecc: 0}
let BODIES = [SUN]          # parents always come before their moons
let BY = {sun: SUN}
for i, p in PLANET_DEFS {
  p.parent = "sun"; p.depth = 1
  p.distance = p.distAU * AU
  p.GMbase = p.surfG * p.radius * p.radius
  p.GM = p.GMbase * PLANET_GM_MULT
  p.omega = TAU / ((p.periodDays / 365.25) * ORBIT_YEAR_SECONDS / sqrt(PERIOD_CAL))
  p.initialAngle = i / len(PLANET_DEFS) * TAU
  p.soi = max(p.radius * 3, p.distance * pow(p.GMbase / (3 * GM_SUN), 1 / 3) * SOI_SCALE)
  p.ecc = ecc_from_mod(p.eccMod)
  if p.atmoFrac == nil { p.atmoFrac = 0 }
  push(BODIES, p); BY[p.key] = p
}
let moon_seed = 0
for m in MOON_DEFS {
  let parent = BY[m.parent]
  m.depth = 2; m.solid = true; m.atmo = false; m.atmoFrac = 0
  m.radius = m.radiusMod * parent.radius
  m.distance = m.distMod * parent.radius
  m.GMbase = m.surfG * m.radius * m.radius
  m.GM = m.GMbase * PLANET_GM_MULT
  m.omega = sqrt(parent.GM / (m.distance * m.distance * m.distance))
  m.initialAngle = (moon_seed % 7) / 7 * TAU
  moon_seed += 1
  m.soi = max(m.radius * 3, m.distance * pow(m.GMbase / (3 * parent.GM), 1 / 3) * SOI_SCALE) * MOON_SOI_MULT
  m.ecc = ecc_from_mod(m.eccMod)
  push(BODIES, m); BY[m.key] = m
}
SUN.soi = 3.5 * BY.pluto.distance
let EARTH = BY.earth
let EARTH_G = EARTH.GM / (EARTH.radius * EARTH.radius)
let CHILDREN = {}
for b in BODIES { CHILDREN[b.key] = [] }
for b in BODIES { if b.parent != nil { push(CHILDREN[b.parent], b) } }

# positions / velocities of every body at sim time t (Kepler orbits, like the original)
let POS = {}
let VEL = {}
fn kepler(M, e) {
  let E = M
  for i in 7 { E -= (E - e * sin(E) - M) / (1 - e * cos(E)) }
  return E
}
fn update_bodies(t) {
  POS.sun = {x: 0, y: 0}
  VEL.sun = {x: 0, y: 0}
  for b in BODIES {
    if b.parent == nil { continue }
    let pp = POS[b.parent]
    let pv = VEL[b.parent]
    let M = (b.initialAngle + b.omega * t) % TAU
    let e = b.ecc
    let r = b.distance
    let th = M
    let drdt = 0
    let dth = b.omega
    if e > 0.0001 {
      let E = kepler(M, e)
      let cE = cos(E)
      let sE = sin(E)
      r = b.distance * (1 - e * cE)
      th = 2 * atan2(sqrt(1 + e) * sin(E / 2), sqrt(1 - e) * cos(E / 2))
      let dEdt = b.omega / (1 - e * cE)
      drdt = b.distance * e * sE * dEdt
      dth = sqrt(1 - e * e) * b.omega / ((1 - e * cE) * (1 - e * cE))
    }
    let ct = cos(th)
    let st = sin(th)
    POS[b.key] = {x: pp.x + r * ct, y: pp.y + r * st}
    VEL[b.key] = {x: pv.x + drdt * ct - r * dth * st, y: pv.y + drdt * st + r * dth * ct}
  }
}

# ---------------------------------------------------------------- parts (data from the original)
let PARTS = {
  pod: {name: "Command Pod", w: 2, h: 2, dryMass: 320, fuel: 0, thrust: 0, fuelRate: 0, color: "#1e1e22", type: "pod", cat: "Command"},
  probeS: {name: "Probe Core — Tiny", w: 2, h: 1, dryMass: 40, fuel: 0, thrust: 0, fuelRate: 0, color: "#4a5568", type: "probe", cat: "Command"},
  probeM: {name: "Probe Core — Med", w: 2, h: 2, dryMass: 80, fuel: 0, thrust: 0, fuelRate: 0, color: "#3d4a5c", type: "probe", cat: "Command"},
  probeL: {name: "Probe Core — Big", w: 4, h: 2, dryMass: 160, fuel: 0, thrust: 0, fuelRate: 0, color: "#2f3a48", type: "probe", cat: "Command"},
  tankS: {name: "Fuel Tank — Small", w: 2, h: 4, dryMass: 400, fuel: 1600, thrust: 0, fuelRate: 0, color: "#c7cdd6", type: "tank", cat: "Fuel"},
  tankM: {name: "Fuel Tank — Medium", w: 4, h: 6, dryMass: 650, fuel: 7000, thrust: 0, fuelRate: 0, color: "#aab2bd", type: "tank", cat: "Fuel"},
  tankL: {name: "Fuel Tank — Large", w: 4, h: 8, dryMass: 1000, fuel: 20000, thrust: 0, fuelRate: 0, color: "#8d96a3", type: "tank", cat: "Fuel"},
  solidFuel: {name: "Solid Fuel", w: 2, h: 1, dryMass: 80, fuel: 800, thrust: 0, fuelRate: 0, color: "#c45c26", type: "solidfuel", cat: "SRB"},
  adapt42: {name: "Adapter Tank 4→2", w: 4, h: 2, dryMass: 280, fuel: 1600, thrust: 0, fuelRate: 0, color: "#b0b8c2", type: "tank", adapter: true, topW: 2, botW: 4, cat: "Fuel"},
  adapt24: {name: "Adapter Tank 2→4", w: 4, h: 2, dryMass: 280, fuel: 1600, thrust: 0, fuelRate: 0, color: "#a8b0ba", type: "tank", adapter: true, topW: 4, botW: 2, cat: "Fuel"},
  adapt21: {name: "Adapter Tank 2→1", w: 2, h: 2, dryMass: 140, fuel: 700, thrust: 0, fuelRate: 0, color: "#bcc4cc", type: "tank", adapter: true, topW: 1, botW: 2, cat: "Fuel"},
  monoprop: {name: "Monoprop Tank", w: 2, h: 2, dryMass: 90, fuel: 400, thrust: 0, fuelRate: 0, color: "#d4a0c8", type: "tank", cat: "Fuel"},
  engB: {name: "Basic Engine", w: 2, h: 3, dryMass: 450, fuel: 0, thrust: 680000, fuelRate: 200, color: "#1a1a1a", type: "engine", cat: "Engines"},
  engM: {name: "Medium Engine", w: 2, h: 3, dryMass: 520, fuel: 0, thrust: 1600000, fuelRate: 480, color: "#141414", type: "engine", cat: "Engines"},
  engA: {name: "Advanced Engine", w: 4, h: 3, dryMass: 700, fuel: 0, thrust: 4800000, fuelRate: 1500, color: "#0e0e0e", type: "engine", cat: "Engines"},
  ionEngine: {name: "Ion Engine", w: 1, h: 1, dryMass: 40, fuel: 0, thrust: 3000, fuelRate: 0.25, color: "#8fe6ff", type: "engine", cat: "Engines", ionOnly: true},
  srbS: {name: "SRB — Small", w: 2, h: 4, dryMass: 300, fuel: 2200, thrust: 900000, fuelRate: 180, color: "#c45c26", type: "srb", cat: "SRB"},
  srbM: {name: "SRB — Medium", w: 2, h: 6, dryMass: 500, fuel: 4800, thrust: 1600000, fuelRate: 320, color: "#b84e1c", type: "srb", cat: "SRB"},
  srbL: {name: "SRB — Large", w: 4, h: 8, dryMass: 900, fuel: 11000, thrust: 3200000, fuelRate: 700, color: "#a34014", type: "srb", cat: "SRB"},
  srbT: {name: "SRB — Tiny Strap", w: 2, h: 3, dryMass: 180, fuel: 900, thrust: 500000, fuelRate: 120, color: "#d46830", type: "srb", cat: "SRB"},
  sep: {name: "Separator", w: 4, h: 1, dryMass: 80, fuel: 0, thrust: 0, fuelRate: 0, color: "#333333", type: "separator", cat: "Staging"},
  sepS: {name: "Separator — Small", w: 2, h: 1, dryMass: 45, fuel: 0, thrust: 0, fuelRate: 0, color: "#2a2a2a", type: "separator", cat: "Staging"},
  sideSep: {name: "Side Separator", w: 1, h: 2, dryMass: 50, fuel: 0, thrust: 0, fuelRate: 0, color: "#2e2e36", type: "sidesep", cat: "Staging"},
  chute: {name: "Parachute", w: 2, h: 1, dryMass: 55, fuel: 0, thrust: 0, fuelRate: 0, color: "#f2f2f2", type: "chute", cat: "Aero"},
  fairS: {name: "Fairing — Small", w: 2, h: 3, dryMass: 60, fuel: 0, thrust: 0, fuelRate: 0, color: "#d0d6de", type: "fairing", cat: "Aero", dragMult: 0.5},
  fairM: {name: "Fairing — Medium", w: 4, h: 4, dryMass: 120, fuel: 0, thrust: 0, fuelRate: 0, color: "#c4cad2", type: "fairing", cat: "Aero", dragMult: 0.45},
  fairL: {name: "Fairing — Large", w: 4, h: 6, dryMass: 200, fuel: 0, thrust: 0, fuelRate: 0, color: "#b8bec6", type: "fairing", cat: "Aero", dragMult: 0.4},
  fairTip: {name: "Fairing Cone Tip", w: 2, h: 2, dryMass: 40, fuel: 0, thrust: 0, fuelRate: 0, color: "#e0e4ea", type: "fairing", cat: "Aero", dragMult: 0.35, tip: true},
  heat: {name: "Heat Shield", w: 2, h: 1, dryMass: 110, fuel: 0, thrust: 0, fuelRate: 0, color: "#5c4033", type: "heatshield", cat: "Aero", dragMult: 0.85},
  coneS: {name: "Nose Cone — Small", w: 2, h: 2, dryMass: 100, fuel: 0, thrust: 0, fuelRate: 0, color: "#d9d9d9", type: "cone", cat: "Aero", dragMult: 0.7},
  coneM: {name: "Nose Cone — Medium", w: 4, h: 3, dryMass: 180, fuel: 0, thrust: 0, fuelRate: 0, color: "#cfcfcf", type: "cone", cat: "Aero", dragMult: 0.55},
  coneL: {name: "Nose Cone — Large", w: 4, h: 4, dryMass: 260, fuel: 0, thrust: 0, fuelRate: 0, color: "#c4c4c4", type: "cone", cat: "Aero", dragMult: 0.4},
  dock: {name: "Docking Port", w: 2, h: 1, dryMass: 60, fuel: 0, thrust: 0, fuelRate: 0, color: "#9a9a9a", type: "dock", cat: "Utility"},
  rcs: {name: "RCS Thruster", w: 1, h: 2, dryMass: 55, fuel: 0, thrust: 90000, fuelRate: 2.5, color: "#8a9aa8", type: "rcs", cat: "Utility"},
  wheel: {name: "Wheel", w: 2, h: 2, dryMass: 150, fuel: 0, thrust: 0, fuelRate: 0, color: "#3a3a3a", type: "wheel", cat: "Utility"},
  legs: {name: "Landing Legs", w: 2, h: 2, dryMass: 90, fuel: 0, thrust: 0, fuelRate: 0, color: "#6a6e74", type: "legs", cat: "Utility"},
  drill: {name: "Ice Drill", w: 2, h: 3, dryMass: 220, fuel: 0, thrust: 0, fuelRate: 0, color: "#6b7c3a", type: "drill", cat: "Utility"},
  solar: {name: "Solar Panel", w: 4, h: 1, dryMass: 45, fuel: 0, thrust: 0, fuelRate: 0, color: "#1a3a7a", type: "solar", cat: "Utility"},
  battery: {name: "Battery Pack", w: 2, h: 2, dryMass: 80, fuel: 0, thrust: 0, fuelRate: 0, color: "#2a5a3a", type: "battery", cat: "Utility"},
  ionStorage: {name: "Ion Storage", w: 2, h: 2, dryMass: 80, fuel: 0, thrust: 0, fuelRate: 0, color: "#2a5a3a", type: "ionstorage", cat: "Utility"},
  antenna: {name: "Comm Antenna", w: 2, h: 2, dryMass: 35, fuel: 0, thrust: 0, fuelRate: 0, color: "#c8cdd4", type: "antenna", cat: "Utility"},
  science: {name: "Science Bay", w: 2, h: 2, dryMass: 110, fuel: 0, thrust: 0, fuelRate: 0, color: "#f0f2f5", type: "science", cat: "Utility"},
  strut: {name: "Structural Strut", w: 1, h: 3, dryMass: 40, fuel: 0, thrust: 0, fuelRate: 0, color: "#8a9098", type: "strut", cat: "Utility"}
}
let PART_CATS = ["All", "Command", "Fuel", "Engines", "SRB", "Staging", "Aero", "Utility"]
fn is_engine(t) { return t == "engine" or t == "srb" }
fn is_fuel(t) { return t == "tank" or t == "srb" or t == "solidfuel" }

# ---------------------------------------------------------------- formatting
fn fmt_scaled(v, d) {
  let a = abs(v)
  if d == nil { d = 1 }
  for s in [[1e21, "Sx"], [1e18, "Qn"], [1e15, "Qd"], [1e12, "Tr"], [1e9, "B"], [1e6, "M"], [1e3, "k"]] {
    if a >= s[0] { return fmt(v / s[0], d) + s[1] }
  }
  return fmt(v, 0)
}
fn fmt_dist(v) { return fmt_scaled(v, 2) + " u" }
fn fmt_speed(v) { return fmt_scaled(v, 1) + " m/s" }
fn fmt_warp(w) {
  if w >= 1000000 { return str(w / 1000000) + "M×" }
  if w >= 1000 { return str(w / 1000) + "k×" }
  return str(w) + "×"
}

# ---------------------------------------------------------------- theme (light / dark mode, like the original)
let LIGHT = {primary: "#1a1a1a", secondary: "#ebebeb", accent: "#ff4500", bg: "#fafafa", panel: "rgba(250,250,250,0.95)", danger: "#b3261e", ok: "#2e7d32", muted: "#666666", grid: "#1c1c1c", gridline: "rgba(255,255,255,0.06)"}
let DARK = {primary: "#ededed", secondary: "#333333", accent: "#ff4500", bg: "#121212", panel: "rgba(20,20,20,0.94)", danger: "#ff6e62", ok: "#4caf50", muted: "#aaaaaa", grid: "#0c0c0c", gridline: "rgba(255,255,255,0.05)"}
let prefs = store_get("sfs_prefs", {dark: false, orbits: true, trails: true, stars: true})
let T = LIGHT
if prefs.dark { T = DARK }
let THEMED = []
let FONT = "Segoe UI, Helvetica, Arial, sans-serif"

fn css(el, m) {
  for k, v in m { setstyle(el, k, v) }
  return el
}
fn style_one(el, kind) {
  if kind == "panel" { css(el, {background: T.panel, color: T.primary, border: "1px solid " + T.primary}) }
  else if kind == "header" { css(el, {background: T.bg, color: T.primary, "border-bottom": "1px solid " + T.primary}) }
  else if kind == "btn" { css(el, {background: T.bg, color: T.primary, border: "1px solid " + T.primary}) }
  else if kind == "btn-primary" { css(el, {background: T.primary, color: T.bg, border: "1px solid " + T.primary}) }
  else if kind == "btn-accent" { css(el, {background: T.accent, color: "#ffffff", border: "1px solid " + T.accent}) }
  else if kind == "btn-danger" { css(el, {background: T.bg, color: T.danger, border: "1px solid " + T.danger}) }
  else if kind == "muted" { css(el, {color: T.muted}) }
  else if kind == "val" { css(el, {color: T.accent}) }
  else if kind == "input" { css(el, {background: T.bg, color: T.primary, border: "1px solid " + T.primary}) }
  else if kind == "fg" { css(el, {color: T.primary}) }
  else if kind == "line" { css(el, {"border-bottom": "1px solid " + T.secondary}) }
}
fn themed(el, kind) {
  push(THEMED, {el: el, kind: kind})
  style_one(el, kind)
  return el
}
fn restyle(el, kind) {
  for t in THEMED { if t.el == el { t.kind = kind } }
  style_one(el, kind)
}
fn apply_theme() {
  T = LIGHT
  if prefs.dark { T = DARK }
  for t in THEMED { style_one(t.el, t.kind) }
  settext(dark_btn, prefs.dark and "☀ Light Mode" or "🌙 Dark Mode")
  draw_grid()
}

fn btn(parent, text, f, kind) {
  let b = button(parent, text, f)
  css(b, {"border-radius": 0, padding: "7px 14px", "font-family": FONT, "font-size": 12, "font-weight": 600, cursor: "pointer"})
  themed(b, kind or "btn")
  return b
}
fn panel(parent, title, place) {
  let p = col(parent)
  css(p, {position: "absolute", padding: "10px 12px", gap: 4, "font-family": FONT, "font-size": 11.5, "z-index": 5, "box-shadow": "0 2px 10px rgba(0,0,0,0.12)"})
  css(p, place)
  themed(p, "panel")
  if title != "" {
    let h = label(p, title)
    css(h, {"font-weight": 700, "font-size": 12.5, "padding-bottom": 6, "margin-bottom": 4})
    themed(h, "line")
  }
  return p
}
let last_stat_name = nil
fn stat_line(parent, name) {
  let r = row(parent)
  css(r, {"justify-content": "space-between", gap: 10})
  let a = label(r, name)
  last_stat_name = a
  let v = label(r, "—")
  css(v, {"font-weight": 700, "text-align": "right", "font-variant-numeric": "tabular-nums"})
  themed(v, "val")
  return v
}

# ---------------------------------------------------------------- page skeleton
let stage = body()
css(stage, {"font-family": FONT, overflow: "hidden"})
themed(stage, "header")
let header = row(stage)
css(header, {position: "absolute", left: 0, right: 0, top: 0, height: 38, padding: "0 18px", gap: 12, "z-index": 20})
themed(header, "header")
let collapse_btn = btn(header, "▾ Collapse", fn() { toggle_header() })
css(collapse_btn, {padding: "3px 8px", "font-size": 10})
let title_el = label(header, "Spaceflight Sim")
css(title_el, {"font-weight": 800, "font-size": 19, "margin-left": 4})
let credit_el = label(header, "Original by Rough_Capital1339/CatPrinceHQ2 · Mod by KampfGuy · KampfScript rebuild")
css(credit_el, {"font-size": 10.5})
themed(credit_el, "muted")
let header_space = box(header)
css(header_space, {flex: 1})
let dark_btn = btn(header, "🌙 Dark Mode", fn() {
  prefs.dark = not prefs.dark
  store_set("sfs_prefs", prefs)
  apply_theme()
})
let menu_btn = btn(header, "☰ Menu", fn() { save_world(); show_screen("menu") })
let to_build_btn = btn(header, "← Back to Build", fn() { show_screen("build") }, "btn-primary")
let header_open = true
fn toggle_header() {
  header_open = not header_open
  for e in [title_el, credit_el, dark_btn, menu_btn, to_build_btn] { show(e, header_open) }
  settext(collapse_btn, header_open and "▾ Collapse" or "▸ Header")
  css(header, {height: header_open and 38 or 24})
  css(screens, {top: header_open and 38 or 24})
}

let screens = box(stage)
css(screens, {position: "absolute", left: 0, right: 0, bottom: 0, top: 38})
let menu_screen = box(screens)
let build_screen = box(screens)
let flight_screen = box(screens)
for s in [menu_screen, build_screen, flight_screen] { css(s, {position: "absolute", inset: 0, overflow: "hidden"}) }

let toast_el = label(stage, "")
css(toast_el, {position: "absolute", top: 10, left: "50%", transform: "translateX(-50%)", background: "rgba(20,20,20,0.85)", color: "#ffffff", padding: "8px 14px", "font-size": 12, "font-weight": 600, "z-index": 50, "pointer-events": "none"})
show(toast_el, false)
let toast_n = 0
fn toast(msg) {
  settext(toast_el, msg)
  show(toast_el, true)
  toast_n += 1
  let mine = toast_n
  after(2600, fn() { if mine == toast_n { show(toast_el, false) } })
}

let mode = "menu"
fn show_screen(name) {
  mode = name
  show(menu_screen, name == "menu")
  show(build_screen, name == "build")
  show(flight_screen, name == "flight")
  show(menu_btn, name != "menu")
  show(to_build_btn, name == "flight")
  if name == "build" { refresh_build() }
  if name == "flight" { refresh_flight_panels() }
  if name == "menu" { refresh_menu() }
}

# ---------------------------------------------------------------- worlds + saving (store_get / store_set)
let worlds = store_get("sfs_worlds", [])
let world = nil
let ships = []
let active = -1
let sim_time = 0
let ship_counter = 0
let warp = 1
let cheats = {infiniteFuel: false, mousePull: false, camRotate: true, noclip: false, bigGrid: false}

fn find_world(id) {
  for w in worlds { if w.id == id { return w } }
  return nil
}
fn save_world() {
  if world == nil { return }
  world.simTime = sim_time
  world.counter = ship_counter
  world.active = active
  world.updated = time()
  let saved = []
  for s in ships {
    if s.status != "crashed" { push(saved, {name: s.name, parts: s.parts, dom: s.dom, rx: s.rx, ry: s.ry, vx: s.vx, vy: s.vy, angle: s.angle, status: s.status, msg: s.msg, tankFuel: s.tankFuel, engineEnabled: s.engineEnabled, throttle: s.throttle, chute: s.chute, ion: s.ion})}
  }
  world.ships = saved
  world.placed = placed
  store_set("sfs_worlds", worlds)
}

# ---------------------------------------------------------------- MENU screen
let menu_bg = canvas(menu_screen)
css(menu_bg, {position: "absolute", inset: 0})
let menu_card = col(menu_screen)
css(menu_card, {position: "absolute", left: "50%", top: "50%", transform: "translate(-50%,-50%)", width: 290, padding: "26px 26px 18px", gap: 10, "text-align": "center", "z-index": 3})
themed(menu_card, "panel")
fn menu_title(t, sub) {
  clear(menu_card)
  let h = label(menu_card, t)
  css(h, {"font-size": 21, "font-weight": 800, "letter-spacing": 0.5})
  if sub != "" {
    let s = label(menu_card, sub)
    css(s, {"font-size": 10.5, "margin-bottom": 8})
    themed(s, "muted")
  }
}
fn menu_button(t, f, kind) {
  let b = btn(menu_card, t, f, kind)
  css(b, {padding: "10px 0", width: "100%"})
  return b
}
fn draw_menu_bg() {
  let sz = canvas_size(menu_bg)
  draw_clear(menu_bg, "#0a0a0c")
  draw_glow(menu_bg, sz.w / 2, sz.h * 0.35, max(sz.w, sz.h) * 0.6, "#1b2233", "#0a0a0c")
  draw_points(menu_bg, menu_stars(sz), "rgba(255,255,255,0.7)", 1.5)
}
let menu_star_list = []
fn menu_stars(sz) {
  if len(menu_star_list) == 0 {
    for i in 160 { push(menu_star_list, [random(), random()]) }
  }
  return map(menu_star_list, fn(p) { return [p[0] * sz.w, p[1] * sz.h] })
}
fn refresh_menu() {
  menu_title("SPACEFLIGHT SIM", "Original by Rough_Capital1339/CatPrinceHQ2 · Mod by KampfGuy")
  menu_button("New World", fn() { new_world_panel() }, "btn-primary")
  let rb = menu_button("Resume World", fn() { resume_panel() })
  enable(rb, len(worlds) > 0)
  menu_button("Settings", fn() { settings_panel() })
  let foot = label(menu_card, len(worlds) == 0 and "No worlds yet — create a New World" or `{len(worlds)} saved world{len(worlds) == 1 and "" or "s"}`)
  css(foot, {"font-size": 10.5, "margin-top": 6})
  themed(foot, "muted")
  let k = label(menu_card, "Written in KampfScript · runs inside Kompass")
  css(k, {"font-size": 9.5})
  themed(k, "muted")
  after(30, fn() { draw_menu_bg() })
}
fn form_row(text) {
  let r = row(menu_card)
  css(r, {"justify-content": "space-between", "font-size": 12})
  label(r, text)
  return r
}
fn new_world_panel() {
  menu_title("New World", "")
  let name_box = textbox(form_row("Name"), "My World")
  css(name_box, {width: 150, "border-radius": 0, padding: "4px 6px"})
  themed(name_box, "input")
  setvalue(name_box, "My World")
  let cheat_box = checkbox(menu_card, "Enable cheats", true)
  css(cheat_box, {"font-size": 12})
  menu_button("Create & Play", fn() {
    let nm = trim(getvalue(name_box))
    if nm == "" { nm = "My World" }
    create_world(nm, getvalue(cheat_box))
  }, "btn-primary")
  menu_button("← Back", fn() { refresh_menu() })
}
fn resume_panel() {
  menu_title("Resume World", "")
  let list = col(menu_card)
  css(list, {"max-height": 280, "overflow-y": "auto", gap: 8})
  for w in reverse(worlds) {
    let r = row(list)
    css(r, {"justify-content": "space-between", padding: "6px 8px", border: "1px solid " + T.secondary})
    let info = col(r)
    css(info, {gap: 1, "text-align": "left"})
    let n = label(info, w.name)
    css(n, {"font-weight": 700, "font-size": 12})
    let d = label(info, `{len(w.ships or [])} ship(s) · day {floor((w.simTime or 0) / 86400)}`)
    css(d, {"font-size": 10})
    themed(d, "muted")
    let wid = w.id
    let play = btn(r, "Play", fn() { load_world(wid) }, "btn-primary")
    css(play, {padding: "4px 10px"})
    let del = btn(r, "✕", fn() {
      worlds = filter(worlds, fn(x) { return x.id != wid })
      store_set("sfs_worlds", worlds)
      resume_panel()
    }, "btn-danger")
    css(del, {padding: "4px 8px"})
  }
  menu_button("← Back", fn() { refresh_menu() })
}
fn settings_panel() {
  menu_title("Settings", "These replace the original's mod manager")
  for item in [["orbits", "Show orbit lines"], ["trails", "Show ship trails"], ["stars", "Starfield"]] {
    let k = item[0]
    let c = checkbox(menu_card, item[1], prefs[k], fn(on) { prefs[k] = on; store_set("sfs_prefs", prefs) })
    css(c, {"font-size": 12})
  }
  menu_button("← Back", fn() { refresh_menu() })
}
fn create_world(name, cheats_on) {
  world = {id: "w" + str(time()), name: name, cheats: cheats_on, simTime: 0, counter: 0, active: -1, ships: [], placed: [], created: time(), updated: time()}
  push(worlds, world)
  ships = []
  active = -1
  sim_time = 0
  ship_counter = 0
  placed = []
  apply_cheat_lock()
  save_world()
  show_screen("build")
  toast(`Sandbox world "{name}" created`)
}
fn load_world(id) {
  world = find_world(id)
  if world == nil { return }
  sim_time = world.simTime or 0
  ship_counter = world.counter or 0
  placed = world.placed or []
  ships = []
  for s in world.ships or [] {
    s.trail = []
    s.engineOn = false
    s.flame = 0
    recompute_ship(s)
    push(ships, s)
  }
  active = world.active
  if active == nil or active >= len(ships) { active = len(ships) - 1 }
  apply_cheat_lock()
  update_bodies(sim_time)
  if len(ships) > 0 { show_screen("flight") } else { show_screen("build") }
  toast(`Loaded "{world.name}"`)
}
fn apply_cheat_lock() {
  show(build_cheats, world.cheats)
  show(flight_cheats, world.cheats)
  if not world.cheats {
    cheats.infiniteFuel = false
    cheats.mousePull = false
    cheats.noclip = false
  }
}

# ---------------------------------------------------------------- part drawing (shared by the builder and the flight view)
let GRAD = {}
fn part_grad(id) {
  if GRAD[id] == nil {
    let c = PARTS[id].color
    GRAD[id] = [shade(c, -0.22), shade(c, 0.05), shade(c, 0.18), shade(c, 0.18), shade(c, 0.02), shade(c, -0.26)]
  }
  return GRAD[id]
}
let RIM = "rgba(0,0,0,0.55)"
# draw part `id` un-rotated into the pixel box x, y, w, h
fn draw_part_shape(c, id, x, y, w, h) {
  let d = PARTS[id]
  let t = d.type
  let g = part_grad(id)
  let lw = max(1, w * 0.025)
  let s = min(w, h)
  if t == "pod" {
    draw_poly(c, [[x + w * 0.22, y], [x + w * 0.78, y], [x + w, y + h], [x, y + h]], g)
    draw_poly(c, [[x + w * 0.22, y], [x + w * 0.78, y], [x + w, y + h], [x, y + h]], RIM, lw)
    draw_circle(c, x + w / 2, y + h * 0.5, s * 0.16, "#9fd3ff")
    draw_circle(c, x + w / 2, y + h * 0.5, s * 0.16, "#333333", lw)
  } else if t == "engine" {
    draw_rect(c, x + w * 0.3, y, w * 0.4, h * 0.3, g)
    draw_poly(c, [[x + w * 0.22, y + h * 0.28], [x + w * 0.78, y + h * 0.28], [x + w, y + h], [x, y + h]], g)
    draw_poly(c, [[x + w * 0.22, y + h * 0.28], [x + w * 0.78, y + h * 0.28], [x + w, y + h], [x, y + h]], RIM, lw)
    draw_line(c, x + w * 0.1, y + h * 0.85, x + w * 0.9, y + h * 0.85, "rgba(255,255,255,0.18)", lw)
    if d.ionOnly { draw_circle(c, x + w / 2, y + h * 0.65, s * 0.18, "#8fe6ff") }
  } else if t == "srb" {
    draw_round_rect(c, x, y, w, h * 0.86, s * 0.12, g)
    draw_poly(c, [[x + w * 0.25, y + h * 0.86], [x + w * 0.75, y + h * 0.86], [x + w * 0.9, y + h], [x + w * 0.1, y + h]], "#2a2a2a")
    for k in [0.2, 0.5, 0.75] { draw_line(c, x, y + h * k, x + w, y + h * k, "rgba(0,0,0,0.25)", lw) }
    draw_round_rect(c, x, y, w, h * 0.86, s * 0.12, RIM, lw)
  } else if t == "tank" and d.adapter {
    let tw = w * d.topW / d.w
    let bw = w * d.botW / d.w
    let pts_ = [[x + (w - tw) / 2, y], [x + (w + tw) / 2, y], [x + (w + bw) / 2, y + h], [x + (w - bw) / 2, y + h]]
    draw_poly(c, pts_, g)
    draw_poly(c, pts_, RIM, lw)
  } else if t == "tank" or t == "solidfuel" or t == "battery" or t == "ionstorage" or t == "science" or t == "probe" {
    draw_round_rect(c, x, y, w, h, s * 0.12, g)
    if t == "tank" {
      draw_line(c, x, y + h * 0.12, x + w, y + h * 0.12, "rgba(0,0,0,0.22)", lw)
      draw_line(c, x, y + h * 0.88, x + w, y + h * 0.88, "rgba(0,0,0,0.22)", lw)
    }
    if t == "probe" { draw_circle(c, x + w / 2, y + h / 2, s * 0.2, "#7fd1ff") }
    if t == "battery" or t == "ionstorage" { draw_rect(c, x + w * 0.35, y + h * 0.3, w * 0.3, h * 0.4, t == "ionstorage" and "#8fe6ff" or "#9be29b") }
    if t == "science" { draw_circle(c, x + w / 2, y + h / 2, s * 0.25, "#333333", lw) }
    draw_round_rect(c, x, y, w, h, s * 0.12, RIM, lw)
  } else if t == "separator" or t == "sidesep" {
    draw_round_rect(c, x, y, w, h, s * 0.12, ["down", shade(d.color, 0.18), d.color, shade(d.color, -0.25)])
    if t == "separator" { draw_line(c, x + w * 0.05, y + h / 2, x + w * 0.95, y + h / 2, "#ffcc00", max(1, h * 0.18)) }
    else { draw_line(c, x + w / 2, y + h * 0.05, x + w / 2, y + h * 0.95, "#ffcc00", max(1, w * 0.18)) }
  } else if t == "chute" {
    draw_poly(c, [[x, y + h], [x, y + h * 0.5], [x + w * 0.2, y + h * 0.1], [x + w / 2, y], [x + w * 0.8, y + h * 0.1], [x + w, y + h * 0.5], [x + w, y + h]], g)
    draw_line(c, x + w * 0.1, y + h * 0.7, x + w * 0.9, y + h * 0.7, "#ff4500", max(1, h * 0.12))
  } else if t == "cone" or (t == "fairing" and d.tip) {
    draw_poly(c, [[x + w / 2, y], [x + w, y + h], [x, y + h]], g)
    draw_poly(c, [[x + w / 2, y], [x + w, y + h], [x, y + h]], RIM, lw)
  } else if t == "fairing" {
    draw_round_rect(c, x, y, w, h, s * 0.08, g)
    draw_line(c, x + w / 2, y, x + w / 2, y + h, "rgba(0,0,0,0.25)", lw)
    draw_round_rect(c, x, y, w, h, s * 0.08, RIM, lw)
  } else if t == "heatshield" {
    draw_poly(c, [[x, y], [x + w, y], [x + w * 0.94, y + h * 0.9], [x + w * 0.06, y + h * 0.9]], ["down", shade(d.color, 0.25), d.color, shade(d.color, -0.35)])
  } else if t == "wheel" {
    draw_circle(c, x + w / 2, y + h / 2, s * 0.46, "#2b2b2b")
    draw_circle(c, x + w / 2, y + h / 2, s * 0.2, "#9a9a9a")
  } else if t == "legs" {
    draw_line(c, x + w * 0.5, y, x + w * 0.08, y + h, "#6a6e74", max(1.5, w * 0.1))
    draw_line(c, x + w * 0.5, y, x + w * 0.92, y + h, "#6a6e74", max(1.5, w * 0.1))
    draw_rect(c, x, y + h * 0.9, w * 0.2, h * 0.1, "#444444")
    draw_rect(c, x + w * 0.8, y + h * 0.9, w * 0.2, h * 0.1, "#444444")
  } else if t == "solar" {
    draw_rect(c, x, y + h * 0.15, w, h * 0.7, "#1a3a7a")
    for k in 4 { draw_line(c, x + w * k / 4, y + h * 0.15, x + w * k / 4, y + h * 0.85, "#6f8fd0", 1) }
    draw_rect(c, x, y + h * 0.15, w, h * 0.7, RIM, lw)
  } else if t == "antenna" {
    draw_rect(c, x + w * 0.45, y + h * 0.45, w * 0.1, h * 0.55, "#c8cdd4")
    draw_arc(c, x + w / 2, y + h * 0.45, s * 0.35, PI, TAU, "#c8cdd4", max(1, w * 0.06))
  } else if t == "drill" {
    draw_poly(c, [[x + w * 0.2, y], [x + w * 0.8, y], [x + w * 0.65, y + h * 0.55], [x + w * 0.55, y + h], [x + w * 0.45, y + h], [x + w * 0.35, y + h * 0.55]], g)
  } else if t == "strut" or t == "rcs" {
    draw_round_rect(c, x + w * 0.2, y, w * 0.6, h, 2, g)
    if t == "rcs" { draw_circle(c, x + w / 2, y + h / 2, w * 0.18, "#333333") }
  } else {
    draw_round_rect(c, x, y, w, h, s * 0.12, g)
    draw_round_rect(c, x, y, w, h, s * 0.12, RIM, lw)
  }
}
fn eff_dims(id, rot) {
  let d = PARTS[id]
  if rot == 90 or rot == 270 { return {w: d.h, h: d.w} }
  return {w: d.w, h: d.h}
}
# draw a placed part with its rotation; x, y, w, h = its on-screen footprint
fn draw_part(c, id, x, y, w, h, rot) {
  if rot == 0 or rot == nil { draw_part_shape(c, id, x, y, w, h); return }
  let d = PARTS[id]
  let nw = w
  let nh = h
  if rot == 90 or rot == 270 { nw = h; nh = w }
  draw_save(c)
  draw_translate(c, x + w / 2, y + h / 2)
  draw_rotate(c, rot * PI / 180)
  draw_part_shape(c, id, -nw / 2, -nh / 2, nw, nh)
  draw_restore(c)
}

# ---------------------------------------------------------------- BUILD screen
let COLS = 24
let ROWS = 75
let placed = []
let next_uid = 1
let selected_part = "pod"
let selected_rot = 0
let gcam = {x: 0, y: 0, z: 1}
let hover = nil
let grid_canvas = canvas(build_screen)
css(grid_canvas, {position: "absolute", inset: 0})

fn foot(p) {
  let e = eff_dims(p.id, p.rot)
  return {col: p.col, row: p.row, w: e.w, h: e.h}
}
fn overlap(a, b) { return a.col < b.col + b.w and a.col + a.w > b.col and a.row < b.row + b.h and a.row + a.h > b.row }
fn touching(a, b) {
  let co = a.col < b.col + b.w and a.col + a.w > b.col
  let ro = a.row < b.row + b.h and a.row + a.h > b.row
  return (co and (a.row + a.h == b.row or b.row + b.h == a.row)) or (ro and (a.col + a.w == b.col or b.col + b.w == a.col))
}
fn part_at(c_, r_) {
  for i, p in placed {
    let f = foot(p)
    if c_ >= f.col and c_ < f.col + f.w and r_ >= f.row and r_ < f.row + f.h { return i }
  }
  return -1
}
fn can_place(id, c_, r_, rot) {
  let e = eff_dims(id, rot)
  let f = {col: c_, row: r_, w: e.w, h: e.h}
  if c_ < 0 or r_ < 0 or c_ + e.w > COLS or r_ + e.h > ROWS { return "Outside the build area" }
  if cheats.noclip { return "" }
  let touches = len(placed) == 0
  for p in placed {
    let g = foot(p)
    if overlap(f, g) { return "Overlaps another part" }
    if touching(f, g) { touches = true }
  }
  if not touches { return "Parts must touch the rocket" }
  return ""
}
fn cell_px() { return 20 * gcam.z }
fn grid_origin() {
  let sz = canvas_size(grid_canvas)
  let cp = cell_px()
  return {x: floor(sz.w / 2 - COLS * cp / 2 + gcam.x), y: floor(60 + gcam.y)}
}
fn draw_grid() {
  if mode != "build" { return }
  let c = grid_canvas
  let sz = canvas_size(c)
  draw_clear(c, prefs.dark and "#0e0e0e" or "#141414")
  let o = grid_origin()
  let cp = cell_px()
  let gw = COLS * cp
  let gh = ROWS * cp
  draw_rect(c, o.x, o.y, gw, gh, T.grid)
  if cp >= 6 {
    for i in COLS + 1 { draw_line(c, o.x + i * cp, o.y, o.x + i * cp, o.y + gh, T.gridline, 1) }
    for j in ROWS + 1 { draw_line(c, o.x, o.y + j * cp, o.x + gw, o.y + j * cp, T.gridline, 1) }
  }
  draw_line(c, o.x + gw / 2, o.y, o.x + gw / 2, o.y + gh, "rgba(255,69,0,0.35)", 1)
  draw_rect(c, o.x, o.y, gw, gh, "rgba(255,255,255,0.25)", 1)
  for p in placed {
    let f = foot(p)
    draw_part(c, p.id, o.x + f.col * cp + 1, o.y + f.row * cp + 1, f.w * cp - 2, f.h * cp - 2, p.rot)
  }
  if hover != nil {
    if hover.remove >= 0 {
      let f = foot(placed[hover.remove])
      draw_rect(c, o.x + f.col * cp, o.y + f.row * cp, f.w * cp, f.h * cp, "rgba(255,80,60,0.9)", 2)
    } else {
      let e = eff_dims(selected_part, selected_rot)
      let why = can_place(selected_part, hover.col, hover.row, selected_rot)
      draw_alpha(c, 0.55)
      draw_part(c, selected_part, o.x + hover.col * cp + 1, o.y + hover.row * cp + 1, e.w * cp - 2, e.h * cp - 2, selected_rot)
      draw_alpha(c, 1)
      draw_rect(c, o.x + hover.col * cp, o.y + hover.row * cp, e.w * cp, e.h * cp, why == "" and "rgba(80,220,120,0.9)" or "rgba(255,80,60,0.9)", 2)
      if why != "" { draw_text(c, o.x + hover.col * cp + e.w * cp + 6, o.y + hover.row * cp + 8, why, "#ff8a70", 11) }
    }
  }
}
let gdrag = nil
on_mouse(grid_canvas, fn(e) {
  let o = grid_origin()
  let cp = cell_px()
  let c_ = floor((e.x - o.x) / cp)
  let r_ = floor((e.y - o.y) / cp)
  if e.type == "down" {
    gdrag = {x: e.x, y: e.y, sx: gcam.x, sy: gcam.y, button: e.button, moved: false}
  } else if e.type == "move" {
    if gdrag != nil and (abs(e.x - gdrag.x) + abs(e.y - gdrag.y) > 5) {
      gdrag.moved = true
      gcam.x = gdrag.sx + e.x - gdrag.x
      gcam.y = gdrag.sy + e.y - gdrag.y
    }
    let rm = part_at(c_, r_)
    if gdrag != nil and gdrag.moved { hover = nil } else { hover = {col: c_, row: r_, remove: -1} }
    draw_grid()
  } else if e.type == "up" {
    if gdrag != nil and not gdrag.moved {
      if gdrag.button == "right" {
        let i = part_at(c_, r_)
        if i >= 0 { remove(placed, i); update_stats() }
      } else if gdrag.button == "left" {
        let why = can_place(selected_part, c_, r_, selected_rot)
        if why == "" {
          push(placed, {id: selected_part, col: c_, row: r_, uid: next_uid, rot: selected_rot})
          next_uid += 1
          update_stats()
        } else { toast(why) }
      }
    }
    gdrag = nil
    draw_grid()
  } else if e.type == "wheel" {
    gcam.z = clamp(gcam.z * (e.dy > 0 and 0.88 or 1.14), 0.35, 4)
    draw_grid()
  }
})

# palette
let palette = panel(build_screen, "Parts", {left: 16, top: 16, bottom: 56, width: 182})
let cat_row = row(palette)
css(cat_row, {"flex-wrap": "wrap", gap: 3, "margin-bottom": 6})
let part_list = col(palette)
css(part_list, {"overflow-y": "auto", flex: 1, gap: 4})
let palette_cat = "All"
let cat_buttons = {}
let part_cards = {}
fn build_palette() {
  clear(cat_row)
  for cat in PART_CATS {
    let k = cat
    let b = btn(cat_row, cat, fn() { palette_cat = k; build_palette() }, palette_cat == cat and "btn-accent" or "btn")
    css(b, {padding: "2px 5px", "font-size": 9.5, "font-weight": 500})
  }
  clear(part_list)
  part_cards = {}
  for id in keys(PARTS) {
    let d = PARTS[id]
    if palette_cat != "All" and d.cat != palette_cat { continue }
    let pid = id
    let card = col(part_list)
    css(card, {padding: "6px 8px", gap: 2, cursor: "pointer"})
    themed(card, selected_part == id and "btn-accent" or "panel")
    let top = row(card)
    css(top, {gap: 6})
    let sw = box(top)
    css(sw, {width: 10, height: 10, background: d.color, border: "1px solid #000"})
    let nm = label(top, d.name)
    css(nm, {"font-weight": 700, "font-size": 11})
    let info = `{d.h}×{d.w} (H×W) · mass {d.dryMass}`
    if d.fuel > 0 { info = info + ` · fuel {d.fuel}` }
    if d.thrust > 0 { info = info + ` · thrust {fmt_scaled(d.thrust, 1)}` }
    let il = label(card, info)
    css(il, {"font-size": 9.5, opacity: 0.75})
    on_click(card, fn() { select_part(pid) })
    part_cards[id] = card
  }
}
fn select_part(id) {
  if part_cards[selected_part] != nil { restyle(part_cards[selected_part], "panel") }
  selected_part = id
  if part_cards[id] != nil { restyle(part_cards[id], "btn-accent") }
  draw_grid()
}

# stats
let stats_panel = panel(build_screen, "Rocket stats", {right: 16, top: 16, width: 164})
let st_dry = stat_line(stats_panel, "Dry mass")
let st_fuel = stat_line(stats_panel, "Fuel mass")
let st_thrust = stat_line(stats_panel, "Total thrust")
let st_twr = stat_line(stats_panel, "Thrust/weight")
let st_dv = stat_line(stats_panel, "Est. Δv")
let st_orbit = stat_line(stats_panel, "Orbit Δv (Earth)")
let st_warn = label(stats_panel, "")
css(st_warn, {"font-size": 10, "font-weight": 700, "margin-top": 4})
themed(st_warn, "val")

fn stats_of(parts) {
  let s = {dry: 0, fuel: 0, thrust: 0, rate: 0, control: 0, engines: 0}
  for p in parts {
    let d = PARTS[p.id]
    s.dry += d.dryMass
    s.fuel += d.fuel
    if is_engine(d.type) and not d.ionOnly { s.thrust += d.thrust; s.rate += d.fuelRate; s.engines += 1 }
    if d.type == "pod" or d.type == "probe" { s.control += 1 }
  }
  let wet = s.dry + s.fuel
  s.twr = wet > 0 and s.thrust / (wet * EARTH_G) or 0
  let ve = s.rate > 0 and s.thrust / s.rate or 0
  s.dv = (ve > 0 and s.dry > 0) and ve * log(wet / s.dry) or 0
  return s
}
fn orbit_dv_needed() { return sqrt(EARTH.GM / (EARTH.radius * 1.06)) * 2.55 }
fn update_stats() {
  let s = stats_of(placed)
  settext(st_dry, fmt(s.dry))
  settext(st_fuel, fmt(s.fuel))
  settext(st_thrust, fmt(s.thrust))
  settext(st_twr, fmt(s.twr, 2))
  settext(st_dv, fmt(s.dv) + " m/s")
  settext(st_orbit, fmt(orbit_dv_needed()) + " m/s")
  settext(st_warn, len(placed) == 0 and "Place parts to build." or `Orbit budget ~{fmt(orbit_dv_needed())} m/s (info only)`)
  enable(launch_btn, len(placed) > 0)
  draw_grid()
}

# saved rockets
let saved_panel = panel(build_screen, "Saved Rockets", {right: 16, top: 228, width: 164})
let saved_list = col(saved_panel)
css(saved_list, {gap: 4, "max-height": 160, "overflow-y": "auto"})
let rockets = store_get("sfs_rockets", [])
fn render_saved() {
  clear(saved_list)
  if len(rockets) == 0 {
    let m = label(saved_list, "No saved rockets yet.")
    themed(m, "muted")
    return
  }
  for i, r in rockets {
    let idx = i
    let rr = row(saved_list)
    css(rr, {"justify-content": "space-between", gap: 4})
    let n = link(rr, r.name, fn() { load_rocket(idx) })
    css(n, {"font-size": 11, "font-weight": 600})
    themed(n, "fg")
    let x = btn(rr, "✕", fn() { remove(rockets, idx); store_set("sfs_rockets", rockets); render_saved() }, "btn-danger")
    css(x, {padding: "1px 6px", "font-size": 10})
  }
}
fn load_rocket(i) {
  placed = []
  for p in rockets[i].parts { push(placed, {id: p.id, col: p.col, row: p.row, rot: p.rot or 0, uid: next_uid}); next_uid += 1 }
  update_stats()
  toast(`Loaded {rockets[i].name}`)
}

# build cheats
let build_cheats = panel(build_screen, "Cheats  DEV", {right: 16, bottom: 120, width: 164})
checkbox(build_cheats, "Noclip (overlap parts)", false, fn(on) { cheats.noclip = on; draw_grid() })
checkbox(build_cheats, "More Build Space (64×96)", false, fn(on) {
  cheats.bigGrid = on
  COLS = on and 64 or 24
  ROWS = on and 96 or 75
  draw_grid()
})

# zoom + action bar + hint
let zoom_bar = row(build_screen)
css(zoom_bar, {position: "absolute", right: 16, bottom: 16, gap: 4, padding: 6, "z-index": 5})
themed(zoom_bar, "panel")
for z in [["–", 0.8], ["⟳", 0], ["+", 1.25]] {
  let f = z[1]
  let b = btn(zoom_bar, z[0], fn() {
    if f == 0 { gcam = {x: 0, y: 0, z: 1} } else { gcam.z = clamp(gcam.z * f, 0.35, 4) }
    draw_grid()
  })
  css(b, {padding: "4px 9px"})
}
let action_bar = row(build_screen)
css(action_bar, {position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 16, gap: 6, padding: 6, "z-index": 5})
themed(action_bar, "panel")
btn(action_bar, "Clear rocket", fn() { placed = []; update_stats() }, "btn-danger")
btn(action_bar, "Save Rocket", fn() {
  if len(placed) == 0 { toast("Nothing to save"); return }
  push(rockets, {name: `Rocket {len(rockets) + 1}`, parts: placed})
  store_set("sfs_rockets", rockets)
  render_saved()
  toast("Rocket saved")
})
let launch_btn = btn(action_bar, "Launch ▲", fn() { launch() }, "btn-primary")
let hint = label(build_screen, "Click: place  ·  Right-click: remove  ·  R: rotate 90°  ·  Drag: pan  ·  Scroll: zoom  ·  Space in flight: stage")
css(hint, {position: "absolute", left: 16, bottom: 16, "font-size": 10, padding: "4px 8px", "z-index": 4, "max-width": 300})
themed(hint, "panel")

fn refresh_build() {
  build_palette()
  render_saved()
  update_stats()
  after(20, fn() { draw_grid() })
}

# ---------------------------------------------------------------- ships
fn key_of(uid) { return str(uid) }
fn recompute_ship(s) {
  let minC = 99999
  let minR = 99999
  let maxC = -99999
  let maxR = -99999
  let dry = 0
  let cx = 0
  let cy = 0
  let tm = 0
  let drag = 1
  s.hasChute = false
  s.solar = 0
  s.ionCap = 0
  s.control = 0
  for p in s.parts {
    let f = foot(p)
    minC = min(minC, f.col)
    minR = min(minR, f.row)
    maxC = max(maxC, f.col + f.w)
    maxR = max(maxR, f.row + f.h)
  }
  for p in s.parts {
    let d = PARTS[p.id]
    let f = foot(p)
    dry += d.dryMass
    let m = d.dryMass + d.fuel
    cx += (f.col - minC + f.w / 2) * m
    cy += (f.row - minR + f.h / 2) * m
    tm += m
    if d.type == "chute" { s.hasChute = true }
    if d.type == "solar" { s.solar += 1 }
    if d.type == "ionstorage" { s.ionCap += ION_STORAGE_CAPACITY }
    if d.type == "pod" or d.type == "probe" { s.control += 1 }
    if d.type == "heatshield" or d.type == "fairing" { drag *= d.dragMult }
    if d.type == "cone" {
      for o in s.parts { if PARTS[o.id].type == "tank" and touching(f, foot(o)) { drag *= d.dragMult; break } }
    }
  }
  s.dry = dry
  s.minC = minC
  s.minR = minR
  s.cellsW = maxC - minC
  s.cellsH = maxR - minR
  s.comX = tm > 0 and cx / tm or s.cellsW / 2
  s.comY = tm > 0 and cy / tm or s.cellsH / 2
  s.foot = (s.cellsH - s.comY) * CELL_WORLD
  s.size = max(s.cellsW, s.cellsH) * CELL_WORLD
  s.dragMult = drag
  if s.ion == nil { s.ion = 0 }
  s.ion = min(s.ion, s.ionCap)
  # engine -> tank connections: walk through touching tanks above each engine (like the original)
  s.conn = {}
  let fuel = 0
  for p in s.parts {
    let t = PARTS[p.id].type
    if is_fuel(t) {
      if s.tankFuel[key_of(p.uid)] == nil { s.tankFuel[key_of(p.uid)] = 0 }
      fuel += s.tankFuel[key_of(p.uid)]
    }
    if is_engine(t) {
      if s.engineEnabled[key_of(p.uid)] == nil { s.engineEnabled[key_of(p.uid)] = true }
      let ef = foot(p)
      let erow = ef.row + ef.h / 2
      let seen = {}
      seen[key_of(p.uid)] = true
      let queue = [p]
      let tanks = []
      while len(queue) > 0 {
        let cur = remove(queue, 0)
        let cf = foot(cur)
        for o in s.parts {
          let ot = PARTS[o.id].type
          if seen[key_of(o.uid)] or not (ot == "tank" or ot == "solidfuel") { continue }
          let of = foot(o)
          if not touching(cf, of) or of.row + of.h / 2 > erow { continue }
          seen[key_of(o.uid)] = true
          push(tanks, key_of(o.uid))
          push(queue, o)
        }
      }
      s.conn[key_of(p.uid)] = tanks
    }
  }
  s.fuel = fuel
  let cap = 0
  for p in s.parts { cap += PARTS[p.id].fuel }
  s.fuelCap = cap
}
fn new_ship(name, parts) {
  let s = {name: name, parts: parts, dom: "earth", rx: 0, ry: 0, vx: 0, vy: 0, angle: 0, status: "landed", msg: "", tankFuel: {}, engineEnabled: {}, engineOn: false, throttle: 1, chute: false, ion: 0, trail: [], flame: 0}
  for p in parts { if is_fuel(PARTS[p.id].type) { s.tankFuel[key_of(p.uid)] = PARTS[p.id].fuel } }
  recompute_ship(s)
  return s
}
fn active_ship() {
  if active < 0 or active >= len(ships) { return nil }
  return ships[active]
}
fn ship_world(s) {
  let p = POS[s.dom]
  return {x: p.x + s.rx, y: p.y + s.ry}
}
fn pad_dir() {
  let e = POS.earth
  let d = max(1, hypot(e.x, e.y))
  return {x: e.x / d, y: e.y / d}
}
fn launch() {
  if len(placed) == 0 { return }
  let prev = active_ship()
  if prev != nil { prev.engineOn = false }
  ship_counter += 1
  let parts = []
  for p in placed { push(parts, {id: p.id, col: p.col, row: p.row, rot: p.rot or 0, uid: p.uid}) }
  let s = new_ship(`Ship {ship_counter}`, parts)
  update_bodies(sim_time)
  let n = pad_dir()
  let gr = EARTH.radius + LAUNCH_PAD_HEIGHT + s.foot
  s.rx = n.x * gr
  s.ry = n.y * gr
  s.angle = atan2(n.x, n.y)
  s.msg = "Ready for launch on Earth pad."
  push(ships, s)
  active = len(ships) - 1
  cam.mpp = 0.5
  cam.free = false
  set_warp(1)
  save_world()
  show_screen("flight")
  toast(`{s.name} ready — Δv {fmt(stats_of(parts).dv)} m/s.`)
}

# fire engines for `sec` simulated seconds; returns the thrust (drains tanks)
fn burn(s, sec) {
  let thrust = 0
  let inf = cheats.infiniteFuel
  let any = false
  for p in s.parts {
    let d = PARTS[p.id]
    if not is_engine(d.type) { continue }
    let u = key_of(p.uid)
    if s.engineEnabled[u] == false { continue }
    if d.type == "srb" {
      let solids = filter(s.conn[u] or [], fn(k) { return s.tankFuel[k] > 0 and srb_block(s, k) })
      let have = s.tankFuel[u]
      for k in solids { have += s.tankFuel[k] }
      if inf { have = 1 }
      if have <= 0 { continue }
      any = true
      thrust += d.thrust
      if not inf {
        let need = d.fuelRate * sec
        for k in solids {
          let take = min(s.tankFuel[k], need)
          s.tankFuel[k] -= take
          need -= take
        }
        s.tankFuel[u] = max(0, s.tankFuel[u] - need)
      }
    } else if d.ionOnly {
      if s.ion <= 0 and not inf { continue }
      any = true
      thrust += d.thrust * s.throttle
      if not inf { s.ion = max(0, s.ion - d.fuelRate * s.throttle * sec) }
    } else {
      let tanks = s.conn[u] or []
      let have = 0
      for k in tanks { have += s.tankFuel[k] }
      if inf { have = 1 }
      if have <= 0 { continue }
      any = true
      thrust += d.thrust * s.throttle
      if not inf {
        let need = min(d.fuelRate * s.throttle * sec, have)
        for k in tanks {
          if need <= 0 { break }
          let take = min(s.tankFuel[k], need)
          s.tankFuel[k] -= take
          need -= take
        }
      }
    }
  }
  if not inf {
    s.fuel = sum(values(s.tankFuel))
    if not any {
      s.engineOn = false
      if s == active_ship() { toast("Out of fuel."); dirty_panels = true }
    }
  }
  return thrust
}
fn srb_block(s, k) {
  for p in s.parts { if key_of(p.uid) == k { return PARTS[p.id].type == "solidfuel" } }
  return false
}

fn change_dom(s, key) {
  let o = POS[s.dom]
  let ov = VEL[s.dom]
  let n = POS[key]
  let nv = VEL[key]
  s.rx += o.x - n.x
  s.ry += o.y - n.y
  s.vx += ov.x - nv.x
  s.vy += ov.y - nv.y
  s.dom = key
  if s == active_ship() {
    if BY[key].depth >= 2 { if warp != 0 { set_warp(0); toast(`Entered {BY[key].name}'s sphere of influence — paused`) } }
    else if warp > 1 { set_warp(1) }
    dirty_panels = true
  }
}
fn crash(s, why) {
  s.status = "crashed"
  s.msg = why
  s.engineOn = false
  if s == active_ship() { toast(why); dirty_panels = true }
}
fn on_pad(s) {
  if s.dom != "earth" { return false }
  let n = pad_dir()
  let r = max(1, hypot(s.rx, s.ry))
  return abs(s.rx / r * n.y - s.ry / r * n.x) * EARTH.radius < 21 and (s.rx * n.x + s.ry * n.y) > 0
}
fn step_ship(s, sec, budget) {
  let b = BY[s.dom]
  let thrust = 0
  if s.engineOn { thrust = burn(s, sec) }
  s.flame = thrust
  let mass = max(1, s.dry + s.fuel)
  let acc = thrust / mass
  let ax = sin(s.angle) * acc
  let ay = cos(s.angle) * acc
  if cheats.mousePull and pulling and s == active_ship() {
    let w = ship_world(s)
    let dx = mouse_world.x - w.x
    let dy = mouse_world.y - w.y
    let l = max(1, hypot(dx, dy))
    ax += dx / l * MOUSE_PULL_ACCEL
    ay += dy / l * MOUSE_PULL_ACCEL
  }
  if s.status == "landed" {
    let r = max(1, hypot(s.rx, s.ry))
    let up = (ax * s.rx + ay * s.ry) / r
    if up <= b.GM / (r * r) { return }
    s.status = "flying"
    s.msg = ""
    dirty_panels = true
  }
  let remaining = sec
  let steps = 0
  while remaining > 0.000001 and steps < budget and s.status == "flying" {
    let r = max(1, hypot(s.rx, s.ry))
    let speed = max(1, hypot(s.vx, s.vy))
    let gap = max(1, r - b.radius)
    let maxdt = b.key == "sun" and 2000 or 150
    maxdt = min(maxdt, 0.012 * TAU * sqrt(r * r * r / b.GM))
    if s.inAtmo { maxdt = min(maxdt, 8) }
    let dt = min(remaining, max(min(maxdt, gap / speed * 0.5), 0.002))
    let g = b.GM / (r * r)
    s.vx += (-g * s.rx / r + ax) * dt
    s.vy += (-g * s.ry / r + ay) * dt
    # atmosphere drag (density model from the original)
    let dens = 0
    if b.atmo {
      if b.solid {
        let top = b.radius * (1 + b.atmoFrac)
        if r < top { dens = pow(clamp((top - r) / (top - b.radius), 0, 1), 1.6) }
      } else if r < b.radius {
        let depth = 1 - r / b.radius
        dens = min(1, depth * 1.4)
        if depth > GAS_GIANT_CRUSH_DEPTH { crash(s, `{s.name} was crushed deep in {b.name}'s atmosphere.`); return }
      }
    }
    s.inAtmo = dens > 0
    if dens > 0 {
      let k = ATMO_DRAG_K * dens * s.dragMult
      if s.chute { k *= PARACHUTE_DRAG_MULT }
      let decay = exp(-min(k * dt, 3.5))
      s.vx *= decay
      s.vy *= decay
    }
    s.decay = 0
    if b.solid and b.atmo {
      let alt = r - b.radius
      let ah = b.radius * b.atmoFrac
      if alt > 0 and alt < ah * 4 {
        s.decay = exp(-alt / (ah * 0.55))
        let d2 = exp(-min(ORBIT_DECAY_K * s.decay * s.dragMult * dt, 0.8))
        s.vx *= d2
        s.vy *= d2
      }
    }
    s.rx += s.vx * dt
    s.ry += s.vy * dt
    remaining -= dt
    steps += 1
    r = hypot(s.rx, s.ry)
    # ground / sun contact
    if b.key == "sun" and r < SUN_RADIUS { crash(s, `{s.name} burned up in the Sun.`); return }
    if b.solid {
      let ground = b.radius + s.foot
      if on_pad(s) { ground += LAUNCH_PAD_HEIGHT }
      if r <= ground {
        let rel = hypot(s.vx, s.vy)
        if rel <= SAFE_LANDING_SPEED {
          let nx = s.rx / max(1, r)
          let ny = s.ry / max(1, r)
          s.rx = nx * ground
          s.ry = ny * ground
          s.vx = 0
          s.vy = 0
          s.status = "landed"
          s.angle = atan2(nx, ny)
          s.engineOn = false
          s.chute = false
          s.msg = `Landed safely on {b.name}.`
          if s == active_ship() { toast(s.msg); dirty_panels = true }
        } else { crash(s, `{s.name} was destroyed on impact with {b.name} at {fmt(rel)} m/s.`) }
        return
      }
    }
    # sphere of influence changes (patched conics)
    if b.parent != nil and r > b.soi {
      change_dom(s, b.parent)
      b = BY[s.dom]
      continue
    }
    let me = POS[s.dom]
    for ch in CHILDREN[s.dom] {
      let cp = POS[ch.key]
      if hypot(s.rx - (cp.x - me.x), s.ry - (cp.y - me.y)) < ch.soi {
        change_dom(s, ch.key)
        b = ch
        break
      }
    }
  }
}
fn charge_ion(s, sec) {
  if s.ionCap <= 0 or s.solar <= 0 { return }
  let w = ship_world(s)
  let d = max(SUN_RADIUS, hypot(w.x, w.y)) / AU
  s.ion = min(s.ionCap, s.ion + s.solar * 0.5 * sec / max(0.05, d * d))
}

# staging: activate the bottom-most separator (like the original's spacebar)
fn handle_space() {
  let s = active_ship()
  if s == nil or s.status == "crashed" { return }
  if s.status == "landed" { toggle_engine(); return }
  let best = -1
  let best_row = -1
  for i, p in s.parts {
    let t = PARTS[p.id].type
    if t == "separator" or t == "sidesep" {
      let f = foot(p)
      if f.row + f.h / 2 > best_row { best_row = f.row + f.h / 2; best = i }
    }
  }
  if best < 0 { toggle_engine(); return }
  if warp > 1 { set_warp(1) }
  let sp = s.parts[best]
  let sf = foot(sp)
  let side = PARTS[sp.id].type == "sidesep"
  let a = []
  let b2 = []
  for i, p in s.parts {
    if i == best { continue }
    let f = foot(p)
    let first = side and (f.col + f.w / 2 < sf.col + sf.w / 2) or (not side and f.row + f.h / 2 < sf.row + sf.h / 2)
    if first { push(a, p) } else { push(b2, p) }
  }
  let ca = len(filter(a, fn(p) { return PARTS[p.id].type == "pod" or PARTS[p.id].type == "probe" }))
  let cb = len(filter(b2, fn(p) { return PARTS[p.id].type == "pod" or PARTS[p.id].type == "probe" }))
  let keep = a
  let drop = b2
  if cb > ca { keep = b2; drop = a }
  if len(keep) == 0 { crash(s, `{s.name} had no parts left after staging.`); return }
  s.parts = keep
  recompute_ship(s)
  if len(drop) > 0 {
    # the jettisoned stage keeps flying as debris
    let d = new_ship(s.name + " debris", drop)
    for p in drop { let k = key_of(p.uid); if s.tankFuel[k] != nil { d.tankFuel[k] = s.tankFuel[k] } }
    recompute_ship(d)
    d.dom = s.dom
    d.angle = s.angle
    let off = -(s.size / 2 + d.size / 2)
    d.rx = s.rx + sin(s.angle) * off * 0.6
    d.ry = s.ry + cos(s.angle) * off * 0.6
    d.vx = s.vx - sin(s.angle) * 3
    d.vy = s.vy - cos(s.angle) * 3
    d.status = "flying"
    d.debris = true
    push(ships, d)
  }
  for p in s.parts { if PARTS[p.id].type == "engine" { s.engineOn = true } }
  toast(`{s.name}: staged — {len(drop)} part(s) jettisoned.`)
  dirty_panels = true
}
fn toggle_engine() {
  let s = active_ship()
  if s == nil or s.status == "crashed" { return }
  s.engineOn = not s.engineOn
  dirty_panels = true
}
fn toggle_chute() {
  let s = active_ship()
  if s == nil or not s.hasChute { return }
  s.chute = not s.chute
  dirty_panels = true
}
fn teleport(key) {
  let s = active_ship()
  let b = BY[key]
  if s == nil or b == nil { return }
  let r = b.radius * (1 + max(0.5, b.atmoFrac * 1.4))
  if not b.solid and b.atmo { r = b.radius * 1.5 }
  s.dom = key
  s.rx = 0
  s.ry = r
  s.vx = sqrt(b.GM / r)
  s.vy = 0
  s.angle = PI / 2
  s.status = "flying"
  s.msg = ""
  s.trail = []
  set_warp(1)
  cam.mpp = max(0.5, r / 300)
  toast(`{s.name} teleported to orbit around {b.name}`)
  dirty_panels = true
}

# ---------------------------------------------------------------- FLIGHT screen
let cam = {x: 0, y: 0, mpp: 0.5, angle: 0, free: false}
let fc = canvas(flight_screen)
css(fc, {position: "absolute", inset: 0})
let dirty_panels = true
let pulling = false
let mouse_world = {x: 0, y: 0}
let mouse_px = {x: 0, y: 0}
let pan = nil

# telemetry
let hud = panel(flight_screen, "Telemetry", {left: 16, top: 16, width: 164})
let h_speed = stat_line(hud, "Speed")
let h_alt = stat_line(hud, "Alt (Earth)")
let h_alt_label = last_stat_name
let h_sun = stat_line(hud, "Dist. Sun")
let h_soi = stat_line(hud, "Sphere of influence")
let h_fuel = stat_line(hud, "Fuel")
let h_throttle = stat_line(hud, "Throttle")
let h_warp = stat_line(hud, "Warp")
let h_status = label(hud, "")
css(h_status, {"font-weight": 700, "font-size": 11, "margin-top": 4})
let engines_panel = panel(flight_screen, "Engines", {left: 194, top: 16, width: 144})
let engines_list = col(engines_panel)
let ships_panel = panel(flight_screen, "Ships", {left: 16, top: 232, width: 164})
let ships_list = col(ships_panel)
css(ships_list, {"max-height": 180, "overflow-y": "auto", gap: 3})
let zoom_panel = col(flight_screen)
css(zoom_panel, {position: "absolute", right: 16, top: 16, padding: 4, gap: 3, "z-index": 5, width: 64})
themed(zoom_panel, "panel")
let zoom_btns = []
for z in [["1 Ship", 0.4], ["2 Orbit", 3000000], ["3 System", 200000000]] {
  let m = z[1]
  let b = btn(zoom_panel, z[0], fn() { cam.mpp = m })
  css(b, {padding: "5px 2px", "font-size": 10})
}
let free_btn = btn(zoom_panel, "Free cam", fn() { set_free(not cam.free) })
css(free_btn, {padding: "5px 2px", "font-size": 10})
fn set_free(on) {
  cam.free = on
  restyle(free_btn, on and "btn-accent" or "btn")
}
let fuel_panel = panel(flight_screen, "Fuel Tanks", {right: 16, top: 150, width: 152})
let fuel_list = col(fuel_panel)
css(fuel_list, {"max-height": 150, "overflow-y": "auto", gap: 3})
let flight_cheats = panel(flight_screen, "Cheats  DEV", {right: 16, top: 330, width: 152})
checkbox(flight_cheats, "Infinite Fuel", false, fn(on) { cheats.infiniteFuel = on })
checkbox(flight_cheats, "Mouse Pull (hold click)", false, fn(on) { cheats.mousePull = on })
checkbox(flight_cheats, "Rotate Cam with Ship", true, fn(on) { cheats.camRotate = on })
let tp_label = label(flight_cheats, "Teleport to planet")
css(tp_label, {"margin-top": 4})
let tp_names = ["— select —"]
for b in BODIES { if b.key != "sun" { push(tp_names, b.name) } }
let tp = dropdown(flight_cheats, tp_names, fn(v) {
  for b in BODIES { if b.name == v { teleport(b.key) } }
  setvalue(tp, "— select —")
})
css(tp, {width: "100%", "font-size": 11})
themed(tp, "input")

# bottom control bar
let controls = col(flight_screen)
css(controls, {position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 16, padding: "8px 14px", gap: 8, "z-index": 6, "align-items": "center"})
themed(controls, "panel")
let c1 = row(controls)
css(c1, {gap: 14})
let engine_btn = btn(c1, "ENGINE: OFF", fn() { toggle_engine() })
css(engine_btn, {"min-width": 84, padding: "7px 12px"})
let chute_btn = btn(c1, "CHUTE: STOWED", fn() { toggle_chute() })
let thr_label = label(c1, "THROTTLE")
css(thr_label, {"font-size": 9, "font-weight": 700, "letter-spacing": 1})
let throttle = slider(c1, 0, 100, 100, fn(v) {
  let s = active_ship()
  if s != nil { s.throttle = v / 100 }
})
css(throttle, {width: 90, "accent-color": "#ff4500"})
let rot_label = label(c1, "ROTATE ◄ A/D ►")
css(rot_label, {"font-size": 9, "font-weight": 700, "letter-spacing": 1})
let c2 = row(controls)
css(c2, {gap: 3})
let wl = label(c2, "WARP")
css(wl, {"font-size": 9, "font-weight": 700, "letter-spacing": 1, "margin-right": 6})
let warp_btns = []
for w in WARP_LEVELS {
  let ww = w
  let b = btn(c2, fmt_warp(w), fn() { if ww <= max_warp() { set_warp(ww) } else { toast(`Warp is capped at {fmt_warp(max_warp())} here`) } })
  css(b, {padding: "3px 6px", "font-size": 10, "font-weight": 500})
  push(warp_btns, b)
}
let c3 = row(controls)
css(c3, {gap: 6})
let cl = label(c3, "CUSTOM")
css(cl, {"font-size": 9, "font-weight": 700, "letter-spacing": 1})
let custom_warp = textbox(c3, "e.g. 5000000", fn(t) { apply_custom_warp(t) })
css(custom_warp, {width: 96, "border-radius": 0, padding: "2px 6px", "font-size": 11})
themed(custom_warp, "input")
let cw_btn = btn(c3, "Set", fn() { apply_custom_warp(getvalue(custom_warp)) })
css(cw_btn, {padding: "3px 8px"})
fn apply_custom_warp(t) {
  let v = num(t)
  if v == nil or v < 0 { toast("Enter a warp number like 5000"); return }
  set_warp(v)
}

fn max_warp() {
  let cap = INFINITY
  for s in ships {
    if s.status != "flying" or s.debris { continue }
    if s.inAtmo { cap = min(cap, 5) }
    else if BY[s.dom].depth >= 2 { cap = min(cap, 100) }
    else if BY[s.dom].depth == 1 { cap = min(cap, 10000) }
  }
  return cap
}
fn set_warp(w) {
  warp = w
  for i, b in warp_btns { restyle(b, WARP_LEVELS[i] == w and "btn-primary" or "btn") }
}
fn update_warp_buttons() {
  let cap = max_warp()
  if warp > cap {
    let best = 0
    for w in WARP_LEVELS { if w <= cap { best = w } }
    set_warp(best)
  }
  for i, b in warp_btns { enable(b, WARP_LEVELS[i] <= cap) }
}

fn refresh_flight_panels() {
  dirty_panels = false
  let s = active_ship()
  # engines
  clear(engines_list)
  if s != nil {
    let n = 0
    for p in s.parts {
      if not is_engine(PARTS[p.id].type) { continue }
      n += 1
      let u = key_of(p.uid)
      let r = row(engines_list)
      css(r, {"justify-content": "space-between"})
      label(r, `Engine {n}`)
      let on = s.engineEnabled[u] != false
      let b = btn(r, on and "ON" or "OFF", fn() { s.engineEnabled[u] = not (s.engineEnabled[u] != false); dirty_panels = true }, on and "btn" or "btn-danger")
      css(b, {padding: "3px 8px", "font-size": 10})
    }
    if n == 0 { let m = label(engines_list, "No engines"); themed(m, "muted") }
  }
  # ships
  clear(ships_list)
  for i, sh in ships {
    let idx = i
    let r = row(ships_list)
    css(r, {"justify-content": "space-between", padding: "4px 6px", cursor: "pointer", background: i == active and "rgba(255,69,0,0.08)" or "transparent"})
    let n = label(r, sh.name)
    css(n, {"font-weight": i == active and 700 or 500, "font-size": 10.5})
    let st = label(r, upper(sh.status))
    css(st, {"font-size": 8.5, "letter-spacing": 1, color: sh.status == "crashed" and T.danger or (sh.status == "landed" and T.ok or T.muted)})
    on_click(r, fn() { switch_ship(idx) })
    let x = link(r, "✕", fn() { delete_ship(idx) })
    css(x, {color: T.accent, "text-decoration": "none"})
  }
  if len(ships) == 0 { let m = label(ships_list, "No ships yet"); themed(m, "muted") }
  # fuel
  clear(fuel_list)
  fuel_bars = []
  if s != nil {
    let n = 0
    for p in s.parts {
      if not is_fuel(PARTS[p.id].type) { continue }
      n += 1
      let r = row(fuel_list)
      css(r, {gap: 6})
      let l = label(r, PARTS[p.id].type == "tank" and `Tank {n}` or (PARTS[p.id].type == "srb" and `SRB {n}` or `Solid {n}`))
      css(l, {width: 42, "font-size": 10})
      let bar = box(r)
      css(bar, {flex: 1, height: 6, background: T.secondary})
      let fill = box(bar)
      css(fill, {height: 6, background: T.accent, width: "100%"})
      let pct = label(r, "")
      css(pct, {width: 32, "text-align": "right", "font-size": 10, "font-weight": 700, color: T.accent})
      push(fuel_bars, {uid: key_of(p.uid), cap: PARTS[p.id].fuel, fill: fill, pct: pct})
    }
    if n == 0 { let m = label(fuel_list, "No tanks"); themed(m, "muted") }
    setvalue(throttle, s.throttle * 100)
  }
  show(chute_btn, s != nil and s.hasChute)
  update_buttons()
}
let fuel_bars = []
fn update_buttons() {
  let s = active_ship()
  if s == nil {
    settext(engine_btn, "ENGINE: —")
    enable(engine_btn, false)
    return
  }
  enable(engine_btn, s.status != "crashed")
  if s.status == "landed" and not s.engineOn { settext(engine_btn, "LAUNCH ▲"); restyle(engine_btn, "btn") }
  else { settext(engine_btn, s.engineOn and "ENGINE: ON" or "ENGINE: OFF"); restyle(engine_btn, s.engineOn and "btn-accent" or "btn") }
  settext(chute_btn, s.chute and "CHUTE: DEPLOYED" or "CHUTE: STOWED")
  restyle(chute_btn, s.chute and "btn-accent" or "btn")
}
fn switch_ship(i) {
  let s = active_ship()
  if s != nil { s.engineOn = false }
  active = i
  set_free(false)
  dirty_panels = true
}
fn delete_ship(i) {
  remove(ships, i)
  if active >= len(ships) { active = len(ships) - 1 }
  else if i < active { active -= 1 }
  dirty_panels = true
}

# ---------------------------------------------------------------- rendering
let CA = 1
let SA = 0
let CW = 800
let CH = 600
fn sx(x, y) { return CW / 2 + ((x - cam.x) * CA + (y - cam.y) * SA) / cam.mpp }
fn sy(x, y) { return CH / 2 + ((x - cam.x) * SA - (y - cam.y) * CA) / cam.mpp }
fn screen_to_world(px, py) {
  let dx = (px - CW / 2) * cam.mpp
  let dy = (py - CH / 2) * cam.mpp
  return {x: cam.x + dx * CA + dy * SA, y: cam.y + dx * SA - dy * CA}
}
let STARS = []
for i in 320 { push(STARS, [random() - 0.5, random() - 0.5, random()]) }
let star_cache = {w: 0, small: [], big: []}
fn draw_stars(alpha) {
  if star_cache.w != CW + CH * 10000 {
    let d = hypot(CW, CH)
    star_cache = {w: CW + CH * 10000, small: [], big: []}
    for s in STARS {
      if s[2] > 0.85 { push(star_cache.big, [s[0] * d, s[1] * d]) } else { push(star_cache.small, [s[0] * d, s[1] * d]) }
    }
  }
  draw_save(fc)
  draw_translate(fc, CW / 2, CH / 2)
  draw_rotate(fc, cam.angle)
  draw_alpha(fc, alpha)
  draw_points(fc, star_cache.small, "#ffffff", 1.2)
  draw_points(fc, star_cache.big, "#ffffff", 2.2)
  draw_restore(fc)
}
fn sky(s) {
  # atmosphere colour at the ship, fading to space as you zoom out (like the original)
  let dens = 0
  let colr = "#0c0c10"
  if s != nil {
    let b = BY[s.dom]
    if b.atmo {
      let r = hypot(s.rx, s.ry)
      if b.solid {
        let top = b.radius * (1 + b.atmoFrac)
        if r < top { dens = pow(clamp((top - r) / (top - b.radius), 0, 1), 1.6) }
      } else if r < b.radius * 1.08 { dens = clamp(1 - (r - b.radius * 0.6) / (b.radius * 0.48), 0, 1) }
      colr = b.atmoColor
    }
  }
  let zt = clamp((log(cam.mpp + 1) - log(3)) / (log(61) - log(3)), 0, 1)
  let amount = dens * (1 - zt)
  let star = clamp(1 - amount * 1.8, 0, 1)
  if cam.mpp > 25 { star = max(star, min(1, (cam.mpp - 25) / 40)) }
  return {bg: mix("#0c0c10", colr, amount), stars: star}
}
fn draw_bodies() {
  let lim = 50 * max(CW, CH)
  if prefs.orbits {
    draw_alpha(fc, 0.5)
    for b in BODIES {
      if b.parent == nil { continue }
      let a = b.distance / cam.mpp
      if a < 4 or a > lim { continue }
      let pp = POS[b.parent]
      let cx = pp.x - b.distance * b.ecc
      draw_ellipse(fc, sx(cx, pp.y), sy(cx, pp.y), a, a * sqrt(1 - b.ecc * b.ecc), cam.angle, b.color, 1)
    }
    draw_alpha(fc, 0.12)
    for b in BODIES {
      if b.parent == nil { continue }
      let r = b.soi / cam.mpp
      if r < 8 or r > lim { continue }
      let p = POS[b.key]
      draw_circle(fc, sx(p.x, p.y), sy(p.x, p.y), r, "#ffffff", 1)
    }
    draw_alpha(fc, 1)
  }
  for b in BODIES {
    let p = POS[b.key]
    let x = sx(p.x, p.y)
    let y = sy(p.x, p.y)
    let r = max(1.2, b.radius / cam.mpp)
    let halo = r * 3
    if x < -halo or x > CW + halo or y < -halo or y > CH + halo { continue }
    if b.key == "sun" {
      draw_glow(fc, x, y, max(6, r * 3), "rgba(255,176,32,0.45)", "rgba(255,176,32,0)")
      draw_circle(fc, x, y, r, "#ffb020")
      if r > 10 { draw_text(fc, x + r + 4, y, "Sun", "rgba(255,255,255,0.75)", 11) }
      continue
    }
    if b.atmo and r > 2 {
      let ar = b.solid and r * (1 + b.atmoFrac) or r * 1.08
      draw_glow(fc, x, y, ar, b.atmoColor + "60", b.atmoColor + "00")
    }
    draw_circle(fc, x, y, r, b.color)
    if r > 3 and r < 4000 {
      draw_glow(fc, x - r * 0.3, y - r * 0.3, r * 1.1, "rgba(255,255,255,0.16)", "rgba(255,255,255,0)")
      draw_circle(fc, x, y, r, "rgba(255,255,255,0.14)", 1)
    }
    if r > 10 and r < 4000 { draw_text(fc, x + r + 4, y + 4, b.name, "rgba(255,255,255,0.75)", 11) }
    else if r <= 10 and cam.mpp > 1000 and b.depth == 1 { draw_text(fc, x + 6, y - 6, b.name, "rgba(255,255,255,0.55)", 10) }
  }
}
fn draw_pad() {
  if cam.mpp > 60 { return }
  let e = POS.earth
  let n = pad_dir()
  let tx = -n.y
  let ty = n.x
  let cx = e.x + n.x * EARTH.radius
  let cy = e.y + n.y * EARTH.radius
  let pts_ = []
  for q in [[-21, -4], [21, -4], [14, LAUNCH_PAD_HEIGHT], [-14, LAUNCH_PAD_HEIGHT]] {
    let wx = cx + tx * q[0] + n.x * q[1]
    let wy = cy + ty * q[0] + n.y * q[1]
    push(pts_, [sx(wx, wy), sy(wx, wy)])
  }
  draw_poly(fc, pts_, ["down", "#a8b0b8", "#808890", "#484e56"])
  draw_line(fc, pts_[3][0], pts_[3][1], pts_[2][0], pts_[2][1], "#ffcc00", max(1, 1.4 / cam.mpp))
}
fn draw_trail(s) {
  if not prefs.trails or len(s.trail) < 2 { return }
  let pts_ = []
  for t in s.trail {
    let p = POS[t[0]]
    let wx = p.x + t[1]
    let wy = p.y + t[2]
    push(pts_, [sx(wx, wy), sy(wx, wy)])
  }
  let w = ship_world(s)
  push(pts_, [sx(w.x, w.y), sy(w.x, w.y)])
  draw_lines(fc, pts_, s == active_ship() and "rgba(255,69,0,0.7)" or "rgba(200,200,200,0.35)", 1.2)
}
fn draw_ship(s, is_active) {
  if s.status == "crashed" { return }
  let w = ship_world(s)
  let x = sx(w.x, w.y)
  let y = sy(w.x, w.y)
  if x < -300 or x > CW + 300 or y < -300 or y > CH + 300 { return }
  let rel = s.angle + cam.angle
  if cam.mpp < 6 {
    let k = CELL_WORLD / cam.mpp
    draw_save(fc)
    draw_translate(fc, x, y)
    draw_rotate(fc, rel)
    if s.chute {
      let top = -s.comY * k
      let cwid = s.cellsW * k * 1.6
      draw_line(fc, -s.cellsW * k / 2, top, -cwid / 2, top - cwid * 0.55, "#dddddd", 1)
      draw_line(fc, s.cellsW * k / 2, top, cwid / 2, top - cwid * 0.55, "#dddddd", 1)
      draw_arc(fc, 0, top - cwid * 0.2, cwid / 2, PI, TAU, "#f2f2f2", max(2, k * 0.5))
      draw_poly(fc, [[-cwid / 2, top - cwid * 0.2], [-cwid / 2.4, top - cwid * 0.55], [0, top - cwid * 0.72], [cwid / 2.4, top - cwid * 0.55], [cwid / 2, top - cwid * 0.2]], "#ff6a33")
    }
    for p in s.parts {
      let f = foot(p)
      let px = (f.col - s.minC - s.comX) * k
      let py = (f.row - s.minR - s.comY) * k
      draw_part(fc, p.id, px, py, f.w * k, f.h * k, p.rot)
      if s.flame > 0 and is_engine(PARTS[p.id].type) and s.engineEnabled[key_of(p.uid)] != false {
        let fl = (1.4 + random() * 0.7) * k * max(0.25, PARTS[p.id].type == "srb" and 1 or s.throttle)
        let bx = px + f.w * k / 2
        let by = py + f.h * k
        let hw = f.w * k * 0.38
        draw_poly(fc, [[bx - hw, by], [bx + hw, by], [bx, by + fl * 2.2]], ["down", "#fff6c0", "#ffb030", "rgba(255,69,0,0)"])
      }
    }
    draw_restore(fc)
  } else {
    let col_ = is_active and "#ff4500" or "#dddddd"
    draw_save(fc)
    draw_translate(fc, x, y)
    draw_rotate(fc, rel)
    draw_poly(fc, [[0, -7], [5, 6], [-5, 6]], col_)
    if s.flame > 0 { draw_poly(fc, [[-3, 6], [3, 6], [0, 13]], "#ffb030") }
    draw_restore(fc)
    draw_text(fc, x + 10, y - 8, s.name, "rgba(255,255,255,0.7)", 10)
  }
}

# ---------------------------------------------------------------- the game loop (runs every frame)
let frame_n = 0
let trail_clock = 0
fn flight_frame(dt) {
  frame_n += 1
  let s = active_ship()
  # rotation keys
  if s != nil and s.status == "flying" and warp <= 1 {
    if key_down("left") or key_down("a") or key_down("q") { s.angle -= 1.6 * dt }
    if key_down("right") or key_down("d") or key_down("e") { s.angle += 1.6 * dt }
  }
  if s != nil and key_down("shift") { s.throttle = min(1, s.throttle + dt); setvalue(throttle, s.throttle * 100) }
  if s != nil and key_down("control") { s.throttle = max(0, s.throttle - dt); setvalue(throttle, s.throttle * 100) }
  update_warp_buttons()
  let sec = min(dt * warp, 8000)
  sim_time += sec
  update_bodies(sim_time)
  for sh in ships {
    if sh.status == "crashed" { continue }
    charge_ion(sh, sec)
    if sh.status == "flying" or sh.engineOn or (pulling and sh == s) { step_ship(sh, sec, sh == s and 400 or 80) }
  }
  # clean up crashed debris
  let before = len(ships)
  let keep = []
  for i, sh in ships {
    if sh.debris and sh.status != "flying" and i != active { continue }
    push(keep, sh)
  }
  if len(keep) != before {
    let cur = active_ship()
    ships = keep
    active = indexof(ships, cur)
    dirty_panels = true
  }
  s = active_ship()
  # trail
  trail_clock += dt
  if trail_clock > 0.2 {
    trail_clock = 0
    for sh in ships {
      if sh.status == "flying" {
        push(sh.trail, [sh.dom, sh.rx, sh.ry])
        if len(sh.trail) > 240 { remove(sh.trail, 0) }
      }
    }
  }
  # camera
  let sz = canvas_size(fc)
  CW = sz.w
  CH = sz.h
  if s != nil and s.status != "crashed" and not cam.free {
    let w = ship_world(s)
    cam.x = w.x
    cam.y = w.y
    cam.angle = (cheats.camRotate and s.status == "flying") and -s.angle or 0
  } else { cam.angle = 0 }
  CA = cos(cam.angle)
  SA = sin(cam.angle)
  if pulling { mouse_world = screen_to_world(mouse_px.x, mouse_px.y) }
  # draw
  let k = sky(s)
  draw_clear(fc, k.bg)
  if prefs.stars and k.stars > 0.01 { draw_stars(k.stars) }
  draw_bodies()
  draw_pad()
  for sh in ships { draw_trail(sh) }
  for i, sh in ships { draw_ship(sh, i == active) }
  if pulling and cheats.mousePull and s != nil {
    let w = ship_world(s)
    draw_line(fc, sx(w.x, w.y), sy(w.x, w.y), mouse_px.x, mouse_px.y, "rgba(255,69,0,0.6)", 1.5)
  }
  if dirty_panels { refresh_flight_panels() }
  if frame_n % 5 == 0 { update_hud(s) }
}
fn update_hud(s) {
  settext(h_warp, fmt_warp(warp))
  if s == nil {
    settext(h_speed, "0 m/s")
    for e in [h_alt, h_sun, h_soi, h_fuel] { settext(e, "-") }
    settext(h_status, len(ships) > 0 and "" or "No active ship — build and launch, or select one from the list.")
    return
  }
  let b = BY[s.dom]
  let w = ship_world(s)
  settext(h_speed, fmt_speed(hypot(s.vx, s.vy)))
  settext(h_alt_label, `Alt ({b.name})`)
  settext(h_alt, fmt_dist(hypot(s.rx, s.ry) - b.radius))
  settext(h_sun, fmt_dist(hypot(w.x, w.y) - SUN_RADIUS))
  settext(h_soi, b.name + (s.inAtmo and " — atmosphere" or ""))
  settext(h_fuel, cheats.infiniteFuel and "∞" or (s.fuelCap > 0 and `{round(100 * s.fuel / s.fuelCap)}%` or "0%"))
  settext(h_throttle, `{round(s.throttle * 100)}%`)
  let msg = ""
  let colr = T.ok
  if s.status == "landed" or s.status == "crashed" { msg = s.msg; if s.status == "crashed" { colr = T.danger } }
  else if s.decay != nil and s.decay > 0.05 { msg = "Orbital decay · drag"; colr = T.danger }
  else if s.ionCap > 0 { msg = `Ion {round(s.ion)}/{s.ionCap}`; colr = T.primary }
  settext(h_status, msg)
  css(h_status, {color: colr})
  for f in fuel_bars {
    let v = s.tankFuel[f.uid] or 0
    let p = f.cap > 0 and round(100 * v / f.cap) or 0
    css(f.fill, {width: str(clamp(p, 0, 100)) + "%"})
    settext(f.pct, cheats.infiniteFuel and "∞" or `{p}%`)
  }
  update_buttons()
}

# flight mouse: wheel zoom, free-cam drag, mouse-pull cheat
on_mouse(fc, fn(e) {
  mouse_px = {x: e.x, y: e.y}
  if e.type == "wheel" { cam.mpp = clamp(cam.mpp * (e.dy > 0 and 1.15 or 1 / 1.15), 0.02, 44000000000) }
  else if e.type == "down" {
    if cam.free and e.button != "left" { pan = {x: e.x, y: e.y} }
    else if e.button == "left" and cheats.mousePull { pulling = true }
  } else if e.type == "move" {
    if pan != nil {
      let dx = (e.x - pan.x) * cam.mpp
      let dy = (e.y - pan.y) * cam.mpp
      cam.x -= dx * CA + dy * SA
      cam.y -= dx * SA - dy * CA
      pan = {x: e.x, y: e.y}
    }
  } else if e.type == "up" {
    pan = nil
    pulling = false
  }
})

# keyboard: space = stage / launch, 1 2 3 = zoom presets, F = free cam, R = rotate part (build)
on_keypress(fn(k) {
  if mode == "flight" {
    if k == "space" { handle_space() }
    else if k == "1" { set_free(false); cam.mpp = 0.4 }
    else if k == "2" { cam.mpp = 3000000 }
    else if k == "3" { cam.mpp = 200000000 }
    else if k == "f" { set_free(not cam.free) }
    else if k == "z" { let s = active_ship(); if s != nil { s.throttle = 1; setvalue(throttle, 100) } }
    else if k == "x" { let s = active_ship(); if s != nil { s.throttle = 0; setvalue(throttle, 0) } }
    else if k == "." or k == "," {
      let i = indexof(WARP_LEVELS, warp)
      if i < 0 { i = 3 }
      i = clamp(i + (k == "." and 1 or -1), 0, len(WARP_LEVELS) - 1)
      if WARP_LEVELS[i] <= max_warp() { set_warp(WARP_LEVELS[i]) }
    }
  } else if mode == "build" and k == "r" {
    if hover != nil and part_at(hover.col, hover.row) >= 0 {
      let p = placed[part_at(hover.col, hover.row)]
      p.rot = (p.rot + 90) % 360
      update_stats()
    } else {
      selected_rot = (selected_rot + 90) % 360
      draw_grid()
    }
  }
})

on_frame(fn(dt) {
  if mode == "flight" { flight_frame(dt) }
})
every_ms(10000, fn() { if world != nil and mode != "menu" { save_world() } })

# ---------------------------------------------------------------- start
update_bodies(0)
set_warp(1)
apply_theme()
show_screen("menu")
