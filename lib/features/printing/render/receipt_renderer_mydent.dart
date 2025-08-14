import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renderer for MyDent receipts.
///
/// This class demonstrates usage of `PlatformDispatcher`, `Colors`, and
/// `pw.Divider` with proper imports to avoid undefined identifier errors.
class ReceiptRendererMyDent {
  ReceiptRendererMyDent();

  /// Example method that builds a simple PDF page.
  pw.Document buildDocument() {
    final doc = pw.Document();

    // Access `PlatformDispatcher` for demonstration purposes.
    final brightness = PlatformDispatcher.instance.platformBrightness;
    debugPrint('Current platform brightness: ' + brightness.toString());

    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text(
                'Receipt',
                style: pw.TextStyle(
                  // Use Flutter's [Colors] constant.
                  color: PdfColor.fromInt(Colors.black.value),
                ),
              ),
              // Use the PDF package's divider widget.
              pw.Divider(),
            ],
          );
        },
      ),
    );

    return doc;
  }
}
