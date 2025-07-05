// v1.0.7 - Final Fix for Navigation
// 📁 lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🌸 Imports from our project
import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import '../services/patient_service.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import 'appointment_add.dart';
import 'daily_calendar_screen.dart';
// ✨ 1. The Fix! จุดที่สำคัญที่สุดอยู่ตรงนี้ค่ะ!
// พี่ทะเลช่วยไลลาตรวจสอบหน่อยนะคะ ว่าไฟล์หน้าจอรายสัปดาห์ของเรา
// ชื่อว่า 'weekly_view_screen.dart' เป๊ะๆ แบบนี้เลยใช่ไหมคะ?
// และต้องอยู่ในโฟลเดอร์เดียวกันกับไฟล์นี้ (lib/screens/) นะคะ
import 'weekly_calendar_screen.dart'; 

class CalendarScreen extends StatefulWidget {
  final bool showReset;
  const CalendarScreen({super.key, this.showReset = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  List<Map<String, dynamic>> _selectedAppointmentsWithPatients = [];
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DayWorkingHours? _selectedDayWorkingHours;
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  CalendarFormat _calendarFormat = CalendarFormat.month; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
  }

  Future<void> _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    setState(() { _isLoading = true; });
    try {
      final appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      List<Map<String, dynamic>> appointmentsWithPatients = [];

      for (var appointment in appointments) {
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
        final allWorkingHours = await _workingHoursService.loadWorkingHours();
        dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == _getThaiDayName(selectedDay.weekday));
      } catch (e) {
        dayWorkingHours = null;
      }

      if (!mounted) return;

      setState(() {
        _selectedAppointmentsWithPatients = appointmentsWithPatients;
        _selectedDayWorkingHours = dayWorkingHours;
        _isLoading = false;
      });
    } catch(e) {
        debugPrint('Error fetching data for calendar screen: $e');
        if(mounted) setState(() { _isLoading = false; });
    }
  }
  
  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('ปฏิทินนัดหมาย'),
        actions: widget.showReset ? [
          IconButton(
            icon: const Icon(Icons.developer_mode, color: AppTheme.textSecondary),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('skipLogin');
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ] : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ViewModeSelector(
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                if (format == CalendarFormat.week) {
                  // ✨ 2. และเราจะเรียกใช้ WeeklyViewScreen ที่นี่ค่ะ
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeeklyViewScreen(focusedDate: _focusedDay),
                    ),
                  ).then((_) {
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
                  });
                } else {
                  if (_calendarFormat != format) {
                    setState(() { _calendarFormat = format; });
                  }
                }
              },
              onDailyViewTapped: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyCalendarScreen(selectedDate: _selectedDay),
                  ),
                ).then((_) {
                  _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
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
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
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
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(selectedDay);
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily)))
                    : TimelineView(
                        selectedDate: _selectedDay,
                        appointments: _selectedAppointmentsWithPatients,
                        workingHours: _selectedDayWorkingHours!,
                        onDataChanged: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: _selectedDay)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay)),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }
}
