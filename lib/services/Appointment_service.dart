import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _appointmentsCollection = FirebaseFirestore.instance.collection('appointments');



  Future<void> addAppointment({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String treatment,
    required int duration,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String status = 'รอยืนยัน',
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("ยังไม่ได้ล็อกอิน");

    final docRef = _firestore.collection('appointments').doc();
    await docRef.set({
      'appointmentId': docRef.id,
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'treatment': treatment,
      'duration': duration,
      'status': status,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // เพิ่มการตรวจสอบว่ามีการนัดหมายซ้ำซ้อนหรือไม่
    if (await _isTimeSlotConflict(date, startTime, endTime)) {
        throw Exception("ช่วงเวลานี้มีการนัดหมายอื่นอยู่แล้ว");
    }

  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String treatment,
    required int duration,
    required String status,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("ยังไม่ได้ล็อกอิน");

    await _firestore.collection('appointments').doc(appointmentId).update({
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'treatment': treatment,
      'duration': duration,
      'status': status,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'updatedAt': FieldValue.serverTimestamp(),
    });
     // เพิ่มการตรวจสอบว่ามีการนัดหมายซ้ำซ้อนหรือไม่
    if (await _isTimeSlotConflict(date, startTime, endTime, appointmentId)) {
      throw Exception("ช่วงเวลานี้มีการนัดหมายอื่นอยู่แล้ว");
    }

  }

  Future<List<Map<String, dynamic>>> getAppointmentsByDate(
    DateTime selectedDate,
  ) async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('appointments')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['appointmentId'] = doc.id;
      return data;
    }).toList();
  }

   Future<bool> _isTimeSlotConflict(
    DateTime date,
    DateTime startTime,
    DateTime endTime, [
    String? excludeAppointmentId,
  ]) async {
    final appointments = await getAppointmentsByDate(date);

    for (final appointment in appointments) {
      if (appointment['appointmentId'] == excludeAppointmentId) continue; // Skip the appointment being updated

      final existingStart = (appointment['startTime'] as Timestamp).toDate();
      final existingEnd = (appointment['endTime'] as Timestamp).toDate();

      // Check for overlap:
      // (start1 < end2) && (end1 > start2)
      if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
        return true; // Conflict found
      }
      // Also check if the new appointment completely contains an existing one
      if (startTime.isBefore(existingStart) && endTime.isAfter(existingEnd)) {
        return true;
      }
    }

    return false; // No conflict
  }

  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    final snapshot = await _firestore.collection('patients').doc(patientId).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data()!;
    data['patientId'] = snapshot.id;
    return data;
  }

  Stream<List<Map<String, dynamic>>> getAppointmentsForCurrentUser() async* {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield [];
      return;
    }

    final snapshots = _firestore
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .snapshots();

    await for (final snapshot in snapshots) {
      final appointments = snapshot.docs.map((doc) => doc.data()).toList();
      final patientIds = appointments.map((a) => a['patientId']).toSet();

      final Map<String, String> patientNames = {};
      for (final pid in patientIds) {
        final patientSnapshot = await _firestore.collection('patients').doc(pid).get();
        if (patientSnapshot.exists) {
          final data = patientSnapshot.data();
          patientNames[pid] = data?['name'] ?? '';
        }
      }

      final result = appointments.map((a) {
        return {
          ...a,
          'patientName': patientNames[a['patientId']] ?? '',
        };
      }).toList();

      yield result;
    }
  }

  // ฟังก์ชันสำหรับลบนัดหมายตาม ID ที่ส่งเข้ามาค่ะ
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _appointmentsCollection.doc(appointmentId).delete();
    } catch (e) {
      // เผื่อว่าเกิดข้อผิดพลาด เราจะได้รู้ค่ะ
      print('เกิดข้อผิดพลาดในการลบนัดหมาย: $e');
      rethrow; // ส่งต่อ error ให้ที่เรียกใช้จัดการต่อได้
    }
  }

  /// ฟังก์ชันสำหรับอัปเดตสถานะของนัดหมายค่ะ
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _appointmentsCollection.doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(), // อัปเดตเวลาล่าสุดด้วยเลยค่ะ
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e');
      rethrow;
    }
  }
  
}

