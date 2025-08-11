import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/appointment_slip_model.dart';

class AppointmentSlipRenderer {
  final int widthPx;
  AppointmentSlipRenderer({this.widthPx = 576});

  final _dt = DateFormat('EEE dd/MM/yyyy HH:mm', 'th'); // รูปแบบวันนัด

  Future<ui.Image> render(AppointmentSlipModel s) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), 1600), Paint()..color = const Color(0xFFFFFFFF));

    double y = 16;

    y += _text(c, s.clinic.name, y, size: 28, bold: true, center: true);
    y += _text(c, s.clinic.address, y, size: 20, center: true);
    y += _text(c, 'โทร: ${s.clinic.phone}', y, size: 20, center: true);
    y += _hr(c, y);

    y += _text(c, 'ใบนัดหมาย', y, size: 24, bold: true, center: true);
    y += _text(c, 'ผู้ป่วย: ${s.patient.name}${s.patient.hn.isNotEmpty ? "  (HN: ${s.patient.hn})" : ""}', y, size: 22);
    y += _text(c, 'วันเวลา: ${_dt.format(s.appointment.startAt)}', y, size: 22);
    if (s.appointment.note?.isNotEmpty == true) {
      y += _text(c, 'หมายเหตุ: ${s.appointment.note}', y, size: 20);
    }

    y += _hr(c, y);
    y += _text(c, 'กรุณามาก่อนเวลานัด 10–15 นาที', y, size: 20, center: true);
    y += 24;

    final pic = rec.endRecording();
    final img = await pic.toImage(widthPx, y.ceil() + 24);
    return img;
  }

  double _text(Canvas c, String text, double y, {double size = 22, bool bold = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: Colors.black)),
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
}
