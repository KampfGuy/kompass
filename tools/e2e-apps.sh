#!/bin/bash
# Headless Electron runs of the Kugel Design / Kugel Work store apps with real mouse + keyboard input
# (Linux + xvfb). Screenshots land in $OUT/shots. Usage: tools/e2e-apps.sh [script.js ...]   (default: all)
set -u
cd "$(dirname "$0")/.."
REPO=$PWD; E=$REPO/tests/e2e/apps; OUT=${OUT:-/tmp/kompass-e2e-apps}; PORT=${PORT:-18995}
rm -rf "$OUT"; mkdir -p "$OUT/shots" "$OUT/store"
node tools/build-apps.js >/dev/null && cp -r resources/store/entries resources/store/index.json "$OUT/store/"
(cd "$OUT/store" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) & SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT; sleep 1
declare -A OPEN=([lat-imp2.js]=excel-made.xlsx [paint-open.js]=u.png [vector-test.js]=test.svg [prism-test.js]=in.pptx)
LIST=("$@"); [ ${#LIST[@]} -eq 0 ] && LIST=(calc-test.js pa-test.js notes-test.js lattice-test.js lat-imp2.js paint-test.js paint-open.js vector-test.js motion-test.js prism-test.js)
for s in "${LIST[@]}"; do
  echo "=== $s"; f=""; [ -n "${OPEN[$s]:-}" ] && f="$E/fixtures/${OPEN[$s]}"
  rm -rf "$OUT/home" "$OUT/save"; mkdir -p "$OUT/home" "$OUT/save"
  HOME=$OUT/home KOMPASS_NO_UPDATER=1 KOMPASS_STORE_URL=http://127.0.0.1:$PORT KOMPASS_SAVE_DIR=$OUT/save KOMPASS_OPEN_FILE="$f" \
  KOMPASS_TEST_SCRIPT="$E/$s" KOMPASS_TEST_OUT="$OUT" timeout ${TMO:-300} xvfb-run -a -s "-screen 0 1600x1000x24" \
    npx electron . --no-sandbox --enable-unsafe-swiftshader --use-angle=swiftshader 2>&1 | grep -E "^\[|Error|error|FAIL|BAD|REG" | grep -v -E "dbus|ERROR:.*(ozone|egl|gl_|gpu|viz)"
done
ls "$OUT/shots"
