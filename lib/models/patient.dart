// lib/models/patient.dart
class Patient {
  final String patientId;
  final String name;
  final String telephone;
  final DateTime birthDate;
  final String medicalHistory;
  final String allergy;

  Patient({
    required this.patientId,
    required this.name,
    required this.telephone,
    required this.birthDate,
    required this.medicalHistory,
    required this.allergy,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'name': name,
      'telephone': telephone,
      'birthDate': birthDate.toIso8601String(),
      'medicalHistory': medicalHistory,
      'allergy': allergy,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patientId'],
      name: map['name'],
      telephone: map['telephone'],
      birthDate: DateTime.parse(map['birthDate']),
      medicalHistory: map['medicalHistory'],
      allergy: map['allergy'],
    );
  }
}