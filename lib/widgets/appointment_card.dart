// 📁 lib/widgets/appointment_card.dart (แก้ไข Layout ให้สมบูรณ์และปลอดภัย)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> patient;
  final VoidCallback onTap;
  final bool isCompact;
  final bool isShort;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.patient,
    required this.onTap,
    this.isCompact = false,
    this.isShort = false,
  });

  @override
  Widget build(BuildContext context) {
    // --- ดึงข้อมูลพื้นฐาน ---
    final startTime = (appointment['startTime'] as Timestamp).toDate();
    final endTime = (appointment['endTime'] as Timestamp).toDate();
    final status = appointment['status'] ?? '-';
    final patientName = patient['name'] ?? '-';
    final treatment = appointment['treatment'] ?? '-';
    final teethList = appointment['teeth'] as List<dynamic>?;
    final teeth =
        (teethList != null && teethList.isNotEmpty) ? teethList.join(', ') : '';
    final String notes = appointment['notes'] ?? '';
    final int rating = (patient['rating'] as num?)?.toInt() ?? 0;

    // --- ✨ ปรับปรุง Logic การเลือกสีให้ใกล้เคียงกับ Dialog ✨ ---
    Color cardColor;
    Color borderColor;

    if (rating > 0) {
      if (rating >= 5) {
        cardColor = const Color(0xFFE0F7E9); // light green
        borderColor = const Color(0xFFC3E6CB);
      } else if (rating >= 4) {
        cardColor = const Color(0xFFFFF8E1); // light yellow
        borderColor = const Color(0xFFFFEEBA);
      } else { // 1-3 stars
        cardColor = const Color(0xFFFFEBEE); // light red
        borderColor = const Color(0xFFF5C6CB);
      }
    } else {
      // Fallback to status-based color if rating is 0
      cardColor = switch (status) {
        'ยืนยันแล้ว' => const Color(0xFFD4EDDA),
        'รอยืนยัน' || 'ติดต่อไม่ได้' => const Color(0xFFFFF3CD),
        'ไม่มาตามนัด' || 'ปฏิเสธนัด' => const Color(0xFFF8D7DA),
        _ => Colors.grey.shade200,
      };
      borderColor = switch (status) {
        'ยืนยันแล้ว' => const Color(0xFFC3E6CB),
        'รอยืนยัน' || 'ติดต่อไม่ได้' => const Color(0xFFFFEEBA),
        'ไม่มาตามนัด' || 'ปฏิเสธนัด' => const Color(0xFFF5C6CB),
        _ => Colors.grey.shade300,
      };
    }

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
            // ถ้าเป็นนัดหมายสั้น ให้แสดงผลแบบแถวเดียวเสมอ
            if (isShort) {
              return _buildShortView(context, patientName, treatment, teeth, patient['telephone'],
                  status, constraints);
            }

            return Container(
              padding: const EdgeInsets.all(12),
              // กำหนดความสูงขั้นต่ำเพื่อให้การ์ดไม่เล็กเกินไปใน ListView
              constraints: const BoxConstraints(minHeight: 90),
              child: _buildFullView(
                  context, startTime, endTime, patientName, treatment, status, patient['telephone'], notes, rating, isCompact),
            );
          },
        ),
      ),
    );
  }

  // Widget สำหรับนัดหมายสั้นๆ (<= 30 นาที) แสดงผลในแถวเดียว
  Widget _buildShortView(BuildContext context, String patientName,
      String treatment, String teeth, String? phone, String status, BoxConstraints constraints) {
    // เมื่อการ์ดถูกบีบให้แคบมากๆ ให้แสดงข้อมูลที่จำเป็นที่สุด
    bool isVeryCompact = constraints.maxWidth < 180;

    if (isVeryCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                patientName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 2),
            _buildCompactCallButton(context, phone, patientName),
          ],
        ),
      );
    }

    // Layout ปกติสำหรับนัดหมายสั้น
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/icons/user.png', width: 16, height: 16),
          const SizedBox(width: 4),
          Flexible(
            flex: 5, // ให้น้ำหนักกับชื่อคนไข้
            fit: FlexFit.loose,
            child: Text(
              patientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset('assets/icons/treatment.png', width: 16, height: 16),
          const SizedBox(width: 4),
          Flexible(
            flex: 6, // ให้น้ำหนักกับหัตถการ
            fit: FlexFit.loose,
            child: Text(
              '$treatment ${teeth.isNotEmpty ? teeth : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const Spacer(), // ✨ ใช้ Spacer จัดการพื้นที่ว่างที่เหลือทั้งหมด
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          // ✨ ปรับปุ่มโทรให้มีกรอบวงกลม ✨
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _makeCall(context, phone),
            child: Tooltip(
              message: 'โทรหา $patientName',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Icon(Icons.phone,
                    color: Colors.green.shade700, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCallButton(BuildContext context, String? phone, String patientName) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _makeCall(context, phone),
      child: Tooltip(
        message: 'โทรหา $patientName',
        child: Container(
          padding: const EdgeInsets.all(4), // ลด padding เพื่อลดความสูงโดยรวม
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Icon(Icons.phone,
              color: Colors.green.shade700, size: 20),
        ),
      ),
    );
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Image.asset(
            index < rating
                ? 'assets/icons/tooth_good.png'
                : 'assets/icons/tooth_broke.png',
            width: 16,
            height: 16,
          ),
        );
      }),
    );
  }

  // ฟังก์ชันสำหรับโทรออก
  void _makeCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ไม่มีเบอร์โทรศัพท์สำหรับคนไข้รายนี้'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรออกได้: $e')),
      );
    }
  }

  // ✨ Widget สำหรับการ์ดเวอร์ชันเต็ม (ที่แก้ไขแล้ว ไม่ใช้ Spacer) ✨
  Widget _buildFullView(BuildContext context, DateTime startTime, DateTime endTime,
      String patientName, String treatment, String status, String? phone, String notes, int rating, bool isCompact) {
    final durationInMinutes = endTime.difference(startTime).inMinutes;
    final bool isLongAppointment = durationInMinutes > 60;

    // ✨ กำหนดขนาด Font และ Icon ตามเงื่อนไข ✨
    // ใช้ Layout ขนาดใหญ่เมื่อเป็นการ์ดนัดหมายยาว และไม่ได้ถูกบีบอัด (isCompact = false)
    final bool useLargeLayout = isLongAppointment && !isCompact;

    final double iconSize = useLargeLayout ? 20.0 : 16.0;
    final double titleFontSize = useLargeLayout ? 20.0 : 15.0;
    final double subtitleFontSize = useLargeLayout ? 18.0 : 12.0;
    final double treatmentFontSize = useLargeLayout ? 18.0 : 13.0;
    final double statusFontSize = useLargeLayout ? 16.0 : 11.0;
    final double notesIconSize = useLargeLayout ? 18.0 : 14.0;
    final double notesFontSize = useLargeLayout ? 18.0 : 12.0;


    return Stack(
      children: [
        Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // จัดการพื้นที่แนวตั้งให้ Widget แรกอยู่บนสุด และตัวสุดท้ายอยู่ล่างสุด
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ส่วนบนของการ์ด
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✨ เพิ่มช่องว่างด้านบนเมื่อเป็นการ์ดนัดหมายยาว เพื่อไม่ให้ทับกับ Rating ✨
            if (isLongAppointment)
              const SizedBox(height: 30),
            Row(
              children: [
                Image.asset('assets/icons/user.png', width: iconSize, height: iconSize),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patientName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleFontSize),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1), // ลดระยะห่างลง 1px เพื่อแก้ปัญหา Overflow
            Row(
              children: [
                Image.asset(
                  'assets/icons/clock.png',
                  width: iconSize,
                  height: iconSize,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}',
                  style: TextStyle(fontSize: subtitleFontSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox.shrink(), // ลดระยะห่างลง 1px (ใช้ shrink() จะไม่มีความสูงเลย)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/icons/treatment.png', width: iconSize, height: iconSize),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    treatment,
                    style: TextStyle(fontSize: treatmentFontSize, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: isLongAppointment ? 2 : 1,
                  ),
                ),
              ],
            ),
            if (isLongAppointment && notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined, size: notesIconSize, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(fontSize: notesFontSize, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        // const Spacer(), // ไม่จำเป็นแล้วเมื่อใช้ MainAxisAlignment.spaceBetween
        Align( // ส่วนล่างของการ์ด
          alignment: Alignment.bottomRight, // จัดชิดขวาล่าง
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: statusFontSize, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              _buildCompactCallButton(context, phone, patientName),
            ],
          ),
        ),
      ],
    ),
    if (isLongAppointment && !isCompact && rating > 0)
      Positioned(
        top: 4,
        right: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade100),
          ),
          child: _buildRatingStars(rating),
        ),
      ),
    ]
    ); // Closing bracket for Stack
  }
}