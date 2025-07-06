// ----- FILE: lib/services/treatment.dart -----
// เวอร์ชัน 1.1: ไม่มีการเปลี่ยนแปลงในไฟล์นี้
// Service ของเราเขียนมาดีและยืดหยุ่นมากๆ อยู่แล้วค่ะ
// เมื่อ Model เปลี่ยนแปลง มันก็พร้อมทำงานกับข้อมูลใหม่ได้ทันทีเลย เก่งจัง!

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/treatment.dart';

class TreatmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTreatment(Treatment treatment) async {
    try {
      final docRef =
          _firestore
              .collection('patients')
              .doc(treatment.patientId)
              .collection('treatments')
              .doc(); // สร้าง ID ใหม่

      final newTreatment = treatment.copyWith(id: docRef.id);
      print(
        '📨 กำลังบันทึกที่ path: patients/${treatment.patientId}/treatments/${docRef.id}',
      );
      print('📦 ข้อมูล v1.1: ${newTreatment.toMap()}'); // ข้อมูลใหม่จะมี treatmentMasterId แล้ว
      await docRef.set(newTreatment.toMap());

      print('✅ บันทึก treatment สำเร็จสำหรับคนไข้ ${treatment.patientId}');
    } catch (e) {
      print('❌ เกิดข้อผิดพลาดในการบันทึก treatment: $e');
    }
  }

  Future<void> updateTreatment(Treatment treatment) async {
    await _firestore
        .collection('patients')
        .doc(treatment.patientId)
        .collection('treatments')
        .doc(treatment.id)
        .update(treatment.toMap());
  }

  Future<void> deleteTreatment(String patientId, String treatmentId) async {
    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('treatments')
        .doc(treatmentId)
        .delete();
  }

  Stream<List<Treatment>> getTreatments(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('treatments')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Treatment.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }
}