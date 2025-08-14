// ===============================================
// lib/features/printing/render/appointment_slip_preview_page.dart
// v3 — ใบนัด 80mm พร้อมโลโก้ (assets/images/logo_clinic.png)
//      มี RepaintBoundary จับภาพเป็น PNG ได้
// ===============================================
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary; // สำหรับ toImage
import 'package:flutter/services.dart' show rootBundle, ByteData;
import '../utils/th_format.dart';
import '../domain/appointment_slip_model.dart';

class AppointmentSlipPreviewPage extends StatefulWidget {
  final AppointmentSlipModel slip;
  const AppointmentSlipPreviewPage({super.key, required this.slip});

  @override
  State<AppointmentSlipPreviewPage> createState() => _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState extends State<AppointmentSlipPreviewPage> {
  final _boundaryKey = GlobalKey();
  ByteData? _logo;
  Uint8List? _png;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) setState(() => _logo = logo);
    } catch (_) {
      if (mounted) setState(() => _logo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบนัด (80mm)')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: _SlipWidget(width: 576, slip: widget.slip, logoBytes: _logo),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _capturePng,
                  icon: const Icon(Icons.image),
                  label: const Text('บันทึกเป็นภาพ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_png == null || _busy) ? null : _sendToPrinter,
                  icon: const Icon(Icons.print),
                  label: const Text('พิมพ์'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capturePng() async {
    if (_busy) return; setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) { throw Exception('ไม่พบ RepaintBoundary'); }
      if (obj.debugNeedsPaint) { await WidgetsBinding.instance.endOfFrame; }
      final ui.Image image = await obj.toImage(pixelRatio: 2.6);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return; setState(() => _png = byteData!.buffer.asUint8List());
      if (kDebugMode) debugPrint('Slip PNG: ${_png!.lengthInBytes} bytes');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('จับภาพไม่สำเร็จ: $e')));
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _sendToPrinter() async {
    if (kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สาธิต: ส่งภาพใบนัด (${_png?.lengthInBytes ?? 0} bytes) ไปเครื่องพิมพ์')),
      );
    }
  }
}

class _SlipWidget extends StatelessWidget {
  final double width; // ≈ 576px สำหรับ 80mm
  final AppointmentSlipModel slip;
  final ByteData? logoBytes;
  const _SlipWidget({required this.width, required this.slip, this.logoBytes});

  @override
  Widget build(BuildContext context) {
    final divider = Container(height: 1, color: Colors.black);
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 24, color: Colors.black, height: 1.25),
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
              const SizedBox(height: 6),
            ],
            Center(
              child: Text(
                slip.clinic.name,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            if (slip.clinic.address.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(child: Text(slip.clinic.address, textAlign: TextAlign.center)),
            ],
            if (slip.clinic.phone.trim().isNotEmpty)
              Center(child: Text('โทร ${slip.clinic.phone}')),
            const SizedBox(height: 10),
            divider,
            const SizedBox(height: 10),
            const Center(child: Text('ใบนัด', style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            _kv('ผู้ป่วย', slip.patient.name.isEmpty ? '-' : slip.patient.name),
            _kv('วันที่นัด', ThFormat.dateThai(slip.appointment.startAt)),
            _kv('เวลา', ThFormat.timeThai(slip.appointment.startAt)),
            if ((slip.appointment.note ?? '').trim().isNotEmpty)
              _kv('หมายเหตุ', slip.appointment.note!.trim()),
            const SizedBox(height: 14),
            divider,
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(child: _SignLine(label: 'ผู้ป่วย')),
                SizedBox(width: 18),
                Expanded(child: _SignLine(label: 'เจ้าหน้าที่')),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: Text('กรุณามาตามเวลานัด')),
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
}

class _SignLine extends StatelessWidget {
  final String label;
  const _SignLine({required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Divider(thickness: 1, height: 1, color: Colors.black),
        SizedBox(height: 4),
        // ignore: prefer_const_constructors
        Text(''),
      ],
    );
  }
}
