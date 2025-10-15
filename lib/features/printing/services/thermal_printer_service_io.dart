// lib/features/printing/services/thermal_printer_service.dart
// v1.1.0 - ปรับปรุงการเว้นบรรทัดท้ายกระดาษ (Post-Print Feed)

import 'dart:io' show Platform;
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

abstract class PrinterClient {
  Future<void> ensureConnectAndPrintPng(BuildContext context, Uint8List pngBytes, {int feed = 3, bool cut = true});
}

class ThermalPrinterService implements PrinterClient {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();
  // Test hook: allow overriding implementation during widget tests
  static PrinterClient? debugOverride;
  static PrinterClient get I => debugOverride ?? instance;

  static const _keyMac = 'mydent.printer.mac';
  static const _keyName = 'mydent.printer.name';

  CapabilityProfile? _profile;
  Future<CapabilityProfile> _loadProfile() async => _profile ??= await CapabilityProfile.load();

  static int? _cachedAndroidSdk;
  int get _androidSdkInt {
    if (!Platform.isAndroid) return 0;
    final cached = _cachedAndroidSdk;
    if (cached != null) return cached;
    final version = Platform.version;
    final match = RegExp(r'(SDK|API)\s*(\d+)').firstMatch(version);
    final parsed = match != null ? int.tryParse(match.group(2)!) : null;
    final value = parsed ?? 0;
    _cachedAndroidSdk = value;
    return value;
  }

  bool get _useModernBluetoothPermissions {
    if (!Platform.isAndroid) return false;
    final sdk = _androidSdkInt;
    return sdk == 0 || sdk >= 31;
  }

  List<Permission> _permissionsToRequest() {
    if (!Platform.isAndroid) return const <Permission>[];
    final perms = <Permission>{Permission.bluetoothConnect};
    if (_useModernBluetoothPermissions) {
      perms.add(Permission.bluetoothScan);
    } else {
      perms.add(Permission.bluetooth);
      perms.add(Permission.location);
    }
    return perms.toList();
  }

  bool _statusGranted(PermissionStatus status) {
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  Future<Map<Permission, PermissionStatus>> _currentPermissionStatuses() async {
    final req = _permissionsToRequest();
    if (req.isEmpty) return <Permission, PermissionStatus>{};
    final map = <Permission, PermissionStatus>{};
    for (final p in req) {
      map[p] = await p.status;
    }
    return map;
  }

  Future<bool> _requestAll() async {
    final req = _permissionsToRequest();
    if (req.isEmpty) return true;
    final res = await req.request();
    return res.values.every(_statusGranted);
  }

  Future<bool> hasPrintingPermissions() async {
    final current = await _currentPermissionStatuses();
    if (current.isEmpty) return true;
    return current.values.every(_statusGranted);
  }

  Future<bool> ensurePrintingPermissions(BuildContext context) async {
    // เช็คสถานะปัจจุบันก่อน
    final current = await _currentPermissionStatuses();
    if (current.isEmpty || current.values.every(_statusGranted)) {
      // (iOS หรือแพลตฟอร์มอื่น ๆ ที่ไม่ต้องใช้สิทธิ์พิเศษ)
      return true;
    }

    // แสดงคำอธิบายก่อนเพื่อให้ผู้ใช้เตรียมพร้อม แล้วค่อยยิง system prompt
    if (!context.mounted) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('อนุญาตการใช้งาน Bluetooth'),
        content: const Text('การพิมพ์ต้องการสิทธิ์ Bluetooth (สแกน/เชื่อมต่อ) และอาจต้องการ Location บนอุปกรณ์บางรุ่น\n\nกด "อนุญาต" เพื่อดำเนินการต่อ'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('อนุญาต')),
        ],
      ),
    );
    if (confirm != true) return false;

    final ok = await _requestAll();
    if (ok) return true;

    // ถ้ายังไม่ได้สิทธิ์ แนะนำให้เปิดหน้า Settings ของแอป
    if (!context.mounted) return false;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ต้องอนุญาตผ่านการตั้งค่า'),
        content: const Text('ดูเหมือนสิทธิ์ถูกปฏิเสธแบบไม่สอบถามอีก (Don\'t ask again)\nโปรดเปิดการอนุญาตในหน้า Settings ของแอป จากนั้นกลับมาลองอีกครั้ง'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ปิด')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('เปิดหน้าการตั้งค่าแอป')),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
      // กลับมาแล้วเช็คอีกครั้ง
      return await _requestAll();
    }
    return false;
  }

  Future<List<PrinterDevice>> discoverPaired() async {
    if (!Platform.isAndroid) return const <PrinterDevice>[];
    
    final permissionsOk = await _requestAll();
    if (!permissionsOk) return const <PrinterDevice>[];

    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => PrinterDevice(name: d.name, mac: d.macAdress)).toList(growable: false);
  }

  Future<bool> isConnected() async {
    try { return await PrintBluetoothThermal.connectionStatus; } catch (_) { return false; }
  }

  Future<bool> connectByMac(String mac, {int maxRetries = 2, Duration retryDelay = const Duration(milliseconds: 600)}) async {
    final trimmedMac = mac.trim();
    if (trimmedMac.isEmpty) return false;

    final permissionsOk = await _requestAll();
    if (!permissionsOk) return false;

    // Always start from a clean state; some printers refuse a new socket while the
    // previous channel is still marked as connected on Android.
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        await PrintBluetoothThermal.disconnect;
      }
    } catch (_) {}

    bool connected = false;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(retryDelay);
      }

      try {
        connected = await PrintBluetoothThermal.connect(macPrinterAddress: trimmedMac);
      } catch (e, st) {
        if (kDebugMode) debugPrint('ThermalPrinterService.connectByMac failure (attempt ${attempt + 1}): $e\n$st');
        connected = false;
      }

      if (connected) {
        return true;
      }

      // Ensure the underlying plugin socket is torn down before retrying.
      try { await PrintBluetoothThermal.disconnect; } catch (_) {}
    }
    return false;
  }

  Future<void> disconnect() async { try { await PrintBluetoothThermal.disconnect; } catch (_) {} }

  Future<bool> connectWithPicker(BuildContext context, {bool rememberSelection = true}) async {
    if (!Platform.isAndroid) { _toast(context, 'โหมดนี้รองรับ Android ก่อนนะคะ'); return false; }

    if (!context.mounted) return false;
    final permissionsOk = await ensurePrintingPermissions(context);
    if (!context.mounted) return false;
    if (!permissionsOk) {
      if (!context.mounted) return false;
      _toast(context, 'ต้องอนุญาตสิทธิ์การใช้งานก่อนเชื่อมต่อ');
      return false;
    }

    if (!context.mounted) return false;
    final picked = await _showPickerDialog(context);
    if (!context.mounted) return false;
    if (picked == null) return false;

    final ok = await connectByMac(picked.mac);
    if (ok && rememberSelection) await saveDefault(picked);

    if (!context.mounted) return ok;
    _toast(context, ok ? 'เชื่อมต่อเครื่องพิมพ์เรียบร้อย' : 'เชื่อมต่อเครื่องพิมพ์ไม่สำเร็จ');
    return ok;
  }

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

    if (!context.mounted) return false;
    final permissionsOk = await ensurePrintingPermissions(context);
    if (!context.mounted) return false;
    if (!permissionsOk) {
      if (!context.mounted) return false;
      _toast(context, 'ต้องอนุญาตสิทธิ์การใช้งานก่อนพิมพ์');
      return false;
    }
    
    final saved = await loadDefault();
    if (!context.mounted) return false;
    if (saved != null && await connectByMac(saved.mac)) return true;
    
    if (!context.mounted) return false;
    final picked = await _showPickerDialog(context);
    if (!context.mounted) return false;
    if (picked == null) return false;
    
    final ok = await connectByMac(picked.mac);
    if (ok) await saveDefault(picked);
    return ok;
  }

  Future<PrinterDevice?> _showPickerDialog(BuildContext context) async {
    final devices = await discoverPaired();
    if (!context.mounted) return null;

    if (devices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('ไม่พบอุปกรณ์ที่จับคู่ไว้'),
          content: const Text('โปรดเปิด Bluetooth และจับคู่เครื่องพิมพ์ในหน้า Settings ก่อน จากนั้นกลับมาลองอีกครั้ง'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('ปิด')),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try { await openAppSettings(); } catch (_) {}
              },
              child: const Text('เปิดหน้าการตั้งค่าแอป'),
            ),
          ],
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
    final profile = await _loadProfile();
    final gen = Generator(PaperSize.mm80, profile);

    img.Image? src = img.decodePng(pngBytes);
    if (src == null) throw Exception('ไม่สามารถอ่าน PNG');
    if (src.width != 576) src = img.copyResize(src, width: 576);

    final bytes = <int>[];
    bytes.addAll(gen.imageRaster(src, align: align, highDensityHorizontal: true, highDensityVertical: true));
    
    // 💖 FIX v1.1.0: ทำให้ feed เป็นตัวควบคุมระยะห่างท้ายกระดาษทั้งหมด
    if (feed > 0) bytes.addAll(gen.feed(feed));
    if (cut) { 
      bytes.addAll(gen.cut(mode: PosCutMode.full)); 
      // เอา feed(2) ที่เคย hardcode ไว้ออก เพื่อให้ตั้งค่าจากข้างนอกได้ 100%
    }

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  @override
  Future<void> ensureConnectAndPrintPng(BuildContext context, Uint8List pngBytes, {int feed = 3, bool cut = true}) async {
    if (!Platform.isAndroid) { _toast(context, 'โหมดนี้รองรับ Android ก่อนนะคะ'); return; }
    final ok = await ensureConnectedOrPick(context);
    if (!context.mounted) return;
    if (!ok) { _toast(context, 'เชื่อมต่อเครื่องพิมพ์ไม่สำเร็จ'); return; }
    try {
      await printPng(pngBytes, feed: feed, cut: cut);
      if (!context.mounted) return;
      _toast(context, 'ส่งพิมพ์เรียบร้อย');
    } catch (e, st) {
      if (kDebugMode) debugPrint('print error: $e\n$st');
      if (!context.mounted) return;
      _toast(context, 'พิมพ์ไม่สำเร็จ: $e');
    }
  }

  void _toast(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

