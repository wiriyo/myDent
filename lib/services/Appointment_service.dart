// lib/services/appointment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

class AppointmentService {
  final CollectionReference _appointments =
      FirebaseFirestore.instance.collection('appointments');
  final CollectionReference _patients =
      FirebaseFirestore.instance.collection('patients');

  // ดึงนัดหมายตามวันที่
  Stream<List<Appointment>> getAppointmentsByDate(DateTime selectedDate) {
    DateTime startOfDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    DateTime endOfDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    return _appointments
        .where('date',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
            isLessThanOrEqualTo: endOfDay.toIso8601String())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // ดึงข้อมูลคนไข้จาก patientId
  Future<Patient> getPatientById(String patientId) async {
    DocumentSnapshot doc = await _patients.doc(patientId).get();
    return Patient.fromMap(doc.data() as Map<String, dynamic>);
  }
}