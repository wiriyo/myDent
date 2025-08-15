import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Simple wrapper around [BlueThermalPrinter] to handle connection and
/// printing images to a thermal printer via Bluetooth.
class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  bool _connected = false;

  /// Connects to the first bonded device if not already connected.
  Future<void> _ensureConnected() async {
    if (_connected) return;
    final devices = await _bluetooth.getBondedDevices();
    if (devices.isEmpty) {
      throw Exception('ไม่พบเครื่องพิมพ์ที่จับคู่ไว้');
    }
    // Connect to the first paired device.
    await _bluetooth.connect(devices.first);
    _connected = true;
  }

  /// Sends raw image bytes to the printer.
  Future<void> printImage(Uint8List bytes) async {
    await _ensureConnected();
    await _bluetooth.printImageBytes(bytes);
    await _bluetooth.paperCut();
  }

  /// Disconnect from the printer if connected.
  Future<void> disconnect() async {
    if (_connected) {
      await _bluetooth.disconnect();
      _connected = false;
    }
  }
}
