// lib/features/printing/render/receipt_renderer_mydent.dart
// v1.3.0 - Final Cleanup! ลบปุ่มปรับค่าและเปลี่ยนมาใช้ค่าที่บันทึกไว้อัตโนมัติ

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:http/http.dart' as http;
import '../../../config/clinic_defaults.dart';
import '../../../config/clinic_context.dart';
import '../../../services/clinic_settings_service.dart';
import '../utils/th_format.dart';
import '../services/thermal_printer_service.dart';
import '../services/qz_print_service.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import '../services/image_saver_service.dart';
import '../../../services/logo_cache_service.dart';
import '../services/print_settings_service.dart';
import '../services/web_print_service.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final ReceiptModel? receipt;
  final AppointmentInfo? nextAppt;
  final bool useSampleData;
  final bool showNextAppt;
  // Test-only: preset PNG to bypass capture in widget tests
  final Uint8List? debugPngOverride;
  final PrintSettingsService? printSettingsService;

  const ReceiptPreviewPage({
    super.key,
    this.receipt,
    this.nextAppt,
    this.useSampleData = false,
    this.showNextAppt = false,
    this.debugPngOverride,
    this.printSettingsService,
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

  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  late final PrintSettingsService _printSettingsService;
  final QzPrintService _qzService = QzPrintService.I;
  String? _savedQzPrinter;

  @override
  void initState() {
    super.initState();
    _printSettingsService =
        widget.printSettingsService ?? PrintSettingsService();
    _prepare();
    if (_qzService.isEnabled) {
      _loadSavedPrinter();
    }
  }

  Future<void> _prepare() async {
    final settings = await _printSettingsService.load();

    try {
      final data =
          (widget.useSampleData || widget.receipt == null)
              ? _sampleData()
              : widget.receipt!;
      await _loadClinicHeader();
      final logo = await _loadLogo();
      if (!mounted) return;

      setState(() {
        _printingScale = settings.scale;
        _printingPostFeed = settings.postFeed;
        _printingHeaderSpace = settings.headerSpace;
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

  Future<void> _loadSavedPrinter() async {
    try {
      final saved = await _qzService.loadSavedPrinter();
      if (!mounted) return;
      setState(() => _savedQzPrinter = saved);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to load saved QZ printer: $error');
      }
    }
  }

  Future<void> _loadClinicHeader() async {
    try {
      final svc = ClinicSettingsService();
      final data = await svc.getClinicInfo(
        clinicId: ClinicContext.activeClinicId,
      );
      _clinicName =
          ((data?['name'] as String?)?.trim().isNotEmpty == true)
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

  Future<Uint8List?> _ensurePng({bool forceRecapture = false}) async {
    if (!forceRecapture && _lastPng != null) {
      return _lastPng;
    }

    if (!forceRecapture &&
        _lastPng == null &&
        widget.debugPngOverride != null) {
      _lastPng = widget.debugPngOverride;
      return _lastPng;
    }

    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      return null;
    }

    _lastPng = byteData.buffer.asUint8List();
    return _lastPng;
  }

  Future<bool> _persistPng(Uint8List png, {required String prefix}) async {
    if (widget.debugPngOverride != null) {
      return true;
    }
    final fileName = '$prefix-${DateTime.now().millisecondsSinceEpoch}.png';
    return ImageSaverService.saveImage(png, fileName);
  }

  Future<void> _captureAndSavePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      final png = await _ensurePng(forceRecapture: true);
      if (png == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่มีภาพสำหรับบันทึก')),
        );
        return;
      }

      final bool success = await _persistPng(png, prefix: 'MyDent-Receipt');
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกภาพลงในแกลเลอรีเรียบร้อย')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกภาพไม่สำเร็จ! โปรดตรวจสอบการอนุญาต'),
          ),
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('capture/save error: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $error')));
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _print() async {
    if (_busyCapture) return;
    if (kIsWeb) {
      await _showPrintMenu();
      return;
    }

    setState(() => _busyCapture = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final png = await _ensurePng();
      if (png == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')),
        );
        return;
      }

      final bool saved = await _persistPng(png, prefix: 'MyDent-Receipt');
      if (!mounted) return;
      if (!saved) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถบันทึกภาพใบเสร็จได้ โปรดอนุญาตให้แอปเข้าถึงรูปภาพก่อนพิมพ์',
            ),
          ),
        );
        return;
      }

      await ThermalPrinterService.I.ensureConnectAndPrintPng(
        context,
        png,
        feed: _printingPostFeed,
        cut: true,
      );
      if (!mounted) return;
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดขณะพิมพ์: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _showPrintMenu() async {
    if (_busyCapture || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_qzService.isEnabled)
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text('พิมพ์ (QZ Tray)'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _printWithQz();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('พิมพ์ผ่านเบราว์เซอร์'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _printWithBrowser();
                },
              ),
              if (_qzService.isEnabled)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('เปิด QZ Tray'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _launchQzTray();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _printWithBrowser({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await _ensurePng(forceRecapture: forceRecapture);
      if (png == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')),
        );
        return;
      }
      await WebPrintService.I.printPng(png);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('พิมพ์ผ่านเบราว์เซอร์ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _printWithQz({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    if (!_qzService.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    setState(() => _busyCapture = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final png = await _ensurePng(forceRecapture: forceRecapture);
      if (png == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')),
        );
        return;
      }
      await _performQzPrint(png);
    } on QzPrintException catch (error) {
      _handleQzException(error);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('พิมพ์ผ่าน QZ Tray ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _performQzPrint(Uint8List png) async {
    await _qzService.ensureReady();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final List<String> printers = await _qzService.listPrinters();
    if (!mounted) return;
    String? printer = _savedQzPrinter;

    if (printer != null && !printers.contains(printer)) {
      await _qzService.savePrinter(null);
      printer = null;
      if (mounted) {
        setState(() => _savedQzPrinter = null);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่พบเครื่องพิมพ์ที่บันทึกไว้ใน QZ Tray โปรดเลือกใหม่',
            ),
          ),
        );
      }
    }

    if (printer == null) {
      final choice = await _pickPrinter(printers);
      if (choice == null) {
        return;
      }
      printer = choice.printerName;
      if (choice.remember && printer != null) {
        await _qzService.savePrinter(printer);
        if (mounted) setState(() => _savedQzPrinter = printer);
      } else {
        await _qzService.savePrinter(null);
        if (mounted) setState(() => _savedQzPrinter = null);
      }
    }

    final result = await _qzService.printPng(png, printerName: printer);
    final String? used = result.printerName ?? printer;
    if (used != null && used.isNotEmpty) {
      await _qzService.savePrinter(used);
      if (mounted) setState(() => _savedQzPrinter = used);
    }

    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ส่งคำสั่งพิมพ์ไปยัง QZ Tray แล้ว')),
      );
    }
  }

  Future<_PrinterChoice?> _pickPrinter(List<String> printers) async {
    if (!mounted) return null;
    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QZ Tray ยังไม่รายงานเครื่องพิมพ์')),
      );
      return null;
    }

    String? current = _savedQzPrinter;
    if (current != null && !printers.contains(current)) {
      current = null;
    }
    current ??= printers.isNotEmpty ? printers.first : null;
    bool remember = current != null;

    return showDialog<_PrinterChoice>(
      context: context,
      builder: (dialogContext) {
        String? selection = current;
        bool rememberSelection = remember;
        final double listHeight = (printers.length * 56.0).clamp(160.0, 320.0);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('เลือกเครื่องพิมพ์ QZ Tray'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: listHeight,
                    width: 360,
                    child: RadioGroup<String?>(
                      groupValue: selection,
                      onChanged: (value) {
                        setStateDialog(() {
                          selection = value;
                          if (value == null) {
                            rememberSelection = false;
                          }
                        });
                      },
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final printerName in printers)
                            RadioListTile<String?>(
                              title: Text(printerName),
                              value: printerName,
                            ),
                          RadioListTile<String?>(
                            title: const Text('ให้ QZ Tray ถามทุกครั้ง'),
                            value: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('จำเครื่องพิมพ์นี้ไว้'),
                    value: rememberSelection,
                    onChanged:
                        selection == null
                            ? null
                            : (value) {
                              setStateDialog(() {
                                rememberSelection = value ?? false;
                              });
                            },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed:
                      selection == null && rememberSelection
                          ? null
                          : () {
                            Navigator.of(dialogContext).pop(
                              _PrinterChoice(
                                printerName: selection,
                                remember:
                                    rememberSelection && selection != null,
                              ),
                            );
                          },
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleQzException(QzPrintException error) {
    if (!mounted) return;
    if (error.code == 'qz_printer_not_found') {
      _qzService.savePrinter(null);
      setState(() => _savedQzPrinter = null);
    }
    _showQzErrorSnackBar(error);
  }

  void _showQzErrorSnackBar(QzPrintException error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    _printWithQz();
                  },
                  child: const Text('ลองอีกครั้ง'),
                ),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    _runQzSelfTest();
                  },
                  child: const Text('ช่วยตรวจแก้ (self-test)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runQzSelfTest() async {
    if (!_qzService.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await _qzService.diagnose();
      final summary = _formatSelfTest(report);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text(summary),
        ),
      );
    } on QzPrintException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('ตรวจสอบ QZ Tray ไม่สำเร็จ: $error')),
      );
    }
  }

  String _formatSelfTest(QzSelfTestReport report) {
    final parts = <String>['QZ: ${_mapSelfTestStatus(report)}'];
    if (report.version != null && report.version!.isNotEmpty) {
      parts.add('เวอร์ชัน ${report.version}');
    }
    if (report.printersCount != null) {
      parts.add('เครื่องพิมพ์ ${report.printersCount}');
    }
    if (report.lastError != null) {
      parts.add('ปัญหา: ${report.lastError!.code}');
    }
    return parts.join(' • ');
  }

  String _mapSelfTestStatus(QzSelfTestReport report) {
    if (!report.isActive) {
      final String? errorCode = report.lastError?.code;

      if (errorCode == 'qz_bridge_missing') {
        return '?1,?,??1^?,z?,s?1,?,??,s?,??,??,??,?';
      }

      if (errorCode != null) {
        return '?1,?,??1^?1??,S?,??1^?,-?,??,?1^?,-';
      }

      return '?,??,3?,??,?,?1??,S?,??1^?,-?,??,?1^?,-';
    }

    return '?,z?,??1%?,-?,??1??,S?1%?,?,??,T';
  }

  Future<void> _launchQzTray() async {
    if (!_qzService.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _qzService.launchQzTray();
      await Future<void>.delayed(const Duration(seconds: 2));
      await _qzService.ensureReady();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('พยายามเปิด QZ Tray แล้ว โปรดลองพิมพ์อีกครั้ง'),
        ),
      );
    } on QzPrintException catch (error) {
      _showQzErrorSnackBar(error);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('เปิด QZ Tray ไม่สำเร็จ: $error')),
      );
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
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ')),
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            // 💖 NEW: ใช้ค่า scale ที่อ่านมา
            data: MediaQuery.of(
              bodyContext,
            ).copyWith(textScaler: TextScaler.linear(_printingScale)),
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
                widgetKey: const ValueKey('receipt_capture_button'),
              ),
              const SizedBox(width: 24),
              _buildIconButton(
                onPressed: _busyCapture ? null : _print,
                bgColor: const Color(0xFFFFF3E0),
                iconAsset: 'assets/icons/printer.png',
                widgetKey: const ValueKey('receipt_print_button'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required VoidCallback? onPressed,
    required Color bgColor,
    required String iconAsset,
    Key? widgetKey,
  }) {
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

  ReceiptModel _sampleData() {
    return ReceiptModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
        address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
        phone: '094-5639334',
      ),
      bill: BillInfo(billNo: '68-001', issuedAt: DateTime.now()),
      patient: const PatientInfo(name: 'นาย อรุณ วิริโยคุณ', hn: 'HN12345'),
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

class _PrinterChoice {
  const _PrinterChoice({required this.printerName, required this.remember});

  final String? printerName;
  final bool remember;
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
              Image.memory(
                logoBytes!.buffer.asUint8List(),
                width: 180,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 6),
            ],

            Text(
              clinicName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 2),
            if (clinicAddress.trim().isNotEmpty)
              Text(clinicAddress, textAlign: TextAlign.center),
            if (clinicPhone.trim().isNotEmpty)
              Text(clinicPhone, textAlign: TextAlign.center),
            if ((clinicTaxId ?? '').trim().isNotEmpty)
              Text(
                'เลขผู้เสียภาษี: ${clinicTaxId!.trim()}',
                textAlign: TextAlign.center,
              ),
            if ((clinicLineId ?? '').trim().isNotEmpty)
              Text(
                'Line ID: ${clinicLineId!.trim()}',
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 6),
            const Text('*********************'),
            const SizedBox(height: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('เลขที่', data.bill.billNo),
                _kv(
                  'วันที่',
                  ThFormat.dateThai(data.bill.issuedAt, shortYear: false),
                ),
                _kv('เวลา', ThFormat.timeThai(data.bill.issuedAt)),
                _kv('ชื่อ', ''),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(data.patient.name, textAlign: TextAlign.right),
                  ),
                ),
                _kv(
                  'หัตถการ:',
                  data.lines.isNotEmpty ? data.lines.first.name : '-',
                ),
                _kv('ค่าบริการ', ThFormat.baht(data.totals.grandTotal)),
              ],
            ),

            const SizedBox(height: 18),
            if (showNextAppt && nextAppointment != null) ...[
              const Divider(height: 20, thickness: 1, color: Colors.black),
              const Text(
                'ใบนัดครั้งถัดไป',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(
                    'วันที่นัด',
                    ThFormat.dateThai(
                      nextAppointment!.startAt,
                      shortYear: false,
                    ),
                  ),
                  _kv('เวลา', ThFormat.timeThai(nextAppointment!.startAt)),
                  if ((nextAppointment!.note ?? '').trim().isNotEmpty)
                    _kv('หมายเหตุ', nextAppointment!.note!),
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
