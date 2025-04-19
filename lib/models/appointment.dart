// lib/models/appointment.dart
class Appointment {
  final String appointmentId;
  final String patientId;
  final DateTime date;
  final String time;
  final String treatment;
  final String status;

  Appointment({
    required this.appointmentId,
    required this.patientId,
    required this.date,
    required this.time,
    required this.treatment,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'date': date.toIso8601String(),
      'time': time,
      'treatment': treatment,
      'status': status,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      appointmentId: map['appointmentId'],
      patientId: map['patientId'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      treatment: map['treatment'],
      status: map['status'],
    );
  }
}