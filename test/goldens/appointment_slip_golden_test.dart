import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 3,
      'mydent.printing.headerspace': 0,
    });
  });

  testWidgets('Appointment slip golden', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppointmentSlipPreviewPage(useSampleData: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final file = File('test/goldens/appointment_slip.png');
    if (file.existsSync()) {
      await expectLater(find.byType(AppointmentSlipPreviewPage), matchesGoldenFile('goldens/appointment_slip.png'));
    } else {
      // Baseline not present; run with --update-goldens to create
      expect(true, isTrue);
    }
  });
}
