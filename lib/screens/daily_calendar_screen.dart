// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // ✨ เพิ่ม import สำหรับ CalendarFormat
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointment_service.dart';
import '../widgets/appointment_card.dart';
import '../widgets/gap_card.dart';
import '../services/working_hours_service.dart'; // เพิ่ม import
import '../models/working_hours_model.dart'; // เพิ่ม import
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
  DayWorkingHours? _selectedDayWorkingHours; // เพิ่มตัวแปร
  final WorkingHoursService _workingHoursService = WorkingHoursService(); // เพิ่มตัวแปร
  int _selectedIndex = 0; // ✨ เพิ่มตัวแปรสำหรับเก็บ index ที่เลือกใน Bottom Bar

  // ✨ สถานะปัจจุบันของปุ่มเปลี่ยนมุมมองบนหน้ารายวัน
  _CalendarButtonMode _buttonModeForDailyView = _CalendarButtonMode.displayMonthly;

  @override
  void initState() { // แก้ไข initState
    super.initState();
    _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
  }

  // Helper function to combine DateTime and TimeOfDay
  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // Helper to get Thai day name
  String _getThaiDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'จันทร์';
      case DateTime.tuesday: return 'อังคาร';
      case DateTime.wednesday: return 'พุธ';
      case DateTime.thursday: return 'พฤหัสบดี';
      case DateTime.friday: return 'ศุกร์';
      case DateTime.saturday: return 'เสาร์';
      case DateTime.sunday: return 'อาทิตย์';
      default: return '';
    }
  }

  // New combined fetch method for appointments and working hours
  void _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    // Fetch appointments
    List<Map<String, dynamic>> appointments = await _appointmentService.getAppointmentsByDate(selectedDay);

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

    // Fetch working hours for the selected day
    DayWorkingHours? dayWorkingHours;
    try {
      final allWorkingHours = await _workingHoursService.loadWorkingHours();
      final dayName = _getThaiDayName(selectedDay.weekday);
      dayWorkingHours = allWorkingHours.firstWhere(
        (day) => day.dayName == dayName,
        orElse: () => DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []),
      );
    } catch (e) {
      debugPrint('Error loading working hours for selected day: $e');
      dayWorkingHours = DayWorkingHours(dayName: _getThaiDayName(selectedDay.weekday), isClosed: true, timeSlots: []);
    }

    if (mounted) {
      setState(() {
        _appointmentsWithPatients = result;
        _selectedDayWorkingHours = dayWorkingHours; // อัปเดตเวลาทำการ
      });
    }
  }

  // ✨ เพิ่มฟังก์ชัน _onItemTapped สำหรับจัดการการกดปุ่มใน Bottom Navigation Bar
  void _onItemTapped(int index) {
    // 🧭 ปรับการนำทาง
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // ถ้ากดปุ่ม Calendar (index 0) ในหน้า Daily Calendar ให้ย้อนกลับไปหน้า Calendar หลัก พร้อมบอกให้แสดงผลแบบรายเดือน
      // ไลลาส่ง CalendarFormat.month กลับไป เพื่อให้หน้า CalendarScreen รู้ว่าต้องแสดงผลแบบรายเดือน
      Navigator.pop(context, CalendarFormat.month);
    } else if (index == 1) {
      // ไปหน้า PatientsScreen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PatientsScreen()));
    } else if (index == 3) {
      // ไปหน้า ReportsScreen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
    } else if (index == 4) {
      // ไปหน้า SettingsScreen
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
    }
  }

  // Modified buildAppointmentListWithGaps to consider clinic working hours
  List<Map<String, dynamic>> buildAppointmentListWithGaps(
    List<Map<String, dynamic>> rawAppointments,
    DayWorkingHours? dayWorkingHours,
    DateTime selectedDate,
  ) {
    List<Map<String, dynamic>> finalCombinedList = [];

    // If the clinic is closed or no working hours are defined for the day,
    // only show existing appointments, no new gaps.
    if (dayWorkingHours == null || dayWorkingHours.isClosed || dayWorkingHours.timeSlots.isEmpty) {
      rawAppointments.sort((a, b) {
        final aStart = a['appointment']['startTime'] as Timestamp;
        final bStart = b['appointment']['startTime'] as Timestamp;
        return aStart.toDate().compareTo(bStart.toDate());
      });
      return rawAppointments;
    }

    // Create a list of all "events" (start/end of clinic slots and appointments)
    List<Map<String, dynamic>> events = [];

    // Add clinic working hours as events
    for (var slot in dayWorkingHours.timeSlots) {
      events.add({
        'time': _combineDateAndTime(selectedDate, slot.openTime),
        'type': 'clinic_open',
      });
      events.add({
        'time': _combineDateAndTime(selectedDate, slot.closeTime),
        'type': 'clinic_close',
      });
    }

    // Add appointments as events
    for (var appt in rawAppointments) {
      events.add({
        'time': (appt['appointment']['startTime'] as Timestamp).toDate(),
        'type': 'appointment_start',
        'data': appt, // Store the full appointment data
      });
      events.add({
        'time': (appt['appointment']['endTime'] as Timestamp).toDate(),
        'type': 'appointment_end',
      });
    }

    // Sort all events by time. If times are equal, clinic_open/appointment_start comes before clinic_close/appointment_end.
    events.sort((a, b) {
      final timeA = a['time'] as DateTime;
      final timeB = b['time'] as DateTime;
      int compare = timeA.compareTo(timeB);
      if (compare == 0) {
        // Prioritize 'open' or 'start' events over 'close' or 'end' events at the same time
        if (a['type'] == 'clinic_open' || a['type'] == 'appointment_start') return -1;
        if (b['type'] == 'clinic_open' || b['type'] == 'appointment_start') return 1;
      }
      return compare;
    });

    // Process events to build the final combined list
    DateTime? lastProcessedTime;
    int openClinicCount = 0; // Tracks if we are currently within a clinic's open slot
    int activeAppointmentCount = 0; // Tracks if we are currently within an appointment

    for (var event in events) {
      final currentTime = event['time'] as DateTime;

      // If there's a time gap between lastProcessedTime and currentTime
      if (lastProcessedTime != null && currentTime.isAfter(lastProcessedTime)) {
        // If clinic is open and no appointments are active, it's a free slot (gap)
        if (openClinicCount > 0 && activeAppointmentCount == 0) {
          finalCombinedList.add({
            'isGap': true,
            'start': lastProcessedTime,
            'end': currentTime,
          });
        }
      }

      // Update counts based on the current event
      if (event['type'] == 'clinic_open') {
        openClinicCount++;
      } else if (event['type'] == 'clinic_close') {
        openClinicCount--;
      } else if (event['type'] == 'appointment_start') {
        activeAppointmentCount++;
        // Add the actual appointment to the list
        finalCombinedList.add(event['data']);
      } else if (event['type'] == 'appointment_end') {
        activeAppointmentCount--;
      }

      lastProcessedTime = currentTime;
    }

    // Add any remaining open slot from the last processed time to the end of the day's working hours
    if (openClinicCount > 0 && activeAppointmentCount == 0) {
      DateTime? latestCloseTime;
      for (var slot in dayWorkingHours.timeSlots) {
        final closeTime = _combineDateAndTime(selectedDate, slot.closeTime);
        if (latestCloseTime == null || closeTime.isAfter(latestCloseTime)) {
          latestCloseTime = closeTime;
        }
      }
      if (lastProcessedTime != null && latestCloseTime != null && latestCloseTime.isAfter(lastProcessedTime)) {
          finalCombinedList.add({
            'isGap': true,
            'start': lastProcessedTime,
            'end': latestCloseTime,
          });
      }
    }

    // Final sort to ensure correct order (appointments and gaps might be added out of order slightly)
    finalCombinedList.sort((a, b) {
      DateTime aSortTime;
      DateTime bSortTime;

      if (a['isGap'] == true) {
        aSortTime = a['start'] as DateTime;
      } else {
        aSortTime = (a['appointment']['startTime'] as Timestamp).toDate();
      }

      if (b['isGap'] == true) {
        bSortTime = b['start'] as DateTime;
      } else {
        bSortTime = (b['appointment']['startTime'] as Timestamp).toDate();
      }
      return aSortTime.compareTo(bSortTime);
    });

    return finalCombinedList;
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
        _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate); // โหลดข้อมูลนัดหมายใหม่
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
            const SizedBox(height: 8), // เพิ่มระยะห่างเล็กน้อย
            Expanded( // ✨ ให้ ListView ใช้พื้นที่ที่เหลือ
              child: _appointmentsWithPatients.isEmpty && (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed || _selectedDayWorkingHours!.timeSlots.isEmpty) // ปรับเงื่อนไข
                  ? const Center(child: Text('ไม่มีนัดหมายและคลินิกปิดทำการ')) // ปรับข้อความ
                  : ListView.builder(
                      itemCount: buildAppointmentListWithGaps(_appointmentsWithPatients, _selectedDayWorkingHours, widget.selectedDate).length, // ส่ง working hours และ selectedDate
                      itemBuilder: (context, index) {
                        final item = buildAppointmentListWithGaps(
                          _appointmentsWithPatients,
                          _selectedDayWorkingHours,
                          widget.selectedDate,
                        )[index];

                        if (item['isGap'] == true) {
                          final gapStart = item['start'] as DateTime;
                          final gapEnd = item['end'] as DateTime;
                          return GapCard(
                            gapStart: gapStart, // Pass the gap's start time
                            gapEnd: gapEnd, // Pass the gap's end time
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AppointmentAddDialog(
                                  initialDate: widget.selectedDate,
                                  initialStartTime: gapStart,
                                ), // Pass the gap's start time
                              ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate));
                            },
                          );
                        }
 
                        final appointment = item['appointment'];
                        final patient = item['patient'];
                        return AppointmentCard(
                          appointment: appointment,
                          patient: patient,
                          onTap: () { // แก้ไข: ปิดวงเล็บของ onTap callback ให้ถูกต้อง
                            showDialog(
                              context: context,
                              builder: (_) => AppointmentAddDialog(
                                appointmentData: appointment,
                              ), // ส่งข้อมูลนัดหมายเดิม
                            ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)); // อัปเดตข้อมูล
                          }, // แก้ไข: ปิดวงเล็บของ onTap callback ให้ถูกต้อง
                        ); // แก้ไข: ปิดวงเล็บของ AppointmentCard constructor ให้ถูกต้อง
                      },
                    ),
            ), 
            // ✨ ปีกกาของ Expanded ควรจะปิดตรงนี้
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
          ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)); // อัปเดตข้อมูล
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
