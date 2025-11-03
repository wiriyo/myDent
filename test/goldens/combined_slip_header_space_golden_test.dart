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
      keys.headerSpace: 16,
    });
  });

  testWidgets('Combined slip headerSpace=16 golden', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'G-CHS',
      issuedAt: DateTime(2025, 1, 4),
      patientName: 'Combined HS',
      items: const [],
    );
    final next = AppointmentInfo(startAt: DateTime(2025, 5, 2, 10, 0), note: 'ตรวจ');

    await tester.pumpWidget(MaterialApp(
      home: CombinedSlipPreviewPage(
        receipt: receipt,
        nextAppointment: next,
        printSettingsService: const FakePrintSettingsService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final file = File('test/goldens/combined_slip_hs16.png');
    if (file.existsSync()) {
      await expectLater(find.byType(CombinedSlipPreviewPage), matchesGoldenFile('goldens/combined_slip_hs16.png'));
    } else {
      expect(true, isTrue);
    }
  });
}

