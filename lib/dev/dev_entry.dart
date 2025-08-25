// 💖 สวัสดีค่ะพี่ทะเล! ไลลาอัปเดตไฟล์สำหรับทดสอบสลิปแบบรวมให้แล้วนะคะ 😊

// ===============================================
// lib/dev/dev_entry.dart
// ===============================================

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

// Printing Preview pages
import '../features/printing/render/preview_pages.dart' as pv;

// Domain models needed for creating sample data
import '../features/printing/domain/appointment_slip_model.dart';

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
                  clinicName: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
                  clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
                  clinicPhone: '094-5639334',
                  billNo: '68-001',
                  issuedAt: DateTime.now(),
                  patientName: 'คุณสมชาย ใจดี',
                  items: const [
                    ReceiptLineInput(name: 'ขูดหินปูน', qty: 1, price: 800),
                    ReceiptLineInput(name: 'ยาสีฟัน', qty: 1, price: 120),
                  ],
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ใช้ useSampleData: false เพื่อให้แสดงข้อมูลจริงที่ส่งไป
                    builder: (_) => pv.ReceiptPreviewPage(receipt: receipt, useSampleData: false),
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
                  clinicName: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
                  clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
                  clinicPhone: '094-5639334',
                  patientName: 'คุณสมหญิง ยิ้มแย้ม',
                  hn: 'HN889900',
                  startAt: DateTime.now().add(const Duration(days: 7)),
                  note: 'ถอน(#21)',
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ใช้ useSampleData: false เพื่อให้แสดงข้อมูลจริงที่ส่งไป
                    builder: (_) => pv.AppointmentSlipPreviewPage(slip: slip, useSampleData: false),
                  ),
                );
              },
              child: const Text('พรีวิวใบนัด'),
            ),
            const SizedBox(height: 12),

            // -------- ✨ NEW: พรีวิวสลิปรวม (ใบเสร็จ + ใบนัด) --------
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () {
                // 1. สร้างข้อมูลใบเสร็จ
                final receipt = buildReceiptModel(
                  clinicName: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
                  clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
                  clinicPhone: '094-5639334',
                  billNo: '68-002',
                  issuedAt: DateTime.now(),
                  patientName: 'คุณสมศักดิ์ แข็งแรง',
                  items: const [
                    ReceiptLineInput(name: 'อุดฟัน', qty: 1, price: 700),
                  ],
                );

                // 2. สร้างข้อมูลนัดครั้งถัดไป
                final nextAppointment = AppointmentInfo(
                  startAt: DateTime.now().add(const Duration(days: 14, hours: 2)),
                  note: 'ตรวจติดตามผลการอุดฟัน',
                );

                // 3. เปิดหน้าพรีวิวสลิปแบบรวม
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => pv.CombinedSlipPreviewPage(
                      receipt: receipt,
                      nextAppointment: nextAppointment,
                    ),
                  ),
                );
              },
              child: const Text('พรีวิวสลิปรวม (ใบเสร็จ+ใบนัด)'),
            ),
          ],
        ),
      ),
    );
  }
}