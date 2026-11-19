# ---------------------------------------------------------------- start
build_ui()
let saved = store_get("autosave", nil)
let start_p = nil
if saved != nil { start_p = parse_json(saved) }
if start_p == nil or start_p.targets == nil { start_p = samples()[0].make() }
load_project(start_p)
status(APP.hello)
