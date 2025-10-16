import 'dart:typed_data';

Future<void> Function(Uint8List bytes) createWebPrintService() {
  return (Uint8List _) async {
    throw UnsupportedError('Web printing is not supported on this platform.');
  };
}
