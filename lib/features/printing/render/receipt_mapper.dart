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
  final _sub = subTotal ?? lines.fold<num>(0, (p, e) => p + e.qty * e.price);
  final _grand = grandTotal ?? _sub - discount + vat;

  return ReceiptModel(
    clinic: ClinicInfo(name: clinicName, address: clinicAddress, phone: clinicPhone),
    bill: BillInfo(billNo: billNo, issuedAt: issuedAt),
    patient: PatientInfo(name: patientName, hn: hn),
    lines: lines,
    totals: TotalSummary(subTotal: _sub, discount: discount, vat: vat, grandTotal: _grand),
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

/*
// เวอร์ชันต่อยอดภายหลัง: mapper ผูกกับชนิดจริงของ MyDent
ReceiptModel mapFromMyDent({
  required MdClinic clinic,
  required MdInvoice invoice,
  required MdPatient patient,
}) {
  // TODO: แปลงฟิลด์จริงของ MyDent → ReceiptModel
}
*/