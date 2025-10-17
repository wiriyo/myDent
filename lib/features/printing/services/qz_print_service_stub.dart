import 'dart:async';

import 'qz_models.dart';

class QzPrintPlatform {
  Stream<QzStatusSnapshot> get statusStream =>
      Stream<QzStatusSnapshot>.value(const QzStatusSnapshot.inactive());

  Future<QzStatusSnapshot> readStatus() =>
      Future<QzStatusSnapshot>.value(const QzStatusSnapshot.inactive());

  Future<QzStatusSnapshot> refreshSecurityStatus() => Future.error(
        QzPrintException(
          'qz_unsupported',
          'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
        ),
      );

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

  Future<QzSelfTestRunResult> runSelfTestPrints({String? printerName}) =>
      Future.error(
        QzPrintException(
          'qz_unsupported',
          'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
        ),
      );

  Future<void> ensureWhitelist() => Future.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );

  Future<bool> openSiteManager() => Future<bool>.error(
    QzPrintException(
      'qz_unsupported',
      'QZ Tray printing ใช้งานได้เฉพาะบนเว็บเท่านั้น',
    ),
  );
}

QzPrintPlatform createQzPrintPlatform() => QzPrintPlatform();
