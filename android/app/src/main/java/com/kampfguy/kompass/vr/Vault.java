package com.kampfguy.kompass.vr;

import android.os.Handler;
import android.os.Looper;
import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

import javax.crypto.Cipher;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

/** Kompass VR password vault: PBKDF2-HMAC-SHA256 (master password) -> AES-256-GCM, stored in the app's private files.
 *  (The Windows vault uses scrypt; the files are not interchangeable.) Auto-locks after 5 minutes without use. */
final class Vault {
    private static final int ITER = 210000;
    private static final SecureRandom RNG = new SecureRandom();
    private final File file;
    private final Runnable onLock;
    private final Handler h = new Handler(Looper.getMainLooper());
    private final Runnable lockTask = this::lock;
    private byte[] key, salt;
    private JSONArray items = new JSONArray();

    Vault(File f, Runnable onLock) { file = f; this.onLock = onLock; }

    synchronized boolean exists() { return file.exists(); }
    synchronized boolean unlocked() { return key != null; }
    synchronized int count() { return key == null ? 0 : items.length(); }
    private void touch() { h.removeCallbacks(lockTask); if (key != null) h.postDelayed(lockTask, 5 * 60 * 1000); }
    synchronized void lock() { boolean was = key != null; key = null; items = new JSONArray(); h.removeCallbacks(lockTask); if (was) onLock.run(); }
    private void need() throws Exception { if (key == null) throw new Exception("Vault is locked"); touch(); }

    private static byte[] kdf(String pw, byte[] salt, int iter) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(pw.toCharArray(), salt, iter, 256);
        return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
    }
    private static String b64(byte[] b) { return Base64.encodeToString(b, Base64.NO_WRAP); }
    private static byte[] unb64(String s) { return Base64.decode(s, Base64.NO_WRAP); }

    synchronized Object unlock(String master) throws Exception {
        if (!exists()) {
            if (master.length() < 8) return new JSONObject().put("ok", false).put("error", "Choose a master password of at least 8 characters");
            salt = new byte[16]; RNG.nextBytes(salt); key = kdf(master, salt, ITER); items = new JSONArray(); write(); touch();
            return new JSONObject().put("ok", true).put("created", true);
        }
        JSONObject f = new JSONObject(new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8));
        byte[] s = unb64(f.getString("salt")); byte[] k = kdf(master, s, f.optInt("iter", ITER));
        try {
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, new SecretKeySpec(k, "AES"), new GCMParameterSpec(128, unb64(f.getString("iv"))));
            items = new JSONObject(new String(c.doFinal(unb64(f.getString("data"))), StandardCharsets.UTF_8)).getJSONArray("items");
        } catch (Exception e) { return new JSONObject().put("ok", false).put("error", "Wrong master password"); }
        salt = s; key = k; touch();
        return new JSONObject().put("ok", true);
    }

    private void write() throws Exception {
        byte[] iv = new byte[12]; RNG.nextBytes(iv);
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, iv));
        byte[] data = c.doFinal(new JSONObject().put("items", items).toString().getBytes(StandardCharsets.UTF_8));
        JSONObject out = new JSONObject().put("v", 1).put("kdf", "pbkdf2-sha256").put("iter", ITER).put("salt", b64(salt)).put("iv", b64(iv)).put("data", b64(data));
        File tmp = new File(file.getPath() + ".tmp");
        try (FileOutputStream o = new FileOutputStream(tmp)) { o.write(out.toString().getBytes(StandardCharsets.UTF_8)); }
        if (!tmp.renameTo(file)) throw new Exception("could not save the vault");
    }

    static String originOf(String u) {
        try { URI x = new URI(u); String s = x.getScheme(); if (!"http".equals(s) && !"https".equals(s) || x.getHost() == null) return "";
            return s + "://" + x.getHost().toLowerCase() + (x.getPort() > 0 ? ":" + x.getPort() : ""); } catch (Exception e) { return ""; }
    }

    synchronized JSONArray list(String q) throws Exception {
        need(); q = q == null ? "" : q.toLowerCase(); JSONArray r = new JSONArray();
        for (int i = 0; i < items.length(); i++) {
            JSONObject it = items.getJSONObject(i);
            if (!q.isEmpty() && !(it.optString("origin") + " " + it.optString("username")).toLowerCase().contains(q)) continue;
            r.put(new JSONObject().put("id", it.getString("id")).put("origin", it.optString("origin")).put("username", it.optString("username")).put("updated", it.optLong("updated")));
        }
        return r;
    }
    private JSONObject find(String id) throws Exception { for (int i = 0; i < items.length(); i++) if (items.getJSONObject(i).getString("id").equals(id)) return items.getJSONObject(i); return null; }
    synchronized String password(String id) throws Exception { need(); JSONObject it = find(id); return it == null ? null : it.optString("password", ""); }
    synchronized String save(String id, String origin, String user, String pw) throws Exception {
        need(); String o = originOf(origin); if (o.isEmpty()) o = originOf("https://" + origin);
        if (o.isEmpty()) throw new Exception("Site must be a web address like https://example.com");
        JSONObject it = id != null ? find(id) : null;
        if (it == null && id == null) for (int i = 0; i < items.length(); i++) { JSONObject x = items.getJSONObject(i); if (x.optString("origin").equals(o) && x.optString("username").equals(user)) { it = x; break; } }
        if (it == null) { it = new JSONObject().put("id", UUID.randomUUID().toString()).put("created", System.currentTimeMillis()); items.put(it); }
        it.put("origin", o).put("username", user == null ? "" : user); if (pw != null) it.put("password", pw);
        it.put("updated", System.currentTimeMillis()); write(); return it.getString("id");
    }
    synchronized void remove(String id) throws Exception {
        need(); JSONArray n = new JSONArray(); for (int i = 0; i < items.length(); i++) if (!items.getJSONObject(i).getString("id").equals(id)) n.put(items.getJSONObject(i));
        items = n; write();
    }

    static String generate(int len) {
        int n = Math.max(8, Math.min(64, len <= 0 ? 20 : len));
        String[] sets = {"ABCDEFGHJKLMNPQRSTUVWXYZ", "abcdefghijkmnopqrstuvwxyz", "23456789", "!@#$%^&*-_=+?"};
        String all = String.join("", sets); List<Character> out = new ArrayList<>();
        for (String s : sets) out.add(s.charAt(RNG.nextInt(s.length())));
        while (out.size() < n) out.add(all.charAt(RNG.nextInt(all.length())));
        Collections.shuffle(out, RNG);
        StringBuilder b = new StringBuilder(); for (char ch : out) b.append(ch); return b.toString();
    }
}
