// lib/models/patient.dart
class Patient {
  final String patientId;
  final String name;
  final String telephone;
  final DateTime? birthDate;
  final String medicalHistory;
  final String allergy;
  final int? rating;
  final String gender;
  final int? age;

  Patient({
    required this.patientId,
    required this.name,
    required this.telephone,
    this.birthDate,
    this.medicalHistory = 'ปฏิเสธ',
    this.allergy = 'ปฏิเสธ',
    this.rating,
    this.gender = 'หญิง',
    this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'name': name,
      'telephone': telephone,
      'birthDate': birthDate?.toIso8601String(),
      'medicalHistory': medicalHistory,
      'allergy': allergy,
      'rating': rating,
      'gender': gender,
      'age': age,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patientId'] ?? '',
      name: map['name'] ?? '',
      telephone: map['telephone'] ?? '',
      birthDate: map['birthDate'] != null ? DateTime.tryParse(map['birthDate']) : null,
      medicalHistory: map['medicalHistory'] ?? 'ปฏิเสธ',
      allergy: map['allergy'] ?? 'ปฏิเสธ',
      rating: map['rating'],
      gender: map['gender'] ?? 'หญิง',
      age: map['age'],
    );
  }
}
