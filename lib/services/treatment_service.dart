// v1.4.0 - 🗑️ เพิ่มฟังก์ชันสำหรับลบรูปภาพเดี่ยวๆ ของการรักษา
// v1.3.0 - ✨ อัปเกรดให้บันทึกรูปภาพลงแกลเลอรีรวมโดยอัตโนมัติ
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/treatment.dart';
import 'medical_image_service.dart';

class TreatmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicalImageService _medicalImageService = MedicalImageService();

  /// ฟังก์ชันสำหรับเข้าถึง collection 'treatments' ของคนไข้แต่ละคน
  CollectionReference _getTreatmentsCollection(String patientId) {
    return _firestore.collection('patients').doc(patientId).collection('treatments');
  }

  /// ✨ [NEW v1.3.0] ผู้ช่วยสำหรับบันทึก URL รูปภาพลงในแกลเลอรีรวม
  Future<void> _saveImageUrlToMainGallery(String patientId, String imageUrl) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('medical_images')
          .add({
        'url': imageUrl,
        'createdAt': Timestamp.now(),
      });
      debugPrint("✅ Saved image URL to main gallery.");
    } catch (e) {
      debugPrint("❌ Failed to save image URL to main gallery: $e");
    }
  }

  /// ✨ [NEW v1.3.0] ผู้ช่วยสำหรับลบรูปภาพออกจากแกลเลอรีรวมโดยใช้ URL
  Future<void> _deleteImageFromMainGallery(String patientId, String imageUrl) async {
    try {
      final querySnapshot = await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('medical_images')
          .where('url', isEqualTo: imageUrl)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
        debugPrint("🗑️ Deleted image record from main gallery.");
      }
    } catch (e) {
      debugPrint("❌ Failed to delete image record from main gallery: $e");
    }
  }

  /// ดึงข้อมูลการรักษาทั้งหมดของคนไข้มาแสดง
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

  /// [UPGRADED v1.3.0] เพิ่มการรักษาใหม่ พร้อมบันทึกรูปภาพลงแกลเลอรีรวม
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
          await _saveImageUrlToMainGallery(patientId, imageUrl);
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

  /// [UPGRADED v1.3.0] อัปเดตการรักษาเดิม พร้อมบันทึกรูปภาพใหม่ลงแกลเลอรีรวม
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
          await _saveImageUrlToMainGallery(patientId, imageUrl);
        }
      }
      final updatedTreatment = treatment.copyWith(imageUrls: updatedImageUrls);
      await _getTreatmentsCollection(patientId).doc(treatment.id).update(updatedTreatment.toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการอัปเดตข้อมูลการรักษา: $e");
      rethrow;
    }
  }

  /// ✨ [NEW v1.4.0] ฟังก์ชันสำหรับลบรูปภาพเดี่ยวๆ ของการรักษา
  /// ฟังก์ชันนี้จะทำหน้าที่ลบรูปภาพออกจากทุกที่: Storage, แกลเลอรีรวม, และอัลบั้มของการรักษา
  Future<void> deleteTreatmentImage({
    required String patientId,
    required String treatmentId,
    required String imageUrl,
  }) async {
    try {
      // 1. ลบไฟล์รูปออกจาก Storage
      await _medicalImageService.deleteImageFromUrl(imageUrl);
      
      // 2. ลบข้อมูลรูปออกจากแกลเลอรีรวม
      await _deleteImageFromMainGallery(patientId, imageUrl);

      // 3. นำ URL ของรูปออกจาก Array 'imageUrls' ในเอกสาร treatment
      final docRef = _getTreatmentsCollection(patientId).doc(treatmentId);
      await docRef.update({
        'imageUrls': FieldValue.arrayRemove([imageUrl])
      });

      debugPrint("🗑️ Completely deleted treatment image: $imageUrl");
    } catch (e) {
      debugPrint("❌ Failed to delete treatment image: $e");
      rethrow;
    }
  }

  /// [UPGRADED v1.3.0] ลบการรักษา พร้อมทั้งลบรูปภาพที่เกี่ยวข้องออกจาก Storage และแกลเลอรีรวม
  Future<void> deleteTreatment(String patientId, String treatmentId) async {
    try {
      final docRef = _getTreatmentsCollection(patientId).doc(treatmentId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final treatmentData = Treatment.fromMap(docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
        if (treatmentData.imageUrls.isNotEmpty) {
          for (final imageUrl in treatmentData.imageUrls) {
            await _medicalImageService.deleteImageFromUrl(imageUrl);
            await _deleteImageFromMainGallery(patientId, imageUrl);
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
