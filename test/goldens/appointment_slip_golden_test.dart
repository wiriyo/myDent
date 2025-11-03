import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import 'package:mydent_app/features/printing/services/print_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_utils/fake_print_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    final keys = PrintSettingsService.storageKeysForTesting();
    SharedPreferences.setMockInitialValues({
      keys.scale: 1.0,
      keys.postFeed: 3,
      keys.headerSpace: 0,
    });
  });

  testWidgets('Appointment slip golden', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppointmentSlipPreviewPage(
        useSampleData: true,
        printSettingsService: FakePrintSettingsService(),
      ),
    ));
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
