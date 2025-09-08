// v1.3.0 - 📝 เพิ่มช่องสำหรับบันทึกการรักษา (Treatment Notes)
// v1.2.1 - 🐞 ปรับปรุงโค้ดให้ Analyzer เข้าใจง่ายขึ้น
import 'package:cloud_firestore/cloud_firestore.dart';

// --- 📝 พิมพ์เขียวข้อมูลการรักษา (Treatment Model) ---
class Treatment {
  final String id;
  final String patientId;
  final String treatmentMasterId;
  final String procedure;
  final String toothNumber;
  final double price;
  final DateTime date;
  final List<String> imageUrls;
  
  // 📝 [NEW v1.3.0] เพิ่มช่องสำหรับเก็บ "สมุดบันทึกการรักษา"
  // เป็น String? (nullable) เพื่อให้รองรับข้อมูลเก่าที่ยังไม่มี field นี้ได้ค่ะ
  final String? notes;

  Treatment({
    required this.id,
    required this.patientId,
    required this.treatmentMasterId,
    required this.procedure,
    required this.toothNumber,
    required this.price,
    required this.date,
    this.imageUrls = const [],
    this.notes, // 📝 [NEW v1.3.0] เพิ่มใน constructor
  });

  // --- ⚙️ เครื่องมือแปลงข้อมูล ---

  /// แปลง Object Treatment ของเราให้กลายเป็น Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'treatmentMasterId': treatmentMasterId,
      'procedure': procedure,
      'toothNumber': toothNumber,
      'price': price,
      'date': Timestamp.fromDate(date),
      'imageUrls': imageUrls,
      'notes': notes, // 📝 [NEW v1.3.0] เพิ่มตอนแปลงเป็น Map
    };
  }

  /// สร้าง Object Treatment ขึ้นมาจากข้อมูล Map ที่ได้รับจาก Firestore
  factory Treatment.fromMap(Map<String, dynamic> map, String id) {
    var imageUrlsData = map['imageUrls'];
    List<String> imageUrlsList = [];
    if (imageUrlsData is List) {
      for (var item in imageUrlsData) {
        if (item is String) {
          imageUrlsList.add(item);
        }
      }
    }

    return Treatment(
      id: id,
      patientId: map['patientId'] ?? '',
      treatmentMasterId: map['treatmentMasterId'] ?? '',
      procedure: map['procedure'] ?? '',
      toothNumber: map['toothNumber'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrls: imageUrlsList,
      notes: map['notes'], // 📝 [NEW v1.3.0] อ่านค่า notes จาก Firestore
    );
  }

  /// สร้างสำเนาของ Treatment object ปัจจุบัน แต่สามารถแก้ไขบาง field ได้
  Treatment copyWith({
    String? id,
    String? patientId,
    String? treatmentMasterId,
    String? procedure,
    String? toothNumber,
    double? price,
    DateTime? date,
    List<String>? imageUrls,
    String? notes, // 📝 [NEW v1.3.0] เพิ่มใน copyWith
  }) {
    return Treatment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      treatmentMasterId: treatmentMasterId ?? this.treatmentMasterId,
      procedure: procedure ?? this.procedure,
      toothNumber: toothNumber ?? this.toothNumber,
      price: price ?? this.price,
      date: date ?? this.date,
      imageUrls: imageUrls ?? this.imageUrls,
      notes: notes ?? this.notes, // 📝 [NEW v1.3.0]
    );
  }
}
