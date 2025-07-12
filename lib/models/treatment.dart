// ================================================================
// 📁 1. lib/models/treatment.dart
// v1.2.1 - 🐞 ปรับปรุงโค้ดให้ Analyzer เข้าใจง่ายขึ้น
// ================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

class Treatment {
  final String id;
  final String patientId;
  final String treatmentMasterId;
  final String procedure;
  final String toothNumber;
  final double price;
  final DateTime date;
  final List<String> imageUrls;

  Treatment({
    required this.id,
    required this.patientId,
    required this.treatmentMasterId,
    required this.procedure,
    required this.toothNumber,
    required this.price,
    required this.date,
    this.imageUrls = const [],
  });

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
    };
  }

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
    );
  }

  Treatment copyWith({
    String? id,
    String? patientId,
    String? treatmentMasterId,
    String? procedure,
    String? toothNumber,
    double? price,
    DateTime? date,
    List<String>? imageUrls,
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
    );
  }
}