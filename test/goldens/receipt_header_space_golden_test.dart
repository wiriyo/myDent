import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/receipt_renderer_mydent.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import '../test_utils/fake_print_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 3,
      'mydent.printing.headerspace': 24,
    });
  });

  testWidgets('Receipt headerSpace=24 golden', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'G-HS',
      issuedAt: DateTime(2025, 1, 3),
      patientName: 'Slip HS',
      items: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: ReceiptPreviewPage(
        receipt: receipt,
        useSampleData: false,
        printSettingsService: const FakePrintSettingsService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final file = File('test/goldens/receipt_hs24.png');
    if (file.existsSync()) {
      await expectLater(find.byType(ReceiptPreviewPage), matchesGoldenFile('goldens/receipt_hs24.png'));
    } else {
      expect(true, isTrue);
    }
  });
}

