// lib/features/printing/render/preview_pages.dart
export 'appointment_slip_preview_page.dart' show AppointmentSlipPreviewPage;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;

import '../utils/th_format.dart';

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
  Uint8List? _lastPng;
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
      logo = null;
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
      await WidgetsBinding.instance.endOfFrame;
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ RepaintBoundary');
      }
      if (obj.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      final ui.Image image = await obj.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      setState(() => _lastPng = byteData!.buffer.asUint8List());
    } catch (e) {
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
          final v = (o is Map) ? o[k] : o.___noMap___;
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

  ReceiptRenderData _sampleData() {
    return ReceiptRenderData(
      receiptNo: '68-001',
      issuedAt: DateTime.now(),
      clinicName: 'คลินิกทันตกรรมหมอกุสุมาภรณ์',
      clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
      clinicTel: '094-5639334',
      patientName: 'นาย อรุณ วิริโยคุณ',
      items: [
        const ReceiptItem(name: 'ถอน (#11)', qty: 1, price: 600),
      ],
      subtotal: 600,
      discount: 0,
      total: 600,
      paid: 600,
      change: 0,
    );
  }
}

class ReceiptRenderData {
  final String receiptNo;
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
  final NextAppointmentBlock? nextAppointment;
  const ReceiptRenderData({
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
  final num price;
  const ReceiptItem({required this.name, required this.qty, required this.price});
  num get lineTotal => qty * price;
}

class NextAppointmentBlock {
  final DateTime dateTime;
  final String? note;
  const NextAppointmentBlock({required this.dateTime, this.note});
}

class _ReceiptPreviewWidget extends StatelessWidget {
  final ReceiptRenderData data;
  final ByteData? logoBytes;
  final double width;
  const _ReceiptPreviewWidget({required this.data, required this.logoBytes, required this.width});

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 6),
            ],
            Center(
              child: Text(
                data.clinicName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
            ),
            if ((data.clinicAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(child: Text(data.clinicAddress!, textAlign: TextAlign.center)),
            ],
            if ((data.clinicTel ?? '').trim().isNotEmpty)
              Center(child: Text('โทร. ${data.clinicTel!}')),
            const SizedBox(height: 6),
            const Center(child: Text('*********************')),
            const SizedBox(height: 8),
            _kv('เลขที่', data.receiptNo),
            _kv('วันที่', ThFormat.dateThai(data.issuedAt)),
            _kv('เวลา', ThFormat.timeThai(data.issuedAt)),
            _kv('ชื่อ', ''),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(data.patientName, textAlign: TextAlign.right),
              ),
            ),
            _kv('หัตถการ:', data.items.isNotEmpty ? data.items.first.name : '-'),
            _kv('ค่าบริการ', ThFormat.baht(data.total)),
            const SizedBox(height: 18),
            if (data.nextAppointment != null) ...[
              const Divider(height: 20, thickness: 1),
              const Center(child: Text('ใบนัดครั้งถัดไป', style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 6),
              _kv('วันที่นัด', ThFormat.dateThai(data.nextAppointment!.dateTime)),
              _kv('เวลา', ThFormat.timeThai(data.nextAppointment!.dateTime)),
              if ((data.nextAppointment!.note ?? '').trim().isNotEmpty)
                _kv('หมายเหตุ', data.nextAppointment!.note!),
              const SizedBox(height: 10),
            ],
            const Center(child: Text('ขอบคุณที่ใช้บริการ')),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
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
