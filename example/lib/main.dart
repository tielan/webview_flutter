// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'webview_contentair_page.dart';

void main() => runApp(MaterialApp(home: WebViewContainerPage()));






String content =
    '&lt;p&gt;&lt;img src=&quot;/images/ea/ea/fa/c46b16229967e15a3f0e5c6029143063dda0dd32.jpg&quot;&gt;&lt;img src=&quot;/images/9a/c6/37/abe4291b7e5ddbdea9844701e149ec2908f1ecc6.jpg&quot;&gt;&lt;video controls=&quot;&quot; src=&quot;/images/upload_img/brandimg/Hario.mp4&quot; uc-video-toolbar-id=&quot;c196903d-fd63-8d2d-0528-1507703044609&quot; width=&quot;100%&quot;&gt;&lt;/video&gt;&lt;img src=&quot;/images/31/16/36/56bb2f2fbe0f50b5b0b0e8109aa4f2fdb2b892d3.jpg&quot;&gt;&lt;img src=&quot;/images/4d/93/20/48ae647ad2414a3f846283891e61d33f98fba79a.jpg&quot;&gt;&lt;img src=&quot;/images/7e/ee/f3/412740be31c4bdba212cd8da4c125448315b3a78.jpg&quot;&gt;&lt;img src=&quot;/images/d9/56/d6/8c578bcb25fd8bc1b8572c918b16bca5fa64c05e.jpg&quot;&gt;&amp;gt;&lt;img src=&quot;/images/40/0a/45/dfc6203da8fe0e234c091d9ea9a2c7a7f46d99d7.jpg&quot;&gt;&lt;img src=&quot;/images/aa/53/b5/f00cafa576af3859b40054bcf787a68dac1b3e04.jpg&quot;&gt;&lt;img src=&quot;/images/df/b7/21/89f31ebced9e3cd75f13b096117a73a87b158f1e.jpg&quot;&gt;&lt;img src=&quot;/images/4e/9e/3b/51dae8e17ae32c9743f9cf25a0e7d72621d038dd.jpg&quot;&gt;&lt;img src=&quot;/images/af/80/71/d5d4cf81e815d545b9e851b16292b51063fb29fc.jpg&quot;&gt;&lt;/p&gt;';
String htmlEntityDecode(String string) {
  string = string.replaceAll("&quot;", "\"");
  string = string.replaceAll("&apos;", "'");
  string = string.replaceAll("&lt;", "<");
  string = string.replaceAll("&gt;", ">");
  string = string.replaceAll("&amp;", "&");
  return string;
}

String baseUrl = 'https://pmall.52pht.com/';
String loadHtml(String contentStr) {
  String content = htmlEntityDecode(contentStr);
  String htmlString = "<!DOCTYPE html> <html> " +
      "<head> " +
      "<meta content=\"text/html; charset=utf-8\" http-equiv=\"Content-Type\" />" +
      "<meta content=\"width=device-width,initial-scale=1,user-scalable=no\" name=\"viewport\" />" +
      "<meta name=\"apple-touch-fullscreen\" content=\"yes\" />" +
      "<meta name=\"format-detection\" content=\"telephone=no,address=no\" />" +
      "<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"white\" />" +
      "</head> " +
      "<body>" +
      "$content" +
      "</body>" +
      "<script src='$baseUrl/themes/mobilemall/appjs/fix.js'></script>" +
      "</html>";
  return htmlString;
}

class Demo extends StatefulWidget {
  @override
  _DemoState createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  WebViewController _controller;
  double webHeight = 10;
  bool isDetail = true;
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    Size size = mediaQueryData.size;
    print(mediaQueryData.devicePixelRatio);
    return Scaffold(
        appBar: AppBar(
          title: const Text('Flutter WebView example'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Container(
                height: 200,
                color: Colors.greenAccent,
                child: Row(
                  children: <Widget>[
                    RaisedButton(
                      onPressed: () {
                        _controller?.loadUrlContent(loadHtml(content));
                      },
                      child: Text('详情子昂起'),
                    ),
                    RaisedButton(
                      onPressed: () {
                        _controller?.loadUrlContent(loadHtml('content'));
                      },
                      child: Text('详情子昂起'),
                    )
                  ],
                ),
              ),
              Container(
                  height: webHeight,
                  child: WebView(
                    content: loadHtml(content),
                    onWebViewCreated: (WebViewController webViewController) {
                      _controller = webViewController;
                    },
                    javascriptChannels: <JavascriptChannel>[
                      _onGetWebContentHeight(context),
                      _onPageStarted(context)
                    ].toSet(),
                  )),
              Container(
                height: 800,
                color: Colors.redAccent,
              ),
            ],
          ),
        ));
  }

  _onGetWebContentHeight(BuildContext context) {
    return JavascriptChannel(
        name: 'onGetWebContentHeight',
        onMessageReceived: (JavascriptMessage message) {
          print('onGetWebContentHeight');
          setState(() {
              webHeight = double.parse(message.message) / 3.0;
          });
        });
  }

  _onPageStarted(BuildContext context) {
    return JavascriptChannel(
        name: 'onPageStarted',
        onMessageReceived: (JavascriptMessage message) {
          setState(() {
            webHeight = 10;
          });
        });
  }
}

enum MenuOptions {
  showUserAgent,
  toast,
  listCookies,
  clearCookies,
}

class SampleMenu extends StatelessWidget {
  SampleMenu(this.controller);

  final Future<WebViewController> controller;
  final CookieManager cookieManager = CookieManager();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: controller,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> controller) {
        return PopupMenuButton<MenuOptions>(
          onSelected: (MenuOptions value) {
            switch (value) {
              case MenuOptions.showUserAgent:
                _onShowUserAgent(controller.data, context);
                break;
              case MenuOptions.toast:
                Scaffold.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You selected: $value'),
                  ),
                );
                break;
              case MenuOptions.listCookies:
                _onListCookies(controller.data, context);
                break;
              case MenuOptions.clearCookies:
                _onClearCookies(context);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuItem<MenuOptions>>[
                PopupMenuItem<MenuOptions>(
                  value: MenuOptions.showUserAgent,
                  child: const Text('Show user agent'),
                  enabled: controller.hasData,
                ),
                const PopupMenuItem<MenuOptions>(
                  value: MenuOptions.toast,
                  child: Text('Make a toast'),
                ),
                const PopupMenuItem<MenuOptions>(
                  value: MenuOptions.listCookies,
                  child: Text('List cookies'),
                ),
                const PopupMenuItem<MenuOptions>(
                  value: MenuOptions.clearCookies,
                  child: Text('Clear cookies'),
                ),
              ],
        );
      },
    );
  }

  void _onShowUserAgent(
      WebViewController controller, BuildContext context) async {
    // Send a message with the user agent string to the Toaster JavaScript channel we registered
    // with the WebView.
    controller.evaluateJavascript(
        'Toaster.postMessage("User Agent: " + navigator.userAgent);');
  }

  void _onListCookies(
      WebViewController controller, BuildContext context) async {
    final String cookies =
        await controller.evaluateJavascript('document.cookie');
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Cookies:'),
          _getCookieList(cookies),
        ],
      ),
    ));
  }

  void _onClearCookies(BuildContext context) async {
    final bool hadCookies = await cookieManager.clearCookies();
    String message = 'There were cookies. Now, they are gone!';
    if (!hadCookies) {
      message = 'There are no cookies.';
    }
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  Widget _getCookieList(String cookies) {
    if (cookies == null || cookies == '""') {
      return Container();
    }
    final List<String> cookieList = cookies.split(';');
    final Iterable<Text> cookieWidgets =
        cookieList.map((String cookie) => Text(cookie));
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: cookieWidgets.toList(),
    );
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls(this._webViewControllerFuture)
      : assert(_webViewControllerFuture != null);

  final Future<WebViewController> _webViewControllerFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _webViewControllerFuture,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> snapshot) {
        final bool webViewReady =
            snapshot.connectionState == ConnectionState.done;
        final WebViewController controller = snapshot.data;
        return Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller.canGoBack()) {
                        controller.goBack();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(content: Text("No back history item")),
                        );
                        return;
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller.canGoForward()) {
                        controller.goForward();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("No forward history item")),
                        );
                        return;
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: !webViewReady
                  ? null
                  : () {
                      controller.reload();
                    },
            ),
          ],
        );
      },
    );
  }
}
