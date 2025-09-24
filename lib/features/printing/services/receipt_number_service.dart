// lib/features/printing/services/receipt_number_service.dart
// บริการสำหรับจัดการเลขใบเสร็จ (Receipt Number)
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/clinic_sequence_service.dart';
import '../utils/th_format.dart';

/// รูปแบบเลขใบเสร็จ: YY-NNN (ปี พ.ศ. 2 หลัก)
class ReceiptNumberService {
  static const _kLastBeYear = 'md_receipt_last_be_year';
  static const _kCounter = 'md_receipt_counter';

  /// คืนค่าเลขใบเสร็จใหม่พร้อมอัปเดตตัวนับ
  static Future<String> next() async {
    final now = DateTime.now();
    final be = ThFormat.beYear(now);
    try {
      final result = await ClinicSequenceService().nextReceipt();
      await _persistLocal(be, result.counter);
      return result.value;
    } catch (e) {
      debugPrint('❌ ReceiptNumberService.next Firestore error: $e');
      return _localNext(be);
    }
  }

  /// ดูเลขปัจจุบัน (ไม่เพิ่ม)
  static Future<String> peek() async {
    final now = DateTime.now();
    final be = ThFormat.beYear(now);
    try {
      final result = await ClinicSequenceService().peekReceipt();
      if (result != null) {
        await _persistLocal(be, result.counter);
        return result.value;
      }
    } catch (e) {
      debugPrint('❌ ReceiptNumberService.peek Firestore error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt(_kCounter) ?? 0;
    final yy = (be % 100).toString().padLeft(2, '0');
    final nnn = counter.toString().padLeft(3, '0');
    return '$yy-$nnn';
  }

  /// เซ็ตตัวนับด้วยมือ (กรณีต้องย้ายระบบ)
  static Future<void> setCounter(int value) async {
    try {
      await ClinicSequenceService().overrideReceiptCounter(value);
    } catch (e) {
      debugPrint('❌ ReceiptNumberService.setCounter Firestore error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCounter, value);
  }

  static Future<void> _persistLocal(int beYear, int counter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastBeYear, beYear);
    await prefs.setInt(_kCounter, counter);
  }

  static Future<String> _localNext(int beYear) async {
    final prefs = await SharedPreferences.getInstance();
    final lastBe = prefs.getInt(_kLastBeYear) ?? beYear;
    int counter = prefs.getInt(_kCounter) ?? 0;
    if (lastBe != beYear) {
      counter = 0;
      await prefs.setInt(_kLastBeYear, beYear);
    }
    counter += 1;
    await prefs.setInt(_kCounter, counter);
    await prefs.setInt(_kLastBeYear, beYear);
    final yy = (beYear % 100).toString().padLeft(2, '0');
    final nnn = counter.toString().padLeft(3, '0');
    return '$yy-$nnn';
  }
}