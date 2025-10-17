import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qz_models.dart';
import 'qz_print_service_stub.dart'
    if (dart.library.html) 'qz_print_service_web.dart'
    as platform;

export 'qz_models.dart';

const bool _envQzEnabled = bool.fromEnvironment(
  'MYDENT_ENABLE_QZ',
  defaultValue: true,
);
const String _bridgeMissingMessage =
    'ไม่พบ JS bridge สำหรับ QZ Tray (ลองกด "ลองโหลดบริดจ์ใหม่" หรือรีเฟรชหน้า หากยังไม่ดีให้หยุดแล้วรัน flutter run -d chrome ใหม่)';

class QzPrintService {
  QzPrintService._() {
    _delegate.statusStream.listen(
      (QzStatusSnapshot snapshot) {
        statusNotifier.value = snapshot;
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('QZ status stream error: $error');
        }
      },
    );
    scheduleMicrotask(_primeStatus);
  }

  static final QzPrintService I = QzPrintService._();

  static bool _overrideDisabled = false;

  final platform.QzPrintPlatform _delegate = platform.createQzPrintPlatform();
  final QzPrinterPreferences _preferences = QzPrinterPreferences.instance;
  final ValueNotifier<QzStatusSnapshot> statusNotifier =
      ValueNotifier<QzStatusSnapshot>(const QzStatusSnapshot.inactive());

  bool get isAvailableOnPlatform => kIsWeb;

  QzStatusSnapshot get currentStatus => statusNotifier.value;

  bool get isEnabled =>
      isAvailableOnPlatform && _envQzEnabled && !_overrideDisabled;

  void disableForSession() {
    _overrideDisabled = true;
    statusNotifier.value = const QzStatusSnapshot.inactive();
  }

  void enableForSession() {
    _overrideDisabled = false;
    scheduleMicrotask(_primeStatus);
  }

  Future<void> ensureReady() async {
    _assertEnabled();
    try {
      await _delegate.ensureReady();
    } on QzPrintException catch (error) {
      if (kDebugMode) debugPrint('QZ ensureReady error: $error');
      if (_isBridgeMissingCode(error.code)) {
        throw QzPrintException(
          'qz_bridge_missing',
          _bridgeMissingMessage,
          error,
        );
      }
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('QZ ensureReady error: $error');
      _throwMapped(error, 'qz_connect_failed', 'เชื่อมต่อ QZ Tray ไม่สำเร็จ');
    }
  }

  Future<QzStatusSnapshot> ensureSecurityReady() async {
    _assertEnabled();
    try {
      final QzStatusSnapshot snapshot = await _delegate.refreshSecurityStatus();
      if (snapshot.hasCertificateIssue) {
        throw QzPrintException(
          'qz_certificate_invalid',
          'certificate ของ QZ Tray ไม่ถูกต้องหรือหมดอายุ',
          snapshot,
        );
      }
      if (snapshot.isTrusted == false) {
        throw QzPrintException(
          'qz_untrusted',
          'QZ Tray ยังไม่อนุญาตให้ไซต์นี้เชื่อมต่อ (Untrusted website)',
          snapshot,
        );
      }
      return snapshot;
    } on QzPrintException {
      rethrow;
    } catch (error) {
      throw QzPrintException(
        'qz_security_check_failed',
        'ตรวจสอบสถานะความปลอดภัยของ QZ Tray ไม่สำเร็จ',
        error,
      );
    }
  }

  Future<List<String>> listPrinters() async {
    _assertEnabled();
    try {
      return await _delegate.listPrinters();
    } catch (error) {
      if (kDebugMode) debugPrint('QZ listPrinters error: $error');
      _throwMapped(
        error,
        'qz_printer_lookup_failed',
        'ดึงรายชื่อเครื่องพิมพ์จาก QZ Tray ไม่สำเร็จ',
      );
    }
  }

  Future<QzPrintResult> printPng(
    Uint8List pngBytes, {
    String? printerName,
  }) async {
    _assertEnabled();
    final base64Data = base64Encode(pngBytes);
    try {
      final usedPrinter = await _delegate.printPng(
        base64Data,
        printerName: printerName,
      );
      return QzPrintResult(printerName: usedPrinter ?? printerName);
    } catch (error) {
      if (kDebugMode) debugPrint('QZ printPng error: $error');
      _throwMapped(error, 'qz_print_failed', 'สั่งพิมพ์ผ่าน QZ Tray ไม่สำเร็จ');
    }
  }

  Future<void> launchQzTray() async {
    if (!isEnabled) {
      return;
    }
    try {
      await _delegate.launchQzTray();
    } catch (error) {
      if (kDebugMode) debugPrint('QZ launch error: $error');
      _throwMapped(error, 'qz_connect_failed', 'เชื่อมต่อ QZ Tray ไม่สำเร็จ');
    }
  }

  Future<QzSelfTestReport> diagnose() async {
    _assertEnabled();
    try {
      return await _delegate.diagnose();
    } on QzPrintException catch (error) {
      if (kDebugMode) debugPrint('QZ diagnose error: $error');
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('QZ diagnose error: $error');
      throw QzPrintException(
        'qz_diagnose_failed',
        'ตรวจสอบสถานะ QZ Tray ไม่สำเร็จ',
        error,
      );
    }
  }

  Future<QzSelfTestRunResult> runSelfTestWithPrints({String? printerName}) async {
    _assertEnabled();
    try {
      return await _delegate.runSelfTestPrints(printerName: printerName);
    } on QzPrintException {
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('QZ self-test print error: $error');
      throw QzPrintException(
        'qz_print_failed',
        'สั่งพิมพ์ทดสอบผ่าน QZ Tray ไม่สำเร็จ',
        error,
      );
    }
  }

  Future<String?> loadSavedPrinter() => _preferences.load();

  Future<void> savePrinter(String? printerName) =>
      _preferences.save(printerName);

  Future<void> ensureWhitelist() async {
    if (!isEnabled) {
      return;
    }
    try {
      await _delegate.ensureWhitelist();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('QZ ensureWhitelist error: $error');
      }
    }
  }

  Future<bool> openSiteManager() async {
    if (!isEnabled) {
      return false;
    }
    return _delegate.openSiteManager();
  }

  Future<void> _primeStatus() async {
    try {
      final QzStatusSnapshot snapshot = await _delegate.readStatus();
      statusNotifier.value = snapshot;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('QZ prime status error: $error');
      }
      statusNotifier.value = const QzStatusSnapshot.inactive();
    }
  }

  void _assertEnabled() {
    if (!isEnabled) {
      throw QzPrintException(
        'qz_disabled',
        'ฟีเจอร์ QZ Tray printing ถูกปิดอยู่',
      );
    }
  }

  bool _isBridgeMissingCode(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('bridge') ||
        normalized.contains('not_available');
  }

  Never _throwMapped(
    Object error,
    String fallbackCode,
    String fallbackMessage,
  ) {
    if (error is QzPrintException) {
      throw error;
    }
    throw QzPrintException(fallbackCode, fallbackMessage, error);
  }
}

class QzPrinterPreferences {
  const QzPrinterPreferences._();

  static const QzPrinterPreferences instance = QzPrinterPreferences._();

  static const String _storageKey = 'mydent.qz.printerName';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  Future<void> save(String? printerName) async {
    final prefs = await SharedPreferences.getInstance();
    final value = printerName?.trim();
    if (value == null || value.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, value);
    }
  }
}
