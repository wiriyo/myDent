// v1.0.9 - Added Date Navigation
// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import 'appointment_add.dart';


class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  // ✨ The Fix! สร้างตัวแปรสำหรับเก็บวันที่ที่กำลังแสดงผลอยู่ค่ะ
  late DateTime _currentDate;
  List<Map<String, dynamic>> _appointmentsWithPatients = [];
  DayWorkingHours? _selectedDayWorkingHours;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✨ กำหนดค่าเริ่มต้นให้เป็นวันที่ที่ถูกส่งมาค่ะ
    _currentDate = widget.selectedDate;
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate);
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
        debugPrint("Could not find working hours for this day.");
      }

      if (!mounted) return;

      setState(() {
        _appointmentsWithPatients = appointmentsWithPatients;
        _selectedDayWorkingHours = dayWorkingHours;
        _isLoading = false;
      });
    } catch(e) {
        debugPrint('Error fetching data for daily screen: $e');
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
        title: const Text('รายวัน'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: ViewModeSelector(
              isDailyViewActive: true, 
              calendarFormat: CalendarFormat.month,
              onFormatChanged: (format) {
                Navigator.pop(context, format);
              },
              onDailyViewTapped: () {
                  _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate);
              },
            ),
          ),
          // ✨ The Fix! เพิ่มปุ่มลูกศรสำหรับเลื่อนวันค่ะ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
                  onPressed: () {
                    setState(() {
                      _currentDate = _currentDate.subtract(const Duration(days: 1));
                    });
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate);
                  },
                ),
                Text(
                  DateFormat('d MMMM yyyy', 'th_TH').format(_currentDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
                  onPressed: () {
                    setState(() {
                      _currentDate = _currentDate.add(const Duration(days: 1));
                    });
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily)))
                    : TimelineView(
                        selectedDate: _currentDate,
                        appointments: _appointmentsWithPatients,
                        workingHours: _selectedDayWorkingHours!,
                        onDataChanged: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate),
                      ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => showDialog(context: context, builder: (context) => AppointmentAddDialog(initialDate: _currentDate)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_currentDate)),
      backgroundColor: AppTheme.primary,
      tooltip: 'เพิ่มนัดหมายใหม่',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }
}
