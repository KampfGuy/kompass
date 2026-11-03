# Releasing Kompass (and how auto-update works)

Since **1.4.0** Kompass updates itself. Every release MUST contain these assets or installed copies won't update:

| asset | why |
|---|---|
| `Kompass-X.Y.Z-portable.exe` | the file the updater downloads and swaps in |
| `kompass-update.json` | manifest: version + `size` + `sha512` (base64) of each file — the updater refuses anything that doesn't match |
| `Kompass-X.Y.Z-win-x64.zip`, `SHA512SUMS.txt`, `KAMPFSCRIPT_FOR_AI.md` | manual downloads / checksums / docs |

## Steps
1. Bump `"version"` in `package.json` **and** `let VERSION = "…"` in `resources/browser.ks` (the script checks they match).
2. `npm run gen:ai` if built-ins changed, commit, push.
3. `node tools/release.js --notes notes.md` → runs `npm test`, builds the portable exe + zip, writes
   `dist/kompass-update.json` + `dist/SHA512SUMS.txt`, then `gh release create vX.Y.Z` with all assets.
   (`--no-publish` to build only, `--manifest-only` to just recompute the manifest.)
4. The release must be a normal (not draft, not pre-release) release so it is `releases/latest`.

## How the updater works (src/updater.js)
- On launch (+8 s) and every 4 h, if *Settings → Updates → Auto-update* is on (default), Kompass asks
  `https://api.github.com/repos/KampfGuy/kompass/releases/latest`, compares the tag with its own version (semver).
- If newer, it reads `kompass-update.json`, downloads the portable exe into `%APPDATA%\Kompass\kompass\updates\`
  with progress, and verifies size + sha512. Offline / API errors are silent (only the manual *Check for updates* button shows them).
- Then the UI shows **"Update ready — restart to update"**. *Restart to update* (or simply closing Kompass) writes
  `kompass-update.cmd`, which waits until the running exe is unlocked, copies the new exe over the file in
  `PORTABLE_EXECUTABLE_FILE` (the .exe you started), deletes the download, relaunches (restart only) and deletes itself.
  Log: `updates\update.log`.
- Zip / unpacked builds (no `PORTABLE_EXECUTABLE_FILE`) only show "X is available → Download" (opens the release page).
- Why not electron-updater/NSIS: building NSIS with electron-builder on Linux needs wine, which is not available on the build box.
  If wine becomes available, NSIS + electron-updater could replace this; the portable updater keeps working either way.

## Testing
- `npm test` includes `tests/v14.test.js` (semver, mock GitHub API + download server, sha/size checks, helper script, full swap+relaunch, UI).
- `npm run e2e:update` runs the real Electron app against a local mock GitHub, clicks *Restart to update*, and checks the swap + relaunch (Linux helper).
- Dev overrides: `KOMPASS_UPDATE_API`, `KOMPASS_UPDATE_TARGET`, `KOMPASS_UPDATE_DELAY_MS`, `KOMPASS_NO_UPDATER=1`.
