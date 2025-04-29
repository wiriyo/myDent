import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient.dart';

class PatientService {
  final CollectionReference patientsCollection =
      FirebaseFirestore.instance.collection('patients'); // 🌸 collection มาตรฐานเลยน้า

  // เพิ่มคนไข้ใหม่
  Future<void> addPatient(Patient patient) async {
    try {
      await patientsCollection.doc(patient.patientId).set(patient.toMap());
    } catch (e) {
      print('Error adding patient: $e');
      rethrow;
    }
  }

  // อัปเดตข้อมูลคนไข้ (รวมถึง rating ถ้ามี)
  Future<void> updatePatient(Patient patient) async {
    try {
      await patientsCollection.doc(patient.patientId).update(patient.toMap());
    } catch (e) {
      print('Error updating patient: $e');
      rethrow;
    }
  }

  // อัปเดตแค่ rating ของคนไข้
  Future<void> updateRating(String patientId, int rating) async {
    try {
      await patientsCollection.doc(patientId).update({
        'rating': rating,
      });
    } catch (e) {
      print('Error updating rating: $e');
      rethrow;
    }
  }

  // ลบคนไข้
  Future<void> deletePatient(String patientId) async {
    try {
      await patientsCollection.doc(patientId).delete();
    } catch (e) {
      print('Error deleting patient: $e');
      rethrow;
    }
  }

  // ดึงข้อมูลคนไข้ทั้งหมดแบบ real-time
  Stream<List<Patient>> getPatients() {
    return patientsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Patient.fromMap(data);
      }).toList();
    });
  }

    // ดึงข้อมูลคนไข้ทั้งหมดแบบครั้งเดียว (ใช้ .get())
Future<List<Patient>> fetchPatientsOnce() async {
  try {
    final snapshot = await patientsCollection.get();
    print('--- Loaded ${snapshot.docs.length} documents ---');
    for (var doc in snapshot.docs) {
      print('🔍 document: ${doc.id}, data: ${doc.data()}');
    }
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Patient.fromMap(data);
    }).toList();
  } catch (e) {
    print('Error fetching patients once: $e');
    rethrow;
  }
}


  // ดึงข้อมูลคนไข้คนเดียว (by patientId)
  Future<Patient?> getPatientById(String patientId) async {
    try {
      DocumentSnapshot doc = await patientsCollection.doc(patientId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Patient.fromMap(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting patient: $e');
      rethrow;
    }
  }
}
