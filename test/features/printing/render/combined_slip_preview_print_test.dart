import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/combined_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import 'package:mydent_app/features/printing/domain/appointment_slip_model.dart';
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
      'mydent.printing.postfeed': 7,
      'mydent.printing.headerspace': 0,
    });
  });

  tearDown(() { ThermalPrinterService.debugOverride = null; });

  testWidgets('CombinedSlipPreviewPage tapping print calls printer', (tester) async {
    final fake = _FakePrinter();
    ThermalPrinterService.debugOverride = fake;

    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'P-002',
      issuedAt: DateTime(2025, 1, 2),
      patientName: 'ทดสอบ2',
      items: const [],
    );
    final appt = AppointmentInfo(startAt: DateTime(2025, 5, 1, 9, 0), note: 'ตรวจ');

    final preset = Uint8List.fromList([3, 2, 1, 0]);
    await tester.pumpWidget(MaterialApp(home: CombinedSlipPreviewPage(
      receipt: receipt,
      nextAppointment: appt,
      debugPngOverride: preset,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('combined_print_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.called, isTrue);
    expect(fake.lastFeed, 7);
    expect(fake.lastCut, isTrue);
  });
}
