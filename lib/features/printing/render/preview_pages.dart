import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import 'receipt_renderer.dart';
import 'appointment_slip_renderer.dart';

/// พรีวิวใบเสร็จ (80mm) และ (ออปชัน) แสดงบล็อก "นัดต่อไป" ต่อท้าย
///
/// หมายเหตุ: ไม่แตะลายเซ็นของ ReceiptRenderer.render()
/// ถ้า showNextAppt == true และมี nextAppt จะเรนเดอร์ใบนัดเป็นภาพแยกแล้วแสดงต่อท้าย
class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({
    super.key,
    required this.receipt,
    this.showNextAppt = false,
    this.nextAppt,
  });

  final ReceiptModel receipt;
  final bool showNextAppt;
  final AppointmentInfo? nextAppt;

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  Uint8List? _pngReceipt;
  Uint8List? _pngNextAppt;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() => _busy = true);

    // 1) เรนเดอร์ใบเสร็จเป็นภาพ
    final receiptRenderer = ReceiptRenderer();
    final receiptImg = await receiptRenderer.render(widget.receipt);
    final receiptBytes = await receiptRenderer.toPngBytes(receiptImg);

    Uint8List? apptBytes;

    // 2) ถ้าต้องการแสดงบล็อกใบนัด → เรนเดอร์ใบนัดเป็นภาพแยก
    if (widget.showNextAppt && widget.nextAppt != null) {
      final slip = AppointmentSlipModel(
        clinic: widget.receipt.clinic,
        patient: widget.receipt.patient,
        appointment: AppointmentInfo(
          startAt: widget.nextAppt!.startAt,
          note: widget.nextAppt!.note,
        ),
      );
      final apptRenderer = AppointmentSlipRenderer();
      final apptImg = await apptRenderer.render(slip);
      final apptByteData = await apptImg.toByteData(format: ui.ImageByteFormat.png);
      apptBytes = apptByteData?.buffer.asUint8List();
    }

    if (!mounted) return;
    setState(() {
      _pngReceipt = receiptBytes;
      _pngNextAppt = apptBytes;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ (80mm)')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    if (_pngReceipt != null) Image.memory(_pngReceipt!, gaplessPlayback: true),
                    if (_pngNextAppt != null) ...[
                      const SizedBox(height: 16),
                      Image.memory(_pngNextAppt!, gaplessPlayback: true),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// พรีวิว "ใบนัด" เดี่ยว ๆ (ใช้ทดสอบเลย์เอาต์ใบนัดโดยไม่ผ่านใบเสร็จ)
class AppointmentSlipPreviewPage extends StatefulWidget {
  const AppointmentSlipPreviewPage({super.key, required this.slip});
  final AppointmentSlipModel slip;

  @override
  State<AppointmentSlipPreviewPage> createState() => _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState extends State<AppointmentSlipPreviewPage> {
  Uint8List? _png;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() => _busy = true);
    final renderer = AppointmentSlipRenderer();
    final img = await renderer.render(widget.slip);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    setState(() {
      _png = byteData?.buffer.asUint8List();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบนัด')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _png == null
                    ? const Text('ไม่พบภาพ')
                    : Image.memory(_png!, gaplessPlayback: true),
              ),
            ),
    );
  }
}
