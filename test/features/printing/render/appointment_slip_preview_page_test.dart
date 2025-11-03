import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/appointment_slip_preview_page.dart';
import 'package:mydent_app/config/clinic_defaults.dart';
import 'package:mydent_app/features/printing/services/print_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../test_utils/fake_print_settings_service.dart';

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

  testWidgets('AppointmentSlipPreviewPage shows default clinic header and slip title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentSlipPreviewPage(
          useSampleData: true,
          printSettingsService: const FakePrintSettingsService(),
        ),
      ),
    );

    // Initial loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // AppBar title exists
    expect(find.text('พรีวิวใบนัด'), findsOneWidget);
    // Default clinic name shown (when no clinic settings loaded)
    expect(find.text(ClinicDefaults.defaultClinicName), findsWidgets);
    // Slip title exists
    expect(find.text('ใบนัด'), findsOneWidget);
  });
}

