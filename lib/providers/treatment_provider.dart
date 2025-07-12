// ================================================================
// 📁 4. lib/providers/treatment_provider.dart
// v1.2.0 - 🖼️ อัปเกรดให้รองรับการบันทึกรูปภาพ
// ================================================================
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