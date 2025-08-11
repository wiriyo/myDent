import 'package:flutter/foundation.dart';

@immutable
class ClinicInfo {
  final String name;
  final String address;
  final String phone;
  const ClinicInfo({required this.name, required this.address, required this.phone});
}

@immutable
class BillInfo {
  final String billNo;
  final DateTime issuedAt;
  const BillInfo({required this.billNo, required this.issuedAt});
}

@immutable
class PatientInfo {
  final String name;
  final String hn; // ถ้าไม่ใช้ HN ใส่ '' ได้
  const PatientInfo({required this.name, this.hn = ''});
}

@immutable
class ReceiptLine {
  final String name;
  final int qty;
  final num price;
  const ReceiptLine({required this.name, required this.qty, required this.price});
  num get lineTotal => qty * price;
}

@immutable
class TotalSummary {
  final num subTotal;
  final num discount;
  final num vat;
  final num grandTotal;
  const TotalSummary({
    required this.subTotal,
    required this.discount,
    required this.vat,
    required this.grandTotal,
  });
}

@immutable
class ReceiptModel {
  final ClinicInfo clinic;
  final BillInfo bill;
  final PatientInfo patient;
  final List<ReceiptLine> lines;
  final TotalSummary totals;
  const ReceiptModel({
    required this.clinic,
    required this.bill,
    required this.patient,
    required this.lines,
    required this.totals,
  });
}
