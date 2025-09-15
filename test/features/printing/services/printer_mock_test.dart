import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/widgets/print_button.dart';
import 'package:mydent_app/features/printing/services/thermal_printer_service.dart';

class _FakePrinterService implements PrinterClient {
  bool called = false;
  Uint8List? lastBytes;
  int? lastFeed;
  bool? lastCut;

  @override
  Future<void> ensureConnectAndPrintPng(BuildContext context, Uint8List pngBytes, {int feed = 3, bool cut = true}) async {
    called = true;
    lastBytes = pngBytes;
    lastFeed = feed;
    lastCut = cut;
    // Simulate a quick success
    return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 2,
      'mydent.printing.headerspace': 5,
    });
  });

  tearDown(() {
    ThermalPrinterService.debugOverride = null;
  });

  testWidgets('PrintButton taps and calls printer service with provided bytes', (tester) async {
    final fake = _FakePrinterService();
    ThermalPrinterService.debugOverride = fake;

    final sample = Uint8List.fromList(List<int>.generate(100, (i) => i % 256));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrintButton(pngBytes: sample, label: 'พิมพ์'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PrintButton));
    await tester.pumpAndSettle();

    expect(fake.called, isTrue);
    expect(fake.lastBytes, isNotNull);
    expect(fake.lastBytes!.isNotEmpty, isTrue);
    // Default feed value from PrintButton is 3
    expect(fake.lastFeed, 3);
    expect(fake.lastCut, isTrue);
  });
}
