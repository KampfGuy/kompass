package com.kampfguy.kompass.vr;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import org.json.JSONObject;

/**
 * Kompass VR main window: one full-panel WebView runs the KampfScript runtime (src/lang.js + host.js + browser.ks,
 * served from the APK assets at https://appassets.androidplatform.net/assets/www/). Web pages open in separate
 * native WebViews (WebTabs) positioned over the UI's page area. Only the UI WebView gets the KompassAndroid bridge.
 */
public class MainActivity extends Activity {
    static final String TAG = "KompassVR";
    static final String HOST = "appassets.androidplatform.net";
    static final String START = "https://" + HOST + "/assets/www/index.html";

    FrameLayout root;
    WebView ui;
    WebTabs tabs;
    Bridge bridge;
    View fullscreenView;
    WebChromeClient.CustomViewCallback fullscreenCb;
    boolean uiReady = false;
    String pendingUrl = null;

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(16, 20, 31));

        ui = new WebView(this);
        ui.setBackgroundColor(Color.rgb(16, 20, 31));
        WebSettings s = ui.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setSupportZoom(false);
        s.setTextZoom(100);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        ui.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest r) {
                return AssetServer.serve(MainActivity.this, r.getUrl());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if (HOST.equals(u.getHost())) return false;
                openExternal(u.toString());          // the UI window never navigates away from Kompass itself
                return true;
            }
            @Override public void onPageFinished(WebView v, String url) {
                uiReady = true;
                if (pendingUrl != null) { emit("open-tab", JSONObject.quote(pendingUrl)); pendingUrl = null; }
            }
        });
        ui.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onConsoleMessage(ConsoleMessage m) {
                Log.i(TAG, "[ui] " + m.message() + " (" + m.sourceId() + ":" + m.lineNumber() + ")");
                return true;
            }
        });
        tabs = new WebTabs(this);
        bridge = new Bridge(this);
        ui.addJavascriptInterface(bridge, "KompassAndroid");
        root.addView(ui, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);
        hideSystemBars();
        handleIntent(getIntent());
        ui.loadUrl(START);
    }

    /** Quest panels have no system bars; on other Android devices give Kompass the whole screen too. */
    void hideSystemBars() {
        if (android.os.Build.VERSION.SDK_INT >= 30 && getWindow().getInsetsController() != null) {
            getWindow().getInsetsController().hide(android.view.WindowInsets.Type.systemBars());
            getWindow().getInsetsController().setSystemBarsBehavior(android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        }
    }

    @Override protected void onNewIntent(Intent i) { super.onNewIntent(i); handleIntent(i); }

    void handleIntent(Intent i) {
        if (i == null || !Intent.ACTION_VIEW.equals(i.getAction()) || i.getData() == null) return;
        String u = i.getData().toString();
        if (!u.startsWith("http://") && !u.startsWith("https://")) return;
        if (uiReady) emit("open-tab", JSONObject.quote(u)); else pendingUrl = u;
    }

    /** Send an event to the shim: window.__kvr.emit(name, json). Safe to call from any thread. */
    void emit(String ev, String json) {
        final String js = "window.__kvr&&window.__kvr.emit(" + JSONObject.quote(ev) + "," + JSONObject.quote(json == null ? "null" : json) + ")";
        runOnUiThread(() -> ui.evaluateJavascript(js, null));
    }

    void js(String code) { runOnUiThread(() -> ui.evaluateJavascript(code, null)); }

    void openExternal(String url) {
        try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); }
        catch (Exception e) { Log.w(TAG, "no app for " + url); }
    }

    // ---- HTML5 fullscreen (YouTube etc.) from a web tab
    void showFullscreen(View v, WebChromeClient.CustomViewCallback cb) {
        if (fullscreenView != null) { cb.onCustomViewHidden(); return; }
        fullscreenView = v; fullscreenCb = cb;
        root.addView(v, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }
    void hideFullscreen() {
        if (fullscreenView == null) return;
        root.removeView(fullscreenView); fullscreenView = null;
        if (fullscreenCb != null) fullscreenCb.onCustomViewHidden(); fullscreenCb = null;
    }

    @Override
    public void onBackPressed() {
        if (fullscreenView != null) { hideFullscreen(); return; }
        emit("key", JSONObject.quote("alt+arrowleft"));   // browser.ks: on_key("alt+arrowleft") = Back
    }

    @Override protected void onPause() { super.onPause(); ui.onPause(); tabs.pauseAll(true); }
    @Override protected void onResume() { super.onResume(); ui.onResume(); tabs.pauseAll(false); }
    @Override protected void onDestroy() { tabs.destroyAll(); ui.destroy(); super.onDestroy(); }
}
