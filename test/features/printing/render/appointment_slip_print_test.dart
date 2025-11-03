import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import 'package:mydent_app/features/printing/services/print_settings_service.dart';
import 'package:mydent_app/features/printing/services/thermal_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final keys = PrintSettingsService.storageKeysForTesting();
    SharedPreferences.setMockInitialValues({
      keys.scale: 1.0,
      keys.postFeed: 4,
      keys.headerSpace: 0,
    });
  });

  tearDown(() { ThermalPrinterService.debugOverride = null; });

  testWidgets('AppointmentSlipPreviewPage tapping print calls printer (bypass capture)', (tester) async {
    final fake = _FakePrinter();
    ThermalPrinterService.debugOverride = fake;

    final preset = Uint8List.fromList([9, 8, 7, 6]);
    await tester.pumpWidget(MaterialApp(
      home: AppointmentSlipPreviewPage(
        useSampleData: true,
        debugPngOverride: preset,
        printSettingsService: const FakePrintSettingsService(),
      ),
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
