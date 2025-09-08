// lib/features/printing/render/combined_slip_preview_page.dart
// v1.5.0 - Final Cleanup! ลบปุ่มปรับค่าและเปลี่ยนมาใช้ค่าที่บันทึกไว้อัตโนมัติ

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:shared_preferences/shared_preferences.dart'; // 💖 NEW: import เพื่ออ่านค่า
import '../utils/th_format.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';

class CombinedSlipPreviewPage extends StatefulWidget {
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;

  const CombinedSlipPreviewPage({
    super.key,
    required this.receipt,
    required this.nextAppointment,
  });

  @override
  State<CombinedSlipPreviewPage> createState() => _CombinedSlipPreviewPageState();
}

class _CombinedSlipPreviewPageState extends State<CombinedSlipPreviewPage> {
  final _boundaryKey = GlobalKey();
  ByteData? _logo;
  Uint8List? _lastPng;
  bool _busyCapture = false;
  bool _isLoading = true;

  // 💖 NEW: สร้างตัวแปรสำหรับเก็บค่าที่อ่านมาจาก SharedPreferences
  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  static const String _scaleKey = 'mydent.printing.scale';
  static const String _postFeedKey = 'mydent.printing.postfeed';
  static const String _headerSpaceKey = 'mydent.printing.headerspace';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    // 💖 NEW: อ่านค่าการตั้งค่าทั้งหมดจาก SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedScale = prefs.getDouble(_scaleKey) ?? 1.0;
    final savedPostFeed = prefs.getInt(_postFeedKey) ?? 3;
    final savedHeaderSpace = prefs.getInt(_headerSpaceKey) ?? 0;

    try {
      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) {
        setState(() {
          // 💖 NEW: นำค่าที่อ่านได้มาใช้งาน
          _printingScale = savedScale;
          _printingPostFeed = savedPostFeed;
          _printingHeaderSpace = savedHeaderSpace;
          _logo = logo;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logo = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('พรีวิวสลิป')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวสลิป')),
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            // 💖 NEW: ใช้ค่า scale ที่อ่านมา
            data: MediaQuery.of(bodyContext).copyWith(textScaler: TextScaler.linear(_printingScale)),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _CombinedSlipWidget(
                    width: 576,
                    receipt: widget.receipt,
                    nextAppointment: widget.nextAppointment,
                    logoBytes: _logo,
                    // 💖 NEW: ใช้ค่า headerSpace ที่อ่านมา
                    headerSpace: _printingHeaderSpace.toDouble(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      // 💖 FIX: เอาปุ่มปรับค่าออก เหลือแค่ปุ่มหลัก
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(
                onPressed: _busyCapture ? null : _captureAndSavePng,
                bgColor: const Color(0xFFE8F5E9),
                iconAsset: 'assets/icons/picture.png',
              ),
              const SizedBox(width: 24),
              _buildIconButton(
                onPressed: _busyCapture ? null : _print,
                bgColor: const Color(0xFFFFF3E0),
                iconAsset: 'assets/icons/printer.png',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required VoidCallback? onPressed, required Color bgColor, required String iconAsset}) {
    return SizedBox(
      width: 110,
      height: 72,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Image.asset(iconAsset, width: 36, height: 36),
      ),
    );
  }

  Future<void> _captureAndSavePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) throw Exception('ไม่พบ RepaintBoundary');
      
      final ui.Image image = await obj.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('ไม่สามารถแปลงภาพเป็นข้อมูลได้');
      
      final pngBytes = byteData.buffer.asUint8List();
      setState(() => _lastPng = pngBytes);

      final fileName = 'MyDent-CombinedSlip-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(pngBytes, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพสลิปลงในแกลเลอรีเรียบร้อย')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพไม่สำเร็จ! โปรดตรวจสอบการอนุญาต')));
      }
    } catch (e) {
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
        // 💖 NEW: ใช้ค่า postFeed ที่อ่านมา
        await ThermalPrinterService.instance.ensureConnectAndPrintPng(context, _lastPng!, feed: _printingPostFeed, cut: true);
        if (mounted) Navigator.of(context).pop();
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
      if (mounted) setState(() => _busyCapture = false);
    }
  }
}

class _CombinedSlipWidget extends StatelessWidget {
  final double width;
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;
  final ByteData? logoBytes;
  final double headerSpace; // 💖 NEW: รับค่า headerSpace

  const _CombinedSlipWidget({
    required this.width,
    required this.receipt,
    required this.nextAppointment,
    this.logoBytes,
    this.headerSpace = 0.0, // 💖 NEW: ค่าเริ่มต้น
  });

  static const double _labelWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 22, color: Colors.black, height: 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 💖 NEW: ใช้ค่า headerSpace ที่รับมา
            SizedBox(height: headerSpace),
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
                _kv('เลขที่', receipt.bill.billNo),
                _kv('วันที่', ThFormat.dateThai(receipt.bill.issuedAt, shortYear: false)),
                _kv('เวลา', ThFormat.timeThai(receipt.bill.issuedAt)),
                _kv('ชื่อ', ''),
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Align(alignment: Alignment.centerRight, child: Text(receipt.patient.name, textAlign: TextAlign.right))),
                _kv('หัตถการ:', receipt.lines.isNotEmpty ? receipt.lines.first.name : '-'),
                _kv('ค่าบริการ', ThFormat.baht(receipt.totals.grandTotal)),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 20, thickness: 1, color: Colors.black),
            const SizedBox(height: 10),
            const Text('นัดครั้งต่อไป', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('วันที่นัด', ThFormat.dateThai(nextAppointment.startAt, shortYear: false)),
                _kv('เวลานัด', ThFormat.timeThai(nextAppointment.startAt)),
                if ((nextAppointment.note ?? '').trim().isNotEmpty)
                  _kv('หัตถการ', nextAppointment.note!.trim()),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              children: const [
                Text('กรุณามาก่อนเวลานัด 10-15 นาที', style: TextStyle(fontSize: 16)),
                Text('หากไม่สะดวกในวัน/เวลาดังกล่าว', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                Text('กรุณาติดต่อขอรับคิวใหม่', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
              ],
            ),
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
