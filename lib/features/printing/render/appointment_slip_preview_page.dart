// lib/features/printing/render/appointment_slip_preview_page.dart
// v1.7.0 - The Perfect Solution! เพิ่มระบบ Printing Scale ที่ปรับขนาดได้
// อัปเกรด: ปรับปรุง UI และเพิ่มฟังก์ชันการทำงานของปุ่มให้สมบูรณ์

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 💖 NEW: import กล่องเก็บของวิเศษ
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

  // 💖 NEW: สร้างตัวแปรสำหรับเก็บค่า Printing Scale
  double _printingScale = 1.0;
  static const String _scaleKey = 'mydent.printing.scale';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    // 💖 NEW: โหลดค่า scale ที่เคยบันทึกไว้
    final prefs = await SharedPreferences.getInstance();
    final savedScale = prefs.getDouble(_scaleKey) ?? 1.0;

    try {
      final data = (widget.useSampleData || widget.slip == null)
          ? _sampleData()
          : widget.slip!;

      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) {
        setState(() {
          _printingScale = savedScale; // นำค่าที่โหลดมาใช้
          _logo = logo;
          _data = data;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logo = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // 💖 NEW: ฟังก์ชันสำหรับปรับและบันทึกค่า Scale
  Future<void> _updateScale(double newScale) async {
    final prefs = await SharedPreferences.getInstance();
    // ทำให้ค่า scale ไม่น้อยกว่า 0.5 และไม่มากกว่า 2.0
    final clampedScale = newScale.clamp(0.5, 2.0);
    await prefs.setDouble(_scaleKey, clampedScale);
    setState(() {
      _printingScale = clampedScale;
      _lastPng = null; // เคลียร์ภาพเก่าทิ้งเพื่อให้สร้างใหม่ตาม scale ใหม่
    });
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
      appBar: AppBar(title: Text('พรีวิวใบนัด (Scale: ${_printingScale.toStringAsFixed(1)})')),
      // 💖 FIX v1.7.0: ใช้ค่า _printingScale ที่ปรับได้
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            data: MediaQuery.of(bodyContext).copyWith(textScaleFactor: _printingScale),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _SlipWidget(width: 576, slip: slipData, logoBytes: _logo),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 💖 NEW: ปุ่มทดสอบสำหรับลด Scale
              _buildScaleButton(Icons.remove, () => _updateScale(_printingScale - 0.1)),
              const Spacer(),
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
              const Spacer(),
              // 💖 NEW: ปุ่มทดสอบสำหรับเพิ่ม Scale
              _buildScaleButton(Icons.add, () => _updateScale(_printingScale + 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  // 💖 NEW: Helper widget สำหรับสร้างปุ่ม Print/Save
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
  
  // 💖 NEW: Helper widget สำหรับสร้างปุ่มปรับ Scale
  Widget _buildScaleButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 28),
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
        startAt: DateTime(2025, 8, 22, 11, 0),
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
        await ThermalPrinterService.instance.ensureConnectAndPrintPng(context, _lastPng!, feed: 3, cut: true);
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
  const _SlipWidget({required this.width, required this.slip, this.logoBytes});

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
