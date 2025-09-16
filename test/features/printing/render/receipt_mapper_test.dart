import 'package:flutter_test/flutter_test.dart';
import 'package:mydent_app/features/printing/render/receipt_mapper.dart';

class _FakeCalendarResult {
  final DateTime startTime;
  final String? treatment;
  final List<dynamic>? teeth;
  final String? notes;
  _FakeCalendarResult({
    required this.startTime,
    this.treatment,
    this.teeth,
    this.notes,
  });
}

void main() {
  group('receipt_mapper', () {
    test('buildReceiptModel computes totals when not provided', () {
      final m = buildReceiptModel(
        clinicName: 'คลินิก',
        clinicAddress: 'ที่อยู่',
        clinicPhone: '0812345678',
        billNo: 'B-001',
        issuedAt: DateTime(2025, 1, 1),
        patientName: 'สมชาย',
        items: const [
          ReceiptLineInput(name: 'A', qty: 1, price: 100),
          ReceiptLineInput(name: 'B', qty: 2, price: 50),
        ],
      );
      expect(m.totals.subTotal, 200);
      expect(m.totals.discount, 0);
      expect(m.totals.vat, 0);
      expect(m.totals.grandTotal, 200);
      expect(m.lines.length, 2);
    });

    test('buildReceiptModel respects provided totals', () {
      final m = buildReceiptModel(
        clinicName: 'คลินิก',
        clinicAddress: 'ที่อยู่',
        clinicPhone: '0812345678',
        billNo: 'B-002',
        issuedAt: DateTime(2025, 1, 1),
        patientName: 'สมศรี',
        items: const [ReceiptLineInput(name: 'A', qty: 1, price: 100)],
        subTotal: 100,
        discount: 10,
        vat: 7,
        grandTotal: 97,
      );
      expect(m.totals.subTotal, 100);
      expect(m.totals.discount, 10);
      expect(m.totals.vat, 7);
      expect(m.totals.grandTotal, 97);
    });

    test('buildAppointmentSlip packs data as expected', () {
      final s = buildAppointmentSlip(
        clinicName: 'คลินิก',
        clinicAddress: 'ที่อยู่',
        clinicPhone: '0812345678',
        patientName: 'สมหมาย',
        hn: 'HN123',
        startAt: DateTime(2025, 5, 10, 10, 30),
        note: 'ถอนฟัน',
      );
      expect(s.patient.name, 'สมหมาย');
      expect(s.patient.hn, 'HN123');
      expect(s.appointment.note, 'ถอนฟัน');
    });

    test('mapCalendarResultToApptInfo composes note from treatment + teeth + notes', () {
      final fake = _FakeCalendarResult(
        startTime: DateTime(2025, 6, 1, 9, 0),
        treatment: 'ถอน',
        teeth: [11, 12],
        notes: 'ลึกมาก',
      );
      final info = mapCalendarResultToApptInfo(fake);
      expect(info.startAt, fake.startTime);
      expect(info.note, 'ถอน (#11, 12)\nลึกมาก');
    });

    test('mapCalendarResultToApptInfo handles missing teeth and notes', () {
      final fake = _FakeCalendarResult(
        startTime: DateTime(2025, 6, 1, 9, 0),
        treatment: 'ขูดหินปูน',
        teeth: const [],
        notes: null,
      );
      final info = mapCalendarResultToApptInfo(fake);
      expect(info.note, 'ขูดหินปูน');
    });
  });
}

