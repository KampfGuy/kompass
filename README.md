# 🧭 Kompass

This repository has three apps:

- **[Kompass for Windows](#-kompass-for-windows)**, a desktop web browser built with **KampfScript** (`.ks`), the small language from
  [KampfOS](https://github.com/KampfGuy/kampfos). Its Kugel Store has the **Kugel apps**: a 3D modeler and two block-based game makers.
- **[Kompass VR](#-kompass-vr-for-meta-quest)**, the same browser as an app for Meta Quest headsets
- **[Kugel Mail](#-kugel-mail)**, a small private email app for Windows

---

## 🧭 Kompass for Windows

### ⬇ Download
**[Download the latest Kompass for Windows](https://github.com/KampfGuy/kompass/releases/latest)**
(Windows 10/11, 64-bit). It comes in two forms:
- `Kompass-<version>-portable.exe`: a single file with no install. Double-click it to run. **This is the one that updates itself.**
- `Kompass-<version>-win-x64.zip`: unzip it anywhere and run `Kompass.exe`.

The exe isn't code-signed, so Windows SmartScreen will say "Windows protected your PC". Click **More info → Run anyway**.

### What it is
Kompass is a real Chromium-based web browser for Windows. Its whole interface is a KampfScript program,
[`resources/browser.ks`](resources/browser.ks), which you can read and edit from inside the app: tabs, address bar,
bookmarks, history, settings, the start page and every `kompass://` page. Electron (Chromium 156) only draws web pages
and provides native built-ins.

![Kompass start page](docs/kompass11-main.png)

### What it can do
- **Browse the real web.** Each page runs in a sandboxed Chromium tab, so YouTube, Google, Docs and the rest work.
  - It has tabs, back/forward, bookmarks bar (`Ctrl+D`), history (`Ctrl+H`), find, zoom and an ad/tracker blocklist.
  - You can type a search into the address bar and it goes to **Kugel**, Google or DuckDuckGo.
  - Since 1.6.0, Google sees a normal, up-to-date browser. Google sign-in is still hit-and-miss (see below).
- **Fullscreen.** Use `F11` for the whole browser, or the ⛶ fullscreen button on a page (YouTube, Slides, Maps…). `Esc` leaves fullscreen.
- **Kugel Store** (`kompass://store`): a catalog of KampfScript games and apps, including 3D games, that run in a sandbox. You can **publish your own** from the editor.
- **3D games API.** Over 40 built-ins on three.js: `scene3d`, `cube`, `sphere`, `move3d`, `camera3d`, `fps_controls`, `hits3d`, `ray3d`, `gamepad()`…
  - The `vr_*` built-ins also work on a normal screen (mouse = hand).
  - Try them at `kompass://games3d`, `kompass://maze3d` and `kompass://runner3d`.
- **Kugel apps** (in the Kugel Store, need Kompass 1.7.0+). All three are plain KampfScript, made to run on a weak PC (integrated graphics, 4 GB RAM):
  - **🧊 Kugel 3D Modeler** (`kompass://store/kugel-modeler`): Blender-style modeling. Orbit / pan / zoom viewport with grid, cube / sphere / cylinder / cone / plane / torus,
    object and edit mode (select vertices / faces, box select), **extrude**, move / rotate / scale gizmo and **G / R / S** keys, subdivide, merge, smooth, join, undo / redo,
    outliner, materials (colour, shiny, metal, glow, opacity, wireframe), studio / sunset / night lights, **Render** to PNG, save / open `.kmodel`,
    **import and export OBJ, glTF and GLB**, and **To games**: save a model so any 3D game (and Kugel Blocks 3D) can `load_model` it. A ⚡ Performance switch makes it lighter.
  - **🧩 Kugel Blocks** (`kompass://store/kugel-blocks`): make games with drag-and-drop blocks, like Scratch. Motion, looks, sound, events, control (with clones),
    sensing, operators, variables, lists, pen and your own blocks; sprites with a costume library and a **paint editor**, backdrops, a stage you can drag sprites on.
    Every block turns into readable KampfScript (the `{ } KampfScript` tab), and **⇩ Export game** makes a stand-alone `.ks` game you can publish.
  - **🎲 Kugel Blocks 3D** (`kompass://store/kugel-blocks-3d`): the same editor for 3D games. Actors (shapes or your Modeler models), walk with arrows / WASD / gamepad,
    jump, gravity, solid walls, touching, follow / first-person / fixed cameras, sky, fog, light and ground. Samples: Coin Run, Maze Walk, Space Dodge.

  ![Kugel 3D Modeler](docs/kugel-modeler.png)
  ![Kugel Blocks](docs/kugel-blocks.png)
  ![Kugel Blocks 3D](docs/kugel-blocks-3d.png)
- **Learn KampfScript** (`kompass://learn`, `F1`): 15 lessons with runnable examples, auto-checked exercises, saved progress and tutorial videos. Lessons ⑫–⑮ teach making 3D games. `kompass://learn/ai` is the full language reference to paste into an AI.
- **⚡ Editor and console** (`Ctrl+Shift+K`): write and run your own `.ks` scripts, make your own `kompass://page/...` pages, or edit `browser.ks` and restart.
  - The **builder** (`kompass://builder`) makes a custom Google-style home page.
- **{ } KampfScript DevTools** (`F12`): an inspector, a live console (REPL), an event log, a debugger with breakpoints and stepping, a source/AST view, performance and errors. Chromium's page devtools are there too.
- **🔑 Password manager**: an encrypted vault, a "save password?" bar, autofill, CSV and encrypted import/export. KampfScript code never sees a password.
- **Looks**: four themes (Brass, Midnight, Neon, Paper), an accent colour and a double right-click quick menu.

Your data (settings, bookmarks, history, scripts, your `browser.ks`) lives in `%APPDATA%\Kompass\kompass\`.

### How it updates
- **When it checks:** the portable exe checks **GitHub's latest release** (`/releases/latest`) when it starts and every 4 hours.
- **How it updates:** when there's a newer version, Kompass reads that release's `kompass-update.json` and downloads the new exe in the background.
  - It **checks the size and SHA512**, then shows **"Update ready — restart to update"**.
  - Restart Kompass (or just close it) and the new exe replaces the old one. It's the same file and your data stays.
- **Prereleases are never offered.** GitHub's "latest" never points to a prerelease, so the VR builds below never reach Windows.
- **The zip build** can't replace itself, so it shows "new version available → Download".
- **Settings → Updates** has an Auto-update switch, a Check now button and your current version.

### What's new in 1.7.0
- **Three Kugel apps in the Kugel Store**: Kugel 3D Modeler, Kugel Blocks and Kugel Blocks 3D (see above).
- **New built-ins for apps** (all documented in `kompass://learn/ai`): threads (`spawn`, `wait`, `next_frame`), running a program in its own sandbox
  (`run_app` / `stop_app`), images on canvases (`draw_image`, `canvas_data`, `draw_fill`…), synthesised sounds (`beep`, `sound`), JSON,
  saving / opening files **only through Windows' own Save / Open boxes** (`file_save`, `file_open`), editable 3D meshes (`mesh3d`, `mesh_extrude`…),
  OBJ / glTF / GLB export and import, and a model library shared by all 3D games (`model_save`, `load_model`).
- **Kugel Mail** is a new, separate app (below).

### What's new in 1.6.0
- **Google sees an up-to-date browser.** Kompass 1.5 ran **Chromium 130** (late 2024) while Chrome is at 159, and its
  pages went out without Chrome's client hints. Kompass now runs **Electron 45 / Chromium 156** and sends a clean Chrome
  User-Agent with the real version plus `Sec-CH-UA` on every site.
- **Google sign-in: better, but not guaranteed.** Google deliberately blocks sign-in in browsers built into apps
  ("Couldn't sign you in — This browser or app may not be secure"), and it spots Electron even when it claims to be Chrome.
  Kompass now uses a Firefox User-Agent on Google's sign-in pages (`accounts.google.com`) only, which sometimes gets you
  to the password step. If Google still refuses, a note explains what happened and offers **↗ Open in my browser**.
- **The Kompass VR app's source is now in this repo**, in `android/` and `vr/`.

### Build from source
```bash
npm install
npm start                 # run
npm test                  # interpreter, browser.ks, lessons, 3D games, user-agent, Kugel apps tests
node tools/build-blocks.js  # rebuild Kugel Blocks / Blocks 3D from kugel-apps/blocks/*.ks
node tools/release.js     # build portable exe + zip + kompass-update.json + SHA512SUMS and publish (docs/RELEASING.md)
```

---

## 🥽 Kompass VR (for Meta Quest)

### ⬇ Download
**[Download Kompass VR 1.6.0-vr.1 (APK)](https://github.com/KampfGuy/kompass/releases/download/v1.6.0-vr.1/Kompass-VR-1.6.0-vr.1.apk)**.
You can also see [all Kompass VR releases](https://github.com/KampfGuy/kompass/releases?q=Kompass+VR&expanded=true) and pick the newest `Kompass-VR-<version>.apk`.
VR builds are published as GitHub *prereleases*, so they never show up as the Windows "latest".

### What it is
Kompass VR is the same KampfScript browser (`browser.ks` plus a VR add-on), packaged as an Android app that runs as a
2D panel on Meta Quest. It's built for headset use:
- big touch targets
- point-and-trigger clicking
- hold the trigger (or pinch) for the quick menu
- an on-screen keyboard
- controller B goes Back

### What it can do
- **Browse the web** in tabs, with bookmarks, history, Kugel/Google search, the editor, Learn (16 lessons, including ⑯ *VR games*) and the password vault.
- **3D and VR mode.** The full 3D API, plus `vr_setup`, `vr_start`, `vr_hand` (position, swing speed, trigger/grip/A/B/stick), `vr_attach`, `vr_haptic`, `panel3d`…
  - Quest's in-app web view has no WebXR, so **"Play in VR"** opens the game in the **Quest Browser**. Press *Enter VR* there for real immersive VR. The app serves its own files from `127.0.0.1` for this.
- **A VR-only Kugel Store** (`index-vr.json`) with three VR games:
  - 🎾 **Kugel Tennis VR**: Wii-Tennis for VR. Swing your controller like a racket against a CPU, with real tennis scoring.
  - 🦍 **Kugel Gorillas VR**: Gorilla-Tag-style arm locomotion. Push off the ground, rocks and trees to run and climb, and tag 4 AI gorillas.
  - ⚔ **Kugel Saber VR**: Beat-Saber style. Slice red and blue blocks in the arrow's direction, dodge bombs, and build combos up to 8×.

### How to install (sideload)
1. Turn on **Developer mode** for your headset in the Meta Horizon phone app. It needs a free Meta developer account.
2. Connect the Quest to your PC with USB and allow USB debugging.
3. Install the app with `adb install -r Kompass-VR-<version>.apk` (Android platform-tools), or drag the APK onto **SideQuest**.
4. On the Quest, open **App Library → Unknown Sources → Kompass VR**.

New versions install over old ones and keep your data, because every build is signed with the same key.

### How it updates
Kompass VR checks the **full GitHub release list, including prereleases**, for the newest release that has a
`Kompass-VR-*.apk`. When it finds a newer version it shows **"update available"** and opens the APK download.
Install that APK the same way you installed the app, and it goes over the old one.

### Build from source
```bash
node vr/build-web.js <out>   # the web bundle (also done by the Gradle build)
vr/build-apk.sh              # APK -> /workspace/kompass-vr-dist/Kompass-VR-<version>.apk (JDK 17, Android SDK 34, Gradle 8.7)
npm run test:vr              # VR bundle + VR API on a simulated WebXR runtime + bots playing the 3 VR games
```
There's more detail in [`vr/README.md`](vr/README.md).

---
MIT licensed.

---

## ✉ Kugel Mail

### ⬇ Download
**[Download Kugel Mail 1.0.0 for Windows](https://github.com/KampfGuy/kompass/releases/tag/kugel-mail-v1.0.0)** (`Kugel-Mail-1.0.0-portable.exe`, no install).
It is not code-signed, so SmartScreen may warn: **More info → Run anyway**. It is also listed in the Kugel Store (`kompass://store/kugel-mail`).

### Why a separate app?
Email means talking straight to your mail server over IMAP and SMTP. Kugel Store programs run in a sandbox that cannot open network
connections (that is what keeps them safe), so Kugel Mail is its own small Electron app. Its source is in [`apps/kugel-mail`](apps/kugel-mail).

![Kugel Mail](docs/kugel-mail.png)

### What it can do
- Gmail, Yahoo and any IMAP/SMTP provider (presets + "Other"), several accounts. It checks receiving and sending before saving an account.
- Folders with unread counts, newest first, search, read, reply, reply all, forward (with the original attachments), write with attachments, save attachments, mark unread, delete (to Trash).
- **Private by default:** the password is encrypted with Windows' DPAPI (Electron `safeStorage`) and never shown to the window; mail is cleaned
  (no scripts, forms or event handlers) and shown in a sandboxed frame; **pictures from the internet are blocked** until you press *Load images*; links open in your normal browser;
  only SSL/TLS or STARTTLS connections are allowed (plain text only to `localhost`).
- **Gmail and Yahoo need an app password** (Google: 2-Step Verification, then myaccount.google.com/apppasswords). The app explains this on the setup screen.
- **Outlook.com / Hotmail:** Microsoft switched personal accounts to OAuth-only sign-in, which Kugel Mail 1.0 does not support yet, so they will probably be refused.

### Build / test
```bash
cd apps/kugel-mail
npm install
npm start
npm test        # sanitizer + IMAP/SMTP tests against a local GreenMail server (see test/README.md)
npm run dist:win
```
Kugel Mail does not update itself; new versions appear on the releases page and in the Kugel Store.
