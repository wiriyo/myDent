import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import 'package:mydent_app/features/printing/services/thermal_printer_service.dart';

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
      'mydent.printing.postfeed': 4,
      'mydent.printing.headerspace': 0,
    });
  });

  tearDown(() { ThermalPrinterService.debugOverride = null; });

  testWidgets('AppointmentSlipPreviewPage tapping print calls printer (bypass capture)', (tester) async {
    final fake = _FakePrinter();
    ThermalPrinterService.debugOverride = fake;

    final preset = Uint8List.fromList([9, 8, 7, 6]);
    await tester.pumpWidget(MaterialApp(
      home: AppointmentSlipPreviewPage(useSampleData: true, debugPngOverride: preset),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('appointment_print_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(fake.called, isTrue);
    expect(fake.lastFeed, 4);
    expect(fake.lastCut, isTrue);
  });
}
