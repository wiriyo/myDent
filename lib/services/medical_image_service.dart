import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/clinic_context.dart';
import '../config/feature_flags.dart';
import '../utils/upload_image_payload.dart';

class MedicalImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadImageAndGetUrl({
    required UploadImagePayload image,
    required String patientId,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final fileName = _resolveFileName(image);
      final clinicId = ClinicContext.activeClinicId;
      final path = (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty)
          ? 'medical_images/$clinicId/$patientId/$fileName'
          : 'medical_images/$patientId/$fileName';
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        image.bytes,
        SettableMetadata(
          contentType: image.contentType ?? 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        ),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Uploaded medical image. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      rethrow;
    }
  }

  Future<void> deleteImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('Deleted image from Storage: $imageUrl');
    } catch (e) {
      debugPrint('Error deleting image from Storage by URL: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getMedicalImages(String patientId) {
    final clinicId = ClinicContext.activeClinicId;
    CollectionReference<Map<String, dynamic>> imagesRef;
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
      imagesRef = _firestore.collection('clinics').doc(clinicId)
          .collection('patients').doc(patientId)
          .collection('medical_images');
    } else {
      imagesRef = _firestore.collection('patients').doc(patientId)
          .collection('medical_images');
    }
    return imagesRef.orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'url': data['url'] ?? '',
                'createdAt': data['createdAt'],
              };
            }).toList());
  }

  Future<void> deleteAllPatientImages(String patientId) async {
    if (patientId.isEmpty) return;
    try {
      final clinicId = ClinicContext.activeClinicId;
      final legacyRef = _storage.ref('medical_images/$patientId');
      try {
        final listLegacy = await legacyRef.listAll();
        for (final item in listLegacy.items) {
          await item.delete();
        }
      } catch (_) {}

      if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
        final nestedRef = _storage.ref('medical_images/$clinicId/$patientId');
        try {
          final listNested = await nestedRef.listAll();
          for (final item in listNested.items) {
            await item.delete();
          }
        } catch (_) {}
      }
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
         debugPrint('Error deleting patient images from Storage: $e');
      }
    }
  }

  String _resolveFileName(UploadImagePayload image) {
    final providedName = image.fileName?.trim();
    final baseWithoutExt = providedName != null && providedName.isNotEmpty
        ? _sanitizeFileName(_stripExtension(providedName))
        : '';
    final base = baseWithoutExt.isEmpty ? const Uuid().v4() : baseWithoutExt;
    final extension = _extensionFromFileName(image.fileName) ??
        _extensionFromContentType(image.contentType) ??
        'jpg';
    return '$base.$extension';
  }

  String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }

  String _sanitizeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final collapsed = sanitized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  String? _extensionFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return null;
    final ext = fileName.substring(dot + 1).toLowerCase();
    if (ext.isEmpty) return null;
    return ext;
  }

  String? _extensionFromContentType(String? contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/bmp':
        return 'bmp';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
    }
    return null;
  }
}
