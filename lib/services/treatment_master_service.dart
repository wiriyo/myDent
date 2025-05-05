import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/treatment_master.dart';

class TreatmentMasterService {
  static final _collection = FirebaseFirestore.instance.collection('treatment_master'); // ✅ แก้ตรงนี้

  static Stream<List<TreatmentMaster>> getAllTreatments() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TreatmentMaster.fromMap(doc.data(), doc.id))
            .toList());
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

  static Future<void> addIfNotExist(String name, double price) async {
    final snapshot = await _collection
        .where('name', isEqualTo: name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      await _collection.add({
        'name': name,
        'price': price,
        'duration': 30,
      });
      print('🆕 เพิ่มเข้า treatment_master: $name');
    } else {
      print('✅ ชื่อหัตถการนี้มีอยู่แล้วใน master');
    }
  }
}
