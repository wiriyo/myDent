// lib/features/printing/render/appointment_slip_preview_page.dart
// v2 — ใบนัดมีโลโก้ + จับภาพปลอดภัยแบบ on-screen + รองรับโมเดล slip ที่ยืดหยุ่น
// - แสดงโลโก้คลินิกจาก assets/images/logo_clinic.png (ถ้าไม่พบจะข้าม)
// - ใช้ RepaintBoundary ในต้นไม้ UI แล้วค่อย toImage() หลัง endOfFrame
// - รับพารามิเตอร์เป็น `slip:` (จาก buildAppointmentSlip) และ map ฟิลด์อย่างยืดหยุ่น
// - ความกว้างฐาน 576px (เหมาะ 80mm)

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary; // ✅ สำหรับ cast
import 'package:flutter/services.dart' show rootBundle, ByteData;

import '../utils/th_format.dart';

class AppointmentSlipPreviewPage extends StatefulWidget {
  final dynamic slip; // รองรับทั้งโมเดล domain หรือ Map
  const AppointmentSlipPreviewPage({super.key, required this.slip});

  @override
  State<AppointmentSlipPreviewPage> createState() => _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState extends State<AppointmentSlipPreviewPage> {
  final _boundaryKey = GlobalKey();
  Uint8List? _png;
  bool _busy = false;
  ByteData? _logo; // โลโก้คลินิก
  late _SlipView _view; // มุมมองข้อมูลที่ UI ใช้จริง

  @override
  void initState() {
    super.initState();
    _view = _mapSlip(widget.slip);
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) setState(() => _logo = logo);
    } catch (_) {
      // ไม่มีโลโก้ก็ไม่เป็นไร — UI จะข้าม
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppointmentSlip: logo not found at assets/images/logo_clinic.png');
      }
    }
  }

  Future<void> _capturePng() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame; // ให้เฟรมปัจจุบันทาสีเสร็จ

      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ RepaintBoundary');
      }
      if (obj.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame; // รออีกเฟรมถ้ายังต้อง paint
      }

      final ui.Image image = await obj.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      setState(() => _png = byteData!.buffer.asUint8List());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกภาพใบนัดไว้ในหน่วยความจำแล้ว')),
      );
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppointmentSlip capture error: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('จับภาพไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
            child: _AppointmentSlipWidget(
              width: 576,
              clinicName: _view.clinicName,
              clinicAddress: _view.clinicAddress,
              clinicTel: _view.clinicPhone,
              patientName: _view.patientName,
              hn: _view.hn,
              dateTime: _view.startAt,
              note: _view.note,
              logoBytes: _logo,
            ),
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

  Future<void> _sendToPrinter() async {
    // TODO: ต่อปลั๊กอินพิมพ์ของคลินิกด้วย _png
    if (kDebugMode) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สาธิต: ส่งภาพ (${_png?.lengthInBytes ?? 0} bytes) ไปที่เครื่องพิมพ์')),
      );
    }
  }

  // ------------------ mapper ให้ยืดหยุ่นกับชนิดของ slip ------------------
  _SlipView _mapSlip(dynamic s) {
    String? _s(List<String> keys) {
      if (s == null) return null;
      for (final k in keys) {
        try {
          if (k.contains('.')) {
            final ps = k.split('.');
            dynamic cur = s;
            for (final p in ps) { cur = cur[p]; }
            if (cur is String) return cur;
          } else {
            final v = (s is Map) ? s[k] : s.___noMap___; // will throw
            if (v is String) return v;
          }
        } catch (_) {
          try { final v = s.toJson?[k]; if (v is String) return v; } catch (_) {}
        }
      }
      return null;
    }

    DateTime? _dt(List<String> keys) {
      for (final k in keys) {
        try { final v = (s is Map) ? s[k] : s.___noMap___; if (v is DateTime) return v; } catch (_) {}
        try { final v = s.toJson?[k]; if (v is DateTime) return v; } catch (_) {}
      }
      return null;
    }

    return _SlipView(
      clinicName: _s(const ['clinicName','clinic_name']) ?? 'คลินิกทันตกรรม',
      clinicAddress: _s(const ['clinicAddress','clinic_address','address']),
      clinicPhone: _s(const ['clinicPhone','clinicTel','phone','tel']),
      patientName: _s(const ['patientName','patient.name','name']) ?? '-',
      hn: _s(const ['hn','patient.hn']) ?? '',
      startAt: _dt(const ['startAt','start','dateTime','time']) ?? DateTime.now(),
      note: _s(const ['note','notes','remark']) ?? '',
    );
  }
}

class _SlipView {
  final String clinicName;
  final String? clinicAddress;
  final String? clinicPhone;
  final String patientName;
  final String hn;
  final DateTime startAt;
  final String note;
  _SlipView({
    required this.clinicName,
    this.clinicAddress,
    this.clinicPhone,
    required this.patientName,
    required this.hn,
    required this.startAt,
    required this.note,
  });
}

// --------------------- UI ของใบนัด (กว้าง ~576 px) ---------------------
class _AppointmentSlipWidget extends StatelessWidget {
  final double width; // 80mm ≈ 576px
  final String clinicName;
  final String? clinicAddress;
  final String? clinicTel;
  final String patientName;
  final String hn;
  final DateTime dateTime;
  final String note;
  final ByteData? logoBytes;

  const _AppointmentSlipWidget({
    required this.width,
    required this.clinicName,
    this.clinicAddress,
    this.clinicTel,
    required this.patientName,
    required this.hn,
    required this.dateTime,
    required this.note,
    this.logoBytes,
  });

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
              const SizedBox(height: 8),
            ],
            Center(
              child: Text(
                clinicName,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            if ((clinicAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(child: Text(clinicAddress!, textAlign: TextAlign.center)),
            ],
            if ((clinicTel ?? '').trim().isNotEmpty)
              Center(child: Text('โทร $clinicTel')),
            const SizedBox(height: 10),
            divider,
            const SizedBox(height: 10),
            const Center(
              child: Text('ใบนัด', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            _kv('ผู้ป่วย', patientName),
            if (hn.trim().isNotEmpty) _kv('HN', hn),
            _kv('วันที่นัด', ThFormat.dateThai(dateTime)),
            _kv('เวลา', ThFormat.timeThai(dateTime)),
            if (note.trim().isNotEmpty) _kv('หมายเหตุ', note),
            const SizedBox(height: 14),
            divider,
            const SizedBox(height: 24),
            const Row(
              children: [
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
      children: [
        Container(height: 1, color: Colors.black),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
