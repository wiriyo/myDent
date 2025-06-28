// 📁 lib/widgets/appointment_card.dart (ฉบับสมบูรณ์)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> patient;
  final VoidCallback onTap;
  final bool isCompact;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.patient,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = (appointment['startTime'] as Timestamp).toDate();
    final endTime = (appointment['endTime'] as Timestamp).toDate();
    final status = appointment['status'] ?? '-';
    final patientName = patient['name'] ?? '-';
    final treatment = appointment['treatment'] ?? '-';

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

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1.5),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool showCompact = isCompact || constraints.maxWidth < 110;
            return Container(
              padding: EdgeInsets.all(showCompact ? 6 : 12),
              child: showCompact
                  ? _buildCompactView(startTime, patientName)
                  : _buildFullView(startTime, endTime, patientName, treatment, status),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactView(DateTime startTime, String patientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          DateFormat.Hm().format(startTime),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black.withOpacity(0.8)),
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

  Widget _buildFullView(DateTime startTime, DateTime endTime, String patientName, String treatment, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'เวลา: ${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}',
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          treatment,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const Spacer(), // ใช้ Spacer เพื่อดัน Status ไปข้างล่าง
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}