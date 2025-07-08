// ----------------------------------------------------------------
// 📁 lib/models/appointment_model.dart (UPGRADED)
// v1.2.0 - ✨ Add fromMap factory for backward compatibility
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String appointmentId;
  final String userId;
  final String patientId;
  final String patientName;
  final String? hnNumber;
  final String? patientPhone;
  final String treatment;
  final int duration;
  final String status;
  final DateTime startTime;
  final DateTime endTime;
  final String? notes;
  final List<String>? teeth;
  final List<String>? searchKeywords;

  AppointmentModel({
    required this.appointmentId,
    required this.userId,
    required this.patientId,
    required this.patientName,
    this.hnNumber,
    this.patientPhone,
    required this.treatment,
    required this.duration,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.teeth,
    this.searchKeywords,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'hn_number': hnNumber,
      'patientPhone': patientPhone,
      'treatment': treatment,
      'duration': duration,
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'notes': notes,
      'teeth': teeth,
      'searchKeywords': _createSearchKeywords(),
    };
  }

  List<String> _createSearchKeywords() {
    final Set<String> keywords = {};
    
    patientName.toLowerCase().split(' ').forEach((word) {
      if (word.isNotEmpty) keywords.add(word);
    });

    if (hnNumber != null && hnNumber!.isNotEmpty) {
      keywords.add(hnNumber!.toLowerCase());
    }

    if (patientPhone != null && patientPhone!.isNotEmpty) {
      keywords.add(patientPhone!);
    }
    
    return keywords.toList();
  }

  // ✨ [FIXED v1.2] ทำให้ fromFirestore เรียกใช้ fromMap เพื่อลดความซ้ำซ้อน
  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppointmentModel.fromMap(data, doc.id);
  }

  // ✨ [NEW v1.2] เพิ่ม fromMap factory กลับเข้ามา
  // เพื่อให้โค้ดส่วนอื่นๆ ที่ยังเรียกใช้อยู่ (เช่น weekly_calendar_screen) สามารถทำงานได้ตามปกติค่ะ
  factory AppointmentModel.fromMap(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      appointmentId: id,
      userId: data['userId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? 'N/A',
      hnNumber: data['hn_number'],
      patientPhone: data['patientPhone'],
      treatment: data['treatment'] ?? '',
      duration: (data['duration'] as num?)?.toInt() ?? 30,
      status: data['status'] ?? 'รอยืนยัน',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      notes: data['notes'],
      teeth: List<String>.from(data['teeth'] ?? []),
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
    );
  }
}
