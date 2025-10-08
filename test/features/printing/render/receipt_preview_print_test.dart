import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/receipt_renderer_mydent.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import 'package:mydent_app/features/printing/services/thermal_printer_service.dart';
import '../../../test_utils/fake_print_settings_service.dart';

class _FakePrinter implements PrinterClient {
  bool called = false;
  int? lastFeed;
  bool? lastCut;
  @override
  Future<void> ensureConnectAndPrintPng(BuildContext context, Uint8List pngBytes, {int feed = 3, bool cut = true}) async {
    called = true;
    lastFeed = feed;
    lastCut = cut;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      // set a non-default feed to verify it is passed to printer
      'mydent.printing.postfeed': 5,
      'mydent.printing.headerspace': 0,
    });
  });

  tearDown(() { ThermalPrinterService.debugOverride = null; });

  testWidgets('ReceiptPreviewPage tapping print calls printer', (tester) async {
    final fake = _FakePrinter();
    ThermalPrinterService.debugOverride = fake;

    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'P-001',
      issuedAt: DateTime(2025, 1, 1),
      patientName: 'ทดสอบ',
      items: const [],
    );

    // Provide debugPngOverride to bypass capture in widget tests
    final preset = Uint8List.fromList([0, 1, 2, 3]);
    await tester.pumpWidget(MaterialApp(
      home: ReceiptPreviewPage(
        receipt: receipt,
        useSampleData: false,
        debugPngOverride: preset,
        printSettingsService: const FakePrintSettingsService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('receipt_print_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.called, isTrue);
    expect(fake.lastFeed, 5);
    expect(fake.lastCut, isTrue);
  });
}
