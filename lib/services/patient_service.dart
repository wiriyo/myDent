// ----------------------------------------------------------------
// 📁 lib/services/patient_service.dart
// v1.3.0 - ✨ เพิ่มความสามารถในการสร้าง HN อัตโนมัติ
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import 'medical_image_service.dart';

class PatientService {
  final CollectionReference _patientsCollection = FirebaseFirestore.instance.collection('patients');
  final MedicalImageService _medicalImageService = MedicalImageService();

  // --- (เมธอด fetchPatientsOnce, getPatientById ยังคงเหมือนเดิม) ---
  Future<List<Patient>> fetchPatientsOnce() async {
    try {
      final snapshot = await _patientsCollection.orderBy('name').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        return Patient.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการดึงข้อมูลคนไข้: $e");
      return [];
    }
  }

  Future<Patient?> getPatientById(String patientId) async {
    if (patientId.isEmpty) return null;
    try {
      final doc = await _patientsCollection.doc(patientId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        return Patient.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการดึงข้อมูลคนไข้ด้วย ID: $e");
      return null;
    }
  }

  // --- ✨ [UPGRADED v1.3] อัปเกรดเมธอดเพิ่มคนไข้ ---
  Future<void> addPatient(Patient patient) async {
    try {
      // 1. 🤖 สร้าง HN ใหม่โดยอัตโนมัติ
      final newHnNumber = await _generateNewHN();
      
      // 2. สร้าง object คนไข้ใหม่พร้อมกับ HN ที่ได้รับ
      final patientWithHn = Patient(
        patientId: '', // Firestore จะสร้าง ID นี้ให้เอง
        name: patient.name,
        prefix: patient.prefix,
        hnNumber: newHnNumber, // ✨ ใช้ HN ที่สร้างขึ้นใหม่
        telephone: patient.telephone,
        address: patient.address,
        idCard: patient.idCard,
        birthDate: patient.birthDate,
        medicalHistory: patient.medicalHistory,
        allergy: patient.allergy,
        rating: patient.rating,
        gender: patient.gender,
        age: patient.age,
      );

      // 3. 💾 บันทึกข้อมูลลง Firestore
      await _patientsCollection.add(patientWithHn.toMap());
      debugPrint("✅ Added new patient with HN: $newHnNumber");

    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการเพิ่มคนไข้: $e");
      rethrow;
    }
  }

  // ✨ [NEW v1.3] เมธอดสำหรับสร้าง HN ใหม่
  Future<String> _generateNewHN() async {
    // 1. หาปี พ.ศ. ปัจจุบัน (เช่น 2567 -> 67)
    final now = DateTime.now();
    final buddhistYear = now.year + 543;
    final yearPrefix = (buddhistYear % 100).toString().padLeft(2, '0');
    final hnPrefix = 'HN-$yearPrefix-';

    // 2. ค้นหา HN ล่าสุดของปีนี้
    final querySnapshot = await _patientsCollection
        .where('hn_number', isGreaterThanOrEqualTo: hnPrefix)
        .where('hn_number', isLessThan: 'HN-$yearPrefix-z') // ใช้ 'z' เพื่อสร้างช่วงการค้นหา
        .orderBy('hn_number', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (querySnapshot.docs.isNotEmpty) {
      // 3. ถ้าเจอ HN ของปีนี้, ให้เอาเลขลำดับสุดท้ายมาบวก 1
      final lastHn = querySnapshot.docs.first.get('hn_number') as String;
      final lastNumberStr = lastHn.split('-').last;
      final lastNumber = int.tryParse(lastNumberStr) ?? 0;
      nextNumber = lastNumber + 1;
    }

    // 4. จัดรูปแบบ HN ใหม่ให้สวยงาม (เช่น HN-67-0001)
    return '$hnPrefix${nextNumber.toString().padLeft(4, '0')}';
  }

  Future<void> updatePatient(Patient patient) async {
    try {
      await _patientsCollection.doc(patient.patientId).update(patient.toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการอัปเดตคนไข้: $e");
      rethrow;
    }
  }

  Future<void> deletePatient(String patientId) async {
    if (patientId.isEmpty) {
      throw ArgumentError("Patient ID cannot be empty.");
    }
    try {
      final patientDocRef = _patientsCollection.doc(patientId);
      await _medicalImageService.deleteAllPatientImages(patientId);
      await _deleteSubcollection(patientDocRef, 'treatments');
      await _deleteSubcollection(patientDocRef, 'medical_images');
      await patientDocRef.delete();
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการลบคนไข้และข้อมูลที่เกี่ยวข้อง: $e");
      rethrow;
    }
  }
  
  Future<void> _deleteSubcollection(DocumentReference docRef, String subcollectionName) async {
      final snapshot = await docRef.collection(subcollectionName).get();
      final futures = snapshot.docs.map((doc) => doc.reference.delete()).toList();
      await Future.wait(futures);
  }
}