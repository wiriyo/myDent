// ----- FILE: lib/models/treatment.dart -----
// เวอร์ชัน 1.1: ✨ อัปเกรดพิมพ์เขียว "ใบเสร็จการรักษา"
// เพิ่มเส้นด้ายที่มองไม่เห็นเพื่อผูกกับเมนูหัตถการ

import 'package:cloud_firestore/cloud_firestore.dart';

class Treatment {
  final String id;
  final String patientId;
  // 🧵✨ [NEW v1.1] เพิ่ม treatmentMasterId เพื่อใช้เป็น Foreign Key
  // ที่เชื่อมไปยัง treatment_master collection ทำให้ข้อมูลสัมพันธ์กันอย่างแท้จริง
  final String treatmentMasterId;
  final String procedure; // ยังคงเก็บชื่อไว้เพื่อความสะดวกในการแสดงผล
  final String toothNumber;
  final double price;
  final DateTime date;

  Treatment({
    required this.id,
    required this.patientId,
    required this.treatmentMasterId, // 🧵✨ [NEW v1.1] เพิ่มใน constructor
    required this.procedure,
    required this.toothNumber,
    required this.price,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'treatmentMasterId': treatmentMasterId, // 🧵✨ [NEW v1.1] เพิ่มตอนแปลงเป็น Map
      'procedure': procedure,
      'toothNumber': toothNumber,
      'price': price,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Treatment.fromMap(Map<String, dynamic> map, String id) {
    return Treatment(
      id: id,
      patientId: map['patientId'] ?? '',
      // 🧵✨ [NEW v1.1] อ่านค่า treatmentMasterId จาก Firestore
      // ถ้าไม่มี ให้เป็นค่าว่างไปก่อน (สำหรับข้อมูลเก่า)
      treatmentMasterId: map['treatmentMasterId'] ?? '',
      procedure: map['procedure'] ?? '',
      toothNumber: map['toothNumber'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Treatment copyWith({
    String? id,
    String? patientId,
    String? treatmentMasterId, // 🧵✨ [NEW v1.1] เพิ่มใน copyWith
    String? procedure,
    String? toothNumber,
    double? price,
    DateTime? date,
  }) {
    return Treatment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      // 🧵✨ [NEW v1.1]
      treatmentMasterId: treatmentMasterId ?? this.treatmentMasterId,
      procedure: procedure ?? this.procedure,
      toothNumber: toothNumber ?? this.toothNumber,
      price: price ?? this.price,
      date: date ?? this.date,
    );
  }
}