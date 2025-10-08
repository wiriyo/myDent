import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/combined_slip_preview_page.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
import 'package:mydent_app/features/printing/domain/appointment_slip_model.dart';
import 'package:mydent_app/config/clinic_defaults.dart';
import '../../../test_utils/fake_print_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mydent.printing.scale': 1.0,
      'mydent.printing.postfeed': 3,
      'mydent.printing.headerspace': 0,
    });
  });

  testWidgets('CombinedSlipPreviewPage shows default header and both sections', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'T-001',
      issuedAt: DateTime(2025, 1, 1),
      patientName: 'ทดสอบ',
      items: const [],
    );
    final appt = AppointmentInfo(startAt: DateTime(2025, 5, 1, 10, 0), note: 'ตรวจ');

    await tester.pumpWidget(
      MaterialApp(
        home: CombinedSlipPreviewPage(
          receipt: receipt,
          nextAppointment: appt,
          printSettingsService: const FakePrintSettingsService(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    // AppBar title exists
    expect(find.text('พรีวิวสลิป'), findsOneWidget);
    // Default clinic name shown
    expect(find.text(ClinicDefaults.defaultClinicName), findsWidgets);
    // Receipt section (เลขที่, วันที่, เวลา) and Next appointment header present
    expect(find.text('เลขที่'), findsOneWidget);
    expect(find.text('นัดครั้งต่อไป'), findsOneWidget);
  });
}
