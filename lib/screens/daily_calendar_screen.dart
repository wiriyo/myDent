// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointment_service.dart';
import 'appointment_add.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _appointmentsWithPatients = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  void _fetchAppointments() async {
    List<Map<String, dynamic>> appointments = await _appointmentService
        .getAppointmentsByDate(widget.selectedDate);

    List<Map<String, dynamic>> result = [];
    for (var appointment in appointments) {
      final patientId = appointment['patientId'];
      Map<String, dynamic>? patient = await _appointmentService.getPatientById(
        patientId,
      );
      if (patient != null) {
        result.add({'appointment': appointment, 'patient': patient});
      }
    }
    if (mounted) {
      setState(() {
        _appointmentsWithPatients = result;
      });
    }
  }

  List<Map<String, dynamic>> buildAppointmentListWithGaps(
    List<Map<String, dynamic>> rawList,
  ) {
    List<Map<String, dynamic>> fullList = [];

    rawList.sort((a, b) {
      final aStart = a['appointment']['startTime'] as Timestamp;
      final bStart = b['appointment']['startTime'] as Timestamp;
      return aStart.compareTo(bStart);
    });

    for (int i = 0; i < rawList.length; i++) {
      fullList.add(rawList[i]);
      if (i < rawList.length - 1) {
        final currentEnd =
            (rawList[i]['appointment']['endTime'] as Timestamp).toDate();
        final nextStart =
            (rawList[i + 1]['appointment']['startTime'] as Timestamp).toDate();
        if (currentEnd.isBefore(nextStart)) {
          fullList.add({'isGap': true, 'start': currentEnd, 'end': nextStart});
        }
      }
    }
    return fullList;
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        elevation: 0,
        title: Text(
          'นัดหมายประจำวันที่ ${DateFormat('d MMM yyyy', 'th_TH').format(widget.selectedDate)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child:
            _appointmentsWithPatients.isEmpty
                ? const Center(child: Text('ไม่มีนัดหมาย'))
                : ListView.builder(
                  itemCount:
                      buildAppointmentListWithGaps(
                        _appointmentsWithPatients,
                      ).length,
                  itemBuilder: (context, index) {
                    final item =
                        buildAppointmentListWithGaps(
                          _appointmentsWithPatients,
                        )[index];

                    if (item['isGap'] == true) {
                      final gapStart = item['start'] as DateTime;
                      final gapEnd = item['end'] as DateTime;
                      final timeFormat = DateFormat.Hm();
                      return InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (_) => AppointmentAddDialog(
                                  initialDate: widget.selectedDate,
                                  initialStartTime: gapStart,
                                ),
                          ).then((_) => _fetchAppointments());
                        },
                        child: Card(
                          color: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'ว่าง: ${timeFormat.format(gapStart)} - ${timeFormat.format(gapEnd)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final appointment = item['appointment'];
                    final patient = item['patient'];

                    final start =
                        (appointment['startTime'] as Timestamp).toDate();
                    final end = (appointment['endTime'] as Timestamp).toDate();
                    final time =
                        '${DateFormat.Hm().format(start)} - ${DateFormat.Hm().format(end)}';
                    final treatment = appointment['treatment'] ?? '-';
                    final status = appointment['status'] ?? '-';
                    final rating =
                        patient['rating'] is int ? patient['rating'] : 0;

                    final duration = end.difference(start).inMinutes;
                    double height = 130;
                    if (duration >= 90)
                      height = 180;
                    else if (duration >= 60)
                      height = 160;

                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (_) => AppointmentAddDialog(
                                appointmentData: appointment,
                              ),
                        ).then((_) => _fetchAppointments());
                      },
                      child: Card(
                        color: () {
                          if (status == 'ยืนยันแล้ว')
                            return const Color(0xFFE0F7E9);
                          if (status == 'รอยืนยัน' || status == 'ติดต่อไม่ได้')
                            return const Color(0xFFFFF8E1);
                          if (status == 'ไม่มาตามนัด' || status == 'ปฏิเสธนัด')
                            return const Color(0xFFFFEBEE);
                          return Colors.pink.shade50;
                        }(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: SizedBox(
                          height: height,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'ชื่อคนไข้: ${patient['name'] ?? '-'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (rating > 0)
                                          _buildRatingStars(rating),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('เวลา: $time'),
                                    Text('หัตถการ: $treatment'),
                                    Text('สถานะ: $status'),
                                    if (patient['telephone'] != null &&
                                        patient['telephone']
                                            .toString()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Text(
                                          'เบอร์โทร: ${patient['telephone']}',
                                        ),
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
                                      backgroundColor:
                                          Colors.greenAccent.shade100,
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
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
