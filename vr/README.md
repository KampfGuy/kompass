# Kompass VR — Kompass for Meta Quest (Android APK)

Kompass VR is the Kompass browser for VR headsets running **Meta Horizon OS** (Quest 2, Quest Pro, Quest 3, Quest 3S).
It opens as a big **2D panel** in your Quest home, so you get your browser next to everything else, and you
use it with controller rays or hand tracking.

It runs the **same KampfScript runtime** as Kompass for Windows: `src/lang.js`, `src/host.js`, `src/render.js`,
`src/editor.js`, `src/devtools.js` and `src/style.css` are copied into the APK as they are, and the whole browser UI is
still `resources/browser.ks`. The Windows build is not affected by any of this.

## How it works

Electron does not exist on Android, so the APK swaps in a different shell:

| Windows (Electron) | Kompass VR (Android) |
|---|---|
| `src/main.js` + `src/preload.js` → `window.native` | `vr/web/native-shim.js` → the same `window.native`, backed by the Java bridge `KompassAndroid` (`android/.../Bridge.java`) |
| `<webview>` tabs (Chromium) | `<kompass-webview>` placeholders; a **native Android WebView** per tab is placed exactly over the placeholder's rectangle (`WebTabs.java`) |
| profile files in `%APPDATA%` | app-private files (`files/data/*.json`, `files/scripts/*.ks`, `files/browser.ks`) |
| scrypt + AES-GCM vault | PBKDF2-SHA256 + AES-GCM vault (`Vault.java`; not file-compatible with Windows) |
| Node `fetch` for Kugel search / store | Java `HttpURLConnection` (no CORS/Origin), `src/store.js` reused through `ks-store.js` |
| auto-update (portable exe) | checks GitHub releases for a `Kompass-VR-*.apk` asset and opens the download |

`vr/browser-vr-addon.ks` is appended to `browser.ks` when the APK is built. It adds a ☰ quick-menu button, more
quick-menu entries (Home, Editor, Store, YouTube), a compact toolbar and the calm *midnight* theme on first start.

### Made for VR
- **No right-click needed.** The double-right-click quick menu becomes: the ☰ button, or **hold the trigger / pinch
  for 0.6 s** anywhere (on a web link it offers "Open link in new tab").
- **Big targets**: toolbar buttons 56 px, tabs 52 px, every button/field at least 48 px, 17 px base text, 18 px scrollbars.
- **Ray-friendly hover**: clear glow on everything you point at; no hover animations that move a target away from the ray.
- **Comfortable dark**: the *midnight* theme is tuned for headsets (no pure black/white, less glare). All 4 themes still work.
- **On-screen keyboard**: the address bar gets the "Go" key, autocorrect/capitalisation off, and a focused field
  scrolls into view above the system keyboard.
- **Panel**: landscape, 1280×800 dp by default, resizable; HTML5 video goes fullscreen inside the panel.
- **Controller B / Back** = browser Back.
- **Canvas mirror (experimental)**: `vr/web/vr-xr.js` shows a "🥽 Immersive" button on ordinary 2D KampfScript canvas
  games when the runtime supports WebXR (hidden for VR games, which have their own immersive mode, see below).

## VR mode, 3D and VR games (1.5.3-vr.1)
- **3D**: the full KampfScript 3D API from Kompass 1.5.2+ (`scene3d`, `cube`, `move3d`, … three.js r187) is in the VR
  build. On Android the pixel ratio is capped at 1 for the Quest's GPU; controllers/gamepads show up in `gamepad()`.
- **VR API** (in every KampfScript sandbox, documented in `kompass://learn/ai` §7.9 and lesson ⑯):
  `vr_setup(s, {height, hands, pitch, reach})`, `vr_start(s)`, `vr_stop(s)`, `vr_mode(s)`, `vr_supported()`,
  `vr_available()`, `vr_rig(s, x, y, z, yaw)`, `vr_head(s)`, `vr_hand(s, "left"|"right")` (position, rotation, `dir`,
  velocity `vx/vy/vz/speed`, `trigger`, `grip`, `a`, `b`, `stick_x/y`), `vr_hands(s)`, `vr_attach(s, obj, hand)`,
  `vr_haptic(s, hand, strength, ms)`, `panel3d(s, canvas, width)` (a live 2D canvas as a 3D screen), `world3d(obj)`.
- **Immersive mode**: where WebXR exists (Quest Browser, desktop browsers with a headset) `vr_start` opens an
  `immersive-vr` session (local-floor) and drives the scene from the headset's frame loop. Android's System WebView
  (which the APK's panel uses) has **no WebXR**, so inside the app `vr_start` hands the game to the **Quest Browser**:
  the APK serves its own `www/` on `http://127.0.0.1:47653` (LocalServer.java, assets only) and opens
  `index.html#play=<store id>`, which boots Kompass VR in the browser and opens that game; press "Enter VR" there.
- **Desktop / panel fallback ("flat")**: the mouse is your right hand (Shift = left), left click = trigger,
  right click = grip, wheel = reach, E/R = A/B, WASD/arrows = sticks; every VR game also has keyboard controls.
- **Kugel Store in VR shows only VR games**: the app reads `index-vr.json` from KampfGuy/kugel-store and keeps
  entries tagged `vr` (`store.indexVR`). The Windows app reads `index.json` only, so its games are unchanged.
  The offline copy bundled in the APK is `vr/store/`.
- **The 3 VR games** (`vr/store/entries/`):
  - 🎾 **Kugel Tennis VR** — Wii-Tennis for VR: swing the controller like a racket vs a CPU Kugel; auto-run,
    aim by swing direction, real scoring (15-30-40-deuce, first to 3 games); wins + best rally saved.
  - 🦍 **Kugel Gorillas VR** — Gorilla-Tag-style arm locomotion: push off the ground, rocks, trees and the wall
    with your hands to run, jump and climb; you are IT, tag all 4 AI gorillas in 120 s; best time saved.
  - ⚔ **Kugel Saber VR** — Beat-Saber-style: slice red (left) and blue (right) blocks in the arrow's direction,
    avoid bombs, combo multiplier up to 8×, energy bar, 60-second song; best score + combo saved.

## Build

```bash
vr/build-apk.sh            # debug APK -> /workspace/kompass-vr-dist/Kompass-VR-<version>.apk
node vr/tests/vr.test.js   # VR checks (bundle, boot of the VR browser.ks, shim contract, manifest)
node vr/tests/vr-games.test.js   # VR API on a fake WebXR runtime + bots play the 3 VR games (npm run test:vr runs both)
```
Needs JDK 17, Android SDK (platform 34, build-tools 34), Gradle 8.7 and node. Version: `vr/version.json`.
To sign with your own key set `KOMPASS_VR_KEYSTORE`, `KOMPASS_VR_KEYSTORE_PASS` (and optionally `KOMPASS_VR_KEY_ALIAS`);
keep the keystore **outside** the repo. Updates install over the old version only when signed with the same key.

Preview the VR UI in a desktop browser: serve `android/app/src/main/assets/www/` and open `www/index.html`
(the shim falls back to localStorage and iframes; `vr/tests/screenshot.js` and `vr/tests/screenshot-games.js` take
Quest-size screenshots).

## Install on a Quest
1. In the **Meta Horizon** phone app: Devices → your headset → Headset settings → **Developer mode** → on
   (needs a Meta developer account, free). Restart the headset.
2. Connect the Quest to your PC with a USB-C cable, put it on and allow **USB debugging** ("Always allow").
3. Install, either
   - **adb**: `adb install -r Kompass-VR-<version>.apk` (Android platform-tools), or
   - **SideQuest**: drag the APK onto SideQuest's "Install APK" button.
4. On the Quest: App Library → filter **Unknown Sources** → **Kompass VR**.

## Not done yet / differences from Windows
- Password autofill / "save password?" on web pages, and vault import/export.
- `tab_mute` mutes `<video>/<audio>` elements only; `tab_zoom` changes text zoom; Chromium DevTools for a page =
  `chrome://inspect` on a PC over adb.
- The Learn videos are bundled in the APK (about 29 MB of the size).
- A native web view always draws above the KampfScript UI, so while a popup/quick menu covers the page area the page
  is hidden for that moment.
- High scores of a game played in the Quest Browser (immersive) are stored by the browser, separate from the
  ones of the same game played on the panel.
