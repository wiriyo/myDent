// ----------------------------------------------------------------
// 📁 lib/providers/patient_provider.dart (‼️ NEW FILE)
// v1.2.0 - ✨ สร้างหัวหน้าเชฟคนใหม่สำหรับจัดการข้อมูลคนไข้
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

  // เมธอดสำหรับอัปเดตสถานะภายใน
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
  }

  // 🍳 เมนูหลักของเชฟ: "บันทึกหรืออัปเดตข้อมูลคนไข้"
  Future<bool> savePatient(Patient patient, bool isEditing) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. ตรวจสอบและเพิ่ม Prefix ใหม่ถ้ายังไม่มี
      await PrefixService.addIfNotExist(patient.prefix);

      // 2. เรียกใช้ Service เพื่อบันทึกข้อมูลลง Firestore
      if (isEditing) {
        await _patientService.updatePatient(patient);
      } else {
        await _patientService.addPatient(patient);
      }
      
      _setLoading(false);
      return true; // สำเร็จ!
    } catch (e) {
      _setError('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
      _setLoading(false);
      return false; // ล้มเหลว
    }
  }

  // 🍳 อีกเมนูของเชฟ: "ลบข้อมูลคนไข้"
  Future<bool> deletePatient(String patientId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _patientService.deletePatient(patientId);
      _setLoading(false);
      return true; // สำเร็จ!
    } catch (e) {
      _setError('เกิดข้อผิดพลาดในการลบข้อมูล: $e');
      _setLoading(false);
      return false; // ล้มเหลว
    }
  }
}