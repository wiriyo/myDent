// v1.1.0 - Complete & Stable
// 📁 lib/services/patient_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart'; // ✨ Import พิมพ์เขียว Patient ของเราค่ะ

class PatientService {
  final CollectionReference _patientsCollection = FirebaseFirestore.instance.collection('patients');

  // --- ✨ [อ่านข้อมูล] ดึงข้อมูลคนไข้ทั้งหมด (สำหรับ Autocomplete) ---
  /// ดึงข้อมูลคนไข้ทั้งหมดจาก Firestore แค่ครั้งเดียว
  /// เหมาะสำหรับใช้ในหน้าเพิ่มนัดหมายเพื่อทำ Autocomplete ค่ะ
  Future<List<Patient>> fetchPatientsOnce() async {
    try {
      final snapshot = await _patientsCollection.orderBy('name').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // เพิ่ม docId เข้าไปใน Map ก่อนส่งไปสร้าง Model ค่ะ
        data['docId'] = doc.id;
        return Patient.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการดึงข้อมูลคนไข้: $e");
      return [];
    }
  }

  // --- ✨ [อ่านข้อมูล] ดึงข้อมูลคนไข้คนเดียวด้วย ID ---
  /// ดึงข้อมูลคนไข้คนเดียวแบบเจาะจงด้วย patientId ค่ะ
  /// เหมาะสำหรับใช้ในหน้ารายละเอียดคนไข้
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
  
  // --- ✨ [อ่านข้อมูล] ดึงข้อมูลคนไข้ทั้งหมด (แบบ Real-time) ---
  /// ดึงข้อมูลคนไข้ทั้งหมดแบบ Real-time ค่ะ
  /// เหมาะสำหรับใช้ในหน้ารายชื่อคนไข้ (PatientsScreen)
  Stream<List<Patient>> getPatientsStream() {
    return _patientsCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        return Patient.fromMap(data);
      }).toList();
    });
  }

  // --- ✨ [สร้างข้อมูล] เพิ่มคนไข้ใหม่ ---
  Future<void> addPatient(Patient patient) async {
    try {
      await _patientsCollection.add(patient.toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการเพิ่มคนไข้: $e");
      rethrow;
    }
  }

  // --- ✨ [อัปเดตข้อมูล] แก้ไขข้อมูลคนไข้ ---
  Future<void> updatePatient(Patient patient) async {
    try {
      await _patientsCollection.doc(patient.patientId).update(patient.toMap());
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการอัปเดตคนไข้: $e");
      rethrow;
    }
  }

  // --- ✨ [ลบข้อมูล] ลบคนไข้ ---
  Future<void> deletePatient(String patientId) async {
    try {
      await _patientsCollection.doc(patientId).delete();
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการลบคนไข้: $e");
      rethrow;
    }
  }
}