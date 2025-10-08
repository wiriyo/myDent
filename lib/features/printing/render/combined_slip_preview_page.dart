// lib/features/printing/render/combined_slip_preview_page.dart
// v1.5.0 - Final Cleanup! ลบปุ่มปรับค่าและเปลี่ยนมาใช้ค่าที่บันทึกไว้อัตโนมัติ

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:http/http.dart' as http;
import '../../../services/clinic_settings_service.dart';
import '../../../config/clinic_defaults.dart';
import '../../../config/clinic_context.dart';
import '../utils/th_format.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';
import '../../../services/logo_cache_service.dart';
import '../services/print_settings_service.dart';

class CombinedSlipPreviewPage extends StatefulWidget {
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;
  // Test-only: preset PNG to bypass capture in widget tests
  final Uint8List? debugPngOverride;
  final PrintSettingsService? printSettingsService;

  const CombinedSlipPreviewPage({
    super.key,
    required this.receipt,
    required this.nextAppointment,
    this.debugPngOverride,
    this.printSettingsService,
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
  String _clinicName = ClinicDefaults.defaultClinicName;
  String _clinicAddress = '';
  String _clinicPhone = '';
  String? _clinicTaxId;
  String? _clinicLineId;
  String? _remoteLogoUrl;

  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  late final PrintSettingsService _printSettingsService;

  @override
  void initState() {
    super.initState();
    _printSettingsService = widget.printSettingsService ?? PrintSettingsService();
    _prepare();
  }

  Future<void> _prepare() async {
    final settings = await _printSettingsService.load();

    try {
      await _loadClinicHeader();
      final logo = await _loadLogo();
      if (mounted) {
        setState(() {
          _printingScale = settings.scale;
          _printingPostFeed = settings.postFeed;
          _printingHeaderSpace = settings.headerSpace;
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
      _clinicName = ((data?['name'] as String?)?.trim().isNotEmpty == true) ? (data!['name'] as String) : ClinicDefaults.defaultClinicName;
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
          // Cache for splash/offline use
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
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(
                onPressed: _busyCapture ? null : _captureAndSavePng,
                bgColor: const Color(0xFFE8F5E9),
                iconAsset: 'assets/icons/picture.png',
                widgetKey: const ValueKey('combined_capture_button'),
              ),
              const SizedBox(width: 24),
              _buildIconButton(
                onPressed: _busyCapture ? null : _print,
                bgColor: const Color(0xFFFFF3E0),
                iconAsset: 'assets/icons/printer.png',
                widgetKey: const ValueKey('combined_print_button'),
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

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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
        if (widget.debugPngOverride == null) {
          final fileName = 'MyDent-CombinedSlip-${DateTime.now().millisecondsSinceEpoch}.png';
          final saved = await ImageSaverService.saveImage(_lastPng!, fileName);
          if (!saved) {
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('ไม่สามารถบันทึกภาพใบเสร็จ+ใบนัดได้ โปรดอนุญาตให้แอปเข้าถึงรูปภาพก่อนพิมพ์')),
            );
            return;
          }
        }

        // 💖 NEW: ใช้ค่า postFeed ที่อ่านมา
        if (!mounted) return;
        await ThermalPrinterService.I.ensureConnectAndPrintPng(context, _lastPng!, feed: _printingPostFeed, cut: true);
        if (!mounted) return;
        navigator.pop();
      } else {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดขณะพิมพ์: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }
}

class _CombinedSlipWidget extends StatelessWidget {
  final double width;
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;
  final ByteData? logoBytes;
  final double headerSpace; // 💖 NEW: รับค่า headerSpace
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final String? clinicTaxId;
  final String? clinicLineId;

  const _CombinedSlipWidget({
    required this.width,
    required this.receipt,
    required this.nextAppointment,
    this.logoBytes,
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
            if (clinicPhone.trim().isNotEmpty) Text('โทร: $clinicPhone', textAlign: TextAlign.center),
            if ((clinicTaxId ?? '').isNotEmpty) Text('เลขผู้เสียภาษี: $clinicTaxId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            if ((clinicLineId ?? '').isNotEmpty) Text('Line ID: $clinicLineId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
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
