// 📁 lib/widgets/appointment_card.dart
// ไลลาช่วยปรับปรุงโค้ดให้น่ารักและปลอดภัยยิ่งขึ้นค่ะ 💕

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✨ สร้าง record น่ารักๆ ไว้เก็บคู่สี จะได้ไม่ต้องพิมพ์ซ้ำซ้อนค่ะ
typedef CardTheme = ({Color cardColor, Color borderColor});

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

  // --- ✨ [Helper] ฟังก์ชันดึงข้อมูลแบบปลอดภัย by ไลลา ✨ ---
  T _getData<T>(Map<String, dynamic> data, String key, T defaultValue) {
    if (data.containsKey(key) && data[key] is T) {
      return data[key] as T;
    }
    return defaultValue;
  }

  DateTime _getDateTime(Map<String, dynamic> data, String key) {
    if (data.containsKey(key) && data[key] is Timestamp) {
      return (data[key] as Timestamp).toDate();
    }
    return DateTime.now();
  }

  // --- ✨ [Helper] ฟังก์ชันเลือกสีการ์ดสุดน่ารัก by ไลลา ✨ ---
  CardTheme _getCardTheme(int rating, String status) {
    if (rating > 0) {
      return switch (rating) {
        5 => (
            cardColor: const Color(0xFFE0F2F1),
            borderColor: const Color(0xFFB2DFDB)
          ),
        4 => (
            cardColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFECB3)
          ),
        _ => (
            cardColor: const Color(0xFFFCE4EC),
            borderColor: const Color(0xFFF8BBD0)
          ),
      };
    }
    return switch (status) {
      'ยืนยันแล้ว' => (
          cardColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFFC8E6C9)
        ),
      'รอยืนยัน' || 'ติดต่อไม่ได้' => (
          cardColor: const Color(0xFFFFFDE7),
          borderColor: const Color(0xFFFFF9C4)
        ),
      'ไม่มาตามนัด' || 'ปฏิเสธนัด' => (
          cardColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFFFCDD2)
        ),
      _ => (
          cardColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade300
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _getDateTime(appointment, 'startTime');
    final endTime = _getDateTime(appointment, 'endTime');
    final status = _getData<String>(appointment, 'status', '-');
    final treatment = _getData<String>(appointment, 'treatment', 'ไม่มีข้อมูล');
    final notes = _getData<String>(appointment, 'notes', '');
    final teethList = _getData<List<dynamic>>(appointment, 'teeth', []);
    final teeth = teethList.join(', ');

    final patientName = _getData<String>(patient, 'name', 'คนไข้');
    final patientPhone = _getData<String>(patient, 'telephone', '');
    final rating = _getData<num>(patient, 'rating', 0).toInt();
    final cardTheme = _getCardTheme(rating, status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        color: cardTheme.cardColor,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cardTheme.borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isShort) {
              return _buildShortView(context, patientName, treatment, teeth,
                  patientPhone, status, constraints);
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              constraints: const BoxConstraints(minHeight: 90),
              child: _buildFullView(context, startTime, endTime, patientName,
                  treatment, status, patientPhone, notes, rating, isCompact),
            );
          },
        ),
      ),
    );
  }

  // --- 🧍 Widget สำหรับนัดหมายสั้นๆ (แถวเดียว) ---
  Widget _buildShortView(
      BuildContext context,
      String patientName,
      String treatment,
      String teeth,
      String phone,
      String status,
      BoxConstraints constraints) {
    bool isVeryCompact = constraints.maxWidth < 200;

    if (isVeryCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(patientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            _buildStatusChip(status, 10),
            const SizedBox(width: 2),
            _buildCompactCallButton(context, phone, patientName),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/icons/user.png', width: 16, height: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(patientName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
                softWrap: false),
          ),
          const SizedBox(width: 12),
          Image.asset('assets/icons/treatment.png', width: 16, height: 16),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text('$treatment ${teeth.isNotEmpty ? '(#$teeth)' : ''}',
                style:
                    TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis,
                softWrap: false),
          ),
          const Spacer(),
          _buildStatusChip(status, 11),
          const SizedBox(width: 6),
          _buildCallButton(context, phone, patientName),
        ],
      ),
    );
  }

  // --- 📝 Widget สำหรับการ์ดเต็มรูปแบบ (แก้ไขแล้ว!) ---
  Widget _buildFullView(
      BuildContext context,
      DateTime startTime,
      DateTime endTime,
      String patientName,
      String treatment,
      String status,
      String phone,
      String notes,
      int rating,
      bool isCompact) {
    final durationInMinutes = endTime.difference(startTime).inMinutes;
    final bool isLongAppointment = durationInMinutes > 60;
    final bool useLargeLayout = isLongAppointment && !isCompact;
    final double iconSize = useLargeLayout ? 20.0 : 16.0;
    final double titleSize = useLargeLayout ? 19.0 : 16.0;
    final double detailSize = useLargeLayout ? 15.0 : 13.0;
    final double notesSize = useLargeLayout ? 14.0 : 12.0;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // จัดให้อยู่กลางสวยๆ
                children: [
                  if (useLargeLayout) const SizedBox(height: 30),
                  _buildInfoRow(
                    iconAsset: 'assets/icons/user.png',
                    text: patientName,
                    iconSize: iconSize,
                    textStyle: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: titleSize),
                  ),
                  const SizedBox(height: 4),

                  // ✨ [FIX] จะแสดงเวลาและโน้ตเฉพาะนัดที่ยาวกว่า 60 นาทีเท่านั้นค่ะ! ✨
                  if (isLongAppointment) ...[
                    _buildInfoRow(
                      iconAsset: 'assets/icons/clock.png',
                      text:
                          '${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)} ($durationInMinutes นาที)',
                      iconSize: iconSize,
                      textStyle: TextStyle(
                          fontSize: detailSize, color: Colors.black.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 4),
                  ],

                  _buildInfoRow(
                    iconAsset: 'assets/icons/treatment.png',
                    text: treatment,
                    iconSize: iconSize,
                    textStyle: TextStyle(
                        fontSize: detailSize, color: Colors.black.withOpacity(0.8)),
                    maxLines: useLargeLayout ? 2 : 1,
                  ),

                  if (isLongAppointment && notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildInfoRow(
                      icon: Icons.notes_rounded,
                      text: notes,
                      iconSize: iconSize,
                      iconColor: Colors.grey.shade700,
                      textStyle: TextStyle(
                          fontSize: notesSize,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildStatusChip(status, 12),
                const SizedBox(width: 4),
                _buildCompactCallButton(context, phone, patientName),
              ],
            ),
          ],
        ),
        if (rating > 0 && useLargeLayout)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildRatingStars(rating),
            ),
          ),
      ],
    );
  }

  // --- 💁‍♀️ [Helper Widget] สร้างแถวข้อมูลพร้อมไอคอน ---
  Widget _buildInfoRow({
    String? iconAsset,
    IconData? icon,
    required String text,
    required double iconSize,
    Color? iconColor,
    TextStyle? textStyle,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: (iconAsset != null)
              ? Image.asset(iconAsset, width: iconSize, height: iconSize)
              : Icon(icon, size: iconSize, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textStyle,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- 🏷️ [Helper Widget] ป้ายสถานะ ---
  Widget _buildStatusChip(String status, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87),
      ),
    );
  }

  // --- ⭐ [Helper Widget] ดาว Rating ---
  Widget _buildRatingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Image.asset(
            index < rating
                ? 'assets/icons/tooth_good.png'
                : 'assets/icons/tooth_broke.png',
            width: 18,
            height: 18,
          ),
        );
      }),
    );
  }

  // --- 📞 [Helper Widget] ปุ่มโทรแบบเต็ม ---
  Widget _buildCallButton(
      BuildContext context, String phone, String patientName) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _makeCall(context, phone, patientName),
      child: Tooltip(
        message: 'โทรหา $patientName',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade200, width: 1.2),
          ),
          child: Icon(Icons.phone_rounded,
              color: Colors.green.shade600, size: 22),
        ),
      ),
    );
  }

  // --- 📞 [Helper Widget] ปุ่มโทรแบบย่อ ---
  Widget _buildCompactCallButton(
      BuildContext context, String phone, String patientName) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _makeCall(context, phone, patientName),
      child: Tooltip(
        message: 'โทรหา $patientName',
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade200, width: 1),
          ),
          child: Icon(Icons.phone_forwarded_rounded,
              color: Colors.green.shade600, size: 20),
        ),
      ),
    );
  }

  // --- ☎️ [Action] ฟังก์ชันสำหรับโทรออก ---
  void _makeCall(
      BuildContext context, String? phoneNumber, String patientName) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่มีเบอร์โทรศัพท์สำหรับคุณ $patientName ค่ะ'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'ไม่สามารถเปิดแอปโทรศัพท์ได้';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโทรออกค่ะ: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}
