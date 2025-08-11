import 'package:flutter/foundation.dart';
import './receipt_model.dart'; // reuse ClinicInfo / PatientInfo

@immutable
class AppointmentInfo {
  final DateTime startAt;
  final String? note;
  const AppointmentInfo({required this.startAt, this.note});
}

@immutable
class AppointmentSlipModel {
  final ClinicInfo clinic;
  final PatientInfo patient;
  final AppointmentInfo appointment;
  const AppointmentSlipModel({
    required this.clinic,
    required this.patient,
    required this.appointment,
  });
}
