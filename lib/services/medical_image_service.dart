// ================================================================
// 📁 2. lib/services/medical_image_service.dart
// v1.2.0 - ✨ เพิ่มเครื่องมือสำหรับจัดการรูปภาพของการรักษาโดยเฉพาะ
// ================================================================
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/feature_flags.dart';
import '../config/clinic_context.dart';

class MedicalImageService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<String> uploadImageAndGetUrl({
    required File file,
    required String patientId,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final fileName = const Uuid().v4();
      final clinicId = ClinicContext.activeClinicId;
      final path = (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty)
          ? 'medical_images/$clinicId/$patientId/$fileName.jpg'
          : 'medical_images/$patientId/$fileName.jpg';
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint("✅ Image uploaded. URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ Image upload failed: $e");
      rethrow;
    }
  }

  Future<void> deleteImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('🗑️ Deleted image from Storage: $imageUrl');
    } catch (e) {
      debugPrint('❌ Error deleting image from Storage by URL: $e');
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
      // Try delete both legacy and nested folder
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
         debugPrint('❌ Error deleting patient images from Storage: $e');
      }
    }
  }
}
