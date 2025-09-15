// lib/features/printing/render/appointment_slip_preview_page.dart
// v1.8.1 - เพิ่ม debugPngOverride สำหรับ widget tests (ข้ามขั้นตอน capture)

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/clinic_settings_service.dart';
import '../../../config/clinic_defaults.dart';
import '../../../config/clinic_context.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 💖 NEW: import เพื่ออ่านค่า
import '../domain/appointment_slip_model.dart';
import '../domain/receipt_model.dart';
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';
import '../utils/th_format.dart';
import '../../../services/logo_cache_service.dart';

class AppointmentSlipPreviewPage extends StatefulWidget {
  final AppointmentSlipModel? slip;
  final bool useSampleData;
  // Test-only: preset PNG เพื่อข้ามการ capture ใน widget tests
  final Uint8List? debugPngOverride;
  const AppointmentSlipPreviewPage({super.key, this.slip, this.useSampleData = true, this.debugPngOverride});

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
  // clinic header values
  String _clinicName = ClinicDefaults.defaultClinicName;
  String _clinicAddress = '';
  String _clinicPhone = '';
  String? _clinicTaxId;
  String? _clinicLineId;
  String? _remoteLogoUrl;

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

      await _loadClinicHeader();
      final logo = await _loadLogo();
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

  Future<void> _loadClinicHeader() async {
    try {
      final svc = ClinicSettingsService();
      final data = await svc.getClinicInfo(clinicId: ClinicContext.activeClinicId);
      _clinicName = ((data?['name'] as String?)?.trim().isNotEmpty == true)
          ? (data!['name'] as String)
          : ClinicDefaults.defaultClinicName;
      _clinicAddress = (data?['address'] as String?)?.trim() ?? '';
      _clinicPhone = (data?['phone'] as String?)?.trim() ?? '';
      final showLine = (data?['showLineId'] ?? true) as bool;
      final showTax = (data?['showTaxId'] ?? false) as bool;
      _clinicLineId = showLine ? (data?['lineId'] as String?)?.trim() : null;
      _clinicTaxId = showTax ? (data?['taxId'] as String?)?.trim() : null;
      _remoteLogoUrl = (data?['logoUrl'] as String?)?.trim();
    } catch (_) {}
  }

  Future<ByteData?> _loadLogo() async {
    try {
      if (_remoteLogoUrl != null && _remoteLogoUrl!.isNotEmpty) {
        final resp = await http.get(Uri.parse(_remoteLogoUrl!));
        if (resp.statusCode == 200) {
          final bytes = resp.bodyBytes;
          await LogoCacheService.save(bytes);
          return ByteData.view(bytes.buffer);
        }
      }
      return await rootBundle.load(ClinicDefaults.defaultLogoAsset);
    } catch (_) {
      try { return await rootBundle.load(ClinicDefaults.defaultLogoAsset); } catch (_) { return null; }
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
                  child: _SlipWidget(
                    width: 576,
                    slip: slipData,
                    logoBytes: _logo,
                    headerSpace: _printingHeaderSpace.toDouble(),
                    clinicName: _clinicName,
                    clinicAddress: _clinicAddress,
                    clinicPhone: _clinicPhone,
                    clinicTaxId: _clinicTaxId,
                    clinicLineId: _clinicLineId,
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
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(
                onPressed: _busyCapture ? null : _captureAndSavePng,
                bgColor: const Color(0xFFE8F5E9),
                iconAsset: 'assets/icons/picture.png',
                widgetKey: const ValueKey('appointment_capture_button'),
              ),
              const SizedBox(width: 24),
              _buildIconButton(
                onPressed: _busyCapture ? null : _print,
                bgColor: const Color(0xFFFFF3E0),
                iconAsset: 'assets/icons/printer.png',
                widgetKey: const ValueKey('appointment_print_button'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildIconButton({required VoidCallback? onPressed, required Color bgColor, required String iconAsset, Key? widgetKey}) {
    return SizedBox(
      width: 110,
      height: 72,
      child: FilledButton(
        key: widgetKey,
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
        if (widget.debugPngOverride != null) {
          _lastPng = widget.debugPngOverride;
        } else {
          final obj = _boundaryKey.currentContext?.findRenderObject();
          if (obj is! RenderRepaintBoundary) return;
          final ui.Image image = await obj.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) return;
          _lastPng = byteData.buffer.asUint8List();
        }
      }
      
      if (_lastPng != null) {
        // 💖 NEW: ใช้ค่า postFeed ที่อ่านมา
        await ThermalPrinterService.I.ensureConnectAndPrintPng(context, _lastPng!, feed: _printingPostFeed, cut: true);
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
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final String? clinicTaxId;
  final String? clinicLineId;

  const _SlipWidget({
    required this.width,
    required this.slip,
    this.logoBytes,
    this.headerSpace = 0.0,
    required this.clinicName,
    required this.clinicAddress,
    required this.clinicPhone,
    this.clinicTaxId,
    this.clinicLineId,
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
              Image.memory(
                logoBytes!.buffer.asUint8List(),
                width: 180,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 6),
            ],
            Text(clinicName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            if (clinicAddress.trim().isNotEmpty) Text(clinicAddress, textAlign: TextAlign.center),
            if (clinicPhone.trim().isNotEmpty) Text('โทร: $clinicPhone', textAlign: TextAlign.center),
            if ((clinicTaxId ?? '').isNotEmpty) Text('เลขผู้เสียภาษี: $clinicTaxId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            if ((clinicLineId ?? '').isNotEmpty) Text('Line ID: $clinicLineId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),

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
