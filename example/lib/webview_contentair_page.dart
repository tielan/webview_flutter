import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewContainerPage extends StatefulWidget {
  @override
  _WebViewContainerPageState createState() => _WebViewContainerPageState();
}

class _WebViewContainerPageState extends State<WebViewContainerPage> {
  WebViewController _controller;
  String webTitle = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(webTitle),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (await _controller.canGoBack()) {
            _controller.goBack();
            return new Future.value(false);
          } else {
            return new Future.value(true);
          }
        },
        child: WebView(
          initialUrl: "https://52pht.com/",
          onWebViewCreated: (WebViewController webViewController) {
            _controller = webViewController;
          },
          javascriptChannels: initHandler(context),
        ),
      ),
    );
  }

  Set<JavascriptChannel> initHandler(BuildContext context) {
    return [
      JavascriptChannel(
          name: 'onPageStarted',
          onMessageReceived: (JavascriptMessage message) {
            print('onPageStarted');
          }),
      JavascriptChannel(
          name: 'onPageFinished',
          onMessageReceived: (JavascriptMessage message) {
            print('onPageFinished');
          }),
      JavascriptChannel(
          name: 'onReceivedError',
          onMessageReceived: (JavascriptMessage message) {
            print('onReceivedError');
          }),
      JavascriptChannel(
          name: 'onReceivedTitle',
          onMessageReceived: (JavascriptMessage message) {
            print('onReceivedTitle');
            setState(() {
              webTitle = message.message;
            });
          }),
      JavascriptChannel(
          name: 'shouldOverrideUrlLoading',
          onMessageReceived: (JavascriptMessage message) {
            print('shouldOverrideUrlLoading');
            _controller.loadUrl(message.message);
          })
    ].toSet();
  }
}
