import 'dart:typed_data';

import 'package:flutter/material.dart';

class PrinterDevice {
  final String name;
  final String mac;
  const PrinterDevice({required this.name, required this.mac});
}

abstract class PrinterClient {
  Future<void> ensureConnectAndPrintPng(
    BuildContext context,
    Uint8List pngBytes, {
    int feed = 3,
    bool cut = true,
  });
}

class ThermalPrinterService implements PrinterClient {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();
  static PrinterClient? debugOverride;
  static PrinterClient get I => debugOverride ?? instance;

  Future<bool> hasPrintingPermissions() async => false;

  Future<bool> ensurePrintingPermissions(BuildContext context) async {
    _showUnsupported(context);
    return false;
  }

  Future<List<PrinterDevice>> discoverPaired() async => const [];

  Future<bool> isConnected() async => false;

  Future<bool> connectByMac(
    String mac, {
    int maxRetries = 2,
    Duration retryDelay = const Duration(milliseconds: 600),
  }) async {
    return false;
  }

  Future<void> disconnect() async {}

  Future<bool> connectWithPicker(
    BuildContext context, {
    bool rememberSelection = true,
  }) async {
    _showUnsupported(context);
    return false;
  }

  Future<void> saveDefault(PrinterDevice d) async {}

  Future<PrinterDevice?> loadDefault() async => null;

  Future<bool> ensureConnectedOrPick(BuildContext context) async {
    _showUnsupported(context);
    return false;
  }

  @override
  Future<void> ensureConnectAndPrintPng(
    BuildContext context,
    Uint8List pngBytes, {
    int feed = 3,
    bool cut = true,
  }) async {
    _showUnsupported(context);
  }

  void _showUnsupported(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thermal printing is not supported on this platform.')),
    );
  }
}
