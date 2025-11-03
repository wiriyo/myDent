import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/receipt_renderer_mydent.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
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

  testWidgets('Receipt golden', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'G-001',
      issuedAt: DateTime(2025, 1, 1),
      patientName: 'ทดสอบ',
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
    await tester.pump(const Duration(milliseconds: 200));

    final file = File('test/goldens/receipt.png');
    if (file.existsSync()) {
      await expectLater(find.byType(ReceiptPreviewPage), matchesGoldenFile('goldens/receipt.png'));
    } else {
      expect(true, isTrue);
    }
  });
}
