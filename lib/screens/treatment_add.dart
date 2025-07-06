// ----- ‼️ FILE: lib/screens/treatment_add.dart -----
// เวอร์ชัน 1.3: ✨ ขัดเงา!
// เปลี่ยนให้รับ Treatment model แทน Map

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/treatment_provider.dart';
import '../widgets/treatment_form.dart';
import '../models/treatment.dart'; // ✨ [CHANGED v1.3] import Treatment model

void showTreatmentDialog(
  BuildContext context, {
  required String patientId,
  // ✨ [CHANGED v1.3] เปลี่ยนจาก Map มาเป็น Treatment model
  Treatment? treatment,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return ChangeNotifierProvider(
        create: (_) => TreatmentProvider(),
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFFBEAFF),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: TreatmentForm(
              patientId: patientId,
              // ✨ [CHANGED v1.3] ส่ง object ไปทั้งก้อนเลย!
              treatment: treatment,
            ),
          ),
        ),
      );
    },
  );
}