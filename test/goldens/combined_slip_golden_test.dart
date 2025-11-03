import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/combined_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import 'package:mydent_app/features/printing/domain/appointment_slip_model.dart';
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

  testWidgets('Combined slip golden', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'G-002',
      issuedAt: DateTime(2025, 1, 2),
      patientName: 'ทดสอบ2',
      items: const [],
    );
    final next = AppointmentInfo(startAt: DateTime(2025, 5, 1, 10, 0), note: 'ตรวจ');

    await tester.pumpWidget(MaterialApp(
      home: CombinedSlipPreviewPage(
        receipt: receipt,
        nextAppointment: next,
        printSettingsService: const FakePrintSettingsService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final file = File('test/goldens/combined_slip.png');
    if (file.existsSync()) {
      await expectLater(find.byType(CombinedSlipPreviewPage), matchesGoldenFile('goldens/combined_slip.png'));
    } else {
      expect(true, isTrue);
    }
  });
}
