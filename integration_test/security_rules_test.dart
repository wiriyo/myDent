// Integration tests for Firestore security rules using local emulators.
// Requires Firestore + Auth emulators running and reachable from device.
//
// Example run on a physical Android device (same LAN as your PC):
// flutter test -d <deviceId> \
//   --dart-define=FIRESTORE_EMULATOR_HOST=192.168.1.85 \
//   --dart-define=FIRESTORE_EMULATOR_PORT=8080 \
//   integration_test/security_rules_test.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mydent_app/firebase_options.dart';

Future<(String host, int port)> _resolveEmulator() async {
  String host = const String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: 'localhost');
  String portStr = const String.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: '8080');
  int port = int.tryParse(portStr) ?? 8080;

  // Allow combined env FIRESTORE_EMULATOR_HOST=host:port
  final hpEnv = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  if ((host == 'localhost' && port == 8080) && hpEnv != null) {
    if (hpEnv.contains(':')) {
      final parts = hpEnv.split(':');
      host = parts[0];
      if (parts.length > 1) port = int.tryParse(parts[1]) ?? port;
    } else {
      host = hpEnv;
      final p = Platform.environment['FIRESTORE_EMULATOR_PORT'];
      if (p != null) port = int.tryParse(p) ?? port;
    }
  }

  // Android emulator uses 10.0.2.2 for host machine
  if (defaultTargetPlatform == TargetPlatform.android) {
    if (host == 'localhost' || host == '127.0.0.1') host = '10.0.2.2';
  }
  return (host, port);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firestore rules: non-member denied, member allowed', (tester) async {
    // Minimal widget tree
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    await tester.runAsync(() async {
      final (host, port) = await _resolveEmulator();

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      try { await FirebaseFirestore.instance.clearPersistence(); } catch (_) {}

      // Auth emulator
      try { FirebaseAuth.instance.useAuthEmulator(host, 9099); } catch (_) {}

      final now = DateTime.now().millisecondsSinceEpoch;
      final clinicId = 'rules_test_$now';
      final clinics = FirebaseFirestore.instance.collection('clinics');

      // Sign in as user A (non-member) and attempt write -> denied
      await FirebaseAuth.instance.signInAnonymously();
      final uidA = FirebaseAuth.instance.currentUser!.uid;

      bool deniedA = false;
      try {
        await clinics.doc(clinicId).collection('settings').doc('clinicProfile').set({ 'name': 'X' });
      } on FirebaseException catch (e) {
        deniedA = e.code == 'permission-denied';
      }
      expect(deniedA, isTrue, reason: 'Non-member should be denied writing clinic settings');

      // Create clinic doc (allowed create when signed-in per dev rules) and add membership for A
      await clinics.doc(clinicId).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await clinics.doc(clinicId).collection('members').doc(uidA).set({'role': 'admin'});

      // Now write should succeed
      await clinics.doc(clinicId).collection('settings').doc('clinicProfile').set({
        'name': 'Clinic A',
        'phone': '099-0000000',
      }, SetOptions(merge: true));

      // Verify read allowed
      final doc = await clinics.doc(clinicId).collection('settings').doc('clinicProfile').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'Clinic A');

      // Sign in as user B (non-member)
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      final uidB = FirebaseAuth.instance.currentUser!.uid;

      // Read should be denied for B (non-member)
      bool deniedReadB = false;
      try {
        await clinics.doc(clinicId).collection('settings').doc('clinicProfile').get();
      } on FirebaseException catch (e) {
        deniedReadB = e.code == 'permission-denied';
      }
      expect(deniedReadB, isTrue, reason: 'Non-member should be denied reading clinic settings');

      // Write other member document (A) as B should be denied
      bool deniedWriteOtherMember = false;
      try {
        await clinics.doc(clinicId).collection('members').doc(uidA).set({'role': 'admin2'});
      } on FirebaseException catch (e) {
        deniedWriteOtherMember = e.code == 'permission-denied';
      }
      expect(deniedWriteOtherMember, isTrue, reason: 'User should not write membership for others');

      // B can add self to members
      await clinics.doc(clinicId).collection('members').doc(uidB).set({'role': 'staff'});

      // After membership, B can read settings
      final docB = await clinics.doc(clinicId).collection('settings').doc('clinicProfile').get();
      expect(docB.exists, isTrue);

      // Clean-up (optional): remove created docs
      try {
        final settings = clinics.doc(clinicId).collection('settings');
        final settingsSnap = await settings.get();
        for (final d in settingsSnap.docs) { await d.reference.delete(); }
        final members = clinics.doc(clinicId).collection('members');
        final memSnap = await members.get();
        for (final d in memSnap.docs) { await d.reference.delete(); }
        await clinics.doc(clinicId).delete();
      } catch (_) {}
    });
  });

  testWidgets('Firestore rules: patients and appointments under clinics/{clinicId}', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    await tester.runAsync(() async {
      final (host, port) = await _resolveEmulator();

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      try { await FirebaseFirestore.instance.clearPersistence(); } catch (_) {}

      try { FirebaseAuth.instance.useAuthEmulator(host, 9099); } catch (_) {}

      final now = DateTime.now().millisecondsSinceEpoch;
      final clinicId = 'rules_pat_appt_$now';
      final clinics = FirebaseFirestore.instance.collection('clinics');
      final patients = clinics.doc(clinicId).collection('patients');
      final appts = clinics.doc(clinicId).collection('appointments');

      // Non-member (C) cannot write patients or appointments
      await FirebaseAuth.instance.signInAnonymously();
      final uidC = FirebaseAuth.instance.currentUser!.uid;
      bool deniedPatientWriteC = false;
      try { await patients.doc('p1').set({'name': 'John'}); } on FirebaseException catch (e) { deniedPatientWriteC = e.code == 'permission-denied'; }
      expect(deniedPatientWriteC, isTrue, reason: 'Non-member should be denied writing patients');

      bool deniedApptWriteC = false;
      try { await appts.doc('a1').set({'startTime': Timestamp.now()}); } on FirebaseException catch (e) { deniedApptWriteC = e.code == 'permission-denied'; }
      expect(deniedApptWriteC, isTrue, reason: 'Non-member should be denied writing appointments');

      // Bootstrap clinic + add C to members
      await clinics.doc(clinicId).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await clinics.doc(clinicId).collection('members').doc(uidC).set({'role': 'admin'});

      // Now write patients/appointments allowed
      await patients.doc('p1').set({'name': 'John', 'createdAt': FieldValue.serverTimestamp()});
      await appts.doc('a1').set({'startTime': Timestamp.now(), 'createdAt': FieldValue.serverTimestamp()});

      // Read allowed
      final p1 = await patients.doc('p1').get();
      final a1 = await appts.doc('a1').get();
      expect(p1.exists, isTrue);
      expect(a1.exists, isTrue);

      // Another user (D) who is not member cannot read
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      bool deniedPatientReadD = false;
      try { await patients.doc('p1').get(); } on FirebaseException catch (e) { deniedPatientReadD = e.code == 'permission-denied'; }
      expect(deniedPatientReadD, isTrue, reason: 'Non-member should be denied reading patients');

      bool deniedApptReadD = false;
      try { await appts.doc('a1').get(); } on FirebaseException catch (e) { deniedApptReadD = e.code == 'permission-denied'; }
      expect(deniedApptReadD, isTrue, reason: 'Non-member should be denied reading appointments');

      // Clean-up
      try {
        final ps = await patients.get();
        for (final d in ps.docs) { await d.reference.delete(); }
        final as = await appts.get();
        for (final d in as.docs) { await d.reference.delete(); }
        final mems = await clinics.doc(clinicId).collection('members').get();
        for (final d in mems.docs) { await d.reference.delete(); }
        await clinics.doc(clinicId).delete();
      } catch (_) {}
    });
  });
}
