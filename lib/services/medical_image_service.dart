import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalImageService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> uploadMedicalImage({
    required File file,
    required String patientId,
  }) async {
    try {
      // ✅ 1. เช็กให้แน่ใจว่ามี user signed in ก่อน
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // 🏷️ ตั้งชื่อไฟล์แบบไม่ซ้ำ
      final fileName = const Uuid().v4();
      final ref = _storage.ref().child('medical_images/$patientId/$fileName.jpg');

      // 📤 อัปโหลดไฟล์
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 🧾 บันทึก URL ไปยัง Firestore
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('medical_images')
          .add({
        'url': downloadUrl,
        'createdAt': Timestamp.now(),
      });

      print("✅ Upload success: $downloadUrl");
    } catch (e) {
      print("❌ Upload failed: $e");
      rethrow;
    }
  }
}
