package com.kampfguy.kompass.vr;

import android.content.Context;
import android.net.Uri;
import android.webkit.WebResourceResponse;

import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/** Serves the APK's assets/www/ at https://appassets.androidplatform.net/assets/www/ (a secure, same-origin URL). */
final class AssetServer {
    private static final Map<String, String> MIME = new HashMap<>();
    static {
        MIME.put("html", "text/html"); MIME.put("js", "text/javascript"); MIME.put("css", "text/css");
        MIME.put("svg", "image/svg+xml"); MIME.put("png", "image/png"); MIME.put("jpg", "image/jpeg");
        MIME.put("ttf", "font/ttf"); MIME.put("json", "application/json"); MIME.put("mp4", "video/mp4"); MIME.put("webm", "video/webm");
        MIME.put("ks", "text/plain"); MIME.put("md", "text/plain"); MIME.put("txt", "text/plain");
    }
    static WebResourceResponse serve(Context c, Uri u) {
        if (!MainActivity.HOST.equals(u.getHost()) || !"https".equals(u.getScheme())) return null;
        String p = u.getPath();
        if (p == null || !p.startsWith("/assets/www/") || p.contains("..")) return notFound();
        String rel = p.substring("/assets/".length());
        String ext = rel.contains(".") ? rel.substring(rel.lastIndexOf('.') + 1).toLowerCase() : "";
        String mime = MIME.containsKey(ext) ? MIME.get(ext) : "application/octet-stream";
        try {
            InputStream in = c.getAssets().open(rel);
            WebResourceResponse r = new WebResourceResponse(mime, mime.startsWith("text/") || mime.endsWith("json") ? "utf-8" : null, in);
            Map<String, String> h = new HashMap<>();
            h.put("Cache-Control", "no-cache");
            h.put("Access-Control-Allow-Origin", "https://" + MainActivity.HOST);
            r.setResponseHeaders(h);
            return r;
        } catch (Exception e) { return notFound(); }
    }
    private static WebResourceResponse notFound() {
        WebResourceResponse r = new WebResourceResponse("text/plain", "utf-8", new java.io.ByteArrayInputStream(new byte[0]));
        r.setStatusCodeAndReasonPhrase(404, "Not Found");
        return r;
    }
}
