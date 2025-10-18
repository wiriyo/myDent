import 'dart:async';

import 'browser_print_service_delegate.dart';

BrowserPrintServiceDelegate createBrowserPrintService() {
  return _UnsupportedBrowserPrintServiceDelegate();
}

class _UnsupportedBrowserPrintServiceDelegate
    implements BrowserPrintServiceDelegate {
  @override
  Future<void> printPng(
    String base64Png,
    bool autoClose,
    int pixelWidth,
  ) async {
    throw UnsupportedError(
      'Browser printing is not supported on this platform.',
    );
  }

  @override
  Future<void> printHtml(
    Map<String, dynamic> payload,
    bool autoClose,
  ) async {
    throw UnsupportedError(
      'Browser printing is not supported on this platform.',
    );
  }
}
