// v1.3.0 - 📝 อัปเกรดให้รองรับการจัดการ Treatment Notes
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

  /// [UPGRADED v1.3.0] เมธอดสำหรับ "บันทึกการรักษา"
  /// ตอนนี้จะรับ Treatment object ทั้งก้อน ซึ่งมีข้อมูล notes อยู่ข้างในแล้ว
  /// และยังรองรับการแนบไฟล์รูปภาพ (images) ไปพร้อมกันด้วย
  Future<bool> saveTreatment({
    required String patientId,
    required Treatment treatment,
    bool isEditing = false,
    List<File>? images,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. เช็คและเพิ่มหัตถการลงใน Master Data (ถ้ายังไม่มี)
      final masterId = await TreatmentMasterService.addIfNotExist(treatment.procedure, treatment.price);
      
      // 2. สร้าง object การรักษาใหม่พร้อมกับ Master ID ที่ถูกต้อง
      // ข้อมูล notes ที่มาจากฟอร์มจะอยู่ใน treatment object นี้เรียบร้อยแล้ว
      final treatmentToSave = treatment.copyWith(treatmentMasterId: masterId);

      // 3. เรียกใช้ Service ให้จัดการบันทึกข้อมูล
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
      return true; // สำเร็จ!
    } catch (e) {
      debugPrint('🧑‍🍳❌ พ่อครัวทำพลาด: $e');
      _setError('เกิดข้อผิดพลาดในการบันทึกข้อมูลค่ะ: $e');
      _setLoading(false);
      return false; // ล้มเหลว
    }
  }
  
  /// เมนูสำหรับ "ลบรูปภาพของการรักษา"
  Future<bool> deleteTreatmentImage({
    required String patientId,
    required String treatmentId,
    required String imageUrl,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
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
