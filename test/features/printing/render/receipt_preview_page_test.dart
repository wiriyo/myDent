import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mydent_app/features/printing/render/receipt_renderer_mydent.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';
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

  testWidgets('ReceiptPreviewPage shows default header and receipt content', (tester) async {
    final receipt = buildReceiptModel(
      clinicName: 'X',
      clinicAddress: '-',
      clinicPhone: '-',
      billNo: 'T-002',
      issuedAt: DateTime(2025, 1, 2),
      patientName: 'ทดสอบ2',
      items: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPreviewPage(
          receipt: receipt,
          useSampleData: false,
          printSettingsService: const FakePrintSettingsService(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('พรีวิวใบเสร็จ'), findsOneWidget);
    expect(find.text(ClinicDefaults.defaultClinicName), findsWidgets);
    expect(find.text('เลขที่'), findsOneWidget);
    expect(find.text('ค่าบริการ'), findsOneWidget);
  });
}

