// lib/features/printing/widgets/print_button.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../features/printing/services/thermal_printer_service.dart';

class PrintButton extends StatelessWidget {
  final Uint8List pngBytes;
  final String label;
  final int feed;
  final bool cut;
  const PrintButton({super.key, required this.pngBytes, this.label = 'พิมพ์', this.feed = 3, this.cut = true});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const Icon(Icons.print),
      label: Text(label),
      onPressed: () => ThermalPrinterService.instance
          .ensureConnectAndPrintPng(context, pngBytes, feed: feed, cut: cut),
    );
  }
}