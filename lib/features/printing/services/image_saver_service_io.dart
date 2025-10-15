// lib/features/printing/services/image_saver_service.dart
// หน่วยปฏิบัติการพิเศษสำหรับบันทึกภาพลงแกลเลอรี (Final Upgrade)

import 'package:flutter/foundation.dart';
// ✨ NEW: import กุญแจ Master Key ดอกใหม่ของเรา!
import 'package:gal/gal.dart';
// permission_handler ยังต้องใช้อยู่นะคะ
import 'package:permission_handler/permission_handler.dart';

class ImageSaverService {
  /// บันทึกข้อมูลรูปภาพ (Uint8List) ลงในแกลเลอรีของอุปกรณ์
  static Future<bool> saveImage(Uint8List imageBytes, String fileName) async {
    // 1. ขออนุญาตเข้าถึง Photos/Storage ก่อน
    // library 'gal' ต้องการให้เราจัดการ permission เองค่ะ
    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      debugPrint('Photos permission not granted');
      return false;
    }

    try {
      // 2. เรียกใช้ 'gal' เพื่อบันทึกภาพโดยตรง! ง่ายมากๆ เลยค่ะ
      await Gal.putImageBytes(imageBytes, name: fileName);
      debugPrint('Image saved successfully using gal!');
      return true;
    } catch (e) {
      debugPrint('Error saving image with gal: $e');
      return false;
    }
  }

  /// ตรวจสอบและขอสิทธิ์ในการบันทึกรูปภาพตามแพลตฟอร์ม
  static Future<bool> ensurePermission() => _ensurePermission();

  static Future<bool> _ensurePermission() async {
    // ถ้าเป็นเว็บก็ยังไม่รองรับการบันทึกภาพนะคะ
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 12 ลงไปใช้ storage permission แบบเดิม
      PermissionStatus storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      if (storageStatus.isGranted) {
        return true;
      }

      // Android 13 ขึ้นไปใช้ READ_MEDIA_IMAGES (photos)
      PermissionStatus photosStatus = await Permission.photos.status;
      if (!photosStatus.isGranted && !photosStatus.isLimited) {
        photosStatus = await Permission.photos.request();
      }
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return true;
      }

      return false;
    }

    // iOS / อื่น ๆ ใช้ photos permission ตามปกติ
    PermissionStatus status = await Permission.photos.status;
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.photos.request();
    }
    return status.isGranted || status.isLimited;
  }
}
