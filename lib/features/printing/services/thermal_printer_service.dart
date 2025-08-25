// lib/features/printing/services/thermal_printer_service.dart
// อัปเดตครั้งสุดท้าย: เพิ่มการขอ Permission.location โดยตรง

import 'dart:io' show Platform;
// ✨ FIX: แก้ไข typo จาก package.flutter -> package:flutter ค่ะ
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class PrinterDevice {
  final String name;
  final String mac;
  const PrinterDevice({required this.name, required this.mac});
}

class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  static const _keyMac = 'mydent.printer.mac';
  static const _keyName = 'mydent.printer.name';

  CapabilityProfile? _profile;
  Future<CapabilityProfile> _loadProfile() async => _profile ??= await CapabilityProfile.load();

  // ✨ FINAL FIX: อัปเกรดฟังก์ชันขออนุญาตให้สมบูรณ์แบบที่สุด!
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // เพิ่มการขอ Location เข้าไปโดยตรง เพราะบาง OS ผูกติดกัน
      Permission.location, 
    ].request();

    var allGranted = true;
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted = false;
        debugPrint('${permission.toString()} was not granted. Status: ${status.toString()}');
      }
    });

    return allGranted;
  }

  Future<List<PrinterDevice>> discoverPaired() async {
    if (!Platform.isAndroid) return const <PrinterDevice>[];
    
    final permissionsOk = await _requestPermissions();
    if (!permissionsOk) return const <PrinterDevice>[];

    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => PrinterDevice(name: d.name, mac: d.macAdress)).toList(growable: false);
  }

  Future<bool> isConnected() async {
    try { return await PrintBluetoothThermal.connectionStatus; } catch (_) { return false; }
  }

  Future<bool> connectByMac(String mac) async {
    final permissionsOk = await _requestPermissions();
    if (!permissionsOk) return false;
    return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<void> disconnect() async { try { await PrintBluetoothThermal.disconnect; } catch (_) {} }

  Future<void> saveDefault(PrinterDevice d) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyMac, d.mac);
    await sp.setString(_keyName, d.name);
  }

  Future<PrinterDevice?> loadDefault() async {
    final sp = await SharedPreferences.getInstance();
    final mac = sp.getString(_keyMac);
    final name = sp.getString(_keyName);
    if (mac == null || name == null) return null;
    return PrinterDevice(name: name, mac: mac);
  }

  Future<bool> ensureConnectedOrPick(BuildContext context) async {
    if (await isConnected()) return true;
    
    final permissionsOk = await _requestPermissions();
    if (!permissionsOk) {
      _toast(context, 'จำเป็นต้องอนุญาตการเข้าถึง Bluetooth และ Location ก่อนนะคะ');
      return false;
    }
    
    final saved = await loadDefault();
    if (saved != null && await connectByMac(saved.mac)) return true;
    
    final picked = await _showPickerDialog(context);
    if (picked == null) return false;
    
    final ok = await connectByMac(picked.mac);
    if (ok) await saveDefault(picked);
    return ok;
  }

  Future<PrinterDevice?> _showPickerDialog(BuildContext context) async {
    // ... (ส่วนนี้เหมือนเดิมค่ะ)
    final devices = await discoverPaired();
    if (!mounted(context)) return null;

    if (devices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('ไม่พบอุปกรณ์ที่จับคู่ไว้'),
          content: const Text('โปรดจับคู่เครื่องพิมพ์ใน Bluetooth settings ก่อนนะคะ'),
          actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('โอเค'))],
        ),
      );
      return null;
    }

    return showDialog<PrinterDevice>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('เลือกเครื่องพิมพ์ (Bluetooth)'),
        content: SizedBox(
          width: 360,
          height: 360,
          child: ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (ctx, __) => const Divider(height: 1),
            itemBuilder: (itemCtx, i) {
              final d = devices[i];
              return ListTile(
                title: Text(d.name),
                subtitle: Text(d.mac),
                onTap: () => Navigator.of(itemCtx).pop(d),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(null), child: const Text('ยกเลิก'))],
      ),
    );
  }

  Future<void> printPng(Uint8List pngBytes, {int feed = 3, bool cut = true, PosAlign align = PosAlign.center}) async {
    // ... (ส่วนนี้เหมือนเดิมค่ะ)
    final profile = await _loadProfile();
    final gen = Generator(PaperSize.mm80, profile);

    img.Image? src = img.decodePng(pngBytes);
    if (src == null) throw Exception('ไม่สามารถอ่าน PNG');
    if (src.width != 576) src = img.copyResize(src, width: 576);

    final bytes = <int>[];
    bytes.addAll(gen.imageRaster(src, align: align, highDensityHorizontal: true, highDensityVertical: true));
    if (feed > 0) bytes.addAll(gen.feed(feed));
    if (cut) { bytes.addAll(gen.cut(mode: PosCutMode.full)); bytes.addAll(gen.feed(2)); }

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> ensureConnectAndPrintPng(BuildContext context, Uint8List pngBytes, {int feed = 3, bool cut = true}) async {
    // ... (ส่วนนี้เหมือนเดิมค่ะ)
    if (!Platform.isAndroid) { _toast(context, 'โหมดนี้รองรับ Android ก่อนนะคะ'); return; }
    final ok = await ensureConnectedOrPick(context);
    if (!mounted(context)) return;
    if (!ok) { _toast(context, 'เชื่อมต่อเครื่องพิมพ์ไม่สำเร็จ'); return; }
    try { await printPng(pngBytes, feed: feed, cut: cut); _toast(context, 'ส่งพิมพ์เรียบร้อย'); }
    catch (e, st) { if (kDebugMode) debugPrint('print error: $e\n$st'); _toast(context, 'พิมพ์ไม่สำเร็จ: $e'); }
  }

  void _toast(BuildContext context, String msg) {
    if (mounted(context)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  bool mounted(BuildContext context) {
    try {
      // ignore: unnecessary_null_comparison
      return context != null && context.findRenderObject() != null;
    } catch (e) {
      return false;
    }
  }
}
