// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'browser_print_service_delegate.dart';

BrowserPrintServiceDelegate createBrowserPrintService() {
  return _WebBrowserPrintServiceDelegate();
}

class _WebBrowserPrintServiceDelegate
    implements BrowserPrintServiceDelegate {
  @override
  Future<void> printPng(
    String base64Png,
    bool autoClose,
    int pixelWidth,
  ) async {
    await _openPrintWindow(
      mode: 'png',
      autoClose: autoClose,
      payload: <String, dynamic>{
        'base64': base64Png,
        'pixelWidth': pixelWidth,
      },
    );
  }

  @override
  Future<void> printHtml(
    Map<String, dynamic> payload,
    bool autoClose,
  ) async {
    await _openPrintWindow(
      mode: 'html',
      autoClose: autoClose,
      payload: payload,
    );
  }
}

Future<void> _openPrintWindow({
  required String mode,
  required bool autoClose,
  required Map<String, dynamic> payload,
}) async {
  final String origin = html.window.location.origin ?? '';
  final Uri baseUri = Uri.parse(html.window.location.href ?? '/');
  final Uri resolved = baseUri.resolve(
    'print/print.html?mode=$mode&autoClose=${autoClose ? '1' : '0'}',
  );

  final html.WindowBase? popup = html.window.open(
    resolved.toString(),
    '_blank',
    'noopener,noreferrer,width=480,height=800',
  );

  if (popup == null) {
    throw StateError(
      'Unable to open browser print window. Please allow pop-ups for this site.',
    );
  }

  final Map<String, dynamic> message = <String, dynamic>{
    'type': 'mydent-print',
    'mode': mode,
    'payload': payload,
    'autoClose': autoClose,
  };
  final String encodedMessage = jsonEncode(message);

  void sendMessage() {
    try {
      popup.postMessage(encodedMessage, origin);
    } catch (_) {
      // ignore errors from detached windows
    }
  }

  final StreamSubscription<html.Event> sub = html.window.onMessage.listen(
    (html.Event event) {
      if (event is! html.MessageEvent) {
        return;
      }
      if (event.origin != origin) {
        return;
      }
      final dynamic data = event.data;
      if (data is String) {
        try {
          final dynamic decoded = jsonDecode(data);
          if (decoded is Map && decoded['type'] == 'mydent-print-ready') {
            if (decoded['mode'] == mode) {
              sendMessage();
            }
          }
        } catch (_) {
          // ignore invalid messages
        }
      }
    },
  );

  Timer(const Duration(milliseconds: 100), sendMessage);
  Timer(const Duration(milliseconds: 400), sendMessage);
  Timer(const Duration(milliseconds: 1200), sendMessage);
  Timer(const Duration(seconds: 5), () => sub.cancel());
}
