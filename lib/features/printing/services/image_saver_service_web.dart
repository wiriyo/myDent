// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

class ImageSaverService {
  static Future<bool> saveImage(Uint8List imageBytes, String fileName) async {
    final Object? maybeBridge = js_util.getProperty<Object?>(
      web.window,
      'mydentImageSaver',
    );
    if (maybeBridge == null) {
      debugPrint('mydentImageSaver bridge is not available on web.');
      return false;
    }
    final Object bridge = maybeBridge;

    final DateTime now = DateTime.now();
    final Map<String, Object?> payload = <String, Object?>{
      'base64Data': base64Encode(imageBytes),
      'dayFolder': DateFormat('dd_MM_yy').format(now),
      'fileBase': DateFormat('ddMMyy_HHmm').format(now),
    };

    try {
      final Object? savePromise = js_util.callMethod<Object?>(
        bridge,
        'saveImage',
        <Object?>[js_util.jsify(payload)],
      );
      if (savePromise == null) {
        debugPrint('Web bridge returned null for saveImage.');
        return false;
      }
      final Object? result = await js_util.promiseToFuture<Object?>(
        savePromise,
      );
      if (result == null) {
        return false;
      }
      final bool success =
          js_util.getProperty<Object?>(result, 'success') == true;
      if (!success) {
        final Object? error = js_util.getProperty<Object?>(result, 'error');
        debugPrint('Failed to save image via web bridge: $error');
      }
      return success;
    } catch (error, stackTrace) {
      debugPrint('Web image saving threw an exception: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  static Future<bool> ensurePermission() async {
    final Object? maybeBridge = js_util.getProperty<Object?>(
      web.window,
      'mydentImageSaver',
    );
    if (maybeBridge == null) {
      return false;
    }
    final Object bridge = maybeBridge;
    try {
      final Object? permissionPromise = js_util.callMethod<Object?>(
        bridge,
        'ensurePermission',
        const <Object>[],
      );
      if (permissionPromise == null) {
        return false;
      }
      final Object? granted = await js_util.promiseToFuture<Object?>(
        permissionPromise,
      );
      return granted == true;
    } catch (error) {
      debugPrint('ensurePermission via web bridge failed: $error');
      return false;
    }
  }
}
