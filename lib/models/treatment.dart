// ----- FILE: lib/models/treatment.dart -----

import 'package:cloud_firestore/cloud_firestore.dart';


class Treatment {
  final String id;
  final String patientId;
  final String procedure;
  final String toothNumber;
  final double price;
  final DateTime date;

  Treatment({
    required this.id,
    required this.patientId,
    required this.procedure,
    required this.toothNumber,
    required this.price,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'procedure': procedure,
      'toothNumber': toothNumber,
      'price': price,
      'date': Timestamp.fromDate(date),
    };
  }

factory Treatment.fromMap(Map<String, dynamic> map, String id) {
  return Treatment(
    id: id,
    patientId: map['patientId'] ?? '',
    procedure: map['procedure'] ?? '',
    toothNumber: map['toothNumber'] ?? '',
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

  Treatment copyWith({
    String? id,
    String? patientId,
    String? procedure,
    String? toothNumber,
    double? price,
    DateTime? date,
  }) {
    return Treatment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      procedure: procedure ?? this.procedure,
      toothNumber: toothNumber ?? this.toothNumber,
      price: price ?? this.price,
      date: date ?? this.date,
    );
  }
}
