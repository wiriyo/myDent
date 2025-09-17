import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/combined_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/receipt_renderer_mydent.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
    await tester.pump();
    final ctx = tester.element(find.byType(Scaffold));
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  testWidgets('E2E: Print from Appointment/Receipt/Combined (mock printer)', (tester) async {
    final fake = _FakePrinter();
    ThermalPrinterService.debugOverride = fake;

    // 1) Appointment
    await openPage(tester, AppointmentSlipPreviewPage(useSampleData: true, debugPngOverride: Uint8List.fromList([1,2,3])));
    await tester.tap(find.byKey(const ValueKey('appointment_print_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(fake.called, isTrue);

    // Reset
    fake.called = false;

    // 2) Receipt
    final receipt = buildReceiptModel(
      clinicName: 'X', clinicAddress: '-', clinicPhone: '-',
      billNo: 'E2E-1', issuedAt: DateTime.now(), patientName: 'Test', items: const [],
    );
    await openPage(tester, ReceiptPreviewPage(receipt: receipt, useSampleData: false, debugPngOverride: Uint8List.fromList([4,5,6])));
    await tester.tap(find.byKey(const ValueKey('receipt_print_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(fake.called, isTrue);

    // Reset
    fake.called = false;

    // 3) Combined
    final rec2 = buildReceiptModel(
      clinicName: 'X', clinicAddress: '-', clinicPhone: '-',
      billNo: 'E2E-2', issuedAt: DateTime.now(), patientName: 'Test2', items: const [],
    );
    final next = AppointmentInfo(startAt: DateTime.now().add(const Duration(days: 1)), note: 'ตรวจ');
    await openPage(tester, CombinedSlipPreviewPage(receipt: rec2, nextAppointment: next, debugPngOverride: Uint8List.fromList([7,8,9])));
    await tester.tap(find.byKey(const ValueKey('combined_print_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(fake.called, isTrue);

    // Clean override
    ThermalPrinterService.debugOverride = null;
  });
}
