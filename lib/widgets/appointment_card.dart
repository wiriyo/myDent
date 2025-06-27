// 📁 lib/widgets/appointment_card.dart (อัปเกรดให้แปลงร่างได้ ✨)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> patient;
  final VoidCallback onTap;
  // ✨ เพิ่มตัวแปร isCompact เข้ามาตรงนี้นะคะ! ✨
  final bool isCompact;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.patient,
    required this.onTap,
    this.isCompact = false, // ค่าเริ่มต้นคือไม่แปลงร่าง
  });

  @override
  Widget build(BuildContext context) {
    final startTime = (appointment['startTime'] as Timestamp).toDate();
    final status = appointment['status'] ?? '-';
    final patientName = patient['name'] ?? '-';

    Color cardColor = switch (status) {
      'ยืนยันแล้ว' => const Color(0xFFD4EDDA),
      'รอยืนยัน' || 'ติดต่อไม่ได้' => const Color(0xFFFFF3CD),
      'ไม่มาตามนัด' || 'ปฏิเสธนัด' => const Color(0xFFF8D7DA),
      _ => Colors.grey.shade200,
    };

    Color borderColor = switch (status) {
      'ยืนยันแล้ว' => const Color(0xFFC3E6CB),
      'รอยืนยัน' || 'ติดต่อไม่ได้' => const Color(0xFFFFEEBA),
      'ไม่มาตามนัด' || 'ปฏิเสธนัด' => const Color(0xFFF5C6CB),
      _ => Colors.grey.shade300,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        // ถ้าการ์ดถูกบีบให้แคบมากๆ หรือเราสั่งให้ isCompact เป็น true
        bool showCompact = isCompact || constraints.maxWidth < 100;

        return InkWell(
          onTap: onTap,
          child: Card(
            elevation: 0,
            color: cardColor,
            margin: const EdgeInsets.all(1.5),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(showCompact ? 4 : 8),
              child: showCompact
                  ? _buildCompactView(startTime, patientName)
                  : _buildFullView(startTime, status, patientName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactView(DateTime startTime, String patientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          DateFormat.Hm().format(startTime),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          patientName,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildFullView(DateTime startTime, String status, String patientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Text(
          'เวลา: ${DateFormat.Hm().format(startTime)}',
          style: const TextStyle(fontSize: 13),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}