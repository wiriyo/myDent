import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';
import 'receipt_renderer.dart';
import 'appointment_slip_renderer.dart';

class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({super.key, required this.receipt});
  final ReceiptModel receipt;

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  ui.Image? _image;
  Uint8List? _png;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() => _busy = true);
    final renderer = ReceiptRenderer();
    final img = await renderer.render(widget.receipt);
    final png = await renderer.toPngBytes(img);
    setState(() {
      _image = img;
      _png = png;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบเสร็จ (80mm)')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _png == null
                    ? const Text('ไม่พบภาพ')
                    : Image.memory(_png!, gaplessPlayback: true),
              ),
            ),
    );
  }
}

class AppointmentSlipPreviewPage extends StatefulWidget {
  const AppointmentSlipPreviewPage({super.key, required this.slip});
  final AppointmentSlipModel slip;

  @override
  State<AppointmentSlipPreviewPage> createState() => _AppointmentSlipPreviewPageState();
}

class _AppointmentSlipPreviewPageState extends State<AppointmentSlipPreviewPage> {
  Uint8List? _png;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() => _busy = true);
    final renderer = AppointmentSlipRenderer();
    final img = await renderer.render(widget.slip);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    setState(() {
      _png = byteData!.buffer.asUint8List();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พรีวิวใบนัด')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _png == null
                    ? const Text('ไม่พบภาพ')
                    : Image.memory(_png!, gaplessPlayback: true),
              ),
            ),
    );
  }
}