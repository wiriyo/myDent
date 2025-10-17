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
    this.isTrusted,
    this.isCertificateValid,
    this.certificateExpiresAt,
    this.certificateSubject,
    this.certificateIssuer,
    this.whitelistEnsured,
    this.whitelistUpdatedAt,
    this.whitelistError,
    this.environment,
  });

  const QzStatusSnapshot.inactive()
      : state = QzConnectionState.inactive,
        lastErrorCode = null,
        lastErrorMessage = null,
        timestamp = null,
        isTrusted = null,
        isCertificateValid = null,
        certificateExpiresAt = null,
        certificateSubject = null,
        certificateIssuer = null,
        whitelistEnsured = null,
        whitelistUpdatedAt = null,
        whitelistError = null,
        environment = null;

  final QzConnectionState state;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime? timestamp;
  final bool? isTrusted;
  final bool? isCertificateValid;
  final DateTime? certificateExpiresAt;
  final String? certificateSubject;
  final String? certificateIssuer;
  final bool? whitelistEnsured;
  final DateTime? whitelistUpdatedAt;
  final String? whitelistError;
  final String? environment;

  bool get isReady =>
      state == QzConnectionState.active &&
      (lastErrorCode == null || lastErrorCode!.isEmpty) &&
      (isTrusted ?? true) &&
      (isCertificateValid ?? true);

  bool get hasCertificateIssue => (isCertificateValid ?? true) == false;

  bool get isWhitelisted => whitelistEnsured == true && (whitelistError == null || whitelistError!.isEmpty);
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
