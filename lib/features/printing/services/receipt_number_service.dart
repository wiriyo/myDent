// lib/features/printing/services/receipt_number_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/th_format.dart';

/// รูปแบบเลขใบเสร็จ: YY-NNN (ปี พ.ศ. 2 หลัก)
class ReceiptNumberService {
  static const _kLastBeYear = 'md_receipt_last_be_year';
  static const _kCounter = 'md_receipt_counter';

  /// คืนค่าเลขใบเสร็จใหม่พร้อมอัปเดตตัวนับ
  static Future<String> next() async {
    final now = DateTime.now();
    final be = ThFormat.beYear(now);
    final prefs = await SharedPreferences.getInstance();

    final lastBe = prefs.getInt(_kLastBeYear) ?? be;
    int counter = prefs.getInt(_kCounter) ?? 0;

    if (lastBe != be) {
      // ปีใหม่ (พ.ศ.) รีเซ็ตเคาน์เตอร์
      counter = 0;
      await prefs.setInt(_kLastBeYear, be);
    }

    counter += 1;
    await prefs.setInt(_kCounter, counter);
    await prefs.setInt(_kLastBeYear, be);

    final yy = (be % 100).toString().padLeft(2, '0');
    final nnn = counter.toString().padLeft(3, '0');
    return '$yy-$nnn';
  }

  /// ดูเลขปัจจุบัน (ไม่เพิ่ม)
  static Future<String> peek() async {
    final now = DateTime.now();
    final be = ThFormat.beYear(now);
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt(_kCounter) ?? 0;
    final yy = (be % 100).toString().padLeft(2, '0');
    final nnn = counter.toString().padLeft(3, '0');
    return '$yy-$nnn';
  }

  /// เซ็ตตัวนับด้วยมือ (กรณีต้องย้ายระบบ)
  static Future<void> setCounter(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCounter, value);
  }
}