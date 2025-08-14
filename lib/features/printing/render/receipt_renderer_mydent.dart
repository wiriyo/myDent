// lib/features/printing/render/receipt_renderer_mydent.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';

/// โหลดรูปจาก assets แล้วบีบให้กว้างตามต้องการ (พิกเซล)
Future<ui.Image?> loadClinicLogo({
  String assetPath = 'assets/images/logo_clinic.png',
  int targetWidthPx = 160,
}) async {
  try {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidthPx,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (e) {
    debugPrint('❌ Load clinic logo failed: $e');
    return null;
  }
}

class MyDentReceiptRenderer {
  // กว้างหน้ากระดาษ 80 มม. ส่วนมาก ~ 576px (ขึ้นกับเครื่อง/ความละเอียด)
  static const double paperW = 576;
  static const double pad = 24;
  static const double lh = 32; // base line height

  /// ฟังก์ชันช่วย เรียกง่าย ๆ พร้อมโหลดโลโก้จาก assets ให้เลย
  Future<ui.Image> renderWithLogoAsset(
    ReceiptModel model, {
    String logoAsset = 'assets/images/logo_clinic.png',
    int logoTargetWidthPx = 160,
    bool showNextAppointment = false,
    AppointmentInfo? nextAppointment,
  }) async {
    final logo = await loadClinicLogo(
      assetPath: logoAsset,
      targetWidthPx: logoTargetWidthPx,
    );
    return render(
      model,
      showNextAppointment: showNextAppointment,
      nextAppointment: nextAppointment,
      logo: logo,
    );
  }

  /// เรนเดอร์ใบเสร็จเป็นภาพ (ใช้ในพรีวิว/พิมพ์จริงก็ได้)
  Future<ui.Image> render(
    ReceiptModel model, {
    bool showNextAppointment = false,
    AppointmentInfo? nextAppointment,
    ui.Image? logo,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, paperW, 2200), // เว้นเผื่อความสูง แล้วค่อย crop ท้าย
    );

    // BG ขาว
    canvas.drawRect(
      Rect.fromLTWH(0, 0, paperW, 2200),
      Paint()..color = Colors.white,
    );

    double y = pad;

    // 1) LOGO (ถ้ามี)
    if (logo != null) {
      final logoW = logo.width.toDouble(); // โหลดมาบีบกว้างไว้แล้วจาก helper
      final logoH = logo.height.toDouble();
      final dx = (paperW - logoW) / 2;
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(dx, y, logoW, logoH),
        Paint(),
      );
      y += logoH + 8;
    }

    // 2) ส่วนหัวคลินิก (กึ่งกลาง)
    y = _textCenter(canvas, model.clinic.name, y, 22, FontWeight.w700);
    if (model.clinic.address.trim().isNotEmpty) {
      y = _textCenter(canvas, model.clinic.address, y, 18, FontWeight.w400);
    }
    if (model.clinic.phone.trim().isNotEmpty) {
      y = _textCenter(canvas, 'โทร. ${model.clinic.phone}', y, 18, FontWeight.w400);
    }

    // 3) เส้นดาว
    y += 6;
    y = _divider(canvas, y, pattern: '****************');

    // 4) กล่องมุมขวา: เลขที่ + วันที่ไทย (อยู่ด้านขวาทั้งคู่)
    final billNoText = 'เลขที่  ${model.bill.billNo}';
    final issuedText = _formatThaiDate(model.bill.issuedAt);
    y += 6;
    y = _textRight(canvas, billNoText, y, 18, FontWeight.w600);
    y = _textRight(canvas, issuedText, y, 18, FontWeight.w400);
    y += 8;

    // 5) บล็อกผู้รับบริการ + รายการ
    y = _kv(canvas, 'ผู้รับบริการ:', model.patient.name, y);

    // ✅ สรุปรายการจากบรรทัดแรก (ดีไซน์ของพี่: 1 ไอเท็มหลัก, ไม่คิด VAT แยก)
    final firstLine = model.lines.isNotEmpty ? model.lines.first : null;
    final proc = firstLine?.name ?? '-';
    final qty = firstLine?.qty ?? 1;
    final price = firstLine?.price ?? 0;
    final service = qty > 1 ? '$proc x$qty' : proc;

    y = _kv(canvas, 'การรักษา:', service, y);

    // ดึงซี่ฟันจากชื่อรายการแบบคร่าว ๆ (#11)
    final tooth = _extractTooth(proc);
    if (tooth != null) {
      y = _kv(canvas, 'ซี่ฟัน:', tooth, y);
    }

    y = _kv(canvas, 'ค่าบริการ:', _formatBaht(model.totals.grandTotal), y);

    // 6) เส้นคั่น
    y += 6;
    y = _rule(canvas, y);

    // 7) บล็อก “นัดต่อไป” (ถ้าขอให้แสดง และมีข้อมูล)
    if (showNextAppointment && nextAppointment != null) {
      y = _textCenter(canvas, 'นัดต่อไป', y + 6, 20, FontWeight.w700);
      y = _kv(canvas, 'วัน:', _formatThaiDate(nextAppointment.startAt), y);
      y = _kv(canvas, 'เวลา:', _formatTime(nextAppointment.startAt), y);
      if ((nextAppointment.note ?? '').trim().isNotEmpty) {
        y = _kv(canvas, 'หมายเหตุ:', nextAppointment.note!.trim(), y);
      }
      y += 6;
      y = _rule(canvas, y);
    }

    // 8) ข้อความกำกับท้ายบิล
    y = _textCenter(canvas, 'กรุณามาก่อนนัดหมาย 10–15 นาที', y + 6, 18, FontWeight.w400);
    y = _textCenter(canvas, 'ขอบคุณที่ใช้บริการ', y + 2, 18, FontWeight.w600);

    // ปิดภาพ + crop ความสูงจริง
    final picture = recorder.endRecording();
    final img = await picture.toImage(paperW.toInt(), (y + pad).ceil());
    return img;
  }

  /// แปลงภาพ → PNG bytes (เอาไปแสดงใน Image.memory หรือส่งพิมพ์)
  Future<Uint8List> toPngBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ================= helpers (วาดข้อความ/เส้น) =================

  double _textCenter(Canvas c, String text, double y, double size, FontWeight w) {
    final tp = _tp(text, size, w, TextAlign.center);
    tp.layout(maxWidth: paperW - (pad * 2));
    tp.paint(c, Offset(pad, y));
    return y + math.max(lh, tp.height + 2);
  }

  double _textRight(Canvas c, String text, double y, double size, FontWeight w) {
    final tp = _tp(text, size, w, TextAlign.right);
    tp.layout(maxWidth: paperW - (pad * 2));
    tp.paint(c, Offset(pad, y));
    return y + math.max(lh, tp.height + 2);
  }

  double _kv(Canvas c, String k, String v, double y) {
    const keyW = 140.0;
    final tpK = _tp(k, 18, FontWeight.w600, TextAlign.left)..layout(maxWidth: keyW);
    final tpV = _tp(v, 18, FontWeight.w400, TextAlign.left)
      ..layout(maxWidth: paperW - pad * 2 - keyW - 8);

    tpK.paint(c, Offset(pad, y));
    tpV.paint(c, Offset(pad + keyW + 8, y));

    final h = math.max(tpK.height, tpV.height);
    return y + math.max(lh, h + 2);
  }

  double _divider(Canvas c, double y, {String pattern = '****************'}) {
    final tp = _tp(pattern, 18, FontWeight.w600, TextAlign.center)
      ..layout(maxWidth: paperW - pad * 2);
    tp.paint(c, Offset(pad, y));
    return y + math.max(lh, tp.height + 2);
  }

  double _rule(Canvas c, double y) {
    final paint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    c.drawLine(Offset(pad, y), Offset(paperW - pad, y), paint);
    return y + 8;
  }

  TextPainter _tp(String text, double size, FontWeight w, TextAlign align) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: w,
          color: Colors.black,
          height: 1.15,
          // ถ้ามีพิมพ์ไทยเฉพาะ ให้กำหนดฟอนต์ เช่น:
          // fontFamily: 'NotoSansThai',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      // maxLines: null = ไม่จำกัดบรรทัด (จะตัดคำให้อัตโนมัติภายใน maxWidth)
      maxLines: null,
      ellipsis: null,
    );
  }

  String _formatThaiDate(DateTime dt) {
    // ตัวอย่างที่ต้องการ: อังคาร 12 สิงหาคม 2568
    final base = DateFormat('EEEE d MMMM yyyy', 'th_TH').format(dt);
    final be = dt.year + 543;
    final parts = base.split(' ');
    if (parts.isNotEmpty) {
      parts[parts.length - 1] = be.toString();
    }
    return parts.join(' ');
  }

  String _formatTime(DateTime dt) => '${DateFormat('HH:mm', 'th_TH').format(dt)} น.';

  String _formatBaht(num n) {
    final f = NumberFormat('#,##0.##', 'th_TH');
    return '${f.format(n)} บาท';
  }

  String? _extractTooth(String name) {
    // หา #ตัวเลข เช่น #11
    final re = RegExp(r'#\d+');
    final m = re.firstMatch(name);
    return m?.group(0);
  }
}
