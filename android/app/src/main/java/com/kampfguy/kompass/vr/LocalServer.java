package com.kampfguy.kompass.vr;

import android.content.Context;
import android.util.Log;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Immersive VR hand-off. Android's System WebView has no WebXR, but the Quest Browser does. To play a Kugel Store
 * game in the headset, Kompass VR serves its OWN web bundle (assets/www, the same files the app runs) on
 * http://127.0.0.1:47653 — loopback only, a secure context for WebXR, a fixed port so best scores (localStorage) stay —
 * and opens index.html#play=<game id> in the Quest Browser. Read-only: GET/HEAD of packaged files, nothing else.
 */
final class LocalServer {
    static final int PORT = 47653;
    private static LocalServer instance;
    private final Context ctx;
    private ServerSocket server;
    private final ExecutorService pool = Executors.newFixedThreadPool(4);
    int port = 0;

    private LocalServer(Context c) { ctx = c.getApplicationContext(); }

    static synchronized LocalServer start(Context c) throws Exception {
        if (instance != null && instance.server != null && !instance.server.isClosed()) return instance;
        LocalServer s = new LocalServer(c);
        InetAddress lo = InetAddress.getByName("127.0.0.1");
        try { s.server = new ServerSocket(PORT, 16, lo); } catch (Exception e) { s.server = new ServerSocket(0, 16, lo); }
        s.port = s.server.getLocalPort();
        Thread t = new Thread(s::loop, "kompass-vr-local"); t.setDaemon(true); t.start();
        instance = s;
        Log.i(MainActivity.TAG, "local server on http://127.0.0.1:" + s.port + "/");
        return s;
    }

    String url(String path) { return "http://127.0.0.1:" + port + "/" + path; }

    private void loop() {
        while (!server.isClosed()) {
            try { final Socket c = server.accept(); pool.execute(() -> handle(c)); }
            catch (Exception e) { if (!server.isClosed()) Log.w(MainActivity.TAG, "local server: " + e); }
        }
    }

    static String path(String requestLine) {
        String[] p = requestLine.split(" ");
        if (p.length < 2 || !(p[0].equals("GET") || p[0].equals("HEAD"))) return null;
        String u = p[1]; int q = u.indexOf('?'); if (q >= 0) u = u.substring(0, q); q = u.indexOf('#'); if (q >= 0) u = u.substring(0, q);
        if (!u.startsWith("/") || u.contains("..") || u.contains("\\") || u.contains("%")) return null;
        if (u.equals("/")) u = "/index.html";
        return "www" + u;
    }

    private void handle(Socket c) {
        try (Socket s = c) {
            s.setSoTimeout(15000);
            BufferedReader in = new BufferedReader(new InputStreamReader(s.getInputStream(), StandardCharsets.UTF_8));
            String line = in.readLine(); if (line == null) return;
            while (true) { String h = in.readLine(); if (h == null || h.isEmpty()) break; }
            OutputStream out = s.getOutputStream();
            String rel = path(line);
            byte[] body = null;
            if (rel != null) { try (InputStream a = ctx.getAssets().open(rel)) { ByteArrayOutputStream b = new ByteArrayOutputStream(); byte[] buf = new byte[16384]; int n; while ((n = a.read(buf)) > 0) b.write(buf, 0, n); body = b.toByteArray(); } catch (Exception e) { body = null; } }
            if (body == null) { out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".getBytes(StandardCharsets.US_ASCII)); out.flush(); return; }
            String ext = rel.contains(".") ? rel.substring(rel.lastIndexOf('.') + 1).toLowerCase() : "";
            String mime = AssetServer.mime(ext);
            String head = "HTTP/1.1 200 OK\r\nContent-Type: " + mime + (mime.startsWith("text/") || mime.endsWith("json") ? "; charset=utf-8" : "")
                + "\r\nContent-Length: " + body.length + "\r\nCache-Control: no-cache\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n";
            out.write(head.getBytes(StandardCharsets.US_ASCII));
            if (line.startsWith("GET")) out.write(body);
            out.flush();
        } catch (Exception e) { Log.w(MainActivity.TAG, "local server request: " + e); }
    }
}
