// lib/features/printing/render/receipt_renderer.dart
// Renderer สำหรับใบเสร็จ MyDent

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import '../utils/th_format.dart';

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart' show AppointmentInfo; // เผื่อใช้ในอนาคตสำหรับบล็อกใบนัด

/// เรนเดอร์ใบเสร็จ 80 มม. ตามรูปแบบที่คลินิกต้องการ (ไม่มี VAT)
/// โครง: โลโก้(ออปชัน) → ชื่อ/ที่อยู่/โทรคลินิก → เส้นคั่น "*********************" →
/// เลขที่/วันที่/เวลา/ชื่อ/หัตถการ/ค่าบริการ แบบสองคอลัมน์ → (ใบนัดครั้งถัดไปออปชัน) → ขอบคุณ
class ReceiptRenderer {
  /// ความกว้างพิกเซลสำหรับ 80mm @ ~203dpi (บางรุ่น 576px)
  final int widthPx;
  static const double _fontScale = 1.0;
  static const double _logoScale = 1.3;
  static const double _defaultLogoWidthFactor = 0.5;
  static const double _fallbackFontSize = 14.0;
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
        final img = await _loadAssetImage(
          logoAssetPath,
          maxWidth: (widthPx * _defaultLogoWidthFactor * _logoScale).round(),
        );
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
    y = _drawCenter(canvas, y, _repeatChar('*', count: 21),
        style: const TextStyle(letterSpacing: 1.0));

    // 3) ข้อมูลเลขที่ / วันที่ / เวลา / ชื่อ / หัตถการ / ค่าบริการ (สองคอลัมน์)
    y += 8;
    y = _drawTwoColumns(canvas, y,
        left: 'เลขที่',
        right: receipt.bill.billNo,
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle: const TextStyle(fontSize: 16));

    final dateText = ThFormat.dateThai(receipt.bill.issuedAt);
    y = _drawTwoColumns(canvas, y,
        left: 'วันที่',
        right: dateText,
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle: const TextStyle(fontSize: 16));

    final timeText = ThFormat.timeThai(receipt.bill.issuedAt);
    y = _drawTwoColumns(canvas, y,
        left: 'เวลา',
        right: timeText,
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle: const TextStyle(fontSize: 16));

    final patientName = receipt.patient.displayName.trim();
    y = _drawTwoColumns(canvas, y,
        left: 'ชื่อ',
        right: '',
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle: const TextStyle(fontSize: 16));
    y = _drawRight(canvas, y,
        patientName.isEmpty ? '(ไม่ระบุ)' : patientName,
        style: const TextStyle(fontSize: 18));

    // ใช้บรรทัดแรกเป็นชื่อหัตถการหลัก (พร้อมซี่ฟันหากมีในวงเล็บ)
    final mainLine = receipt.lines.isNotEmpty ? receipt.lines.first : null;
    final treatmentName = mainLine?.name ?? '-';
    y = _drawTwoColumns(canvas, y,
        left: 'หัตถการ:',
        right: treatmentName,
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle: const TextStyle(fontSize: 16));

    final num total = receipt.lines.fold<num>(0, (p, e) => p + e.qty * e.price);
    y = _drawTwoColumns(canvas, y,
        left: 'ค่าบริการ',
        right: '${_formatBaht(total)} บาท',
        leftStyle: const TextStyle(fontSize: 16),
        rightStyle:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));

    // 4) ใบนัดครั้งถัดไป (ออปชัน)
    if (showNextAppointment && nextAppointment != null) {
      y += 18;
      canvas.drawLine(
          Offset(24, y), Offset(widthPx - 24, y), paint..strokeWidth = 1);
      y += 12;
      y = _drawCenter(canvas, y, 'ใบนัดครั้งถัดไป',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
      y += 6;
      final nextDate = ThFormat.dateThai(nextAppointment.startAt);
      final nextTime = ThFormat.timeThai(nextAppointment.startAt);
      y = _drawTwoColumns(canvas, y,
          left: 'วันที่นัด',
          right: nextDate,
          leftStyle: const TextStyle(fontSize: 16),
          rightStyle: const TextStyle(fontSize: 16));
      y = _drawTwoColumns(canvas, y,
          left: 'เวลา',
          right: nextTime,
          leftStyle: const TextStyle(fontSize: 16),
          rightStyle: const TextStyle(fontSize: 16));
      final note = nextAppointment.note?.trim();
      if (note != null && note.isNotEmpty) {
        y = _drawTwoColumns(canvas, y,
            left: 'หมายเหตุ',
            right: note,
            leftStyle: const TextStyle(fontSize: 16),
            rightStyle: const TextStyle(fontSize: 16));
      }
      y += 10;
    }

    // 5) Footer
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

  String _formatBaht(num n) => NumberFormat('#,##0.##', 'th_TH').format(n);
  String _repeatChar(String ch, {required int count}) => List.filled(count, ch).join();

  TextStyle _scaledStyle(TextStyle? style) {
    final base = style ?? const TextStyle();
    final double resolvedFontSize = (base.fontSize ?? _fallbackFontSize) * _fontScale;
    return base.copyWith(
      fontSize: resolvedFontSize,
      color: Colors.black,
    );
  }

  double _drawCenter(Canvas canvas, double y, String text, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _scaledStyle(style)),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble());
    tp.paint(canvas, Offset((widthPx - tp.width) / 2, y));
    return y + tp.height + 4;
  }

  double _drawRight(Canvas canvas, double y, String text, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _scaledStyle(style)),
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
      text: TextSpan(text: left, style: _scaledStyle(leftStyle)),
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble() * 0.6);

    final rightTp = TextPainter(
      text: TextSpan(text: right, style: _scaledStyle(rightStyle)),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: widthPx.toDouble() * 0.35);

    leftTp.paint(canvas, Offset(24, y));
    rightTp.paint(canvas, Offset(widthPx - rightTp.width - 24, y));

    return y + math.max(leftTp.height, rightTp.height) + 2;
  }
}
