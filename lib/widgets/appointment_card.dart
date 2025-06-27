// 📁 lib/widgets/appointment_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> patient;
  final VoidCallback onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.patient,
    required this.onTap,
  });

  // Helper function to build rating stars
  Widget _buildRatingStars(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: List.generate(5, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Image.asset(
              index < rating
                  ? 'assets/icons/tooth_good.png'
                  : 'assets/icons/tooth_broke.png',
              width: 16,
              height: 16,
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamic startRaw = appointment['startTime'];
    final dynamic endRaw = appointment['endTime'];

    DateTime? startTime;
    DateTime? endTime;
    if (startRaw is Timestamp) {
      startTime = startRaw.toDate();
    } else if (startRaw is String) {
      startTime = DateTime.tryParse(startRaw);
    }

    if (endRaw is Timestamp) {
      endTime = endRaw.toDate();
    } else if (endRaw is String) {
      endTime = DateTime.tryParse(endRaw);
    }

    final timeFormat = DateFormat.Hm();
    final startFormatted = startTime != null ? timeFormat.format(startTime) : '-';
    final endFormatted = endTime != null ? timeFormat.format(endTime) : '-';
    final showTime = endFormatted != '-' ? 'เวลา: $startFormatted - $endFormatted' : 'เวลา: $startFormatted';
    final treatment = appointment['treatment'] ?? '-';
    final status = appointment['status'] ?? '-';
    final rating = patient['rating'] is int ? patient['rating'] : 0;

    return InkWell(
      onTap: onTap,
      child: Card(
        color: () {
          if (status == 'ยืนยันแล้ว') {
            return const Color(0xFFE0F7E9);
          }
          if (status == 'รอยืนยัน' || status == 'ติดต่อไม่ได้') {
            return const Color(0xFFFFF8E1);
          }
          if (status == 'ไม่มาตามนัด' || status == 'ปฏิเสธนัด') {
            return const Color(0xFFFFEBEE);
          }
          return Colors.pink.shade50;
        }(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 50.0), // Add padding at the bottom for the button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Let the column take minimum required height
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'ชื่อคนไข้: ${patient['name'] ?? '-'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (rating > 0) _buildRatingStars(rating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(showTime),
                  Text('หัตถการ: $treatment'),
                  Text('สถานะ: $status'),
                  if (patient['telephone'] != null &&
                      patient['telephone'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('เบอร์โทร: ${patient['telephone']}'),
                    ),
                ],
              ),
            ),
            if (patient['telephone'] != null &&
                patient['telephone'].toString().isNotEmpty)
              Positioned(
                bottom: 12,
                right: 12,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade100,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    final phone = patient['telephone'];
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  icon: Image.asset(
                    'assets/icons/phone.png',
                    width: 20,
                    height: 20,
                  ),
                  label: const Text('โทร'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}