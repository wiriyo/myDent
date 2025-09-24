// lib/features/printing/render/printer_settings_page.dart
// v1.1.0 - Header preview reflects Clinic Settings (with live updates)
// - Loads clinic name/address/phone/tax/line + logo from ClinicSettingsService
// - Falls back to defaults when fields are empty
// - Subscribes to changes to update preview live

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:http/http.dart' as http;
import '../utils/th_format.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
// 💖 NEW: import service ที่จำเป็นสำหรับการทำงานของปุ่มใหม่ค่ะ
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';
import '../services/print_settings_service.dart';
import '../../../services/clinic_settings_service.dart';
import '../../../config/clinic_context.dart';
import '../../../config/clinic_defaults.dart';
import 'dart:async';
import '../../../services/logo_cache_service.dart';


class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  // 💖 NEW: กุญแจสำหรับใช้ชี้ตำแหน่ง Widget ที่เราจะแคปภาพค่ะ
  final _boundaryKey = GlobalKey();
  ByteData? _logo;
  bool _isLoading = true;
  // 💖 NEW: ตัวแปรสำหรับเก็บภาพที่แคปไว้ และสถานะการทำงานค่ะ
  Uint8List? _lastPng;
  bool _busyCapture = false;

  // --- Printing Settings ---
  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  final PrintSettingsService _printSettingsService = PrintSettingsService();

  // --- Clinic header state (live from settings) ---
  String _clinicName = ClinicDefaults.defaultClinicName;
  String _clinicAddress = '';
  String _clinicPhone = '';
  String? _clinicTaxId;
  String? _clinicLineId;
  String? _remoteLogoUrl;
  StreamSubscription<Map<String, dynamic>?>? _clinicSub;

  // --- Permission & connection status (Android) ---
  bool? _hasPrinterPermissions;
  bool? _isPrinterConnected;
  bool _busyPermissionAction = false;

  @override
  void initState() {
    super.initState();
    _prepare();
    _refreshPermStatus();
    _refreshConnectionStatus();
  }

  Future<void> _prepare() async {
    final settings = await _printSettingsService.load();

    try {
      // Load initial clinic header and subscribe for updates
      await _loadClinicHeader();
      _subscribeClinic();
      // Load logo from remote URL if exists; fallback to default asset
      final logo = await _loadLogo();
      if (mounted) {
        setState(() {
          _applyPrintSettings(settings);
          _logo = logo;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logo = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPermStatus() async {
    try {
      final hasPerm = await ThermalPrinterService.instance.hasPrintingPermissions();
      if (!mounted) return;
      setState(() {
        _hasPrinterPermissions = hasPerm;
      });
    } catch (_) {}
  }

  Future<void> _refreshConnectionStatus() async {
    try {
      final connected = await ThermalPrinterService.instance.isConnected();
      if (!mounted) return;
      setState(() {
        _isPrinterConnected = connected;
      });
    } catch (_) {}
  }

  Future<void> _handlePermissionButton() async {
    if (_busyPermissionAction) return;
    setState(() => _busyPermissionAction = true);

    try {
      final connected = _isPrinterConnected == true;
      if (connected) {
        await ThermalPrinterService.instance.disconnect();
        if (!mounted) return;
        setState(() {
          _isPrinterConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ตัดการเชื่อมต่อเครื่องพิมพ์แล้ว')),
        );
      } else {
        final ok = await ThermalPrinterService.instance.connectWithPicker(context);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _isPrinterConnected = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      await _refreshPermStatus();
      await _refreshConnectionStatus();
      if (mounted) setState(() => _busyPermissionAction = false);
    }
  }

  Future<void> _loadClinicHeader() async {
    try {
      final svc = ClinicSettingsService();
      final data = await svc.getClinicInfo(clinicId: ClinicContext.activeClinicId);
      _applyClinicData(data);
    } catch (_) {}
  }

  void _subscribeClinic() {
    _clinicSub?.cancel();
    final svc = ClinicSettingsService();
    _clinicSub = svc.watchClinicInfo(clinicId: ClinicContext.activeClinicId).listen((data) async {
      if (!mounted) return;
      setState(() {
        _applyClinicData(data);
        _lastPng = null; // force re-capture
      });
      final newLogo = await _loadLogo();
      if (!mounted) return;
      setState(() { _logo = newLogo; });
    });
  }

  void _applyClinicData(Map<String, dynamic>? data) {
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

  Future<void> _updateScale(double newScale) async {
    final settings = _buildPrintSettings(scale: newScale);
    setState(() {
      _applyPrintSettings(settings);
      _lastPng = null; // 💖 NEW: ถ้าปรับค่า ต้องแคปภาพใหม่นะคะ
    });
    await _persistSettings(settings);
  }

  Future<void> _updatePostFeed(int newFeed) async {
    final settings = _buildPrintSettings(postFeed: newFeed);
    setState(() {
      _applyPrintSettings(settings);
    });
    await _persistSettings(settings);
  }

  Future<void> _updateHeaderSpace(int newSpace) async {
    final settings = _buildPrintSettings(headerSpace: newSpace);
    setState(() {
      _applyPrintSettings(settings);
      _lastPng = null; // 💖 NEW: ถ้าปรับค่า ต้องแคปภาพใหม่นะคะ
    });
    await _persistSettings(settings);
  }

  void _applyPrintSettings(PrintSettings settings) {
    _printingScale = settings.scale;
    _printingPostFeed = settings.postFeed;
    _printingHeaderSpace = settings.headerSpace;
  }

  PrintSettings _buildPrintSettings({double? scale, int? postFeed, int? headerSpace}) {
    return PrintSettings(
      scale: scale ?? _printingScale,
      postFeed: postFeed ?? _printingPostFeed,
      headerSpace: headerSpace ?? _printingHeaderSpace,
    );
  }

  Future<void> _persistSettings(PrintSettings settings) async {
    try {
      await _printSettingsService.save(settings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกการตั้งค่าการพิมพ์ไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ตั้งค่าการพิมพ์')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าการพิมพ์'),
        // 💖 FIX v1.0.4: ลบปุ่มทดสอบเก่าออกจาก AppBar ค่ะ
      ),
      floatingActionButton: _buildPermFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            data: MediaQuery.of(bodyContext).copyWith(textScaler: TextScaler.linear(_printingScale)),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                // 💖 NEW: ห่อสลิปด้วย RepaintBoundary เพื่อให้เราแคปภาพได้ค่ะ
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _CombinedSlipWidget(
                    width: 576,
                    receipt: _sampleReceiptData(),
                    nextAppointment: _sampleAppointmentData(),
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
      // 💖 FIX v1.0.4: เปลี่ยนแถบด้านล่างเป็นปุ่มใหม่ทั้งหมดเลยค่ะ
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSettingControl('ขนาด', _printingScale.toStringAsFixed(1), () => _updateScale(_printingScale - 0.1), () => _updateScale(_printingScale + 0.1))),
                  Expanded(child: _buildSettingControl('ท้ายกระดาษ', '$_printingPostFeed', () => _updatePostFeed(_printingPostFeed - 1), () => _updatePostFeed(_printingPostFeed + 1))),
                  Expanded(child: _buildSettingControl('หัวกระดาษ', '$_printingHeaderSpace', () => _updateHeaderSpace(_printingHeaderSpace - 5), () => _updateHeaderSpace(_printingHeaderSpace + 5))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconButton(
                    onPressed: _busyCapture ? null : _captureAndSavePng,
                    bgColor: const Color(0xFFE8F5E9), // สีเขียวมิ้นต์
                    iconAsset: 'assets/icons/picture.png',
                    widgetKey: ValueKey('printer_settings_capture_button'),
                  ),
                  const SizedBox(width: 24),
                  _buildIconButton(
                    onPressed: _busyCapture ? null : _print,
                    bgColor: const Color(0xFFFFF3E0), // สีชมพูอ่อน
                    iconAsset: 'assets/icons/printer.png',
                    widgetKey: ValueKey('printer_settings_print_button'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 💖 NEW: ฟังก์ชันสร้างปุ่มสวยๆ เหมือนหน้าพรีวิวค่ะ
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
  
  Widget _buildSettingControl(String label, String value, VoidCallback onDecrement, VoidCallback onIncrement) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallScaleButton(Icons.remove, onDecrement),
            Flexible(
              child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
            _buildSmallScaleButton(Icons.add, onIncrement),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallScaleButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
      ),
    );
  }

  // 💖 NEW: ฟังก์ชันสำหรับแคปภาพและบันทึกลงแกลเลอรีค่ะ
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

      final fileName = 'MyDent-TestPrint-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(pngBytes, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพตัวอย่างลงในแกลเลอรีเรียบร้อย')));
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

  // 💖 NEW: ฟังก์ชันสำหรับสั่งพิมพ์ภาพที่แคปไว้ค่ะ
  Future<void> _print() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);

    try {
      // ถ้ายังไม่เคยแคปภาพ ให้แคปก่อน
      if (_lastPng == null) {
        final obj = _boundaryKey.currentContext?.findRenderObject();
        if (obj is! RenderRepaintBoundary) return;
        final ui.Image image = await obj.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        _lastPng = byteData.buffer.asUint8List();
      }
      
      if (_lastPng != null) {
        final fileName = 'MyDent-PrinterSample-${DateTime.now().millisecondsSinceEpoch}.png';
        final saved = await ImageSaverService.saveImage(_lastPng!, fileName);
        if (!saved) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่สามารถบันทึกรูปภาพตัวอย่างได้ โปรดอนุญาตให้แอปเข้าถึงรูปภาพก่อนพิมพ์')),
            );
          }
          return;
        }

        await ThermalPrinterService.I.ensureConnectAndPrintPng(context, _lastPng!, feed: _printingPostFeed, cut: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำสั่งพิมพ์ตัวอย่างแล้ว')));
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
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Widget _buildPermFab() {
    final bool hasPermission = _hasPrinterPermissions == true;
    final bool connected = _isPrinterConnected == true;

    final Color bg;
    if (!hasPermission) {
      bg = Colors.red.shade200;
    } else if (connected) {
      bg = Colors.green.shade200;
    } else {
      bg = Colors.amber.shade200;
    }

    return FloatingActionButton(
      heroTag: 'permFab',
      backgroundColor: bg,
      onPressed: _busyPermissionAction ? null : _handlePermissionButton,
      child: _busyPermissionAction
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset('assets/icons/printer.png', width: 26, height: 26),
    );
  }

  @override
  void dispose() {
    _clinicSub?.cancel();
    super.dispose();
  }

  ReceiptModel _sampleReceiptData() {
    return ReceiptModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม',
        address: 'หมอกุสุมาภรณ์',
        phone: '094-5639334',
      ),
      bill: BillInfo(
        billNo: 'XX-XXXX',
        issuedAt: DateTime.now(),
      ),
      patient: const PatientInfo(
        name: 'คุณ ตัวอย่าง การพิมพ์',
        hn: 'HNXXXXX',
      ),
      lines: const [
        ReceiptLine(name: 'รายการทดสอบ 1', qty: 1, price: 500),
        ReceiptLine(name: 'รายการทดสอบ 2', qty: 1, price: 500),
      ],
      totals: const TotalSummary(
        subTotal: 1000,
        discount: 0,
        vat: 0,
        grandTotal: 1000,
      ),
    );
  }

  AppointmentInfo _sampleAppointmentData() {
    return AppointmentInfo(
      startAt: DateTime.now().add(const Duration(days: 7)),
      note: 'นัดตรวจครั้งต่อไป',
    );
  }
}

class _CombinedSlipWidget extends StatelessWidget {
  final double width;
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;
  final ByteData? logoBytes;
  final double headerSpace;
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
