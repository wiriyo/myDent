// 💖 สวัสดีค่ะพี่ทะเล ไลลาแก้ไขไฟล์นี้ให้แล้วนะคะ
// โดยการย้ายฟังก์ชัน updatePatientRating กลับเข้าไปอยู่ในบ้าน PatientService ค่ะ 😊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import 'medical_image_service.dart';

class PatientService {
  final CollectionReference _patientsCollection = FirebaseFirestore.instance.collection('patients');
  final MedicalImageService _medicalImageService = MedicalImageService();

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

  Future<void> addPatient(Patient patient) async {
    try {
      final newHnNumber = await _generateNewHN();
      
      final patientWithHn = Patient(
        patientId: '',
        name: patient.name,
        prefix: patient.prefix,
        hnNumber: newHnNumber,
        telephone: patient.telephone,
        address: patient.address,
        idCard: patient.idCard,
        birthDate: patient.birthDate,
        medicalHistory: patient.medicalHistory,
        allergy: patient.allergy,
        rating: patient.rating, // ✨ ตอนนี้เป็น double แล้ว
        gender: patient.gender,
        age: patient.age,
      );
      await _patientsCollection.add(patientWithHn.toMap());
      debugPrint("✅ Added new patient with HN: $newHnNumber");
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการเพิ่มคนไข้: $e");
      rethrow;
    }
  }

  Future<String> _generateNewHN() async {
    final now = DateTime.now();
    final buddhistYear = now.year + 543;
    final yearPrefix = (buddhistYear % 100).toString().padLeft(2, '0');
    final hnPrefix = 'HN-$yearPrefix-';

    final querySnapshot = await _patientsCollection
        .where('hn_number', isGreaterThanOrEqualTo: hnPrefix)
        .where('hn_number', isLessThan: 'HN-$yearPrefix-z')
        .orderBy('hn_number', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (querySnapshot.docs.isNotEmpty) {
      final lastHn = querySnapshot.docs.first.get('hn_number') as String;
      final lastNumberStr = lastHn.split('-').last;
      final lastNumber = int.tryParse(lastNumberStr) ?? 0;
      nextNumber = lastNumber + 1;
    }
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

  // ✨ [FIXED] ย้ายเข้ามาอยู่ในบ้าน PatientService แล้วนะคะ!
  Future<void> updatePatientRating(String patientId, double newRating) async {
    if (patientId.isEmpty) return;
    try {
      await _patientsCollection.doc(patientId).update({'rating': newRating});
      debugPrint("✅ Updated rating for patient $patientId to $newRating");
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการอัปเดตคะแนนคนไข้: $e");
      rethrow;
    }
  }
}