// v1.1.0 - Added getAppointmentById function
// 📁 lib/services/appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart'; 
import '../models/patient.dart';
import '../services/patient_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _appointmentsCollection = FirebaseFirestore.instance.collection('appointments');

  Future<void> addAppointment(AppointmentModel appointment) async {
    // if (await _isTimeSlotConflict(appointment.startTime, appointment.endTime)) {
    //   throw Exception("ช่วงเวลานี้มีการนัดหมายอื่นอยู่แล้ว");
    // }

    try {
      final docRef = _appointmentsCollection.doc();
      await docRef.set({
        ...appointment.toMap(), 
        'appointmentId': docRef.id, 
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error adding appointment: $e");
      rethrow;
    }
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    try {
      await _appointmentsCollection.doc(appointment.appointmentId).update({
        ...appointment.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating appointment: $e");
      rethrow;
    }
  }

  // ✨ [ADDED v1.1.0] เพิ่มฟังก์ชันสำหรับดึงข้อมูลนัดหมายฉบับเต็มจาก ID ค่ะ
  // ฟังก์ชันนี้จำเป็นสำหรับหน้าค้นหา เพื่อให้สามารถเปิดดูรายละเอียดนัดหมายได้ค่ะ
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final docSnapshot = await _appointmentsCollection.doc(appointmentId).get();
      if (docSnapshot.exists) {
        // ถ้าเจอเอกสาร ก็แปลงข้อมูลเป็น AppointmentModel แล้วส่งกลับไปค่ะ
        return AppointmentModel.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
      }
      // ถ้าไม่เจอ ก็ส่งค่า null กลับไปค่ะ
      return null;
    } catch (e) {
      debugPrint("Error fetching appointment by ID: $e");
      return null;
    }
  }

  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime selectedDate) async {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _appointmentsCollection
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching appointments by date: $e");
      return []; 
    }
  }

  Future<bool> _isTimeSlotConflict(DateTime startTime, DateTime endTime, [String? excludeAppointmentId]) async {
    try {
      final querySnapshot = await _appointmentsCollection
        .where('startTime', isLessThan: Timestamp.fromDate(endTime))
        .where('endTime', isGreaterThan: Timestamp.fromDate(startTime))
        .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      if (excludeAppointmentId != null) {
        if (querySnapshot.docs.length == 1 && querySnapshot.docs.first.id == excludeAppointmentId) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint("Error checking for time slot conflict: $e");
      return true; 
    }
  }

  Stream<List<AppointmentModel>> getAppointmentsStreamByDate(DateTime selectedDate) {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _appointmentsCollection
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
        });
  }

  Future<Patient?> getPatientById(String patientId) async {
    final PatientService patientService = PatientService();
    return await patientService.getPatientById(patientId);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _appointmentsCollection.doc(appointmentId).delete();
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการลบนัดหมาย: $e');
      rethrow;
    }
  }
}
