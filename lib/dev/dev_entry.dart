import 'package:flutter/material.dart';
import '../features/printing/render/receipt_mapper.dart';
import '../features/printing/render/preview_pages.dart';

class DevEntry extends StatelessWidget {
  const DevEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Preview')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(
            onPressed: () {
              final receipt = buildReceiptModel(
                clinicName: 'MyDent คลินิก',
                clinicAddress: '123 ถนนสุขใจ เขตบางกะปิ กทม.',
                clinicPhone: '02-123-4567',
                billNo: 'INV-2508-001',
                issuedAt: DateTime.now(),
                patientName: 'คุณสมชาย ใจดี',
                hn: 'HN001122',
                items: const [
                  ReceiptLineInput(name: 'ขูดหินปูน', qty: 1, price: 800),
                  ReceiptLineInput(name: 'ยาสีฟัน', qty: 1, price: 120),
                ],
                discount: 0,
                vat: 64.40,
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReceiptPreviewPage(receipt: receipt)),
              );
            },
            child: const Text('พรีวิวใบเสร็จ'),
          ),
          const SizedBox(height: 12),
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
                MaterialPageRoute(builder: (_) => AppointmentSlipPreviewPage(slip: slip)),
              );
            },
            child: const Text('พรีวิวใบนัด'),
          ),
        ]),
      ),
    );
  }
}