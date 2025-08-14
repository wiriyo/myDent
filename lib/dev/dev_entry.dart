// lib/dev/dev_entry.dart
// v2 — แก้ error ใน DEV menu: buildReceiptModel ไม่มีพารามิเตอร์ paid/change
//      ตัดออก และคง grandTotal/subTotal/discount/vat ไว้ตามสัญญาใน receipt_mapper.dart
//      แสดงเฉพาะตอน DEBUG (kDebugMode) เท่านั้น

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

// Printing Preview pages
import '../features/printing/render/preview_pages.dart' as pv;

// Mapper สร้างโมเดลทดสอบสำหรับใบเสร็จ/ใบนัด
import '../features/printing/render/receipt_mapper.dart';

class DevEntry extends StatelessWidget {
  const DevEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('DEV menu is available only in Debug builds.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Preview')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -------- พรีวิวใบเสร็จ --------
            FilledButton(
              onPressed: () {
                final receipt = buildReceiptModel(
                  clinicName: 'MyDent คลินิก',
                  clinicAddress: '123 ถนนสุขใจ เขตบางกะปิ กทม.',
                  clinicPhone: '02-123-4567',
                  billNo: '68-001',
                  issuedAt: DateTime.now(),
                  patientName: 'คุณสมชาย ใจดี',
                  items: const [
                    ReceiptLineInput(name: 'ขูดหินปูน', qty: 1, price: 800),
                    ReceiptLineInput(name: 'ยาสีฟัน', qty: 1, price: 120),
                  ],
                  subTotal: 920,
                  discount: 0,
                  vat: 0,
                  grandTotal: 920,
                  // ❌ ไม่มี paid/change ในสัญญาของ buildReceiptModel — ไม่ต้องส่ง
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => pv.ReceiptPreviewPage(receipt: receipt),
                  ),
                );
              },
              child: const Text('พรีวิวใบเสร็จ'),
            ),
            const SizedBox(height: 12),

            // -------- พรีวิวใบนัด --------
            FilledButton.tonal(
              onPressed: () {
                final slip = buildAppointmentSlip(
                  clinicName: 'MyDent คลินิก',
                  clinicAddress: '123 ถนนสุขใจ เขตบางกะปิ กทม.',
                  clinicPhone: '02-123-4567',
                  patientName: 'คุณสมหญิง ยิ้มแย้ม',
                  hn: 'HN889900',
                  startAt: DateTime.now().add(const Duration(days: 7)),
                  note: 'มาก่อน 10 นาที',
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => pv.AppointmentSlipPreviewPage(slip: slip),
                  ),
                );
              },
              child: const Text('พรีวิวใบนัด'),
            ),
          ],
        ),
      ),
    );
  }
}
