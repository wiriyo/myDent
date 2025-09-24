// ----------------------------------------------------------------
// 📁 lib/models/appointment_search_model.dart (‼️ NEW FILE)
// v1.0.0 - ✨ พิมพ์เขียวสำหรับแสดงผลการค้นหานัดหมาย
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentSearchModel {
  final String appointmentId;
  final String userId;
  final String patientId;
  final String patientName;
  final String? hnNumber;
  final String treatment;
  final int duration;
  final String status;
  final DateTime startTime;
  final DateTime endTime;
  final String? notes;
  final List<String>? teeth;
  final List<String>? searchKeywords;

  late final String normalizedPatientName = patientName.trim().toLowerCase();
  late final Set<String> normalizedNameTokens = normalizedPatientName
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toSet();
  late final Set<String> normalizedKeywordTokens = (searchKeywords ?? const <String>[])
      .map((keyword) => keyword.toLowerCase())
      .toSet();

  AppointmentSearchModel({
    required this.appointmentId,
    required this.userId,
    required this.patientId,
    required this.patientName,
    this.hnNumber,
    required this.treatment,
    required this.duration,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.teeth,
    this.searchKeywords,
  });

  factory AppointmentSearchModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppointmentSearchModel(
      appointmentId: doc.id,
      userId: data['userId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? 'N/A',
      hnNumber: data['hn_number'],
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