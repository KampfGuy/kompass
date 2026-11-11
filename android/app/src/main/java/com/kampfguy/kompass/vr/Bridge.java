package com.kampfguy.kompass.vr;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * window.KompassAndroid — the Android side of window.native (see vr/web/native-shim.js). Replaces what Electron's
 * main.js does on Windows: profile files, browser.ks, scripts, password vault, clipboard, network without CORS,
 * and the native web tabs. Results are JSON {"r": value} or {"e": "message"}.
 */
final class Bridge {
    private final MainActivity act;
    private final File data, scripts, userKs, shippedKs;
    private final Vault vault;
    private final ExecutorService pool = Executors.newFixedThreadPool(3);
    private final Handler main = new Handler(Looper.getMainLooper());

    Bridge(MainActivity a) {
        act = a;
        data = new File(a.getFilesDir(), "data"); scripts = new File(a.getFilesDir(), "scripts");
        data.mkdirs(); scripts.mkdirs();
        userKs = new File(a.getFilesDir(), "browser.ks"); shippedKs = new File(a.getFilesDir(), "browser.ks.shipped");
        vault = new Vault(new File(a.getFilesDir(), "vault-vr.kpv"), () -> act.emit("pw-locked", "null"));
    }

    static String safeName(String n) {
        String s = String.valueOf(n).replaceAll("[^a-zA-Z0-9_.-]", "_");
        if (s.length() > 80) s = s.substring(0, 80);
        if (s.isEmpty() || s.equals(".") || s.equals("..")) s = "_";
        return s;
    }
    private static String read(File f) throws Exception { return new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8); }
    private static void write(File f, String s) throws Exception {
        File tmp = new File(f.getPath() + ".tmp");
        try (OutputStream o = new FileOutputStream(tmp)) { o.write(s.getBytes(StandardCharsets.UTF_8)); }
        if (!tmp.renameTo(f)) throw new Exception("could not write " + f.getName());
    }
    private String asset(String p) throws Exception {
        try (InputStream in = act.getAssets().open(p)) { return new String(readAll(in, 64 << 20), StandardCharsets.UTF_8); }
    }
    private static byte[] readAll(InputStream in, int max) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream(); byte[] buf = new byte[16384]; int n;
        while ((n = in.read(buf)) > 0) { b.write(buf, 0, n); if (b.size() > max) throw new Exception("too big"); }
        return b.toByteArray();
    }
    /** Run on the UI thread and wait (tab and clipboard calls). */
    private void ui(Runnable r) {
        if (Looper.myLooper() == Looper.getMainLooper()) { r.run(); return; }
        CountDownLatch l = new CountDownLatch(1);
        main.post(() -> { try { r.run(); } finally { l.countDown(); } });
        try { l.await(); } catch (InterruptedException ignored) {}
    }
    private static Object ok(Object... kv) throws Exception { JSONObject j = new JSONObject(); for (int i = 0; i + 1 < kv.length; i += 2) j.put((String) kv[i], kv[i + 1]); return j; }
    private static Object err(Exception e) { try { return ok("ok", false, "error", e.getMessage() == null ? e.toString() : e.getMessage()); } catch (Exception x) { return JSONObject.NULL; } }

    // Same upgrade rule as main.js: keep the user's edited browser.ks, replace an unmodified older shipped copy.
    private String browserSource() throws Exception {
        String dflt = asset("www/ks/browser.ks");
        if (!userKs.exists()) { write(userKs, dflt); write(shippedKs, dflt); return dflt; }
        String cur = read(userKs);
        if (!cur.equals(dflt)) {
            String prev = shippedKs.exists() ? read(shippedKs) : null;
            if (prev != null && cur.equals(prev)) { write(userKs, dflt); cur = dflt; }
            write(shippedKs, dflt);
        }
        return cur;
    }

    @JavascriptInterface
    public String call(String method, String argsJson) {
        JSONObject res = new JSONObject();
        try {
            JSONArray a = new JSONArray(argsJson == null ? "[]" : argsJson);
            res.put("r", dispatch(method, a));
        } catch (Exception e) {
            try { res.put("e", method + ": " + (e.getMessage() == null ? e.toString() : e.getMessage())); } catch (Exception ignored) {}
        }
        return res.toString();
    }

    @JavascriptInterface
    public void callAsync(final int id, final String method, final String argsJson) {
        pool.execute(() -> {
            JSONObject res = new JSONObject();
            try { JSONArray a = new JSONArray(argsJson == null ? "[]" : argsJson); res.put("r", dispatchAsync(method, a)); }
            catch (Exception e) { try { res.put("r", err(e)); } catch (Exception ignored) {} }
            act.js("window.__kvr&&window.__kvr.done(" + id + "," + JSONObject.quote(res.toString()) + ")");
        });
    }

    private Object dispatch(String m, final JSONArray a) throws Exception {
        switch (m) {
            case "browserSource": return browserSource();
            case "saveBrowserSource": write(userKs, a.getString(0)); return true;
            case "paths": return ok("data", data.getPath(), "scripts", scripts.getPath(), "browserKs", userKs.getPath());
            case "load": { File f = new File(data, safeName(a.getString(0)) + ".json"); return f.exists() ? read(f) : JSONObject.NULL; }
            case "save": write(new File(data, safeName(a.getString(0)) + ".json"), a.getString(1)); return true;
            case "listScripts": { JSONArray r = new JSONArray(); String[] l = scripts.list(); if (l != null) { Arrays.sort(l); for (String s : l) if (s.endsWith(".ks")) r.put(s); } return r; }
            case "readScript": { File f = new File(scripts, safeName(a.getString(0))); return f.isFile() ? read(f) : JSONObject.NULL; }
            case "writeScript": { String f = safeName(a.getString(0)); if (!f.endsWith(".ks")) f += ".ks"; write(new File(scripts, f), a.getString(1)); return f; }
            case "adblock": { if (!a.isNull(0)) act.tabs.blockOn = a.getBoolean(0); return ok("on", act.tabs.blockOn, "blocked", act.tabs.blocked); }
            case "openExternal": { String u = a.getString(0); if (u.startsWith("http://") || u.startsWith("https://")) act.openExternal(u); return true; }
            case "copyText": { final String t = a.getString(0); ui(() -> clip(t)); return true; }
            case "toast": { final String t = a.getString(0); main.post(() -> Toast.makeText(act, t, Toast.LENGTH_LONG).show()); return true; }
            case "quit": main.post(act::finishAndRemoveTask); return true;
            case "webDebugging": main.post(() -> WebView.setWebContentsDebuggingEnabled(true)); return true;
            // ---- native web tabs
            case "tabCreate": { final int id = a.getInt(0); main.post(() -> act.tabs.create(id)); return true; }
            case "tabRect": { final int id = a.getInt(0), x = a.getInt(1), y = a.getInt(2), w = a.getInt(3), h = a.getInt(4); final boolean v = a.getBoolean(5); main.post(() -> act.tabs.rect(id, x, y, w, h, v)); return true; }
            case "tabLoad": { final int id = a.getInt(0); final String u = a.getString(1); main.post(() -> act.tabs.load(id, u)); return true; }
            case "tabBack": { final int id = a.getInt(0); main.post(() -> act.tabs.back(id)); return true; }
            case "tabForward": { final int id = a.getInt(0); main.post(() -> act.tabs.forward(id)); return true; }
            case "tabReload": { final int id = a.getInt(0); main.post(() -> act.tabs.reload(id)); return true; }
            case "tabStop": { final int id = a.getInt(0); main.post(() -> act.tabs.stop(id)); return true; }
            case "tabZoom": { final int id = a.getInt(0); final double f = a.getDouble(1); main.post(() -> act.tabs.zoom(id, f)); return true; }
            case "tabFind": { final int id = a.getInt(0); final String q = a.getString(1); main.post(() -> act.tabs.find(id, q)); return true; }
            case "tabMute": { final int id = a.getInt(0); final boolean on = a.getBoolean(1); main.post(() -> act.tabs.mute(id, on)); return true; }
            case "tabDestroy": { final int id = a.getInt(0); main.post(() -> act.tabs.destroy(id)); return true; }
            // ---- password vault (passwords never reach KampfScript; host.js only passes them through secret fields)
            case "pwStatus": return ok("exists", vault.exists(), "unlocked", vault.unlocked(), "count", vault.count());
            case "pwUnlock": try { return vault.unlock(a.getString(0)); } catch (Exception e) { return err(e); }
            case "pwLock": vault.lock(); return true;
            case "pwList": try { return ok("ok", true, "items", vault.list(a.optString(0, ""))); } catch (Exception e) { return err(e); }
            case "pwSave": try { return ok("ok", true, "id", vault.save(a.isNull(0) ? null : a.getString(0), a.getString(1), a.optString(2, ""), a.isNull(3) ? null : a.getString(3))); } catch (Exception e) { return err(e); }
            case "pwDelete": try { vault.remove(a.getString(0)); return ok("ok", true); } catch (Exception e) { return err(e); }
            case "pwReveal": try { String p = vault.password(a.getString(0)); return p == null ? ok("ok", false, "error", "not found") : ok("ok", true, "password", p); } catch (Exception e) { return err(e); }
            case "pwCopy": try {
                final String p = vault.password(a.getString(0)); if (p == null) return ok("ok", false);
                ui(() -> clip(p));
                main.postDelayed(() -> { ClipboardManager cm = (ClipboardManager) act.getSystemService(Context.CLIPBOARD_SERVICE); ClipData c = cm.getPrimaryClip();
                    if (c != null && c.getItemCount() > 0 && p.contentEquals(String.valueOf(c.getItemAt(0).getText()))) cm.setPrimaryClip(ClipData.newPlainText("", "")); }, 30000);
                return ok("ok", true); } catch (Exception e) { return err(e); }
            case "pwGenerate": return Vault.generate(a.optInt(0, 20));
            default: throw new Exception("unknown method");
        }
    }

    private Object dispatchAsync(String m, JSONArray a) throws Exception {
        switch (m) {
            case "http": return http(a.getJSONObject(0));
            case "clearBrowsingData": ui(() -> act.tabs.clearAll()); new File(data, "history.json").delete(); return true;
            case "saveTextFile": {
                File dir = act.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS); if (dir == null) dir = new File(act.getFilesDir(), "Download");
                dir.mkdirs(); File f = new File(dir, safeName(a.getString(0))); write(f, a.getString(1));
                final String p = f.getPath(); main.post(() -> Toast.makeText(act, "Saved " + p, Toast.LENGTH_LONG).show()); return p;
            }
            default: throw new Exception("unknown async method " + m);
        }
    }

    private void clip(String t) { ((ClipboardManager) act.getSystemService(Context.CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("Kompass", t)); }

    // Network for the Kugel search proxy, the Kugel Store and the update check (no browser Origin / CORS).
    private Object http(JSONObject q) throws Exception {
        String url = q.getString("url");
        if (!url.startsWith("https://")) return ok("error", "only https");
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        try {
            c.setConnectTimeout(15000); c.setReadTimeout(45000);
            c.setInstanceFollowRedirects(!q.optBoolean("noRedirect", false));
            c.setRequestMethod(q.optString("method", "GET"));
            c.setRequestProperty("User-Agent", "Kompass-VR/" + BuildConfig.VERSION_NAME);
            JSONObject h = q.optJSONObject("headers");
            if (h != null) for (Iterator<String> it = h.keys(); it.hasNext(); ) { String k = it.next(); c.setRequestProperty(k, h.getString(k)); }
            if (!q.isNull("body") && q.has("body")) { c.setDoOutput(true); try (OutputStream o = c.getOutputStream()) { o.write(q.getString("body").getBytes(StandardCharsets.UTF_8)); } }
            int st = c.getResponseCode();
            if (st >= 300 && st < 400 && q.optBoolean("noRedirect", false)) return ok("error", "redirect not allowed (HTTP " + st + ")");
            InputStream in = st >= 400 ? c.getErrorStream() : c.getInputStream();
            String body = in == null ? "" : new String(readAll(in, 8 << 20), StandardCharsets.UTF_8);
            return ok("status", st, "body", body);
        } finally { c.disconnect(); }
    }
}
