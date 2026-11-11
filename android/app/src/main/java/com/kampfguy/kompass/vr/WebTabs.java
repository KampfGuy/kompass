package com.kampfguy.kompass.vr;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Message;
import android.util.Base64;
import android.view.MotionEvent;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.GeolocationPermissions;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebStorage;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * The real web pages: one native WebView per Kompass tab, laid over the <kompass-webview> placeholder that
 * browser.ks put in its page area (the shim reports its rectangle). Web content NEVER gets the KompassAndroid bridge.
 * Events go back to host.js as Electron-like webview events through window.__kvr.tab(id, ev, json).
 * All methods must run on the UI thread.
 */
final class WebTabs {
    private final MainActivity act;
    private final Map<Integer, WebView> views = new HashMap<>();
    private final Set<String> blocklist = new HashSet<>();
    volatile boolean blockOn = true;
    volatile int blocked = 0;
    private float lastX, lastY;

    WebTabs(MainActivity a) {
        act = a;
        try (BufferedReader r = new BufferedReader(new InputStreamReader(a.getAssets().open("www/ks/blocklist.txt")))) {
            String l; while ((l = r.readLine()) != null) { l = l.trim(); if (!l.isEmpty() && !l.startsWith("#")) blocklist.add(l.toLowerCase()); }
        } catch (Exception ignored) {}
    }

    private boolean isBlocked(String host) {
        if (host == null) return false; host = host.toLowerCase();
        while (true) { if (blocklist.contains(host)) return true; int i = host.indexOf('.'); if (i < 0) return false; host = host.substring(i + 1); }
    }

    private void send(int id, String ev, JSONObject d) {
        WebView v = views.get(id);
        try { if (v != null) { d.put("canBack", v.canGoBack()); d.put("canFwd", v.canGoForward()); } } catch (Exception ignored) {}
        act.js("window.__kvr&&window.__kvr.tab(" + id + "," + JSONObject.quote(ev) + "," + JSONObject.quote(d.toString()) + ")");
    }
    private static JSONObject o(Object... kv) { JSONObject j = new JSONObject(); try { for (int i = 0; i + 1 < kv.length; i += 2) j.put((String) kv[i], kv[i + 1]); } catch (Exception ignored) {} return j; }

    @SuppressLint({"SetJavaScriptEnabled", "ClickableViewAccessibility"})
    void create(final int id) {
        if (views.containsKey(id)) return;
        final WebView v = new WebView(act);
        v.setBackgroundColor(Color.WHITE);
        WebSettings s = v.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setSupportZoom(true); s.setBuiltInZoomControls(true); s.setDisplayZoomControls(false);
        s.setUseWideViewPort(true); s.setLoadWithOverviewMode(true);
        s.setSupportMultipleWindows(true);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setAllowFileAccess(false); s.setAllowContentAccess(false);
        s.setUserAgentString(s.getUserAgentString() + " KompassVR/" + BuildConfig.VERSION_NAME);
        CookieManager.getInstance().setAcceptThirdPartyCookies(v, true);
        v.setVisibility(View.GONE);

        v.setWebViewClient(new WebViewClient() {
            @Override public void onPageStarted(WebView w, String url, Bitmap fav) {
                send(id, "start", o());
                send(id, "navigate", o("url", url));
            }
            @Override public void onPageFinished(WebView w, String url) { send(id, "stop", o("url", url)); }
            @Override public void doUpdateVisitedHistory(WebView w, String url, boolean reload) { send(id, "navigate-in-page", o("url", url)); }
            @Override public void onReceivedError(WebView w, WebResourceRequest r, WebResourceError e) {
                if (r.isForMainFrame()) send(id, "fail", o("code", e.getErrorCode(), "description", String.valueOf(e.getDescription())));
            }
            @Override public boolean shouldOverrideUrlLoading(WebView w, WebResourceRequest r) {
                String sch = r.getUrl().getScheme();
                if ("http".equals(sch) || "https".equals(sch)) return false;
                if ("about".equals(sch) || "data".equals(sch) || "blob".equals(sch)) return false;
                act.openExternal(r.getUrl().toString());   // intent:, mailto:, market: ... -> system
                return true;
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView w, WebResourceRequest r) {
                if (blockOn && !r.isForMainFrame() && isBlocked(r.getUrl().getHost())) {
                    blocked++;
                    return new WebResourceResponse("text/plain", "utf-8", 204, "Blocked", new HashMap<>(), new ByteArrayInputStream(new byte[0]));
                }
                return null;
            }
        });
        v.setWebChromeClient(new WebChromeClient() {
            @Override public void onReceivedTitle(WebView w, String t) { send(id, "title", o("title", t)); }
            @Override public void onReceivedIcon(WebView w, Bitmap icon) {
                try { Bitmap b = Bitmap.createScaledBitmap(icon, 32, 32, true); ByteArrayOutputStream bo = new ByteArrayOutputStream(); b.compress(Bitmap.CompressFormat.PNG, 100, bo);
                    send(id, "favicon", o("favicon", "data:image/png;base64," + Base64.encodeToString(bo.toByteArray(), Base64.NO_WRAP))); } catch (Exception ignored) {}
            }
            @Override public void onShowCustomView(View view, CustomViewCallback cb) { act.showFullscreen(view, cb); }
            @Override public void onHideCustomView() { act.hideFullscreen(); }
            @Override public void onPermissionRequest(PermissionRequest r) { r.deny(); }          // no camera / mic in Kompass VR
            @Override public void onGeolocationPermissionsShowPrompt(String o, GeolocationPermissions.Callback cb) { cb.invoke(o, false, false); }
            // target=_blank / window.open: capture the URL and let browser.ks open it as a new Kompass tab
            @Override public boolean onCreateWindow(WebView w, boolean dialog, boolean gesture, Message msg) {
                final WebView tmp = new WebView(act);
                tmp.setWebViewClient(new WebViewClient() {
                    boolean done = false;
                    void take(String u) { if (done || u == null || u.startsWith("about:")) return; done = true; act.emit("open-tab", JSONObject.quote(u)); tmp.post(tmp::destroy); }
                    @Override public boolean shouldOverrideUrlLoading(WebView x, WebResourceRequest r) { take(r.getUrl().toString()); return true; }
                    @Override public void onPageStarted(WebView x, String u, Bitmap f) { take(u); }
                });
                ((WebView.WebViewTransport) msg.obj).setWebView(tmp);
                msg.sendToTarget();
                return true;
            }
        });
        v.setDownloadListener((url, ua, cd, mime, len) -> act.openExternal(url));

        // VR has no right mouse button: a long trigger press / pinch-hold opens the Kompass quick menu
        v.setOnTouchListener((w, e) -> { if (e.getActionMasked() == MotionEvent.ACTION_DOWN) { lastX = e.getX(); lastY = e.getY(); } return false; });
        v.setOnLongClickListener(w -> {
            WebView.HitTestResult h = v.getHitTestResult();
            int t = h == null ? WebView.HitTestResult.UNKNOWN_TYPE : h.getType();
            if (t == WebView.HitTestResult.EDIT_TEXT_TYPE) return false;   // keep paste / text selection in fields
            String link = (t == WebView.HitTestResult.SRC_ANCHOR_TYPE || t == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE) ? h.getExtra() : "";
            float d = act.getResources().getDisplayMetrics().density;
            send(id, "longpress", o("x", lastX / d, "y", lastY / d, "link", link == null ? "" : link));
            return true;
        });

        act.root.addView(v, new FrameLayout.LayoutParams(1, 1));
        views.put(id, v);
    }

    void rect(int id, int x, int y, int w, int h, boolean visible) {
        WebView v = views.get(id); if (v == null) return;
        if (!visible) { v.setVisibility(View.GONE); return; }
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(Math.max(1, w), Math.max(1, h));
        lp.leftMargin = act.ui.getLeft() + x; lp.topMargin = act.ui.getTop() + y;
        v.setLayoutParams(lp);
        if (v.getVisibility() != View.VISIBLE) { v.setVisibility(View.VISIBLE); v.bringToFront(); }
        if (act.fullscreenView != null) act.fullscreenView.bringToFront();
    }

    void load(int id, String url) {
        WebView v = views.get(id); if (v == null) return;
        Uri u = Uri.parse(url); String sch = u.getScheme();
        if ("http".equals(sch) || "https".equals(sch) || "about:blank".equals(url)) v.loadUrl(url);
    }
    void back(int id) { WebView v = views.get(id); if (v != null && v.canGoBack()) v.goBack(); }
    void forward(int id) { WebView v = views.get(id); if (v != null && v.canGoForward()) v.goForward(); }
    void reload(int id) { WebView v = views.get(id); if (v != null) v.reload(); }
    void stop(int id) { WebView v = views.get(id); if (v != null) v.stopLoading(); }
    void zoom(int id, double f) { WebView v = views.get(id); if (v != null) v.getSettings().setTextZoom((int) Math.round(Math.max(0.3, Math.min(3, f)) * 100)); }
    void find(int id, String q) { WebView v = views.get(id); if (v == null) return; if (q == null || q.isEmpty()) v.clearMatches(); else v.findAllAsync(q); }
    void mute(int id, boolean on) {
        WebView v = views.get(id);
        if (v != null) v.evaluateJavascript("document.querySelectorAll('video,audio').forEach(function(m){m.muted=" + on + "})", null);
    }
    void destroy(int id) {
        WebView v = views.remove(id); if (v == null) return;
        act.root.removeView(v); v.stopLoading(); v.destroy();
    }
    void destroyAll() { for (Integer id : new HashSet<>(views.keySet())) destroy(id); }
    void pauseAll(boolean pause) { for (WebView v : views.values()) { if (pause) v.onPause(); else v.onResume(); } }
    void clearAll() {
        CookieManager.getInstance().removeAllCookies(null);
        CookieManager.getInstance().flush();
        WebStorage.getInstance().deleteAllData();
        for (WebView v : views.values()) { v.clearCache(true); v.clearHistory(); v.clearFormData(); }
    }
}
