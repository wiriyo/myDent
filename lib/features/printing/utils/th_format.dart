// lib/features/printing/utils/th_format.dart
import 'package:intl/intl.dart';

class ThFormat {
  static String baht(num value) {
    final f = NumberFormat('#,##0.##', 'th_TH');
    return '${f.format(value)} บาท';
  }

  /// คืนปี พ.ศ.
  static int beYear(DateTime dt) => dt.year + 543;

  /// วันที่ไทย เช่น 12 ก.ย. 2568 หรือ 12 ก.ย. 68 (เมื่อ shortYear=true)
  static String dateThai(DateTime dt, {bool shortYear = false}) {
    final months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final d = dt.day;
    final m = months[dt.month - 1];
    final y = beYear(dt);
    final yStr = shortYear ? (y % 100).toString().padLeft(2, '0') : y.toString();
    return '$d $m $yStr';
  }

  /// เวลาไทย HH:mm น.
  static String timeThai(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm น.';
  }
}