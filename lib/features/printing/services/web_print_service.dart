import 'package:flutter/foundation.dart';

import 'web_print_service_stub.dart'
    if (dart.library.html) 'web_print_service_web.dart';

typedef _PrintDelegate = Future<void> Function(Uint8List bytes);

final _PrintDelegate _delegate = createWebPrintService();

/// Provides web-only thermal printing by opening a temporary window,
/// injecting the rendered PNG, and invoking `window.print()`.
class WebPrintService {
  const WebPrintService._();

  static const WebPrintService I = WebPrintService._();

  Future<void> printPng(Uint8List bytes) async {
    if (!kIsWeb) {
      throw UnsupportedError('Web printing is only available on Flutter Web.');
    }
    await _delegate(bytes);
  }
}
