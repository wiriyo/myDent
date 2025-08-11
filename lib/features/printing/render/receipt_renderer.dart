import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart'; // ใช้ TextPainter / Colors
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../domain/receipt_model.dart';

class ReceiptRenderer {
  /// ความกว้าง pixel สำหรับกระดาษ 80mm ส่วนใหญ่ ~576px
  final int widthPx;
  ReceiptRenderer({this.widthPx = 576});

  final _money = NumberFormat('#,##0.00');
  String _thb(num n) => '฿${_money.format(n)}';
  String _dt(DateTime t) => DateFormat('dd/MM/yyyy HH:mm').format(t);

  Future<ui.Image> render(ReceiptModel r) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintBg = Paint()..color = const Color(0xFFFFFFFF);
    // สูงเผื่อก่อน 3000px เดี๋ยวตัดจริงท้ายสุด
    canvas.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), 3000), paintBg);

    double y = 16;

    // หัวบิล (พาสเทลเบา ๆ)
    y += _text(canvas, r.clinic.name, y, size: 28, bold: true, center: true);
    y += _text(canvas, r.clinic.address, y, size: 20, center: true);
    y += _text(canvas, 'โทร: ${r.clinic.phone}', y, size: 20, center: true);
    y += _hr(canvas, y);

    // ข้อมูลบิล + คนไข้
    y += _text(canvas, 'เลขที่บิล: ${r.bill.billNo}    วันที่: ${_dt(r.bill.issuedAt)}', y, size: 20);
    y += _text(canvas, 'ผู้ป่วย: ${r.patient.name}${r.patient.hn.isNotEmpty ? "  (HN: ${r.patient.hn})" : ""}', y, size: 22);

    y += _hr(canvas, y);

    // รายการ: ชื่อซ้าย, qty+ราคารวมขวา
    for (final line in r.lines) {
      y += _rowItem(canvas,
          left: line.name,
          right: 'x${line.qty}  ${_thb(line.lineTotal)}',
          y: y,
          size: 22);
    }

    y += _hr(canvas, y);

    // รวมยอด
    y += _rowItem(canvas, left: 'รวม', right: _thb(r.totals.subTotal), y: y, size: 22);
    if (r.totals.discount > 0) {
      y += _rowItem(canvas, left: 'ส่วนลด', right: '-${_thb(r.totals.discount)}', y: y, size: 22);
    }
    y += _rowItem(canvas, left: 'VAT', right: _thb(r.totals.vat), y: y, size: 22);
    y += _rowItem(canvas, left: 'สุทธิ', right: _thb(r.totals.grandTotal), y: y, size: 24, bold: true);

    y += 24;

    // ปิดรูปด้วยความสูงพอดี
    final picture = recorder.endRecording();
    final imgResult = await picture.toImage(widthPx, y.ceil() + 24);
    return imgResult;
  }

  /// แปลง ui.Image -> PNG bytes (เผื่อ export/preview)
  Future<Uint8List> toPngBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ---------- helpers ----------
  double _text(Canvas c, String text, double y,
      {double size = 22, bool bold = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: Colors.black,
        ),
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble());

    final dx = center ? (widthPx - tp.width) / 2 : 0.0;
    tp.paint(c, Offset(dx, y));
    return tp.height + 6;
  }

  double _hr(Canvas c, double y) {
    return _text(c, '----------------------------------------', y, size: 20, center: true);
  }

  double _rowItem(Canvas c, {required String left, required String right, required double y, double size = 22, bool bold = false}) {
    // วาดซ้าย
    final leftPaint = TextPainter(
      text: TextSpan(
        text: left,
        style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: Colors.black),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: (widthPx * 0.6)); // ชื่อจุ ~60%
    leftPaint.paint(c, Offset(0, y));

    // วาดขวา (ชิดขอบขวา)
    final rightPaint = TextPainter(
      text: TextSpan(
        text: right,
        style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: Colors.black),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: (widthPx * 0.38)); // ช่องขวา ~38%
    rightPaint.paint(c, Offset(widthPx - rightPaint.width, y));

    return (leftPaint.height > rightPaint.height ? leftPaint.height : rightPaint.height) + 6;
  }
}
