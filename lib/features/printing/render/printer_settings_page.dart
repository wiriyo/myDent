// lib/features/printing/render/printer_settings_page.dart
// v1.0.4 - อัปเกรดปุ่มพิมพ์ทดสอบให้ใช้งานได้จริง!
// เพิ่มฟังก์ชัน 'บันทึกเป็นภาพ' และ 'พิมพ์' เหมือนหน้าพรีวิว

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/th_format.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
// 💖 NEW: import service ที่จำเป็นสำหรับการทำงานของปุ่มใหม่ค่ะ
import '../services/image_saver_service.dart';
import '../services/thermal_printer_service.dart';


class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  // 💖 NEW: กุญแจสำหรับใช้ชี้ตำแหน่ง Widget ที่เราจะแคปภาพค่ะ
  final _boundaryKey = GlobalKey();
  ByteData? _logo;
  bool _isLoading = true;
  // 💖 NEW: ตัวแปรสำหรับเก็บภาพที่แคปไว้ และสถานะการทำงานค่ะ
  Uint8List? _lastPng;
  bool _busyCapture = false;

  // --- Printing Settings ---
  double _printingScale = 1.0;
  int _printingPostFeed = 3;
  int _printingHeaderSpace = 0;
  static const String _scaleKey = 'mydent.printing.scale';
  static const String _postFeedKey = 'mydent.printing.postfeed';
  static const String _headerSpaceKey = 'mydent.printing.headerspace';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final prefs = await SharedPreferences.getInstance();
    final savedScale = prefs.getDouble(_scaleKey) ?? 1.0;
    final savedPostFeed = prefs.getInt(_postFeedKey) ?? 3;
    final savedHeaderSpace = prefs.getInt(_headerSpaceKey) ?? 0;

    try {
      final logo = await rootBundle.load('assets/images/logo_clinic.png');
      if (mounted) {
        setState(() {
          _printingScale = savedScale;
          _printingPostFeed = savedPostFeed;
          _printingHeaderSpace = savedHeaderSpace;
          _logo = logo;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logo = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateScale(double newScale) async {
    final prefs = await SharedPreferences.getInstance();
    final clampedScale = newScale.clamp(0.5, 2.0);
    await prefs.setDouble(_scaleKey, clampedScale);
    setState(() {
      _printingScale = clampedScale;
      _lastPng = null; // 💖 NEW: ถ้าปรับค่า ต้องแคปภาพใหม่นะคะ
    });
  }

  Future<void> _updatePostFeed(int newFeed) async {
    final prefs = await SharedPreferences.getInstance();
    final clampedFeed = newFeed.clamp(0, 10);
    await prefs.setInt(_postFeedKey, clampedFeed);
    setState(() {
      _printingPostFeed = clampedFeed;
    });
  }

  Future<void> _updateHeaderSpace(int newSpace) async {
    final prefs = await SharedPreferences.getInstance();
    final clampedSpace = newSpace.clamp(0, 50);
    await prefs.setInt(_headerSpaceKey, clampedSpace);
    setState(() {
      _printingHeaderSpace = clampedSpace;
       _lastPng = null; // 💖 NEW: ถ้าปรับค่า ต้องแคปภาพใหม่นะคะ
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ตั้งค่าการพิมพ์')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าการพิมพ์'),
        // 💖 FIX v1.0.4: ลบปุ่มทดสอบเก่าออกจาก AppBar ค่ะ
      ),
      body: Builder(
        builder: (bodyContext) {
          return MediaQuery(
            data: MediaQuery.of(bodyContext).copyWith(textScaleFactor: _printingScale),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                // 💖 NEW: ห่อสลิปด้วย RepaintBoundary เพื่อให้เราแคปภาพได้ค่ะ
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _CombinedSlipWidget(
                    width: 576,
                    receipt: _sampleReceiptData(),
                    nextAppointment: _sampleAppointmentData(),
                    logoBytes: _logo,
                    headerSpace: _printingHeaderSpace.toDouble(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      // 💖 FIX v1.0.4: เปลี่ยนแถบด้านล่างเป็นปุ่มใหม่ทั้งหมดเลยค่ะ
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSettingControl('ขนาด', _printingScale.toStringAsFixed(1), () => _updateScale(_printingScale - 0.1), () => _updateScale(_printingScale + 0.1))),
                  Expanded(child: _buildSettingControl('ท้ายกระดาษ', '$_printingPostFeed', () => _updatePostFeed(_printingPostFeed - 1), () => _updatePostFeed(_printingPostFeed + 1))),
                  Expanded(child: _buildSettingControl('หัวกระดาษ', '$_printingHeaderSpace', () => _updateHeaderSpace(_printingHeaderSpace - 5), () => _updateHeaderSpace(_printingHeaderSpace + 5))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconButton(
                    onPressed: _busyCapture ? null : _captureAndSavePng,
                    bgColor: const Color(0xFFE8F5E9), // สีเขียวมิ้นต์
                    iconAsset: 'assets/icons/picture.png',
                  ),
                  const SizedBox(width: 24),
                  _buildIconButton(
                    onPressed: _busyCapture ? null : _print,
                    bgColor: const Color(0xFFFFF3E0), // สีชมพูอ่อน
                    iconAsset: 'assets/icons/printer.png',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 💖 NEW: ฟังก์ชันสร้างปุ่มสวยๆ เหมือนหน้าพรีวิวค่ะ
  Widget _buildIconButton({required VoidCallback? onPressed, required Color bgColor, required String iconAsset}) {
    return SizedBox(
      width: 110,
      height: 72,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Image.asset(iconAsset, width: 36, height: 36),
      ),
    );
  }
  
  Widget _buildSettingControl(String label, String value, VoidCallback onDecrement, VoidCallback onIncrement) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallScaleButton(Icons.remove, onDecrement),
            Flexible(
              child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
            _buildSmallScaleButton(Icons.add, onIncrement),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallScaleButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
      ),
    );
  }

  // 💖 NEW: ฟังก์ชันสำหรับแคปภาพและบันทึกลงแกลเลอรีค่ะ
  Future<void> _captureAndSavePng() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);
    try {
      final obj = _boundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) throw Exception('ไม่พบ RepaintBoundary');
      
      final ui.Image image = await obj.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('ไม่สามารถแปลงภาพเป็นข้อมูลได้');
      
      final pngBytes = byteData.buffer.asUint8List();
      setState(() => _lastPng = pngBytes);

      final fileName = 'MyDent-TestPrint-${DateTime.now().millisecondsSinceEpoch}.png';
      final bool success = await ImageSaverService.saveImage(pngBytes, fileName);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพตัวอย่างลงในแกลเลอรีเรียบร้อย')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกภาพไม่สำเร็จ! โปรดตรวจสอบการอนุญาต')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  // 💖 NEW: ฟังก์ชันสำหรับสั่งพิมพ์ภาพที่แคปไว้ค่ะ
  Future<void> _print() async {
    if (_busyCapture) return;
    setState(() => _busyCapture = true);

    try {
      // ถ้ายังไม่เคยแคปภาพ ให้แคปก่อน
      if (_lastPng == null) {
        final obj = _boundaryKey.currentContext?.findRenderObject();
        if (obj is! RenderRepaintBoundary) return;
        final ui.Image image = await obj.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        _lastPng = byteData.buffer.asUint8List();
      }
      
      if (_lastPng != null) {
        await ThermalPrinterService.instance.ensureConnectAndPrintPng(context, _lastPng!, feed: _printingPostFeed, cut: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำสั่งพิมพ์ตัวอย่างแล้ว')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่มีภาพสำหรับพิมพ์')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดขณะพิมพ์: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyCapture = false);
    }
  }

  ReceiptModel _sampleReceiptData() {
    return ReceiptModel(
      clinic: const ClinicInfo(
        name: 'คลินิกทันตกรรม',
        address: 'หมอกุสุมาภรณ์',
        phone: '094-5639334',
      ),
      bill: BillInfo(
        billNo: 'XX-XXXX',
        issuedAt: DateTime.now(),
      ),
      patient: const PatientInfo(
        name: 'คุณ ตัวอย่าง การพิมพ์',
        hn: 'HNXXXXX',
      ),
      lines: const [
        ReceiptLine(name: 'รายการทดสอบ 1', qty: 1, price: 500),
        ReceiptLine(name: 'รายการทดสอบ 2', qty: 1, price: 500),
      ],
      totals: const TotalSummary(
        subTotal: 1000,
        discount: 0,
        vat: 0,
        grandTotal: 1000,
      ),
    );
  }

  AppointmentInfo _sampleAppointmentData() {
    return AppointmentInfo(
      startAt: DateTime.now().add(const Duration(days: 7)),
      note: 'นัดตรวจครั้งต่อไป',
    );
  }
}

class _CombinedSlipWidget extends StatelessWidget {
  final double width;
  final ReceiptModel receipt;
  final AppointmentInfo nextAppointment;
  final ByteData? logoBytes;
  final double headerSpace;

  const _CombinedSlipWidget({
    required this.width,
    required this.receipt,
    required this.nextAppointment,
    this.logoBytes,
    this.headerSpace = 0.0,
  });

  static const double _labelWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 22, color: Colors.black, height: 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: headerSpace),
            if (logoBytes != null) ...[
              Image.memory(logoBytes!.buffer.asUint8List(), width: 180, filterQuality: FilterQuality.medium),
              const SizedBox(height: 6),
            ],
            const Text('คลินิกทันตกรรม', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const Text('หมอกุสุมาภรณ์', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('304 ม.1 ต.หนองพอก', textAlign: TextAlign.center),
            const Text('อ.หนองพอก จ.ร้อยเอ็ด', textAlign: TextAlign.center),
            const Text('094-5639334', textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('*********************'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('เลขที่', receipt.bill.billNo),
                _kv('วันที่', ThFormat.dateThai(receipt.bill.issuedAt, shortYear: false)),
                _kv('เวลา', ThFormat.timeThai(receipt.bill.issuedAt)),
                _kv('ชื่อ', ''),
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Align(alignment: Alignment.centerRight, child: Text(receipt.patient.name, textAlign: TextAlign.right))),
                _kv('หัตถการ:', receipt.lines.isNotEmpty ? receipt.lines.first.name : '-'),
                _kv('ค่าบริการ', ThFormat.baht(receipt.totals.grandTotal)),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 20, thickness: 1, color: Colors.black),
            const SizedBox(height: 10),
            const Text('นัดครั้งต่อไป', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('วันที่นัด', ThFormat.dateThai(nextAppointment.startAt, shortYear: false)),
                _kv('เวลานัด', ThFormat.timeThai(nextAppointment.startAt)),
                if ((nextAppointment.note ?? '').trim().isNotEmpty)
                  _kv('หัตถการ', nextAppointment.note!.trim()),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              children: const [
                Text('กรุณามาก่อนเวลานัด 10-15 นาที', style: TextStyle(fontSize: 16)),
                Text('หากไม่สะดวกในวัน/เวลาดังกล่าว', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                Text('กรุณาติดต่อขอรับคิวใหม่', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _labelWidth, child: Text(k)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
