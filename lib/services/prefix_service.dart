// v1.1.0 - ✨ Temporarily Disabled Auto-Add Functionality
// 📁 lib/services/prefix_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/prefix.dart';

class PrefixService {
  static final _collection = FirebaseFirestore.instance.collection('prefix_master');

  static Stream<List<Prefix>> getAllPrefixes() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Prefix.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ✨ [DISABLED v1.1.0] ไลลาได้ปิดการทำงานของฟังก์ชันนี้ชั่วคราวนะคะ
  // เพื่อให้แน่ใจว่าจะไม่มีการเพิ่ม Prefix ใหม่จากหน้าอื่น ๆ โดยไม่ตั้งใจ
  // เราจะกลับมาเปิดใช้งานอีกครั้งเมื่อทำหน้า Setting สำหรับจัดการ Prefix โดยเฉพาะค่ะ
  static Future<void> addIfNotExist(String name) async {
    // final snapshot = await _collection
    //     .where('name', isEqualTo: name)
    //     .limit(1)
    //     .get();

    // if (snapshot.docs.isEmpty) {
    //   await _collection.add({'name': name});
    //   print('🆕 เพิ่มคำนำหน้านามใหม่: $name');
    // } else {
    //   print('✅ คำนำหน้านามนี้มีอยู่แล้ว: $name');
    // }
    debugPrint('ℹ️ การเพิ่ม Prefix อัตโนมัติถูกปิดใช้งานชั่วคราวค่ะ');
    return; // ทำให้ฟังก์ชันนี้ไม่ทำงานอะไรเลย
  }
}
