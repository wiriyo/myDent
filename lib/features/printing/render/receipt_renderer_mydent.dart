import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import '../utils/th_format.dart';
import '../services/thermal_printer_service.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final dynamic receipt;
  final bool showNextAppt;
  final dynamic nextAppt;
  final bool useSampleData;
  const ReceiptPreviewPage({super.key, this.receipt, this.showNextAppt = false, this.nextAppt, this.useSampleData = false});
  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _boundaryKey = GlobalKey();
  ReceiptRenderData? _data;
  ByteData? _logo;
  Uint8List? _lastPng;
  bool _busyCapture = false;
  // ✨ NEW: เพิ่มตัวแปรสำหรับเช็คสถานะ loading ค่ะ
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      // ✨ IMPROVED: ปรับ logic การเลือกข้อมูลให้ชัดเจนขึ้น
      final data = (widget.useSampleData || widget.receipt == null)
          ? _sampleData()
          : _mapToRenderData(widget.receipt, showNextAppt: widget.showNextAppt, nextAppt: widget.nextAppt);

      final logo = await _loadLogo();
      if (!mounted) return;
      
      // พอเตรียมข้อมูลเสร็จ ก็บอกว่า loading เสร็จแล้วน้า
      setState(() {
        _data = data;
        _logo = logo;
        _isLoading = false;
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('prepare error: $e\n$st');
      if (mounted) {
        setState(() {
          _data = _sampleData(); // ถ้ามีปัญหา ให้ใช้ข้อมูลตัวอย่างไปก่อน
          _isLoading = false;
        });
      }
    }
  }

  Future<ByteData?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/imgaes/logo_clinic.png');
      return data;
    } catch (_) {
      // ถ้าหาโลโก้ไม่เจอ จะ return null ไปเงียบๆ ค่ะ
      return null;
    }
  }

  Future<void> _capturePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await WidgetsBinding.instance.endOfFrame;
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ RepaintBoundary');
      }
      if (obj.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      final ui.Image image = await obj.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      setState(() => _lastPng = byteData!.buffer.asUint8List());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพเรียบร้อย')));
    } catch (e, st) {
      if (kDebugMode) debugPrint('capture error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('จับภาพไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _print() async {
    if (_lastPng == null) {
      await _capturePng();
    }
    if (_lastPng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')));
      return;
    }
    await ThermalPrinterService.instance.ensureConnectAndPrintPng(context, _lastPng!, feed: 3, cut: true);
  }

  @override
  Widget build(BuildContext context) {
    // ✨ NEW: ถ้ายัง loading อยู่ ให้โชว์วงกลมหมุนๆ น่ารักๆ ไปก่อน
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('พรีวิวใบเสร็จ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // พอโหลดเสร็จแล้ว เรามั่นใจได้เลยว่า _data ไม่ใช่ null แน่นอน
    final renderData = _data!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('พรีวิวใบเสร็จ'),
        actions: [
          IconButton(onPressed: _busyCapture ? null : _capturePng, icon: const Icon(Icons.image_outlined), tooltip: 'บันทึกเป็นภาพ'),
          IconButton(onPressed: _busyCapture ? null : _print, icon: const Icon(Icons.print), tooltip: 'พิมพ์'),
        ],
      ),
      body: Center(
        child: SingleChildScrollView( // ✨ Added SingleChildScrollView for long receipts
          child: ColoredBox(
            color: Colors.white,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints.tightFor(width: 576),
                child: MyDentReceiptRenderer(
                  data: renderData,
                  logo: _logo,
                  showNextAppointment: widget.showNextAppt,
                  nextAppointment: widget.nextAppt,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: FilledButton.icon(onPressed: _busyCapture ? null : _capturePng, icon: const Icon(Icons.image), label: const Text('บันทึกเป็นภาพ'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(onPressed: _busyCapture ? null : _print, icon: const Icon(Icons.print), label: const Text('พิมพ์'))),
          ],
        ),
      ),
    );
  }
  
  // ... (ส่วนที่เหลือของโค้ดเหมือนเดิมค่ะ)
  ReceiptRenderData _mapToRenderData(dynamic r, {required bool showNextAppt, dynamic nextAppt}) {
    String clinicName = _readString(r, ['clinicName', 'clinic_name']) ?? 'คลินิกทันตกรรมหมอกุสุมาภรณ์';
    String? clinicAddr = _readString(r, ['clinicAddress', 'clinic_address', 'address']);
    String? clinicTel = _readString(r, ['clinicPhone', 'clinicTel', 'phone', 'tel']);
    String billNo = _readString(r, ['billNo', 'receiptNo', 'bill_no', 'receipt_no']) ?? '00-001';
    DateTime issuedAt = _readDateTime(r, ['issuedAt', 'createdAt']) ?? DateTime.now();
    String patient = _readString(r, ['patientName', 'patient.name', 'name']) ?? '-';
    final items = _readItems(r);
    num subtotal = _readNum(r, ['subTotal', 'subtotal']) ?? items.fold<num>(0, (s, it) => s + it.lineTotal);
    num discount = _readNum(r, ['discount']) ?? 0;
    num total = _readNum(r, ['grandTotal', 'total']) ?? (subtotal - discount);
    if (total < 0) total = 0;
    num paid = _readNum(r, ['paid']) ?? total;
    num change = _readNum(r, ['change']) ?? 0;
    NextAppointmentBlock? next;
    if (showNextAppt && nextAppt != null) {
      final dt = _readDateTime(nextAppt, ['startAt', 'start', 'dateTime', 'time']);
      final note = _readString(nextAppt, ['note', 'notes', 'remark']);
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
  dynamic _maybeToMap(dynamic o) {
    if (o == null) return null;
    if (o is Map) return o;
    try {
      final m = (o as dynamic).toJson();
      if (m is Map) return m;
    } catch (_) {}
    return null;
  }
  dynamic _readPath(dynamic o, String path) {
    dynamic cur = o;
    for (final part in path.split('.')) {
      if (cur == null) return null;
      if (cur is Map) {
        cur = cur[part];
        continue;
      }
      cur = _maybeToMap(cur);
      if (cur is Map) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }
  String? _readString(dynamic o, List<String> keys) {
    for (final k in keys) {
      final v = _readPath(o, k);
      if (v is String) return v;
    }
    return null;
  }
  num? _readNum(dynamic o, List<String> keys) {
    for (final k in keys) {
      final v = _readPath(o, k);
      if (v is num) return v;
      if (v is String) {
        final p = num.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }
  DateTime? _readDateTime(dynamic o, List<String> keys) {
    for (final k in keys) {
      final v = _readPath(o, k);
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
    }
    return null;
  }
  List<ReceiptItem> _readItems(dynamic r) {
    dynamic raw = _readPath(r, 'items');
    // ✨ FIX: แก้ไขเรื่อง const ให้ถูกต้องค่ะ
    if (raw is! List || raw.isEmpty) return const [const ReceiptItem(name: 'ค่าบริการ', qty: 1, price: 0)];
    final out = <ReceiptItem>[];
    for (final it in raw) {
      final name = _readString(it, ['name', 'title']) ?? '-';
      final qty = (_readNum(it, ['qty', 'quantity']) ?? 1).toInt();
      final price = _readNum(it, ['price', 'unitPrice']) ?? 0;
      out.add(ReceiptItem(name: name, qty: qty, price: price));
    }
    return out;
  }
  ReceiptRenderData _sampleData() {
    return ReceiptRenderData(
      receiptNo: '68-001',
      issuedAt: DateTime(2025, 8, 15, 14, 30),
      clinicName: 'คลินิกทันตกรรมหมอกุสุมาภรณ์',
      clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
      clinicTel: '094-5639334',
      patientName: 'นาย อรุณ วิริโยคุณ',
      items: const [ReceiptItem(name: 'ถอน (#11)', qty: 1, price: 600)],
      subtotal: 600,
      discount: 0,
      total: 600,
      paid: 600,
      change: 0,
      nextAppointment: NextAppointmentBlock(dateTime: DateTime(2025, 8, 22, 10, 0), note: 'ตรวจติดตามผล'),
    );
  }
}

class MyDentReceiptRenderer extends StatelessWidget {
  final ReceiptRenderData data;
  final ByteData? logo;
  final bool showNextAppointment;
  final dynamic nextAppointment;
  const MyDentReceiptRenderer({super.key, required this.data, this.logo, this.showNextAppointment = false, this.nextAppointment});
  @override
  Widget build(BuildContext context) {
    return _ReceiptWidget(data: data, logoBytes: logo, width: 576, showNextAppt: showNextAppointment, nextAppt: nextAppointment);
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
  const ReceiptRenderData({required this.receiptNo, required this.issuedAt, required this.clinicName, this.clinicAddress, this.clinicTel, required this.patientName, required this.items, required this.subtotal, required this.discount, required this.total, required this.paid, required this.change, this.nextAppointment});
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
  final ReceiptRenderData data;
  final ByteData? logoBytes;
  final double width;
  final bool showNextAppt;
  final dynamic nextAppt;
  const _ReceiptWidget({required this.data, required this.logoBytes, required this.width, this.showNextAppt = false, this.nextAppt});
  static const double _labelWidth = 200;
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
          mainAxisSize: MainAxisSize.min, // Make column only as tall as its content
          children: [
            if (logoBytes != null) ...[
              Center(child: Image.memory(logoBytes!.buffer.asUint8List(), width: 180, filterQuality: FilterQuality.medium)),
              const SizedBox(height: 6),
            ],
            Center(child: Text(data.clinicName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
            if ((data.clinicAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(child: Text(data.clinicAddress!, textAlign: TextAlign.center)),
            ],
            if ((data.clinicTel ?? '').trim().isNotEmpty) Center(child: Text('โทร. ${data.clinicTel!}')),
            const SizedBox(height: 6),
            const Center(child: Text('*********************')),
            const SizedBox(height: 8),
            _kv('เลขที่', data.receiptNo),
            _kv('วันที่', ThFormat.dateThai(data.issuedAt)),
            _kv('เวลา', ThFormat.timeThai(data.issuedAt)),
            _kv('ชื่อ', ''),
            Padding(padding: const EdgeInsets.only(bottom: 2), child: Align(alignment: Alignment.centerRight, child: Text(data.patientName, textAlign: TextAlign.right))),
            _kv('หัตถการ:', data.items.isNotEmpty ? data.items.first.name : '-'),
            _kv('ค่าบริการ', ThFormat.baht(data.total)),
            const SizedBox(height: 18),
            if (showNextAppt && data.nextAppointment != null) ...[
              const Divider(height: 20, thickness: 1),
              const Center(child: Text('ใบนัดครั้งถัดไป', style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 6),
              _kv('วันที่นัด', ThFormat.dateThai(data.nextAppointment!.dateTime)),
              _kv('เวลา', ThFormat.timeThai(data.nextAppointment!.dateTime)),
              if ((data.nextAppointment!.note ?? '').trim().isNotEmpty) _kv('หมายเหตุ', data.nextAppointment!.note!),
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
          SizedBox(width: _labelWidth, child: Text(k)),
          const SizedBox(width: 10),
          Expanded(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
