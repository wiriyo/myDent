import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/clinic_context.dart';
import '../config/feature_flags.dart';
import '../utils/upload_image_payload.dart';

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

  Future<String?> uploadLogo(UploadImagePayload image, {String? clinicId}) async {
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) return null;

    final fileName = _resolveFileName(image);
    final ref = _storage.ref().child('clinic_logos/$id/$fileName');
    final task = await ref.putData(
      image.bytes,
      SettableMetadata(contentType: image.contentType ?? 'image/png'),
    );
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
    required bool welcomeScreenEnabled,
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
      'welcomeScreenEnabled': welcomeScreenEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _doc(id).set(payload, SetOptions(merge: true));
  }

  String _resolveFileName(UploadImagePayload image) {
    final providedName = image.fileName?.trim();
    final baseWithoutExt = providedName != null && providedName.isNotEmpty
        ? _sanitizeFileName(_stripExtension(providedName))
        : 'logo_${DateTime.now().millisecondsSinceEpoch}';
    final extension = _extensionFromFileName(image.fileName) ??
        _extensionFromContentType(image.contentType) ??
        'png';
    return '$baseWithoutExt.$extension';
  }

  String _stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  String _sanitizeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final collapsed = sanitized.replaceAll(RegExp(r'_+'), '_');
    final trimmed = collapsed.replaceAll(RegExp(r'^_|_$'), '');
    return trimmed.isEmpty ? 'logo_${DateTime.now().millisecondsSinceEpoch}' : trimmed;
  }

  String? _extensionFromFileName(String? name) {
    if (name == null || name.isEmpty) return null;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  String? _extensionFromContentType(String? contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/gif':
        return 'gif';
    }
    return null;
  }
}


