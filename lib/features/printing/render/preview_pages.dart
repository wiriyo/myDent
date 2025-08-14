export 'appointment_slip_preview_page.dart' show AppointmentSlipPreviewPage;

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
  const ReceiptPreviewPage({super.key, this.receipt, this.showNextAppt = false, this.nextAppt});
  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _boundaryKey = GlobalKey();
  Uint8List? _png;
  bool _busy = false;
  ByteData? _logo;

  @override
  void initState() {
    super.initState();
    _loadLogo().then((_) => _render());
  }

  Future<void> _loadLogo() async {
    try {
      _logo = await rootBundle.load('assets/images/logo_clinic.png');
    } catch (_) {
      _logo = null;
    }
  }

  Future<void> _render() async {
    if (!mounted) return; setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) throw Exception('boundary not found');
      if (obj.debugNeedsPaint) { await WidgetsBinding.instance.endOfFrame; }
      final ui.Image image = await obj.toImage(pixelRatio: 2.6);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return; setState(() => _png = byteData!.buffer.asUint8List());
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('ReceiptPreview render error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เรนเดอร์ใบเสร็จไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.receipt == null
        ? _sampleData()
        : _mapToRenderData(widget.receipt, showNextAppt: widget.showNextAppt, nextAppt: widget.nextAppt);
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ (80mm)')),
      body: Center(
        child: Stack(
          children: [
            if (_png != null)
              SingleChildScrollView(padding: const EdgeInsets.all(12), child: Image.memory(_png!))
            else if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              const Center(child: Text('ไม่มีภาพ')),
            IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _ReceiptWidget(width: 576, data: data, logoBytes: _logo),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _render,
                  icon: const Icon(Icons.refresh),
                  label: const Text('เรนเดอร์ใหม่'),
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('สาธิต: ส่งภาพ ${_png?.lengthInBytes ?? 0} bytes ไปเครื่องพิมพ์')));
  }

  ReceiptRenderData _sampleData() {
    return ReceiptRenderData(
      receiptNo: '68-001',
      issuedAt: DateTime.now(),
      clinicName: 'คลินิกทันตกรรมหมอกุสุมาภรณ์',
      clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
      clinicTel: '094-5639334',
      patientName: 'นาย อรุณ วิริโยคุณ',
      items: [ReceiptItem(name: 'ถอน (#11)', qty: 1, price: 600)],
      subtotal: 600,
      discount: 0,
      total: 600,
      paid: 600,
      change: 0,
    );
  }

  ReceiptRenderData _mapToRenderData(dynamic r, {required bool showNextAppt, dynamic nextAppt}) {
    String clinicName = _getS(r, ['clinic.name', 'clinicName']) ?? 'คลินิกทันตกรรม';
    String? clinicAddr = _getS(r, ['clinic.address', 'clinicAddress', 'address']);
    String? clinicTel = _getS(r, ['clinic.phone', 'clinicTel', 'phone', 'tel']);
    String billNo = _getS(r, ['bill.billNo', 'billNo', 'receiptNo']) ?? '00-001';
    DateTime issuedAt = _getDt(r, ['bill.issuedAt', 'issuedAt', 'createdAt']) ?? DateTime.now();
    String patient = _getS(r, ['patient.name', 'patientName', 'name']) ?? '-';
    final items = _getItems(r);
    num subtotal = _getN(r, ['totals.subTotal', 'subtotal', 'subTotal']) ?? items.fold<num>(0, (s, it) => s + it.lineTotal);
    num discount = _getN(r, ['totals.discount', 'discount']) ?? 0;
    num total = _getN(r, ['totals.grandTotal', 'grandTotal', 'total']) ?? (subtotal - discount);
    num paid = _getN(r, ['paid']) ?? total;
    num change = _getN(r, ['change']) ?? 0;
    NextAppointmentBlock? next;
    if (showNextAppt && nextAppt != null) {
      final dt = _getDt(nextAppt, ['startAt', 'start', 'dateTime', 'time']);
      final note = _getS(nextAppt, ['note', 'notes', 'remark']);
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
      total: total < 0 ? 0 : total,
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
          final v = (o is Map) ? o[k] : null;
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
      try { final v = (o is Map) ? o[k] : null; if (v is num) return v; } catch (_) {}
      try { final v = o.toJson?[k]; if (v is num) return v; } catch (_) {}
    }
    return null;
  }

  DateTime? _getDt(dynamic o, List<String> keys) {
    for (final k in keys) {
      try { final v = (o is Map) ? o[k] : null; if (v is DateTime) return v; } catch (_) {}
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

class _ReceiptWidget extends StatelessWidget {
  final double width;
  final ReceiptRenderData data;
  final ByteData? logoBytes;
  const _ReceiptWidget({required this.width, required this.data, this.logoBytes});
  @override
  Widget build(BuildContext context) {
    final firstItemName = data.items.isNotEmpty ? data.items.first.name : '-';
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
            _kv('หัตถการ:', firstItemName),
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
