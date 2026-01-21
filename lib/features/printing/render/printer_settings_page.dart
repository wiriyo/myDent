// lib/features/printing/render/printer_settings_page.dart
// v1.1.0 - Header preview reflects Clinic Settings (with live updates)
// - Loads clinic name/address/phone/tax/line + logo from ClinicSettingsService
// - Falls back to defaults when fields are empty
// - Subscribes to changes to update preview live

import 'dart:convert';
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
import '../services/qz_print_service.dart';
import '../services/browser_print_service.dart';
import '../../../services/clinic_settings_service.dart';
import '../../../config/clinic_context.dart';
import '../../../config/clinic_defaults.dart';
import 'dart:async';
import '../../../services/logo_cache_service.dart';
import 'qz_status_ui.dart';
import 'qz_diagnostics_sheet.dart';
import 'browser_print_payload.dart';
import 'png_postprocessor.dart';

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
  String? _cachedPngBase64;
  bool _busyCapture = false;

  // --- Printing Settings ---
  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  BrowserPrintMode _browserMode = PrintSettings.defaultBrowserMode;
  int _browserPixelWidth = PrintSettings.defaultBrowserPixelWidth;
  bool _browserAutoClose = PrintSettings.defaultBrowserAutoClose;
  final PrintSettingsService _printSettingsService = PrintSettingsService();
  final QzPrintService _qzService = QzPrintService.I;
  String? _savedQzPrinter;

  void _showSnackBarSafe(SnackBar snackBar) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _hideCurrentSnackBarSafe() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

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
    if (_qzService.isEnabled) {
      unawaited(_loadSavedPrinter());
    }
    if (kIsWeb && _qzService.isEnabled) {
      unawaited(_qzService.ensureWhitelist());
    }
  }

  Future<void> _prepare() async {
    final settings = await _printSettingsService.load(
      clinicId: ClinicContext.activeClinicId,
    );

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
      final hasPerm =
          await ThermalPrinterService.instance.hasPrintingPermissions();
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
        final ok = await ThermalPrinterService.instance.connectWithPicker(
          context,
        );
        if (!mounted) return;
        if (ok) {
          setState(() {
            _isPrinterConnected = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
      final data = await svc.getClinicInfo(
        clinicId: ClinicContext.activeClinicId,
      );
      _applyClinicData(data);
    } catch (_) {}
  }

  void _subscribeClinic() {
    _clinicSub?.cancel();
    final svc = ClinicSettingsService();
    _clinicSub = svc
        .watchClinicInfo(clinicId: ClinicContext.activeClinicId)
        .listen((data) async {
          if (!mounted) return;
          setState(() {
            _applyClinicData(data);
            _lastPng = null; // force re-capture
          });
          final newLogo = await _loadLogo();
          if (!mounted) return;
          setState(() {
            _logo = newLogo;
          });
        });
  }

  void _applyClinicData(Map<String, dynamic>? data) {
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
      try {
        return await rootBundle.load(ClinicDefaults.defaultLogoAsset);
      } catch (_) {
        return null;
      }
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
    _browserMode = settings.browserMode;
    _browserPixelWidth = settings.browserPixelWidth;
    _browserAutoClose = settings.browserAutoClose;
  }

  PrintSettings _buildPrintSettings({
    double? scale,
    int? postFeed,
    int? headerSpace,
  }) {
    return PrintSettings(
      scale: scale ?? _printingScale,
      postFeed: postFeed ?? _printingPostFeed,
      headerSpace: headerSpace ?? _printingHeaderSpace,
      browserMode: _browserMode,
      browserPixelWidth: _browserPixelWidth,
      browserAutoClose: _browserAutoClose,
    );
  }

  Future<void> _persistSettings(PrintSettings settings) async {
    try {
      await _printSettingsService.save(
        settings,
        clinicId: ClinicContext.activeClinicId,
      );
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
            data: MediaQuery.of(
              bodyContext,
            ).copyWith(textScaler: TextScaler.linear(_printingScale)),
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
                  Expanded(
                    child: _buildSettingControl(
                      'ขนาด',
                      _printingScale.toStringAsFixed(1),
                      () => _updateScale(_printingScale - 0.1),
                      () => _updateScale(_printingScale + 0.1),
                    ),
                  ),
                  Expanded(
                    child: _buildSettingControl(
                      'ท้ายกระดาษ',
                      '$_printingPostFeed',
                      () => _updatePostFeed(_printingPostFeed - 1),
                      () => _updatePostFeed(_printingPostFeed + 1),
                    ),
                  ),
                  Expanded(
                    child: _buildSettingControl(
                      'หัวกระดาษ',
                      '$_printingHeaderSpace',
                      () => _updateHeaderSpace(_printingHeaderSpace - 5),
                      () => _updateHeaderSpace(_printingHeaderSpace + 5),
                    ),
                  ),
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

  Widget _buildSettingControl(
    String label,
    String value,
    VoidCallback onDecrement,
    VoidCallback onIncrement,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallScaleButton(Icons.remove, onDecrement),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
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
      child: IconButton(onPressed: onPressed, icon: Icon(icon), iconSize: 20),
    );
  }

  // 💖 NEW: ฟังก์ชันสำหรับแคปภาพและบันทึกลงแกลเลอรีค่ะ
  Future<Uint8List?> _ensurePng({bool forceRecapture = false}) async {
    if (forceRecapture) {
      _cachedPngBase64 = null;
      _lastPng = null;
    }
    if (_lastPng != null) {
      _cachedPngBase64 ??= base64Encode(_lastPng!);
      return _lastPng;
    }

    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);
    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        return null;
      }

      final Uint8List raw = byteData.buffer.asUint8List();
      _lastPng = await ThermalPngPostProcessor.process(
        raw,
        targetWidth: _browserPixelWidth,
      );
      _cachedPngBase64 = base64Encode(_lastPng!);
      return _lastPng;
    } finally {
      image.dispose();
    }
  }

  Future<void> _captureAndSavePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      final png = await _ensurePng(forceRecapture: true);
      if (png == null) {
        throw Exception('????? RepaintBoundary');
      }

      final fileName =
          'MyDent-TestPrint-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(png, fileName);

      if (!mounted) return;

      if (success) {
        _showSnackBarSafe(
          const SnackBar(content: Text('บันทึกรูปภาพเรียบร้อยแล้ว')),
        );
      } else {
        _showSnackBarSafe(
          const SnackBar(
            content: Text('บันทึกรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBarSafe(
          SnackBar(content: Text('เกิดข้อผิดพลาดระหว่างบันทึกภาพ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  // 💖 NEW: ฟังก์ชันสำหรับสั่งพิมพ์ภาพที่แคปไว้ค่ะ
  Future<void> _print() async {
    if (_busyCapture) return;
    if (kIsWeb) {
      await _printWeb();
      return;
    }

    setState(() => _busyCapture = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final png = await _ensurePng();
      if (png == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเตรียมภาพสำหรับพิมพ์ได้')),
        );
        return;
      }

      final fileName =
          'MyDent-PrinterSample-${DateTime.now().millisecondsSinceEpoch}.png';
      final saved = await ImageSaverService.saveImage(png, fileName);
      if (!saved) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถบันทึกรูปภาพสำหรับการพิมพ์ได้ กรุณาลองใหม่อีกครั้ง',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      final int feedLines = PrintSettings.feedLinesFromSetting(
        _printingPostFeed,
      );
      await ThermalPrinterService.I.ensureConnectAndPrintPng(
        context,
        png,
        feed: feedLines,
        cut: true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('??????????????????????????')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('?????????????????????????????: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _printWeb() async {
    if (!_qzService.isEnabled) {
      await _printWithBrowser(forceRecapture: true);
      return;
    }
    if (!mounted) return;
    setState(() => _busyCapture = true);
    var releaseBusy = true;
    try {
      QzStatusSnapshot status = _qzService.statusNotifier.value;
      if (!status.isReady) {
        try {
          await _qzService.ensureReady();
        } on QzPrintException catch (error) {
          _showQzErrorSnackBar(error);
        } catch (error) {
          if (mounted) {
            _showSnackBarSafe(
              SnackBar(content: Text('????????? QZ Tray ?????????: $error')),
            );
          }
        }
        status = _qzService.statusNotifier.value;
      }
      if (status.isReady) {
        if (mounted) setState(() => _busyCapture = false);
        releaseBusy = false;
        await _printWithQz(forceRecapture: true);
        return;
      }
      if (!mounted) return;
      _showSnackBarSafe(
        const SnackBar(
          content: Text(
            'QZ Tray ????????????????? ????????????????????????????????????????????',
          ),
        ),
      );
    } finally {
      if (releaseBusy && mounted) {
        setState(() => _busyCapture = false);
      }
    }
  }

  Future<void> _printWithBrowser({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      if (_browserMode == BrowserPrintMode.png) {
        final png = await _ensurePng(forceRecapture: forceRecapture);
        if (!mounted) return;
        if (png == null) {
          _showSnackBarSafe(
            const SnackBar(content: Text('????????????????????????????????')),
          );
          return;
        }
        final String base64 = _cachedPngBase64 ?? base64Encode(png);
        await BrowserPrintService.I.printPng(
          base64,
          pixelWidth: _browserPixelWidth,
          autoClose: _browserAutoClose,
        );
      } else {
        final receipt = _sampleReceiptData();
        final appointment = _sampleAppointmentData();
        final slip = AppointmentSlipModel(
          clinic: receipt.clinic,
          patient: receipt.patient,
          appointment: appointment,
        );
        final payload = BrowserPrintPayloadBuilder.combined(
          receipt: receipt,
          slip: slip,
          clinicName: _clinicName,
          clinicAddress: _clinicAddress,
          clinicPhone: _clinicPhone,
          clinicTaxId: _clinicTaxId,
          clinicLineId: _clinicLineId,
          headerSpace: _printingHeaderSpace,
          pixelWidth: _browserPixelWidth,
          logoBytes: _logo,
        );
        await BrowserPrintService.I.printHtml(
          payload,
          autoClose: _browserAutoClose,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(content: Text('???????????????????????????: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _printWithQz({bool forceRecapture = false}) async {
    if (_busyCapture) return;
    if (!_qzService.isEnabled) {
      _showSnackBarSafe(
        const SnackBar(content: Text('QZ Tray ??????????????????????????')),
      );
      return;
    }

    setState(() => _busyCapture = true);

    try {
      final png = await _ensurePng(forceRecapture: forceRecapture);
      if (!mounted) return;
      if (png == null) {
        _showSnackBarSafe(
          const SnackBar(content: Text('????????????????????????????????')),
        );
        return;
      }
      await _performQzPrint(png);
    } on QzPrintException catch (error) {
      await _handleQzException(error);
    } catch (error) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(content: Text('????????? QZ Tray ???????: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  Future<void> _performQzPrint(Uint8List png) async {
    await _qzService.ensureReady();
    if (!mounted) return;
    try {
      await _qzService.ensureSecurityReady();
    } on QzPrintException catch (error) {
      final QzStatusSnapshot? snapshot =
          error.original is QzStatusSnapshot
              ? error.original as QzStatusSnapshot
              : null;
      await _showQzSecurityDialog(error, snapshot);
      return;
    }
    final List<String> printers = await _qzService.listPrinters();
    if (!mounted) return;
    String? printer = _savedQzPrinter;

    if (printer != null && !printers.contains(printer)) {
      await _qzService.savePrinter(null);
      printer = null;
      if (mounted) {
        setState(() => _savedQzPrinter = null);
        _showSnackBarSafe(
          const SnackBar(
            content: Text(
              '??????????????????????????? QZ Tray ???? ??????????????',
            ),
          ),
        );
      }
    }

    if (printer == null) {
      final choice = await _pickPrinter(printers);
      if (!mounted) return;
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

    final int feedLines = PrintSettings.feedLinesFromSetting(_printingPostFeed);
    final result = await _qzService.printPng(
      png,
      printerName: printer,
      postFeed: feedLines,
    );
    final String? used = result.printerName ?? printer;
    if (used != null && used.isNotEmpty) {
      await _qzService.savePrinter(used);
      if (mounted) setState(() => _savedQzPrinter = used);
    }

    if (mounted) {
      _showSnackBarSafe(
        const SnackBar(content: Text('????????? QZ Tray ?????????????')),
      );
    }
  }

  Future<void> _handleQzException(QzPrintException error) async {
    if (!mounted) return;
    if (error.code == 'qz_printer_not_found') {
      await _handlePrinterNotFound(error);
      return;
    }
    _showQzErrorSnackBar(error);
  }

  Future<void> _handlePrinterNotFound(QzPrintException error) async {
    if (!mounted) return;
    await _qzService.savePrinter(null);
    if (mounted) {
      setState(() => _savedQzPrinter = null);
    }
    _hideCurrentSnackBarSafe();
    _showSnackBarSafe(SnackBar(content: Text(error.message)));
    try {
      final List<String> printers = await _qzService.listPrinters();
      if (!mounted || printers.isEmpty) {
        return;
      }
      final _PrinterChoice? choice = await _pickPrinter(printers);
      if (!mounted || choice == null) {
        return;
      }
      await _qzService.savePrinter(choice.remember ? choice.printerName : null);
      if (choice.remember && choice.printerName != null && mounted) {
        setState(() => _savedQzPrinter = choice.printerName);
      }
      _hideCurrentSnackBarSafe();
      await _printWithQz();
    } catch (e) {
      if (!mounted) return;
      _showSnackBarSafe(
        SnackBar(
          content: Text('?????????????????????????????????? QZ Tray: $e'),
        ),
      );
    }
  }

  void _showQzErrorSnackBar(QzPrintException error) {
    if (!mounted) return;
    _hideCurrentSnackBarSafe();
    _showSnackBarSafe(
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
                    _hideCurrentSnackBarSafe();
                    _printWithQz();
                  },
                  child: const Text('???????????'),
                ),
                TextButton(
                  onPressed: () {
                    _hideCurrentSnackBarSafe();
                    _runQzSelfTestFromSettings();
                  },
                  child: const Text('Self-test (QZ Tray)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQzSecurityDialog(
    QzPrintException error,
    QzStatusSnapshot? status,
  ) async {
    if (!mounted) return;
    final bool certificateInvalid = status?.hasCertificateIssue ?? false;
    final bool whitelistOk = status?.isWhitelisted ?? false;
    final String subject = status?.certificateSubject ?? '-';
    final String issuer = status?.certificateIssuer ?? '-';
    final String? expiresAt =
        status?.certificateExpiresAt?.toLocal().toString();

    final List<Widget> contentWidgets = [
      Text(
        certificateInvalid
            ? '??????????? QZ Tray ???????????????? ????????????????????'
            : 'QZ Tray ??????????????????????????????? (Untrusted website)',
      ),
      const SizedBox(height: 12),
      Text('Subject: $subject'),
      Text('Issuer: $issuer'),
    ];
    if (expiresAt != null) {
      contentWidgets.addAll([
        const SizedBox(height: 8),
        Text('???????: $expiresAt'),
      ]);
    }
    contentWidgets.addAll([
      const SizedBox(height: 12),
      Text(
        whitelistOk
            ? '?? whitelist ???????? ??????????? QZ Tray ??????????????????????'
            : '???????? whitelist ?????????? localhost/127.0.0.1 ?? whitelist.txt ???????? Site Manager',
      ),
    ]);

    final bool? action = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('QZ Tray ??????????????'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentWidgets,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('???'),
            ),
            TextButton(
              onPressed: () async {
                await _qzService.ensureWhitelist();
                if (!mounted) return;
                _showSnackBarSafe(
                  const SnackBar(
                    content: Text('????? host ???? whitelist ????'),
                  ),
                );
                Navigator.of(context).pop(true);
              },
              child: const Text('????????? whitelist'),
            ),
            TextButton(
              onPressed: () async {
                final bool opened = await _qzService.openSiteManager();
                if (!mounted) return;
                if (!opened) {
                  _showSnackBarSafe(
                    const SnackBar(
                      content: Text('????????????? QZ Tray Site Manager ???'),
                    ),
                  );
                }
                Navigator.of(context).pop(opened);
              },
              child: const Text('???? Site Manager'),
            ),
          ],
        );
      },
    );

    if (action == true && certificateInvalid && mounted) {
      _showSnackBarSafe(
        const SnackBar(
          content: Text(
            '????????????????????????????? qz.io/latest-signing ????????????? QZ Tray',
          ),
        ),
      );
    }
  }

  Future<_PrinterChoice?> _pickPrinter(List<String> printers) async {
    if (!mounted) return null;
    if (printers.isEmpty) {
      _showSnackBarSafe(
        const SnackBar(
          content: Text('QZ Tray ???????????????????????????????'),
        ),
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
              title: const Text('????????????????? QZ Tray'),
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
                            title: const Text('???????????'),
                            value: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('????????????????????'),
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('??????'),
                ),
                FilledButton(
                  onPressed:
                      selection == null && rememberSelection
                          ? null
                          : () {
                            Navigator.of(context).pop(
                              _PrinterChoice(
                                printerName: selection,
                                remember:
                                    rememberSelection && selection != null,
                              ),
                            );
                          },
                  child: const Text('????'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _qzStatusColor(QzStatusSnapshot status) {
    if (status.isReady) {
      return Colors.green.shade400;
    }
    if (status.state == QzConnectionState.connecting) {
      return Colors.amber.shade400;
    }
    if (status.lastErrorCode != null && status.lastErrorCode!.isNotEmpty) {
      return Colors.red.shade300;
    }
    return Colors.blueGrey.shade300;
  }

  Future<void> _showWebPrinterMenu() async {
    if (!mounted) return;
    if (!_qzService.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<QzStatusSnapshot>(
                valueListenable: _qzService.statusNotifier,
                builder: (context, status, _) {
                  return ListTile(
                    leading: Text(
                      qzStatusEmoji(status),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: const Text('เชื่อมต่อ QZ Tray'),
                    subtitle: Text(qzStatusMessage(status)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _connectQzFromSettings();
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('เปิด QZ Tray'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _launchQzTrayFromSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_outlined),
                title: const Text('ลองโหลดบริดจ์ใหม่'),
                subtitle: const Text(
                  'รีโหลดสคริปต์ QZ Tray และลองเชื่อมต่ออีกครั้ง',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  retryQzBridge(context, _qzService);
                },
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Self-test (QZ Tray)'),
                subtitle: const Text('ส่งคำสั่งทดสอบการเชื่อมต่อ'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _runQzSelfTestFromSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('QZ Diagnostics'),
                subtitle: const Text('ดู origin ปัจจุบันและสถานะความปลอดภัย'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showQzDiagnosticsSheet(context, _qzService);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectQzFromSettings() async {
    if (!_qzService.isEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _qzService.ensureReady();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('เชื่อมต่อ QZ Tray เรียบร้อย')),
      );
    } on QzPrintException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('เชื่อมต่อ QZ Tray ไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _launchQzTrayFromSettings() async {
    if (!_qzService.isEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _qzService.launchQzTray();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('สั่งเปิด QZ Tray แล้ว')),
      );
    } on QzPrintException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('เปิด QZ Tray ไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _runQzSelfTestFromSettings() async {
    if (!_qzService.isEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _qzService.runSelfTestWithPrints();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          content: Text(_summarizeSelfTestResult(result)),
        ),
      );
    } on QzPrintException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Self-test ไม่สำเร็จ: $error')),
      );
    }
  }

  String _summarizeSelfTestResult(QzSelfTestRunResult result) {
    final lines = <String>[
      _summarizeSelfTestReport(result.report),
      _formatSelfTestTaskSummary('RAW', result.raw),
      _formatSelfTestTaskSummary('PNG', result.image),
    ];
    if (result.printerName != null && result.printerName!.isNotEmpty) {
      lines.add('เครื่องพิมพ์: ${result.printerName}');
    }
    return lines.join('\n');
  }

  String _summarizeSelfTestReport(QzSelfTestReport report) {
    final parts = <String>[
      report.isActive ? 'QZ Tray พร้อมใช้งาน' : 'QZ Tray ไม่ตอบสนอง',
    ];
    if (report.version != null && report.version!.isNotEmpty) {
      parts.add('เวอร์ชัน ${report.version}');
    }
    if (report.printersCount != null) {
      parts.add('เครื่องพิมพ์ ${report.printersCount}');
    }
    if (report.lastError != null) {
      parts.add('ข้อผิดพลาด: ${report.lastError!.code}');
    }
    return parts.join(' • ');
  }

  String _formatSelfTestTaskSummary(String label, QzSelfTestTaskResult task) {
    if (task.skipped) {
      final String detail =
          task.message.trim().isEmpty ? '' : ' - ${task.message.trim()}';
      return '$label: ข้าม$detail';
    }
    final String status = task.success ? 'สำเร็จ' : 'ล้มเหลว';
    final String code =
        (task.errorCode == null || task.errorCode!.isEmpty)
            ? ''
            : ' (${task.errorCode})';
    final String detail =
        task.message.trim().isEmpty ? '' : ' - ${task.message.trim()}';
    return '$label: $status$code$detail';
  }

  Widget _buildPermFab() {
    if (kIsWeb && _qzService.isEnabled) {
      return ValueListenableBuilder<QzStatusSnapshot>(
        valueListenable: _qzService.statusNotifier,
        builder: (context, status, _) {
          final bool busy = status.state == QzConnectionState.connecting;
          final Color bg = _qzStatusColor(status);
          final Widget iconWidget =
              busy
                  ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(
                    status.isReady
                        ? Icons.check_circle_outline
                        : Icons.print_outlined,
                    color: Colors.white,
                  );
          final String label =
              status.isReady ? 'พร้อมพิมพ์แล้ว' : 'เชื่อมต่อเครื่องพิมพ์';
          return FloatingActionButton.extended(
            heroTag: 'permFab',
            backgroundColor: bg,
            onPressed: _showWebPrinterMenu,
            icon: iconWidget,
            label: Text(label),
          );
        },
      );
    }

    if (kIsWeb) {
      return FloatingActionButton.extended(
        heroTag: 'permFab',
        backgroundColor: Colors.blueGrey.shade300,
        onPressed: null,
        icon: const Icon(Icons.print_disabled, color: Colors.white),
        label: const Text('ปิดการใช้งาน QZ Tray'),
      );
    }

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
      child:
          _busyPermissionAction
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
      bill: BillInfo(billNo: 'XX-XXXX', issuedAt: DateTime.now()),
      patient: const PatientInfo(name: 'คุณ ตัวอย่าง การพิมพ์', hn: 'HNXXXXX'),
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

class _PrinterChoice {
  const _PrinterChoice({required this.printerName, required this.remember});

  final String? printerName;
  final bool remember;
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
              Text('โทร: $clinicPhone', textAlign: TextAlign.center),
            if ((clinicTaxId ?? '').isNotEmpty)
              Text(
                'เลขผู้เสียภาษี: $clinicTaxId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            if ((clinicLineId ?? '').isNotEmpty)
              Text(
                'Line ID: $clinicLineId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 6),
            const Text('*********************'),
            const SizedBox(height: 4),
            const Text(
              'ใบเสร็จรับเงิน',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('เลขที่', receipt.bill.billNo),
                _kv(
                  'วันที่',
                  ThFormat.dateThai(receipt.bill.issuedAt, shortYear: false),
                ),
                _kv('เวลา', ThFormat.timeThai(receipt.bill.issuedAt)),
                _kv('ชื่อ', ''),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      receipt.patient.displayName,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                _kv(
                  'หัตถการ:',
                  receipt.lines.isNotEmpty ? receipt.lines.first.name : '-',
                ),
                _kv('ค่าบริการ', ThFormat.baht(receipt.totals.grandTotal)),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 20, thickness: 1, color: Colors.black),
            const SizedBox(height: 10),
            const Text(
              'นัดครั้งต่อไป',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  'วันที่นัด',
                  ThFormat.dateThai(nextAppointment.startAt, shortYear: false),
                ),
                _kv('เวลานัด', ThFormat.timeThai(nextAppointment.startAt)),
                if ((nextAppointment.note ?? '').trim().isNotEmpty)
                  _kv('หัตถการ', nextAppointment.note!.trim()),
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
