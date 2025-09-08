// lib/features/printing/render/appointment_slip_renderer.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/th_format.dart';
import '../domain/appointment_slip_model.dart';

class AppointmentSlipRenderer {
  final int widthPx;
  AppointmentSlipRenderer({this.widthPx = 576});

  Future<ui.Image> render(AppointmentSlipModel s) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final totalRect = Rect.fromLTWH(0, 0, widthPx.toDouble(), 1600);
    c.drawRect(totalRect, Paint()..color = const Color(0xFFFFFFFF));

    double y = 16;

    // --- Header ---
    y += _text(c, s.clinic.name, y, size: 28, bold: true, center: true);
    y += _text(c, s.clinic.address, y, size: 20, center: true, height: 1.3);
    y += _text(c, 'โทร: ${s.clinic.phone}', y, size: 20, center: true);
    y += _hr(c, y);

    // --- Body ---
    y += _text(c, 'ใบนัดหมาย', y, size: 24, bold: true, center: true);
    y += 8;
    y += _text(c, 'ผู้ป่วย: ${s.patient.name}${s.patient.hn.isNotEmpty ? "  (HN: ${s.patient.hn})" : ""}', y, size: 22);
    // 💖 FIX: แก้ไขการเรียกใช้ฟังก์ชันวันที่ให้ถูกต้องค่า
    y += _text(c, 'วันเวลา: ${ThFormat.dateThai(s.appointment.startAt, shortYear: false)} เวลา ${ThFormat.timeThai(s.appointment.startAt)}', y, size: 22);
    if (s.appointment.note?.isNotEmpty == true) {
      y += _text(c, 'หมายเหตุ: ${s.appointment.note}', y, size: 20, height: 1.3);
    }
    y += 8;

    // --- Footer ---
    y += _hr(c, y);
    y += _text(c, 'กรุณามาก่อนเวลานัด 10–15 นาที', y, size: 20, center: true);
    y += 24;

    final pic = rec.endRecording();
    final img = await pic.toImage(widthPx, y.ceil());
    return img;
  }

  double _text(Canvas c, String text, double y, {double size = 22, bool bold = false, bool center = false, double height = 1.25}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: Colors.black, height: height)),
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: ui.TextDirection.ltr,
      // 💖 FIX: บังคับ textScaleFactor = 1.0
      // เพื่อให้ TextPainter ไม่ปรับขนาดฟอนต์ตามการตั้งค่าของเครื่อง
      textScaleFactor: 1.0, 
    )..layout(maxWidth: widthPx.toDouble() - 16); // มี padding ซ้ายขวานิดหน่อย

    final dx = center ? (widthPx - tp.width) / 2 : 8.0;
    tp.paint(c, Offset(dx, y));
    return tp.height + 6;
  }

  double _hr(Canvas c, double y) {
    return _text(c, '----------------------------------------', y, size: 20, center: true);
  }
}
