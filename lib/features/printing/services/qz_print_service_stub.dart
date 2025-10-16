import 'dart:async';

import 'qz_models.dart';

class QzPrintPlatform {
  Future<void> ensureReady() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );

  Future<void> ensureConnected() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );

  Future<List<String>> listPrinters() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );

  Future<String?> printPng(String base64Png, {String? printerName}) =>
      Future.error(
        QzPrintException(
          'qz_unsupported',
          'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
        ),
      );

  Future<void> launchQzTray() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );

  Future<QzSelfTestReport> diagnose() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );
}

QzPrintPlatform createQzPrintPlatform() => QzPrintPlatform();
