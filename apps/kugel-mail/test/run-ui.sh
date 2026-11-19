#!/bin/bash
# usage: run.sh test.js [keep]   (keep = do not wipe the profile)
cd /workspace/kompass-win3d/apps/kugel-mail
[ "$2" != keep ] && rm -rf /tmp/kmail/home /tmp/kmail/data; mkdir -p /tmp/kmail/home /tmp/kmail/save
HOME=/tmp/kmail/home KUGELMAIL_DATA=/tmp/kmail/data KUGELMAIL_TEST_ALLOW_BASIC=1 KUGELMAIL_TEST_SAVE_DIR=/tmp/kmail/save KUGELMAIL_TEST_PICK=/tmp/kmail/homework.txt KUGELMAIL_TEST_SCRIPT="$1" KUGELMAIL_TEST_OUT=/tmp/kmail \
 timeout 200 xvfb-run -a -s "-screen 0 1400x900x24" npx electron . --no-sandbox --password-store=basic 2>&1 | grep -v -E "dbus|Fontconfig|GPU|gpu_|viz_|ozone|egl|gl_|libva|sandbox" | tail -n 60
