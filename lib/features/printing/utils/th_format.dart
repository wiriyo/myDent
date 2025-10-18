// lib/features/printing/utils/th_format.dart
// Utilities สำหรับฟอร์แมตรูปแบบวันที่ เวลา และจำนวนเงินภาษาไทย

import 'package:intl/intl.dart';

class ThFormat {
  static String baht(num value) {
    final formatter = NumberFormat('#,##0.##', 'th_TH');
    return '${formatter.format(value)} บาท';
  }

  /// คืนค่าเป็นปีพุทธศักราช
  static int beYear(DateTime date) => date.year + 543;

  /// คืนข้อความวันที่ในรูปแบบไทย เช่น 12 ม.ค. 2568 หรือ 12 ม.ค. 68
  static String dateThai(DateTime date, {bool shortYear = false}) {
    const months = <String>[
      'ม.ค',
      'ก.พ',
      'มี.ค',
      'เม.ย',
      'พ.ค',
      'มิ.ย',
      'ก.ค',
      'ส.ค',
      'ก.ย',
      'ต.ค',
      'พ.ย',
      'ธ.ค',
    ];
    final day = date.day;
    final month = months[date.month - 1];
    final year = beYear(date);
    final yearText =
        shortYear ? (year % 100).toString().padLeft(2, '0') : year.toString();
    return '$day $month $yearText';
  }

  /// คืนข้อความเวลารูปแบบ HH:mm น.
  static String timeThai(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes น.';
  }
}
