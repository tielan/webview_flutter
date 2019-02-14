package io.flutter.plugins.webviewflutter;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
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
  private static final String JS_CHANNEL_NAMES_FIELD = "javascriptChannelNames";
  private final WebView webView;
  private final LinearLayout layout;
  private final MethodChannel methodChannel;
  private Mobile mobile = new Mobile();

  @SuppressWarnings("unchecked")
  FlutterWebView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
    webView = new WebView(context);
    WebSettings settings = webView.getSettings();
    webView.getSettings().setJavaScriptEnabled(true);
    String userAgent = settings.getUserAgentString();
    Log.i("TAG", "User Agent:" + userAgent);

    webView.addJavascriptInterface(mobile, "mobile");
    methodChannel = new MethodChannel(messenger, "plugins.flutter.io/webview_" + id);
    methodChannel.setMethodCallHandler(this);

    applySettings((Map<String, Object>) params.get("settings"));

    if (params.containsKey(JS_CHANNEL_NAMES_FIELD)) {
      registerJavaScriptChannelNames((List<String>) params.get(JS_CHANNEL_NAMES_FIELD));
    }
    String content = (String) params.get("content");
    webView.loadDataWithBaseURL("https://pmall.52pht.com/",content, "text/html",  "utf-8",null );
    webView.setWebViewClient(webViewClient);
    layout = new LinearLayout(context);
    LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,LinearLayout.LayoutParams.WRAP_CONTENT);
    layout.addView(webView,layoutParams);
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
          HashMap<String, String> arguments = new HashMap<>();
          arguments.put("channel", "onGetWebContentHeight");
          arguments.put("message", ""+measuredHeight);
          Log.e("methodChannel",""+measuredHeight);
          methodChannel.invokeMethod("javascriptChannelMessage", arguments);
        }
      });
    }
  }

  @Override
  public View getView() {
    return layout;
  }

  private WebViewClient webViewClient = new WebViewClient(){

    @Override
    public void onPageStarted(WebView view, String url, Bitmap favicon) {
      super.onPageStarted(view, url, favicon);
      HashMap<String, String> arguments = new HashMap<>();
      arguments.put("channel", "onPageStarted");
      methodChannel.invokeMethod("javascriptChannelMessage", arguments);
    }

    @Override
    public void onPageFinished(WebView view, String url) {
      super.onPageFinished(view, url);
      mobile.onGetWebContentHeight();
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

  private void updateFrame(MethodCall methodCall, Result result){
    LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,LinearLayout.LayoutParams.WRAP_CONTENT);
    layoutParams.height = (int)methodCall.arguments;
    layout.setLayoutParams(layoutParams);
  }

  private void loadUrl(MethodCall methodCall, Result result) {
    String url = (String) methodCall.arguments;
    webView.loadUrl(url);
    result.success(null);
  }

  private void loadUrlContent(MethodCall methodCall, Result result) {
    String content = (String) methodCall.arguments;
    webView.loadDataWithBaseURL("https://pmall.52pht.com/",content, "text/html",  "utf-8",null );
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
  public void dispose() {}
}
