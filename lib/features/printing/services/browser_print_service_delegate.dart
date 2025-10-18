import 'dart:async';

/// Delegate that performs browser-backed print operations.
abstract class BrowserPrintServiceDelegate {
  Future<void> printPng(
    String base64Png,
    bool autoClose,
    int pixelWidth,
  );

  Future<void> printHtml(
    Map<String, dynamic> payload,
    bool autoClose,
  );
}
