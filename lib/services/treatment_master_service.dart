import 'package:flutter/foundation.dart';
// ----- FILE: lib/services/treatment_master.dart -----
// เวอร์ชัน 1.1: ✨ อัปเกรด Service จัดการเมนูหัตถการ
// ทำให้เมธอด addIfNotExist ฉลาดขึ้น สามารถคืนค่า ID กลับมาได้

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/treatment_master.dart';
import '../config/feature_flags.dart';
import '../config/clinic_context.dart';

class TreatmentMasterService {
  static CollectionReference<Map<String, dynamic>> _baseCollection({String? clinicIdOverride}) {
    final firestore = FirebaseFirestore.instance;
    final clinicId = clinicIdOverride ?? ClinicContext.activeClinicId;
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
      return firestore.collection('clinics').doc(clinicId).collection('treatment_master');
    }
    return firestore.collection('treatment_master').withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }

  static Stream<List<TreatmentMaster>> getAllTreatments({String? clinicIdOverride}) {
    return _baseCollection(clinicIdOverride: clinicIdOverride)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TreatmentMaster.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  static Future<void> addTreatment(TreatmentMaster treatment, {String? clinicIdOverride}) async {
    await _baseCollection(clinicIdOverride: clinicIdOverride).add(treatment.toMap());
  }

  static Future<void> updateTreatment(TreatmentMaster treatment, {String? clinicIdOverride}) async {
    await _baseCollection(clinicIdOverride: clinicIdOverride).doc(treatment.treatmentId).update(treatment.toMap());
  }

  static Future<void> deleteTreatment(String treatmentId, {String? clinicIdOverride}) async {
    await _baseCollection(clinicIdOverride: clinicIdOverride).doc(treatmentId).delete();
  }

  // 📌 ดึงข้อมูลหัตถการตามชื่อ เพื่อใช้เติมราคาอัตโนมัติ
  static Future<TreatmentMaster?> getTreatmentByName(String name, {String? clinicIdOverride}) async {
    final snapshot =
        await _baseCollection(clinicIdOverride: clinicIdOverride).where('name', isEqualTo: name).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TreatmentMaster.fromMap(doc.data(), doc.id);
  }

  // 🧵✨ [CHANGED v1.1] ปรับปรุงเมธอดนี้ให้คืนค่า ID ของ Master กลับมาด้วย
  // ไม่ว่าจะเป็น ID ของรายการที่มีอยู่แล้ว หรือ ID ของรายการที่เพิ่งสร้างใหม่
  static Future<String> addIfNotExist(String name, double price, {String? clinicIdOverride}) async {
    final col = _baseCollection(clinicIdOverride: clinicIdOverride);
    final snapshot = await col.where('name', isEqualTo: name).limit(1).get();

    if (snapshot.docs.isEmpty) {
      // ถ้าไม่มีอยู่ ให้สร้างใหม่
      final docRef = await col.add({
        'name': name,
        'price': price,
        'duration': 30, // ค่าเริ่มต้น
      });
      debugPrint('🆕 เพิ่มเข้า treatment_master: $name และได้ ID: ${docRef.id}');
      return docRef.id; // คืนค่า ID ของเอกสารที่สร้างใหม่
    } else {
      // ถ้ามีอยู่แล้ว
      final docId = snapshot.docs.first.id;
      debugPrint('✅ ชื่อหัตถการนี้มีอยู่แล้วใน master ด้วย ID: $docId');
      return docId; // คืนค่า ID ของเอกสารที่มีอยู่
    }
  }
}
