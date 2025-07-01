// 📁 lib/widgets/appointment_card.dart (แก้ไข Layout ให้สมบูรณ์และปลอดภัย)

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
    // --- ดึงข้อมูลพื้นฐาน ---
    final startTime = (appointment['startTime'] as Timestamp).toDate();
    final endTime = (appointment['endTime'] as Timestamp).toDate();
    final status = appointment['status'] ?? '-';
    final patientName = patient['name'] ?? '-';
    final treatment = appointment['treatment'] ?? '-';

    // --- เลือกสีพื้นหลังของการ์ด ---
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool showCompact = isCompact || constraints.maxWidth < 110;

            // ✨ ใช้ Container ที่มีความสูงที่แน่นอนสำหรับหน้า ListView ✨
            // และใช้ Column ธรรมดาสำหรับ Timeline view
            return Container(
              padding: EdgeInsets.all(showCompact ? 6 : 12),
              // กำหนดความสูงขั้นต่ำเพื่อให้การ์ดไม่เล็กเกินไปใน ListView
              constraints: const BoxConstraints(minHeight: 90),
              child: showCompact
                  ? _buildCompactView(startTime, patientName)
                  : _buildFullView(startTime, endTime, patientName, treatment, status),
            );
          },
        ),
      ),
    );
  }

  // Widget สำหรับการ์ดเวอร์ชันมินิ (เมื่ออยู่ใน Timeline ที่แคบ)
  Widget _buildCompactView(DateTime startTime, String patientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start, // จัดชิดบน
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

  // ✨ Widget สำหรับการ์ดเวอร์ชันเต็ม (ที่แก้ไขแล้ว ไม่ใช้ Spacer) ✨
  Widget _buildFullView(DateTime startTime, DateTime endTime, String patientName, String treatment, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // ✨ ทำให้ Column ไม่พยายามขยายจนสุด
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
        // ✨ ใช้ Expanded หุ้ม Text เพื่อให้ตัดคำได้เมื่อข้อความยาว ✨
        Expanded(
          child: Text(
            treatment,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        // ✨ ไม่ใช้ Spacer แต่ใช้ SizedBox และ Align เพื่อจัดตำแหน่ง Status ✨
         const SizedBox(height: 8),
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