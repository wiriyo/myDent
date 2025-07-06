// ----- ‼️ NEW FILE: lib/providers/treatment_provider.dart -----
// เวอร์ชัน 1.2: 🧑‍🍳✨ สร้างพ่อครัวมืออาชีพคนใหม่!
// พ่อครัวคนนี้จะรับผิดชอบ Logic การบันทึกและลบข้อมูลทั้งหมด

import 'package:flutter/material.dart';
import '../models/treatment.dart';
import '../services/treatment_service.dart';
import '../services/treatment_master_service.dart';

class TreatmentProvider with ChangeNotifier {
  // พ่อครัวของเราต้องมีผู้ช่วยคือ Service ที่เราสร้างไว้ค่ะ
  final TreatmentService _treatmentService = TreatmentService();

  // สถานะการทำงานของพ่อครัว (กำลังทำอาหารอยู่รึเปล่า)
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // หากทำอาหารพลาด จะได้รู้ว่าพลาดเพราะอะไร
  String? _error;
  String? get error => _error;

  // เมธอดสำหรับอัปเดตสถานะภายใน (สำหรับใช้ในคลาสนี้เท่านั้น)
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners(); // แจ้งเตือน "พนักงานเสิร์ฟ" (UI) ว่าสถานะเปลี่ยนไปแล้วนะ!
  }

  // เมธอดสำหรับบันทึกข้อผิดพลาด
  void _setError(String? message) {
    _error = message;
  }

  // 🍳 นี่คือเมนูหลักของพ่อครัว: "บันทึกหรืออัปเดตการรักษา"
  // รับออเดอร์ (ข้อมูล) มาจากพนักงานเสิร์ฟ (UI)
  Future<bool> saveOrUpdateTreatment({
    required String patientId,
    String? treatmentId,
    String? selectedTreatmentMasterId,
    required String procedure,
    required String toothNumber,
    required double price,
    required DateTime date,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. พ่อครัวจะเช็คก่อนว่า "หัตถการ" นี้มีในเมนูหลัก (Master) หรือยัง
      // ถ้ายังไม่มี ก็จะเพิ่มให้โดยอัตโนมัติ แล้วเอา ID กลับมา
      final masterId = await TreatmentMasterService.addIfNotExist(procedure, price);

      // 2. เตรียมข้อมูลทั้งหมดเพื่อปรุงอาหาร (สร้าง Treatment object)
      final treatmentData = Treatment(
        id: treatmentId ?? '', // ถ้าเป็นการสร้างใหม่ ID จะยังเป็นค่าว่าง
        patientId: patientId,
        // ถ้าผู้ใช้เลือกจากรายการที่มีอยู่แล้ว ให้ใช้ ID นั้น, แต่ถ้าพิมพ์ใหม่ ให้ใช้ ID ที่เพิ่งสร้าง/หาเจอ
        treatmentMasterId: (selectedTreatmentMasterId != null && selectedTreatmentMasterId.isNotEmpty)
            ? selectedTreatmentMasterId
            : masterId,
        procedure: procedure,
        toothNumber: toothNumber,
        price: price,
        date: date,
      );

      // 3. ส่งอาหารไปเสิร์ฟ (บันทึกข้อมูลลง Firestore)
      if (treatmentId == null || treatmentId.isEmpty) {
        await _treatmentService.addTreatment(treatmentData);
      } else {
        await _treatmentService.updateTreatment(treatmentData);
      }

      _setLoading(false);
      return true; // ทำอาหารสำเร็จ!
    } catch (e) {
      print('🧑‍🍳❌ พ่อครัวทำพลาด: $e');
      _setError('เกิดข้อผิดพลาดในการบันทึกข้อมูลค่ะ: $e');
      _setLoading(false);
      return false; // ทำอาหารล้มเหลว
    }
  }

  // 🍳 อีกเมนูของพ่อครัว: "ลบการรักษา"
  Future<bool> deleteTreatment(String patientId, String treatmentId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _treatmentService.deleteTreatment(patientId, treatmentId);
      _setLoading(false);
      return true; // ลบสำเร็จ
    } catch (e) {
      print('🧑‍🍳❌ พ่อครัวทำพลาดตอนลบ: $e');
      _setError('เกิดข้อผิดพลาดในการลบข้อมูลค่ะ: $e');
      _setLoading(false);
      return false; // ลบล้มเหลว
    }
  }
}