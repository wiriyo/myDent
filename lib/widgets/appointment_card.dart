// ----------------------------------------------------------------
// 📁 lib/widgets/appointment_card.dart (UPGRADED)
// v1.2.0 - 💖 แก้ไขปัญหา Overflow และปรับปรุง Layout ให้ยืดหยุ่นขึ้น
// ----------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../styles/app_theme.dart';

typedef CardTheme = ({Color cardColor, Color borderColor});

class AppointmentCard extends StatelessWidget {
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

  CardTheme _getCardTheme(double rating, String status) {
    if (rating > 0) {
      if (rating >= 4.5) {
        return (cardColor: AppTheme.rating5Star, borderColor: Colors.green.shade200);
      } else if (rating >= 3.5) {
        return (cardColor: AppTheme.rating4Star, borderColor: Colors.yellow.shade300);
      } else {
        return (cardColor: AppTheme.rating3StarAndBelow, borderColor: Colors.red.shade200);
      }
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
              child: _buildFullView(context, appointment.startTime, appointment.endTime, patientName,
                  treatment, teeth, status, patientPhone, notes, rating, isCompact),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShortView(BuildContext context, String patientName, String treatment, String teeth, String phone, String status, BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                // ✨ FIX: ใช้ Flexible เพื่อให้ข้อความนี้ยืดหยุ่นและไม่ดันจนล้น
                if (constraints.maxHeight > 38)
                  Flexible(
                    child: Text(
                      '$treatment ${teeth.isNotEmpty ? '(#$teeth)' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black.withOpacity(0.7)),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8), 
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusChip(status, 10),
              const SizedBox(width: 4),
              _buildCompactCallButton(context, phone, patientName),
            ],
          ),
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
      double rating,
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
                    const SizedBox(height: 2), 
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
            const SizedBox(height: 2), 
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

  Widget _buildInfoRow({String? iconAsset, IconData? icon, required String text, required double iconSize, Color? iconColor, TextStyle? textStyle, int maxLines = 1,}) {
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

  Widget _buildRatingStars(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        Widget toothIcon;
        if (index < fullStars) {
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 18,
            height: 18,
          );
        } else if (index == fullStars && hasHalfStar) {
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 18,
            height: 18,
            color: AppTheme.ratingInflamedTooth,
          );
        } else {
          toothIcon = Image.asset(
            'assets/icons/tooth_broke.png',
            width: 18,
            height: 18,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: toothIcon,
        );
      }),
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
