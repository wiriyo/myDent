import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/clinic_context.dart';
import '../config/feature_flags.dart';

class ClinicSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _doc(String clinicId) {
    if (FeatureFlags.useNestedCollections && clinicId.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('settings').doc('clinicProfile');
    }
    // Fallback (should not be used in production): keep at root settings
    return _firestore.collection('settings').doc('clinicProfile');
  }

  String _effectiveClinicId(String? provided) {
    return (provided ?? ClinicContext.activeClinicId) ?? '';
  }

  Future<Map<String, dynamic>?> getClinicInfo({String? clinicId}) async {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return null;
    final snap = await _doc(id).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Stream<Map<String, dynamic>?> watchClinicInfo({String? clinicId}) {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return const Stream.empty();
    return _doc(id).snapshots().map((s) => s.data());
  }

  Future<void> deleteLogo({String? clinicId, required String logoUrl}) async {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return;
    try {
      await _storage.refFromURL(logoUrl).delete();
    } catch (_) {
      // ignore failures; we still nullify the URL in Firestore
    }
    await _doc(id).set({'logoUrl': null, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<String?> uploadLogo(File file, {String? clinicId}) async {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return null;
    final ref = _storage.ref().child('clinic_logos/$id/logo_${DateTime.now().millisecondsSinceEpoch}.png');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<void> saveClinicInfo({
    String? clinicId,
    String? logoUrl,
    String? name,
    String? address,
    String? phone,
    String? lineId,
    required bool showLineId,
    String? taxId,
    required bool showTaxId,
  }) async {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return;
    final payload = <String, dynamic>{
      'logoUrl': logoUrl,
      'name': name,
      'address': address,
      'phone': phone,
      'lineId': lineId,
      'showLineId': showLineId,
      'taxId': taxId,
      'showTaxId': showTaxId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _doc(id).set(payload, SetOptions(merge: true));
  }
}
