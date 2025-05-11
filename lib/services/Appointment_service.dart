import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addAppointment({
    required String patientId,
    required String treatment,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("ยังไม่ได้ล็อกอิน");

    final docRef = _firestore.collection('appointments').doc();
    await docRef.set({
      'appointmentId': docRef.id,
      'userId': userId,
      'patientId': patientId,
      'treatment': treatment,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'status': 'scheduled',
    });
  }

  /// ดึงข้อมูลนัดหมายจาก Firestore โดยใช้วันที่
  Future<List<Map<String, dynamic>>> getAppointmentsByDate(
    DateTime selectedDate,
  ) async {
    final formattedDate = selectedDate.toIso8601String().split('T').first;

    final snapshot =
        await _firestore
            .collection('appointments')
            .where('date', isEqualTo: formattedDate)
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// ดึงข้อมูลผู้ป่วยจาก Firestore โดยใช้ patientId
  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    final snapshot =
        await _firestore.collection('patients').doc(patientId).get();

    return snapshot.exists ? snapshot.data() : null;
  }

  Stream<List<Map<String, dynamic>>> getAppointmentsForCurrentUser() async* {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield [];
      return;
    }

    final snapshots =
        _firestore
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .snapshots();

    await for (final snapshot in snapshots) {
      final appointments = snapshot.docs.map((doc) => doc.data()).toList();

      // ดึง patientId ทุกอันออกมา
      final patientIds = appointments.map((a) => a['patientId']).toSet();

      // ดึงชื่อคนไข้ทั้งหมด
      final Map<String, String> patientNames = {};
      for (final pid in patientIds) {
        final patientSnapshot =
            await _firestore.collection('patients').doc(pid).get();
        if (patientSnapshot.exists) {
          final data = patientSnapshot.data();
          patientNames[pid] = data?['name'] ?? '';
        }
      }

      // รวมชื่อคนไข้เข้าไปในแต่ละ appointment
      final result =
          appointments.map((a) {
            return {...a, 'patientName': patientNames[a['patientId']] ?? ''};
          }).toList();

      yield result;
    }
  }
}
