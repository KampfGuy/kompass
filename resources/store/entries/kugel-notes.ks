# ============================================================================
#  🗒 Kugel Notes — Kugel Store app for Kompass 1.8+ (written in KampfScript)
#  Notes with folders, Markdown formatting, checklists, pins and search. Import and export .md / .txt. Everything stays on this PC.
#  Built by tools/build-apps.js from kugel-apps/work/kit.ks, kugel-apps/work/notes.ks
# ============================================================================

# ---------------------------------------------------------------- Kugel Work kit (shared by Kugel Notes, Lattice and Prism)
# Small helpers + the light "Kugel Work" look (CSS classes .kw-* in Kompass 1.8). Everything stays on this PC.
let KW_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
fn kw_civil(z) {
  z = z + 719468
  let era = floor(z / 146097)
  let doe = z - era * 146097
  let yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  let mp = floor((5 * doy + 2) / 153)
  let d = doy - floor((153 * mp + 2) / 5) + 1
  let m = mp + 3
  if mp >= 10 { m = mp - 9 }
  if m <= 2 { y += 1 }
  return {y: y, m: m, d: d}
}
fn kw_date(ms) { let c = kw_civil(floor(ms / 86400000)); return KW_MONTHS[c.m - 1] + " " + str(c.d) + ", " + str(c.y) }
fn kw_iso(ms) { let c = kw_civil(floor(ms / 86400000)); let m = str(c.m); let d = str(c.d); if c.m < 10 { m = "0" + m }; if c.d < 10 { d = "0" + d }; return str(c.y) + "-" + m + "-" + d }
fn kw_id() { return str(time()) + "-" + str(random(1000, 9999)) }
fn kw_esc(s) { return replace(replace(replace(replace(str(s), "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), "\"", "&quot;") }
fn kw_unesc(s) { return replace(replace(replace(replace(replace(str(s), "&lt;", "<"), "&gt;", ">"), "&quot;", "\""), "&apos;", "'"), "&amp;", "&") }
fn kw_btn(parent, text, f, cls) { let c = "kw-btn"; if cls != nil { c = c + " " + cls }; return button(parent, text, f, c) }
fn kw_tool(parent, text, tip, f) { let b = button(parent, text, f, "kw-tool"); settip(b, tip); return b }
fn kw_sep(parent) { return box(parent, "kw-sep") }
fn kw_space(parent) { return box(parent, "kw-space") }
fn kw_toast(root, text) { let t = label(root, text, "kw-toast"); after(2600, fn() { destroy(t) }); return t }
fn kw_safe_name(s) {
  let out = ""
  for ch in split(trim(s), "") { if contains("\\/:*?\"<>|", ch) { out = out + "_" } else { out = out + ch } }
  if out == "" { out = "Untitled" }
  return substr(out, 0, 60)
}
# a simple in-app dialog: returns {box, close}
fn kw_dialog(root, title) {
  let shade = box(root, "kw-shade")
  let d = col(shade, "kw-dialog")
  let h = row(d, "kw-dhead")
  label(h, title, "kw-dtitle")
  kw_space(h)
  button(h, "✕", fn() { destroy(shade) }, "kw-x")
  return {box: d, close: fn() { destroy(shade) }}
}
# stable merge sort with a compare fn(a, b) -> negative / 0 / positive
fn kw_sort(l, cmp) {
  if len(l) <= 1 { return slice(l, 0) }
  let mid = floor(len(l) / 2)
  let a = kw_sort(slice(l, 0, mid), cmp)
  let b = kw_sort(slice(l, mid), cmp)
  let out = []
  let i = 0
  let j = 0
  while i < len(a) and j < len(b) { if cmp(b[j], a[i]) < 0 { push(out, b[j]); j += 1 } else { push(out, a[i]); i += 1 } }
  while i < len(a) { push(out, a[i]); i += 1 }
  while j < len(b) { push(out, b[j]); j += 1 }
  return out
}

# ---------------------------------------------------------------- Kugel Notes
# Notes with folders, pins, search, Markdown (headings, lists, checklists, bold / italic / code, quotes) and a live preview.
# Import / export .md and .txt, or a whole .knotes backup. Saved on this PC only (store_set), nothing goes online.
let notes = store_get("notes", [])
let folders = store_get("folders", ["Personal", "Work", "Ideas"])
let view = store_get("view", "all")
let sel_id = store_get("sel", "")
let mode = store_get("mode", "split")
let query = ""

fn save_notes() { store_set("notes", notes); store_set("folders", folders); store_set("view", view); store_set("sel", sel_id); store_set("mode", mode) }
fn find_note(id) { for n in notes { if n.id == id { return n } }; return nil }
fn note_title(n) { let t = trim(n.title); if t == "" { return "Untitled note" }; return t }
fn snippet(n) {
  for l in split(n.body, "\n") {
    let t = trim(l)
    while startswith(t, "#") or startswith(t, "-") or startswith(t, ">") or startswith(t, "*") { t = trim(substr(t, 1)) }
    if startswith(t, "[ ]") or startswith(t, "[x]") { t = trim(substr(t, 3)) }
    t = replace(replace(t, "**", ""), "`", "")
    if t != "" { return substr(t, 0, 80) }
  }
  return "No additional text"
}
if len(notes) == 0 {
  push(notes, {id: kw_id(), title: "Welcome to Kugel Notes", folder: "Personal", pinned: true, trashed: false, created: time(), updated: time(),
    body: "# Welcome to Kugel Notes\n\nNotes are saved **on this PC** as you type. Nothing goes online.\n\n## Try it\n- [x] Open Kugel Notes\n- [ ] Make a folder with **+ Folder**\n- [ ] Pin a note with 📌\n- [ ] Export a note as Markdown\n\n## Formatting\nUse the toolbar or type Markdown: **bold**, *italic*, `code`.\n\n> Tip: Ctrl+F style search is the box at the top.\n\n1. Numbered lists work too\n2. So do quotes and code blocks\n\n```\nlet x = 42\nprint(x)\n```"})
  sel_id = notes[0].id
  save_notes()
}

let root = box(body(), "kw kw-notes")
let bar = row(root, "kw-bar")
label(bar, "🗒", "kw-logo")
label(bar, "Kugel Notes", "kw-title")
let search = textbox(bar, "Search notes", nil, "kw-search")
on_input(search, fn(t) { query = lower(trim(t)); draw_list() }, 150)
kw_space(bar)
kw_btn(bar, "+ New note", fn() { new_note() }, "accent")
kw_btn(bar, "Import", fn() { import_file() }, nil)
kw_btn(bar, "Export", fn() { export_dialog() }, nil)
let main_ = row(root, "kw-main")
let nav = col(main_, "kw-nav")
let list_box = col(main_, "kw-list")
let ed = col(main_, "kw-editor")
let status = row(root, "kw-status")

fn visible_notes() {
  let out = []
  for n in notes {
    if view == "trash" { if not n.trashed { continue } } else if n.trashed { continue }
    if view == "pinned" and not n.pinned { continue }
    if startswith(view, "f:") and n.folder != substr(view, 2) { continue }
    if query != "" and not contains(lower(n.title + "\n" + n.body), query) { continue }
    push(out, n)
  }
  return kw_sort(out, fn(a, b) {
    if a.pinned != b.pinned { if a.pinned { return -1 }; return 1 }
    return b.updated - a.updated
  })
}
fn count_in(v) {
  let c = 0
  for n in notes {
    if v == "trash" { if n.trashed { c += 1 } }
    else if not n.trashed {
      if v == "all" { c += 1 } else if v == "pinned" and n.pinned { c += 1 } else if startswith(v, "f:") and n.folder == substr(v, 2) { c += 1 }
    }
  }
  return c
}
fn nav_item(txt, v, icon) {
  let r = row(nav, "kw-navitem")
  togglestyle(r, "on", view == v)
  label(r, icon, "kw-navico")
  label(r, txt, "kw-navtxt")
  label(r, str(count_in(v)), "kw-count")
  on_click(r, fn() { view = v; save_notes(); draw_nav(); draw_list() })
  return r
}
fn draw_nav() {
  clear(nav)
  nav_item("All notes", "all", "🗒")
  nav_item("Pinned", "pinned", "📌")
  label(nav, "FOLDERS", "kw-navsec")
  for f in folders { let ff = f; nav_item(f, "f:" + f, "📁") }
  kw_btn(nav, "+ Folder", fn() { new_folder() }, "ghost")
  kw_space(nav)
  nav_item("Trash", "trash", "🗑")
}
fn draw_list() {
  clear(list_box)
  let vn = visible_notes()
  let h = row(list_box, "kw-listhead")
  let t = "All notes"
  if view == "pinned" { t = "Pinned" } else if view == "trash" { t = "Trash" } else if startswith(view, "f:") { t = substr(view, 2) }
  label(h, t, "kw-h3")
  kw_space(h)
  label(h, str(len(vn)) + " notes", "kw-dim")
  if view == "trash" and len(vn) > 0 { kw_btn(list_box, "Empty trash", fn() { notes = filter(notes, fn(n) { return not n.trashed }); save_notes(); draw_all() }, "danger small") }
  if len(vn) == 0 { label(list_box, "No notes here yet.", "kw-empty") }
  for n in vn {
    let id = n.id
    let it = col(list_box, "kw-note")
    togglestyle(it, "on", id == sel_id)
    let r = row(it, "")
    let tl = label(r, note_title(n), "kw-ntitle")
    if n.pinned { label(r, "📌", "kw-pin") }
    label(it, snippet(n), "kw-snip")
    label(it, kw_date(n.updated) + " · " + n.folder, "kw-dim")
    on_click(it, fn() { sel_id = id; save_notes(); draw_list(); draw_editor() })
  }
}
let body_box = nil
let title_box = nil
let preview = nil
fn draw_editor() {
  clear(ed)
  body_box = nil
  let n = find_note(sel_id)
  if n == nil or (n.trashed and view != "trash") {
    let e = col(ed, "kw-blank")
    label(e, "🗒", "kw-bigicon")
    label(e, "Select a note or make a new one.", "kw-dim")
    kw_btn(e, "+ New note", fn() { new_note() }, "accent")
    draw_status()
    return
  }
  let tb = row(ed, "kw-toolbar")
  if n.trashed {
    label(tb, "This note is in the Trash.", "kw-dim")
    kw_space(tb)
    kw_btn(tb, "Restore", fn() { n.trashed = false; touch(n); draw_all() }, "accent")
    kw_btn(tb, "Delete forever", fn() { notes = filter(notes, fn(x) { return x.id != n.id }); sel_id = ""; save_notes(); draw_all() }, "danger")
  } else {
    fn fmt_btn(t, tip, a, b) { kw_tool(tb, t, tip, fn() { if body_box != nil { text_insert(body_box, a, b) } }) }
    fmt_btn("B", "Bold", "**", "**")
    fmt_btn("I", "Italic", "*", "*")
    fmt_btn("</>", "Code", "`", "`")
    kw_sep(tb)
    fmt_btn("H1", "Heading", "\n# ", "")
    fmt_btn("H2", "Subheading", "\n## ", "")
    fmt_btn("•", "Bulleted list", "\n- ", "")
    fmt_btn("1.", "Numbered list", "\n1. ", "")
    fmt_btn("☑", "Checklist", "\n- [ ] ", "")
    fmt_btn("❝", "Quote", "\n> ", "")
    fmt_btn("—", "Divider", "\n\n---\n", "")
    kw_sep(tb)
    for m in [["edit", "Edit"], ["split", "Split"], ["preview", "Preview"]] {
      let mm = m[0]
      let b = kw_tool(tb, m[1], m[1] + " view", fn() { mode = mm; save_notes(); draw_editor() })
      togglestyle(b, "on", mode == mm)
    }
    kw_space(tb)
    let fd = dropdown(tb, folders, fn(f) { n.folder = f; touch(n); draw_nav(); draw_list() }, "kw-dd")
    setvalue(fd, n.folder)
    let pb = kw_tool(tb, "📌", "Pin / unpin", fn() { n.pinned = not n.pinned; touch(n); draw_list(); draw_editor() })
    togglestyle(pb, "on", n.pinned)
    kw_tool(tb, "🗑", "Move to Trash", fn() { n.trashed = true; touch(n); sel_id = ""; draw_all() })
  }
  title_box = textbox(ed, "Title", nil, "kw-ntitlebox")
  settext(title_box, n.title)
  if not n.trashed { on_input(title_box, fn(t) { n.title = t; touch(n); draw_list() }, 300) }
  label(ed, "Edited " + kw_date(n.updated) + " · Created " + kw_date(n.created), "kw-dim kw-meta")
  let area = row(ed, "kw-area")
  if mode != "preview" and not n.trashed {
    body_box = codebox(area, n.body, "fill kw-body")
    on_input(body_box, fn(t) { n.body = t; touch(n); if preview != nil { render_md(preview, n) }; draw_status(); draw_list() }, 250)
  }
  preview = nil
  if mode != "edit" or n.trashed {
    preview = col(area, "kw-preview")
    render_md(preview, n)
  }
  draw_status()
}
fn touch(n) { n.updated = time(); save_notes() }
fn draw_status() {
  clear(status)
  let n = find_note(sel_id)
  if n == nil { label(status, str(count_in("all")) + " notes · saved on this PC", ""); return }
  let words = len(filter(split(replace(n.body, "\n", " "), " "), fn(w) { return trim(w) != "" }))
  label(status, str(words) + " words · " + str(len(n.body)) + " characters", "")
  kw_space(status)
  label(status, "Saved on this PC", "")
}

# ----- Markdown preview
fn inline(parent, text) {
  let p = box(parent, "kw-p")
  let i = 0
  let buf = ""
  let n = len(text)
  fn flush() { if buf != "" { label(p, buf, "kw-span"); buf = "" } }
  while i < n {
    let c = substr(text, i, 1)
    if c == "`" {
      let j = indexof(substr(text, i + 1), "`")
      if j >= 0 { flush(); label(p, substr(text, i + 1, j), "kw-span kw-code"); i = i + j + 2; continue }
    }
    if substr(text, i, 2) == "**" {
      let j = indexof(substr(text, i + 2), "**")
      if j >= 0 { flush(); label(p, substr(text, i + 2, j), "kw-span kw-b"); i = i + j + 4; continue }
    }
    if c == "*" or c == "_" {
      let j = indexof(substr(text, i + 1), c)
      if j > 0 { flush(); label(p, substr(text, i + 1, j), "kw-span kw-i"); i = i + j + 2; continue }
    }
    buf = buf + c
    i += 1
  }
  flush()
  return p
}
fn render_md(target, n) {
  clear(target)
  let lines = split(n.body, "\n")
  let in_code = false
  let code = []
  let idx = 0
  for raw in lines {
    let li = idx
    idx += 1
    let l = raw
    if startswith(trim(l), "```") {
      if in_code { let cb = label(target, join(code, "\n"), "kw-codeblock"); code = []; in_code = false } else { in_code = true }
      continue
    }
    if in_code { push(code, l); continue }
    let t = trim(l)
    if t == "" { box(target, "kw-gap"); continue }
    if t == "---" or t == "***" { box(target, "kw-hr"); continue }
    if startswith(t, "### ") { addstyle(inline(target, substr(t, 4)), "kw-mh3"); continue }
    if startswith(t, "## ") { addstyle(inline(target, substr(t, 3)), "kw-mh2"); continue }
    if startswith(t, "# ") { addstyle(inline(target, substr(t, 2)), "kw-mh1"); continue }
    if startswith(t, "- [ ] ") or startswith(t, "- [x] ") or startswith(t, "- [X] ") {
      let done = not startswith(t, "- [ ] ")
      let r = row(target, "kw-checkrow")
      let lineno = li
      checkbox(r, "", done, fn(on) {
        let ls = split(n.body, "\n")
        if on { ls[lineno] = replace(ls[lineno], "- [ ] ", "- [x] ") } else { ls[lineno] = replace(replace(ls[lineno], "- [x] ", "- [ ] "), "- [X] ", "- [ ] ") }
        n.body = join(ls, "\n")
        touch(n)
        if body_box != nil { settext(body_box, n.body) }
        render_md(target, n)
      }, "kw-cb")
      let p = inline(r, substr(t, 6))
      if done { addstyle(p, "kw-done") }
      continue
    }
    if startswith(t, "- ") or startswith(t, "* ") { let r = row(target, "kw-li"); label(r, "•", "kw-bullet"); inline(r, substr(t, 2)); continue }
    let dot = indexof(t, ". ")
    if dot > 0 and dot < 4 and num(substr(t, 0, dot)) != nil { let r = row(target, "kw-li"); label(r, substr(t, 0, dot) + ".", "kw-bullet"); inline(r, substr(t, dot + 2)); continue }
    if startswith(t, "> ") { addstyle(inline(target, substr(t, 2)), "kw-quote"); continue }
    inline(target, t)
  }
  if in_code { label(target, join(code, "\n"), "kw-codeblock") }
}

# ----- actions
fn new_note() {
  let f = "Personal"
  if startswith(view, "f:") { f = substr(view, 2) } else if len(folders) > 0 { f = folders[0] }
  if view == "trash" { view = "all" }
  let n = {id: kw_id(), title: "", body: "", folder: f, pinned: view == "pinned", trashed: false, created: time(), updated: time()}
  insert(notes, 0, n)
  sel_id = n.id
  query = ""
  settext(search, "")
  save_notes()
  draw_all()
  if title_box != nil { focus(title_box) }
}
fn new_folder() {
  let d = kw_dialog(root, "New folder")
  let tb = textbox(d.box, "Folder name", fn(t) { add_folder(t, d) }, "kw-in")
  focus(tb)
  let r = row(d.box, "kw-drow")
  kw_space(r)
  kw_btn(r, "Cancel", fn() { d.close() }, nil)
  kw_btn(r, "Create", fn() { add_folder(gettext(tb), d) }, "accent")
}
fn add_folder(name, d) {
  let t = trim(name)
  if t == "" or contains(folders, t) { d.close(); return }
  push(folders, t)
  view = "f:" + t
  save_notes()
  d.close()
  draw_all()
}
fn import_file() {
  let f = file_open(["md", "txt", "knotes"])
  if f == nil or not f.ok { return }
  if endswith(lower(f.name), ".knotes") {
    let data = parse_json(f.text)
    if data == nil or type(data) != "map" or not has(data, "notes") { kw_toast(root, "That is not a Kugel Notes backup"); return }
    let c = 0
    for n in data.notes { if find_note(n.id) == nil { push(notes, n); c += 1 } }
    for fo in data.folders { if not contains(folders, fo) { push(folders, fo) } }
    save_notes()
    draw_all()
    kw_toast(root, "Imported " + str(c) + " notes")
    return
  }
  let name = f.name
  let dot = indexof(name, ".")
  if dot > 0 { name = substr(name, 0, dot) }
  let n = {id: kw_id(), title: name, body: f.text, folder: "Personal", pinned: false, trashed: false, created: time(), updated: time()}
  if startswith(view, "f:") { n.folder = substr(view, 2) }
  insert(notes, 0, n)
  sel_id = n.id
  save_notes()
  draw_all()
  kw_toast(root, "Imported " + f.name)
}
fn export_dialog() {
  let n = find_note(sel_id)
  let d = kw_dialog(root, "Export")
  if n != nil {
    label(d.box, "This note: " + note_title(n), "kw-dim")
    let r = row(d.box, "kw-drow")
    kw_btn(r, "Markdown (.md)", fn() { d.close(); file_save(kw_safe_name(note_title(n)) + ".md", n.body) }, "accent")
    kw_btn(r, "Plain text (.txt)", fn() { d.close(); file_save(kw_safe_name(note_title(n)) + ".txt", note_title(n) + "\n\n" + n.body) }, nil)
  }
  label(d.box, "All notes and folders (backup you can import again):", "kw-dim")
  let r2 = row(d.box, "kw-drow")
  kw_btn(r2, "Backup (.knotes)", fn() { d.close(); file_save("Kugel Notes backup.knotes", json({app: "kugel-notes", version: 1, notes: notes, folders: folders}, true)) }, nil)
}
fn draw_all() { draw_nav(); draw_list(); draw_editor() }

on_keypress(fn(k) { if k == "escape" { query = ""; settext(search, ""); draw_list() } })
draw_all()
