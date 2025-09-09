// 💖 Updated by Laila — PatientService
// - เพิ่ม getPatientNameById() และ watchPatientById() เพื่อดึง/ติดตามชื่อสะดวกขึ้น
// - คง method ที่พี่มีไว้เดิมทั้งหมด และย้าย updatePatientRating() กลับเข้าบ้าน
// - เพิ่มคอมเมนต์และ log ให้ดีบักง่ายขึ้น

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import 'medical_image_service.dart';
import '../config/feature_flags.dart';

class PatientService {
  static const String _collectionName = 'patients';
  final String? clinicId;
  PatientService({this.clinicId});
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rootPatients =
      FirebaseFirestore.instance.collection(_collectionName);
  final MedicalImageService _medicalImageService = MedicalImageService();

  CollectionReference<Map<String, dynamic>> get _primaryPatients {
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection(_collectionName);
    }
    return _rootPatients.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }

  CollectionReference<Map<String, dynamic>>? get _nestedPatientsOrNull {
    if (clinicId != null && clinicId!.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection(_collectionName);
    }
    return null;
  }

  // ---------- Read ----------
  Future<List<Patient>> fetchPatientsOnce() async {
    try {
      Query query = _primaryPatients.orderBy('name');
      if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty)) {
        if (clinicId != null && clinicId!.isNotEmpty) {
          query = _rootPatients.where('clinicId', isEqualTo: clinicId).orderBy('name');
        }
      }
      var snapshot = await query.get();

      if (FeatureFlags.dualReadFallbackEnabled && snapshot.docs.isEmpty) {
        final fbQuery = _rootPatients.where('clinicId', isEqualTo: clinicId).orderBy('name');
        snapshot = await fbQuery.get();
      }
      return snapshot.docs.map(_mapDocToPatient).toList();
    } catch (e) {
      debugPrint('❌ fetchPatientsOnce error: $e');
      return [];
    }
  }

  Future<Patient?> getPatientById(String patientId) async {
    if (patientId.isEmpty) return null;
    try {
      final primary = await _primaryPatients.doc(patientId).get();
      if (primary.exists) return _mapDocToPatient(primary);
      if (FeatureFlags.dualReadFallbackEnabled) {
        final legacy = await _rootPatients.doc(patientId).get();
        if (legacy.exists) return _mapDocToPatient(legacy);
      }
      return null;
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
    return _primaryPatients.doc(patientId).snapshots().map((doc) {
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

      // Generate a single docId for dual-write consistency
      final primaryRef = _primaryPatients;
      final docRef = primaryRef.doc();
      final map = patientWithHn.toMap();
      final futures = <Future>[];
      futures.add(docRef.set(map));
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootPatients.doc(docRef.id).set(map));
        final nested = _nestedPatientsOrNull;
        if (nested != null) futures.add(nested.doc(docRef.id).set(map));
      }
      await Future.wait(futures);
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
    Query query = _primaryPatients.orderBy('hn_number')
        .startAt([hnPrefix])
        .endAt(['HN-$yearPrefix-\uf8ff']);
    if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty)) {
      if (clinicId != null && clinicId!.isNotEmpty) {
        query = _rootPatients
            .where('clinicId', isEqualTo: clinicId)
            .orderBy('hn_number')
            .startAt([hnPrefix])
            .endAt(['HN-$yearPrefix-\uf8ff']);
      }
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
      final futures = <Future>[];
      futures.add(_primaryPatients.doc(patient.patientId).update(patient.toMap()));
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootPatients.doc(patient.patientId).update(patient.toMap()));
        final nested = _nestedPatientsOrNull;
        if (nested != null) futures.add(nested.doc(patient.patientId).update(patient.toMap()));
      }
      await Future.wait(futures);
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
      final primaryRef = _primaryPatients.doc(patientId);
      await _medicalImageService.deleteAllPatientImages(patientId);
      await _deleteSubcollection(primaryRef, 'treatments');
      await _deleteSubcollection(primaryRef, 'medical_images');

      final futures = <Future>[];
      futures.add(primaryRef.delete());
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootPatients.doc(patientId).delete());
        final nested = _nestedPatientsOrNull;
        if (nested != null) futures.add(nested.doc(patientId).delete());
      }
      await Future.wait(futures);
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
      final futures = <Future>[];
      futures.add(_primaryPatients.doc(patientId).update({'rating': newRating}));
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootPatients.doc(patientId).update({'rating': newRating}));
        final nested = _nestedPatientsOrNull;
        if (nested != null) futures.add(nested.doc(patientId).update({'rating': newRating}));
      }
      await Future.wait(futures);
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
