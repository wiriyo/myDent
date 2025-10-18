import 'package:flutter/foundation.dart';

import 'browser_print_service_stub.dart'
    if (dart.library.html) 'browser_print_service_web.dart';

class BrowserPrintService {
  const BrowserPrintService._();

  static const BrowserPrintService I = BrowserPrintService._();

  Future<void> printPng(
    String base64Png, {
    required int pixelWidth,
    bool autoClose = true,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('Browser printing is only available on Flutter Web.');
    }
    await _delegate.printPng(base64Png, autoClose, pixelWidth);
  }

  Future<void> printHtml(
    Map<String, dynamic> payload, {
    bool autoClose = true,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('Browser printing is only available on Flutter Web.');
    }
    await _delegate.printHtml(payload, autoClose);
  }
}

final BrowserPrintServiceDelegate _delegate = createBrowserPrintService();
