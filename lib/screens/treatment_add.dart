// lib/screens/treatment_add.dart

import 'package:flutter/material.dart';
import '../widgets/treatment_form.dart';

void showTreatmentDialog(
  BuildContext context, {
  required String patientId,
  Map<String, dynamic>? treatment,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16), // กันชนขอบจอ
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFFBEAFF),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: TreatmentForm(
            patientId: patientId,
            treatment: treatment,
          ),
        ),
      );
    },
  );
}
