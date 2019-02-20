// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef void WebViewCreatedCallback(WebViewController controller);

enum JavascriptMode {
  disabled,
  unrestricted,
}
class JavascriptMessage {
  const JavascriptMessage(this.message) : assert(message != null);
  final String message;
}

typedef void JavascriptMessageHandler(JavascriptMessage message);
final RegExp _validChannelNames = RegExp('^[a-zA-Z_][a-zA-Z0-9]*\$');
class JavascriptChannel {
  JavascriptChannel({
    @required this.name,
    @required this.onMessageReceived,
  })  : assert(name != null),
        assert(onMessageReceived != null),
        assert(_validChannelNames.hasMatch(name));
  final String name;
  final JavascriptMessageHandler onMessageReceived;
}

class WebView extends StatefulWidget {
  const WebView({
    Key key,
    this.onWebViewCreated,
    this.initialUrl,
    this.content,
    this.javascriptMode = JavascriptMode.unrestricted,
    this.javascriptChannels,
    this.gestureRecognizers,
    this.useShouldOverrideUrlLoading = true
  })  : assert(javascriptMode != null),
        super(key: key);
  final WebViewCreatedCallback onWebViewCreated;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final String initialUrl;
  final String content;
  final bool useShouldOverrideUrlLoading;
  final JavascriptMode javascriptMode;
  final Set<JavascriptChannel> javascriptChannels;

  @override
  State<StatefulWidget> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  _WebSettings _settings;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return GestureDetector(
        onLongPress: () {},
        child: AndroidView(
          viewType: 'plugins.flutter.io/webview',
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
          layoutDirection: TextDirection.rtl,
          creationParams: _CreationParams.fromWidget(widget).toMap(),
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'plugins.flutter.io/webview',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the webview_flutter plugin');
  }

  @override
  void initState() {
    super.initState();
    _assertJavascriptChannelNamesAreUnique();
  }

  @override
  void didUpdateWidget(WebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assertJavascriptChannelNamesAreUnique();
    _updateConfiguration(_WebSettings.fromWidget(widget));
  }

  Future<void> _updateConfiguration(_WebSettings settings) async {
    _settings = settings;
    final WebViewController controller = await _controller.future;
    controller._updateSettings(settings);
    controller._updateJavascriptChannels(widget.javascriptChannels);
  }

  void _onPlatformViewCreated(int id) {
    final WebViewController controller = WebViewController._(
      id,
      _WebSettings.fromWidget(widget),
      widget.javascriptChannels,
    );
    _controller.complete(controller);
    if (widget.onWebViewCreated != null) {
      widget.onWebViewCreated(controller);
    }
  }

  void _assertJavascriptChannelNamesAreUnique() {
    if (widget.javascriptChannels == null ||
        widget.javascriptChannels.isEmpty) {
      return;
    }
    assert(_extractChannelNames(widget.javascriptChannels).length ==
        widget.javascriptChannels.length);
  }
}

Set<String> _extractChannelNames(Set<JavascriptChannel> channels) {
  final Set<String> channelNames = channels == null
      ? Set<String>()
      : channels.map((JavascriptChannel channel) => channel.name).toSet();
  return channelNames;
}

class _CreationParams {
  _CreationParams(
      {this.initialUrl,
      this.content,
      this.settings,
      this.useShouldOverrideUrlLoading,
      this.javascriptChannelNames});

  static _CreationParams fromWidget(WebView widget) {
    return _CreationParams(
      initialUrl: widget.initialUrl,
      content: widget.content,
      useShouldOverrideUrlLoading:widget.useShouldOverrideUrlLoading,
      settings: _WebSettings.fromWidget(widget),
      javascriptChannelNames:
          _extractChannelNames(widget.javascriptChannels).toList(),
    );
  }

  final String initialUrl;
  final String content;
  final bool useShouldOverrideUrlLoading;

  final _WebSettings settings;

  final List<String> javascriptChannelNames;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'initialUrl': initialUrl,
      'content': content,
      'useShouldOverrideUrlLoading':useShouldOverrideUrlLoading,
      'settings': settings.toMap(),
      'javascriptChannelNames': javascriptChannelNames,
    };
  }
}

class _WebSettings {
  _WebSettings({
    this.javascriptMode,
  });

  static _WebSettings fromWidget(WebView widget) {
    return _WebSettings(javascriptMode: widget.javascriptMode);
  }

  final JavascriptMode javascriptMode;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'jsMode': javascriptMode.index,
    };
  }

  Map<String, dynamic> updatesMap(_WebSettings newSettings) {
    if (javascriptMode == newSettings.javascriptMode) {
      return null;
    }
    return <String, dynamic>{
      'jsMode': newSettings.javascriptMode.index,
    };
  }
}
class WebViewController {
  WebViewController._(
      int id, this._settings, Set<JavascriptChannel> javascriptChannels)
      : _channel = MethodChannel('plugins.flutter.io/webview_$id') {
    _updateJavascriptChannelsFromSet(javascriptChannels);
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;

  _WebSettings _settings;

  // Maps a channel name to a channel.
  Map<String, JavascriptChannel> _javascriptChannels =
      <String, JavascriptChannel>{};

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'javascriptChannelMessage':
        final String channel = call.arguments['channel'];
        final String message = call.arguments['message'];
        _javascriptChannels[channel]
            .onMessageReceived(JavascriptMessage(message));
        break;
    }
  }


  Future<void> loadUrl(String url) async {
    assert(url != null);
    _validateUrlString(url);
    return _channel.invokeMethod('loadUrl', url);
  }
  Future<void> loadUrlContent(String url) async {
    return _channel.invokeMethod('loadUrlContent', url);
  }
  Future<String> currentUrl() async {
    final String url = await _channel.invokeMethod('currentUrl');
    return url;
  }
  Future<bool> canGoBack() async {
    final bool canGoBack = await _channel.invokeMethod("canGoBack");
    return canGoBack;
  }
  Future<bool> canGoForward() async {
    final bool canGoForward = await _channel.invokeMethod("canGoForward");
    return canGoForward;
  }
  Future<void> goBack() async {
    return _channel.invokeMethod("goBack");
  }
  Future<void> goForward() async {
    return _channel.invokeMethod("goForward");
  }
  Future<void> reload() async {
    return _channel.invokeMethod("reload");
  }
  Future<void> _updateSettings(_WebSettings setting) async {
    final Map<String, dynamic> updateMap = _settings.updatesMap(setting);
    if (updateMap == null) {
      return null;
    }
    _settings = setting;
    return _channel.invokeMethod('updateSettings', updateMap);
  }

  Future<void> _updateJavascriptChannels(
      Set<JavascriptChannel> newChannels) async {
    final Set<String> currentChannels = _javascriptChannels.keys.toSet();
    final Set<String> newChannelNames = _extractChannelNames(newChannels);
    final Set<String> channelsToAdd =
        newChannelNames.difference(currentChannels);
    final Set<String> channelsToRemove =
        currentChannels.difference(newChannelNames);
    if (channelsToRemove.isNotEmpty) {
      _channel.invokeMethod(
          'removeJavascriptChannels', channelsToRemove.toList());
    }
    if (channelsToAdd.isNotEmpty) {
      _channel.invokeMethod('addJavascriptChannels', channelsToAdd.toList());
    }
    _updateJavascriptChannelsFromSet(newChannels);
  }

  void _updateJavascriptChannelsFromSet(Set<JavascriptChannel> channels) {
    _javascriptChannels.clear();
    if (channels == null) {
      return;
    }
    for (JavascriptChannel channel in channels) {
      _javascriptChannels[channel.name] = channel;
    }
  }
  Future<String> evaluateJavascript(String javascriptString) async {
    if (_settings.javascriptMode == JavascriptMode.disabled) {
      throw FlutterError(
          'JavaScript mode must be enabled/unrestricted when calling evaluateJavascript.');
    }
    if (javascriptString == null) {
      throw ArgumentError('The argument javascriptString must not be null. ');
    }
    final String result =
        await _channel.invokeMethod('evaluateJavascript', javascriptString);
    return result;
  }
}

class CookieManager {
  /// Creates a [CookieManager] -- returns the instance if it's already been called.
  factory CookieManager() {
    return _instance ??= CookieManager._();
  }

  CookieManager._();

  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/cookie_manager');
  static CookieManager _instance;

  /// Clears all cookies.
  ///
  /// This is supported for >= IOS 9.
  ///
  /// Returns true if cookies were present before clearing, else false.
  Future<bool> clearCookies() => _channel
      // TODO(amirh): remove this when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      .invokeMethod('clearCookies')
      .then<bool>((dynamic result) => result);
}

// Throws an ArgumentError if `url` is not a valid URL string.
void _validateUrlString(String url) {
  try {
    final Uri uri = Uri.parse(url);
    if (uri.scheme.isEmpty) {
      throw ArgumentError('Missing scheme in URL string: "$url"');
    }
  } on FormatException catch (e) {
    throw ArgumentError(e);
  }
}
