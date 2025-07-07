// ----------------------------------------------------------------
// 📁 lib/providers/patient_provider.dart
// (เวอร์ชันนี้ไม่ต้องแก้ไขอะไรเลยค่ะ เพราะ Logic ถูกย้ายไปที่ Service หมดแล้ว)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../services/prefix_service.dart';

class PatientProvider with ChangeNotifier {
  final PatientService _patientService = PatientService();
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
  }

  Future<bool> savePatient(Patient patient, bool isEditing) async {
    _setLoading(true);
    _setError(null);

    try {
      await PrefixService.addIfNotExist(patient.prefix);

      if (isEditing) {
        await _patientService.updatePatient(patient);
      } else {
        await _patientService.addPatient(patient);
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deletePatient(String patientId) async {
    _setLoading(true);
    _setError(null);

    try {
      // ✨ ตอนนี้เมธอดนี้ฉลาดขึ้นแล้วค่ะ!
      await _patientService.deletePatient(patientId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('เกิดข้อผิดพลาดในการลบข้อมูล: $e');
      _setLoading(false);
      return false;
    }
  }
}
