// lib/features/printing/render/receipt_renderer_mydent.dart
// Renderer สำหรับใบเสร็จ MyDent (อัปเกรด: เพิ่มฟังก์ชันบันทึกภาพลงแกลเลอรี)

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import '../utils/th_format.dart';
import '../services/thermal_printer_service.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
// ✨ NEW: import หน่วยปฏิบัติการพิเศษของเราเข้ามา
import '../services/image_saver_service.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final ReceiptModel? receipt;
  final AppointmentInfo? nextAppt;
  final bool useSampleData;
  final bool showNextAppt;

  const ReceiptPreviewPage({
    super.key,
    this.receipt,
    this.nextAppt,
    this.useSampleData = false,
    this.showNextAppt = false,
  });

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _boundaryKey = GlobalKey();
  ReceiptModel? _data;
  ByteData? _logo;
  Uint8List? _lastPng;
  bool _busyCapture = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final data = (widget.useSampleData || widget.receipt == null)
          ? _sampleData()
          : widget.receipt!;

      final logo = await _loadLogo();
      if (!mounted) return;

      setState(() {
        _data = data;
        _logo = logo;
        _isLoading = false;
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('prepare error: $e\n$st');
      if (mounted) {
        setState(() {
          _data = _sampleData();
          _isLoading = false;
        });
      }
    }
  }

  Future<ByteData?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo_clinic.png');
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading logo: $e');
      return null;
    }
  }

  Future<void> _captureAndSavePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ RepaintBoundary');
      }
      final ui.Image image = await obj.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('ไม่สามารถแปลงภาพเป็นข้อมูลได้');
      }
      final pngBytes = byteData.buffer.asUint8List();
      setState(() => _lastPng = pngBytes);

      final fileName = 'MyDent-Receipt-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(pngBytes, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพลงในแกลเลอรีเรียบร้อย')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพไม่สำเร็จ! โปรดตรวจสอบการอนุญาต')));
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('capture/save error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }


  Future<void> _print() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);

    try {
      if (_lastPng == null) {
        final obj = _boundaryKey.currentContext?.findRenderObject();
        if (obj is! RenderRepaintBoundary) return;
        final ui.Image image = await obj.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        _lastPng = byteData.buffer.asUint8List();
      }
      
      if (_lastPng != null) {
        await ThermalPrinterService.instance.ensureConnectAndPrintPng(context, _lastPng!, feed: 3, cut: true);
        // ✨ FIX: กลับไปหน้าก่อนหน้าหลังจากพิมพ์
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดขณะพิมพ์: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('พรีวิวใบเสร็จ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final renderData = _data!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('พรีวิวใบเสร็จ'),
      ),
      body: Center(
        child: SingleChildScrollView(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 72,
                child: FilledButton(
                  onPressed: _busyCapture ? null : _captureAndSavePng,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFE8F5E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Image.asset('assets/icons/picture.png', width: 36, height: 36),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 110,
                height: 72,
                child: FilledButton(
                  onPressed: _busyCapture ? null : _print,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFFFF3E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Image.asset('assets/icons/printer.png', width: 36, height: 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ReceiptModel _sampleData() {
    return ReceiptModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
        address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
        phone: '094-5639334',
      ),
      bill: BillInfo(
        billNo: '68-001',
        issuedAt: DateTime(2025, 8, 15, 14, 30),
      ),
      patient: const PatientInfo(
        name: 'นาย อรุณ วิริโยคุณ',
        hn: 'HN12345',
      ),
      lines: const [
        ReceiptLine(name: 'ถอนฟัน (#11)', qty: 1, price: 600),
        ReceiptLine(name: 'ขูดหินปูน', qty: 1, price: 800),
      ],
      totals: const TotalSummary(
        subTotal: 1400,
        discount: 0,
        vat: 0,
        grandTotal: 1400,
      ),
    );
  }
}

class MyDentReceiptRenderer extends StatelessWidget {
  final ReceiptModel data;
  final ByteData? logo;
  final bool showNextAppointment;
  final AppointmentInfo? nextAppointment;

  const MyDentReceiptRenderer({
    super.key,
    required this.data,
    this.logo,
    this.showNextAppointment = false,
    this.nextAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return _ReceiptWidget(
      data: data,
      logoBytes: logo,
      width: 576,
      showNextAppt: showNextAppointment,
      nextAppointment: nextAppointment,
    );
  }
}

class _ReceiptWidget extends StatelessWidget {
  final ReceiptModel data;
  final ByteData? logoBytes;
  final double width;
  final bool showNextAppt;
  final AppointmentInfo? nextAppointment;

  const _ReceiptWidget({
    required this.data,
    required this.logoBytes,
    required this.width,
    this.showNextAppt = false,
    this.nextAppointment,
  });

  static const double _labelWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 22, color: Colors.black, height: 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoBytes != null) ...[
              Image.memory(logoBytes!.buffer.asUint8List(), width: 180, filterQuality: FilterQuality.medium),
              const SizedBox(height: 6),
            ],
            
            Text('คลินิกทันตกรรม', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            Text('หมอกุสุมาภรณ์', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            
            const SizedBox(height: 2),
            Text('304 ม.1 ต.หนองพอก', textAlign: TextAlign.center),
            Text('อ.หนองพอก จ.ร้อยเอ็ด', textAlign: TextAlign.center),
            Text('094-5639334', textAlign: TextAlign.center),
            
            const SizedBox(height: 6),
            const Text('*********************'),
            const SizedBox(height: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('เลขที่', data.bill.billNo),
                _kv('วันที่', ThFormat.dateThai(data.bill.issuedAt, shortYear: false)),
                _kv('เวลา', ThFormat.timeThai(data.bill.issuedAt)),
                _kv('ชื่อ', ''),
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Align(alignment: Alignment.centerRight, child: Text(data.patient.name, textAlign: TextAlign.right))),
                _kv('หัตถการ:', data.lines.isNotEmpty ? data.lines.first.name : '-'),
                _kv('ค่าบริการ', ThFormat.baht(data.totals.grandTotal)),
              ],
            ),
            
            const SizedBox(height: 18),
            if (showNextAppt && nextAppointment != null) ...[
              const Divider(height: 20, thickness: 1, color: Colors.black),
              const Text('ใบนัดครั้งถัดไป', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    _kv('วันที่นัด', ThFormat.dateThai(nextAppointment!.startAt, shortYear: false)),
                    _kv('เวลา', ThFormat.timeThai(nextAppointment!.startAt)),
                    if ((nextAppointment!.note ?? '').trim().isNotEmpty) _kv('หมายเหตุ', nextAppointment!.note!),
                 ],
              ),
              const SizedBox(height: 10),
            ],
            const Text('ขอบคุณที่ใช้บริการ'),
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
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
