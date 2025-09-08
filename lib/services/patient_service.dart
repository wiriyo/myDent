// 💖 Updated by Laila — PatientService
// - เพิ่ม getPatientNameById() และ watchPatientById() เพื่อดึง/ติดตามชื่อสะดวกขึ้น
// - คง method ที่พี่มีไว้เดิมทั้งหมด และย้าย updatePatientRating() กลับเข้าบ้าน
// - เพิ่มคอมเมนต์และ log ให้ดีบักง่ายขึ้น

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import 'medical_image_service.dart';

class PatientService {
  static const String _collectionName = 'patients';
  final String? clinicId;
  PatientService({this.clinicId});
  final CollectionReference _patientsCollection =
      FirebaseFirestore.instance.collection(_collectionName);
  final MedicalImageService _medicalImageService = MedicalImageService();

  // ---------- Read ----------
  Future<List<Patient>> fetchPatientsOnce() async {
    try {
      Query query = _patientsCollection.orderBy('name');
      if (clinicId != null && clinicId!.isNotEmpty) {
        query = _patientsCollection.where('clinicId', isEqualTo: clinicId).orderBy('name');
      }
      final snapshot = await query.get();
      return snapshot.docs.map(_mapDocToPatient).toList();
    } catch (e) {
      debugPrint('❌ fetchPatientsOnce error: $e');
      return [];
    }
  }

  Future<Patient?> getPatientById(String patientId) async {
    if (patientId.isEmpty) return null;
    try {
      final doc = await _patientsCollection.doc(patientId).get();
      if (!doc.exists) return null;
      return _mapDocToPatient(doc);
    } catch (e) {
      debugPrint('❌ getPatientById($patientId) error: $e');
      return null;
    }
  }

  /// ดึงเฉพาะ "ชื่อ" สะดวกใช้ในฟอร์ม/ใบเสร็จ
  Future<String?> getPatientNameById(String patientId) async {
    final p = await getPatientById(patientId);
    final name = p?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  /// ติดตามข้อมูลคนไข้แบบเรียลไทม์ (สะดวกกับหน้าบัตรคนไข้)
  Stream<Patient?> watchPatientById(String patientId) {
    if (patientId.isEmpty) return const Stream.empty();
    return _patientsCollection.doc(patientId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _mapDocToPatient(doc);
    });
  }

  // ---------- Create ----------
  Future<void> addPatient(Patient patient) async {
    try {
      final newHnNumber = await _generateNewHN();

      final patientWithHn = Patient(
        patientId: '', // จะใส่ docId ตอนอ่านกลับด้วย _mapDocToPatient
        name: patient.name,
        prefix: patient.prefix,
        clinicId: clinicId ?? patient.clinicId,
        hnNumber: newHnNumber,
        telephone: patient.telephone,
        address: patient.address,
        idCard: patient.idCard,
        birthDate: patient.birthDate,
        medicalHistory: patient.medicalHistory,
        allergy: patient.allergy,
        rating: patient.rating, // double
        gender: patient.gender,
        age: patient.age,
      );

      await _patientsCollection.add(patientWithHn.toMap());
      debugPrint('✅ Added new patient with HN: $newHnNumber');
    } catch (e) {
      debugPrint('❌ addPatient error: $e');
      rethrow;
    }
  }

  Future<String> _generateNewHN() async {
    final now = DateTime.now();
    final buddhistYear = now.year + 543;
    final yearPrefix = (buddhistYear % 100).toString().padLeft(2, '0');
    final hnPrefix = 'HN-$yearPrefix-';

    // Use ascending order + startAt/endAt and limitToLast(1)
    // This typically uses composite index: clinicId Asc, hn_number Asc
    Query query = _patientsCollection.orderBy('hn_number')
        .startAt([hnPrefix])
        .endAt(['HN-$yearPrefix-\uf8ff']);
    if (clinicId != null && clinicId!.isNotEmpty) {
      query = _patientsCollection
          .where('clinicId', isEqualTo: clinicId)
          .orderBy('hn_number')
          .startAt([hnPrefix])
          .endAt(['HN-$yearPrefix-\uf8ff']);
    }
    final querySnapshot = await query.limitToLast(1).get();

    int nextNumber = 1;
    if (querySnapshot.docs.isNotEmpty) {
      final lastHn = querySnapshot.docs.first.get('hn_number') as String;
      final lastNumberStr = lastHn.split('-').last;
      final lastNumber = int.tryParse(lastNumberStr) ?? 0;
      nextNumber = lastNumber + 1;
    }
    return '$hnPrefix${nextNumber.toString().padLeft(4, '0')}';
  }

  // ---------- Update / Delete ----------
  Future<void> updatePatient(Patient patient) async {
    try {
      await _patientsCollection.doc(patient.patientId).update(patient.toMap());
    } catch (e) {
      debugPrint('❌ updatePatient error: $e');
      rethrow;
    }
  }

  Future<void> deletePatient(String patientId) async {
    if (patientId.isEmpty) {
      throw ArgumentError('Patient ID cannot be empty.');
    }
    try {
      final patientDocRef = _patientsCollection.doc(patientId);
      await _medicalImageService.deleteAllPatientImages(patientId);
      await _deleteSubcollection(patientDocRef, 'treatments');
      await _deleteSubcollection(patientDocRef, 'medical_images');
      await patientDocRef.delete();
    } catch (e) {
      debugPrint('❌ deletePatient error: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(
    DocumentReference docRef,
    String subcollectionName,
  ) async {
    final snapshot = await docRef.collection(subcollectionName).get();
    final futures = snapshot.docs.map((doc) => doc.reference.delete()).toList();
    await Future.wait(futures);
  }

  // ---------- Rating ----------
  Future<void> updatePatientRating(String patientId, double newRating) async {
    if (patientId.isEmpty) return;
    try {
      await _patientsCollection.doc(patientId).update({'rating': newRating});
      debugPrint('✅ Updated rating for patient $patientId to $newRating');
    } catch (e) {
      debugPrint('❌ updatePatientRating error: $e');
      rethrow;
    }
  }

  // ---------- Mapper ----------
  Patient _mapDocToPatient(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['docId'] = doc.id; // ฝัง docId เข้า model ด้วย
    return Patient.fromMap(data);
  }
}
