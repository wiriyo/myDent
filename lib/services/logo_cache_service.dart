import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight cache for clinic logo bytes to speed up splash and offline display.
class LogoCacheService {
  static const String _keyBytes = 'mydent.logo.bytes.b64.v1';

  static Future<void> save(Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64 = base64Encode(bytes);
      await prefs.setString(_keyBytes, b64);
    } catch (_) {
      // ignore cache failures
    }
  }

  static Future<Uint8List?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64 = prefs.getString(_keyBytes);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBytes);
    } catch (_) {}
  }
}
