// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // ✨ เพิ่ม import สำหรับ CalendarFormat
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointment_service.dart';
import 'appointment_add.dart';
import 'patients_screen.dart'; // ✨ เพิ่ม import สำหรับหน้าคนไข้
import 'reports_screen.dart'; // ✨ เพิ่ม import สำหรับหน้ารายงาน
import 'setting_screen.dart'; // ✨ เพิ่ม import สำหรับหน้าตั้งค่า
import 'package:url_launcher/url_launcher.dart';

// ✨ เพิ่ม enum สำหรับจัดการสถานะของปุ่มเปลี่ยนมุมมอง (เหมือนใน CalendarScreen)
enum _CalendarButtonMode { displayWeekly, displayDaily, displayMonthly }

class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _appointmentsWithPatients = [];
  int _selectedIndex = 0; // ✨ เพิ่มตัวแปรสำหรับเก็บ index ที่เลือกใน Bottom Bar

  // ✨ สถานะปัจจุบันของปุ่มเปลี่ยนมุมมองบนหน้ารายวัน
  _CalendarButtonMode _buttonModeForDailyView = _CalendarButtonMode.displayMonthly;

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

  // ✨ เพิ่มฟังก์ชัน _onItemTapped สำหรับจัดการการกดปุ่มใน Bottom Navigation Bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 🧭 ปรับการนำทาง
    if (index == 0) {
      // ถ้ากดปุ่ม Calendar (index 0) ในหน้า Daily Calendar ให้ย้อนกลับไปหน้า Calendar หลัก พร้อมบอกให้แสดงผลแบบรายเดือน
      // ไลลาส่ง CalendarFormat.month กลับไป เพื่อให้หน้า CalendarScreen รู้ว่าต้องแสดงผลแบบรายเดือน
      Navigator.pop(context, CalendarFormat.month);
    } else if (index == 1) {
      // ไปหน้า PatientsScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PatientsScreen()),
      );
    } else if (index == 3) {
      // ไปหน้า ReportsScreen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
    } else if (index == 4) {
      // ไปหน้า SettingsScreen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
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

  // ✨ ฟังก์ชันสำหรับสร้างปุ่มเปลี่ยนมุมมองบนหน้ารายวันค่ะ
  Widget _buildDailyScreenToggleButton() {
    IconData icon;
    String label;
    VoidCallback actionToPerform;

    // กำหนดไอคอน, ข้อความ, และการทำงานของปุ่มตามสถานะปัจจุบัน
    if (_buttonModeForDailyView == _CalendarButtonMode.displayMonthly) {
      icon = Icons.calendar_month;
      label = 'ดูรายเดือน';
      actionToPerform = () {
        // กลับไปหน้า CalendarScreen พร้อมบอกให้แสดงผลแบบรายเดือน
        Navigator.pop(context, CalendarFormat.month);
      };
    } else if (_buttonModeForDailyView == _CalendarButtonMode.displayWeekly) {
      icon = Icons.view_week;
      label = 'ดูรายสัปดาห์';
      actionToPerform = () {
        // กลับไปหน้า CalendarScreen พร้อมบอกให้แสดงผลแบบรายสัปดาห์
        Navigator.pop(context, CalendarFormat.week);
      };
    } else { // _buttonModeForDailyView == _CalendarButtonMode.displayDaily (หมายถึง "รีเฟรช" ในหน้านี้)
      icon = Icons.refresh; // ใช้ไอคอนรีเฟรช
      label = 'รีเฟรช';
      actionToPerform = () {
        _fetchAppointments(); // โหลดข้อมูลนัดหมายใหม่
      };
    }

    return TextButton.icon(
      onPressed: () {
        // ทำงานตาม action ที่กำหนดไว้
        actionToPerform();

        // เปลี่ยนสถานะของปุ่มนี้เพื่อให้ครั้งต่อไปแสดงตัวเลือกถัดไป
        setState(() {
          if (_buttonModeForDailyView == _CalendarButtonMode.displayMonthly) {
            _buttonModeForDailyView = _CalendarButtonMode.displayWeekly;
          } else if (_buttonModeForDailyView == _CalendarButtonMode.displayWeekly) {
            _buttonModeForDailyView = _CalendarButtonMode.displayDaily; // ต่อไปคือรีเฟรช
          } else { // เพิ่งกดรีเฟรช (displayDaily)
            _buttonModeForDailyView = _CalendarButtonMode.displayMonthly; // วนกลับไปที่ดูรายเดือน
          }
        });
      },
      icon: Icon(icon, color: Colors.purple),
      label: Text(label, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
          backgroundColor: Colors.purple.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
        child: Column( // ✨ เพิ่ม Column เพื่อให้ใส่ปุ่มด้านบนได้
          crossAxisAlignment: CrossAxisAlignment.end, // ✨ จัดให้ปุ่มอยู่ทางขวา
          children: [
            _buildDailyScreenToggleButton(), // ✨ เพิ่มปุ่มสลับมุมมองตรงนี้ค่ะ
            const SizedBox(height: 8), // ✨ เพิ่มระยะห่างเล็กน้อย
            Expanded( // ✨ ให้ ListView ใช้พื้นที่ที่เหลือ
              child: _appointmentsWithPatients.isEmpty
                  ? const Center(child: Text('ไม่มีนัดหมาย'))
                  : ListView.builder(
                      itemCount: buildAppointmentListWithGaps(
                        _appointmentsWithPatients,
                      ).length,
                      itemBuilder: (context, index) {
                        final item = buildAppointmentListWithGaps(
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
                                builder: (_) => AppointmentAddDialog(
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
                        final rating = patient['rating'] is int ? patient['rating'] : 0;

                        final duration = end.difference(start).inMinutes;
                        double height = 130 + ((duration - 30) * 1.5);
                        if (height < 130) height = 130;

                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AppointmentAddDialog(
                                appointmentData: appointment,
                              ),
                            ).then((_) => _fetchAppointments());
                          },
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
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: height),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'ชื่อคนไข้: ${patient['name'] ?? '-'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (rating > 0) _buildRatingStars(rating),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('เวลา: $time'),
                                    Text('หัตถการ: $treatment'),
                                    Text('สถานะ: $status'),
                                    if (patient['telephone'] != null &&
                                        patient['telephone'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text('เบอร์โทร: ${patient['telephone']}'),
                                      ),
                                    if (patient['telephone'] != null &&
                                        patient['telephone'].toString().isNotEmpty)
                                      Align(
                                        alignment: Alignment.bottomRight,
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
                            ),
                          ),
                        );
                      },
                    ),
            ), // ✨ ปีกกาของ Expanded ควรจะปิดตรงนี้
          ],
        ),
      ),
      // ✨ FloatingActionButton และ BottomNavigationBar ควรจะอยู่ใน Scaffold นะคะ
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AppointmentAddDialog(
              initialDate: widget.selectedDate,
            ),
          ).then((_) => _fetchAppointments());
        },
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        tooltip: 'เพิ่มนัดหมายใหม่',
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 30),
                color: _selectedIndex == 0 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
                tooltip: 'ปฏิทิน',
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color: _selectedIndex == 1 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
                tooltip: 'คนไข้',
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color: _selectedIndex == 3 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
                tooltip: 'รายงาน',
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color: _selectedIndex == 4 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
                tooltip: 'ตั้งค่า',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
