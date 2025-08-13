// lib/features/printing/render/preview_pages.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import 'receipt_renderer_mydent.dart';
import 'appointment_slip_renderer.dart';

/// พรีวิว "ใบเสร็จ" — รองรับแสดงบล็อก "นัดครั้งต่อไป" ด้วย
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
  Uint8List? _png;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final renderer = MyDentReceiptRenderer();
      final img = await renderer.renderWithLogoAsset(
        widget.receipt,
        logoAsset:
            'assets/images/logo_clinic.png', // ตามที่เพิ่มใน pubspec แล้ว
        logoTargetWidthPx: 160, // กว้าง ~160px กำลังสวยบน 80mm
        showNextAppointment:
            (widget.showNextAppt == true) && (widget.nextAppt != null),
        nextAppointment: widget.nextAppt,
      );
      final png = await renderer.toPngBytes(img);
      if (!mounted) return;
      setState(() {
        _png = png;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // optional: show UI message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('เรนเดอร์พรีวิวไม่สำเร็จ: $e')),
      // );
      print('Preview render failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ (80 มม.)')),
      body:
          _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child:
                      _png == null
                          ? const Text('ไม่พบภาพ')
                          : Image.memory(_png!, gaplessPlayback: true),
                ),
              ),
    );
  }
}

/// พรีวิว "ใบนัด" — ใช้เฉพาะโมเดลสลิป
class AppointmentSlipPreviewPage extends StatefulWidget {
  const AppointmentSlipPreviewPage({super.key, required this.slip});
  final AppointmentSlipModel slip;

  @override
  State<AppointmentSlipPreviewPage> createState() =>
      _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState
    extends State<AppointmentSlipPreviewPage> {
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
      body:
          _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child:
                      _png == null
                          ? const Text('ไม่พบภาพ')
                          : Image.memory(_png!, gaplessPlayback: true),
                ),
              ),
    );
  }
}
