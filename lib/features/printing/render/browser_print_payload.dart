import 'dart:convert';
import 'dart:typed_data';

import '../domain/appointment_slip_model.dart';
import '../domain/receipt_model.dart';
import '../utils/th_format.dart';

class BrowserPrintPayloadBuilder {
  const BrowserPrintPayloadBuilder._();

  static Map<String, dynamic> receipt({
    required ReceiptModel receipt,
    required String clinicName,
    required String clinicAddress,
    required String clinicPhone,
    String? clinicTaxId,
    String? clinicLineId,
    required int headerSpace,
    required int pixelWidth,
    ByteData? logoBytes,
  }) {
    return <String, dynamic>{
      'document': 'receipt',
      'pixelWidth': pixelWidth,
      'headerSpace': headerSpace,
      'clinic': _clinicMap(
        name: clinicName,
        address: clinicAddress,
        phone: clinicPhone,
        taxId: clinicTaxId,
        lineId: clinicLineId,
      ),
      'bill': <String, dynamic>{
        'number': receipt.bill.billNo,
        'issuedDate': ThFormat.dateThai(receipt.bill.issuedAt),
        'issuedTime': ThFormat.timeThai(receipt.bill.issuedAt),
      },
      'patient': <String, dynamic>{
        'name': receipt.patient.name,
        'hn': receipt.patient.hn,
      },
      'items': receipt.lines
          .map(
            (line) => <String, dynamic>{
              'name': line.name,
              'qty': line.qty,
              'priceText': _formatMoney(line.price),
              'totalText': _formatMoney(line.lineTotal),
            },
          )
          .toList(),
      'totals': <String, dynamic>{
        'subTotal': _formatMoney(receipt.totals.subTotal),
        'discount': _formatMoney(receipt.totals.discount),
        'discountValue': receipt.totals.discount,
        'vat': _formatMoney(receipt.totals.vat),
        'grandTotal': _formatMoney(receipt.totals.grandTotal),
      },
      'logo': _encodeLogo(logoBytes),
    };
  }

  static Map<String, dynamic> appointment({
    required AppointmentSlipModel slip,
    required String clinicName,
    required String clinicAddress,
    required String clinicPhone,
    String? clinicTaxId,
    String? clinicLineId,
    required int headerSpace,
    required int pixelWidth,
    ByteData? logoBytes,
  }) {
    return <String, dynamic>{
      'document': 'appointment',
      'pixelWidth': pixelWidth,
      'headerSpace': headerSpace,
      'clinic': _clinicMap(
        name: clinicName,
        address: clinicAddress,
        phone: clinicPhone,
        taxId: clinicTaxId,
        lineId: clinicLineId,
      ),
      'patient': <String, dynamic>{
        'name': slip.patient.name,
        'hn': slip.patient.hn,
      },
      'appointment': <String, dynamic>{
        'date': ThFormat.dateThai(slip.appointment.startAt),
        'time': ThFormat.timeThai(slip.appointment.startAt),
        'note': slip.appointment.note ?? '',
      },
      'logo': _encodeLogo(logoBytes),
    };
  }

  static Map<String, dynamic> combined({
    required ReceiptModel receipt,
    required AppointmentSlipModel slip,
    required String clinicName,
    required String clinicAddress,
    required String clinicPhone,
    String? clinicTaxId,
    String? clinicLineId,
    required int headerSpace,
    required int pixelWidth,
    ByteData? logoBytes,
  }) {
    return <String, dynamic>{
      'document': 'combined',
      'pixelWidth': pixelWidth,
      'headerSpace': headerSpace,
      'logo': _encodeLogo(logoBytes),
      'clinic': _clinicMap(
        name: clinicName,
        address: clinicAddress,
        phone: clinicPhone,
        taxId: clinicTaxId,
        lineId: clinicLineId,
      ),
      'receipt': receiptMapOnly(
        receipt: receipt,
      ),
      'appointment': appointmentMapOnly(
        slip: slip,
      ),
    };
  }

  static Map<String, dynamic> receiptMapOnly({
    required ReceiptModel receipt,
  }) {
    return <String, dynamic>{
      'bill': <String, dynamic>{
        'number': receipt.bill.billNo,
        'issuedDate': ThFormat.dateThai(receipt.bill.issuedAt),
        'issuedTime': ThFormat.timeThai(receipt.bill.issuedAt),
      },
      'patient': <String, dynamic>{
        'name': receipt.patient.name,
        'hn': receipt.patient.hn,
      },
      'items': receipt.lines
          .map(
            (line) => <String, dynamic>{
              'name': line.name,
              'qty': line.qty,
              'priceText': _formatMoney(line.price),
              'totalText': _formatMoney(line.lineTotal),
            },
          )
          .toList(),
      'totals': <String, dynamic>{
        'subTotal': _formatMoney(receipt.totals.subTotal),
        'discount': _formatMoney(receipt.totals.discount),
        'discountValue': receipt.totals.discount,
        'vat': _formatMoney(receipt.totals.vat),
        'grandTotal': _formatMoney(receipt.totals.grandTotal),
      },
    };
  }

  static Map<String, dynamic> appointmentMapOnly({
    required AppointmentSlipModel slip,
  }) {
    return <String, dynamic>{
      'patient': <String, dynamic>{
        'name': slip.patient.name,
        'hn': slip.patient.hn,
      },
      'appointment': <String, dynamic>{
        'date': ThFormat.dateThai(slip.appointment.startAt),
        'time': ThFormat.timeThai(slip.appointment.startAt),
        'note': slip.appointment.note ?? '',
      },
    };
  }

  static Map<String, dynamic> _clinicMap({
    required String name,
    required String address,
    required String phone,
    String? taxId,
    String? lineId,
  }) {
    return <String, dynamic>{
      'name': name,
      'address': address,
      'phone': phone,
      'taxId': taxId ?? '',
      'lineId': lineId ?? '',
    };
  }

  static String _formatMoney(num value) {
    final double normalized = value.toDouble();
    return normalized.toStringAsFixed(2);
  }

  static String? _encodeLogo(ByteData? logo) {
    if (logo == null) {
      return null;
    }
    return base64Encode(logo.buffer.asUint8List());
  }
}
