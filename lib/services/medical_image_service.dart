// ----------------------------------------------------------------
// 📁 lib/services/medical_image_service.dart
// v1.1.0 - ✨ เพิ่มความสามารถในการลบรูปภาพทั้งหมดของคนไข้
// ----------------------------------------------------------------
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MedicalImageService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> uploadMedicalImage({
    required File file,
    required String patientId,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final fileName = const Uuid().v4();
      final ref = _storage.ref().child('medical_images/$patientId/$fileName.jpg');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('medical_images')
          .add({
        'url': downloadUrl,
        'createdAt': Timestamp.now(),
      });

      debugPrint("✅ Upload success: $downloadUrl");
    } catch (e) {
      debugPrint("❌ Upload failed: $e");
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getMedicalImages(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('medical_images')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'url': data['url'] ?? '',
                'createdDate': data['createdAt'],
              };
            }).toList());
  }

  // ✨ [NEW v1.1] เมธอดสำหรับลบรูปภาพทั้งหมดใน Storage ของคนไข้คนเดียว
  Future<void> deleteAllPatientImages(String patientId) async {
    if (patientId.isEmpty) return;
    try {
      // 1. ไปที่โฟลเดอร์รูปภาพของคนไข้คนนั้น
      final listResult = await _storage.ref('medical_images/$patientId').listAll();
      
      // 2. วนลูปเพื่อลบไฟล์ทีละไฟล์
      for (final item in listResult.items) {
        await item.delete();
        debugPrint('🗑️ Deleted image from Storage: ${item.fullPath}');
      }
    } on FirebaseException catch (e) {
      // ถ้าไม่เจอโฟลเดอร์ (เช่น คนไข้ไม่เคยมีรูป) ก็ไม่เป็นไรค่ะ ให้ทำงานต่อไปได้เลย
      if (e.code == 'object-not-found') {
        debugPrint('ℹ️ No images folder to delete for patient $patientId.');
      } else {
        debugPrint('❌ Error deleting patient images from Storage: $e');
        // ไม่ต้อง rethrow ก็ได้ค่ะ เพื่อให้การลบข้อมูลใน Firestore ยังคงดำเนินต่อไป
      }
    }
  }
}