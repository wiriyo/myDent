import 'package:flutter/foundation.dart';

class ImageSaverService {
  static Future<bool> saveImage(Uint8List imageBytes, String fileName) async {
    debugPrint('ImageSaverService: saveImage is not supported on this platform.');
    return false;
  }

  static Future<bool> ensurePermission() async => false;
}
