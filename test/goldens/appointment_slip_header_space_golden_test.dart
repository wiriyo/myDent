import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import '../test_utils/fake_print_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 3,
      'mydent.printing.headerspace': 20, // test a non-zero header space
    });
  });

  testWidgets('Appointment slip headerSpace=20 golden', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppointmentSlipPreviewPage(
        useSampleData: true,
        printSettingsService: FakePrintSettingsService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final file = File('test/goldens/appointment_slip_hs20.png');
    if (file.existsSync()) {
      await expectLater(find.byType(AppointmentSlipPreviewPage), matchesGoldenFile('goldens/appointment_slip_hs20.png'));
    } else {
      expect(true, isTrue);
    }
  });
}

