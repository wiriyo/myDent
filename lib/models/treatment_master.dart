// ----- FILE: lib/models/treatment_master.dart -----
// เวอร์ชัน 1.1: ไม่มีการเปลี่ยนแปลงในไฟล์นี้
// พิมพ์เขียวสำหรับ "เมนูหัตถการ" ของคลินิก ยังคงสมบูรณ์แบบเหมือนเดิมค่ะ

class TreatmentMaster {
  final String treatmentId;
  final String name;
  final int duration; // หน่วยเป็นนาที
  final double price;

  TreatmentMaster({
    required this.treatmentId,
    required this.name,
    required this.duration,
    required this.price,
  });

  factory TreatmentMaster.fromMap(Map<String, dynamic> map, String docId) {
    return TreatmentMaster(
      treatmentId: docId,
      name: map['name'] ?? '',
      duration: map['duration'] ?? 30,
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'duration': duration,
      'price': price,
    };
  }
}