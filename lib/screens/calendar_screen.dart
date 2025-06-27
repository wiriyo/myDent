// 📁 lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import 'patients_screen.dart';
import 'appointment_add.dart';
import 'setting_screen.dart';
import 'reports_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/appointment_card.dart'; // Import the new AppointmentCard
import '../widgets/gap_card.dart'; // Import the new GapCard
// For debugPrint
import '../models/working_hours_model.dart';
import 'daily_calendar_screen.dart';

// ✨ เพิ่ม enum สำหรับจัดการสถานะของปุ่มเปลี่ยนมุมมองปฏิทินค่ะ
enum _CalendarButtonMode { displayWeekly, displayDaily }

class CalendarScreen extends StatefulWidget {
  final bool showReset;
  const CalendarScreen({super.key, this.showReset = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _selectedAppointmentsWithPatients = [];
  DateTime _focusedDay = DateTime.now(); // Keep as is, initialized at declaration
  late DateTime _selectedDay; // Change to non-nullable and late
  DayWorkingHours? _selectedDayWorkingHours; // To store the result of working hours for the selected day
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0; // สำหรับ BottomNavigationBar

  // ✨ สถานะปัจจุบันของปุ่มเปลี่ยนมุมมอง เริ่มต้นให้ปุ่มแสดง "ดูรายสัปดาห์" (เพราะปฏิทินเริ่มที่รายเดือน)
  _CalendarButtonMode _buttonMode = _CalendarButtonMode.displayWeekly;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Initialize _selectedDay here
    _calendarFormat = CalendarFormat.month; // ปฏิทินเริ่มแสดงผลแบบรายเดือน
    _buttonMode = _CalendarButtonMode.displayWeekly; // ปุ่มจะแสดงตัวเลือกให้เปลี่ยนเป็น "รายสัปดาห์"
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay); // Call new combined fetch
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
    List<Map<String, dynamic>> appointmentsWithPatients = [];
    for (var appointment in appointments) {
      final patientId = appointment['patientId'];
      Map<String, dynamic>? patient = await _appointmentService.getPatientById(patientId);
      if (patient != null) {
        appointmentsWithPatients.add({'appointment': appointment, 'patient': patient});
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

    if (!mounted) return;
    setState(() {
      _selectedAppointmentsWithPatients = appointmentsWithPatients;
      _selectedDayWorkingHours = dayWorkingHours;
    });
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PatientsScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReportsScreen()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

  // ✨ ฟังก์ชันสำหรับสร้างปุ่มเปลี่ยนมุมมองปฏิทินแบบใหม่ค่ะ
  Widget _buildCalendarToggleButton() {
    IconData icon = Icons.error; // กำหนดค่าเริ่มต้น
    String label = ''; // กำหนดค่าเริ่มต้น
    VoidCallback onPressedAction = () {}; // กำหนดค่าเริ่มต้น

    if (_buttonMode == _CalendarButtonMode.displayWeekly) {
      icon = Icons.view_week; // ไอคอนสำหรับ "ดูรายสัปดาห์"
      label = 'ดูรายสัปดาห์';
      onPressedAction = () {
        setState(() {
          _calendarFormat = CalendarFormat.week; // เปลี่ยนปฏิทินเป็นรายสัปดาห์
          _buttonMode = _CalendarButtonMode.displayDaily; // ปุ่มต่อไปจะแสดง "ดูรายวัน"
        });
      };
    } else if (_buttonMode == _CalendarButtonMode.displayDaily) {
      icon = Icons.calendar_view_day; // ไอคอนสำหรับ "ดูรายวัน"
      label = 'ดูรายวัน';
      onPressedAction = () {
        // เมื่อกด "ดูรายวัน" ให้ไปที่หน้า DailyCalendarScreen และรอรับค่าที่อาจจะส่งกลับมา
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DailyCalendarScreen( // _selectedDay is guaranteed non-null here
              selectedDate: _selectedDay,
            ),
          ),
        ).then((returnedFormat) {
          // ✨ เมื่อ DailyCalendarScreen ถูก pop กลับมา
          if (mounted) { // ตรวจสอบว่า widget ยังอยู่ใน tree ไหม
            setState(() {
              if (returnedFormat is CalendarFormat) {
                // ถ้า DailyCalendarScreen ส่ง CalendarFormat กลับมา (เช่น จากปุ่มสลับมุมมองของมัน)
                _calendarFormat = returnedFormat; // อัปเดต format ของปฏิทินหลัก
                if (returnedFormat == CalendarFormat.month) {
                  _buttonMode = _CalendarButtonMode.displayWeekly; // ปุ่มต่อไปของปฏิทินหลักคือ "ดูรายสัปดาห์"
                } else { // returnedFormat == CalendarFormat.week
                  // ถ้ากลับมาเป็น week แสดงว่าก่อนหน้านี้ปฏิทินหลักเป็น week อยู่แล้ว
                  // และปุ่มควรจะแสดง "ดูรายวัน" เพื่อให้กดไป DailyScreen ได้อีก
                  // หรือถ้าผู้ใช้กด "ดูรายสัปดาห์" จาก DailyScreen กลับมา
                  // ปฏิทินหลักก็จะเป็น week และปุ่มก็ควรจะแสดง "ดูรายวัน"
                  _buttonMode = _CalendarButtonMode.displayDaily;
                }
              } else {
                // ถ้า DailyCalendarScreen pop กลับมาโดยไม่มีค่า (เช่น กด back ของเครื่อง),
                // ให้กลับไปที่มุมมองรายเดือนเป็นค่าเริ่มต้น เพื่อความสอดคล้องของ UI
                _calendarFormat = CalendarFormat.month;
                _buttonMode = _CalendarButtonMode.displayWeekly;
              }
            });
          }
        });
      };
    }

    return TextButton.icon(
      onPressed: onPressedAction,
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
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        title: const Text('Appointment Calendar'),
        actions:
            widget.showReset
                ? [
                  IconButton(
                    icon: Icon(Icons.developer_mode, size: 30),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('skipLogin');
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    tooltip: 'กลับไปหน้า Login',
                    color: Colors.white,
                  ),
                ]
                : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // ✨ ให้ปุ่มใหม่อยู่ทางขวาค่ะ
                    children: [
                      // ✨ ลบปุ่ม "ดูรายวัน" และ "ดูรายสัปดาห์/เดือน" เดิมออก
                      // ✨ แล้วใส่ปุ่มใหม่ที่เราสร้างขึ้นมาแทนค่ะ
                      _buildCalendarToggleButton(),
                    ],
                  ),

                  TableCalendar(
                    locale: 'th_TH',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(selectedDay);
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.pink.shade100,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.purple.shade300,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: TextStyle(
                        color: Colors.purple.shade200,
                      ),
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekendStyle: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _selectedAppointmentsWithPatients.isEmpty && (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed || _selectedDayWorkingHours!.timeSlots.isEmpty)
                      ? const Center(child: Text('ไม่มีนัดหมายและคลินิกปิดทำการ')) // Updated empty state message
                      : Builder( // Use Builder to get a fresh context for the combined list
                        builder: (context) {
                          final combinedAppointmentsAndGaps = buildAppointmentListWithGaps(
                            _selectedAppointmentsWithPatients,
                            _selectedDayWorkingHours,
                            _selectedDay,
                          );
                          return ListView.builder(
                            itemCount: combinedAppointmentsAndGaps.length,
                            itemBuilder: (context, index) {
                              final item = combinedAppointmentsAndGaps[index];

                              if (item['isGap'] == true) {
                                final gapStart = item['start'] as DateTime;
                                final gapEnd = item['end'] as DateTime;
                                return GapCard(
                                  gapStart: gapStart,
                                  gapEnd: gapEnd,
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AppointmentAddDialog(
                                        initialDate: _selectedDay,
                                        initialStartTime: gapStart,
                                      ),
                                    ).then((_) {
                                      _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
                                    });
                                  },
                                );
                              }

                              final appointment = item['appointment'];
                              final patient = item['patient'];
                              return AppointmentCard(
                                appointment: appointment,
                                patient: patient,
                              onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AppointmentAddDialog(
                                      appointmentData: appointment,
                                    ),
                                  ).then((_) {
                                    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
            ), // Closing parenthesis for Expanded
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AppointmentAddDialog(
                  initialDate: _selectedDay, // ✅ ส่งวันที่ที่เลือกในปฏิทินไปจ้า
                ),
          ).then((_) {
            _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
          });
        },
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.calendar_today, size: 30),
                color:
                    _selectedIndex == 0
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
                tooltip: 'ปฏิทิน', // เพิ่ม tooltip
              ),
              IconButton(
                icon: Icon(Icons.people_alt, size: 30),
                color:
                    _selectedIndex == 1
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
                tooltip: 'คนไข้', // เพิ่ม tooltip
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: Icon(Icons.bar_chart, size: 30),
                color:
                    _selectedIndex == 3
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
                tooltip: 'รายงาน', // เพิ่ม tooltip
              ),
              IconButton(
                icon: Icon(Icons.settings, size: 30),
                color:
                    _selectedIndex == 4
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
                tooltip: 'ตั้งค่า', // เพิ่ม tooltip
              ),
            ],
          ),
        ),
      ),
    );
  }
}
