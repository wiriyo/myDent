// Run with Firebase Emulator:
// 1) Start emulators: firestore at localhost:8080
// 2) flutter test integration_test/clinic_header_live_update_test.dart -d emulator-5554

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import 'package:mydent_app/firebase_options.dart';
import 'package:mydent_app/services/clinic_settings_service.dart';
import 'package:mydent_app/config/clinic_context.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Clinic header updates via Firestore emulator', (tester) async {
    // Pump a minimal widget tree to avoid integration_test screenshot issues
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    await tester.runAsync(() async {
      // Resolve host/port from --dart-define (compile-time) or env
      String host = const String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: 'localhost');
      String portStrDef = const String.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: '8080');
      int port = int.tryParse(portStrDef) ?? 8080;

      // Allow combined form in either source: FIRESTORE_EMULATOR_HOST=host:port
      String? hpEnv;
      if (host == 'localhost' && port == 8080) {
        hpEnv = Platform.environment['FIRESTORE_EMULATOR_HOST'];
      }
      final hp = hpEnv ?? host;
      if (hp.contains(':')) {
        final parts = hp.split(':');
        host = parts[0];
        if (parts.length > 1) {
          port = int.tryParse(parts[1]) ?? port;
        }
      } else if (hpEnv != null) {
        // No combined env; try separate env vars
        final portStr = Platform.environment['FIRESTORE_EMULATOR_PORT'] ?? '$port';
        port = int.tryParse(portStr) ?? port;
      }

      // Android emulator uses 10.0.2.2 to reach host machine
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (host == 'localhost' || host == '127.0.0.1') {
          debugPrint('Mapping Firestore Emulator host "localhost" to "10.0.2.2".');
          host = '10.0.2.2';
        }
      }

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      await FirebaseFirestore.instance.clearPersistence();

      // Auth: connect to Auth emulator and sign in anonymously to satisfy security rules
      try {
        FirebaseAuth.instance.useAuthEmulator(host, 9099);
      } catch (_) {}
      await FirebaseAuth.instance.signInAnonymously();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Use a fixed clinic id for the test
      ClinicContext.activeClinicId = 'it_clinic_test';
      final svc = ClinicSettingsService();

      // Seed membership doc to pass security rules (clinics/{clinicId}/members/{uid})
      final clinics = FirebaseFirestore.instance.collection('clinics');
      await clinics.doc(ClinicContext.activeClinicId).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await clinics.doc(ClinicContext.activeClinicId).collection('members').doc(uid).set({'role': 'admin', 'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      // Seed header data
      await svc.saveClinicInfo(
        clinicId: ClinicContext.activeClinicId,
        name: 'Emulator Clinic',
        address: '123 Test St',
        phone: '099-9999999',
        lineId: 'emu_line',
        showLineId: true,
        taxId: 'TAX-123',
        showTaxId: true,
      );

      // Listen and expect new snapshot with timeout to avoid hang
      final stream = svc.watchClinicInfo(clinicId: ClinicContext.activeClinicId);
      final first = await stream
          .firstWhere((d) => d != null && d!['name'] == 'Emulator Clinic')
          .timeout(const Duration(seconds: 10));
      expect(first, isNotNull);
      expect(first!['phone'], '099-9999999');
    });
  });
}
