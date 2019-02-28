import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36; PMALL_Android';


class FullWebPage extends StatefulWidget {
  final Map initParams;

  FullWebPage({Key key, @required this.initParams}) : super(key: key);

  @override
  _FullWebPageState createState() => new _FullWebPageState();
}

class _FullWebPageState extends State<FullWebPage> {
  WebViewController _controller;
  String webTitle = '';
  String initUrl = 'https://pmall.52pht.com/';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool hiddenNav = Uri
        .parse(initUrl)
        .query
        .contains('hiddenNav=YES');
    String cookiesValue = "deviceType=Android;UID=111;path=/";
    return Scaffold(
      appBar: hiddenNav
          ? null
          : AppBar(
          title: Text(webTitle),
          centerTitle: true,
          elevation: 1),
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
            content: widget.initParams['content'],
            domain: widget.initParams['domain'],
            clearCache: true,
            setCookies: {
              'domain': 'https//52pht.com',
              'value': cookiesValue
            },
            userAgent: kAndroidUserAgent,
            onWebViewCreated: (WebViewController webViewController) {
              _controller = webViewController;
            },
            javascriptChannels: initHandler(context),
          )
      ),
    );
  }

  Set<JavascriptChannel> initHandler(BuildContext context) {
    return [
      JavascriptChannel(
          name: 'onPageStarted',
          onMessageReceived: (JavascriptMessage message) {
            setState(() {});
          }),
      JavascriptChannel(
          name: 'onPageFinished',
          onMessageReceived: (JavascriptMessage message) {
            setState(() {});
          }),
      JavascriptChannel(
          name: 'onReceivedError',
          onMessageReceived: (JavascriptMessage message) {}),
      JavascriptChannel(
          name: 'onReceivedTitle',
          onMessageReceived: (JavascriptMessage message) {
            setState(() {
              webTitle = message.message;
            });
          }),
      JavascriptChannel(
          name: 'shouldOverrideUrlLoading',
          onMessageReceived: (JavascriptMessage message) {
            _controller.loadUrl(message.message);
          })
    ].toSet();
  }
}
