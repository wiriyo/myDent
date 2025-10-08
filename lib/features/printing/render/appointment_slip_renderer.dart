// lib/features/printing/render/appointment_slip_renderer.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/th_format.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../../../config/clinic_context.dart';
import '../../../services/clinic_settings_service.dart';
import '../../../config/clinic_defaults.dart';
import 'dart:async';
import '../domain/appointment_slip_model.dart';
import '../../../services/logo_cache_service.dart';

class AppointmentSlipRenderer {
  final int widthPx;
  AppointmentSlipRenderer({this.widthPx = 576});

  Future<ui.Image> render(AppointmentSlipModel s) async {
    // Load clinic header from settings (override model)
    String name = ClinicDefaults.defaultClinicName;
    String address = '';
    String phone = '';
    String? taxId;
    String? lineId;
    Uint8List? logoBytes;
    try {
      final svc = ClinicSettingsService();
      final data = await svc.getClinicInfo(clinicId: ClinicContext.activeClinicId);
      if (data != null) {
        name = ((data['name'] as String?)?.trim().isNotEmpty == true) ? (data['name'] as String) : ClinicDefaults.defaultClinicName;
        address = (data['address'] as String?)?.trim() ?? '';
        phone = (data['phone'] as String?)?.trim() ?? '';
        final showLine = (data['showLineId'] ?? true) as bool;
        final showTax = (data['showTaxId'] ?? false) as bool;
        lineId = showLine ? (data['lineId'] as String?)?.trim() : null;
        taxId = showTax ? (data['taxId'] as String?)?.trim() : null;
        final url = (data['logoUrl'] as String?)?.trim();
        if (url != null && url.isNotEmpty) {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200) {
            logoBytes = resp.bodyBytes;
            // Cache for splash/offline use
            await LogoCacheService.save(resp.bodyBytes);
          }
        }
      }
      logoBytes ??= (await rootBundle.load(ClinicDefaults.defaultLogoAsset)).buffer.asUint8List();
    } catch (_) {}

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final totalRect = Rect.fromLTWH(0, 0, widthPx.toDouble(), 1600);
    c.drawRect(totalRect, Paint()..color = const Color(0xFFFFFFFF));

    double y = 16;

    // --- Header (with logo & clinic info) ---
    if (logoBytes != null) {
      final img = await _decodeImage(logoBytes);
      final drawW = 160.0;
      final drawH = drawW * img.height / img.width;
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH((widthPx - drawW) / 2, y, drawW, drawH),
        Paint(),
      );
      y += drawH + 6;
    }
    y += _text(c, name, y, size: 28, bold: true, center: true);
    if (address.trim().isNotEmpty) y += _text(c, address, y, size: 20, center: true, height: 1.3);
    if (phone.trim().isNotEmpty) y += _text(c, 'โทร: $phone', y, size: 20, center: true);
    if ((taxId ?? '').isNotEmpty) y += _text(c, 'เลขผู้เสียภาษี: $taxId', y, size: 18, center: true);
    if ((lineId ?? '').isNotEmpty) y += _text(c, 'Line ID: $lineId', y, size: 18, center: true);
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

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  double _text(Canvas c, String text, double y, {double size = 22, bool bold = false, bool center = false, double height = 1.25}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: Colors.black, height: height)),
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: ui.TextDirection.ltr,
      // 💖 FIX: บังคับ textScaler = TextScaler.noScaling
      // เพื่อให้ TextPainter ไม่ปรับขนาดฟอนต์ตามการตั้งค่าของเครื่อง
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: widthPx.toDouble() - 16); // มี padding ซ้ายขวานิดหน่อย

    final dx = center ? (widthPx - tp.width) / 2 : 8.0;
    tp.paint(c, Offset(dx, y));
    return tp.height + 6;
  }

  double _hr(Canvas c, double y) {
    return _text(c, '----------------------------------------', y, size: 20, center: true);
  }
}
