// ----------------------------------------------------------------
// 📁 lib/providers/patient_provider.dart
// (เวอร์ชันนี้ไม่ต้องแก้ไขอะไรเลยค่ะ เพราะ Logic ถูกย้ายไปที่ Service หมดแล้ว)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../services/prefix_service.dart';

class PatientProvider with ChangeNotifier {
  final PatientService _patientService;
  PatientProvider({String? clinicId}) : _patientService = PatientService(clinicId: clinicId);
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

  Future<bool> deletePatient(String patientId, {String? clinicIdOverride}) async {
    _setLoading(true);
    _setError(null);

    try {
      final String? normalizedClinicId = clinicIdOverride != null && clinicIdOverride.trim().isNotEmpty
          ? clinicIdOverride.trim()
          : null;
      final PatientService service = normalizedClinicId != null
          ? PatientService(clinicId: normalizedClinicId)
          : _patientService;
      await service.deletePatient(patientId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('???????????????????????????: ');
      _setLoading(false);
      return false;
    }
  }


}
