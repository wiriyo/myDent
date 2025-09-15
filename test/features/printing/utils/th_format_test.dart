import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/utils/th_format.dart';

void main() {
  group('ThFormat', () {
    test('beYear converts AD to BE correctly', () {
      expect(ThFormat.beYear(DateTime(2025, 1, 1)), 2568);
      expect(ThFormat.beYear(DateTime(2000, 12, 31)), 2543);
    });

    test('baht formats number with Thai locale and unit', () {
      expect(ThFormat.baht(0), '0 บาท');
      expect(ThFormat.baht(1234), '1,234 บาท');
      expect(ThFormat.baht(1234.5), '1,234.5 บาท');
      expect(ThFormat.baht(1234.56), '1,234.56 บาท');
    });

    test('dateThai formats long and short years', () {
      final dt = DateTime(2025, 9, 15, 14, 5);
      expect(ThFormat.dateThai(dt), '15 ก.ย 2568');
      expect(ThFormat.dateThai(dt, shortYear: true), '15 ก.ย 68');
    });

    test('timeThai formats HH:mm น.', () {
      expect(ThFormat.timeThai(DateTime(2025, 1, 1, 0, 0)), '00:00 น.');
      expect(ThFormat.timeThai(DateTime(2025, 1, 1, 14, 5)), '14:05 น.');
      expect(ThFormat.timeThai(DateTime(2025, 1, 1, 9, 45)), '09:45 น.');
    });
  });
}

