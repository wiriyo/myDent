// v1.0.5 - Added Missing Import
// 📁 lib/services/appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart'; 
import '../models/patient.dart';
import '../services/patient_service.dart'; // ✨ The Fix! เพิ่ม import ที่ขาดไปค่ะ

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _appointmentsCollection = FirebaseFirestore.instance.collection('appointments');

  Future<void> addAppointment(AppointmentModel appointment) async {
    // ✨ The Fix! ไลลาได้บอกให้พี่ รปภ. ของเราใจดีขึ้นแล้วนะคะ
    // เราจะอนุญาตให้มีการนัดซ้อนได้ โดยการคอมเมนต์ส่วนที่เช็คเวลาออกไปก่อนค่ะ
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

  // ฟังก์ชันนี้เรายังเก็บไว้นะคะ เผื่ออนาคตอยากกลับมาใช้ค่ะ
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
        // ถ้ามีนัดเดียว และเป็นนัดของตัวเอง ก็ไม่ถือว่าซ้อนค่ะ
        if (querySnapshot.docs.length == 1 && querySnapshot.docs.first.id == excludeAppointmentId) {
          return false;
        }
      }
      
      // ถ้ามีนัดอื่นอยู่แล้ว ถือว่าซ้อนค่ะ
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
