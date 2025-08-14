// lib/features/printing/render/receipt_renderer_mydent.dart
// PATCH v1.3 — แก้ assert '!debugNeedsPaint' ตอน toImage()
// - เรียก renderView.prepareInitialFrame() ก่อน build/flush
// - เพิ่มรอบ retry ถ้ายัง debugNeedsPaint ให้ flush อีกครั้งหลัง microtask
// - ไม่เปลี่ยน API เดิมของ MyDentReceiptRenderer.renderPng

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // ใช้ RenderView/PipelineOwner/ฯลฯ
import 'package:flutter/services.dart';
import '../utils/th_format.dart';

/// ===== โมเดลที่ renderer ใช้ =====
class ReceiptRenderData {
  final String receiptNo; // YY-NNN
  final DateTime issuedAt;
  final String clinicName;
  final String? clinicAddress;
  final String? clinicTel;
  final String patientName;
  final List<ReceiptItem> items;
  final num subtotal;
  final num discount;
  final num total;
  final num paid;
  final num change;
  final NextAppointmentBlock? nextAppointment; // ออปชัน: บล็อกใบนัดถัดไป

  ReceiptRenderData({
    required this.receiptNo,
    required this.issuedAt,
    required this.clinicName,
    this.clinicAddress,
    this.clinicTel,
    required this.patientName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.change,
    this.nextAppointment,
  });
}

class ReceiptItem {
  final String name;
  final int qty;
  final num price; // ต่อหน่วย
  const ReceiptItem({required this.name, required this.qty, required this.price});
  num get lineTotal => qty * price;
}

class NextAppointmentBlock {
  final DateTime dateTime;
  final String? note;
  const NextAppointmentBlock({required this.dateTime, this.note});
}

class MyDentReceiptRenderer {
  /// เรนเดอร์ Widget เป็น PNG bytes (ความกว้างฐาน ~576 สำหรับ 80mm)
  static Future<Uint8List> renderPng({
    required ReceiptRenderData data,
    ByteData? logoBytes,
    double logicalWidth = 576,
    double pixelRatio = 2.0,
    Brightness brightness = Brightness.light,
  }) async {
    // ---------- Offscreen render tree ----------
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final boundary = RenderRepaintBoundary();
    final positioned = RenderPositionedBox(alignment: Alignment.topLeft, child: boundary);

    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      configuration: ViewConfiguration(
        // เวอร์ชัน Flutter ปัจจุบันอนุญาตใส่เฉพาะ devicePixelRatio ได้
        devicePixelRatio: pixelRatio,
      ),
      child: positioned,
    );

    pipelineOwner.rootNode = renderView;
    // ✅ สำคัญ: เตรียมเฟรมแรก ไม่งั้น boundary อาจยังต้อง paint อยู่
    renderView.prepareInitialFrame();

    // ---------- Build โครง Widget ----------
    final widget = _ReceiptWidget(
      data: data,
      logoBytes: logoBytes,
      width: logicalWidth,
      brightness: brightness,
    );

    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          // ให้มี metrics คร่าว ๆ สำหรับ layout ด้านใน
          data: MediaQueryData(size: Size(logicalWidth, 2000)),
          child: _AutoMeasureHost(width: logicalWidth, child: widget),
        ),
      ),
    );

    final element = adapter.attachToRenderTree(buildOwner);
    buildOwner.buildScope(element);
    buildOwner.finalizeTree();

    // ---------- Flush จนพร้อม paint ----------
    void _flushAll() {
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();
    }

    _flushAll();

    // ถ้ายังต้องการ paint อยู่ ให้รอ microtask แล้ว flush อีกครั้ง
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(Duration.zero);
      _flushAll();
    }

    // ---------- Snapshot เป็น PNG ----------
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

/// Host จำกัดความกว้างสลิป และคุมพื้นหลัง
class _AutoMeasureHost extends StatelessWidget {
  final double width;
  final Widget child;
  const _AutoMeasureHost({required this.width, required this.child});
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }
}

class _ReceiptWidget extends StatelessWidget {
  final ReceiptRenderData data;
  final ByteData? logoBytes;
  final double width;
  final Brightness brightness;
  const _ReceiptWidget({
    required this.data,
    this.logoBytes,
    required this.width,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Container(height: 1, color: Colors.black);
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 22, color: Colors.black, height: 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logoBytes != null) ...[
              Center(
                child: Image.memory(
                  logoBytes!.buffer.asUint8List(),
                  width: 180,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Center(
              child: Text(
                data.clinicName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
            ),
            if (data.clinicAddress != null && data.clinicAddress!.trim().isNotEmpty)
              Center(child: Text(data.clinicAddress!, textAlign: TextAlign.center)),
            if (data.clinicTel != null && data.clinicTel!.trim().isNotEmpty)
              Center(child: Text('โทร ${data.clinicTel!}')),
            const SizedBox(height: 8),
            divider,
            const SizedBox(height: 8),
            _kv('เลขที่ใบเสร็จ', data.receiptNo),
            _kv('วันที่', ThFormat.dateThai(data.issuedAt)),
            _kv('เวลา', ThFormat.timeThai(data.issuedAt)),
            _kv('ผู้ป่วย', data.patientName),
            const SizedBox(height: 8),
            divider,
            const SizedBox(height: 8),
            _itemsTable(data.items),
            const SizedBox(height: 6),
            divider,
            const SizedBox(height: 6),
            _kv('รวมก่อนส่วนลด', ThFormat.baht(data.subtotal)),
            _kv('ส่วนลด', ThFormat.baht(data.discount)),
            _kvBold('รวมสุทธิ', ThFormat.baht(data.total)),
            const SizedBox(height: 2),
            _kv('รับเงิน', ThFormat.baht(data.paid)),
            _kv('เงินทอน', ThFormat.baht(data.change)),
            const SizedBox(height: 10),
            if (data.nextAppointment != null) ...[
              divider,
              const SizedBox(height: 8),
              const Center(child: Text('ใบนัดครั้งถัดไป', style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 6),
              _kv('วันที่นัด', ThFormat.dateThai(data.nextAppointment!.dateTime)),
              _kv('เวลา', ThFormat.timeThai(data.nextAppointment!.dateTime)),
              if ((data.nextAppointment!.note ?? '').trim().isNotEmpty)
                _kv('หมายเหตุ', data.nextAppointment!.note!),
            ],
            const SizedBox(height: 10),
            const Center(child: Text('ขอบคุณที่ใช้บริการ')),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k)),
          const SizedBox(width: 10),
          Expanded(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _kvBold(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsTable(List<ReceiptItem> items) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 6, child: Text('รายการ')),
            Expanded(flex: 2, child: Text('จำนวน', textAlign: TextAlign.right)),
            Expanded(flex: 3, child: Text('ราคา', textAlign: TextAlign.right)),
            Expanded(flex: 3, child: Text('รวม', textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 4),
        for (final it in items) _itemRow(it),
      ],
    );
  }

  Widget _itemRow(ReceiptItem it) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: Text(it.name)),
          Expanded(flex: 2, child: Text('${it.qty}', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(ThFormat.baht(it.price), textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(ThFormat.baht(it.lineTotal), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
