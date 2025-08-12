import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart' show AppointmentInfo; // เผื่อใช้ในอนาคตสำหรับบล็อกใบนัด

/// เรนเดอร์ใบเสร็จ 80 มม. ตามแบบที่พี่ทะเลกำหนด (ไม่มี VAT)
/// โครง: โลโก้(ออปชัน) → ชื่อ/ที่อยู่/โทรคลินิก → เส้นคั่น "********" → เลขที่ (ขวา) + วันที่ (ขวา ใต้เลขที่)
/// → ผู้รับบริการ → การรักษา → ซี่ฟัน → ค่าบริการ → เส้นคั่น → (บล็อกนัดต่อไปออปชัน) → ขอบคุณ
class ReceiptRenderer {
  /// ความกว้างพิกเซลสำหรับ 80mm @ ~203dpi (บางรุ่น 576px)
  final int widthPx;
  ReceiptRenderer({this.widthPx = 576});

  Future<ui.Image> render(
    ReceiptModel receipt, {
    String? logoAssetPath,
    bool showNextAppointment = false,
    AppointmentInfo? nextAppointment,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.black;
    final double margin = 24;
    double y = margin;

    // พื้นหลังสีขาว (ความสูงเผื่อไว้ จะตัดตอนจบด้วย y จริง)
    canvas.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), 2300), Paint()..color = Colors.white);

    // 0) โลโก้ (ออปชัน)
    if (logoAssetPath != null) {
      try {
        final img = await _loadAssetImage(logoAssetPath, maxWidth: (widthPx * 0.5).round());
        final dx = (widthPx - img.width) / 2;
        canvas.drawImage(img, Offset(dx, y), paint);
        y += img.height + 12;
      } catch (_) {/* ข้ามโลโก้หากโหลดไม่สำเร็จ */}
    }

    // 1) ส่วนหัวคลินิก (จัดกึ่งกลาง)
    y = _drawCenter(canvas, y, receipt.clinic.name,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700));
    y = _drawCenter(canvas, y, receipt.clinic.address,
        style: const TextStyle(fontSize: 16));
    y = _drawCenter(canvas, y, 'โทร.  ${receipt.clinic.phone}',
        style: const TextStyle(fontSize: 16));

    // 2) เส้นคั่นดาว
    y += 6;
    y = _drawCenter(canvas, y, _repeatChar('*', count: 32),
        style: const TextStyle(letterSpacing: 1.0));

    // 3) เลขที่ (ขวา) + วันที่ (ขวา ใต้เลขที่)
    y += 4;
    y = _drawRight(canvas, y, 'เลขที่  ${receipt.bill.billNo}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
    y = _drawRight(canvas, y, _formatThaiBuddhistDate(receipt.bill.issuedAt),
        style: const TextStyle(fontSize: 16));

    y += 8;

    // 4) ผู้รับบริการ / รายการรักษา / ซี่ฟัน / ค่าบริการ
    y = _drawLeft(canvas, y, 'ผู้รับบริการ:', style: const TextStyle(fontSize: 16));
    final patientName = receipt.patient.name.trim();
    y = _drawLeft(canvas, y, '   ${patientName.isEmpty ? '(ไม่ระบุ)' : patientName}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));

    // ใช้บรรทัดแรกเป็นชื่อหัตถการหลัก และดึงซี่ฟันจาก (#...)
    final mainLine = receipt.lines.isNotEmpty ? receipt.lines.first : null;
    String treatmentName = mainLine?.name ?? '';
    String toothText = '';
    final m = RegExp(r"\s*\(#([^\)]+)\)\s*\$").firstMatch(treatmentName);
    if (m != null) {
      toothText = m.group(1) ?? '';
      treatmentName = treatmentName.replaceAll(RegExp(r"\s*\(#([^\)]+)\)\s*\$"), '').trim();
    }

    if (treatmentName.isNotEmpty) {
      y = _drawLeft(canvas, y, 'การรักษา:  $treatmentName', style: const TextStyle(fontSize: 16));
    }
    if (toothText.isNotEmpty) {
      y = _drawLeft(canvas, y, 'ซี่ฟัน:  #$toothText', style: const TextStyle(fontSize: 16));
    }

    final num total = receipt.lines.fold<num>(0, (p, e) => p + e.qty * e.price);
    y = _drawLeft(canvas, y, 'ค่าบริการ:  ${_formatBaht(total)} บาท',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));

    // 5) เส้นคั่น
    y += 8;
    y = _drawCenter(canvas, y, _repeatChar('_', count: 34));

    // 6) บล็อกนัดต่อไป (ออปชัน)
    if (showNextAppointment && nextAppointment != null) {
      y = _drawCenter(canvas, y, 'นัดต่อไป', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
      final nextDate = _formatThaiBuddhistDate(nextAppointment.startAt);
      final nextTime = DateFormat.Hm('th_TH').format(nextAppointment.startAt);
      y = _drawLeft(canvas, y, nextDate, style: const TextStyle(fontSize: 16));
      y = _drawLeft(canvas, y, 'เวลา:  $nextTime น.', style: const TextStyle(fontSize: 16));
      if (treatmentName.isNotEmpty) {
        y = _drawLeft(canvas, y, 'การรักษา:  $treatmentName', style: const TextStyle(fontSize: 16));
      }
      if (toothText.isNotEmpty) {
        y = _drawLeft(canvas, y, 'ซี่ฟัน:  #$toothText', style: const TextStyle(fontSize: 16));
      }

      y += 4;
      y = _drawCenter(canvas, y, _repeatChar('_', count: 30));
      y = _drawCenter(canvas, y, 'กรุณามาก่อนนัดหมาย 10–15 นาที');
    }

    // 7) Footer
    y += 6;
    y = _drawCenter(canvas, y, 'ขอบคุณที่ใช้บริการ');

    // ปิดภาพ
    final picture = recorder.endRecording();
    final img = await picture.toImage(widthPx, y.ceil() + 24);
    return img;
  }

  Future<Uint8List> toPngBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ---------- Helpers ----------
  Future<ui.Image> _loadAssetImage(String assetPath, {int? maxWidth}) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: maxWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  String _formatThaiBuddhistDate(DateTime d) {
    // ตัวอย่าง: "อังคาร 12 สิงหาคม 2568"
    final dowFull = DateFormat('EEEE', 'th_TH').format(d); // เช่น "วันอังคาร"
    final dow = dowFull.replaceFirst('วัน', '').trim();
    final dmy = DateFormat('d MMMM ', 'th_TH').format(d);
    final buddhistYear = d.year + 543;
    return '$dow $dmy$buddhistYear';
  }

  String _formatBaht(num n) => NumberFormat('#,##0.##', 'th_TH').format(n);
  String _repeatChar(String ch, {required int count}) => List.filled(count, ch).join();

  double _drawCenter(Canvas canvas, double y, String text, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: (style ?? const TextStyle()).copyWith(color: Colors.black)),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble());
    tp.paint(canvas, Offset((widthPx - tp.width) / 2, y));
    return y + tp.height + 4;
  }

  double _drawLeft(Canvas canvas, double y, String text, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: (style ?? const TextStyle()).copyWith(color: Colors.black)),
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: (widthPx - 48).toDouble());
    tp.paint(canvas, Offset(24, y));
    return y + tp.height + 2;
  }

  double _drawRight(Canvas canvas, double y, String text, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: (style ?? const TextStyle()).copyWith(color: Colors.black)),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble());
    tp.paint(canvas, Offset(widthPx - tp.width - 24, y));
    return y + tp.height + 2;
  }

  double _drawTwoColumns(
    Canvas canvas,
    double y, {
    required String left,
    required String right,
    TextStyle? leftStyle,
    TextStyle? rightStyle,
  }) {
    final leftTp = TextPainter(
      text: TextSpan(text: left, style: (leftStyle ?? const TextStyle()).copyWith(color: Colors.black)),
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble() * 0.6);

    final rightTp = TextPainter(
      text: TextSpan(text: right, style: (rightStyle ?? const TextStyle()).copyWith(color: Colors.black)),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble() * 0.35);

    leftTp.paint(canvas, Offset(24, y));
    rightTp.paint(canvas, Offset(widthPx - rightTp.width - 24, y));

    return y + math.max(leftTp.height, rightTp.height) + 2;
  }
}
