// lib/features/printing/render/preview_pages.dart
// v4.1 — แก้ error "RenderRepaintBoundary isn't a type" ด้วยการ import rendering
// และทำ safe-capture: ตรวจชนิดก่อนแคปเจอร์ + รอ endOfFrame ชัวร์
// 
// ✅ ไม่แตะไฟล์ renderer เดิมของพี่
// ✅ คงพารามิเตอร์เดิม ReceiptPreviewPage({receipt, showNextAppt, nextAppt})
// ✅ export AppointmentSlipPreviewPage เหมือนเดิม

export 'appointment_slip_preview_page.dart' show AppointmentSlipPreviewPage;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary; // ✅ สำคัญ
import 'package:flutter/services.dart' show rootBundle, ByteData;

import '../utils/th_format.dart';
import 'receipt_renderer_mydent.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final dynamic receipt;
  final bool showNextAppt;
  final dynamic nextAppt;

  const ReceiptPreviewPage({
    super.key,
    this.receipt,
    this.showNextAppt = false,
    this.nextAppt,
  });

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _boundaryKey = GlobalKey();
  ReceiptRenderData? _data;
  ByteData? _logo;
  Uint8List? _lastPng; // เก็บไว้ส่งพิมพ์/แชร์
  bool _busyCapture = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final data = widget.receipt == null
        ? _sampleData()
        : _mapToRenderData(widget.receipt, showNextAppt: widget.showNextAppt, nextAppt: widget.nextAppt);

    ByteData? logo;
    try {
      logo = await rootBundle.load('assets/images/logo_clinic.png');
    } catch (_) {
      logo = null; // ไม่มีโลโก้ก็ไปต่อได้
    }

    if (!mounted) return;
    setState(() {
      _data = data;
      _logo = logo;
    });
  }

  Future<void> _capturePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      // รอให้วาดเฟรมเสร็จจริง ๆ
      await WidgetsBinding.instance.endOfFrame;

      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ RepaintBoundary');
      }

      // กันเคสยังต้อง paint อยู่
      if (obj.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }

      final ui.Image image = await obj.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      setState(() => _lastPng = byteData!.buffer.asUint8List());

      if (kDebugMode) {
        // ignore: avoid_print
        print('Receipt PNG captured: ${_lastPng!.lengthInBytes} bytes');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกภาพพรีวิวไว้ในหน่วยความจำแล้ว')),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('capture PNG error: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('จับภาพไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ (80mm)')),
      body: Center(
        child: _data == null
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _ReceiptPreviewWidget(
                    data: _data!,
                    logoBytes: _logo,
                    width: 576,
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
                  onPressed: _busyCapture || _data == null ? null : _capturePng,
                  icon: const Icon(Icons.image),
                  label: const Text('บันทึกเป็นภาพ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_lastPng == null || _busyCapture) ? null : _sendToPrinter,
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
    if (kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สาธิต: ส่งภาพ (${_lastPng?.lengthInBytes ?? 0} bytes) ไปที่เครื่องพิมพ์')),
      );
    }
  }

  // ------------------------- Mapper -------------------------
  ReceiptRenderData _mapToRenderData(dynamic r, {required bool showNextAppt, dynamic nextAppt}) {
    final clinicName = _getS(r, ['clinicName', 'clinic_name']) ?? 'คลินิกทันตกรรม';
    final clinicAddr = _getS(r, ['clinicAddress', 'clinic_address', 'address']);
    final clinicTel  = _getS(r, ['clinicPhone', 'clinicTel', 'phone', 'tel']);
    final billNo     = _getS(r, ['billNo', 'receiptNo', 'bill_no', 'receipt_no']) ?? '00-001';
    final issuedAt   = _getDt(r, ['issuedAt', 'createdAt']) ?? DateTime.now();
    final patient    = _getS(r, ['patientName', 'patient.name', 'name']) ?? '-';

    final items = _getItems(r);
    num subtotal = _getN(r, ['subTotal','subtotal']) ?? items.fold<num>(0, (s, it) => s + it.lineTotal);
    final discount = _getN(r, ['discount']) ?? 0;
    num total = _getN(r, ['grandTotal','total']) ?? (subtotal - discount);
    if (total < 0) total = 0;

    final paid = _getN(r, ['paid']) ?? total;
    final change = _getN(r, ['change']) ?? 0;

    NextAppointmentBlock? next;
    if (showNextAppt && nextAppt != null) {
      final dt = _getDt(nextAppt, ['startAt','start','dateTime','time']);
      final note = _getS(nextAppt, ['note','notes','remark']);
      if (dt != null) next = NextAppointmentBlock(dateTime: dt, note: note);
    }

    return ReceiptRenderData(
      receiptNo: billNo,
      issuedAt: issuedAt,
      clinicName: clinicName,
      clinicAddress: clinicAddr,
      clinicTel: clinicTel,
      patientName: patient,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paid: paid,
      change: change,
      nextAppointment: next,
    );
  }

  String? _getS(dynamic o, List<String> keys) {
    if (o == null) return null;
    for (final k in keys) {
      try {
        if (k.contains('.')) {
          final parts = k.split('.');
          dynamic cur = o;
          for (final p in parts) { cur = cur[p]; }
          if (cur is String) return cur;
        } else {
          final v = (o is Map) ? o[k] : o.___noMap___; // will throw
          if (v is String) return v;
        }
      } catch (_) {
        try { final v = o.toJson?[k]; if (v is String) return v; } catch (_) {}
      }
    }
    return null;
  }

  num? _getN(dynamic o, List<String> keys) {
    for (final k in keys) {
      try { final v = (o is Map) ? o[k] : o.___noMap___; if (v is num) return v; } catch (_) {}
      try { final v = o.toJson?[k]; if (v is num) return v; } catch (_) {}
    }
    return null;
  }

  DateTime? _getDt(dynamic o, List<String> keys) {
    for (final k in keys) {
      try { final v = (o is Map) ? o[k] : o.___noMap___; if (v is DateTime) return v; } catch (_) {}
      try { final v = o.toJson?[k]; if (v is DateTime) return v; } catch (_) {}
    }
    return null;
  }

  List<ReceiptItem> _getItems(dynamic r) {
    dynamic raw;
    try { raw = r.items; } catch (_) {}
    raw ??= (r is Map ? r['items'] : null);
    if (raw is! List) return [ReceiptItem(name: 'ค่าบริการ', qty: 1, price: 0)];
    final out = <ReceiptItem>[];
    for (final it in raw) {
      String name = '-'; int qty = 1; num price = 0;
      try { name = it.name as String; } catch (_) { if (it is Map && it['name'] is String) name = it['name']; }
      try { qty = (it.qty as num).toInt(); } catch (_) { if (it is Map && it['qty'] is num) qty = (it['qty'] as num).toInt(); }
      try { price = it.price as num; } catch (_) { if (it is Map && it['price'] is num) price = it['price']; }
      out.add(ReceiptItem(name: name, qty: qty, price: price));
    }
    return out.isEmpty ? [ReceiptItem(name: 'ค่าบริการ', qty: 1, price: 0)] : out;
  }

  // ---------- sample ----------
  ReceiptRenderData _sampleData() {
    return ReceiptRenderData(
      receiptNo: '68-001',
      issuedAt: DateTime.now(),
      clinicName: 'MyDent Dental Clinic',
      clinicAddress: '123/4 ถนนสุขุมวิท เขตบางนา กรุงเทพมหานคร 10260',
      clinicTel: '02-123-4567',
      patientName: 'คุณสายรุ้ง ทองดี',
      items: [
        ReceiptItem(name: 'อุดฟันสีเหมือนฟัน', qty: 1, price: 1200),
        ReceiptItem(name: 'ขูดหินปูน + ขัด', qty: 1, price: 900),
        ReceiptItem(name: 'ยาแก้ปวด (10 เม็ด)', qty: 1, price: 80),
      ],
      subtotal: 2180,
      discount: 180,
      total: 2000,
      paid: 2000,
      change: 0,
    );
  }
}

// ====================== หน้าพรีวิว (Widget จริง) ======================
class _ReceiptPreviewWidget extends StatelessWidget {
  final ReceiptRenderData data;
  final ByteData? logoBytes;
  final double width; // 80mm ≈ 576px
  const _ReceiptPreviewWidget({required this.data, required this.logoBytes, required this.width});

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
