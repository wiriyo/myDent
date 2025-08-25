// ----------------------------------------------------------------
// 📁 lib/services/appointment_flow_service.dart (v1.1 - 💖 Laila's Clear Treatment Fix!)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';

import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../screens/appointment_add.dart';
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../features/printing/domain/appointment_slip_model.dart';
import '../features/printing/render/appointment_slip_preview_page.dart';
import '../features/printing/render/combined_slip_preview_page.dart';
import '../features/printing/render/receipt_mapper.dart';

/// 💖 ผู้ช่วยคนใหม่ของไลลาเองค่ะ! 💖
/// คนนี้เป็นศูนย์กลางเวทมนตร์สำหรับจัดการ Flow การสร้างนัดหมายทั้งหมดเลย
/// ไม่ว่าจะเป็นการสร้างนัดจากหน้าไหน หรือมีข้อมูลอะไรติดมาด้วย
/// ผู้ช่วยคนนี้จะจัดการให้เราเองทั้งหมดเลยค่ะ!
class AppointmentFlowService {
  final BuildContext context;
  final Function onFlowComplete;

  AppointmentFlowService({
    required this.context,
    required this.onFlowComplete,
  });

  /// คาถาบทหลักสำหรับเริ่ม Flow การสร้างนัดหมาย
  Future<void> startAddAppointmentFlow({
    required DateTime day,
    DateTime? initialStartTime,
    Patient? chainedPatient,
    receipt.ReceiptModel? receiptDraft,
  }) async {
    // 💖✨ START: CLEAR TREATMENT FIX v1.1 ✨💖
    // เราจะปล่อยให้ initialTreatment เป็นค่าว่าง (null)
    // เพื่อให้ช่องหัตถการในหน้านัดหมายใหม่เริ่มต้นเป็นค่าว่างเสมอค่ะ
    String? initialTreatment;
    String? initialTeeth;

    // เขียน "โพย" ถ้ามีใบเสร็จติดมาด้วย (แต่จะเอามาแค่ซี่ฟันค่ะ)
    if (receiptDraft != null && receiptDraft.lines.isNotEmpty) {
      final firstItem = receiptDraft.lines.first;
      final itemName = firstItem.name;
      
      final toothRegex = RegExp(r'\s\(#(.+)\)$');
      final match = toothRegex.firstMatch(itemName);

      if (match != null) {
        // initialTreatment = itemName.substring(0, match.start).trim(); // ไม่เอาชื่อหัตถการเดิมมาแล้วค่ะ
        initialTeeth = match.group(1)?.trim();
      } else {
        // initialTreatment = itemName.trim(); // ไม่เอาชื่อหัตถการเดิมมาแล้วค่ะ
        initialTeeth = '';
      }
    }
    // 💖✨ END: CLEAR TREATMENT FIX v1.1 ✨💖

    // เปิดหน้าต่างเพิ่มนัดหมาย
    final result = await showDialog(
      context: context,
      builder: (_) => AppointmentAddDialog(
        initialDate: day,
        initialPatient: chainedPatient,
        initialStartTime: initialStartTime,
        initialTreatment: initialTreatment, // จะเป็นค่า null เสมอ
        initialTeeth: initialTeeth,
      ),
    );

    // หลังจากปิดหน้าต่างแล้ว...
    if (result is Map<String, dynamic>) {
      final newAppointment = result['appointment'] as AppointmentModel;
      final newPatient = result['patient'] as Patient;

      // บอกให้หน้าจอหลักรีเฟรชตัวเองก่อนเสมอ
      onFlowComplete(); 
      
      // รอแป๊บนึงให้หน้าจอรีเฟรชเสร็จก่อนนะคะ
      await Future.delayed(const Duration(milliseconds: 100));

      if (!context.mounted) return;

      // ตรวจสอบว่าต้องไปหน้าไหนต่อ
      if (receiptDraft != null) {
        // --- Flow การรักษา (ไปหน้า Combined Slip) ---
        final apptInfo = mapCalendarResultToApptInfo(newAppointment);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CombinedSlipPreviewPage(
              receipt: receiptDraft,
              nextAppointment: apptInfo,
            ),
          ),
        );
      } else {
        // --- Flow ปกติ (สร้างนัดจากหน้าปฏิทิน) ---
        final slip = AppointmentSlipModel(
          clinic: const receipt.ClinicInfo(
            name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
            address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
            phone: '094-5639334',
          ),
          patient: receipt.PatientInfo(
            name: newPatient.name,
            hn: newPatient.hnNumber ?? '',
          ),
          appointment: AppointmentInfo(
            startAt: newAppointment.startTime,
            note: newAppointment.notes?.trim().isEmpty ?? true
                ? newAppointment.treatment
                : newAppointment.notes,
          ),
        );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentSlipPreviewPage(slip: slip, useSampleData: false),
          ),
        );
      }
      
      // เมื่อทุกอย่างเสร็จสิ้นสมบูรณ์ เราจะเรียก onFlowComplete อีกครั้ง
      // เพื่อให้หน้าจอหลักสามารถเคลียร์ข้อมูลคนไข้ที่ค้างอยู่ได้ค่ะ
      onFlowComplete(clearPatient: true);
    }
  }
}
