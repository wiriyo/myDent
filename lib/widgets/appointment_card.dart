 // v1.1.0 - ✨ Upgraded to use Models for Type Safety
// 📁 lib/widgets/appointment_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../styles/app_theme.dart';

// ✨ [Type Safety] ไลลาสร้าง Type Definition สำหรับ Theme ของการ์ด
// เพื่อให้โค้ดอ่านง่ายและจัดการได้สะดวกขึ้นค่ะ
typedef CardTheme = ({Color cardColor, Color borderColor});

class AppointmentCard extends StatelessWidget {
  // ✨ [MODERNIZED] เปลี่ยนจากการรับ Map<String, dynamic> ที่ไม่ปลอดภัย
  // มาเป็น Model ที่แข็งแรงและกำหนดชนิดข้อมูลชัดเจนค่ะ
  // ทำให้เรามั่นใจได้ 100% ว่าข้อมูลที่เข้ามาจะถูกต้องเสมอ
  final AppointmentModel appointment;
  final Patient patient;

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

  // 🗑️ [REMOVED] ไลลาได้ลบฟังก์ชัน _getData และ _getDateTime ที่ไม่จำเป็นออกไปแล้วค่ะ
  // เพราะตอนนี้เราสามารถเข้าถึงข้อมูลจาก Model ได้โดยตรง (เช่น appointment.status)
  // ทำให้โค้ดสะอาดและสั้นลงมากเลยค่ะ!

  // ฟังก์ชันสำหรับกำหนดสีของการ์ดตาม Rating ของคนไข้ หรือสถานะของนัด
  CardTheme _getCardTheme(int rating, String status) {
    // ถ้าคนไข้มี Rating (เคยมาใช้บริการและเราให้คะแนนไว้)
    // เราจะใช้สีตาม Rating เป็นหลักค่ะ
    if (rating > 0) {
      return switch (rating) {
        5 => ( // 5 ดาว: สีเขียว สดใส น่าเชื่อถือ
            cardColor: AppTheme.rating5Star,
            borderColor: Colors.green.shade200,
          ),
        4 => ( // 4 ดาว: สีเหลืองอมส้ม ดูดี
            cardColor: AppTheme.rating4Star,
            borderColor: Colors.yellow.shade300,
          ),
        _ => ( // 3 ดาวหรือต่ำกว่า: สีแดงอ่อนๆ เป็นการเตือนให้ระวัง
            cardColor: AppTheme.rating3StarAndBelow,
            borderColor: Colors.red.shade200,
          ),
      };
    }
    // ถ้าไม่มี Rating (คนไข้ใหม่) จะใช้สีตามสถานะของนัดแทน
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
      _ => ( // สถานะอื่นๆ หรือไม่มีข้อมูล
          cardColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade300
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // ✨ [CLEAN CODE] เข้าถึงข้อมูลจาก Model โดยตรง ทำให้โค้ดอ่านง่ายและปลอดภัยขึ้น
    // เราใช้ Null-aware operators (??) เพื่อกำหนดค่าเริ่มต้นในกรณีที่ข้อมูลเป็น null ค่ะ
    final status = appointment.status;
    final treatment = appointment.treatment;
    final notes = appointment.notes ?? '';
    final teethList = appointment.teeth ?? [];
    final teeth = teethList.join(', ');

    final patientName = patient.name;
    final patientPhone = patient.telephone ?? '';
    final rating = patient.rating;
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
              // ✨ [SIMPLIFIED] ส่งค่าจาก Model ไปตรงๆ ไม่ต้องผ่าน Map แล้วค่ะ
              child: _buildFullView(context, appointment.startTime, appointment.endTime, patientName,
                  treatment, teeth, status, patientPhone, notes, rating, isCompact),
            );
          },
        ),
      ),
    );
  }

  // ส่วนของ UI ที่เหลือ ไลลาไม่ได้แตะต้องอะไรเลยนะคะ ยังคงสวยงามเหมือนเดิมค่ะ
  // แต่จะมีการปรับการรับค่าเล็กน้อยให้สอดคล้องกับการใช้ Model ค่ะ

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

  Widget _buildFullView(
      BuildContext context,
      DateTime startTime,
      DateTime endTime,
      String patientName,
      String treatment,
      String teeth,
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
    final String fullTreatmentText = '$treatment ${teeth.isNotEmpty ? '(#$teeth)' : ''}';

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
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
                      text: fullTreatmentText,
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
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: _buildStatusChip(status, 12)),
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
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildRatingStars(rating),
            ),
          ),
      ],
    );
  }

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
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

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
