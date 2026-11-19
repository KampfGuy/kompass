# Kugel Mail tests

All tests use a **local** GreenMail server only (no real accounts):

    java -Dgreenmail.setup.test.all -Dgreenmail.hostname=127.0.0.1 \
         -Dgreenmail.users=kampf:secret123@test.local,friend:pw456@test.local \
         -jar greenmail-standalone-2.1.15.jar

* `npm test` – sanitizer/unit checks + IMAP/SMTP integration (skipped when GreenMail is not running)
* `node test/seed-greenmail.js` then `test/run-ui.sh test/ui-flow.js` – drives the real window (setup, read, blocked images, attachments, reply all, forward, search, delete); `test/run-ui.sh test/ui-relaunch.js keep` – account is remembered after restart
