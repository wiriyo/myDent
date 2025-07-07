// 📁 lib/services/prefix_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
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

  static Future<void> addIfNotExist(String name) async {
    final snapshot = await _collection
        .where('name', isEqualTo: name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      await _collection.add({'name': name});
      print('🆕 เพิ่มคำนำหน้านามใหม่: $name');
    } else {
      print('✅ คำนำหน้านามนี้มีอยู่แล้ว: $name');
    }
  }
}
