// v1.0.2
// 📁 lib/models/appointment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String? appointmentId; 
  final String userId; 
  final String patientId; 
  final String patientName; 
  final String treatment; 
  final int duration; 
  final String status; 
  final DateTime startTime; 
  final DateTime endTime; 
  final String? notes; 
  final List<String>? teeth; 

  AppointmentModel({
    this.appointmentId,
    required this.userId,
    required this.patientId,
    required this.patientName,
    required this.treatment,
    required this.duration,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.teeth,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Missing data for appointmentId: ${snapshot.id}');
    }
    // ✨ [FIX] เรียกใช้โรงงาน fromMap เพื่อลดโค้ดซ้ำซ้อนค่ะ
    return AppointmentModel.fromMap(snapshot.id, data);
  }

  // ✨ [FIX] เพิ่มโรงงาน fromMap เข้ามาใหม่ค่ะ! ✨
  // โรงงานนี้จะช่วยให้เราสร้าง Model จากข้อมูล Map ที่ไหนก็ได้เลยค่ะ
  factory AppointmentModel.fromMap(String id, Map<String, dynamic> data) {
     return AppointmentModel(
      appointmentId: id, 
      userId: data['userId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      treatment: data['treatment'] ?? '',
      duration: (data['duration'] as num?)?.toInt() ?? 30,
      status: data['status'] ?? 'รอยืนยัน',
      startTime: (data['startTime'] as Timestamp).toDate(), 
      endTime: (data['endTime'] as Timestamp).toDate(),
      notes: data['notes'],
      teeth: data['teeth'] != null ? List<String>.from(data['teeth']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'treatment': treatment,
      'duration': duration,
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'notes': notes,
      'teeth': teeth,
    };
  }
}
