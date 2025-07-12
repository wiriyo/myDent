// v1.3.0 - 🗑️ เพิ่มเมนูสำหรับลบรูปภาพเดี่ยวๆ ของการรักษา
// v1.2.0 - 🖼️ อัปเกรดให้รองรับการบันทึกรูปภาพ
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/treatment.dart';
import '../services/treatment_service.dart';
import '../services/treatment_master_service.dart';

class TreatmentProvider with ChangeNotifier {
  final TreatmentService _treatmentService = TreatmentService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
  }

  /// เมธอดสำหรับ "บันทึกการรักษา"
  Future<bool> saveTreatment({
    required String patientId,
    required Treatment treatment,
    bool isEditing = false,
    List<File>? images,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final masterId = await TreatmentMasterService.addIfNotExist(treatment.procedure, treatment.price);
      final treatmentToSave = treatment.copyWith(treatmentMasterId: masterId);

      if (isEditing) {
        await _treatmentService.updateTreatment(
          patientId,
          treatmentToSave,
          newImages: images,
        );
      } else {
        await _treatmentService.addTreatment(
          patientId,
          treatmentToSave,
          images: images,
        );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('🧑‍🍳❌ พ่อครัวทำพลาด: $e');
      _setError('เกิดข้อผิดพลาดในการบันทึกข้อมูลค่ะ: $e');
      _setLoading(false);
      return false;
    }
  }
  
  /// ✨ [NEW v1.3.0] เมนูใหม่สำหรับ "ลบรูปภาพของการรักษา"
  /// เมนูนี้จะรับคำสั่งมาจาก UI (เช่น ปุ่มกากบาทบน Thumbnail)
  Future<bool> deleteTreatmentImage({
    required String patientId,
    required String treatmentId,
    required String imageUrl,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      // เรียกใช้เครื่องมือลบรูปภาพที่ทรงพลังจาก Service ของเรา
      await _treatmentService.deleteTreatmentImage(
        patientId: patientId,
        treatmentId: treatmentId,
        imageUrl: imageUrl,
      );
      _setLoading(false);
      return true; // ลบสำเร็จ!
    } catch (e) {
      debugPrint('🧑‍🍳❌ พ่อครัวทำพลาดตอนลบรูปภาพ: $e');
      _setError('เกิดข้อผิดพลาดในการลบรูปภาพค่ะ: $e');
      _setLoading(false);
      return false; // ลบล้มเหลว
    }
  }


  /// เมธอดสำหรับ "ลบการรักษา" ทั้งก้อน
  Future<bool> deleteTreatment(String patientId, String treatmentId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _treatmentService.deleteTreatment(patientId, treatmentId);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('🧑‍🍳❌ พ่อครัวทำพลาดตอนลบ: $e');
      _setError('เกิดข้อผิดพลาดในการลบข้อมูลค่ะ: $e');
      _setLoading(false);
      return false;
    }
  }
}
