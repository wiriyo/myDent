import 'dart:async';

class BrowserPrintServiceDelegate {
  const BrowserPrintServiceDelegate({
    required this.printPng,
    required this.printHtml,
  });

  final Future<void> Function(String base64Png, bool autoClose, int pixelWidth)
      printPng;
  final Future<void> Function(Map<String, dynamic> payload, bool autoClose)
      printHtml;
}

BrowserPrintServiceDelegate createBrowserPrintService() {
  return BrowserPrintServiceDelegate(
    printPng: (String _, bool __, int ___) async {
      throw UnsupportedError('Browser printing is not supported on this platform.');
    },
    printHtml: (Map<String, dynamic> _, bool __) async {
      throw UnsupportedError('Browser printing is not supported on this platform.');
    },
  );
}
