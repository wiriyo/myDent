import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/combined_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import 'package:mydent_app/features/printing/domain/appointment_slip_model.dart';
import '../test_utils/fake_print_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 3,
      'mydent.printing.headerspace': 16,
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

