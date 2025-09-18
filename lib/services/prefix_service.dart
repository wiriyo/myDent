// v1.1.0 - ✨ Temporarily Disabled Auto-Add Functionality
// 📁 lib/services/prefix_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/prefix.dart';
import '../config/feature_flags.dart';
import '../config/clinic_context.dart';

class PrefixService {
  static CollectionReference<Map<String, dynamic>> _baseCollection({
    String? clinicIdOverride,
  }) {
    final firestore = FirebaseFirestore.instance;
    final clinicId = clinicIdOverride ?? ClinicContext.activeClinicId;
    if (FeatureFlags.useNestedCollections &&
        clinicId != null &&
        clinicId.isNotEmpty) {
      return firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('prefix_master');
    }
    return firestore
        .collection('prefix_master')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );
  }

  static Stream<List<Prefix>> getAllPrefixes({String? clinicIdOverride}) {
    return _baseCollection(clinicIdOverride: clinicIdOverride).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => Prefix.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ✨ [DISABLED v1.1.0] ไลลาได้ปิดการทำงานของฟังก์ชันนี้ชั่วคราวนะคะ
  // เพื่อให้แน่ใจว่าจะไม่มีการเพิ่ม Prefix ใหม่จากหน้าอื่น ๆ โดยไม่ตั้งใจ
  // เราจะกลับมาเปิดใช้งานอีกครั้งเมื่อทำหน้า Setting สำหรับจัดการ Prefix โดยเฉพาะค่ะ
  static Future<void> addIfNotExist(
    String name, {
    String? clinicIdOverride,
  }) async {
    // final snapshot = await _collection
    //     .where('name', isEqualTo: name)
    //     .limit(1)
    //     .get();

    // if (snapshot.docs.isEmpty) {
    //   await _collection.add({'name': name});
    //   print('dY+ คำนำหน้านามใหม่: $name');
    // } else {
    //   print('⚠️ คำนำหน้านามนี้มีอยู่แล้ว: $name');
    // }
    debugPrint('ℹ️ การเพิ่ม Prefix อัตโนมัติถูกปิดใช้งานชั่วคราวค่ะ');
    return; // ทำให้ฟังก์ชันนี้ไม่ทำงานอะไรเลย
  }

  // --- Explicit CRUD for Settings UI ---
  static Future<void> addPrefix(String name, {String? clinicIdOverride}) async {
    final col = _baseCollection(clinicIdOverride: clinicIdOverride);
    await col.add({'name': name.trim()});
  }

  static Future<void> updatePrefix(
    String id,
    String name, {
    String? clinicIdOverride,
  }) async {
    final col = _baseCollection(clinicIdOverride: clinicIdOverride);
    await col.doc(id).update({'name': name.trim()});
  }

  static Future<void> deletePrefix(
    String id, {
    String? clinicIdOverride,
  }) async {
    final col = _baseCollection(clinicIdOverride: clinicIdOverride);
    await col.doc(id).delete();
  }
}
