enum QzConnectionState {
  inactive,
  connecting,
  active,
}

class QzStatusSnapshot {
  const QzStatusSnapshot({
    required this.state,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.timestamp,
  });

  const QzStatusSnapshot.inactive()
      : state = QzConnectionState.inactive,
        lastErrorCode = null,
        lastErrorMessage = null,
        timestamp = null;

  final QzConnectionState state;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? timestamp;

  bool get isReady =>
      state == QzConnectionState.active && (lastErrorCode == null || lastErrorCode!.isEmpty);
}

class QzPrintResult {
  const QzPrintResult({this.printerName});

  final String? printerName;
}

class QzPrintException implements Exception {
  QzPrintException(this.code, this.message, [this.original]);

  final String code;
  final String message;
  final Object? original;

  @override
  String toString() => 'QzPrintException($code, $message)';
}

class QzEndpointAttempt {
  const QzEndpointAttempt({
    required this.url,
    required this.secure,
    this.skipped = false,
    this.success,
    this.errorCode,
    this.message,
  });

  final String url;
  final bool secure;
  final bool skipped;
  final bool? success;
  final String? errorCode;
  final String? message;
}

class QzSelfTestReport {
  const QzSelfTestReport({
    this.version,
    this.isActive = false,
    this.printersCount,
    this.lastError,
    this.triedEndpoints = const <QzEndpointAttempt>[],
  });

  final String? version;
  final bool isActive;
  final int? printersCount;
  final QzPrintException? lastError;
  final List<QzEndpointAttempt> triedEndpoints;
}
