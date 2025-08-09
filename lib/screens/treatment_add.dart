// ================================================================
// � 5. lib/screens/treatment_add.dart
// v1.4.0 - ✨ อัปเกรดให้เรียกใช้ TreatmentProvider
// ================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/treatment_provider.dart';
import '../widgets/treatment_form.dart';
import '../models/treatment.dart';

void showTreatmentDialog(
  BuildContext context, {
  required String patientId,
  String? patientName,
  String? initialProcedure,
  DateTime? initialDate,
  String? initialToothNumber,
  double? initialPrice,
  Treatment? treatment,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
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
              patientName: patientName,
              initialProcedure: initialProcedure,
              initialDate: initialDate,
              initialToothNumber: initialToothNumber,
              initialPrice: initialPrice,
              treatment: treatment,
            ),
          ),
        ),
      );
    },
  );
}