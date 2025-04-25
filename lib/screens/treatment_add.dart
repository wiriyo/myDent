// lib/screens/treatment_add.dart

import 'package:flutter/material.dart';
import '../widgets/treatment_form.dart';

// class TreatmentAddScreen extends StatelessWidget {
//   final String patientId;
//   final Map<String, dynamic>? treatment;

//   const TreatmentAddScreen({
//     super.key,
//     required this.patientId,
//     this.treatment,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('เพิ่มการรักษา')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: TreatmentForm(
//           patientId: patientId,
//           treatment: treatment,
//         ),
//       ),
//     );
//   }
// }

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
