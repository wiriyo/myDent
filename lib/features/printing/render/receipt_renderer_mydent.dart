// lib/features/printing/render/receipt_renderer_mydent.dart
// v1.3.0 - Final Cleanup! ลบปุ่มปรับค่าและเปลี่ยนมาใช้ค่าที่บันทึกไว้อัตโนมัติ

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:shared_preferences/shared_preferences.dart'; // 💖 NEW: import เพื่ออ่านค่า
import 'package:http/http.dart' as http;
import '../../../config/clinic_defaults.dart';
import '../../../config/clinic_context.dart';
import '../../../services/clinic_settings_service.dart';
import '../utils/th_format.dart';
import '../services/thermal_printer_service.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import '../services/image_saver_service.dart';
import '../../../services/logo_cache_service.dart';

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
  // clinic header
  String _clinicName = ClinicDefaults.defaultClinicName;
  String _clinicAddress = '';
  String _clinicPhone = '';
  String? _clinicTaxId;
  String? _clinicLineId;

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
      final data = (widget.useSampleData || widget.receipt == null)
          ? _sampleData()
          : widget.receipt!;
      await _loadClinicHeader();
      final logo = await _loadLogo();
      if (!mounted) return;

      setState(() {
        // 💖 NEW: นำค่าที่อ่านได้มาใช้งาน
        _printingScale = savedScale;
        _printingPostFeed = savedPostFeed;
        _printingHeaderSpace = savedHeaderSpace;
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
    } catch (e) {
      if (kDebugMode) debugPrint('load clinic header failed: $e');
    }
  }

  String? _remoteLogoUrl;
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
      // fallback to default asset
      return await rootBundle.load(ClinicDefaults.defaultLogoAsset);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading logo: $e');
      try {
        return await rootBundle.load(ClinicDefaults.defaultLogoAsset);
      } catch (_) {
        return null;
      }
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
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            // 💖 NEW: ใช้ค่า scale ที่อ่านมา
            data: MediaQuery.of(bodyContext).copyWith(textScaler: TextScaler.linear(_printingScale)),
            child: Center(
              child: SingleChildScrollView(
                child: ColoredBox(
                  color: Colors.white,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: _ReceiptWidget(
                      data: renderData,
                      logoBytes: _logo,
                      width: 576,
                      showNextAppt: widget.showNextAppt,
                      nextAppointment: widget.nextAppt,
                      // 💖 NEW: ใช้ค่า headerSpace ที่อ่านมา
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

  ReceiptModel _sampleData() {
    return ReceiptModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
        address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
        phone: '094-5639334',
      ),
      bill: BillInfo(
        billNo: '68-001',
        issuedAt: DateTime.now(),
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

class _ReceiptWidget extends StatelessWidget {
  final ReceiptModel data;
  final ByteData? logoBytes;
  final double width;
  final bool showNextAppt;
  final AppointmentInfo? nextAppointment;
  final double headerSpace; // 💖 NEW: รับค่า headerSpace
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final String? clinicTaxId;
  final String? clinicLineId;

  const _ReceiptWidget({
    required this.data,
    required this.logoBytes,
    required this.width,
    this.showNextAppt = false,
    this.nextAppointment,
    this.headerSpace = 0.0, // 💖 NEW: ค่าเริ่มต้น
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
              Image.memory(logoBytes!.buffer.asUint8List(), width: 180, filterQuality: FilterQuality.medium),
              const SizedBox(height: 6),
            ],
            
            Text(clinicName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            
            const SizedBox(height: 2),
            if (clinicAddress.trim().isNotEmpty) Text(clinicAddress, textAlign: TextAlign.center),
            if (clinicPhone.trim().isNotEmpty) Text(clinicPhone, textAlign: TextAlign.center),
            if ((clinicTaxId ?? '').trim().isNotEmpty) Text('เลขผู้เสียภาษี: ${clinicTaxId!.trim()}', textAlign: TextAlign.center),
            if ((clinicLineId ?? '').trim().isNotEmpty) Text('Line ID: ${clinicLineId!.trim()}', textAlign: TextAlign.center),
            
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
