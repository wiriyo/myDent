// v1.0.5 - Removed AppBar Back Button
// 📁 lib/screens/weekly_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// 🌸 Imports from our project
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../models/appointment_model.dart';
import '../models/working_hours_model.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import 'appointment_add.dart';
import '../widgets/appointment_detail_dialog.dart';
import '../widgets/view_mode_selector.dart';
import 'daily_calendar_screen.dart';
import '../widgets/timeline_view.dart';

class WeeklyCalendarScreen extends StatefulWidget {
  final DateTime focusedDate;
  const WeeklyCalendarScreen({super.key, required this.focusedDate});

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  // --- 🧍 ผู้ช่วยและตัวแปรต่างๆ ---
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  late DateTime _focusedDay;
  DateTime? _selectedDay;

  Map<DateTime, Map<String, dynamic>> _weeklyData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDate;
    _selectedDay = widget.focusedDate;
    _fetchDataForWeek(_focusedDay);
  }

  // --- ⚙️ ระบบจัดการข้อมูล ---
  Future<void> _fetchDataForWeek(DateTime focusedDay) async {
    setState(() { _isLoading = true; });

    DateTime firstDayOfWeek = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    Map<DateTime, Map<String, dynamic>> weeklyData = {};
    
    final allWorkingHours = await _workingHoursService.loadWorkingHours();

    try {
      for (int i = 0; i < 7; i++) {
        DateTime currentDay = firstDayOfWeek.add(Duration(days: i));
        DateTime dayKey = DateTime(currentDay.year, currentDay.month, currentDay.day);

        final dailyAppointments = await _appointmentService.getAppointmentsByDate(currentDay);
        
        List<Map<String, dynamic>> appointmentsWithPatients = [];
        for (var appointment in dailyAppointments) {
          final patient = await _patientService.getPatientById(appointment.patientId);
          if (patient != null) {
            final appointmentDataForTimeline = appointment.toMap();
            appointmentDataForTimeline['appointmentId'] = appointment.appointmentId;
            appointmentsWithPatients.add({
              'appointment': appointmentDataForTimeline,
              'patient': patient.toMap()
            });
          }
        }

        DayWorkingHours? dayWorkingHours;
        try {
          dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == _getThaiDayName(currentDay.weekday));
        } catch (e) {
          dayWorkingHours = null;
        }

        weeklyData[dayKey] = {
          'appointments': appointmentsWithPatients,
          'workingHours': dayWorkingHours,
        };
      }

      if (!mounted) return;

      setState(() {
        _weeklyData = weeklyData;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการดึงข้อมูลรายสัปดาห์: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  
  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  // --- 🎨 ส่วนประกอบของ UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        // ✨ The Fix! เอาปุ่ม Back ออกแล้วค่ะ
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('ปฏิทินรายสัปดาห์'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ViewModeSelector(
              calendarFormat: CalendarFormat.week,
              onFormatChanged: (format) {
                if (format == CalendarFormat.month) {
                  Navigator.pop(context);
                }
              },
              onDailyViewTapped: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyCalendarScreen(selectedDate: _selectedDay ?? DateTime.now()),
                  ),
                ).then((_) {
                  _fetchDataForWeek(_focusedDay);
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TableCalendar(
                locale: 'th_TH',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.week,
                availableCalendarFormats: const {
                  CalendarFormat.week: 'Week',
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppTheme.primaryLight.withOpacity(0.5), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _selectedDay = focusedDay;
                  });
                  _fetchDataForWeek(focusedDay);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _buildWeeklyAppointmentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AppointmentAddDialog(initialDate: _selectedDay ?? DateTime.now())
        ).then((_) => _fetchDataForWeek(_focusedDay)),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  /// Widget ที่แสดงรายการนัดหมายของทั้งสัปดาห์
  Widget _buildWeeklyAppointmentList() {
    List<DateTime> daysInWeek = List.generate(7, (index) {
      DateTime firstDay = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
      return firstDay.add(Duration(days: index));
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: daysInWeek.length,
      itemBuilder: (context, index) {
        final day = daysInWeek[index];
        final dayKey = DateTime(day.year, day.month, day.day);
        final dayData = _weeklyData[dayKey];

        return _buildDaySection(context, day, dayData);
      },
    );
  }

  /// Widget ของแต่ละวันให้แสดง TimelineView
  Widget _buildDaySection(BuildContext context, DateTime day, Map<String, dynamic>? dayData) {
    final dayFormatter = DateFormat('EEEE ที่ d', 'th_TH');
    bool isToday = isSameDay(day, DateTime.now());

    final appointments = dayData?['appointments'] as List<Map<String, dynamic>>? ?? [];
    final workingHours = dayData?['workingHours'] as DayWorkingHours?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ของวัน ---
          Text(
            dayFormatter.format(day),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isToday ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
          const Divider(thickness: 1.5),
          // --- ไทม์ไลน์ของวันนั้นๆ ---
          if (workingHours == null || workingHours.isClosed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'คลินิกปิดทำการ',
                  style: TextStyle(color: AppTheme.textDisabled),
                ),
              ),
            )
          else
            TimelineView(
              selectedDate: day,
              appointments: appointments,
              workingHours: workingHours,
              onDataChanged: () => _fetchDataForWeek(_focusedDay),
            ),
        ],
      ),
    );
  }
}
