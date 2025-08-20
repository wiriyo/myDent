// ----------------------------------------------------------------
// 📁 lib/features/printing/render/receipt_mapper.dart (UPGRADED)
// v1.1.0 - 🚀 อัปเกรด mapCalendarResultToApptInfo ให้แสดงข้อมูลครบถ้วน
// ----------------------------------------------------------------

import '../domain/receipt_model.dart';
import '../domain/appointment_slip_model.dart';

/// อินพุตแถวบิลแบบเรียบง่าย (ช่วยให้ map จากของเดิมได้ทันที)
class ReceiptLineInput {
  final String name;
  final int qty;
  final num price;
  const ReceiptLineInput({required this.name, required this.qty, required this.price});
}

/// สร้าง ReceiptModel จากพารามิเตอร์ดิบ (ยังไม่ผูกกับคลาสใน MyDent)
ReceiptModel buildReceiptModel({
  // Clinic
  required String clinicName,
  required String clinicAddress,
  required String clinicPhone,
  // Bill
  required String billNo,
  required DateTime issuedAt,
  // Patient
  required String patientName,
  String hn = '',
  // Items
  required List<ReceiptLineInput> items,
  // Summary (ถ้ามีส่วนลด/VATคำนวณแล้วใส่เข้ามา, ไม่งั้นจะคำนวณง่าย ๆ ให้)
  num? subTotal,
  num discount = 0,
  num vat = 0,
  num? grandTotal,
}) {
  final lines = items
      .map((e) => ReceiptLine(name: e.name, qty: e.qty, price: e.price))
      .toList();
  final sub = subTotal ?? lines.fold<num>(0, (p, e) => p + e.qty * e.price);
  final grand = grandTotal ?? sub - discount + vat;

  return ReceiptModel(
    clinic: ClinicInfo(name: clinicName, address: clinicAddress, phone: clinicPhone),
    bill: BillInfo(billNo: billNo, issuedAt: issuedAt),
    patient: PatientInfo(name: patientName, hn: hn),
    lines: lines,
    totals: TotalSummary(subTotal: sub, discount: discount, vat: vat, grandTotal: grand),
  );
}

/// ใบนัด (appointment slip) — รับค่าที่จำเป็นจาก MyDent แล้วแปลงเป็นโมเดลสลิป
AppointmentSlipModel buildAppointmentSlip({
  required String clinicName,
  required String clinicAddress,
  required String clinicPhone,
  required String patientName,
  String hn = '',
  required DateTime startAt,
  String? note,
}) {
  return AppointmentSlipModel(
    clinic: ClinicInfo(name: clinicName, address: clinicAddress, phone: clinicPhone),
    patient: PatientInfo(name: patientName, hn: hn),
    appointment: AppointmentInfo(startAt: startAt, note: note),
  );
}

/// ✨ [UPGRADED v1.1.0] แปลงผลลัพธ์จากหน้าปฏิทิน (AppointmentModel) ให้เป็น AppointmentInfo
/// ตอนนี้จะรวมข้อมูล หัตถการ + ซี่ฟัน + หมายเหตุ เข้าด้วยกันเพื่อการแสดงผลที่สมบูรณ์
AppointmentInfo mapCalendarResultToApptInfo(dynamic result) {
  if (result == null) {
    throw ArgumentError('calendarResult is null');
  }

  DateTime startAt;
  String treatment;
  List<String> teeth;
  String? notes;

  // ใช้ dynamic เพื่อเลี่ยงการ import AppointmentModel โดยตรง
  // ทำให้ mapper นี้ยืดหยุ่นและไม่ผูกติดกับ model layer โดยตรง
  final r = result as dynamic;
  startAt = r.startTime as DateTime;
  treatment = r.treatment as String? ?? '';
  // แปลง List<dynamic> ให้เป็น List<String> อย่างปลอดภัย
  teeth = (r.teeth as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  notes = r.notes as String?;
  
  // สร้างข้อความสำหรับแสดงผลในใบนัด
  final teethString = teeth.isNotEmpty ? ' (#${teeth.join(', ')})' : '';
  String fullNote = '$treatment$teethString';

  // ถ้ามีหมายเหตุเพิ่มเติม ก็ให้ขึ้นบรรทัดใหม่
  if (notes != null && notes.trim().isNotEmpty) {
    fullNote += '\n${notes.trim()}';
  }

  return AppointmentInfo(startAt: startAt, note: fullNote.trim());
}
