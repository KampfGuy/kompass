package com.kampfguy.kompass.vr;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
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

    /** Immersive VR runs in the Quest Browser (it has WebXR; Android's WebView doesn't). */
    void openInXrBrowser(String url) {
        for (String pkg : new String[] { "com.oculus.browser", "com.android.chrome" }) {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)).setPackage(pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return; }
            catch (Exception ignored) { /* not installed */ }
        }
        try { startActivity(Intent.createChooser(new Intent(Intent.ACTION_VIEW, Uri.parse(url)), "Open in a browser with WebXR")); }
        catch (Exception e) { Log.w(TAG, "no browser for " + url); }
    }

    // ---- controllers / gamepads -> gamepad() in KampfScript (the shim turns these into a standard-mapping pad)
    private static int padButton(int code) {
        switch (code) {
            case KeyEvent.KEYCODE_BUTTON_A: return 0; case KeyEvent.KEYCODE_BUTTON_B: return 1;
            case KeyEvent.KEYCODE_BUTTON_X: return 2; case KeyEvent.KEYCODE_BUTTON_Y: return 3;
            case KeyEvent.KEYCODE_BUTTON_L1: return 4; case KeyEvent.KEYCODE_BUTTON_R1: return 5;
            case KeyEvent.KEYCODE_BUTTON_L2: return 6; case KeyEvent.KEYCODE_BUTTON_R2: return 7;
            case KeyEvent.KEYCODE_BUTTON_SELECT: return 8; case KeyEvent.KEYCODE_BUTTON_START: return 9;
            case KeyEvent.KEYCODE_BUTTON_THUMBL: return 10; case KeyEvent.KEYCODE_BUTTON_THUMBR: return 11;
            case KeyEvent.KEYCODE_DPAD_UP: return 12; case KeyEvent.KEYCODE_DPAD_DOWN: return 13;
            case KeyEvent.KEYCODE_DPAD_LEFT: return 14; case KeyEvent.KEYCODE_DPAD_RIGHT: return 15;
            default: return -1;
        }
    }
    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int src = e.getSource();
        boolean pad = (src & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD || (src & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK;
        int b = padButton(e.getKeyCode());
        if (pad && b >= 0 && e.getRepeatCount() == 0 && (e.getAction() == KeyEvent.ACTION_DOWN || e.getAction() == KeyEvent.ACTION_UP)) {
            emit("pad", "{\"button\":" + b + ",\"down\":" + (e.getAction() == KeyEvent.ACTION_DOWN) + "}");
        }
        return super.dispatchKeyEvent(e);
    }
    @Override
    public boolean onGenericMotionEvent(MotionEvent e) {
        if ((e.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK && e.getAction() == MotionEvent.ACTION_MOVE) {
            float lt = Math.max(e.getAxisValue(MotionEvent.AXIS_LTRIGGER), e.getAxisValue(MotionEvent.AXIS_BRAKE));
            float rt = Math.max(e.getAxisValue(MotionEvent.AXIS_RTRIGGER), e.getAxisValue(MotionEvent.AXIS_GAS));
            emit("pad", String.format(java.util.Locale.ROOT, "{\"axes\":[%.3f,%.3f,%.3f,%.3f],\"lt\":%.3f,\"rt\":%.3f}",
                e.getAxisValue(MotionEvent.AXIS_X), e.getAxisValue(MotionEvent.AXIS_Y), e.getAxisValue(MotionEvent.AXIS_Z), e.getAxisValue(MotionEvent.AXIS_RZ), lt, rt));
            return true;
        }
        return super.onGenericMotionEvent(e);
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
