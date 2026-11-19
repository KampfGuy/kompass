# Kugel Mail — store page. Email needs direct IMAP/SMTP connections, which Kugel Store pages
# (sandboxed, no network) are not allowed to make, so Kugel Mail is its own small Windows app.
let RELEASE = "https://github.com/KampfGuy/kompass/releases/tag/kugel-mail-v1.0.0"
let EXE = "https://github.com/KampfGuy/kompass/releases/download/kugel-mail-v1.0.0/Kugel-Mail-1.0.0-portable.exe"
fn css(e, m) {
  for k in keys(m) { setstyle(e, k, m[k]) }
}
let page = box(body())
css(page, {"max-width": "760px", margin: "0 auto", padding: "28px 24px", "font-family": "Segoe UI, system-ui, sans-serif", "line-height": "1.5"})
let top = row(page)
css(top, {gap: "16px", "align-items": "center"})
let ball = box(top)
css(ball, {width: "64px", height: "64px", "border-radius": "50%", background: "radial-gradient(circle at 35% 30%, #9cc2ff, #2f6fed 60%, #163f9a)", display: "flex", "align-items": "center", "justify-content": "center", color: "white", "font-size": "30px"})
label(ball, "✉")
let tbox = box(top)
heading(tbox, "Kugel Mail")
let sub = label(tbox, "A small, private email app for Windows — Gmail, Yahoo and any IMAP mail.")
css(sub, {opacity: "0.8"})

let dl = row(page)
css(dl, {gap: "10px", margin: "22px 0", "flex-wrap": "wrap"})
let b1 = button(dl, "⬇ Download Kugel Mail 1.0.0 for Windows (portable .exe, 101 MB)", fn() { open_url(EXE) })
css(b1, {background: "#2f6fed", color: "white", padding: "10px 16px", "border-radius": "8px", "font-weight": "600"})
button(dl, "Release notes", fn() { open_url(RELEASE) })
let why = label(page, "Why a separate app? Reading mail means talking straight to your mail server (IMAP and SMTP). Kugel Store programs run in a safe sandbox that cannot open network connections, so Kugel Mail is its own app, like Kompass itself. It is portable: no installer, just run the .exe.")
css(why, {display: "block", background: "rgba(127,127,127,0.12)", padding: "10px 14px", "border-radius": "8px"})

fn section(t, lines) {
  let h = heading(page, t)
  css(h, {"font-size": "18px", "margin-top": "22px"})
  for l in lines {
    let x = label(page, "• " + l)
    css(x, {display: "block", margin: "3px 0"})
  }
}
section("What it does", [
  "Folders with unread counts, newest mail first, search (subject, sender, text)",
  "Read, reply, reply all, forward (keeps attachments), write new mail with attachments",
  "Save attachments, mark unread, delete (goes to Trash), several accounts",
  "Keyboard: Ctrl+N write, Ctrl+R reply, Delete, ↑/↓, F5 check mail, Ctrl+Enter send"])
section("Safe by default", [
  "Your password is encrypted by Windows (DPAPI) and never leaves your PC except to log in to your own mail server",
  "Mail is shown in a locked box: no scripts, no forms; pictures from the internet are blocked until you press \"Load images\" (so senders cannot see when you open their mail)",
  "Links open in your normal browser; only encrypted connections (SSL/TLS or STARTTLS) are allowed to mail servers"])
section("Setting up", [
  "Gmail: turn on 2-Step Verification, then create an App Password at myaccount.google.com/apppasswords and paste it into Kugel Mail (your normal password will not work)",
  "Yahoo: Account Security → Generate app password",
  "Other providers: choose Other and type the IMAP / SMTP servers they give you",
  "Outlook.com / Hotmail: Microsoft now requires OAuth sign-in for personal accounts, which Kugel Mail 1.0 does not have yet — it may be refused"])
let note = label(page, "Windows may show a SmartScreen warning because the app is not code-signed: choose More info → Run anyway.")
css(note, {display: "block", "margin-top": "22px", opacity: "0.7", "font-size": "13px"})
