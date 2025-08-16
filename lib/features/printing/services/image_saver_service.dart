// lib/features/printing/services/image_saver_service.dart
// หน่วยปฏิบัติการพิเศษสำหรับบันทึกภาพลงแกลเลอรี

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaverService {
  /// บันทึกข้อมูลรูปภาพ (Uint8List) ลงในแกลเลอรีของอุปกรณ์
  /// จะมีการขออนุญาตเข้าถึงที่เก็บข้อมูล (Storage/Photos) ก่อน
  static Future<bool> saveImage(Uint8List imageBytes, String fileName) async {
    // 1. ขออนุญาตเข้าถึง Photos (สำหรับ iOS) หรือ Storage (สำหรับ Android รุ่นเก่า)
    // สำหรับ Android รุ่นใหม่ๆ library จะจัดการให้เองค่ะ
    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      try {
        // 2. ถ้าได้รับอนุญาต ก็ทำการบันทึกภาพ
        final result = await ImageGallerySaver.saveImage(
          imageBytes,
          quality: 100, // คุณภาพสูงสุด
          name: fileName, // ตั้งชื่อไฟล์
        );
        debugPrint('Image save result: $result');
        // คืนค่า true ถ้าการบันทึกสำเร็จ
        return result['isSuccess'] ?? false;
      } catch (e) {
        debugPrint('Error saving image: $e');
        return false;
      }
    } else {
      // 3. ถ้าผู้ใช้ไม่อนุญาต ก็คืนค่า false
      debugPrint('Photos permission not granted');
      return false;
    }
  }
}
