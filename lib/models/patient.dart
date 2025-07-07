// ----------------------------------------------------------------
// 📁 lib/models/patient.dart
// v1.2.0 - ✨ Robust fromMap Factory
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String patientId;
  final String name;
  final String prefix;
  final String? hnNumber;
  final String? telephone;
  final String? address;
  final String? idCard;
  final DateTime? birthDate;
  final String? medicalHistory;
  final String? allergy;
  final int rating;
  final String gender;
  final int? age;

  Patient({
    required this.patientId,
    required this.name,
    required this.prefix,
    this.hnNumber,
    this.telephone,
    this.address = '',
    this.idCard = '',
    this.birthDate,
    this.medicalHistory = 'ปฏิเสธ',
    this.allergy = 'ปฏิเสธ',
    this.rating = 3,
    this.gender = 'หญิง',
    this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'prefix': prefix,
      'hn_number': hnNumber,
      'telephone': telephone,
      'address': address,
      'idCard': idCard,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'medicalHistory': medicalHistory,
      'allergy': allergy,
      'rating': rating,
      'gender': gender,
      'age': age,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    // ✨ [FIXED v1.2] ทำให้การดึง ID แข็งแรงและฉลาดขึ้น
    // เพื่อจัดการกับข้อมูลเก่าที่อาจมี field 'patientId' ที่เป็นค่าว่างบันทึกอยู่
    String id = '';
    
    // 1. ให้ความสำคัญกับ docId ที่ส่งมาจาก Service ก่อนเสมอ เพราะนี่คือ ID ที่แท้จริง
    if (map['docId'] != null && (map['docId'] as String).isNotEmpty) {
      id = map['docId'];
    } 
    // 2. ถ้าไม่มี docId (อาจเป็นกรณีเก่ามากๆ) ให้ลองหาจาก patientId แต่ต้องไม่ใช่ค่าว่าง
    else if (map['patientId'] != null && (map['patientId'] as String).isNotEmpty) {
      id = map['patientId'];
    }

    return Patient(
      patientId: id, 
      name: map['name'] ?? '',
      prefix: map['prefix'] ?? '',
      hnNumber: map['hn_number'],
      telephone: map['telephone'],
      address: map['address'],
      idCard: map['idCard'],
      birthDate: map['birthDate'] is Timestamp 
                 ? (map['birthDate'] as Timestamp).toDate()
                 : (map['birthDate'] is String ? DateTime.tryParse(map['birthDate']) : null),
      medicalHistory: map['medicalHistory'],
      allergy: map['allergy'],
      rating: map['rating'] ?? 3,
      gender: map['gender'] ?? 'หญิง',
      age: map['age'],
    );
  }
}