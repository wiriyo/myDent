// lib/features/printing/render/appointment_slip_preview_page.dart
// v1.8.0 - Final Cleanup! ลบปุ่มปรับค่าและเปลี่ยนมาใช้ค่าที่บันทึกไว้อัตโนมัติ

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 💖 NEW: import เพื่ออ่านค่า
import '../domain/appointment_slip_model.dart';
import '../domain/receipt_model.dart';
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';
import '../utils/th_format.dart';

class AppointmentSlipPreviewPage extends StatefulWidget {
  final AppointmentSlipModel? slip;
  final bool useSampleData;
  const AppointmentSlipPreviewPage({super.key, this.slip, this.useSampleData = true});

  @override
  State<AppointmentSlipPreviewPage> createState() => _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState extends State<AppointmentSlipPreviewPage> {
  final _boundaryKey = GlobalKey();
  AppointmentSlipModel? _data;
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
      final data = (widget.useSampleData || widget.slip == null)
          ? _sampleData()
          : widget.slip!;

      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) {
        setState(() {
          // 💖 NEW: นำค่าที่อ่านได้มาใช้งาน
          _printingScale = savedScale;
          _printingPostFeed = savedPostFeed;
          _printingHeaderSpace = savedHeaderSpace;
          _data = data;
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
    if (_isLoading || _data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('พรีวิวใบนัด')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final slipData = _data!;

    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบนัด')),
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            // 💖 NEW: ใช้ค่า scale ที่อ่านมา
            data: MediaQuery.of(bodyContext).copyWith(textScaler: TextScaler.linear(_printingScale)),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  // 💖 NEW: ใช้ค่า headerSpace ที่อ่านมา
                  child: _SlipWidget(width: 576, slip: slipData, logoBytes: _logo, headerSpace: _printingHeaderSpace.toDouble()),
                ),
              ),
            ),
          );
        },
      ),
      // 💖 FIX: เอาปุ่มปรับค่าออก เหลือแค่ปุ่มหลัก
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
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

  AppointmentSlipModel _sampleData() {
    return AppointmentSlipModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
        address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
        phone: '094-5639334',
      ),
      patient: const PatientInfo(
        name: 'คุณสมหญิง น่ารักจุง',
        hn: 'HN54321',
      ),
      appointment: AppointmentInfo(
        startAt: DateTime.now().add(const Duration(days: 7)),
        note: 'ถอน(#21)',
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

      final fileName = 'MyDent-Appointment-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(pngBytes, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพใบนัดลงในแกลเลอรีเรียบร้อย')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพไม่สำเร็จ! โปรดตรวจสอบการอนุญาต')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally { if (mounted) setState(() => _busyCapture = false); }
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
}

class _SlipWidget extends StatelessWidget {
  final double width;
  final AppointmentSlipModel slip;
  final ByteData? logoBytes;
  final double headerSpace; // 💖 NEW: รับค่า headerSpace

  const _SlipWidget({required this.width, required this.slip, this.logoBytes, this.headerSpace = 0.0});

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
              Image.memory(
                logoBytes!.buffer.asUint8List(),
                width: 180,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 6),
            ],
            
            Text('คลินิกทันตกรรม', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            Text('หมอกุสุมาภรณ์', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('304 ม.1 ต.หนองพอก', textAlign: TextAlign.center),
            Text('อ.หนองพอก จ.ร้อยเอ็ด', textAlign: TextAlign.center),
            Text('094-5639334', textAlign: TextAlign.center),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.black, thickness: 1),
            const SizedBox(height: 10),
            const Text('ใบนัด', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('ชื่อ', ''),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      slip.patient.name.isEmpty ? '-' : slip.patient.name,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                _kv('วันที่นัด', ThFormat.dateThai(slip.appointment.startAt, shortYear: false)),
                _kv('เวลานัด', ThFormat.timeThai(slip.appointment.startAt)),
                if ((slip.appointment.note ?? '').trim().isNotEmpty)
                  _kv('หัตถการ', slip.appointment.note!.trim()),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Column(
              children: const [
                Text(
                  'กรุณามาก่อนเวลานัด 10-15 นาที',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  'หากไม่สะดวกในวัน/เวลาดังกล่าว',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'กรุณาติดต่อขอรับคิวใหม่',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
          SizedBox(width: _labelWidth, child: Text(k)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            )
          ),
        ],
      ),
    );
  }
}
