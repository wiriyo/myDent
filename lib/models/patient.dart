// ----------------------------------------------------------------
// 📁 lib/models/patient.dart (v1.3.0)
// ✨ ไลลาเปลี่ยน rating จาก int เป็น double แล้วนะคะ
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String patientId;
  final String name;
  final String prefix;
  final String? clinicId; // multi-tenant support (flat)
  final String? hnNumber;
  final String? telephone;
  final String? address;
  final String? idCard;
  final DateTime? birthDate;
  final String? medicalHistory;
  final String? allergy;
  final double rating; // ✨ [UPDATED] เปลี่ยนเป็น double เพื่อรองรับทศนิยมค่ะ
  final String gender;
  final int? age;

  Patient({
    required this.patientId,
    required this.name,
    required this.prefix,
    this.clinicId,
    this.hnNumber,
    this.telephone,
    this.address = '',
    this.idCard = '',
    this.birthDate,
    this.medicalHistory = 'ปฏิเสธ',
    this.allergy = 'ปฏิเสธ',
    this.rating = 5.0, // ✨ [UPDATED] เปลี่ยนค่าเริ่มต้นเป็น double
    this.gender = 'หญิง',
    this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'name': name,
      'prefix': prefix,
      'hn_number': hnNumber,
      'telephone': telephone,
      'address': address,
      'idCard': idCard,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'medicalHistory': medicalHistory,
      'allergy': allergy,
      'rating': rating, // ✨ ตอนนี้ rating เป็น double แล้วค่ะ
      'gender': gender,
      'age': age,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    String id = '';
    if (map['docId'] != null && (map['docId'] as String).isNotEmpty) {
      id = map['docId'];
    } else if (map['patientId'] != null && (map['patientId'] as String).isNotEmpty) {
      id = map['patientId'];
    }

    return Patient(
      patientId: id,
      name: map['name'] ?? '',
      prefix: map['prefix'] ?? '',
      clinicId: map['clinicId'] as String?,
      hnNumber: map['hn_number'],
      telephone: map['telephone'],
      address: map['address'],
      idCard: map['idCard'],
      birthDate: map['birthDate'] is Timestamp
          ? (map['birthDate'] as Timestamp).toDate()
          : (map['birthDate'] is String ? DateTime.tryParse(map['birthDate']) : null),
      medicalHistory: map['medicalHistory'],
      allergy: map['allergy'],
      // ✨ [UPDATED] ทำให้รองรับทั้ง int และ double จาก Firestore เพื่อความเข้ากันได้กับข้อมูลเก่าค่ะ
      rating: (map['rating'] ?? 5.0).toDouble(),
      gender: map['gender'] ?? 'หญิง',
      age: map['age'],
    );
  }
}
