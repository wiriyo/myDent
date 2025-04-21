import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ดึงข้อมูลนัดหมายจาก Firestore โดยใช้วันที่
  Future<List<Map<String, dynamic>>> getAppointmentsByDate(
    DateTime selectedDate,
  ) async {
    final formattedDate = selectedDate.toIso8601String().split('T').first;

    final snapshot = await _firestore
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

  /// ดึงนัดหมายทั้งหมดของ user ที่ล็อกอิน
  Stream<List<Map<String, dynamic>>> getAppointmentsForCurrentUser() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
