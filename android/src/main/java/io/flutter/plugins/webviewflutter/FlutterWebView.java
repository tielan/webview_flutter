package io.flutter.plugins.webviewflutter;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class FlutterWebView implements PlatformView, MethodCallHandler {
    private static final String LOG_TAG = "FlutterWebView";
    private static final String JS_CHANNEL_NAMES_FIELD = "javascriptChannelNames";
    private final WebView webView;
    private final LinearLayout layout;
    private final MethodChannel methodChannel;
    private Mobile mobile = new Mobile();
    private boolean useShouldOverrideUrlLoading = false;

    @SuppressWarnings("unchecked")
    FlutterWebView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
        webView = new WebView(context);
        WebSettings settings = webView.getSettings();
        webView.getSettings().setJavaScriptEnabled(true);
        webView.setWebViewClient(webViewClient);
        webView.setWebChromeClient(browserChromeClient);
        layout = new LinearLayout(context);
        LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.addView(webView, layoutParams);

        String userAgent = settings.getUserAgentString();
        Log.i("TAG", "User Agent:" + userAgent);

        webView.addJavascriptInterface(mobile, "mobile");
        methodChannel = new MethodChannel(messenger, "plugins.flutter.io/webview_" + id);
        methodChannel.setMethodCallHandler(this);

        applySettings((Map<String, Object>) params.get("settings"));
        if(params.containsKey("useShouldOverrideUrlLoading")){
            useShouldOverrideUrlLoading = Boolean.parseBoolean(params.get("useShouldOverrideUrlLoading")+"");
        }

        if (params.containsKey(JS_CHANNEL_NAMES_FIELD)) {
            registerJavaScriptChannelNames((List<String>) params.get(JS_CHANNEL_NAMES_FIELD));
        }
        if (params.containsKey("initialUrl") && !TextUtils.isEmpty(params.get("initialUrl") + "")) {
            String initialUrl = (String) params.get("initialUrl");
            webView.loadUrl(initialUrl);
        } else if (params.containsKey("content") && !TextUtils.isEmpty(params.get("content") + "")) {
            String content = (String) params.get("content");
            webView.loadDataWithBaseURL("https://pmall.52pht.com/", content, "text/html", "utf-8", null);
        }

    }

    private class Mobile {

        @JavascriptInterface
        public void onGetWebContentHeight() {
            //重新调整webview高度
            webView.post(new Runnable() {
                @Override
                public void run() {
                    webView.measure(0, 0);
                    int measuredHeight = webView.getMeasuredHeight();
                    invokeMethod("onGetWebContentHeight", "" + measuredHeight);
                }
            });
        }
    }

    void invokeMethod(String channel, String message) {
        HashMap<String, String> arguments = new HashMap<>();
        arguments.put("channel", channel);
        arguments.put("message", message);
        Log.e(channel, message);
        methodChannel.invokeMethod("javascriptChannelMessage", arguments);
    }

    @Override
    public View getView() {
        return layout;
    }


    private WebViewClient webViewClient = new WebViewClient() {
        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            super.onPageStarted(view, url, favicon);
            Map<String, Object> data = new HashMap<>();
            data.put("url", url);
            invokeMethod("onPageStarted", "" + url);
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            super.onPageFinished(view, url);
            invokeMethod("onPageFinished", "" + url);
            mobile.onGetWebContentHeight();
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView webView, String url) {
            if (url.startsWith(WebView.SCHEME_TEL)) {
                try {
                    Intent intent = new Intent(Intent.ACTION_DIAL);
                    intent.setData(Uri.parse(url));
                    webView.getContext().startActivity(intent);
                    return true;
                } catch (android.content.ActivityNotFoundException e) {
                    Log.e(LOG_TAG, "Error dialing " + url + ": " + e.toString());
                }
            } else if (url.startsWith("geo:") || url.startsWith(WebView.SCHEME_MAILTO) || url.startsWith("market:") || url.startsWith("intent:")) {
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    intent.setData(Uri.parse(url));
                    webView.getContext().startActivity(intent);
                    return true;
                } catch (android.content.ActivityNotFoundException e) {
                    Log.e(LOG_TAG, "Error with " + url + ": " + e.toString());
                }
            } else if (url.startsWith("sms:")) {
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    // Get address
                    String address;
                    int parmIndex = url.indexOf('?');
                    if (parmIndex == -1) {
                        address = url.substring(4);
                    } else {
                        address = url.substring(4, parmIndex);
                        // If body, then set sms body
                        Uri uri = Uri.parse(url);
                        String query = uri.getQuery();
                        if (query != null) {
                            if (query.startsWith("body=")) {
                                intent.putExtra("sms_body", query.substring(5));
                            }
                        }
                    }
                    intent.setData(Uri.parse("sms:" + address));
                    intent.putExtra("address", address);
                    intent.setType("vnd.android-dir/mms-sms");
                    webView.getContext().startActivity(intent);
                    return true;
                } catch (android.content.ActivityNotFoundException e) {
                    Log.e(LOG_TAG, "Error sending sms " + url + ":" + e.toString());
                }
            }
            if (useShouldOverrideUrlLoading) {
                invokeMethod("shouldOverrideUrlLoading", "" + url);
                return true;
            }
            return super.shouldOverrideUrlLoading(webView, url);
        }

        @Override
        public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
            super.onReceivedError(view, errorCode, description, failingUrl);
            invokeMethod("onReceivedError", "" + errorCode);
        }

        @TargetApi(21)
        @Override
        public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse errorResponse) {
            super.onReceivedHttpError(view, request, errorResponse);
            invokeMethod("onReceivedError", "" + errorResponse.getStatusCode());
        }
    };
    private WebChromeClient browserChromeClient = new WebChromeClient() {

        @Override
        public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, Message resultMsg) {
            WebView newWebView = new WebView(view.getContext());
            newWebView.setWebViewClient(webViewClient);
            newWebView.setWebChromeClient(browserChromeClient);
            WebView.WebViewTransport transport = ((WebView.WebViewTransport) resultMsg.obj);
            transport.setWebView(newWebView);
            resultMsg.sendToTarget();
            return true;
        }

        @Override
        public void onReceivedTitle(WebView view, String title) {
            super.onReceivedTitle(view, title);
            invokeMethod("onReceivedTitle", "" +title);
        }
    };


    @Override
    public void onMethodCall(MethodCall methodCall, Result result) {
        switch (methodCall.method) {
            case "loadUrl":
                loadUrl(methodCall, result);
                break;
            case "updateFrame":
                updateFrame(methodCall, result);
                break;
            case "loadUrlContent":
                loadUrlContent(methodCall, result);
                break;
            case "updateSettings":
                updateSettings(methodCall, result);
                break;
            case "canGoBack":
                canGoBack(methodCall, result);
                break;
            case "canGoForward":
                canGoForward(methodCall, result);
                break;
            case "goBack":
                goBack(methodCall, result);
                break;
            case "goForward":
                goForward(methodCall, result);
                break;
            case "reload":
                reload(methodCall, result);
                break;
            case "currentUrl":
                currentUrl(methodCall, result);
                break;
            case "evaluateJavascript":
                evaluateJavaScript(methodCall, result);
                break;
            case "addJavascriptChannels":
                addJavaScriptChannels(methodCall, result);
                break;
            case "removeJavascriptChannels":
                removeJavaScriptChannels(methodCall, result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void updateFrame(MethodCall methodCall, Result result) {
        LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        layoutParams.height = (int) methodCall.arguments;
        layout.setLayoutParams(layoutParams);
    }

    private void loadUrl(MethodCall methodCall, Result result) {
        String url = (String) methodCall.arguments;
        webView.loadUrl(url);
        result.success(null);
    }

    private void loadUrlContent(MethodCall methodCall, Result result) {
        String content = (String) methodCall.arguments;
        webView.loadDataWithBaseURL("https://pmall.52pht.com/", content, "text/html", "utf-8", null);
        result.success(null);
    }

    private void canGoBack(MethodCall methodCall, Result result) {
        result.success(webView.canGoBack());
    }

    private void canGoForward(MethodCall methodCall, Result result) {
        result.success(webView.canGoForward());
    }

    private void goBack(MethodCall methodCall, Result result) {
        if (webView.canGoBack()) {
            webView.goBack();
        }
        result.success(null);
    }

    private void goForward(MethodCall methodCall, Result result) {
        if (webView.canGoForward()) {
            webView.goForward();
        }
        result.success(null);
    }

    private void reload(MethodCall methodCall, Result result) {
        webView.reload();
        result.success(null);
    }

    private void currentUrl(MethodCall methodCall, Result result) {
        result.success(webView.getUrl());
    }

    @SuppressWarnings("unchecked")
    private void updateSettings(MethodCall methodCall, Result result) {
        applySettings((Map<String, Object>) methodCall.arguments);
        result.success(null);
    }

    @TargetApi(19)
    private void evaluateJavaScript(MethodCall methodCall, final Result result) {
        String jsString = (String) methodCall.arguments;
        if (jsString == null) {
            throw new UnsupportedOperationException("JavaScript string cannot be null");
        }
        webView.evaluateJavascript(
                jsString,
                new android.webkit.ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String value) {
                        result.success(value);
                    }
                });
    }

    @SuppressWarnings("unchecked")
    private void addJavaScriptChannels(MethodCall methodCall, Result result) {
        List<String> channelNames = (List<String>) methodCall.arguments;
        registerJavaScriptChannelNames(channelNames);
        result.success(null);
    }

    @SuppressWarnings("unchecked")
    private void removeJavaScriptChannels(MethodCall methodCall, Result result) {
        List<String> channelNames = (List<String>) methodCall.arguments;
        for (String channelName : channelNames) {
            webView.removeJavascriptInterface(channelName);
        }
        result.success(null);
    }

    private void applySettings(Map<String, Object> settings) {
        for (String key : settings.keySet()) {
            switch (key) {
                case "jsMode":
                    updateJsMode((Integer) settings.get(key));
                    break;
                default:
                    throw new IllegalArgumentException("Unknown WebView setting: " + key);
            }
        }
    }

    private void updateJsMode(int mode) {
        switch (mode) {
            case 0: // disabled
                webView.getSettings().setJavaScriptEnabled(false);
                break;
            case 1: // unrestricted
                webView.getSettings().setJavaScriptEnabled(true);
                break;
            default:
                throw new IllegalArgumentException("Trying to set unknown JavaScript mode: " + mode);
        }
    }

    private void registerJavaScriptChannelNames(List<String> channelNames) {
        for (String channelName : channelNames) {
            webView.addJavascriptInterface(
                    new JavaScriptChannel(methodChannel, channelName), channelName);
        }
    }

    @Override
    public void dispose() {
    }
}
