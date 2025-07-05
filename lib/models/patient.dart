// v1.0.2 - Final
// lib/models/patient.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String patientId;
  final String name;
  final String prefix;
  final String? hnNumber; // ✨ เพิ่ม hnNumber เข้ามาค่ะ
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
    this.hnNumber, // ✨ เพิ่ม hnNumber เข้ามาค่ะ
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
      'patientId': patientId,
      'name': name,
      'prefix': prefix,
      'hn_number': hnNumber, // ✨ เพิ่ม hn_number สำหรับ Firestore ค่ะ
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
    return Patient(
      // ✨ ทำให้การดึง ID ยืดหยุ่นขึ้นค่ะ
      patientId: map['patientId'] ?? map['docId'] ?? '', 
      name: map['name'] ?? '',
      prefix: map['prefix'] ?? '',
      hnNumber: map['hn_number'], // ✨ เพิ่มการดึง hn_number ค่ะ
      telephone: map['telephone'],
      address: map['address'],
      idCard: map['idCard'],
      // ✨ ทำให้การแปลงวันที่ยืดหยุ่นขึ้นค่ะ
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
