// ================================================================
// 📁 3. lib/services/treatment_service.dart
// v1.2.0 - ✨ อัปเกรดให้จัดการ "อัลบั้มรูปการรักษา" ได้
// ================================================================
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/treatment.dart';
import 'medical_image_service.dart';

class TreatmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicalImageService _medicalImageService = MedicalImageService();

  CollectionReference _getTreatmentsCollection(String patientId) {
    return _firestore.collection('patients').doc(patientId).collection('treatments');
  }

  Stream<List<Treatment>> getTreatments(String patientId) {
    return _getTreatmentsCollection(patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Treatment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addTreatment(String patientId, Treatment treatment, {List<File>? images}) async {
    try {
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (var imageFile in images) {
          final imageUrl = await _medicalImageService.uploadImageAndGetUrl(
            file: imageFile,
            patientId: patientId,
          );
          imageUrls.add(imageUrl);
        }
      }
      final treatmentWithImages = treatment.copyWith(imageUrls: imageUrls);
      final docRef = _getTreatmentsCollection(patientId).doc();
      await docRef.set(treatmentWithImages.copyWith(id: docRef.id).toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการเพิ่มข้อมูลการรักษา: $e");
      rethrow;
    }
  }

  Future<void> updateTreatment(String patientId, Treatment treatment, {List<File>? newImages}) async {
    try {
      List<String> updatedImageUrls = List.from(treatment.imageUrls);
      if (newImages != null && newImages.isNotEmpty) {
        for (var imageFile in newImages) {
          final imageUrl = await _medicalImageService.uploadImageAndGetUrl(
            file: imageFile,
            patientId: patientId,
          );
          updatedImageUrls.add(imageUrl);
        }
      }
      final updatedTreatment = treatment.copyWith(imageUrls: updatedImageUrls);
      await _getTreatmentsCollection(patientId).doc(treatment.id).update(updatedTreatment.toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการอัปเดตข้อมูลการรักษา: $e");
      rethrow;
    }
  }

  Future<void> deleteTreatment(String patientId, String treatmentId) async {
    try {
      final docRef = _getTreatmentsCollection(patientId).doc(treatmentId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final treatmentData = Treatment.fromMap(docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
        if (treatmentData.imageUrls.isNotEmpty) {
          for (final imageUrl in treatmentData.imageUrls) {
            await _medicalImageService.deleteImageFromUrl(imageUrl);
          }
        }
      }
      await docRef.delete();
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการลบข้อมูลการรักษา: $e");
      rethrow;
    }
  }
}