import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

import 'qz_models.dart';

class QzPrintPlatform {
  QzPrintPlatform() {
    _setupStatusListener();
    _primeInitialStatus();
  }

  static const String _statusEventName = 'mydent-qz-status';

  final StreamController<QzStatusSnapshot> _statusController =
      StreamController<QzStatusSnapshot>.broadcast();
  JSFunction? _statusEventCallback;

  Stream<QzStatusSnapshot> get statusStream => _statusController.stream;

  Future<QzStatusSnapshot> readStatus() async {
    final QzStatusSnapshot snapshot = await _readStatusSnapshot();
    _statusController.add(snapshot);
    return snapshot;
  }

  Future<void> ensureReady() => _guard(() async {
    await _ensureLoaded();
    await _connectWithDiagnostics();
  });

  Future<void> ensureConnected() => _guard(_connectWithDiagnostics);

  Future<List<String>> listPrinters() => _guard(() async {
    await _ensureLoaded();
    await _connectWithDiagnostics();
    final Object? result = await _invokePromise('mydentQzListPrinters');
    if (result is Iterable) {
      return result
          .whereType<Object?>()
          .map((item) => item?.toString().trim())
          .where((value) => value != null && value.isNotEmpty)
          .cast<String>()
          .toList(growable: false);
    }
    return const <String>[];
  });

  Future<String?> printPng(String base64Png, {String? printerName}) =>
      _guard(() async {
        await _ensureLoaded();
        await _connectWithDiagnostics();
        final Object? result = await _invokePromise(
          'mydentQzPrintPng',
          <dynamic>[base64Png, printerName],
        );
        if (result is Map) {
          final Object? value = result['printer'];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
        return printerName;
      });

  Future<void> launchQzTray() => _guard(() async {
    await _invokePromise('mydentQzLaunch');
  });

  Future<QzSelfTestReport> diagnose() => _guard(() async {
    await _ensureLoaded();
    final dynamic result = await _invokePromise('mydentQzSelfTest');
    return _toSelfTestReport(result);
  });

  Future<T> _guard<T>(FutureOr<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw _mapJsError(error);
    }
  }

  Future<void> _ensureLoaded() => _guardBridge('mydentQzEnsureLoaded');

  Future<void> _connect() => _guardBridge('mydentQzConnect');

  Future<void> _connectWithDiagnostics() async {
    try {
      await _connect();
    } catch (error) {
      final QzSelfTestReport? report = await _trySelfTest();
      throw _decorateWithSelfTest(_mapJsError(error), report);
    }
  }

  Future<QzSelfTestReport?> _trySelfTest() async {
    try {
      final dynamic result = await _invokePromise('mydentQzSelfTest');
      return _toSelfTestReport(result);
    } catch (_) {
      return null;
    }
  }

  void _setupStatusListener() {
    if (_statusEventCallback != null) {
      return;
    }
    try {
      _statusEventCallback = js_util.allowInterop((web.Event event) {
        final QzStatusSnapshot snapshot = _snapshotFromEvent(event);
        _statusController.add(snapshot);
      });
      js_util.callMethod<void>(
        web.window,
        'addEventListener',
        <Object?>[_statusEventName, _statusEventCallback],
      );
    } catch (_) {
      _statusEventCallback = null;
      // ignore listener attachment errors
    }
  }

  void _primeInitialStatus() {
    Future<void>.microtask(() async {
      final QzStatusSnapshot snapshot = await _readStatusSnapshot();
      _statusController.add(snapshot);
    });
  }

  Future<QzStatusSnapshot> _readStatusSnapshot() async {
    if (!_hasBridge('mydentQzStatusDetail')) {
      return const QzStatusSnapshot.inactive();
    }
    try {
      final Object? result = await _invokePromise('mydentQzStatusDetail');
      return _toStatusSnapshot(result);
    } catch (_) {
      return const QzStatusSnapshot.inactive();
    }
  }

  QzStatusSnapshot _snapshotFromEvent(web.Event event) {
    if (event is web.CustomEvent) {
      final JSAny? detail = event.detail;
      final Object? data = detail?.dartify();
      return _toStatusSnapshot(data);
    }
    return const QzStatusSnapshot.inactive();
  }

  Future<void> _guardBridge(String functionName) async {
    await _invokePromise(functionName);
  }

  Future<Object?> _invokePromise(
    String functionName, [
    List<dynamic> args = const <dynamic>[],
  ]) async {
    if (!_hasBridge(functionName)) {
      throw QzPrintException('qz_bridge_missing', _bridgeMissingMessage);
    }
    final JSObject windowObject = web.window as JSObject;
    final List<JSAny?>? jsArgs =
        args.isEmpty
            ? null
            : args.map<JSAny?>(_toJsArgument).toList(growable: false);
    final JSAny? result = windowObject.callMethodVarArgs(
      functionName.toJS,
      jsArgs,
    );
    if (result == null) {
      return null;
    }
    if (result.instanceOfString('Promise')) {
      final JSPromise<JSAny?> promise = result as JSPromise<JSAny?>;
      final JSAny? awaited = await promise.toDart;
      return awaited?.dartify();
    }
    final Object? dartified = result.dartify();
    if (dartified is Future) {
      return await dartified;
    }
    return dartified;
  }

  JSAny? _toJsArgument(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value.toJS;
    }
    if (value is num) {
      return value.toJS;
    }
    if (value is bool) {
      return value.toJS;
    }
    if (value is Map || value is Iterable) {
      return js_util.jsify(value) as JSAny?;
    }
    throw ArgumentError(
      'Unsupported argument type for JS interop: ${value.runtimeType}',
    );
  }

  bool _hasBridge(String name) {
    try {
      return js_util.hasProperty(web.window, name);
    } catch (_) {
      return false;
    }
  }

  QzStatusSnapshot _toStatusSnapshot(Object? raw) {
    final Map<String, Object?> data = _dartifyMap(raw);
    final String stateRaw = data['status']?.toString() ?? '';
    final QzConnectionState state = _parseStatusState(stateRaw);
    final Map<String, Object?> lastError = _dartifyMap(data['lastError']);
    final String? lastErrorCode = lastError['code']?.toString();
    final String? lastErrorMessage = lastError['message']?.toString();
    final DateTime? timestamp = _parseTimestamp(data['timestamp']);
    return QzStatusSnapshot(
      state: state,
      lastErrorCode: lastErrorCode,
      lastErrorMessage: lastErrorMessage,
      timestamp: timestamp,
    );
  }

  QzSelfTestReport _toSelfTestReport(Object? raw) {
    final Map<String, Object?> data = _dartifyMap(raw);
    final Object? lastErrorRaw = data['lastError'];
    final QzPrintException? mappedError =
        lastErrorRaw == null ? null : _mapJsError(lastErrorRaw);

    final List<QzEndpointAttempt> endpoints = _parseEndpoints(
      data['triedEndpoints'],
    );

    return QzSelfTestReport(
      version: data['version']?.toString(),
      isActive: data['isActive'] == true,
      printersCount: _toInt(data['printersCount']),
      lastError: mappedError,
      triedEndpoints: endpoints,
    );
  }

  List<QzEndpointAttempt> _parseEndpoints(Object? raw) {
    if (raw is Iterable) {
      return raw
          .whereType<Object?>()
          .map((item) {
            if (item is Map) {
              final String url = item['url']?.toString() ?? '';
              final bool secure = item['secure'] == true;
              final bool skipped = item['skipped'] == true;
              final Object? successValue = item['success'];
              final bool? success = successValue is bool ? successValue : null;
              final String? errorCode = item['error']?.toString();
              final String? message = item['message']?.toString();
              return QzEndpointAttempt(
                url: url,
                secure: secure,
                skipped: skipped,
                success: success,
                errorCode: errorCode,
                message: message,
              );
            }
            return null;
          })
          .whereType<QzEndpointAttempt>()
          .toList(growable: false);
    }
    return const <QzEndpointAttempt>[];
  }

  QzConnectionState _parseStatusState(String raw) {
    switch (raw.toLowerCase()) {
      case 'active':
        return QzConnectionState.active;
      case 'connecting':
        return QzConnectionState.connecting;
      default:
        return QzConnectionState.inactive;
    }
  }

  DateTime? _parseTimestamp(Object? raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final int? parsed = int.tryParse(raw);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return null;
  }

  QzPrintException _decorateWithSelfTest(
    QzPrintException base,
    QzSelfTestReport? report,
  ) {
    if (report == null) {
      return base;
    }

    final StringBuffer buffer = StringBuffer(base.message.trim());

    if (report.lastError != null &&
        report.lastError!.message.isNotEmpty &&
        report.lastError!.code != base.code) {
      buffer
        ..writeln('\n\nสรุปจาก Self-test: ${report.lastError!.message}')
        ..writeln();
    }

    if (report.triedEndpoints.isNotEmpty) {
      buffer.writeln('ช่องทางที่ลองเชื่อมต่อ:');
      for (final QzEndpointAttempt attempt in report.triedEndpoints) {
        final String status;
        if (attempt.skipped) {
          status = 'ข้าม (ไม่รองรับในบริบทนี้)';
        } else if (attempt.success == true) {
          status = 'สำเร็จ';
        } else {
          final String codePart =
              (attempt.errorCode ?? '').isEmpty
                  ? ''
                  : ' (${attempt.errorCode})';
          final String messagePart =
              (attempt.message ?? '').isEmpty ? '' : ' - ${attempt.message}';
          status = 'ล้มเหลว$codePart$messagePart';
        }
        buffer.writeln('- ${attempt.url} → $status');
      }
    }

    if (report.printersCount != null) {
      buffer.writeln(
        '\nจำนวนเครื่องพิมพ์ที่ QZ Tray พบ: ${report.printersCount}',
      );
    }

    return QzPrintException(base.code, buffer.toString(), base.original);
  }

  QzPrintException _mapJsError(Object error) {
    if (error is QzPrintException) {
      return error;
    }

    final String code = _extractCode(error) ?? 'qz_unknown';
    final String baseMessage =
        _extractMessage(error) ??
        _defaultMessageForCode(code, error.toString());
    final String finalMessage =
        _codesNeedingAdvice.contains(code)
            ? _appendAdvice(baseMessage)
            : baseMessage;
    return QzPrintException(code, finalMessage, error);
  }

  String? _extractCode(Object? error) {
    if (error == null) {
      return null;
    }
    if (error is QzPrintException) {
      return error.code;
    }
    final String? fromProperty = _readStringProperty(error, 'code');
    if (fromProperty != null && fromProperty.isNotEmpty) {
      final String normalized = fromProperty.toLowerCase();
      if (normalized.contains('invalid_signature') || normalized.contains('signature')) {
        return 'qz_security_error';
      }
      return fromProperty;
    }
    return null;
  }

  String? _extractMessage(Object? error) {
    if (error == null) {
      return null;
    }
    if (error is QzPrintException) {
      return error.message;
    }
    final String? fromProperty = _readStringProperty(error, 'message');
    if (fromProperty != null && fromProperty.isNotEmpty) {
      return fromProperty;
    }
    if (error is String && error.isNotEmpty) {
      return error;
    }
    return error.toString();
  }

  Map<String, Object?> _dartifyMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return <String, Object?>{};
  }

  String? _readStringProperty(Object? source, String property) {
    if (source is Map) {
      final Object? value = source[property];
      if (value is String) {
        return value;
      }
    }
    if (source == null) {
      return null;
    }
    try {
      final JSObject jsObject = JSObject.fromInteropObject(source);
      final JSAny? jsValue = jsObject[property];
      final Object? dartValue = jsValue?.dartify();
      if (dartValue is String) {
        return dartValue;
      }
    } catch (_) {
      // ignore non-JS interop objects
    }
    return null;
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

QzPrintPlatform createQzPrintPlatform() => QzPrintPlatform();

const String _bridgeMissingMessage =
    'ไม่พบ JS bridge สำหรับ QZ Tray (ลองหยุด dev server แล้วรัน flutter run -d chrome ใหม่)';

const Set<String> _codesNeedingAdvice = <String>{
  'qz_connect_failed',
  'qz_not_running',
  'qz_ws_refused',
  'qz_ws_timeout',
  'qz_security_error',
  'qz_bridge_missing',
  'qz_mixed_content',
};

String _appendAdvice(String message) {
  final String trimmed = message.trim();
  final StringBuffer buffer = StringBuffer(trimmed);
  final String origin = web.window.location.origin;
  final List<String> tips = <String>[
    'เปิดโปรแกรม QZ Tray แล้วอนุญาตการเชื่อมต่อเมื่อมีแจ้งเตือน',
    'รีเฟรชหน้า MyDent หลังแก้ไขการตั้งค่าหรือกด Allow ใน QZ Tray',
    'ตรวจสอบ Firewall/Antivirus ให้อนุญาต QZ Tray ใช้งานพอร์ต 8181',
    'เพิ่ม $origin ใน QZ Tray → Settings → Security → Allowed Origins',
    'ใช้ QZ Tray เวอร์ชัน 2.2.x ขึ้นไป และรีสตาร์ทโปรแกรมหลังปรับตั้งค่า',
  ];
  buffer.writeln('\n\nคำแนะนำเพิ่มเติม:');
  for (final String tip in tips) {
    buffer.writeln('- $tip');
  }
  return buffer.toString();
}

String _defaultMessageForCode(String code, String fallback) {
  switch (code) {
    case 'qz_bridge_missing':
      return _bridgeMissingMessage;
    case 'qz_security_error':
      return 'certificate หรือ signature ของ QZ Tray ไม่ผ่านการตรวจสอบ หรือ origin นี้ยังไม่ได้อยู่ใน Allowed Origins (หลังแก้ไขให้รีเฟรชหน้าแล้วลองใหม่)';
    case 'qz_ws_timeout':
      return 'หมดเวลารอการตอบสนองจาก QZ Tray กรุณาตรวจสอบว่าโปรแกรมเปิดอยู่และพอร์ต 8181 ไม่ถูกบล็อก';
    case 'qz_ws_refused':
      return 'ไม่สามารถเชื่อมต่อพอร์ต 8181 ได้ อาจถูก Firewall หรือ Antivirus บล็อกไว้';
    case 'qz_not_running':
      return "กรุณาเปิด QZ Tray ก่อนใช้งาน หรือคลิก 'เปิด QZ Tray' แล้วลองใหม่";
    case 'qz_printer_not_found':
      return 'ไม่พบเครื่องพิมพ์ที่เลือกใน QZ Tray';
    case 'qz_mixed_content':
      return 'หน้าเว็บนี้ทำงานผ่าน HTTPS จำเป็นต้องเชื่อมต่อ QZ Tray ผ่าน wss:// เท่านั้น';
    default:
      return fallback.isNotEmpty
          ? fallback
          : 'เกิดข้อผิดพลาดระหว่างใช้งาน QZ Tray';
  }
}
