// ----- FILE: lib/services/treatment_master.dart -----
// เวอร์ชัน 1.1: ✨ อัปเกรด Service จัดการเมนูหัตถการ
// ทำให้เมธอด addIfNotExist ฉลาดขึ้น สามารถคืนค่า ID กลับมาได้

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/treatment_master.dart';

class TreatmentMasterService {
  static final _collection = FirebaseFirestore.instance.collection(
    'treatment_master',
  );

  static Stream<List<TreatmentMaster>> getAllTreatments() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TreatmentMaster.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  static Future<void> addTreatment(TreatmentMaster treatment) async {
    await _collection.add(treatment.toMap());
  }

  static Future<void> updateTreatment(TreatmentMaster treatment) async {
    await _collection.doc(treatment.treatmentId).update(treatment.toMap());
  }

  static Future<void> deleteTreatment(String treatmentId) async {
    await _collection.doc(treatmentId).delete();
  }

  // 📌 ดึงข้อมูลหัตถการตามชื่อ เพื่อใช้เติมราคาอัตโนมัติ
  static Future<TreatmentMaster?> getTreatmentByName(String name) async {
    final snapshot =
        await _collection.where('name', isEqualTo: name).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TreatmentMaster.fromMap(doc.data(), doc.id);
  }

  // 🧵✨ [CHANGED v1.1] ปรับปรุงเมธอดนี้ให้คืนค่า ID ของ Master กลับมาด้วย
  // ไม่ว่าจะเป็น ID ของรายการที่มีอยู่แล้ว หรือ ID ของรายการที่เพิ่งสร้างใหม่
  static Future<String> addIfNotExist(String name, double price) async {
    final snapshot =
        await _collection.where('name', isEqualTo: name).limit(1).get();

    if (snapshot.docs.isEmpty) {
      // ถ้าไม่มีอยู่ ให้สร้างใหม่
      final docRef = await _collection.add({
        'name': name,
        'price': price,
        'duration': 30, // ค่าเริ่มต้น
      });
      print('🆕 เพิ่มเข้า treatment_master: $name และได้ ID: ${docRef.id}');
      return docRef.id; // คืนค่า ID ของเอกสารที่สร้างใหม่
    } else {
      // ถ้ามีอยู่แล้ว
      final docId = snapshot.docs.first.id;
      print('✅ ชื่อหัตถการนี้มีอยู่แล้วใน master ด้วย ID: $docId');
      return docId; // คืนค่า ID ของเอกสารที่มีอยู่
    }
  }
}